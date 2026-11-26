#!/usr/bin/env python3
"""Check local maintenance without constructing payloads in Bend."""
import hashlib
import pathlib
import subprocess
import sys
import tempfile
import time

COMMAND = sys.argv[1:]


def store(path):
    for name in ("objects", "roots", "tmp"):
        (path / name).mkdir(parents=True, exist_ok=True)


def put(path, raw):
    digest = hashlib.sha256(raw).hexdigest()
    (path / "objects" / digest).write_bytes(raw)
    return digest


def invoke(mode, src, dst, root, expected=None):
    proc = subprocess.Popen([*COMMAND, mode, str(src), str(dst), root],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    peak = 0
    deadline = time.monotonic() + 30
    while proc.poll() is None:
        if time.monotonic() > deadline:
            proc.kill()
            proc.communicate()
            raise AssertionError("maintenance exceeded 30 seconds")
        sample = subprocess.run(["ps", "-o", "rss=", "-p", str(proc.pid)],
                                capture_output=True, text=True)
        if sample.stdout.strip():
            peak = max(peak, int(sample.stdout.strip()) * 1024)
        time.sleep(0.005)
    out, err = proc.communicate()
    if expected is None:
        assert proc.returncode != 0, (mode, out, err)
    else:
        assert proc.returncode == 0 and out.strip() == str(expected), (mode, out, err)
    assert not list((dst / "tmp").iterdir())
    return peak


def fixture(src, size):
    store(src)
    header = f"file {size}\n".encode()
    hash_ = hashlib.sha256(header)
    temporary = src / "tmp" / "fixture"
    with temporary.open("wb") as file:
        file.write(header)
        chunk = bytes(65536)
        for offset in range(0, size, len(chunk)):
            piece = chunk[:min(len(chunk), size - offset)]
            file.write(piece)
            hash_.update(piece)
    leaf = hash_.hexdigest()
    temporary.rename(src / "objects" / leaf)
    root = leaf
    for _ in range(24):
        root = put(src, f"item {root} {root} shared\n".encode())
    (src / "roots" / "live").write_text(root)
    return root, leaf


def large(base, mib):
    src, dst = base / f"src-{mib}", base / f"dst-{mib}"
    root, leaf = fixture(src, mib * 1024 * 1024)
    store(dst)
    peaks = [invoke("sync", src, dst, root, 25)]
    assert sorted(p.name for p in (src / "objects").iterdir()) == sorted(p.name for p in (dst / "objects").iterdir())
    for obj in (dst / "objects").iterdir():
        hash_ = hashlib.sha256()
        with obj.open("rb") as file:
            while chunk := file.read(65536):
                hash_.update(chunk)
        assert hash_.hexdigest() == obj.name
    peaks.append(invoke("sync", src, dst, root, 0))
    put(dst, b"end\n")
    peaks.append(invoke("collect", dst, dst, root, 1))
    (dst / "roots" / "live").write_text(root)
    put(dst, b"file 1\nx")
    peaks.append(invoke("named", dst, dst, root, 1))
    assert len(list((dst / "objects").iterdir())) == 25
    print(f"local maintenance {mib} MiB: peak sampled RSS {max(peaks)} bytes", flush=True)
    return max(peaks)


def failures(base):
    src, dst = base / "small-src", base / "small-dst"
    root, leaf = fixture(src, 1)
    store(dst)
    missing = "0" * 64
    put(dst, b"end\n")
    before = sorted(p.name for p in (dst / "objects").iterdir())
    invoke("collect", dst, dst, missing)
    assert before == sorted(p.name for p in (dst / "objects").iterdir())
    original = (src / "objects" / leaf).read_bytes()
    for bad in (None, b"file 1\ny"):
        path = src / "objects" / leaf
        if bad is None:
            path.unlink()
        else:
            path.write_bytes(bad)
        invoke("sync", src, dst, root)
        invoke("collect", src, src, root)
        assert before == sorted(p.name for p in (dst / "objects").iterdir())
        assert (src / "objects" / root).exists()
        path.write_bytes(original)
    # A destination with a corrupt reachable object must fail before any copy.
    (dst / "objects" / leaf).write_bytes(b"broken")
    invoke("sync", src, dst, root)
    assert not (dst / "objects" / root).exists()
    (dst / "objects" / leaf).unlink()
    for raw in (b"file 01\nx", b"end\nx", b"item invalid\n"):
        digest = put(src, raw)
        invoke("sync", src, dst, digest)
        invoke("collect", src, src, digest)
        assert (src / "objects" / root).exists()
    invoke("sync", src, dst, root, 25)
    # Unrelated corrupt objects do not affect a reachable walk.
    put(dst, b"invalid")
    invoke("sync", src, dst, root, 0)
    print("ok local maintenance failures and collection safety", flush=True)


with tempfile.TemporaryDirectory(prefix="storage-local-") as directory:
    base = pathlib.Path(directory)
    failures(base)
    small = large(base, 17)
    large_rss = large(base, 129)
    assert large_rss - small < 32 * 1024 * 1024, (small, large_rss)
