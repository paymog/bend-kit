#!/usr/bin/env python3
"""Validate runtime context and affine bundles over loopback sockets, in both lanes."""
import http.client
import json
import queue
import socket
import subprocess
import tempfile
import threading
import time
from contextlib import ExitStack
from pathlib import Path

from run_dispatch import ENV, ROOT, RSS_LIMIT_KIB, guarded


class Peer:
    def __init__(self, port):
        self.socket = socket.create_connection(("127.0.0.1", port), timeout=5)
        self.reader = self.socket.makefile("rb")

    def close(self):
        self.reader.close()
        self.socket.close()

    def send(self, method, path, body=b"", token="Bearer alice", close=False, **headers):
        fields = {
            "host": "localhost",
            "content-length": str(len(body)),
            "content-type": "application/json",
            "authorization": token,
            "connection": "close" if close else "keep-alive",
            **headers,
        }
        head = f"{method} {path} HTTP/1.1\r\n" + "".join(f"{key}: {value}\r\n" for key, value in fields.items()) + "\r\n"
        self.socket.sendall(head.encode("ascii") + body)

    def response(self, status, body, head=False):
        line = self.reader.readline()
        assert line.startswith(f"HTTP/1.1 {status} ".encode()), line
        headers = http.client.parse_headers(self.reader)
        if status == 204:
            assert body == b"" and headers.get("content-length") is None and headers.get("transfer-encoding") is None, headers
        else:
            assert headers.get_all("content-length") == [str(len(body))], headers
        got = self.reader.read(0 if head else len(body))
        assert got == (b"" if head else body), (got, body)
        return headers

    def capacity(self, expected):
        self.send("GET", "/_capacity")
        body = json.dumps(expected, separators=(",", ":")).encode()
        self.response(200, body)


class Server:
    def __init__(self, command, prefix, workers, connections, store_mode="w", audit_mode="w"):
        self.prefix = prefix
        self.workers = workers
        for slot in range(workers):
            Path(f"{prefix}-store-{slot}").write_bytes(b"")
            Path(f"{prefix}-audit-{slot}").write_bytes(b"seed\n" if audit_mode == "r" else b"")
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            self.port = reservation.getsockname()[1]
        self.lines = []
        self.events = queue.Queue()
        self.errors = tempfile.TemporaryFile(mode="w+t")
        self.process = subprocess.Popen(
            [*command, prefix, str(self.port), str(workers), str(connections), store_mode, audit_mode],
            cwd=ROOT, env=ENV, stdout=subprocess.PIPE, stderr=self.errors, text=True,
        )
        self.reader = threading.Thread(target=self.read_output, daemon=True)
        self.monitor = threading.Thread(target=self.watch, daemon=True)
        self.reader.start()
        self.monitor.start()

    def read_output(self):
        for line in self.process.stdout:
            text = line.strip()
            self.lines.append(text)
            self.events.put(text)
        self.events.put(None)

    def watch(self):
        deadline = time.monotonic() + 20
        while self.process.poll() is None:
            rss = subprocess.run(["ps", "-o", "rss=", "-p", str(self.process.pid)], capture_output=True, text=True, timeout=5)
            if (rss.stdout.strip() and int(rss.stdout) > RSS_LIMIT_KIB) or time.monotonic() > deadline:
                self.events.put("HOST DEADLINE OR RSS LIMIT")
                self.process.kill()
                return
            time.sleep(0.1)

    def wait_for(self, expected):
        deadline = time.monotonic() + 5
        while True:
            line = self.events.get(timeout=max(0.01, deadline - time.monotonic()))
            assert line is not None and line != "HOST DEADLINE OR RSS LIMIT", self.lines
            if line == expected:
                return

    def __enter__(self):
        return self

    def __exit__(self, kind, value, traceback):
        try:
            if kind is None:
                assert self.process.wait(timeout=5) == 0, self.lines
                self.reader.join(timeout=5)
                assert "DIRECT PASS" in self.lines and "live bundled ownership: PASS" in self.lines, self.lines
                leaves = [index for index, line in enumerate(self.lines) if line.startswith("LEAVE ")]
                closed = [(index, line) for index, line in enumerate(self.lines) if line.startswith("CLOSED ")]
                assert [line for _, line in closed] == [f"CLOSED {slot}" for slot in range(self.workers)], self.lines
                assert all(index > max(leaves) for index, _ in closed), self.lines
                assert [json.loads(line) for line in Path(str(self.prefix) + "-direct").read_text().splitlines()] == [{"id": 9, "name": "Cara"}]
        finally:
            if self.process.poll() is None:
                self.process.kill()
            self.process.wait()
            self.reader.join(timeout=5)
            self.monitor.join(timeout=5)
            self.process.stdout.close()
            self.errors.seek(0)
            error_text = self.errors.read()
            self.errors.close()
            if error_text:
                print(error_text, flush=True)
            print("\n".join(self.lines), flush=True)

    def peer(self, stack):
        peer = Peer(self.port)
        stack.callback(peer.close)
        return peer

    def records(self):
        return [json.loads(line) for slot in range(self.workers) for line in Path(f"{self.prefix}-store-{slot}").read_text().splitlines()]

    def audit_bytes(self):
        return b"".join(Path(f"{self.prefix}-audit-{slot}").read_bytes() for slot in range(self.workers))

    def final(self, completed, rejected=0):
        expected = {"limit": self.workers, "busy": 0, "mask": 0, "completed": completed, "rejected": rejected}
        self.wait_for("FINAL " + json.dumps(expected, separators=(",", ":")))


