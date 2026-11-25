#!/usr/bin/env python3
"""Check an origin-only executable: python3 storage/http_origin_check.py <command...>."""
import hashlib
import http.client
import json
import os
from pathlib import Path
import select
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time


def descriptors(pid):
    proc = Path(f"/proc/{pid}/fd")
    if proc.exists():
        return len(list(proc.iterdir()))
    rows = subprocess.check_output(["lsof", "-a", "-p", str(pid), "-Ff"], text=True)
    return sum(row[1:].isdigit() for row in rows.splitlines() if row.startswith("f"))


def request(port, path, digest=None):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
    try:
        conn.request("GET", path, headers={"Connection": "close"})
        response = conn.getresponse()
        got = hashlib.sha256()
        count = 0
        while chunk := response.read(65536):
            got.update(chunk)
            count += len(chunk)
        if digest is not None:
            assert response.status == 200
            assert got.hexdigest() == digest
            assert count == int(response.getheader("Content-Length"))
        return response.status
    finally:
        conn.close()


def exercise(command, mib):
    with tempfile.TemporaryDirectory(prefix="storage-origin-") as directory:
        objects = Path(directory) / "objects"
        objects.mkdir()
        size = mib * 1048576
        header = f"file {size}\n".encode()
        digest = hashlib.sha256(header)
        block = bytes(65536)
        fixture = objects / "fixture"
        with fixture.open("wb") as out:
            out.write(header)
            for _ in range(size // len(block)):
                out.write(block)
                digest.update(block)
        name = digest.hexdigest()
        fixture.rename(objects / name)
        (objects / ("1" * 64)).mkdir()
        env = dict(os.environ, STORAGE_ORIGIN_DIR=directory)
        server = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stopped = threading.Event()
        samples = []

        def sample():
            while not stopped.wait(0.02):
                row = subprocess.run(["ps", "-o", "rss=", "-p", str(server.pid)], capture_output=True, text=True)
                if row.stdout.strip():
                    samples.append(int(row.stdout) * 1024)

        watcher = threading.Thread(target=sample)
        try:
            assert select.select([server.stdout], [], [], 30)[0], "origin startup timed out"
            port = int(server.stdout.readline())
            assert request(port, "/objects/invalid") == 404
            assert request(port, "/objects/" + "0" * 64) == 404
            assert request(port, "/objects/" + "1" * 64) == 500
            watcher.start()
            for _ in range(3):
                request(port, "/objects/" + name, name)
            time.sleep(0.1)
            before = descriptors(server.pid)
            for _ in range(24):
                with socket.create_connection(("127.0.0.1", port), timeout=30) as client:
                    client.sendall(f"GET /objects/{name} HTTP/1.1\r\nHost: localhost\r\n\r\n".encode())
                    assert client.recv(1024).startswith(b"HTTP/1.1 200")
                    client.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
            request(port, "/objects/" + name, name)
            deadline = time.monotonic() + 5
            while descriptors(server.pid) > before and time.monotonic() < deadline:
                time.sleep(0.05)
            after = descriptors(server.pid)
            assert after <= before, ("descriptor leak", before, after)
            assert server.poll() is None, "origin died after an interrupted send"
            return {"payload_mib": mib, "peak_rss_bytes": max(samples), "descriptors_before": before, "descriptors_after": after}
        finally:
            stopped.set()
            if watcher.ident is not None:
                watcher.join()
            server.terminate()
            try:
                server.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.communicate()


def main():
    assert len(sys.argv) > 1, __doc__
    results = [exercise(sys.argv[1:], mib) for mib in (17, 129)]
    print(json.dumps(results, indent=2))
    assert results[1]["peak_rss_bytes"] - results[0]["peak_rss_bytes"] < 32 * 1048576, "source memory grows with payload"


if __name__ == "__main__":
    main()
