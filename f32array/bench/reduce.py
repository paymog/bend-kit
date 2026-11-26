#!/usr/bin/env python3
"""Measure reduction order, cutoff, and float64 error. BEND selects the compiler."""
import math
import os
from pathlib import Path
import statistics
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ACCURACY = "--accuracy" in sys.argv
OUT.mkdir(exist_ok=True)
subprocess.run([os.environ.get("BEND", "bend"), "reduce.bend", "-o", str(OUT / "reduce")], cwd=HERE, check=True)


def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


def reference(family, n):
    if family == 0:
        return dict.fromkeys(["sum", "dot"], float(100000000 + n - 1) if n else 0.0)
    a, b = (
        ([1e8, 1, -1e8, 1] * 2, [1] * 8)
        if family == 1 else
        ([1e4, .125, -1e4, .25, .001, 8, -.001, -4], [.5, 2, .5, 4, 2, -.5, 2, .25])
    )
    a, b = [f32(x) for x in a], [f32(x) for x in b]
    counts = [n // 8 + (i < n % 8) for i in range(8)]
    return {
        "sum": math.fsum(x * count for x, count in zip(a, counts)),
        "dot": math.fsum(x * y * count for x, y, count in zip(a, b, counts)),
    }


print("| family | N | mode | cell cutoff | threads | sum ms | dot ms | sum abs error | dot abs error |", flush=True)
print("|---|---:|---|---:|---:|---:|---:|---:|---:|", flush=True)
cases = [(f, n) for f in [0, 1, 2] for n in [0, 1, 4, 7, 8, 9, 127, 128, 129, 255, 256, 257, 49152, (1 << 22) - 3, 1 << 22]]
if not ACCURACY:
    cases = [(0, n) for n in [49152, 1 << 16, 1 << 18, 1 << 20, 1 << 22, 1 << 24]]
    cases += [(f, n) for f in [0, 1, 2] for n in [0, 1, 7, 8, 9, 127, 128, 129]]
    cases += [(f, n) for f in [1, 2] for n in [49152, 1 << 22]]
settings = [(1, 0, 1), (3, 0, 1), (4, 0, 1)] if ACCURACY else [(0, 0, 1), (1, 0, 1)] + [(2, c, t) for c in [16, 256, 4096, 65536, 1048576] for t in [1, 8]]
for family, n in cases:
    refs = reference(family, n)
    pairwise_bits = None
    for mode, cutoff, threads in settings:
        times = {"sum": [], "dot": []}
        errors = {}
        for _ in range(RUNS):
            result = subprocess.run([str(OUT / "reduce"), str(n), str(mode), str(cutoff), str(family), "+RTS", "--threads", str(threads)], capture_output=True, text=True, check=True)
            bits = {}
            for line in result.stdout.splitlines():
                kind, op, value = line.split("\t")
                if kind == "ms":
                    times[op].append(float(value))
                elif kind == "bits":
                    bits[op] = int(value)
                    actual = struct.unpack("<f", struct.pack("<I", int(value)))[0]
                    errors[op] = abs(actual - refs[op])
            assert bits.keys() == {"sum", "dot"}, result.stdout
            if family != 2:
                assert bits["sum"] == bits["dot"], result.stdout
            if mode == 1:
                pairwise_bits = bits
            elif mode == 2:
                assert bits == pairwise_bits, (family, n, cutoff, threads, bits, pairwise_bits)
            elif mode in [3, 4] and family == 1:
                for op in ["sum", "dot"]:
                    assert errors[op] == abs(f32(refs[op]) - refs[op]), (n, op, errors[op])
        label = ["old four sums", "blocked pairwise", "fork-join", "compensated", "blocked compensated"][mode]
        name = ["positive", "cancellation", "mixed-scale"][family]
        print(f"| {name} | {n} | {label} | {cutoff} | {threads} | {statistics.median(times['sum']):.4f} | {statistics.median(times['dot']):.4f} | {errors['sum']:.9g} | {errors['dot']:.9g} |", flush=True)
