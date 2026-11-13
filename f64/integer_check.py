#!/usr/bin/env python3
"""Compare native integer conversions with Python: [count=20000] [seed=729]."""
import math
import os
import random
import struct
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BIN = HERE / "bench" / "out" / "integer_check"


def bits(x):
    return struct.unpack(">Q", struct.pack(">d", x))[0]


def value(b):
    return struct.unpack(">d", struct.pack(">Q", b))[0]


def expected(x, op):
    if math.isnan(x):
        return 0x7FF8000000000000
    if math.isinf(x):
        return bits(x)
    y = float(op(x))
    return bits(math.copysign(0.0, x) if y == 0 else y)


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 729
    rng = random.Random(seed)
    cases = [0, 1 << 63, 1, (1 << 63) | 1, 0x7FF0000000000000,
             0xFFF0000000000000, 0x7FF0000000000001, 0xFFF8000000000123]
    # Exercise fractional exponents and subnormals as well as uniform bit patterns.
    for i in range(count):
        b = rng.getrandbits(64)
        if i % 4 == 0:
            b = (rng.getrandbits(1) << 63) | rng.getrandbits(52)
        elif i % 4 == 1:
            b = ((rng.getrandbits(1) << 63) | (rng.randrange(1022, 1076) << 52)
                 | rng.getrandbits(52))
        cases.append(b)
    for x in (-1.0, -0.5, 0.5, 1.0, 2.9, 2**20, 2**31, 2**32 - 1, 2**32, 2**52):
        b = bits(x)
        cases.extend([b - 1, b, b + 1])
    BIN.parent.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    subprocess.run(["bend", "integer_check.bend", "-o", BIN], cwd=HERE, env=env, check=True)
    bad = 0
    for start in range(0, len(cases), 1000):
        batch = cases[start:start + 1000]
        args = [str(w) for b in batch for w in (b >> 32, b & 0xFFFFFFFF)]
        result = subprocess.run([BIN, *args], env=env, capture_output=True, text=True, check=True)
        lines = result.stdout.splitlines()
        if len(lines) != len(batch):
            sys.exit(f"Expected {len(batch)} lines, got {len(lines)}")
        for b, line in zip(batch, lines):
            x = value(b)
            p = line.split()
            got = [(int(p[i]) << 32) | int(p[i + 1]) for i in (0, 2, 4)]
            want = [expected(x, op) for op in (math.floor, math.ceil, math.trunc)]
            integer = str(math.trunc(x)) if math.isfinite(x) and -1 < x < 2**32 else "none"
            if got != want or p[6] != integer:
                bad += 1
                if bad <= 20:
                    print(f"MISMATCH {b:016x}: got {got}, {p[6]}; want {want}, {integer}")
    print(f"{len(cases) - bad}/{len(cases)} inputs match Python integer conversions (seed {seed})")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
