#!/usr/bin/env python3
"""Build and run the fixed one-shot deadline workload; verify every checksum."""
import os
from pathlib import Path
import statistics
import subprocess
import sys

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
VARIANTS = {
    "C qsort (batch)": (["cc", "-O2", "bench.c", "-o", OUT / "c"], [OUT / "c"]),
    "Rust BinaryHeap": (["rustc", "-O", "bench.rs", "-o", OUT / "rust"], [OUT / "rust"]),
    "Python heapq": (None, ["python3", "bench.py"]),
    "JavaScript sort (batch)": (None, ["bun", "bench.js"]),
    "Bend scheduler": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def main():
    OUT.mkdir(exist_ok=True)
    checks, times = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            subprocess.run(build, cwd=HERE, env=ENV, check=True)
        values = []
        for _ in range(RUNS):
            result = subprocess.run(run, cwd=HERE, env=ENV, check=True, capture_output=True, text=True)
            ms, checksum = result.stdout.strip().split("\t")
            checks.setdefault(name, checksum)
            assert checks[name] == checksum, (name, "unstable checksum")
            values.append(float(ms))
        times[name] = statistics.median(values)
    assert len(set(checks.values())) == 1, checks
    print("checksum:", next(iter(checks.values())))
    print("| Implementation | Median ms |")
    print("|---|---:|")
    for name, ms in times.items():
        print(f"| {name} | {ms:.3f} |")


if __name__ == "__main__":
    main()
