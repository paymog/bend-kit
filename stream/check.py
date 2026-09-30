#!/usr/bin/env python3
"""Compile and exercise real local binary file/TCP/verified-TLS transfers."""
import argparse
import errno
import os
from pathlib import Path
import signal
import socket
import ssl
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parent
DATA = bytes((i * 73 + 255) % 256 for i in range(259)) + b"\x00\xff\x01"


def certificates(tmp):
    def openssl(*args):
        subprocess.run(("openssl", *args), check=True, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE, cwd=tmp)
    openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-subj", "/CN=Stream local CA", "-addext", "basicConstraints=critical,CA:TRUE",
            "-keyout", "ca.key", "-out", "ca.pem")
    openssl("req", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=localhost",
            "-keyout", "server.key", "-out", "server.csr")
    (tmp / "extensions").write_text("subjectAltName=DNS:localhost\nextendedKeyUsage=serverAuth\n")
    openssl("x509", "-req", "-in", "server.csr", "-CA", "ca.pem", "-CAkey", "ca.key",
            "-CAcreateserial", "-days", "1", "-extfile", "extensions", "-out", "server.pem")
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(tmp / "server.pem", tmp / "server.key")
    return context


class Server:
    def __init__(self, context, action):
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(1)
        self.listener.settimeout(15)
        self.port = self.listener.getsockname()[1]
        self.errors = []
        self.received = bytearray()
        self.context = context
        self.action = action
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()

    def serve(self):
        try:
            with self.listener:
                peer, _ = self.listener.accept()
                peer.settimeout(10)
                if self.context:
                    peer = self.context.wrap_socket(peer, server_side=True, suppress_ragged_eofs=False)
                with peer:
                    self.action(peer, self)
        except BaseException as error:
            self.errors.append(error)

    def finish(self):
        self.thread.join(15)
        if self.thread.is_alive():
            raise RuntimeError("local server did not finish")
        if self.errors:
            raise self.errors[0]


def sink(peer, server):
    while True:
        try:
            block = peer.recv(4096)
        except (ConnectionResetError, ssl.SSLEOFError):
            # Wire close is best-effort; exact payload checks still reject lost/extra bytes.
            break
        if not block:
            break
        server.received.extend(block)


