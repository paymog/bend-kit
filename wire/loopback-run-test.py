#!/usr/bin/env python3
"""Check client forwarding, firewall rollback, and the live OS boundary."""
import errno
import json
import os
from pathlib import Path
import runpy
import socket
import subprocess
import sys
import uuid
from unittest.mock import patch

RUNNER = Path(__file__).with_name("loopback-run.py")


def forwarding():
    env = {**os.environ, "WIRE_LOOPBACK_ONLY": "0", "LOOPBACK_TEST": "space = value"}
    args = ["", "two words", "a=b", "--flag"]
    code = "import json,os,sys; print(json.dumps([sys.argv[1:],os.environ['LOOPBACK_TEST']])); sys.exit(23)"
    result = subprocess.run([sys.executable, str(RUNNER), sys.executable, "-c", code, *args],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 23, result
    assert json.loads(result.stdout) == [args, env["LOOPBACK_TEST"]], result
    print("PASS disabled arguments, environment, and child status")


def rollback(failure, live=False):
    real_run = subprocess.run
    host_env = dict(os.environ)
    installed = []
    calls = []
    child = []
    rules = [
        ["sudo", "iptables", "-w", "-I", "OUTPUT", "!", "-d", "127.0.0.0/8",
         "-m", "owner", "--uid-owner", "0", "-j", "REJECT", "--reject-with", "icmp-host-prohibited"],
        ["sudo", "ip6tables", "-w", "-I", "OUTPUT", "!", "-d", "::1/128",
         "-m", "owner", "--uid-owner", "0", "-j", "REJECT", "--reject-with", "icmp6-adm-prohibited"],
    ]

    def run(command, **kwargs):
        calls.append(command)
        if command[1] in ("iptables", "ip6tables"):
            assert kwargs == {"check": True}, kwargs
            rule = [*command[:3], "-I", *command[4:]]
            if command[3] == "-I":
                assert rule == rules[len(installed)], command
                if failure == command[1]:
                    raise subprocess.CalledProcessError(31, command)
                if live:
                    real_run(command, check=True, env=host_env)
                installed.append(rule)
            else:
                assert command[3] == "-D", command
                if live:
                    real_run(command, check=True, env=host_env)
                assert rule == installed.pop(), command
            return subprocess.CompletedProcess(command, 0)
        assert command[:2] == ["sudo", "/usr/bin/env"], command
        assert installed == rules, installed
        assert command[2:-3] == [f"{k}={v}" for k, v in os.environ.items()], command
        assert command[-3:] == [sys.executable, "two words", ""], command
        child.append(command)
        if failure == "spawn":
            raise OSError("injected client start failure")
        return subprocess.CompletedProcess(command, 23 if failure == "client" else 0)

    env = {"WIRE_LOOPBACK_ONLY": "1", "LOOPBACK_TEST": "space = value"}
    with patch.dict(os.environ, env, clear=True), patch.object(sys, "platform", "linux"), \
            patch.object(sys, "argv", [str(RUNNER), sys.executable, "two words", ""]), \
            patch("subprocess.run", side_effect=run):
        try:
            runpy.run_path(str(RUNNER), run_name="__main__")
        except subprocess.CalledProcessError as error:
            assert failure in ("iptables", "ip6tables") and error.returncode == 31
        except OSError:
            assert failure == "spawn"
        except SystemExit as error:
            assert failure in ("success", "client")
            assert error.code == (23 if failure == "client" else 0), error
        else:
            raise AssertionError("runner did not propagate the result")
    assert not installed, installed
    assert len(child) == (0 if failure in ("iptables", "ip6tables") else 1), child
    assert len(calls) == {"iptables": 1, "ip6tables": 3}.get(failure, 5), calls
    print(f"PASS Linux {'live ' if live else ''}rollback: {failure}")


def denied(address):
    family = socket.AF_INET6 if ":" in address else socket.AF_INET
    with socket.socket(family, socket.SOCK_STREAM) as client:
        client.settimeout(3)
        try:
            client.connect((address, 443))
        except OSError as error:
            assert error.errno in (errno.EPERM, errno.EACCES, errno.EHOSTUNREACH), error
            print(f"PASS policy denial: {address} errno={error.errno}")
        else:
            raise AssertionError(f"connection escaped isolation: {address}")


def policy():
    if sys.platform == "linux":
        def snapshot():
            return [subprocess.run(["sudo", tool, "-w", "-S", "OUTPUT"], check=True,
                                   capture_output=True, text=True).stdout
                    for tool in ("iptables", "ip6tables")]

        before = snapshot()
        for failure in ("success", "iptables", "ip6tables", "client", "spawn"):
            rollback(failure, live=True)
            assert snapshot() == before, f"firewall rules changed after {failure}"
    address = "2001:db8::" + uuid.uuid4().hex[:4]
    route = ["sudo", "ip", "-6", "route"]
    if sys.platform == "linux":
        # A local route reaches OUTPUT even on runners without an IPv6 default route.
        subprocess.run([*route, "add", address + "/128", "dev", "lo"], check=True)
    try:
        env = {**os.environ, "WIRE_LOOPBACK_ONLY": "1"}
        subprocess.run([sys.executable, str(RUNNER), sys.executable, str(Path(__file__).resolve()),
                        "--client", "1.1.1.1", address], env=env, check=True, timeout=15)
    finally:
        if sys.platform == "linux":
            subprocess.run([*route, "del", address + "/128", "dev", "lo"], check=True)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--client"]:
        for address in sys.argv[2:]:
            denied(address)
    else:
        forwarding()
        for failure in ("success", "iptables", "ip6tables", "client", "spawn"):
            rollback(failure)
        if sys.argv[1:] == ["--policy"]:
            policy()
