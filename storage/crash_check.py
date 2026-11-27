#!/usr/bin/env python3
"""Kill real storage writers at barrier boundaries. Never interrupt host power."""
import argparse
import hashlib
import json
import os
import pathlib
import platform
import plistlib
import re
import shutil
import signal
import subprocess
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
POINT = re.compile(r"^POINT (\d+) (\S+)$", re.MULTILINE)
C_HOOK = r'''
#ifndef STORAGE_CRASH_CHECK
#define STORAGE_CRASH_CHECK
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
static void storage_crash_point(const char* label) {
  int saved_errno = errno;
  static unsigned count;
  ++count;
  fprintf(stderr, "POINT %u %s\n", count, label);
  fflush(stderr);
  const char* target = getenv("STORAGE_CRASH_AT");
  if (target && strtoul(target, NULL, 10) == count) raise(SIGSTOP);
  errno = saved_errno;
}
#endif
'''
JS_HOOK = r'''
let storageCrashCount = 0;
function storage_crash_point(label) {
  ++storageCrashCount;
  require("fs").writeSync(2, `POINT ${storageCrashCount} ${label}\n`);
  if (Number(process.env.STORAGE_CRASH_AT) === storageCrashCount) {
    process.kill(process.pid, "SIGSTOP");
  }
}
'''


def checked(command, **kwargs):
    return subprocess.run(command, check=True, capture_output=True, timeout=120,
                          **kwargs).stdout


def instrument(source, language):
    # Only the disposable source copy gets hooks; published effects stay unchanged.
    if language == "c":
        replacements = {
            "  do { rc = fsync(fd); } while (rc < 0 && errno == EINTR);":
                '  storage_crash_point(directory ? "directory.fsync.before" : "file.fsync.before");\n'
                '  do { rc = fsync(fd); } while (rc < 0 && errno == EINTR);\n'
                '  storage_crash_point(directory ? "directory.fsync.after" : "file.fsync.after");',
            "    do { rc = fcntl(fd, F_FULLFSYNC); } while (rc < 0 && errno == EINTR);":
                '    storage_crash_point(directory ? "directory.fullsync.before" : "file.fullsync.before");\n'
                '    do { rc = fcntl(fd, F_FULLFSYNC); } while (rc < 0 && errno == EINTR);\n'
                '    storage_crash_point(directory ? "directory.fullsync.after" : "file.fullsync.after");',
            "  if (rename(tmp, path) < 0) { w->code = errno; return; }":
                '  storage_crash_point("rename.before");\n'
                '  if (rename(tmp, path) < 0) { w->code = errno; return; }\n'
                '  storage_crash_point("rename.after");',
        }
        hook = C_HOOK
    else:
        replacements = {
            "    fs.fsyncSync(fd);":
                '    storage_crash_point(directory ? "directory.fsync.before" : "file.fsync.before");\n'
                '    fs.fsyncSync(fd);\n'
                '    storage_crash_point(directory ? "directory.fsync.after" : "file.fsync.after");',
            "      let rc, code;":
                '      storage_crash_point(directory ? "directory.fullsync.before" : "file.fullsync.before");\n'
                '      let rc, code;',
            "      if (code) throw {errno: code};":
                '      storage_crash_point(directory ? "directory.fullsync.after" : "file.fullsync.after");\n'
                '      if (code) throw {errno: code};',
            "      fs.renameSync(tb, pb);":
                '      storage_crash_point("rename.before");\n'
                '      fs.renameSync(tb, pb);\n'
                '      storage_crash_point("rename.after");',
        }
        hook = JS_HOOK
    for old, new in replacements.items():
        assert source.count(old) == 1, (language, old, "update instrumentation for changed effects")
        source = source.replace(old, new)
    return hook + source


def compile_drivers(base):
    source = base / "source"
    shutil.copytree(HERE, source, ignore=shutil.ignore_patterns("bench", "__pycache__"))
    for language in ("c", "js"):
        effect = source / "effs" / f"storage.{language}"
        effect.write_text(instrument(effect.read_text(), language))
    drivers = {}
    for lane, suffix in (("native", ""), ("bun", ".js")):
        output = base / f"writer{suffix}"
        command = ["bend", "crash_check.bend", "-o", str(output)]
        with subprocess.Popen(command, cwd=source, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE) as proc:
            deadline = time.monotonic() + 180
            try:
                while proc.poll() is None:
                    rss = subprocess.run(["ps", "-o", "rss=", "-p", str(proc.pid)],
                                         capture_output=True, text=True, timeout=5).stdout.strip()
                    if (rss and int(rss) > 20 * 1024 * 1024) or time.monotonic() > deadline:
                        raise RuntimeError("compiler exceeded memory or time limit")
                    time.sleep(0.1)
                out, err = proc.communicate(timeout=30)
            except BaseException:
                proc.kill()
                proc.wait()
                raise
            assert proc.returncode == 0, (command, out.decode(), err.decode())
        drivers[lane] = (["bun"] if suffix else []) + [str(output)]
    return drivers


