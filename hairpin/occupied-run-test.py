#!/usr/bin/env python3
"""Check live reservations, child failures, and cleanup."""
from pathlib import Path
import subprocess
import sys

runner = Path(__file__).with_name("occupied-run.py")
probe = """
import errno
import socket
for port in range(47830, 47838):
    with socket.socket() as listener:
        try:
            listener.bind(("127.0.0.1", port))
        except OSError as error:
            assert error.errno == errno.EADDRINUSE, error
        else:
            raise AssertionError(f"port {port} was not occupied")
"""
subprocess.run([sys.executable, runner, sys.executable, "-c", probe], check=True)
assert subprocess.run([sys.executable, runner, sys.executable, "-c", "raise SystemExit(7)"]).returncode == 7
subprocess.run([sys.executable, runner, sys.executable, "-c", probe], check=True)
print("PASS occupied-port harness: all eight live reservations, exit status, and cleanup")
