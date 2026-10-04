#!/usr/bin/env python3
"""Real native/JS accepts, affine reuse, boundaries, port zero and release."""
import json
from pathlib import Path
import queue
import shutil
import socket
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]


def descendants(pid):
    rows = subprocess.run(["ps", "-axo", "pid=,ppid=,rss="],
                          capture_output=True, text=True, check=True).stdout.splitlines()
    entries = [tuple(map(int, row.split())) for row in rows if len(row.split()) == 3]
    owned = {pid}
    while True:
        more = {child for child, parent, rss in entries if parent in owned}
        if more <= owned:
            break
        owned |= more
    return owned, sum(rss for child, parent, rss in entries if child in owned)


def launch(command):
    assert shutil.disk_usage(ROOT).free > 10 * 1024**3, "need 10 GiB disk headroom"
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    lines = queue.Queue()
    output = []
    receipt = {"command": list(map(str, command)), "peak_descendant_rss_kib": 0,
               "observed_pids": [process.pid]}
    def read_lines():
        for line in process.stdout:
            output.append(line.rstrip())
            lines.put(line.rstrip())
    reader = threading.Thread(target=read_lines)
    reader.start()
    def monitor():
        until = time.monotonic() + 120
        while process.poll() is None:
            owned, rss = descendants(process.pid)
            receipt["observed_pids"] = sorted(set(receipt["observed_pids"]) | owned)
            receipt["peak_descendant_rss_kib"] = max(receipt["peak_descendant_rss_kib"], rss)
            if rss > 20 * 1024**2 or time.monotonic() > until:
                receipt["limit_exceeded"] = True
                for pid in owned:
                    try:
                        subprocess.run(["kill", "-KILL", str(pid)], capture_output=True)
                    except ProcessLookupError:
                        pass
                break
            time.sleep(0.05)
    watcher = threading.Thread(target=monitor)
    watcher.start()
    return process, lines, output, receipt, reader, watcher


def finish(job):
    process, lines, output, receipt, reader, watcher = job
    try:
        process.wait(timeout=125)
    finally:
        if process.poll() is None:
            owned, rss = descendants(process.pid)
            for pid in owned:
                subprocess.run(["kill", "-KILL", str(pid)], capture_output=True)
            process.wait()
        reader.join()
        watcher.join()
        alive = subprocess.run(["ps", "-o", "pid=", "-p",
                                ",".join(map(str, receipt["observed_pids"]))],
                               capture_output=True, text=True).stdout.split()
        receipt["live_observed_pids_after_exit"] = alive
        receipt.update(exit_code=process.returncode, output=output,
                       process_reaped=True)
        print(json.dumps(receipt), flush=True)
    assert process.returncode == 0 and not receipt.get("limit_exceeded"), receipt
    assert not receipt["live_observed_pids_after_exit"], receipt
    return receipt


def listener_port(pid):
    result = subprocess.run(["lsof", "-nP", "-a", "-p", str(pid), "-iTCP",
                             "-sTCP:LISTEN", "-Fn"], capture_output=True, text=True)
    names = [line[1:] for line in result.stdout.splitlines() if line.startswith("n")]
    assert len(names) == 1, (result.returncode, result.stdout, result.stderr)
    return int(names[0].rsplit(":", 1)[1])


def scenario(command, mode):
    # Every case binds port zero: discover the actual listener, never self-connect
    # merely to wake shutdown. This also avoids a reserve/rebind port race.
    job = launch([*command, mode, "0"])
    process, lines, output, receipt, reader, watcher = job
    peer = None
    try:
        assert lines.get(timeout=10) == "READY"
        port = listener_port(process.pid)
        def connect():
            nonlocal peer
            peer = socket.create_connection(("127.0.0.1", port), timeout=5)
        if mode in ("queued", "maximum", "port-zero"):
            connect()
        assert lines.get(timeout=10) == "BEGIN"
        if mode == "delayed":
            time.sleep(0.1)
            connect()
        results, elapsed = [], []
        while True:
            line = lines.get(timeout=10)
            if line == "CONNECT":
                connect()
            elif line.startswith("ELAPSED "):
                elapsed.append(float(line.split()[1]))
            elif line.startswith(("FAIL ", "DONE ")):
                results.append(line)
            elif line == "BLOCKER_DONE":
                pass
            elif line == "CLOSED_LISTENER":
                break
            else:
                raise AssertionError(line)
        if peer is not None:
            assert peer.recv(1) == b"", "accepted handle did not close"
            peer.close()
            peer = None
        receipt = finish(job)
        job = None
        timeout = "FAIL 60" if __import__("sys").platform == "darwin" else "FAIL 110"
        expected = {"repeat": [timeout, timeout, "DONE CLOSED_SOCKET"],
                    "invalid": ["FAIL 22"] * 3 + ["DONE CLOSED_SOCKET"],
                    "empty": [timeout], "minimum": [timeout],
                    "scheduling": [timeout]}.get(mode, ["DONE CLOSED_SOCKET"])
        assert results == expected, (mode, results, expected)
        if mode in ("repeat", "empty"):
            assert all(30 <= value < 500 for value in elapsed[:2]), elapsed
        if mode == "delayed":
            assert 70 <= elapsed[0] < 1000, elapsed
        # Rebind the exact released address with no retry and observe no child.
        with socket.socket() as rebound:
            rebound.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            rebound.bind(("127.0.0.1", port))
            rebound.listen()
        owned, rss = descendants(process.pid)
        assert rss == 0, (owned, rss)
        receipt.update(scenario=mode, port=port, results=results, elapsed_ms=elapsed,
                       listener_rebind=True, descendant_rss_after_exit_kib=rss)
        return receipt
    finally:
        if peer is not None:
            peer.close()
        if job is not None:
            finish(job)


def main():
    rows = []
    with tempfile.TemporaryDirectory(prefix="wire-accept-") as directory:
        for lane, suffix in (("native", ""), ("js", ".js")):
            target = str(Path(directory) / ("accept" + suffix))
            finish(launch(["bend", str(ROOT / "wire/accept_deadline.bend"), "-o", target]))
            command = [target] if lane == "native" else ["bun", target]
            for mode in ("minimum", "empty", "queued", "delayed", "repeat", "invalid", "maximum", "port-zero", "scheduling"):
                row = {"lane": lane, **scenario(command, mode)}
                rows.append(row)
                print(json.dumps(row), flush=True)
    print(json.dumps({"acceptance": rows}, indent=2))


if __name__ == "__main__":
    main()
