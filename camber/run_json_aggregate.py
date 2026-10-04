#!/usr/bin/env python3
"""Measure a held batch of real JSON bodies; do not infer production admission."""
import concurrent.futures
import errno
import hashlib
import json
import platform
import socket
import statistics
import tempfile
import time
from datetime import date
from pathlib import Path

from run_dispatch import ROOT, RSS_LIMIT_KIB, guarded
from run_json_progress import workloads
from run_live import Peer
from run_risks import event_time, observe

HOST_TIMEOUT = 180


def interact(port, body, count):
    def run(process, wait_for):
        partial = ordinary = None
        peers = []
        details = {}
        try:
            wait_for("READY")
            partial = socket.create_connection(("127.0.0.1", port), timeout=5)
            partial.sendall(b"GET /partial HTTP/1.1\r\n")
            wait_for("PARTIAL_READY")
            loading = time.monotonic()
            for _ in range(count):
                peer = Peer(port)
                peers.append(peer)
                peer.socket.settimeout(HOST_TIMEOUT)
                peer.send("POST", "/cpu", body=body, token="", close=True)
                wait_for("CPU_ARMED")
            details["batch_load_seconds"] = time.monotonic() - loading
            ordinary = Peer(port)
            ordinary.socket.settimeout(HOST_TIMEOUT)
            beginning = wait_for("CPU_BEGIN")
            anchor = time.monotonic()
            details["first_cpu_begin_event_seconds"] = beginning["seconds"]

            def request():
                time.sleep(.001)
                sent = time.monotonic()
                ordinary.send("GET", "/ordinary", token="")
                ordinary.response(200, b"ok")
                received = time.monotonic()
                return {"ordinary_response_exact": True, "ordinary_latency_seconds": received - sent,
                        "ordinary_sent_after_cpu_seen_seconds": sent - anchor,
                        "ordinary_response_after_cpu_seen_seconds": received - anchor}

            def expired():
                partial.settimeout(HOST_TIMEOUT)
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
                completed = 0
                for peer in peers:
                    peer.response(200, b"cpu")
                    completed += 1
                details["exact_workload_responses"] = completed
                details["batch_responses_after_cpu_seen_seconds"] = time.monotonic() - anchor
                details.update(ordinary_result.result(timeout=HOST_TIMEOUT))
                details.update(deadline_result.result(timeout=HOST_TIMEOUT))
            recovered = time.monotonic()
            ordinary.send("GET", "/recovery", token="", close=True)
            ordinary.response(200, b"ok")
            details.update(recovery_response_exact=True, recovery_latency_seconds=time.monotonic() - recovered)
        except Exception as error:
            details["interaction_error"] = repr(error)
        finally:
            for peer in peers + ([ordinary] if ordinary is not None else []):
                peer.close()
            if partial is not None:
                partial.close()
        return details
    return run


def classify(record, count):
    events = record["events"]
    times = [event["text"].split()[1:] for event in events if event["text"].startswith("WORK_TIME\t")]
    work = [int(parts[0]) + int(parts[1]) / 1e9 for parts in times]
    begins = [event["seconds"] for event in events if event["text"] == "CPU_BEGIN"]
    ends = [event["seconds"] for event in events if event["text"] == "CPU_END"]
    armed = event_time(record, "DEADLINE_ARMED")
    closed = event_time(record, "DEADLINE_CLOSED")
    handled = event_time(record, "ORDINARY_HANDLED")
    read_errors = [int(event["text"].split()[1]) for event in events if event["text"].startswith("DEADLINE_READ_FAILED ")]
    record.update(internal_work_seconds=work,
                  work_count=len(work), begin_count=len(begins), end_count=len(ends),
                  sum_internal_work_seconds=sum(work),
                  batch_observed_seconds=max(ends) - min(begins) if begins and ends else None,
                  ordinary_handled_before_last_work_end=handled < max(ends) if handled is not None and ends else None,
                  observed_read_arm_to_close_seconds=closed - armed if closed is not None and armed is not None else None,
                  wire_read_error_codes=read_errors)
    record["exact_behavior_passed"] = (record["returncode"] == 0 and "interaction_error" not in record
        and record.get("exact_workload_responses") == count and record.get("ordinary_response_exact") is True
        and record.get("recovery_response_exact") is True and len(work) == len(begins) == len(ends) == count
        and read_errors == [errno.ETIMEDOUT] and record.get("partial_peer_outcome") == "eof"
        and event_time(record, "SERVER_DONE") is not None)


