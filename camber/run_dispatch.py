#!/usr/bin/env python3
"""Measure experiment dispatch only. These are not HTTP server or Camber release benchmarks."""
import json
import os
import platform
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
RSS_LIMIT_KIB = 20 * 1024 * 1024
EXPECTED = {
    "health": 200 + len('{"ok":true}'),
    "parameter": 200 + len('{"id":7,"name":"Alice"}'),
    "invalid-id": 400 + len('{"error":"invalid input"}'),
    "json-1k": len("Cara"),
    "echo-1k": 200 + 1024,
    "registry-10": 200 + 1024,
    "registry-100": 200 + 1024,
    "registry-1000": 200 + 1024,
}


def guarded(command, timeout):
    peak_kib = 0
    start = time.monotonic()
    with tempfile.TemporaryFile(mode="w+t") as out, tempfile.TemporaryFile(mode="w+t") as err:
        process = subprocess.Popen(command, cwd=ROOT, env=ENV, stdout=out, stderr=err)
        try:
            while process.poll() is None:
                rss = subprocess.run(["ps", "-o", "rss=", "-p", str(process.pid)], capture_output=True, text=True, timeout=5)
                if rss.stdout.strip():
                    peak_kib = max(peak_kib, int(rss.stdout))
                if peak_kib > RSS_LIMIT_KIB:
                    raise RuntimeError("process exceeded 20 GiB RSS")
                if time.monotonic() - start > timeout:
                    raise TimeoutError(f"command exceeded {timeout} seconds")
                time.sleep(0.1)
        finally:
            if process.poll() is None:
                process.kill()
            process.wait()
        out.seek(0)
        err.seek(0)
        stdout, stderr = out.read(), err.read()
        if process.returncode:
            raise RuntimeError(f"command failed: {command}\n{stdout}\n{stderr}")
    return stdout, peak_kib, time.monotonic() - start


def parse(text, iterations):
    rows = {}
    for line in text.splitlines():
        name, milliseconds, checksum = line.split("\t")
        assert name not in rows, name
        assert int(checksum) == EXPECTED[name] * iterations, line
        rows[name] = float(milliseconds)
    assert rows.keys() == EXPECTED.keys(), rows
    return rows


def main():
    iterations = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    trials = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    if iterations < 1 or trials < 1:
        raise ValueError("iterations and trials must be positive")
    results = {}
    with tempfile.TemporaryDirectory(prefix="camber-dispatch-") as directory:
        temp = Path(directory)
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            executable = temp / ("dispatch_bench" + suffix)
            _, build_rss, build_seconds = guarded(["bend", ROOT / "camber/dispatch_bench.bend", "-o", executable], 120)
            command = [executable] if lane == "native" else ["bun", executable]
            journal = temp / (lane + "-journal")
            small, _, _ = guarded([*command, "10", journal], 30)
            parse(small, 10)
            samples, peaks = [], []
            for trial in range(trials):
                text, peak, _ = guarded([*command, str(iterations), journal], 120)
                samples.append(parse(text, iterations))
                peaks.append(peak)
                assert journal.read_bytes() == b"", "read-only workloads changed the journal"
            results[lane] = {
                "build_seconds": round(build_seconds, 3),
                "artifact_bytes": executable.stat().st_size,
                "build_sampled_peak_rss_mib": round(build_rss / 1024, 2),
                "runtime_sampled_peak_rss_mib": round(max(peaks) / 1024, 2),
                "median_ms": {name: round(statistics.median(sample[name] for sample in samples), 6) for name in EXPECTED},
                "trials_ms": samples,
            }
    print(json.dumps({"platform": platform.platform(), "iterations": iterations, "trials": trials, "warmup_per_workload": 100, "results": results}, indent=2))


if __name__ == "__main__":
    main()
