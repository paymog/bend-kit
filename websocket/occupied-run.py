#!/usr/bin/env python3
"""Keep both former WebSocket acceptance ports bound while the child runs."""
from contextlib import ExitStack
import socket
import subprocess
import sys

with ExitStack() as sockets:
    for port in (39461, 39462):
        listener = sockets.enter_context(socket.socket())
        listener.bind(("127.0.0.1", port))
        listener.listen()
    raise SystemExit(subprocess.run(sys.argv[1:]).returncode)
