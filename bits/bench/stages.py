#!/usr/bin/env python3
"""Run the native canonical setup batches and print paired stage estimates."""
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STAGES = {"codes": 36592000, "maximum": 36607000, "count": 36847000,
          "next": 32767000, "reserve": 69389000, "assign": 36600000}


def main():
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    (HERE / "out").mkdir(exist_ok=True)
    subprocess.run(["bend", "stages.bend", "-o", "out/stages"], cwd=HERE, check=True)
    samples = []
    for _ in range(runs):
        result = subprocess.run(["out/stages"], cwd=HERE, text=True,
                                capture_output=True, check=True)
        current = {}
        count = 0
        for line in result.stdout.splitlines():
            name, elapsed, checksum = line.split("\t")
            base = name.removesuffix("-prepare").removesuffix("-consume")
            expected = STAGES.get(base, 8000 if name == "complete" else 0)
            assert int(checksum) == expected, line
            assert name not in current, line
            current[name] = float(elapsed)
            if name == "complete":
                assert len(current) == 20, current
                samples.append(current)
                current = {}
                count += 1
        assert not current and count == 10, result.stdout
    print(f"{len(samples)} samples; milliseconds per 1000 operations")
    print("| stage | input preparation | operation + consumption | consumption control | paired difference | difference range |")
    print("|---|---:|---:|---:|---:|---:|")
    for name in STAGES:
        delta = [s[name] - s[name + "-consume"] for s in samples]
        med = [statistics.median(s[key] for s in samples)
               for key in (name + "-prepare", name, name + "-consume")]
        print(f"| {name} | {med[0]:.6f} | {med[1]:.6f} | {med[2]:.6f} | {statistics.median(delta):.6f} | {min(delta):.6f}–{max(delta):.6f} |")
    for name in ("clock", "complete"):
        values = [s[name] for s in samples]
        print(f"{name}: median {statistics.median(values):.6f}; range {min(values):.6f}–{max(values):.6f}")
    totals = [sum(s[n] - s[n + "-consume"] for n in STAGES) for s in samples]
    print(f"stage sum: median {statistics.median(totals):.6f}; range {min(totals):.6f}–{max(totals):.6f}")


if __name__ == "__main__":
    main()
