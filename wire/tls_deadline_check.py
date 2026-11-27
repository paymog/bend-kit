#!/usr/bin/env python3
"""Compiled native/JS live TLS peers: exact bytes, reset, stall, trickle, and boundaries."""
import json
import os
from pathlib import Path
import queue
import runpy
import shutil
import socket
import ssl
import struct
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
fixtures = runpy.run_path(str(ROOT / "stream/check.py"))

SCENARIOS = [
    ("success", "Given a verified TLS peer draining normally, When sending 4099 bytes with 1000ms budget, Then DONE 4099 with exact bytes"),
    ("empty", "Given a verified TLS peer, When sending 0 bytes with 100ms budget, Then DONE 0 with empty payload"),
    ("length", "Given a 4-byte buffer, When requesting len=5 with 100ms budget, Then FAIL EINVAL(22) with 0 bytes"),
    ("zero-budget", "Given a valid buffer, When ms=0, Then FAIL EINVAL(22) with 0 bytes"),
    ("large-budget", "Given a valid buffer, When ms=2147483648, Then FAIL EINVAL(22) with 0 bytes"),
    ("bad-fd", "Given a plain TCP socket without TLS attached, When calling tls.send.words.deadline, Then FAIL EBADF(9) with 0 bytes"),
    ("reset", "Given a TLS peer that resets immediately after handshake, When sending 16 MiB with 1000ms budget, Then FAIL EPIPE/ECONNRESET"),
    ("stall", "Given a TLS peer that never reads after handshake, When sending 16 MiB with 100ms budget, Then FAIL ETIMEDOUT within budget+tolerance"),
    ("trickle", "Given a TLS peer reading 256 KiB every 5ms, When sending 16 MiB with 100ms total budget, Then FAIL ETIMEDOUT after advancing past stall"),
]


def guarded(command, env=None, timeout=120):
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
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


