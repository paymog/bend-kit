#!/usr/bin/env python3
"""Keep the former acceptance ports occupied until the child exits."""
from contextlib import ExitStack
import socket
import subprocess
import sys

with ExitStack() as sockets:
    for port in range(47830, 47838):
        listener = sockets.enter_context(socket.socket())
        listener.bind(("127.0.0.1", port))
        listener.listen()
    raise SystemExit(subprocess.run(sys.argv[1:]).returncode)
