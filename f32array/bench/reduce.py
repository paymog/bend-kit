#!/usr/bin/env python3
"""Measure reduction order, cutoff, and float64 error. BEND selects the compiler."""
import os
from pathlib import Path
import statistics
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OUT.mkdir(exist_ok=True)
subprocess.run([os.environ.get("BEND", "bend"), "reduce.bend", "-o", str(OUT / "reduce")], cwd=HERE, check=True)
print("| N | mode | cell cutoff | threads | sum ms | dot ms | sum abs error | dot abs error |", flush=True)
print("|---:|---|---:|---:|---:|---:|---:|---:|", flush=True)
for n in [49152, 1 << 16, 1 << 18, 1 << 20, 1 << 22, 1 << 24]:
    reference = float(100000000 + n - 1)
    pairwise_bits = None
    for mode, cutoff, threads in [(0, 0, 1), (1, 0, 1)] + [(2, c, t) for c in [256, 4096, 65536, 1048576] for t in [1, 8]]:
        times = {"sum": [], "dot": []}
        errors = {}
        for _ in range(RUNS):
            result = subprocess.run([str(OUT / "reduce"), str(n), str(mode), str(cutoff), "+RTS", "--threads", str(threads)], capture_output=True, text=True, check=True)
            bits = {}
            for line in result.stdout.splitlines():
                kind, op, value = line.split("\t")
                if kind == "ms":
                    times[op].append(float(value))
                elif kind == "bits":
                    bits[op] = int(value)
                    actual = struct.unpack("<f", struct.pack("<I", int(value)))[0]
                    errors[op] = abs(actual - reference)
            assert bits.keys() == {"sum", "dot"}, result.stdout
            assert bits["sum"] == bits["dot"], result.stdout
            if mode == 1:
                pairwise_bits = bits
            elif mode == 2:
                assert bits == pairwise_bits, (n, cutoff, threads, bits, pairwise_bits)
        label = ["old four sums", "blocked pairwise", "fork-join"][mode]
        print(f"| {n} | {label} | {cutoff} | {threads} | {statistics.median(times['sum']):.4f} | {statistics.median(times['dot']):.4f} | {errors['sum']:.0f} | {errors['dot']:.0f} |", flush=True)
