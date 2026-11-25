#!/usr/bin/env python3
"""Observe lifecycle risks without treating current failures as desired behavior."""
import argparse
import json
import platform
import queue
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from datetime import date
from pathlib import Path

from run_dispatch import ENV, ROOT, RSS_LIMIT_KIB, guarded
from run_owner import ready_ports


def observe(command, path, interaction=None, *, timeout_seconds=12):
    events, notifications, peak = [], queue.Queue(), [0]
    started = time.monotonic()
    stop = threading.Event()
    supervision = []
    with tempfile.TemporaryFile(mode="w+t") as errors:
        process = subprocess.Popen(command, cwd=ROOT, env=ENV, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=errors, text=True)

        def reader():
            for line in process.stdout:
                event = {"seconds": time.monotonic() - started, "text": line.rstrip("\n")}
                events.append(event)
                notifications.put(event)

        def monitor():
            while not stop.is_set() and process.poll() is None:
                rss = subprocess.run(["ps", "-o", "rss=", "-p", str(process.pid)],
                                     capture_output=True, text=True, timeout=3)
                if rss.stdout.strip():
                    peak[0] = max(peak[0], int(rss.stdout))
                reason = "rss_limit" if peak[0] > RSS_LIMIT_KIB else "host_deadline" if time.monotonic() - started > timeout_seconds else None
                if reason:
                    supervision.append(reason)
                    process.kill()
                    return
                stop.wait(.05)

        def wait_for(prefix):
            deadline = time.monotonic() + min(8, timeout_seconds)
            while True:
                event = notifications.get(timeout=max(.01, deadline - time.monotonic()))
                if event["text"].startswith(prefix):
                    return event
                if time.monotonic() >= deadline:
                    raise TimeoutError((prefix, events))

        threads = [threading.Thread(target=reader, daemon=True), threading.Thread(target=monitor, daemon=True)]
        for thread in threads:
            thread.start()
        details = {}
        try:
            if interaction:
                details = interaction(process, wait_for)
            code = process.wait(timeout=timeout_seconds + 1)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=3)
            stop.set()
            for thread in threads:
                thread.join(timeout=4)
            process.stdout.close()
        errors.seek(0)
        stderr = errors.read()
    if supervision:
        raise RuntimeError((supervision, events, stderr))
    return {"returncode": code, "wall_seconds": time.monotonic() - started,
            "sampled_peak_rss_kib": peak[0], "events": events, "stderr": stderr,
            "journal": path.read_text() if path.exists() else None,
            "unrelated_journal": Path(str(path) + ".unrelated").read_text() if Path(str(path) + ".unrelated").exists() else None,
            **details}


def event_time(result, prefix):
    return next((event["seconds"] for event in result["events"] if event["text"].startswith(prefix)), None)


def work_seconds(record):
    values = next(event["text"].split()[1:] for event in record["events"]
                  if event["text"].startswith("WORK_TIME\t"))
    return int(values[0]) + int(values[1]) / 1e9


def inspect_failed_send_close(path):
    def interact(process, wait_for):
        closed = wait_for("AFFINE_RESULT_CLOSED")
        wait_for("INSPECT_OPEN_FILES")
        assert process.poll() is None, "process exited before descriptor inspection"
        listing = subprocess.run([shutil.which("lsof"), "-a", "-p", str(process.pid), "-Fn"],
                                 capture_output=True, text=True, timeout=5)
        assert listing.returncode == 0 and process.poll() is None, listing.stderr
        target = "n" + str(path)
        observed = [line for line in listing.stdout.splitlines() if line == target]
        return {"failed_send_resource_explicitly_closed": True,
                "failed_send_close_seconds": closed["seconds"],
                "file_descriptor_remains_open_after_explicit_close": bool(observed),
                "descriptor_evidence": observed, "descriptor_listing": listing.stdout,
                "descriptor_inspection_returncode": listing.returncode,
                "process_alive_before_descriptor_inspection": True,
                "process_alive_after_descriptor_inspection": True}
    return interact


