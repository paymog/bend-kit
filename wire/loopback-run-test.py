#!/usr/bin/env python3
"""Check client forwarding, firewall rollback, and the live OS boundary."""
import contextlib
import errno
import io
import json
import os
from pathlib import Path
import runpy
import socket
import signal
import subprocess
import sys
import threading
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
    real_popen = subprocess.Popen
    host_env = dict(os.environ)
    installed = []
    children = []
    timer = None
    errors = io.StringIO()
    cleanup_failures = []
    rules = [
        ["sudo", "iptables", "-w", "-I", "OUTPUT", "!", "-d", "127.0.0.0/8",
         "-m", "owner", "--uid-owner", "0", "-j", "REJECT", "--reject-with", "icmp-host-prohibited"],
        ["sudo", "ip6tables", "-w", "-I", "OUTPUT", "!", "-d", "::1/128",
         "-m", "owner", "--uid-owner", "0", "-j", "REJECT", "--reject-with", "icmp6-adm-prohibited"],
    ]
    interrupted = failure in ("sigterm", "sigint", "spawn-signal", "signal-cleanup")
    code = ("import time; print('ready', flush=True); time.sleep(60)" if interrupted
            else f"import sys; sys.exit({23 if 'client' in failure else 0})")

    def host_run(command):
        with patch("subprocess.Popen", real_popen):
            return real_run(command, check=True, env=host_env)

    def run(command, **kwargs):
        if command[1] == "kill":
            assert interrupted and command[2:4] == ["-KILL", "--"], command
            return host_run(command if live else command[1:])
        assert command[1] in ("iptables", "ip6tables"), command
        assert kwargs == {"check": True}, kwargs
        rule = [*command[:3], "-I", *command[4:]]
        if command[3] == "-I":
            assert rule == rules[len(installed)], command
            if failure == command[1] or (failure == "setup-cleanup" and command[1] == "ip6tables"):
                raise subprocess.CalledProcessError(31, command)
            if live:
                host_run(command)
            installed.append(rule)
        else:
            assert command[3] == "-D", command
            tool = command[1]
            fail_delete = (failure in (f"delete-{tool}", f"persistent-{tool}", "delete-both")
                           or failure.endswith("-cleanup"))
            if fail_delete and (tool not in cleanup_failures or failure == f"persistent-{tool}"):
                cleanup_failures.append(tool)
                raise subprocess.CalledProcessError(32, command)
            if failure == "signal-cleanup":
                os.kill(os.getpid(), signal.SIGTERM)
            if live:
                host_run(command)
            assert rule in installed, command
            installed.remove(rule)
        return subprocess.CompletedProcess(command, 0)

    def popen(command, **kwargs):
        nonlocal timer
        assert kwargs == {"start_new_session": True}, kwargs
        assert command[:2] == ["sudo", "/usr/bin/env"], command
        assert installed == rules, installed
        assert command[2:-3] == [f"{k}={v}" for k, v in os.environ.items()], command
        assert command[-3:] == [sys.executable, "-c", code], command
        if failure in ("spawn", "spawn-cleanup"):
            raise OSError("injected client start failure")
        child = real_popen(command if live else command[-3:], start_new_session=True,
                           stdout=subprocess.PIPE, text=True, env=host_env)
        children.append(child)
        if interrupted:
            assert child.stdout.readline().strip() == "ready"
            number = signal.SIGINT if failure == "sigint" else signal.SIGTERM
            if failure == "spawn-signal":
                os.kill(os.getpid(), number)
            else:
                timer = threading.Timer(0.1, os.kill, args=(os.getpid(), number))
                timer.start()
        return child

    env = {"WIRE_LOOPBACK_ONLY": "1", "LOOPBACK_TEST": "space = value"}
    with patch.dict(os.environ, env, clear=True), patch.object(sys, "platform", "linux"), \
            patch.object(sys, "argv", [str(RUNNER), sys.executable, "-c", code]), \
            patch("subprocess.run", side_effect=run), patch("subprocess.Popen", side_effect=popen), \
            contextlib.redirect_stderr(errors):
        try:
            runpy.run_path(str(RUNNER), run_name="__main__")
        except subprocess.CalledProcessError as error:
            assert failure in ("iptables", "ip6tables", "setup-cleanup") and error.returncode == 31
        except OSError as error:
            assert failure in ("spawn", "spawn-cleanup") and str(error) == "injected client start failure"
        except SystemExit as error:
            expected = (130 if failure == "sigint" else 143) if interrupted else (
                23 if "client" in failure else (1 if cleanup_failures else 0))
            assert error.code == expected, (failure, error)
        else:
            raise AssertionError("runner did not propagate the result")
    if timer is not None:
        timer.join()
    for child in children:
        assert child.poll() is not None, failure
        try:
            os.waitpid(child.pid, os.WNOHANG)
        except ChildProcessError:
            pass
        else:
            raise AssertionError("client was not reaped")
        child.stdout.close()
    assert installed == [rule for rule in rules if failure == f"persistent-{rule[1]}"], installed
    assert len(children) == (0 if failure in ("iptables", "ip6tables", "setup-cleanup",
                                            "spawn", "spawn-cleanup") else 1), children
    assert errors.getvalue().count("loopback cleanup failed:") == len(cleanup_failures), errors.getvalue()
    print(f"PASS Linux {'live ' if live else ''}rollback: {failure}")


FAILURES = ("success", "iptables", "ip6tables", "client", "spawn", "delete-ip6tables",
            "delete-iptables", "delete-both", "setup-cleanup", "client-cleanup", "spawn-cleanup",
            "sigterm", "sigint", "spawn-signal", "signal-cleanup")


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
        for failure in FAILURES:
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
        for failure in (*FAILURES, "persistent-ip6tables", "persistent-iptables"):
            rollback(failure)
        if sys.argv[1:] == ["--policy"]:
            policy()