def main():
    fixtures = {name: body for name, mode, body, status in workloads() if mode == "json" and status == 200}
    small, large = fixtures["json_array_65536"], fixtures["json_array_1048576"]
    for body in (small, large):
        assert len(body) <= 1048576 and isinstance(json.loads(body)["doc"], list)
    cases = [("small-batch", "json", 4, small, 1), ("yield-control", "yield", 126, small, 3)]
    cases += [("dense-1m", "json", count, large, 3) for count in (4, 16, 126)]
    results = {"date": date.today().isoformat(), "platform": platform.platform(),
               "bend": guarded(["bend", "version"], 20)[0].strip(),
               "bun": guarded(["bun", "--version"], 20)[0].strip(),
               "body_limit_bytes": 1048576, "configured_wire_read_timeout_ms": 200,
               "ordinary_send_delay_ms": 1, "cpu_release_delay_ms": 50,
               "host_deadline_seconds": HOST_TIMEOUT, "rss_limit_kib": RSS_LIMIT_KIB,
               "scope": "Finite held batch using existing JSON parser, HTTP transport, and Wire timed read; not strict decoding or production admission.",
               "admission_setup": "At most 126 held workloads plus ordinary and timed-read connections: 128 sockets. Bodies load sequentially into waiting handlers; all are framed before batch release.",
               "measurement": "Internal monotonic work clocks include body receive, parsing/value disposal, and tiny response construction. Sampled child RSS is not a kernel peak, total-system bound, or steady-state leak test.",
               "host_deadline_note": "Longer observation window for aggregate work; existing application/performance budgets and 20 GiB RSS guard are unchanged.",
               "lanes": {}}
    target = ROOT / "camber/json_aggregate_results.json"
    if target.exists():
        raise FileExistsError("Preserve the previous dataset before running another experiment")
    target.write_text(json.dumps(results, indent=2) + "\n")
    with tempfile.TemporaryDirectory(prefix="camber-json-aggregate-") as directory:
        temp = Path(directory)
        for backend, suffix in (("native", ""), ("javascript", ".js")):
            binary = temp / ("aggregate" + suffix)
            _, rss, seconds = guarded(["bend", ROOT / "camber/json_aggregate_probe.bend", "-o", binary], 180)
            variants = (("native_single", [str(binary), "--threads", "1", "--gpu", "off"]),
                        ("native_default_threads", [str(binary), "--gpu", "off"])) if backend == "native" else (("javascript", ["bun", str(binary)]),)
            for name, command in variants:
                lane = {"runtime_arguments": command[1:], "build_seconds": seconds,
                        "sampled_build_peak_rss_kib": rss, "cases": []}
                results["lanes"][name] = lane
                for workload, mode, count, body, trials in cases:
                    for trial in range(trials):
                        with socket.socket() as reservation:
                            reservation.bind(("127.0.0.1", 0))
                            port = reservation.getsockname()[1]
                        record = observe(command + [mode, str(count), str(port)], temp / "unused",
                                         interact(port, body, count), timeout_seconds=HOST_TIMEOUT)
                        record.update(workload=workload, mode=mode, count=count, trial=trial,
                                      body_bytes=len(body), aggregate_body_bytes=count * len(body),
                                      body_sha256=hashlib.sha256(body).hexdigest())
                        classify(record, count)
                        lane["cases"].append(record)
                        target.write_text(json.dumps(results, indent=2) + "\n")
                        assert record["exact_behavior_passed"], record
                        print(f"{name}/{workload}/{count}/{trial}: ordinary={record['ordinary_latency_seconds'] * 1000:.3f} ms; "
                              f"read-close={record['observed_read_arm_to_close_seconds'] * 1000:.3f} ms; "
                              f"RSS={record['sampled_peak_rss_kib'] / 1024:.1f} MiB", flush=True)
                lane["summary"] = {}
                for workload, mode, count, body, trials in cases:
                    rows = [r for r in lane["cases"] if r["workload"] == workload and r["count"] == count]
                    lane["summary"][f"{workload}/{count}"] = {
                        "median_ordinary_ms": statistics.median(r["ordinary_latency_seconds"] * 1000 for r in rows),
                        "median_read_arm_to_close_ms": statistics.median(r["observed_read_arm_to_close_seconds"] * 1000 for r in rows),
                        "median_batch_ms": statistics.median(r["batch_observed_seconds"] * 1000 for r in rows),
                        "median_recovery_ms": statistics.median(r["recovery_latency_seconds"] * 1000 for r in rows),
                        "maximum_sampled_peak_rss_kib": max(r["sampled_peak_rss_kib"] for r in rows)}
                target.write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
