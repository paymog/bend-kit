#!/usr/bin/env python3
import array, bisect, math, statistics, struct, sys, time

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

def histogram(v):
    edges = [float(i * 10486) for i in range(101)]
    counts = [0] * 100
    for x in v:
        if edges[0] <= x <= edges[-1]:
            i = min(bisect.bisect_right(edges, x) - 1, 99)
            counts[i] += 1
    return float(sum((i + 1) * n for i, n in enumerate(counts)))

for op, f in [("mean", statistics.fmean), ("variance", variance), ("median", statistics.median), ("histogram", histogram)]:
    t0 = time.perf_counter()
    r = f(v)
    ms = (time.perf_counter() - t0) * 1e3
    print(f"{op}\t{ms:.3f}\t{mix(r)}")

def integer_inputs(n):
    pairs = [(0, 0), (0, 0xFFFFFFFF), (0xFFFFFFFF, 0),
             (0xFFFFFFFF, 0xFFFFFFFF), (0xFFFFFFFF, 1),
             (65535, 65536), (65536, 65537), (12, 18)]
    a, b = 0, 1
    for _ in range(47):
        pairs.append((a, b))
        a, b = b, a + b
    x = 44
    for _ in range(n):
        a = xs(x)
        x = xs(a)
        pairs.append((a, x))
    return pairs

def checked_lcm(a, b):
    r = math.lcm(a, b)
    return 0x9E3779B9 if r > 0xFFFFFFFF else r

pairs = integer_inputs(int(sys.argv[1]) if len(sys.argv) > 1 else 2097152)
for op, f in [("gcd", math.gcd), ("lcm", checked_lcm),
              ("isqrt", lambda a, b: math.isqrt(a))]:
    t0 = time.perf_counter()
    checksum = 0
    for a, b in pairs:
        checksum = (checksum + f(a, b)) & 0xFFFFFFFF
    ms = (time.perf_counter() - t0) * 1e3
    print(f"{op}\t{ms:.3f}\t{checksum}")

packed = array.array("I", (word for pair in pairs for word in pair))
assert packed.itemsize == 4
for op, f in [("packed_identity", lambda a, b: a), ("packed_gcd", math.gcd),
              ("packed_lcm", checked_lcm), ("packed_isqrt", lambda a, b: math.isqrt(a))]:
    t0 = time.perf_counter()
    checksum = 0
    for i in range(0, len(packed), 2):
        checksum = (checksum + f(packed[i], packed[i + 1])) & 0xFFFFFFFF
    ms = (time.perf_counter() - t0) * 1e3
    print(f"{op}\t{ms:.3f}\t{checksum}")
