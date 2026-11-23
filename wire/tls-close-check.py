#!/usr/bin/env python3
"""Check complete TLS sends and the bounded close drain with session tickets."""
import os
from pathlib import Path
import runpy
import ssl
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent
fixtures = runpy.run_path(str(ROOT.parent / "stream/check.py"))
DATA = b"0123456789abcdef" * 16


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "native"
    assert target in ("native", "js")
    with tempfile.TemporaryDirectory(prefix="bend-tls-close-") as directory:
        tmp = Path(directory)
        binary = tmp / ("close.js" if target == "js" else "close")
        subprocess.run(("bend", "tls_close_check.bend", "-o", str(binary)), cwd=ROOT, check=True)
        command = ("bun", str(binary)) if target == "js" else (str(binary),)
        context = fixtures["certificates"](tmp)
        assert context.num_tickets > 0
        environment = dict(os.environ, SSL_CERT_FILE=str(tmp / "ca.pem"))
        for mode in ("eof", "stall", "flood"):
            def receive(peer, server):
                while True:
                    block = peer.recv(4096)
                    if not block:
                        break
                    server.received.extend(block)
                assert bytes(server.received) == DATA, (mode, len(server.received))
                if mode == "eof":
                    peer.unwrap().close()
                elif mode == "stall":
                    time.sleep(0.75)
                else:
                    until = time.monotonic() + 0.75
                    try:
                        while time.monotonic() < until:
                            peer.sendall(b"x" * 4096)
                    except (OSError, ssl.SSLError):
                        pass

            server = fixtures["Server"](context, receive)
            try:
                with subprocess.Popen((*command, str(server.port)), env=environment,
                                      stdout=subprocess.PIPE, text=True) as process:
                    assert process.stdout.readline().strip() == "closing"
                    started = time.monotonic()
                    try:
                        status = process.wait(timeout=5)
                    finally:
                        if process.poll() is None:
                            process.kill()
                    elapsed = time.monotonic() - started
                    assert status == 0, status
                    assert process.stdout.read().strip() == "closed"
                    assert elapsed < 0.65, (mode, elapsed)
                    if mode == "stall":
                        assert elapsed >= 0.15, (mode, elapsed)
            finally:
                server.finish()
            print(f"TLS close {mode}: exact payload, close {elapsed:.3f}s")


if __name__ == "__main__":
    main()
