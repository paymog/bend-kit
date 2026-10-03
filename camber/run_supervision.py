#!/usr/bin/env python3
"""Test OS termination of a dedicated process, not embedded Bend cancellation."""
import json
import platform
import signal
import socket
import tempfile
import threading
import time
from datetime import date
from pathlib import Path

from run_dispatch import ROOT, guarded
from run_risks import event_time, observe


def interrupt(path, port):
    def interact(process, wait_for):
        peer = None
        worker = None
        parent_path = Path(str(path) + ".parent")
        try:
            if port:
                wait_for("READY")
                peer = socket.create_connection(("127.0.0.1", port), timeout=2)
                wait_for("LISTENER CLOSED")
            else:
                wait_for("WORK_BEGIN")
            ready = time.monotonic()

            def unrelated_parent_work():
                time.sleep(.5)
                parent_path.write_text("unrelated parent work completed\n")

            worker = threading.Thread(target=unrelated_parent_work)
            worker.start()
            time.sleep(.1)
            alive_before_signal = process.poll() is None
            requested = time.monotonic()
            process.kill()
            process.wait(timeout=1)
            reaped = time.monotonic()
            socket_closed = None
            if peer:
                peer.settimeout(1)
                try:
                    socket_closed = peer.recv(1) == b""
                except ConnectionResetError:
                    socket_closed = True
                except socket.timeout:
                    socket_closed = False
            worker.join(timeout=1)
            return {"child_alive_before_signal": alive_before_signal,
                    "ready_to_signal_seconds": requested - ready,
                    "signal_to_reap_seconds": reaped - requested,
                    "within_scaled_teardown_budget": reaped - requested <= .1,
                    "idle_socket_closed_after_termination": socket_closed,
                    "parent_journal": parent_path.read_text() if parent_path.exists() else None}
        finally:
            if peer:
                peer.close()
            if worker:
                worker.join(timeout=1)
    return interact


def main():
    prior = json.loads((ROOT / "camber/design_risk_results.json").read_text())
    results = {"date": date.today().isoformat(), "platform": platform.platform(),
               "bend": guarded(["bend", "version"], 20)[0].strip(),
               "bun": guarded(["bun", "--version"], 20)[0].strip(),
               "boundary": "Python parent supervising a dedicated Bend child; not embedded cancellation",
               "signal": "SIGKILL", "pre_signal_delay_ms": 100, "forced_teardown_budget_ms": 100,
               "inspected_runtime_source_revision": "7d8a3eb036042c6549461054d25a10f26d361c5c", "lanes": {}}
    target = ROOT / "camber/supervision_risk_results.json"
    with tempfile.TemporaryDirectory(prefix="camber-supervision-") as directory:
        temp = Path(directory)
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            binary = temp / ("probe" + suffix)
            _, rss, seconds = guarded(["bend", ROOT / "camber/risk_probe.bend", "-o", binary], 180)
            command = [str(binary), "--threads", "1", "--gpu", "off"] if lane == "native" else ["bun", str(binary)]
            data = {"build_seconds": seconds, "sampled_build_peak_rss_kib": rss,
                    "reused_cpu_iterations": prior["lanes"][lane]["selected_iterations"], "cases": {}}
            results["lanes"][lane] = data
            for mode in ("external_cpu", "idle"):
                port = 0
                if mode == "idle":
                    with socket.socket() as reservation:
                        reservation.bind(("127.0.0.1", 0))
                        port = reservation.getsockname()[1]
                path = temp / (lane + "-" + mode)
                record = observe(command + [mode, str(path), str(data["reused_cpu_iterations"]), str(port)],
                                 path, interrupt(path, port))
                data["cases"][mode] = record
                target.write_text(json.dumps(results, indent=2) + "\n")
                assert record["child_alive_before_signal"] and record["returncode"] == -signal.SIGKILL, record
                assert record["parent_journal"] == "unrelated parent work completed\n", record
                assert record["journal"] == "committed\n", record
                assert event_time(record, "OWNED_FILE_CLOSED") is None, record
                if mode == "external_cpu":
                    assert event_time(record, "WORK_END") is None, "CPU fixture completed before external stop"
                print(f"{lane}/{mode}: signal-to-reap {record['signal_to_reap_seconds'] * 1000:.3f} ms; "
                      f"socket_closed={record['idle_socket_closed_after_termination']}", flush=True)


if __name__ == "__main__":
    main()