def invoke(command, mode, store, value, digest, target=0, detach=None):
    env = dict(os.environ, STORAGE_CRASH_AT=str(target))
    proc = subprocess.Popen([*command, mode, str(store), str(value), digest], env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        if target:
            deadline = time.monotonic() + 30
            while True:
                pid, status = os.waitpid(proc.pid, os.WUNTRACED | os.WNOHANG)
                if pid:
                    assert os.WIFSTOPPED(status), (mode, target, status, proc.communicate())
                    assert os.WSTOPSIG(status) == signal.SIGSTOP
                    break
                assert time.monotonic() < deadline, (mode, target, "checkpoint timeout")
                time.sleep(0.002)
            if detach:
                detach()
            proc.kill()
        out, err = proc.communicate(timeout=30)
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
    points = [(int(n), label) for n, label in POINT.findall(err)]
    if target:
        assert proc.returncode == -signal.SIGKILL, (out, err, proc.returncode)
        assert points and points[-1][0] == target, (target, points)
        assert "ACK" not in out, out
    else:
        assert proc.returncode == 0 and out.strip() == "ACK", (mode, out, err)
    return points


def objects():
    raws = [b"file 11\nnew payload", b"end\n"]
    hashes = [hashlib.sha256(raw).hexdigest() for raw in raws]
    raws.append(f"item {hashes[0]} {hashes[1]} child\n".encode())
    return {hashlib.sha256(raw).hexdigest(): raw for raw in raws}


OBJECTS = objects()
NEW = list(OBJECTS)[-1]
OLD_RAW = b"file 11\nold payload"
OLD = hashlib.sha256(OLD_RAW).hexdigest()


def verify(store):
    nodes = {}
    for path in (store / "objects").iterdir():
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == path.name, path
        if raw == b"end\n":
            links = []
        elif raw.startswith(b"file "):
            header, payload = raw.split(b"\n", 1)
            assert header == f"file {len(payload)}".encode(), path
            links = []
        else:
            assert re.fullmatch(rb"item [0-9a-f]{64} [0-9a-f]{64} child\n", raw), path
            links = [part.decode() for part in raw.split()[1:3]]
        nodes[path.name] = links
    roots = {}
    for path in (store / "roots").iterdir():
        digest = path.read_text()
        assert re.fullmatch(r"[0-9a-f]{64}", digest), path
        pending, seen = [digest], set()
        while pending:
            key = pending.pop()
            assert key in nodes, (path, "missing closure", key)
            if key not in seen:
                seen.add(key)
                pending.extend(nodes[key])
        roots[path.name] = digest
    assert roots["ack"] == OLD, roots
    return roots


def oracle_check(base):
    store = base / "oracle"
    for name in ("objects", "roots", "tmp"):
        (store / name).mkdir(parents=True)
    for digest, raw in {**OBJECTS, OLD: OLD_RAW}.items():
        (store / "objects" / digest).write_bytes(raw)
    (store / "roots" / "ack").write_text(OLD)
    candidate = store / "roots" / "candidate"
    candidate.write_text(NEW)
    assert verify(store) == {"ack": OLD, "candidate": NEW}
    leaf = store / "objects" / next(iter(OBJECTS))
    raw = leaf.read_bytes()
    for corruption in ("missing", "tampered", "partial-root"):
        if corruption == "missing":
            leaf.unlink()
        elif corruption == "tampered":
            leaf.write_bytes(b"file 7\ncorrupt")
        else:
            candidate.write_text(NEW[:32])
        try:
            verify(store)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"oracle accepted {corruption}")
        leaf.write_bytes(raw)
        candidate.write_text(NEW)
    shutil.rmtree(store)


def prepare(command, store, fixture, scenario):
    invoke(command, "init", store, "unused", OLD)
    invoke(command, "object", store, fixture / OLD, OLD)
    invoke(command, "root", store, "ack", OLD)
    if scenario != "object":
        for digest in OBJECTS:
            if scenario == "fence":
                trace = invoke(command, "object", store, fixture / digest, digest)
                # Discover the rename checkpoint on a separate complete publication.
                (store / "objects" / digest).unlink()
                point = next(n for n, label in trace if label == "rename.after")
                invoke(command, "object", store, fixture / digest, digest, point)
            else:
                invoke(command, "object", store, fixture / digest, digest)
    if scenario == "replace":
        invoke(command, "root", store, "candidate", OLD)


