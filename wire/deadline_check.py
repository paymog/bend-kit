#!/usr/bin/env python3
"""Compiled native/JS live peers: exact bytes, reset, stall and boundaries."""
import json
from pathlib import Path
import queue
import shutil
import socket
import struct
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]


def guarded(command, timeout=120):
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    output = []
    reader = threading.Thread(target=lambda: output.extend(process.stdout), daemon=True)
    reader.start()
    until = time.monotonic() + timeout
    while process.poll() is None:
        rss = subprocess.run(["ps", "-o", "rss=", "-p", str(process.pid)],
                             capture_output=True, text=True).stdout.strip()
        if (rss and int(rss) > 20 * 1024 * 1024) or time.monotonic() > until:
            process.kill()
            process.wait()
            raise AssertionError(f"resource limit: {command}")
        time.sleep(0.05)
    reader.join()
    text = "".join(output)
    print(text, end="", flush=True)
    assert process.returncode == 0, (command, text)


def scenario(command, mode):
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    process = subprocess.Popen([*command, mode, str(port)], cwd=ROOT,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = queue.Queue()
    def read_lines():
        for line in process.stdout:
            lines.put((time.monotonic(), line.strip()))
    threading.Thread(target=read_lines, daemon=True).start()
    peer = None
    received = bytearray()
    read_times = []
    try:
        _, ready = lines.get(timeout=10)
        assert ready == "READY", ready
        peer = socket.socket()
        peer.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
        peer.settimeout(5)
        peer.connect(("127.0.0.1", port))
        if mode == "reset":
            peer.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
            peer.close()
            peer = None
        elif mode != "stall":
            while True:
                part = peer.recv(8192)
                read_times.append(time.monotonic())
                if not part:
                    break
                received.extend(part)
                if mode == "trickle":
                    time.sleep(0.01)
        begin, marker = lines.get(timeout=10)
        assert marker == "BEGIN", marker
        _, timing = lines.get(timeout=10)
        assert timing.startswith("ELAPSED "), timing
        elapsed = float(timing.split()[1])
        ended, result = lines.get(timeout=10)
        _, closed = lines.get(timeout=10)
        assert closed == "CLOSED", closed
        process.wait(timeout=5)
        assert process.returncode == 0
        fields = result.split()
        observed = (ended - begin) * 1000
        if mode == "success":
            assert fields == ["DONE", "4099"], fields
            assert received == (bytes([0, 1, 2, 3]) * 1025)[:4099]
        elif mode == "empty":
            assert fields == ["DONE", "0"] and received == b""
        elif mode in ("length", "zero-budget", "large-budget"):
            assert fields == ["FAIL", "22", "0"] and received == b""
        elif mode == "reset":
            assert fields[0] == "FAIL" and int(fields[1]) in (32, 54, 104)
            assert 0 <= int(fields[2]) < 16777216
        else:
            assert fields[0] == "FAIL" and int(fields[1]) in (60, 110), fields
            made = int(fields[2])
            assert 0 < made < 16777216, fields
            assert 80 <= elapsed <= 250, elapsed
            # After timeout the fixture explicitly closes its returned socket.
            while True:
                part = peer.recv(65536)
                if not part:
                    break
                received.extend(part)
            assert len(received) == made, (len(received), made)
            assert received == (bytes([0, 1, 2, 3]) * ((made + 3) // 4))[:made]
            if mode == "trickle":
                assert sum(t <= ended for t in read_times) > 1, read_times
        return {"scenario": mode, "result": result, "bytes_received": len(received),
                "call_to_continuation_ms": round(elapsed, 3),
                "parent_marker_interval_ms": round(observed, 3), "closed": True,
                "reads_before_result": sum(t <= ended for t in read_times)}
    finally:
        if peer is not None:
            peer.close()
        if process.poll() is None:
            process.kill()
        process.wait()


def main():
    assert shutil.disk_usage(ROOT).free > 10 * 1024**3, "need 10 GiB disk headroom"
    rows = []
    with tempfile.TemporaryDirectory(prefix="wire-deadline-") as directory:
        for lane, suffix in (("native", ""), ("js", ".js")):
            assert shutil.disk_usage(ROOT).free > 10 * 1024**3, "need 10 GiB disk headroom"
            target = str(Path(directory) / ("deadline" + suffix))
            guarded(["bend", "wire/deadline.bend", "-o", target])
            command = [target] if lane == "native" else ["bun", target]
            for mode in ("success", "empty", "length", "zero-budget", "large-budget", "reset", "stall", "trickle"):
                row = {"lane": lane, **scenario(command, mode)}
                rows.append(row)
                print(json.dumps(row), flush=True)
    print(json.dumps({"acceptance": rows}, indent=2))


if __name__ == "__main__":
    main()