def idle_connection():
    def interact(process, wait_for):
        port, = ready_ports(wait_for("READY ")["text"])
        with socket.create_connection(("127.0.0.1", port), timeout=3) as peer:
            closed = wait_for("LISTENER CLOSED")
            try:
                extra = socket.create_connection(("127.0.0.1", port), timeout=.2)
            except ConnectionRefusedError:
                accepts_stopped = True
            else:
                extra.close()
                accepts_stopped = False
            time.sleep(6.25)
            remains = process.poll() is None
            peer.settimeout(.1)
            try:
                socket_closed = peer.recv(1) == b""
            except socket.timeout:
                socket_closed = False
        return {"listener_close_seconds": closed["seconds"], "new_connections_rejected": accepts_stopped,
                "observation_seconds_after_listener_close": 6.25,
                "process_alive_before_client_release": remains, "idle_socket_closed_before_client_release": socket_closed}
    return interact


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("/tmp/camber-design-risks-current.json"))
    args = parser.parse_args()
    if shutil.which("lsof") is None:
        raise RuntimeError("lsof is required to observe actual File-descriptor ownership")
    results = {"date": date.today().isoformat(), "platform": platform.platform(), "timer_delay_ms": 100, "forced_timer_budget_ms": 100,
               "forced_operation": "IO.die(Unit, 1, ...)", "host_deadline_seconds": 12, "rss_limit_kib": RSS_LIMIT_KIB, "lanes": {}}
    results["bend"] = guarded(["bend", "version"], 20)[0].strip()
    target = args.output
    with tempfile.TemporaryDirectory(prefix="camber-design-risks-") as directory:
        temp = Path(directory).resolve()
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            binary = temp / ("risk-probe" + suffix)
            _, rss, seconds = guarded(["bend", str(ROOT / "camber/risk_probe.bend"), "-o", str(binary)], 180)
            command = [str(binary), "+RTS", "--threads", "1", "--gpu", "off", "-RTS"] if lane == "native" else ["bun", str(binary)]
            data = {"build_seconds": seconds, "sampled_build_peak_rss_kib": rss, "cases": {}}
            calibrations = []
            data["cpu_calibration"] = calibrations
            results["lanes"][lane] = data
            chosen = None
            for count in (10000, 250000, 1000000, 8000000, 32000000, 128000000, 512000000):
                path = temp / f"{lane}-cpu-{count}"
                record = observe(command + ["cpu_only", str(path), str(count), "0"], path)
                calibrations.append({"iterations": count, **record})
                target.write_text(json.dumps(results, indent=2) + "\n")
                assert record["returncode"] == 0, record
                duration = work_seconds(record)
                calibrations[-1]["internal_work_seconds"] = duration
                chosen = count
                if duration >= .3:
                    break
            if duration < .3:
                raise RuntimeError(f"{lane}: CPU fixture never reached the 300 ms calibration floor")
            data["selected_iterations"] = chosen
            for mode in ("yield_exit", "cpu_exit", "cooperative", "abandoned", "idle"):
                path = temp / f"{lane}-{mode}"
                interaction = None
                if mode == "abandoned":
                    interaction = inspect_failed_send_close(path)
                if mode == "idle":
                    interaction = idle_connection()
                record = observe(command + [mode, str(path), str(chosen), "0"], path, interaction)
                data["cases"][mode] = record
                target.write_text(json.dumps(results, indent=2) + "\n")
                if mode in ("yield_exit", "cpu_exit"):
                    assert record["returncode"] == 1, record
                    requested = event_time(record, "TIMER_ARMED")
                    forced = event_time(record, "FORCE_PROGRAM_HALT")
                    assert requested is not None and forced is not None, record
                    record["timer_to_force_seconds"] = forced - requested
                    record["force_within_scaled_budget"] = forced - requested <= .2
                    record["explicit_resource_close_observed"] = event_time(record, "OWNED_FILE_CLOSED") is not None
                    record["unrelated_work_completed"] = event_time(record, "UNRELATED_DONE") is not None
                else:
                    assert record["returncode"] == 0, record
                if mode == "abandoned":
                    assert record["journal"] == "committed\n", record
                    assert not record["file_descriptor_remains_open_after_explicit_close"], record
                    assert event_time(record, "SERVER_WORK_DONE") is not None, record
                if mode == "cooperative":
                    assert record["journal"] == "committed\n" and record["unrelated_journal"] == "unrelated completed\n", record
                    assert event_time(record, "COOPERATIVE_RETURN") < event_time(record, "OWNED_FILE_CLOSED") < event_time(record, "UNRELATED_DONE"), record
                target.write_text(json.dumps(results, indent=2) + "\n")
                print(f"{lane}/{mode}: observed", flush=True)
    target.write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps({lane: {mode: {key: value for key, value in record.items() if key in
          ("timer_to_force_seconds", "force_within_scaled_budget", "explicit_resource_close_observed", "unrelated_work_completed",
           "failed_send_resource_explicitly_closed", "file_descriptor_remains_open_after_explicit_close",
           "new_connections_rejected", "process_alive_before_client_release",
           "idle_socket_closed_before_client_release")} for mode, record in data["cases"].items()}
          for lane, data in results["lanes"].items()}, indent=2))


if __name__ == "__main__":
    main()
