#!/usr/bin/env python3
"""Restrict acceptance clients, not builds or RSS supervision."""
import os
import shutil
import sys

command = sys.argv[1:]
command[0] = shutil.which(command[0]) or command[0]
if os.environ.get("WIRE_LOOPBACK_ONLY") == "1":
    if sys.platform == "darwin":
        command = ["sandbox-exec", "-p", """(version 1)
(allow default)
(deny network-outbound)
(allow network-outbound (remote ip "localhost:*"))
""", *command]
    elif sys.platform == "linux":
        command = ["sudo", "systemd-run", "--scope", "--quiet",
                   "-p", "IPAddressDeny=any", "-p", "IPAddressAllow=localhost",
                   "--", "/usr/bin/env", *(f"{k}={v}" for k, v in os.environ.items()),
                   *command]
    else:
        raise SystemExit("Loopback isolation requires Linux or macOS")
os.execvp(command[0], command)
