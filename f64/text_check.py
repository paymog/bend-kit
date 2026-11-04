#!/usr/bin/env python3
"""Compare F64.read and F64.show with Python's float and repr on random inputs.

Usage: python3 text_check.py [count] [seed]

The inputs are the repr of random bit patterns (every exponent, subnormals
included), random decimal strings, and exact halfway points between adjacent
doubles. For each input it checks that read matches float(), that show
matches repr(), and that read(show(x)) gives back x.
"""
import os, random, struct, subprocess, sys
from decimal import Decimal, getcontext
from pathlib import Path

HERE = Path(__file__).resolve().parent
BIN = HERE / "bench" / "out" / "text_check"
COUNT = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 611)
getcontext().prec = 1200


def words(x):
    b = struct.unpack(">Q", struct.pack(">d", x))[0]
    return f"{b >> 32} {b & 0xFFFFFFFF}"


def from_bits(b):
    return struct.unpack(">d", struct.pack(">Q", b))[0]


def finite_bits():
    while True:
        x = from_bits(rng.getrandbits(64))
        if x == x and abs(x) != float("inf"):
            return x


def decimal_text():
    digits = "".join(rng.choice("0123456789") for _ in range(rng.randint(1, 25)))
    point = rng.randint(0, len(digits))
    text = digits[:point] + "." + digits[point:] if point < len(digits) else digits
    return f"{rng.choice(['', '-', '+'])}{text}e{rng.randint(-345, 330)}"


def halfway():
    x = abs(finite_bits())
    up = from_bits(struct.unpack(">Q", struct.pack(">d", x))[0] + 1)
    if up == float("inf"):
        return repr(x)
    return format((Decimal(x) + Decimal(up)) / 2, "f")


def inputs():
    out = ["0", "-0.0", "inf", "-Infinity", "NaN", "5e-324", "2.2250738585072014e-308", "1.7976931348623157e308", "1e309", "1e-400", "0.1", "9007199254740993"]
    while len(out) < COUNT:
        r = rng.random()
        out.append(repr(finite_bits()) if r < 0.6 else decimal_text() if r < 0.95 else halfway())
    return out


def main():
    BIN.parent.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    subprocess.run(["bend", "text_check.bend", "-o", BIN], cwd=HERE, env=env, check=True)
    cases = inputs()
    lines = []
    for i in range(0, len(cases), 2000):
        r = subprocess.run([BIN, *cases[i:i + 2000]], env=env, capture_output=True, text=True, check=True)
        lines += r.stdout.splitlines()
    if len(lines) != len(cases):
        sys.exit(f"expected {len(cases)} lines, got {len(lines)}")
    bad = 0
    for s, line in zip(cases, lines):
        x = float(s)
        got = line.split("\t")
        if x != x:
            ok = got[1] == "nan"
        else:
            ok = got == [words(x), repr(x), words(x)]
        if not ok:
            bad += 1
            if bad <= 20:
                print(f"MISMATCH {s!r}: got {got}, want {[words(x), repr(x), words(x)]}")
    print(f"{len(cases) - bad}/{len(cases)} inputs match Python")
    sys.exit(1 if bad else 0)


main()