def routes(command, prefix):
    with Server(command, prefix, 1, 3) as server, ExitStack() as stack:
        server.wait_for("READY")
        peer = server.peer(stack)
        cases = [
            ("GET", "/health", b"", "", 200, b'{"ok":true}'),
            ("GET", "/users/7", b"", "Bearer alice", 200, b'{"id":7,"name":"Alice"}'),
            ("GET", "/users/me", b"", "Bearer bob", 200, b'{"id":8,"name":"Bob"}'),
            ("POST", "/users", b'{"name":"Cara"}', "Bearer alice", 201, b'{"id":9,"name":"Cara"}'),
            ("GET", "/users/9", b"", "Bearer alice", 200, b'{"id":9,"name":"Cara"}'),
            ("POST", "/users", b"not JSON", "", 401, b""),
            ("GET", "/alias", b"", "Bearer bob", 200, b'{"id":8,"name":"Bob"}'),
            ("POST", "/echo", bytes(range(256)) * 16, "Bearer alice", 200, bytes(range(256)) * 16),
            ("HEAD", "http://example.test/users/%37?tag=a&tag=b", b"", "Bearer alice", 200, b'{"id":7,"name":"Alice"}'),
            ("GET", "/users/m%65", b"", "Bearer bob", 200, b'{"id":8,"name":"Bob"}'),
            ("GET", "/missing", b"", "Bearer alice", 404, b'{"error":"not found"}'),
            ("POST", "/users", b'{"name":"Cara","name":"Other"}', "Bearer alice", 400, b'{"error":"invalid input"}'),
        ]
        for method, path, body, token, status, expected in cases:
            peer.send(method, path, body, token)
            headers = peer.response(status, expected, head=method == "HEAD")
            if status == 201:
                assert headers.get("location") == "/users/9", headers
        assert peer.reader.read(1) == b"", "400 response did not close today's transport connection"
        pipelined = server.peer(stack)
        pipelined.send("GET", "/health", token="")
        pipelined.send("GET", "/users/me", token="Bearer bob")
        pipelined.send("POST", "/echo", b"\0\x80\xff", close=True)
        pipelined.response(200, b'{"ok":true}')
        pipelined.response(200, b'{"id":8,"name":"Bob"}')
        pipelined.response(200, b"\0\x80\xff")
        assert pipelined.reader.read(1) == b""
        fragmented = server.peer(stack)
        body = b'{"name":"Dana"}' + b" " * (1024 - len(b'{"name":"Dana"}'))
        head = f"POST /users HTTP/1.1\r\nHost: localhost\r\nContent-Length: {len(body)}\r\nContent-Type: application/json\r\nAuthorization: Bearer alice\r\nConnection: close\r\n\r\n".encode()
        for piece in (head[:19], head[19:], body[:7], body[7:]):
            fragmented.socket.sendall(piece)
            time.sleep(0.02)
        headers = fragmented.response(201, b'{"id":10,"name":"Dana"}')
        assert headers.get("location") == "/users/10", headers
        assert fragmented.reader.read(1) == b""
        server.final(16)
        assert server.records() == [{"id": 9, "name": "Cara"}, {"id": 10, "name": "Dana"}]
        assert server.audit_bytes() == b"attempt\n" * 6


