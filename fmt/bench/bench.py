"""Shortest F32 benchmark: the Python side (see README.md). Argument: N.

Python has no float32; numpy's format_float_scientific(unique=True) prints the
shortest digits, and the rest reshapes them into repr style."""
import sys, time
import numpy as np


def shortest(x):
    if np.isnan(x):
        return "nan"
    if np.isinf(x):
        return "-inf" if x < 0 else "inf"
    if x == 0:
        return "-0.0" if np.signbit(x) else "0.0"
    m, e = np.format_float_scientific(abs(x), unique=True, trim="-").split("e")
    e = int(e)
    d = m.replace(".", "")
    sign = "-" if x < 0 else ""
    if e < -4 or e >= 16:
        return f"{sign}{d[0]}{'.' + d[1:] if len(d) > 1 else ''}e{'-' if e < 0 else '+'}{abs(e):02d}"
    if e < 0:
        return f"{sign}0.{'0' * (-e - 1)}{d}"
    if e + 1 >= len(d):
        return f"{sign}{d}{'0' * (e + 1 - len(d))}.0"
    return f"{sign}{d[:e + 1]}.{d[e + 1:]}"


n = int(sys.argv[1]) if len(sys.argv) > 1 else 50000
s, xs = 1, []
for _ in range(n):
    s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
    xs.append(s)
fs = np.array(xs, dtype=np.uint32).view(np.float32)
t0 = time.perf_counter()
h = 2166136261
for x in fs:
    for c in shortest(x).encode() + b"\n":
        h = ((h ^ c) * 16777619) & 0xFFFFFFFF
print(f"short\t{(time.perf_counter() - t0) * 1e3:.3f}\t{h}")
