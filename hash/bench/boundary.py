#!/usr/bin/env python3
"""Rotate the nine CRC boundary rows; retain every checked sample as CSV."""
import csv
import os
from pathlib import Path
import statistics
import subprocess
import sys
import zlib

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
PATTERNS = ("zero", "incrementing", "mixed")
ROWS = [(pattern, length) for pattern in PATTERNS for length in (31, 32, 33)]
CALLS = 100000


def main():
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    if runs < 1:
        sys.exit("run count must be positive")
    destination = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT / "boundary.csv"
    OUT.mkdir(exist_ok=True)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    for command in (["bend", "version"], ["clang", "--version"], ["python3", "--version"]):
        print(subprocess.check_output(command, text=True).splitlines()[0], file=sys.stderr)
    subprocess.run(["bend", "boundary.bend", "-o", OUT / "boundary"],
                   cwd=HERE, env=env, check=True)
    samples = {row: [] for row in ROWS}
    positions = [[] for _ in ROWS]
    with destination.open("w", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(("process", "rotation", "position", "pattern", "bytes", "calls", "ms", "crc32"))
        for process in range(runs):
            result = subprocess.check_output([OUT / "boundary"], cwd=HERE, env=env, text=True)
            lines = result.splitlines()
            if len(lines) != 81:
                sys.exit(f"expected 81 rows, got {len(lines)}")
            for index, line in enumerate(lines):
                rotation, position = divmod(index, 9)
                pattern, length = ROWS[(rotation + position) % 9]
                op, ms, checksum = line.split("\t")
                data = bytes(0 if pattern == "zero" else i if pattern == "incrementing"
                             else ((i * 73 + 19) ^ (i * i * 11)) & 255 for i in range(length))
                expected = f"{zlib.crc32(data):08x}"
                if op != f"crc32_{pattern}_{length}" or checksum != expected:
                    sys.exit(f"unexpected row or checksum: {line}")
                samples[pattern, length].append(float(ms))
                positions[position].append(float(ms))
                writer.writerow((process + 1, rotation, position, pattern, length, CALLS, ms, checksum))
    print(f"{runs} fresh processes; 9 rotations; {CALLS:,} calls per sample; raw: {destination}")
    print("| pattern | bytes | median ms | min ms | max ms |")
    print("|---|---:|---:|---:|---:|")
    for (pattern, length), values in samples.items():
        print(f"| {pattern} | {length} | {statistics.median(values):.6f} | {min(values):.6f} | {max(values):.6f} |")
    print("Position medians (ms): " + ", ".join(f"{statistics.median(v):.6f}" for v in positions))


if __name__ == "__main__":
    main()