def exhaustion(command, prefix):
    with Server(command, prefix, 2, 4) as server, ExitStack() as stack:
        server.wait_for("READY")
        alice = server.peer(stack)
        bob = server.peer(stack)
        alice.send("GET", "/users/me", close=True, **{"x-hold": "yes", "x-order": "store-first"})
        bob.send("GET", "/users/me", token="Bearer bob", close=True, **{"x-hold": "yes"})
        entered = set()
        while len(entered) < 2:
            line = server.events.get(timeout=5)
            assert line is not None, server.lines
            if line.startswith("ENTER "):
                entered.add(line)
        assert entered == {"ENTER 0", "ENTER 1"}
        overflow = server.peer(stack)
        overflow.send("POST", "/users", b'{"name":"Cara"}', close=True)
        overflow.response(503, b"")
        control = server.peer(stack)
        server.wait_for("LISTENER CLOSED")
        control.capacity({"limit": 2, "busy": 2, "mask": 3, "completed": 0, "rejected": 1})
        assert not any(line.startswith("CLOSED ") for line in server.lines), server.lines
        assert server.records() == [] and server.audit_bytes() == b""
        control.send("POST", "/_release")
        control.response(204, b"")
        alice.response(200, b'{"id":7,"name":"Alice"}')
        bob.response(200, b'{"id":8,"name":"Bob"}')
        control.capacity({"limit": 2, "busy": 0, "mask": 0, "completed": 2, "rejected": 1})
        control.send("POST", "/echo", b"\0\x80\xff")
        control.response(200, b"\0\x80\xff")
        control.send("GET", "/health", close=True)
        control.response(200, b'{"ok":true}')
        server.final(4, 1)
        assert server.records() == [] and server.audit_bytes() == b"attempt\n"


def failed_write(command, prefix, dependency):
    modes = {"store_mode": "r"} if dependency == "store" else {"audit_mode": "r"}
    with Server(command, prefix, 1, 1, **modes) as server, ExitStack() as stack:
        server.wait_for("READY")
        peer = server.peer(stack)
        peer.send("POST", "/users", b'{"name":"Cara"}')
        peer.response(500, b'{"error":"internal error"}')
        peer.send("GET", "/users/9")
        peer.response(404, b'{"error":"not found"}')
        peer.send("GET", "/users/me", token="Bearer bob")
        peer.response(200, b'{"id":8,"name":"Bob"}')
        peer.send("POST", "/users", b'{"name":"Cara"}')
        peer.response(500, b'{"error":"internal error"}')
        peer.capacity({"limit": 1, "busy": 0, "mask": 0, "completed": 4, "rejected": 0})
        peer.send("GET", "/health", close=True)
        peer.response(200, b'{"ok":true}')
        server.final(5)
        assert server.records() == []
        assert server.audit_bytes() == (b"attempt\n" * 2 if dependency == "store" else b"seed\n")


def main():
    with tempfile.TemporaryDirectory(prefix="camber-live-") as directory:
        temp = Path(directory)
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            executable = temp / ("live_check" + suffix)
            _, rss, seconds = guarded(["bend", ROOT / "camber/live_check.bend", "-o", executable], 120)
            print(f"{lane} build: {seconds:.3f}s; sampled compiler RSS {rss / 1024:.2f} MiB", flush=True)
            command = [executable] if lane == "native" else ["bun", executable]
            for name, check in (("routes", routes), ("exhaustion", exhaustion)):
                check(command, temp / f"{lane}-{name}")
                print(f"{lane}/{name}: PASS", flush=True)
            for dependency in ("store", "audit"):
                failed_write(command, temp / f"{lane}-failed-{dependency}", dependency)
                print(f"{lane}/failed-{dependency}: PASS", flush=True)


if __name__ == "__main__":
    main()
