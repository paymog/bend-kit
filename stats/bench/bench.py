#!/usr/bin/env python3
import statistics, struct, time

def xs(x):
    x ^= (x << 13) & 0xFFFFFFFF
    x ^= x >> 17
    x ^= (x << 5) & 0xFFFFFFFF
    return x

def mix(x):
    l, h = struct.unpack("<II", struct.pack("<d", x))
    return l ^ h

v, x = [], 44
for _ in range(10000):
    x = xs(x)
    v.append(float(x >> 12))

# statistics.variance rounds the exact value once, and sum() compensates,
# so both differ from the plain loop in the low bits.
def variance(v):
    m = statistics.fmean(v)
    s = 0.0
    for x in v:
        s += (x - m) * (x - m)
    return s / (len(v) - 1)

for op, f in [("mean", statistics.fmean), ("variance", variance), ("median", statistics.median)]:
    t0 = time.perf_counter()
    r = f(v)
    ms = (time.perf_counter() - t0) * 1e3
    print(f"{op}\t{ms:.3f}\t{mix(r)}")
