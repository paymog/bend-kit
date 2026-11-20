#!/usr/bin/env python3
"""Scoped package gate plus native/JS owner acceptance; one Bend process at a time."""
import os
from pathlib import Path
import shutil
import signal
import threading
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def run(args, timeout=120, on_line=None):
    if shutil.disk_usage(ROOT).free < 10 * 1024**3:
        raise RuntimeError("less than 10 GiB disk headroom")
    print("$", " ".join(map(str, args)), flush=True)
    with tempfile.NamedTemporaryFile(mode="w+") as output, open(output.name) as reader:
        process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)

        def drain():
            if on_line is None:
                return
            while True:
                position = reader.tell()
                line = reader.readline()
                if not line.endswith("\n"):
                    reader.seek(position)
                    return
                on_line(line)

        started = time.monotonic()
        peak = 0
        try:
            while process.poll() is None:
                drain()
                snapshot = subprocess.check_output(["ps", "-axo", "pid=,ppid=,rss="], text=True)
                rows = [tuple(map(int, line.split())) for line in snapshot.splitlines()]
                members = {process.pid}
                while True:
                    expanded = members | {pid for pid, parent, rss in rows if parent in members}
                    if expanded == members:
                        break
                    members = expanded
                for pid, parent, rss in rows:
                    if pid in members:
                        peak = max(peak, rss)
                        if rss > 20 * 1024**2:
                            raise RuntimeError("RSS exceeds 20 GiB")
                if time.monotonic() - started > timeout:
                    raise RuntimeError("command timed out")
                time.sleep(0.1)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
        output.seek(0)
        drain()
        text = output.read()
    print(text, end="")
    print(f"exit={process.returncode} peak_rss_kib={peak}", flush=True)
    if process.returncode:
        raise RuntimeError("command failed")
    if "JOURNAL " in text:
        assert "camber journal: PASS" in text
        assert text.splitlines().count("PARTIAL CLOSED") == 1
        assert text.splitlines().count("CLOSED 0") == 2
        assert text.splitlines().count("CLOSED 1") == 3
        assert "camber owner: PASS" in text
        print("journals/explicit closes: PASS", flush=True)
    return text


def ready_ports(text, prefix="READY", count=1):
    lines = [line.split() for line in text.splitlines() if line.startswith(prefix + " ")]
    assert len(lines) == count, ("missing or duplicate listener ports", text)
    ports = tuple(int(line[1]) for line in lines)
    assert all(0 < port <= 65535 for port in ports), lines
    return ports


def run_live(args, clients, timeout=120):
    failures, threads = [], []

    def connect(port):
        try:
            clients(port)
        except BaseException as error:
            failures.append(error)

    def output(line):
        if line.startswith("READY "):
            assert not threads, "duplicate readiness"
            port, = ready_ports(line)
            thread = threading.Thread(target=connect, args=(port,), daemon=True)
            threads.append(thread)
            thread.start()

    text = run(args, timeout=timeout, on_line=output)
    assert len(threads) == 1, "server did not report its port"
    threads[0].join(timeout=20)
    assert not threads[0].is_alive(), "live client unfinished"
    if failures:
        raise failures[0]
    return text


def main():
    run(["bash", "scripts/check.sh", "camber"])
    with tempfile.TemporaryDirectory(prefix="camber-owner-build-") as temp:
        native = str(Path(temp) / "owner")
        js = native + ".js"
        run(["bend", "camber/check.bend", "-o", native])
        run([native])
        run(["bend", "camber/check.bend", "-o", js])
        run(["bun", js])
    print("owner native/JS acceptance: PASS")


if __name__ == "__main__":
    main()
