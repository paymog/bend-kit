"""Exercise the native streaming demo with bounded and malformed requests."""

import socket
import subprocess
import sys
import time

HOST = "127.0.0.1"
PORT = 18081


def connect():
    return socket.create_connection((HOST, PORT), timeout=10)


def response(reader):
    status = reader.readline().decode("ascii")
    assert status.startswith("HTTP/1.1 "), status
    headers = {}
    while line := reader.readline().decode("ascii").strip():
        name, value = line.split(":", 1)
        headers[name.lower()] = value.strip()
    return int(status.split()[1]), reader.read(int(headers["content-length"]))


def digest(data):
    value = 5381
    for byte in data:
        value = (value * 33 + byte) & 0xFFFFFFFF
    return value


def run():
    payload = bytes(range(251)) * (17 * 1024 * 1024 // 251 + 1)
    payload = payload[: 17 * 1024 * 1024]
    with connect() as sock:
        sock.sendall(b"POST /large HTTP/1.1\r\nHost: x\r\nContent-Length: " + str(len(payload)).encode() + b"\r\n\r\n")
        sock.sendall(payload)
        with sock.makefile("rb") as reader:
            assert response(reader) == (200, f"/large:{len(payload)}:{digest(payload)}".encode())

    with connect() as sock:
        sock.sendall(b"POST /chunk HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n2\r\nde\r\n0\r\n\r\nGET /next HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n")
        with sock.makefile("rb") as reader:
            assert response(reader) == (200, f"/chunk:5:{digest(b'abcde')}".encode())
            assert response(reader) == (200, b"/next:0:5381")

    with connect() as sock:
        sock.sendall(b"POST /discard HTTP/1.1\r\nHost: x\r\nContent-Length: 6\r\n\r\nabc")
        time.sleep(0.05)
        sock.sendall(b"defGET /after HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n")
        with sock.makefile("rb") as reader:
            assert response(reader) == (200, f"/discard:3:{digest(b'abc')}".encode())
            assert response(reader) == (200, b"/after:0:5381")

    for data, expected in (
        (b"POST /too-big HTTP/1.1\r\nHost: x\r\nContent-Length: 33554433\r\n\r\n", 413),
        (b"POST /short HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nabc", 400),
        (b"POST /bad HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n", 400),
    ):
        with connect() as sock:
            sock.sendall(data)
            sock.shutdown(socket.SHUT_WR)
            with sock.makefile("rb") as reader:
                assert response(reader)[0] == expected


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
        print("streaming request smoke passed")
    finally:
        server.terminate()
        server.wait(timeout=5)
