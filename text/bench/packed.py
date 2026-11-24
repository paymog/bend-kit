#!/usr/bin/env python3
"""Measure String and packed line diffs in alternating paired runs."""
import re
import statistics
import subprocess
from pathlib import Path

here = Path(__file__).resolve().parent
binary = here / "out" / "packed"
binary.parent.mkdir(exist_ok=True)
subprocess.run(["bend", "packed.bend", "-o", str(binary)], cwd=here, check=True)
for mode in ("baseline", "packed"):
    subprocess.run([str(binary), mode, "5"], check=True)
samples = {"baseline": [], "packed": []}
for pair in range(5):
    order = ("baseline", "packed") if pair % 2 == 0 else ("packed", "baseline")
    for mode in order:
        run = subprocess.run(["/usr/bin/time", "-l", str(binary), mode, "10000"], capture_output=True, text=True, check=True)
        values = dict(line.split("\t", 1) for line in run.stdout.splitlines())
        assert values["checksum"] == "654", run.stdout
        rss = re.search(r"(\d+)\s+maximum resident set size", run.stderr)
        assert rss, run.stderr
        result = {key: float(value) for key, value in values.items() if key.endswith(" ms")}
        result["RSS MiB"] = int(rss[1]) / 1048576
        samples[mode].append(result)
        print(pair + 1, mode, result, flush=True)
for mode, runs in samples.items():
    print("median", mode, {key: statistics.median(run[key] for run in runs) for key in runs[0]})
