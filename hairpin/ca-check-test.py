#!/usr/bin/env python3
"""Check CA harness command boundaries, failures, and fixture cleanup offline."""
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time

HARNESS = Path(__file__).with_name("ca-check.sh")
STUB = r'''
import json, os, pathlib, socket, sys, tempfile, time
root = pathlib.Path(os.environ["CA_TEST_ROOT"])
args = sys.argv[1:]
name = pathlib.Path(sys.argv[0]).name
failure = os.environ["CA_TEST_FAILURE"]
def record(kind, *values):
    with (root / "events").open("a") as f:
        f.write(json.dumps([kind, os.environ.get("CA_TEST_RESTRICTED", "0"), *values]) + "\n")
if name == "mktemp":
    directory = tempfile.mkdtemp(prefix="ca fixture ", dir=root)
    record("temporary", directory)
    print(directory)
elif name == "openssl":
    record("certificate", *args)
elif name == "bend":
    record("compile", *args)
    output = pathlib.Path(args[args.index("-o") + 1])
    output.write_text(pathlib.Path(__file__).read_text())
    output.chmod(0o755)
elif name == "sleep":
    time.sleep(0.01)
elif name == "python3":
    target = pathlib.Path(args[0]).name
    if target == "loopback-run.py":
        record("restriction", *args[1:])
        os.environ["CA_TEST_RESTRICTED"] = "1"
        os.execvp(args[1], args[1:])
    assert target == "server.py", args
    record("fixture", os.getpid(), *args[1:])
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen()
    port = listener.getsockname()[1]
    (root / "fixture").write_text(json.dumps([os.getpid(), port]))
    if failure not in ("startup", "interrupt"):
        pathlib.Path(args[3]).write_text(str(port) + "\n")
    while True:
        time.sleep(1)
elif name == "bun":
    record("bun", *args)
    os.execv(sys.executable, [sys.executable, *args])
else:
    check = name.removesuffix(".js")
    record("client", check, *args)
    sys.exit(23 if failure == check else 0)
'''


def events(root):
    path = root / "events"
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def run_case(lane, failure, harness=HARNESS):
    with tempfile.TemporaryDirectory(prefix="hairpin CA test ") as directory:
        root = Path(directory)
        commands = root / "bin"
        commands.mkdir()
        stub = commands / "stub"
        stub.write_text(f"#!{sys.executable}\n" + STUB)
        stub.chmod(0o755)
        for command in ("mktemp", "openssl", "bend", "sleep", "python3", "bun"):
            (commands / command).symlink_to(stub)
        env = {**os.environ, "PATH": str(commands) + os.pathsep + os.environ["PATH"],
               "CA_TEST_ROOT": directory, "CA_TEST_FAILURE": failure,
               "WIRE_LOOPBACK_ONLY": "1"}
        env.pop("CA_TEST_RESTRICTED", None)
        process = subprocess.Popen(["sh", str(harness), lane], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                   start_new_session=True)
        fixture = None
        try:
            if failure == "interrupt":
                deadline = time.monotonic() + 5
                while not (root / "fixture").exists():
                    assert process.poll() is None, "harness exited before fixture startup"
                    assert time.monotonic() < deadline, "fixture did not start"
                    time.sleep(0.01)
                process.send_signal(signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=10)
            calls = events(root)
            assert process.returncode == 0 if failure == "success" else process.returncode != 0, (failure, stdout, stderr)
            temporary = [Path(call[2]) for call in calls if call[0] == "temporary"]
            assert len(temporary) == 1, calls
            assert not temporary[0].exists(), f"temporary directory leaked: {temporary[0]}"
            clients = [call[2] for call in calls if call[0] == "client"]
            expected = {
                "success": ["loopback", "ca_check", "ca_stream_check"],
                "loopback": ["loopback"], "ca_check": ["loopback", "ca_check"],
                "ca_stream_check": ["loopback", "ca_check", "ca_stream_check"],
                "startup": ["loopback"], "interrupt": ["loopback"],
            }[failure]
            assert clients == expected, calls
            restricted = [call for call in calls if call[0] == "restriction"]
            assert len(restricted) == len(expected), calls
            for call, check in zip(restricted, expected):
                command = call[2:]
                if lane == "js":
                    assert command.pop(0) == "bun", call
                assert Path(command[0]).name == check + (".js" if lane == "js" else ""), call
                if check != "loopback":
                    assert command[1] == str(temporary[0] / "ca.pem"), call
                    assert command[2].startswith("https://localhost:"), call
            assert all(call[1] == ("1" if call[0] in ("client", "bun") else "0") for call in calls), calls
            compilations = [call[2:] for call in calls if call[0] == "compile"]
            assert [call[0] for call in compilations] == ["ca_check.bend", "ca_stream_check.bend", "../wire/loopback_check.bend"], calls
            fixture_calls = [call for call in calls if call[0] == "fixture"]
            assert len(fixture_calls) == (0 if failure == "loopback" else 1), calls
            if fixture_calls:
                fixture = json.loads((root / "fixture").read_text())
                pid, port = fixture
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    raise AssertionError(f"fixture was not stopped and reaped: {pid}")
                with socket.socket() as listener:
                    listener.bind(("127.0.0.1", port))
            print(f"PASS {lane}: {failure}")
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
            if (root / "fixture").exists():
                pid, _ = json.loads((root / "fixture").read_text())
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass


if __name__ == "__main__":
    for lane in ("native", "js"):
        for failure in ("success", "loopback", "ca_check", "ca_stream_check", "startup", "interrupt"):
            run_case(lane, failure)
