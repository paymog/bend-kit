#!/usr/bin/env python3
"""Restrict acceptance clients, not builds or RSS supervision."""
import os
import shutil
import subprocess
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
        rules = []
        try:
            for tool, address, reject in (("iptables", "127.0.0.0/8", "icmp-host-prohibited"),
                                          ("ip6tables", "::1/128", "icmp6-adm-prohibited")):
                rule = ["OUTPUT", "!", "-d", address, "-m", "owner",
                        "--uid-owner", "0", "-j", "REJECT", "--reject-with", reject]
                subprocess.run(["sudo", tool, "-w", "-I", *rule], check=True)
                rules.append((tool, rule))
            # Clients run as root; the runner, fixtures, and builds do not.
            status = subprocess.run(["sudo", "/usr/bin/env",
                                     *(f"{k}={v}" for k, v in os.environ.items()),
                                     *command]).returncode
        finally:
            for tool, rule in reversed(rules):
                subprocess.run(["sudo", tool, "-w", "-D", *rule], check=True)
        raise SystemExit(status)
    else:
        raise SystemExit("Loopback isolation requires Linux or macOS")
os.execvp(command[0], command)
