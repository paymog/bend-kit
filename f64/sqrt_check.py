#!/usr/bin/env python3
"""Compare native F64.sqrt bits with math.sqrt: [count=20000] [seed=727]."""
import math
import os
import random
import struct
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BIN = HERE / "bench" / "out" / "sqrt_check"


def bits(x):
    return struct.unpack(">Q", struct.pack(">d", x))[0]


def value(b):
    return struct.unpack(">d", struct.pack(">Q", b))[0]


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 727
    rng = random.Random(seed)
    cases = [0, 1 << 63, 1, (1 << 52) - 1, 1 << 52,
             0x7FEFFFFFFFFFFFFF, bits(1.0), bits(2.0), bits(4.0),
             bits(math.inf), bits(-math.inf), bits(math.nan)]
    # Include random subnormals explicitly, not just their rare uniform samples.
    for i in range(count):
        b = rng.getrandbits(52) if i % 4 == 0 else rng.randrange(0x7FF0000000000000)
        cases.append(b | (rng.getrandbits(1) << 63))
    # Adjacent inputs around exact squares exercise rounding boundaries.
    for _ in range(1000):
        x = value(rng.randrange(0x0010000000000000, 0x5FE0000000000000))
        square = x * x
        if math.isfinite(square) and square > 0:
            b = bits(square)
            cases.extend([b - 1, b, b + 1])
    BIN.parent.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    subprocess.run(["bend", "sqrt_check.bend", "-o", BIN], cwd=HERE, env=env, check=True)
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
            want = 0x7FF8000000000000 if x < 0 or math.isnan(x) else bits(math.sqrt(x))
            hi, lo = map(int, line.split())
            got = (hi << 32) | lo
            if got != want:
                bad += 1
                if bad <= 20:
                    print(f"MISMATCH {b:016x}: got {got:016x}, want {want:016x}")
    print(f"{len(cases) - bad}/{len(cases)} inputs match Python math.sqrt (seed {seed})")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
