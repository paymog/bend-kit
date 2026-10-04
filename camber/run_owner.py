#!/usr/bin/env python3
"""Scoped package gate plus native/JS owner acceptance; one Bend process at a time."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def run(args, timeout=120):
    if shutil.disk_usage(ROOT).free < 10 * 1024**3:
        raise RuntimeError("less than 10 GiB disk headroom")
    print("$", " ".join(map(str, args)), flush=True)
    with tempfile.TemporaryFile(mode="w+") as output:
        process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        started = time.monotonic()
        peak = 0
        try:
            while process.poll() is None:
                snapshot = subprocess.check_output(["ps", "-axo", "pid=,ppid=,rss="], text=True)
                rows = [tuple(map(int, line.split())) for line in snapshot.splitlines()]
                members = {process.pid}
                while True:
                    expanded = members | {pid for pid, parent, rss in rows if parent in members}
                    if expanded == members:
                        break
                    members = expanded
                for pid, parent, rss in rows:
                    if pid in members:
                        peak = max(peak, rss)
                        if rss > 20 * 1024**2:
                            raise RuntimeError("RSS exceeds 20 GiB")
                if time.monotonic() - started > timeout:
                    raise RuntimeError("command timed out")
                time.sleep(0.1)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
        output.seek(0)
        text = output.read()
    print(text, end="")
    print(f"exit={process.returncode} peak_rss_kib={peak}", flush=True)
    journals = [line.removeprefix("JOURNAL ") for line in text.splitlines() if line.startswith("JOURNAL ")]
    try:
        if process.returncode:
            raise RuntimeError("command failed")
        for journal in journals:
            path = Path(journal)
            seen = []
            for slot in range(2):
                a = Path(f"{path}-a-{slot}").read_text()
                b = Path(f"{path}-b-{slot}").read_text()
                assert a == b, "bundle resources disagree about principal/order"
                seen.extend(a.splitlines())
            assert sorted(seen) == ["10", "12", "7", "8"], seen
            assert text.splitlines().count("PARTIAL CLOSED") == 1
            assert text.splitlines().count("CLOSED 0") == 2
            assert text.splitlines().count("CLOSED 1") == 3
            assert "camber owner: PASS" in text
            print("journals/explicit closes: PASS", flush=True)
    finally:
        for journal in journals:
            for file in Path(journal).parent.glob(Path(journal).name + "-*"):
                file.unlink()
    return text


def main():
    run(["bash", "scripts/check.sh", "camber"])
    with tempfile.TemporaryDirectory(prefix="camber-owner-build-") as temp:
        native = str(Path(temp) / "owner")
        js = native + ".js"
        run(["bend", "camber/check.bend", "-o", native])
        run([native])
        run(["bend", "camber/check.bend", "-o", js])
        run(["bun", js])
    print("owner native/JS acceptance: PASS")


if __name__ == "__main__":
    main()
