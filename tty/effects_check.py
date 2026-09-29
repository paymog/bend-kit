#!/usr/bin/env python3
"""Exercise native and Bun tty effects against pipes and a sized pseudo-terminal."""
import errno
import fcntl
import os
import pty
import struct
import subprocess
import tempfile
import termios
from pathlib import Path

HERE = Path(__file__).resolve().parent


def run(argv, tty=False, no_color=False, zero_size=False):
    env = os.environ.copy()
    env.pop("NO_COLOR", None)
    if no_color:
        env["NO_COLOR"] = ""
    if not tty:
        return subprocess.run(argv, cwd=HERE, env=env, capture_output=True, check=True).stdout.decode()
    master, slave = pty.openpty()
    try:
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 0 if zero_size else 24, 0 if zero_size else 80, 0, 0))
        child = subprocess.Popen(argv, cwd=HERE, env=env, stdout=slave, stderr=subprocess.PIPE)
        os.close(slave)
        slave = -1
        out = bytearray()
        while True:
            try:
                chunk = os.read(master, 4096)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
            if not chunk:
                break
            out.extend(chunk)
        assert child.wait(timeout=30) == 0, child.stderr.read().decode()
        return out.decode()
    finally:
        os.close(master)
        if slave >= 0:
            os.close(slave)


def main():
    with tempfile.TemporaryDirectory() as temporary:
        native = str(Path(temporary) / "native")
        js = str(Path(temporary) / "check.js")
        subprocess.run(["bend", "check.bend", "-o", native], cwd=HERE, check=True)
        subprocess.run(["bend", "check.bend", "-o", js], cwd=HERE, check=True)
        for lane, argv in (("C", [native]), ("JS", ["bun", js])):
            redirected = run(argv)
            assert "terminal=no size=unavailable color=no" in redirected, (lane, redirected)
            assert "automatic=red" in redirected and "\x1b[" not in redirected, (lane, redirected)
            enabled = run(argv, tty=True)
            assert "terminal=yes size=80x24 color=yes" in enabled, (lane, enabled)
            assert "automatic=\x1b[31mred\x1b[0m" in enabled, (lane, enabled)
            disabled = run(argv, tty=True, no_color=True)
            assert "terminal=yes size=80x24 color=no" in disabled, (lane, disabled)
            assert "automatic=red" in disabled and "automatic=\x1b[" not in disabled, (lane, disabled)
            unknown = run(argv, tty=True, zero_size=True)
            assert "terminal=yes size=unavailable color=yes" in unknown, (lane, unknown)
            print(f"ok {lane}: pipe, PTY 80x24, unavailable size, NO_COLOR")


if __name__ == "__main__":
    main()
