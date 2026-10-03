#!/usr/bin/env python3
"""Observe response progress and real Wire timeout delivery beside CPU work."""
import concurrent.futures
import json
import platform
import socket
import statistics
import tempfile
import time
from datetime import date

from run_dispatch import ROOT, guarded
from run_live import Peer
from run_risks import event_time, observe


def interact(port, body, status, response, first_ready, ordinary_delay):
    def run(process, wait_for):
        partial = ordinary = cpu = None
        details = {}
        try:
            wait_for("READY")
            partial = socket.create_connection(("127.0.0.1", port), timeout=5)
            partial.sendall(b"GET /partial HTTP/1.1\r\n")
            armed = wait_for(first_ready)
            cpu = Peer(port)
            body_sent = time.monotonic()
            cpu.send("POST" if body else "GET", "/cpu", body=body, token="", close=True)
            wait_for("CPU_ARMED")
            details["host_body_send_to_work_armed_seconds"] = time.monotonic() - body_sent
            ordinary = Peer(port)
            beginning = wait_for("CPU_BEGIN")
            anchor = time.monotonic()
            details.update(first_ready_prefix=first_ready, first_ready_event_seconds=armed["seconds"],
                           cpu_begin_event_seconds=beginning["seconds"])

            def request():
                time.sleep(ordinary_delay)
                sent = time.monotonic()
                ordinary.send("GET", "/ordinary", token="")
                ordinary.response(200, b"ok")
                details["ordinary_response_exact"] = True
                received = time.monotonic()
                return {"ordinary_sent_after_cpu_seen_seconds": sent - anchor,
                        "ordinary_response_after_cpu_seen_seconds": received - anchor,
                        "ordinary_latency_seconds": received - sent}

            def expired():
                partial.settimeout(5)
                try:
                    data = partial.recv(1)
                    outcome = "eof" if data == b"" else "data"
                except ConnectionResetError:
                    outcome = "reset"
                except socket.timeout:
                    outcome = "host_socket_timeout"
                return {"partial_peer_outcome": outcome,
                        "partial_close_after_cpu_seen_seconds": time.monotonic() - anchor}

            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                ordinary_result = pool.submit(request)
                deadline_result = pool.submit(expired)
                cpu.response(status, response)
                details["workload_response_exact"] = True
                details["cpu_response_after_cpu_seen_seconds"] = time.monotonic() - anchor
                details.update(ordinary_result.result(timeout=6))
                details.update(deadline_result.result(timeout=6))
            recovered = time.monotonic()
            ordinary.send("GET", "/recovery", token="", close=True)
            ordinary.response(200, b"ok")
            details["recovery_latency_seconds"] = time.monotonic() - recovered
            details["recovery_response_exact"] = True
        except Exception as error:
            details["interaction_error"] = repr(error)
        finally:
            for peer in (ordinary, cpu):
                if peer is not None:
                    peer.close()
            if partial is not None:
                partial.close()
        return details
    return run


def classify(record):
    begin, end = event_time(record, "CPU_BEGIN"), event_time(record, "CPU_END")
    armed = event_time(record, "DEADLINE_ARMED")
    closed = event_time(record, "DEADLINE_CLOSED")
    handled = event_time(record, "ORDINARY_HANDLED")
    record.update(cpu_work_seconds=end - begin if end is not None and begin is not None else None,
                  ordinary_handler_before_cpu_end=handled < end if handled is not None and end is not None else None,
                  observed_read_arm_to_close_seconds=closed - armed if closed is not None and armed is not None else None,
                  raw_read_failed=event_time(record, "DEADLINE_READ_FAILED") is not None)


def main():
    prior = json.loads((ROOT / "camber/design_risk_results.json").read_text())
    results = {"date": date.today().isoformat(), "platform": platform.platform(),
               "bend": guarded(["bend", "version"], 20)[0].strip(),
               "bun": guarded(["bun", "--version"], 20)[0].strip(),
               "configured_wire_read_timeout_ms": 200, "ordinary_send_delay_ms": 25,
               "cpu_release_delay_ms": 50, "host_deadline_seconds": 12,
               "scope": "Finite HTTP transport plus a separate real Wire timed read; not absolute HTTP phase deadlines or a production server",
               "lanes": {}}
    target = ROOT / "camber/progress_results.json"
    with tempfile.TemporaryDirectory(prefix="camber-progress-") as directory:
        from pathlib import Path
        temp = Path(directory)
        for backend, suffix in (("native", ""), ("javascript", ".js")):
            binary = temp / ("progress" + suffix)
            _, rss, seconds = guarded(["bend", ROOT / "camber/progress_probe.bend", "-o", binary], 180)
            variants = (("native_single", [str(binary), "--threads", "1", "--gpu", "off"]),
                        ("native_default_threads", [str(binary), "--gpu", "off"])) if backend == "native" else (("javascript", ["bun", str(binary)]),)
            for name, command in variants:
                lane = {"runtime_arguments": command[1:] if backend == "native" else ["bun", "<compiled-js>"],
                        "build_seconds": seconds, "sampled_build_peak_rss_kib": rss, "cases": []}
                results["lanes"][name] = lane
                for mode, count, trials in (("small", 10000, 1), ("yield", 0, 3),
                                             ("cpu", prior["lanes"][backend]["selected_iterations"], 3)):
                    for trial in range(trials):
                        with socket.socket() as reservation:
                            reservation.bind(("127.0.0.1", 0))
                            port = reservation.getsockname()[1]
                        record = observe(command + [mode, str(count), str(port)], temp / "unused",
                                         interact(port, b"", 200, b"cpu", "DEADLINE_ARMED", .025))
                        record.update(mode=mode, iterations=count, trial=trial)
                        classify(record)
                        lane["cases"].append(record)
                        target.write_text(json.dumps(results, indent=2) + "\n")
                        assert record["returncode"] == 0 and "interaction_error" not in record, record
                        assert record["recovery_response_exact"], record
                        assert record["raw_read_failed"] and record["partial_peer_outcome"] == "eof", record
                        print(f"{name}/{mode}/{trial}: ordinary={record['ordinary_latency_seconds'] * 1000:.3f} ms; "
                              f"read-close={record['observed_read_arm_to_close_seconds'] * 1000:.3f} ms; "
                              f"CPU={record['cpu_work_seconds'] * 1000:.3f} ms", flush=True)
                lane["summary"] = {mode: {"median_ordinary_ms": statistics.median(case["ordinary_latency_seconds"] * 1000 for case in lane["cases"] if case["mode"] == mode),
                                          "median_read_arm_to_close_ms": statistics.median(case["observed_read_arm_to_close_seconds"] * 1000 for case in lane["cases"] if case["mode"] == mode),
                                          "median_cpu_ms": statistics.median(case["cpu_work_seconds"] * 1000 for case in lane["cases"] if case["mode"] == mode)}
                                   for mode in ("small", "yield", "cpu")}
                target.write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