def run_scenario(command, mode, context, env):
    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    listener.settimeout(15)
    port = listener.getsockname()[1]

    received = bytearray()
    read_times = []
    server_errors = []
    release_stall = threading.Event()

    def serve():
        peer = None
        try:
            raw, _ = listener.accept()
            raw.settimeout(5)
            if mode == "bad-fd":
                peer = raw
                release_stall.wait(timeout=5)
                return
            if mode in ("stall", "trickle"):
                raw.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
            peer = context.wrap_socket(raw, server_side=True, suppress_ragged_eofs=True)
            if mode == "reset":
                peer.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
                peer.close()
                peer = None
                return
            if mode == "stall":
                release_stall.wait(timeout=5)
                while True:
                    try:
                        part = peer.recv(65536)
                    except (ConnectionResetError, ssl.SSLError, OSError):
                        break
                    if not part:
                        break
                    received.extend(part)
                return
            while True:
                try:
                    part = peer.recv(131072 if mode == "trickle" else 8192)
                except (ConnectionResetError, ssl.SSLError, OSError):
                    break
                read_times.append(time.monotonic())
                if not part:
                    break
                received.extend(part)
                if mode == "trickle" and len(read_times) % 16 == 0:
                    time.sleep(0.005)
        except BaseException as exc:
            server_errors.append(exc)
        finally:
            if peer is not None:
                try:
                    peer.close()
                except OSError:
                    pass
            listener.close()

    server_thread = threading.Thread(target=serve, daemon=True)
    server_thread.start()

    process = subprocess.Popen([*command, mode, str(port)], cwd=ROOT, env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = queue.Queue()

    def read_lines():
        for line in process.stdout:
            lines.put((time.monotonic(), line.strip()))

    threading.Thread(target=read_lines, daemon=True).start()
    try:
        begin, marker = lines.get(timeout=15)
        assert marker == "BEGIN", marker
        _, timing = lines.get(timeout=15)
        assert timing.startswith("ELAPSED "), timing
        elapsed = float(timing.split()[1])
        ended, result = lines.get(timeout=15)
        release_stall.set()
        _, closed = lines.get(timeout=15)
        assert closed == "CLOSED", closed
        process.wait(timeout=10)
        assert process.returncode == 0, process.returncode
        server_thread.join(timeout=10)
        assert not server_errors, server_errors
        fields = result.split()
        observed = (ended - begin) * 1000
        if mode == "success":
            assert fields == ["DONE", "4099"], fields
            assert received == (bytes([0, 1, 2, 3]) * 1025)[:4099]
        elif mode == "empty":
            assert fields == ["DONE", "0"] and received == b"", (fields, len(received))
        elif mode in ("length", "zero-budget", "large-budget"):
            assert fields == ["FAIL", "22", "0"] and received == b"", (fields, len(received))
        elif mode == "bad-fd":
            assert fields == ["FAIL", "9", "0"] and received == b"", (fields, len(received))
        elif mode == "reset":
            assert fields[0] == "FAIL" and int(fields[1]) in (32, 54, 104), fields
            assert 0 <= int(fields[2]) < 16777216, fields
        elif mode == "stall":
            assert fields[0] == "FAIL" and int(fields[1]) in (60, 110), fields
            made = int(fields[2])
            assert 0 < made < 16777216, fields
            assert 80 <= elapsed <= 350, elapsed
            assert 0 < len(received) <= made, (len(received), made)
            assert received == (bytes([0, 1, 2, 3]) * ((len(received) + 3) // 4))[:len(received)]
        elif mode == "trickle":
            assert fields[0] == "FAIL" and int(fields[1]) in (60, 110), fields
            made = int(fields[2])
            assert 0 < made < 16777216, fields
            assert 80 <= elapsed <= 350, elapsed
            assert sum(t <= ended for t in read_times) > 1, read_times
            assert 0 < len(received) <= made, (len(received), made)
            assert received == (bytes([0, 1, 2, 3]) * ((len(received) + 3) // 4))[:len(received)]
        return {
            "scenario": mode,
            "result": result,
            "made": int(fields[2]) if len(fields) >= 3 else int(fields[1]),
            "bytes_received": len(received),
            "call_to_continuation_ms": round(elapsed, 3),
            "parent_marker_interval_ms": round(observed, 3),
            "closed": True,
            "reads_before_result": sum(t <= ended for t in read_times),
        }
    finally:
        release_stall.set()
        if process.poll() is None:
            process.kill()
        process.wait()
        server_thread.join(timeout=5)


def main():
    assert shutil.disk_usage(ROOT).free > 10 * 1024**3, "need 10 GiB disk headroom"
    rows = []
    with tempfile.TemporaryDirectory(prefix="wire-tls-deadline-") as directory:
        tmp = Path(directory)
        context = fixtures["certificates"](tmp)
        env = dict(os.environ, SSL_CERT_FILE=str(tmp / "ca.pem"))
        for lane, suffix in (("native", ""), ("js", ".js")):
            assert shutil.disk_usage(ROOT).free > 10 * 1024**3, "need 10 GiB disk headroom"
            target = str(tmp / ("tls_deadline" + suffix))
            guarded(["bend", "wire/tls_deadline.bend", "-o", target], env=env)
            command = [target] if lane == "native" else ["bun", target]
            lane_rows = {}
            for mode, gherkin in SCENARIOS:
                row = {"lane": lane, **run_scenario(command, mode, context, env)}
                rows.append(row)
                lane_rows[mode] = row
                print(f"PASS [{lane}] {gherkin} -> {row['result']} ({row['call_to_continuation_ms']}ms, rx={row['bytes_received']})", flush=True)
            assert lane_rows["trickle"]["made"] > lane_rows["stall"]["made"], (
                f"[{lane}] trickle must advance past stall before expiring: "
                f"trickle={lane_rows['trickle']['made']} stall={lane_rows['stall']['made']}"
            )
            print(f"PASS [{lane}] trickle progress ({lane_rows['trickle']['made']}) > stall ({lane_rows['stall']['made']}) within single 100ms budget", flush=True)
    print(json.dumps({"acceptance": rows}, indent=2))


if __name__ == "__main__":
    main()
