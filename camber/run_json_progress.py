#!/usr/bin/env python3
"""Measure real JSON parsing/name validation beside ordinary HTTP and timed IO."""

import errno
import hashlib
import json
import platform
import socket
import statistics
import tempfile
from datetime import date
from pathlib import Path

from run_dispatch import ROOT, guarded
from run_progress import classify, interact
from run_risks import observe


def workloads():
    yield "name_valid_1k", "name", b'{"name":"Cara"}' + b" " * (1024 - 15), 200
    yield "name_unicode_boundary", "name", json.dumps({"name": "\u20ac" * 100}, ensure_ascii=False, separators=(",", ":")).encode(), 200
    for size in (65536, 1048576):
        name = b'{"name":"' + b"a" * (size - 11) + b'"}'
        yield f"name_oversize_{size}", "name", name, 400
        document = b'{"doc":"' + b"a" * (size - 10) + b'"}'
        yield f"json_string_{size}", "json", document, 200
        array = b'{"doc":[' + b"0," * ((size - 9) // 2 - 1) + b"0]}"
        yield f"json_array_{size}", "json", array + b" " * (size - len(array)), 200
        members = {f"k{i:06d}": 0 for i in range((size - 10) // 12)}
        obj = json.dumps({"doc": members}, separators=(",", ":")).encode()
        yield f"json_object_{size}", "json", obj + b" " * (size - len(obj)), 200
        escaped = b'{"doc":"' + b"\\u0061" * ((size - 10) // 6) + b'"}'
        yield f"json_escapes_{size}", "json", escaped + b" " * (size - len(escaped)), 200
    nested = b'{"doc":' + b"[" * 63 + b"0" + b"]" * 63 + b"}"
    yield "json_depth64", "json", nested, 200
    invalid = b'{"doc":"' + b"a" * (1048576 - 11) + b'"}X'
    yield "json_invalid_at_end_1048576", "json", invalid, 400


def main():
    cases = list(workloads())
    for name, mode, body, status in cases:
        assert len(body) <= 1048576, (name, len(body))
        if status == 200 or mode == "name":
            decoded = json.loads(body)
            if mode == "name":
                assert (1 <= len(decoded["name"]) <= 100) == (status == 200)
        else:
            try:
                json.loads(body)
            except json.JSONDecodeError:
                pass
            else:
                raise AssertionError(name)
    results = {"date": date.today().isoformat(), "platform": platform.platform(),
               "bend": guarded(["bend", "version"], 20)[0].strip(),
               "bun": guarded(["bun", "--version"], 20)[0].strip(),
               "body_limit_bytes": 1048576, "maximum_fixture_json_depth": 64,
               "configured_wire_read_timeout_ms": 200, "ordinary_send_delay_ms": 1,
               "cpu_release_delay_ms": 50, "host_deadline_seconds": 12,
               "scope": "Existing Json.parse.bytes or Users.name on HTTP bodies; parser/name validation and value disposal, not a strict Camber decoder or production server",
               "deadline_setup": "Timed read starts after complete body framing and both HTTP connections are accepted",
               "body_delivery": "One-shot affine body channel is received after CPU_BEGIN to prevent early decoder evaluation",
               "marker_flush_pause_ms": 1,
               "work_clock": "Time.mono around body receive, parsing/validation, value disposal and tiny response construction; excludes pre-work marker pause",
               "lanes": {}}
    target = ROOT / "camber/json_progress_results.json"
    with tempfile.TemporaryDirectory(prefix="camber-json-progress-") as directory:
        temp = Path(directory)
        for backend, suffix in (("native", ""), ("javascript", ".js")):
            binary = temp / ("progress" + suffix)
            _, rss, seconds = guarded(["bend", ROOT / "camber/json_progress_probe.bend", "-o", binary], 180)
            variants = (("native_single", [str(binary), "--threads", "1", "--gpu", "off"]),
                        ("native_default_threads", [str(binary), "--gpu", "off"])) if backend == "native" else (("javascript", ["bun", str(binary)]),)
            for lane_name, command in variants:
                lane = {"runtime_arguments": command[1:] if backend == "native" else ["bun", "<compiled-js>"],
                        "build_seconds": seconds, "sampled_build_peak_rss_kib": rss, "cases": []}
                results["lanes"][lane_name] = lane
                for name, mode, body, status in cases:
                    for trial in range(3):
                        with socket.socket() as reservation:
                            reservation.bind(("127.0.0.1", 0))
                            port = reservation.getsockname()[1]
                        record = observe(command + [mode, str(port)], temp / "unused",
                                         interact(port, body, status, b"cpu" if status == 200 else b"rejected", "PARTIAL_READY", .001))
                        record.update(workload=name, mode=mode, body_bytes=len(body), body_sha256=hashlib.sha256(body).hexdigest(), expected_status=status, trial=trial)
                        classify(record)
                        duration = next((event["text"].split()[1:] for event in record["events"] if event["text"].startswith("WORK_TIME\t")), None)
                        record["internal_work_seconds"] = int(duration[0]) + int(duration[1]) / 1e9 if duration is not None else None
                        read_error = next((event["text"].split()[1] for event in record["events"] if event["text"].startswith("DEADLINE_READ_FAILED ")), None)
                        record["wire_read_error_code"] = int(read_error) if read_error is not None else None
                        lane["cases"].append(record)
                        target.write_text(json.dumps(results, indent=2) + "\n")
                        assert record["returncode"] == 0 and "interaction_error" not in record, record
                        assert record["workload_response_exact"] and record["ordinary_response_exact"] and record["recovery_response_exact"], record
                        assert record["raw_read_failed"] and record["partial_peer_outcome"] == "eof" and record["observed_read_arm_to_close_seconds"] is not None, record
                        assert record["wire_read_error_code"] == errno.ETIMEDOUT, record
                        assert record["internal_work_seconds"] is not None, record
                        print(f"{lane_name}/{name}/{trial}: work={record['internal_work_seconds'] * 1000:.3f} ms; "
                              f"ordinary={record['ordinary_latency_seconds'] * 1000:.3f} ms; "
                              f"read-close={record['observed_read_arm_to_close_seconds'] * 1000:.3f} ms", flush=True)
                lane["summary"] = {name: {"median_work_ms": statistics.median(c["internal_work_seconds"] * 1000 for c in lane["cases"] if c["workload"] == name),
                                          "median_ordinary_ms": statistics.median(c["ordinary_latency_seconds"] * 1000 for c in lane["cases"] if c["workload"] == name),
                                          "median_read_arm_to_close_ms": statistics.median(c["observed_read_arm_to_close_seconds"] * 1000 for c in lane["cases"] if c["workload"] == name),
                                          "median_body_send_to_work_armed_ms": statistics.median(c["host_body_send_to_work_armed_seconds"] * 1000 for c in lane["cases"] if c["workload"] == name)}
                                   for name, *_ in cases}
                target.write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
