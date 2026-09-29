"""Check native server response framing, suppression, and connection reuse."""

import socket
import subprocess
import sys
import time

HOST = "127.0.0.1"
PORT = 18082


def connect():
    return socket.create_connection((HOST, PORT), timeout=20)


def request(path, method="GET", close=False):
    return f"{method} {path} HTTP/1.1\r\nHost: x\r\n".encode() + (b"Connection: close\r\n" if close else b"") + b"\r\n"


def response(reader, method="GET"):
    line = reader.readline().decode("ascii")
    assert line.startswith("HTTP/1.1 "), line
    status = int(line.split()[1])
    fields = []
    while line := reader.readline().decode("ascii").strip():
        name, value = line.split(":", 1)
        fields.append((name.lower(), value.strip()))
    headers = dict(fields)
    assert sum(name == "content-length" for name, _ in fields) <= 1
    assert sum(name == "transfer-encoding" for name, _ in fields) <= 1
    assert not ("content-length" in headers and "transfer-encoding" in headers)
    if method == "HEAD" or status < 200 or status in (204, 304):
        return status, headers, b"", []
    if headers.get("transfer-encoding") == "chunked":
        chunks = []
        body = bytearray()
        while size := int(reader.readline().strip(), 16):
            piece = reader.read(size)
            assert len(piece) == size and reader.read(2) == b"\r\n"
            chunks.append(size)
            body.extend(piece)
        assert reader.read(2) == b"\r\n"
        return status, headers, bytes(body), chunks
    body = reader.read(int(headers["content-length"]))
    return status, headers, body, []


def run():
    with connect() as sock:
        sock.sendall(request("/chunked") + request("/known", close=True))
        with sock.makefile("rb") as reader:
            status, headers, body, chunks = response(reader)
            assert (status, headers["transfer-encoding"], body, chunks) == (200, "chunked", b"hello world", [5, 6])
            status, headers, body, chunks = response(reader)
            assert (status, headers["content-length"], body) == (200, "11", b"hello world")
            assert reader.read() == b""

    with connect() as sock:
        sock.sendall(request("/known", "HEAD") + request("/chunked", "HEAD") + request("/known", close=True))
        with sock.makefile("rb") as reader:
            assert response(reader, "HEAD")[:3] == (200, {"content-length": "11"}, b"")
            status, headers, body, _ = response(reader, "HEAD")
            assert (status, headers.get("transfer-encoding"), body) == (200, "chunked", b"")
            assert response(reader)[2] == b"hello world"

    for path, status in (("/none", 204), ("/not-modified", 304), ("/interim", 103)):
        with connect() as sock:
            sock.sendall(request(path, close=True))
            with sock.makefile("rb") as reader:
                got, headers, body, _ = response(reader)
                assert got == status and body == b"" and reader.read() == b""
                assert "content-length" not in headers and "transfer-encoding" not in headers

    for path, expected in (("/short", b"hello world"), ("/over", b"")):
        with connect() as sock:
            sock.sendall(request(path) + request("/known", close=True))
            with sock.makefile("rb") as reader:
                assert response(reader)[2] == expected
                assert reader.read() == b""

    with connect() as sock:
        sock.sendall(request("/large", close=True))
        with sock.makefile("rb") as reader:
            status, headers, body, chunks = response(reader)
            assert status == 200 and len(body) == 17 * 1024 * 1024
            assert chunks == [65536] * 272 and not any(body)
            assert reader.read() == b""


if __name__ == "__main__":
    server = subprocess.Popen([sys.argv[1]], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        for _ in range(100):
            try:
                with connect():
                    break
            except OSError:
                if server.poll() is not None:
                    raise RuntimeError(server.communicate()[1].decode())
                time.sleep(0.05)
        else:
            raise RuntimeError("server did not start")
        run()
        print("response writer smoke passed")
    finally:
        server.terminate()
        server.wait(timeout=5)