def source(data, short=False, abrupt=False, delay=0, stall=False):
    def action(peer, server):
        time.sleep(delay)
        try:
            if short:
                for byte in data:
                    peer.sendall(bytes((byte,)))
                    time.sleep(0.01)  # Many successful short reads, not EOF.
            else:
                peer.sendall(data)
            if stall:
                assert peer.recv(1) == b""
            elif abrupt:
                time.sleep(0.15)  # Let the complete prefix reach the consumer first.
                os.close(peer.detach())  # TCP EOF without a TLS close_notify.
            elif server.context:
                peer.unwrap().close()  # Real close_notify, never suppress verification.
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
            # Cap/invalid-chunk/deadline cases deliberately stop receiving early.
            if not server.allow_early_close:
                raise
    return action


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=("native", "js"), default="native")
    options = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="bend-stream-check-") as directory:
        tmp = Path(directory)
        binary = tmp / ("live.js" if options.target == "js" else "live")
        subprocess.run(("bend", "live.bend", "-o", str(binary)), cwd=ROOT, check=True)
        command = ("bun", str(binary)) if options.target == "js" else (str(binary),)
        context = certificates(tmp)
        environment = dict(os.environ, SSL_CERT_FILE=str(tmp / "ca.pem"))
        src, dst = tmp / "source.bin", tmp / "output.bin"
        src.write_bytes(DATA)

        def execute(kind, tls=False, port=0, chunk=64, cap=len(DATA), ms=1000,
                    mode=None, expected=("Complete", len(DATA)), preexec_fn=None):
            path = dst if kind == "recv" else src
            result = subprocess.run((*command, kind, "tls" if tls else "plain",
                                     str(path), str(dst), mode or ("r" if kind == "send" else "w"),
                                     str(port), str(chunk), str(cap), str(ms)),
                                    env=environment, cwd=ROOT, check=True, text=True,
                                    capture_output=True, timeout=15, preexec_fn=preexec_fn)
            lines = result.stdout.splitlines()
            fields = lines[0].split()
            assert (fields[0], int(fields[1])) == expected, result.stdout
            if fields[0] in ("Read", "Write"):
                assert int(fields[2]) != 0 and len(fields) > 3, result.stdout
            return lines, fields

        def file_case(data, chunk, cap, expected, output, rest, mode="w"):
            src.write_bytes(data)
            if mode == "r":
                dst.write_bytes(b"")
            lines, fields = execute("file", chunk=chunk, cap=cap, expected=expected, mode=mode)
            assert dst.read_bytes() == output
            assert lines[1] == "Next " + rest[:16].hex(), lines
            if expected[0] == "Write":
                assert int(fields[2]) == errno.EBADF, fields

        file_case(DATA, 3, len(DATA), ("Complete", len(DATA)), DATA, b"")
        file_case(DATA, 64, 100, ("Limit", 100), DATA[:100], DATA[101:])
        file_case(DATA, 64, 0, ("Limit", 0), b"", DATA[1:])
        file_case(b"", 64, 0, ("Complete", 0), b"", b"")
        for chunk in (0, 1048577):
            file_case(DATA, chunk, len(DATA), ("BadChunk", 0), b"", DATA)
        file_case(DATA, 64, len(DATA), ("Write", 0), b"", DATA[64:], mode="r")
        file_case(DATA, 1, 1048576, ("Complete", len(DATA)), DATA, b"")
        file_case(DATA, 1048576, len(DATA), ("Complete", len(DATA)), DATA, b"")
        file_case(DATA, 64, 4294967295, ("Complete", len(DATA)), DATA, b"")
        if os.name == "posix":
            import resource
            def limited_file():
                signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
                resource.setrlimit(resource.RLIMIT_FSIZE, (100, 100))
            src.write_bytes(DATA)
            lines, fields = execute("file", chunk=64, expected=("Write", 64),
                                    preexec_fn=limited_file)
            assert int(fields[2]) == errno.EFBIG, fields
            assert dst.read_bytes() == DATA[:100]
            assert lines[1] == "Next " + DATA[128:144].hex(), lines
            print("partial-write EFBIG: count 64, actual output 100 bytes")
        src.write_bytes(DATA)

        def receive(tls, data, expected, output, chunk=64, cap=None, ms=1000,
                    short=False, abrupt=False, delay=0, mode="w", stall=False):
            server = Server(context if tls else None, source(data, short, abrupt, delay, stall))
            server.allow_early_close = expected[0] != "Complete"
            try:
                lines, fields = execute("recv", tls, server.port, chunk,
                                        len(data) if cap is None else cap, ms,
                                        expected=expected, mode=mode)
            finally:
                server.finish()
            assert dst.read_bytes() == output
            if expected[0] == "Limit":
                assert lines[1] == "Next " + data[(cap or 0) + 1:(cap or 0) + 2].hex(), lines
            if expected[0] == "BadChunk":
                assert lines[1] == "Next " + data[:1].hex(), lines
            return fields

        for tls in (False, True):
            for data, chunk, cap, expected, offset in (
                (DATA, 64, 100, ("Limit", 100), 101),
                (DATA, 64, 0, ("Limit", 0), 1),
                (b"", 64, 0, ("Complete", 0), 0),
                (DATA, 0, len(DATA), ("BadChunk", 0), 0),
                (DATA, 1048577, len(DATA), ("BadChunk", 0), 0),
            ):
                src.write_bytes(data)
                server = Server(context if tls else None, sink)
                try:
                    lines, _ = execute("send", tls, server.port, chunk, cap, expected=expected)
                finally:
                    server.finish()
                assert bytes(server.received) == data[:expected[1]]
                assert lines[1] == "Next " + data[offset:offset + 16].hex(), lines
            src.write_bytes(DATA)
            server = Server(context if tls else None, sink)
            try:
                lines, fields = execute("send", tls, server.port, mode="w", expected=("Read", 0))
            finally:
                server.finish()
            assert int(fields[2]) == errno.EBADF and not server.received, fields
            assert lines[1].startswith("NextError " + str(errno.EBADF) + " "), lines
            src.write_bytes(DATA)
            server = Server(context if tls else None, sink)
            try:
                execute("send", tls, server.port)
            finally:
                server.finish()
            assert bytes(server.received) == DATA
            receive(tls, bytes(server.received), ("Complete", len(DATA)), DATA)
            receive(tls, DATA[:17], ("Complete", 17), DATA[:17], short=True, ms=0)
            receive(tls, DATA[:17], ("Complete", 17), DATA[:17], short=True, ms=100)
            receive(tls, DATA, ("Limit", 100), DATA[:100], cap=100)
            receive(tls, DATA, ("Limit", 0), b"", cap=0)
            receive(tls, b"", ("Complete", 0), b"", cap=0)
            for chunk in (0, 1048577):
                receive(tls, DATA, ("BadChunk", 0), b"", chunk=chunk)
            fields = receive(tls, b"", ("Read", 0), b"", ms=50, delay=0.5)
            assert int(fields[2]) == errno.ETIMEDOUT, fields
            for cap in (len(DATA), 17):
                fields = receive(tls, DATA[:17], ("Read", 17), DATA[:17],
                                 cap=cap, ms=50, stall=True)
                assert int(fields[2]) == errno.ETIMEDOUT, fields
            dst.write_bytes(b"")
            receive(tls, DATA, ("Write", 0), b"", cap=len(DATA), mode="r")
            print(("TLS" if tls else "TCP") + " binary roundtrip/cap/short-read/deadline checks ok")
        receive(True, DATA[:17], ("Read", 17), DATA[:17], abrupt=True, cap=len(DATA))
        print("TLS abrupt EOF preserves 17-byte count and structured Read error")
        print("stream live checks ok; binary contents and counts match")


if __name__ == "__main__":
    main()
