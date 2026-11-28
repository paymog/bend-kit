#!/usr/bin/env python3
"""Restrict acceptance clients, not builds or RSS supervision."""
import os
import shutil
import signal
import subprocess
import sys


def linux(command):
    rules = []
    client = None
    status = 1
    errors = []
    pending = None
    signals = (signal.SIGINT, signal.SIGTERM)

    def interrupt(number, frame):
        nonlocal pending
        pending = number

    handlers = {number: signal.signal(number, interrupt) for number in signals}
    try:
        try:
            # Defer interruption until the new rule or client is recorded.
            for tool, address, reject in (("iptables", "127.0.0.0/8", "icmp-host-prohibited"),
                                          ("ip6tables", "::1/128", "icmp6-adm-prohibited")):
                rule = ["OUTPUT", "!", "-d", address, "-m", "owner",
                        "--uid-owner", "0", "-j", "REJECT", "--reject-with", reject]
                subprocess.run(["sudo", tool, "-w", "-I", *rule], check=True)
                rules.append((tool, rule))
                if pending is not None:
                    raise SystemExit(128 + pending)
            # Clients run as root; the runner, fixtures, and builds do not.
            client = subprocess.Popen(["sudo", "/usr/bin/env",
                                       *(f"{k}={v}" for k, v in os.environ.items()),
                                       *command], start_new_session=True)
            while pending is None:
                try:
                    status = client.wait(timeout=0.1)
                    break
                except subprocess.TimeoutExpired:
                    pass
            if pending is not None:
                raise SystemExit(128 + pending)
        finally:
            if client is not None and client.poll() is None:
                try:
                    subprocess.run(["sudo", "kill", "-KILL", "--", f"-{client.pid}"], check=True)
                    client.wait()
                except (OSError, subprocess.SubprocessError) as error:
                    errors.append(error)
            for tool, rule in reversed(rules):
                for attempt in range(2):
                    try:
                        subprocess.run(["sudo", tool, "-w", "-D", *rule], check=True)
                        break
                    except (OSError, subprocess.SubprocessError) as error:
                        errors.append(error)
            for error in errors:
                print(f"loopback cleanup failed: {error}", file=sys.stderr)
    finally:
        for number, handler in handlers.items():
            signal.signal(number, handler)
    return status or bool(errors)


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
        raise SystemExit(linux(command))
    else:
        raise SystemExit("Loopback isolation requires Linux or macOS")
os.execvp(command[0], command)
