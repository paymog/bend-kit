#!/usr/bin/env python3
"""Measure String and packed line diffs in alternating paired runs."""
import argparse
import re
import statistics
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--baseline", type=Path, help="Compare two packed native binaries instead of String versus packed.")
args = parser.parse_args()
here = Path(__file__).resolve().parent
binary = here / "out" / "packed"
binary.parent.mkdir(exist_ok=True)
subprocess.run(["bend", "packed.bend", "-o", str(binary)], cwd=here, check=True)
variants = {"baseline": (args.baseline.resolve(), "packed") if args.baseline else (binary, "baseline"), "packed": (binary, "packed")}
for executable, mode in variants.values():
    subprocess.run([str(executable), mode, "5"], check=True)
samples = {"baseline": [], "packed": []}
for pair in range(5):
    order = ("baseline", "packed") if pair % 2 == 0 else ("packed", "baseline")
    for mode in order:
        executable, operation = variants[mode]
        run = subprocess.run(["/usr/bin/time", "-l", str(executable), operation, "10000"], capture_output=True, text=True, check=True)
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