def recover(command, store, scenario):
    roots = verify(store)
    candidate = roots.get("candidate")
    assert candidate in ({OLD, NEW} if scenario == "replace" else {None, NEW}), roots
    for digest in roots.values():
        invoke(command, "verify", store, "unused", digest)
    # A fresh process must acquire the exclusive lock left by the killed writer.
    invoke(command, "clean", store, "unused", OLD)
    assert not list((store / "tmp").iterdir())
    if scenario == "object":
        digest = next(iter(OBJECTS))
        return "new" if (store / "objects" / digest).exists() else "absent"
    return "old" if candidate == OLD else "new" if candidate else "absent"


class Image:
    def __init__(self, base):
        self.path = base / "recovery.sparseimage"
        self.mount = base / "mount"
        self.device = None
        checked(["hdiutil", "create", "-size", "256m", "-type", "SPARSE",
                 "-fs", "APFS", "-volname", "storage-crash-check", str(self.path)])
        self.attach()

    def attach(self):
        data = plistlib.loads(checked(["hdiutil", "attach", "-plist", "-nobrowse",
                                     "-mountpoint", str(self.mount), str(self.path)]))
        self.device = data["system-entities"][0]["dev-entry"]
        try:
            assert any(pathlib.Path(entity["mount-point"]).resolve() == self.mount.resolve()
                       for entity in data["system-entities"] if "mount-point" in entity), data
        except BaseException:
            self.close()
            raise

    def detach(self):
        # This targets only the device returned for the image this run created.
        checked(["hdiutil", "detach", "-force", self.device])
        self.device = None

    def close(self):
        if self.device:
            checked(["hdiutil", "detach", self.device])
            self.device = None


def matrix(drivers, base, fixture, image, records):
    location = image.mount if image else base
    for lane, command in drivers.items():
        for scenario in ("object", "create", "replace", "fence"):
            control = location / f"{lane}-{scenario}-control"
            prepare(command, control, fixture, scenario)
            mode, value, digest = (("object", fixture / next(iter(OBJECTS)), next(iter(OBJECTS)))
                                   if scenario == "object" else ("root", "candidate", NEW))
            trace = invoke(command, mode, control, value, digest)
            assert trace and [n for n, _ in trace] == list(range(1, len(trace) + 1))
            assert {"file.fsync.before", "file.fsync.after", "rename.before", "rename.after"} <= {label for _, label in trace}
            if platform.system() == "Darwin":
                assert {"file.fullsync.before", "file.fullsync.after", "directory.fullsync.before", "directory.fullsync.after"} <= {label for _, label in trace}
            assert recover(command, control, scenario) == "new"
            renamed = next(n for n, label in trace if label == "rename.after")
            if image:
                # Force-detach around rename and after the last directory barrier.
                selected = [next(p for p in trace if p[1] == label)
                            for label in ("rename.before", "rename.after")]
                selected.append(trace[-1])
            else:
                selected = trace
            for point, label in selected:
                store = location / f"{lane}-{scenario}-{point}"
                prepare(command, store, fixture, scenario)
                observed = invoke(command, mode, store, value, digest, point,
                                  image.detach if image else None)
                assert observed == trace[:point], (trace, observed)
                if image:
                    image.attach()
                    assert recover(command, control, scenario) == "new"
                outcome = recover(command, store, scenario)
                if point < renamed:
                    assert outcome == ("old" if scenario == "replace" else "absent"), (point, label, outcome)
                elif not image or point == trace[-1][0]:
                    assert outcome == "new", (point, label, outcome)
                record = dict(lane=lane, scenario=scenario, point=point, label=label,
                              medium="apfs-force-detach" if image else "host",
                              outcome=outcome)
                records.append(record)
                print(json.dumps(record), flush=True)
                shutil.rmtree(store)
            shutil.rmtree(control)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apfs-image", action="store_true",
                        help="also force-detach only a disposable image created by this run")
    parser.add_argument("--report", type=pathlib.Path, required=True)
    args = parser.parse_args()
    report = dict(host=platform.platform(), machine=platform.machine(),
                  bend=checked(["bend", "version"], text=True).strip(),
                  bun=checked(["bun", "--version"], text=True).strip(), trials=[])
    try:
        with tempfile.TemporaryDirectory(prefix="storage-crash-") as directory:
            base = pathlib.Path(directory).resolve()
            oracle_check(base)
            fixture = base / "fixture"
            fixture.mkdir()
            for digest, raw in {**OBJECTS, OLD: OLD_RAW}.items():
                (fixture / digest).write_bytes(raw)
            drivers = compile_drivers(base)
            matrix(drivers, base, fixture, None, report["trials"])
            if args.apfs_image:
                assert platform.system() == "Darwin", "APFS image trials require macOS"
                image = Image(base)
                try:
                    report["image_info"] = checked(["diskutil", "info", "-plist", str(image.mount)]).decode()
                    matrix(drivers, base, fixture, image, report["trials"])
                finally:
                    image.close()
        report["result"] = "pass"
    except BaseException as error:
        report["result"] = "fail"
        report["error"] = repr(error)
        raise
    finally:
        args.report.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
