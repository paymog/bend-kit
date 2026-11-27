#!/usr/bin/env python3
"""Compiled native/JS ws:// and wss:// write-deadline acceptance checks."""
import base64
import hashlib
import os
from pathlib import Path
import queue
import runpy
import shutil
import socket
import ssl
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
fixtures = runpy.run_path(str(ROOT / "stream/check.py"))
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

SCENARIOS = [
    ("send-ok", "Given a draining WebSocket peer, When WS.send(4 KiB, 1000ms), Then DONE"),
    ("send-bad-ms", "Given an invalid budget ms=2147483648, When WS.send, Then FAIL EINVAL(22)"),
    ("close-bad-ms", "Given an invalid budget ms=2147483648, When WS.close, Then FAIL EINVAL(22)"),
    ("close-ok", "Given a draining WebSocket peer, When WS.close(1000, 'bye', 1000ms), Then DONE"),
    ("send-stall", "Given a stalled WebSocket peer that never reads after upgrade, When WS.send(16 MiB, 100ms), Then FAIL ETIMEDOUT within budget+tolerance"),
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
    assert process.returncode == 0, (command, text)


def ws_handshake(peer):
    buf = bytearray()
    while b"\r\n\r\n" not in buf:
        chunk = peer.recv(4096)
        if not chunk:
            raise EOFError("closed during handshake")
        buf.extend(chunk)
    head = bytes(buf).decode("ascii", errors="replace")
    key = None
    for line in head.split("\r\n"):
        if line.lower().startswith("sec-websocket-key:"):
            key = line.split(":", 1)[1].strip()
    assert key, head
    accept = base64.b64encode(hashlib.sha1((key + GUID).encode("ascii")).digest()).decode("ascii")
    resp = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
    ).encode("ascii")
    peer.sendall(resp)


def run_scenario(command, mode, scheme, context, env):
    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    listener.settimeout(15)
    port = listener.getsockname()[1]

    release_stall = threading.Event()
    server_errors = []

    def serve():
        peer = None
        try:
            raw, _ = listener.accept()
            raw.settimeout(5)
            if mode == "send-stall":
                raw.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
            peer = context.wrap_socket(raw, server_side=True, suppress_ragged_eofs=True) if scheme == "wss" else raw
            ws_handshake(peer)
            if mode == "send-stall":
                release_stall.wait(timeout=5)
                return
            while True:
                try:
                    data = peer.recv(65536)
                except (ConnectionResetError, ssl.SSLError, OSError):
                    break
                if not data:
                    break
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

    process = subprocess.Popen([*command, mode, scheme, str(port)], cwd=ROOT, env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = queue.Queue()

    def read_lines():
        for line in process.stdout:
            lines.put(line.strip())

    threading.Thread(target=read_lines, daemon=True).start()
    try:
        assert lines.get(timeout=15) == "BEGIN"
        timing = lines.get(timeout=15)
        assert timing.startswith("ELAPSED "), timing
        elapsed = float(timing.split()[1])
        result = lines.get(timeout=15)
        release_stall.set()
        assert lines.get(timeout=15) == "CLOSED"
        process.wait(timeout=10)
        assert process.returncode == 0, process.returncode
        server_thread.join(timeout=10)
        assert not server_errors, server_errors
        if mode in ("send-ok", "close-ok"):
            assert result == "DONE", result
        elif mode in ("send-bad-ms", "close-bad-ms"):
            assert result == "FAIL 22", result
        elif mode == "send-stall":
            fields = result.split()
            assert fields[0] == "FAIL" and int(fields[1]) in (60, 110), result
            assert 80 <= elapsed <= 600, elapsed
        return result, round(elapsed, 3)
    finally:
        release_stall.set()
        if process.poll() is None:
            process.kill()
        process.wait()
        server_thread.join(timeout=5)


def main():
    assert shutil.disk_usage(ROOT).free > 10 * 1024**3, "need 10 GiB disk headroom"
    with tempfile.TemporaryDirectory(prefix="ws-deadline-") as directory:
        tmp = Path(directory)
        context = fixtures["certificates"](tmp)
        env = dict(os.environ, SSL_CERT_FILE=str(tmp / "ca.pem"))
        for lane, suffix in (("native", ""), ("js", ".js")):
            target = str(tmp / ("ws_deadline" + suffix))
            guarded(["bend", "websocket/deadline_check.bend", "-o", target], env=env)
            command = [target] if lane == "native" else ["bun", target]
            for scheme in ("ws", "wss"):
                for mode, gherkin in SCENARIOS:
                    result, elapsed = run_scenario(command, mode, scheme, context, env)
                    print(f"PASS [{lane}/{scheme}] {gherkin} -> {result} ({elapsed}ms)", flush=True)


if __name__ == "__main__":
    main()
