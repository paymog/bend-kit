#!/usr/bin/env python3
"""One guarded Bend command at a time, plus real loopback response receipts."""
from pathlib import Path
import socket
import tempfile
from run_owner import run, run_live


def live(command):
    def clients(port):
        for index in range(43):
            connection = socket.create_connection(("127.0.0.1", port), timeout=5)
            with connection:
                connection.settimeout(5)
                chunks = []
                while True:
                    chunk = connection.recv(4096)
                    if not chunk:
                        break
                    chunks.append(chunk)
            received = b"".join(chunks)
            if index < 21:
                assert received == b"", (index, received)
            elif index < 42:
                assert received.startswith(b"HTTP/1.1 500"), received
                assert received.count(b"HTTP/1.1 ") == 1, received
                head, body = received.split(b"\r\n\r\n", 1)
                assert body == b"", received
                assert b"private" not in received and b"secret" not in received, received
                assert b"x-status:" not in head and b"\r\nx:" not in head, received
            else:
                assert received.startswith(b"HTTP/1.1 200"), received
                assert received.count(b"set-cookie: a=1\r\n") == 1, received
                assert received.count(b"set-cookie: b=2\r\n") == 1, received
                assert received.endswith(b"\r\n\r\nok"), received

    output = run_live(command, clients, timeout=60)
    assert output.count("EXPECTED InvalidResponse NO WRITE") == 21, output
    assert output.count("EXPECTED SAFE MAPPED500 WRITE") == 21, output
    assert "live response safety: PASS" in output, output
    print("21 plain invalid outputs: zero bytes; 21 routed outputs: one safe mapped500; distinct Set-Cookie: PASS", flush=True)


def main():
    run(["bash", "scripts/check.sh", "camber"])
    run(["bash", "scripts/publish.sh", "--check", "camber"])
    with tempfile.TemporaryDirectory(prefix="camber-response-") as temp:
        for source in ("dispatch_check", "response_check", "scoped_check", "response_live"):
            for extension in ("", ".js"):
                target = str(Path(temp) / (source + extension))
                run(["bend", f"camber/{source}.bend", "-o", target])
                command = [target] if not extension else ["bun", target]
                if source == "response_live":
                    live(command)
                else:
                    run(command)
    print("response native/JS acceptance: PASS")


if __name__ == "__main__":
    main()
