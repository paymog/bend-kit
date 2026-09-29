"""Check that rejected requests receive a complete response before close."""

import socket
import sys
import threading
import time

HOST = "127.0.0.1"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 18080
OVER = int(sys.argv[2]) if len(sys.argv) > 2 else 17825792
OVERSIZED_HEAD = f"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: {OVER}\r\n\r\n".encode()
TAIL = b"x" * (2 * 1024 * 1024)


def receive(sock):
    data = bytearray()
    while chunk := sock.recv(65536):
        data.extend(chunk)
    return bytes(data)


def complete(status, request):
    with socket.create_connection((HOST, PORT), timeout=5) as sock:
        sock.settimeout(5)
        sock.sendall(request)
        wire = receive(sock)
    head, mark, body = wire.partition(b"\r\n\r\n")
    assert mark and head.startswith(f"HTTP/1.1 {status} ".encode()), (status, head[:100])
    assert b"connection: close" in head.lower()
    lengths = [int(line.split(b":", 1)[1].strip()) for line in head.split(b"\r\n") if line.lower().startswith(b"content-length:")]
    assert len(lengths) == 1 and len(body) == lengths[0], (status, lengths, len(body))


def slow_sender():
    head = OVERSIZED_HEAD
    with socket.create_connection((HOST, PORT), timeout=5) as sock:
        sock.settimeout(4)
        sock.sendall(head)
        stop = threading.Event()

        def trickle():
            while not stop.is_set():
                try:
                    sock.sendall(b"x")
                except OSError:
                    break
                time.sleep(0.003)

        sender = threading.Thread(target=trickle)
        sender.start()
        started = time.monotonic()
        wire = bytearray()
        try:
            while True:
                try:
                    piece = sock.recv(65536)
                except ConnectionResetError:
                    break
                if not piece:
                    break
                wire.extend(piece)
            elapsed = time.monotonic() - started
        finally:
            stop.set()
            sender.join(timeout=2)
        head, mark, body = wire.partition(b"\r\n\r\n")
        assert mark and head.startswith(b"HTTP/1.1 413 "), head[:100]
        lengths = [int(line.split(b":", 1)[1].strip()) for line in head.split(b"\r\n") if line.lower().startswith(b"content-length:")]
        assert len(lengths) == 1 and len(body) == lengths[0]
        assert elapsed < 4, "slow sender held a rejected connection too long"


if __name__ == "__main__":
    complete(413, OVERSIZED_HEAD + b"x" * 17825792)
    complete(431, b"GET / HTTP/1.1\r\nHost: x\r\nX-H: " + b"a" * 100000 + b"\r\n\r\n" + TAIL)
    complete(400, b"POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: gzip\r\n\r\n" + TAIL)
    slow_sender()
    print("rejection delivery smoke passed")
