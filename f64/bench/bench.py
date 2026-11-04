#!/usr/bin/env python3
import struct, time

VALS = [
    (1072693248, 0),
    (1073217536, 0),
    (1074266112, 0),
    (1017118720, 0),
    (0, 1),
    (3220176896, 0),
]

def f(h, l):
    return struct.unpack("<d", struct.pack("<II", l, h))[0]

def hi(x):
    return struct.unpack("<II", struct.pack("<d", x))[1]

def mix(x):
    l, h = struct.unpack("<II", struct.pack("<d", x))
    return l ^ h

def xs(x):
    x ^= (x << 13) & 0xFFFFFFFF
    x ^= x >> 17
    x ^= (x << 5) & 0xFFFFFFFF
    return x

XS = [f(h, l) for h, l in VALS]

def fold():
    h = 0
    for a in XS:
        for b in XS:
            h ^= hi(a + b) ^ hi(a * b) ^ hi(a / b)
    return h & 0xFFFFFFFF

def gen():
    out, x = [], 611
    for _ in range(1000):
        a = xs(x)
        b = xs(a)
        x = b
        if (a >> 20) & 2047 != 2047:
            out.append(f(a, b))
    return out

def checksum(text):
    h = 0
    for s in text:
        h ^= mix(float(s))
    return h

t0 = time.perf_counter()
h = fold()
ms = (time.perf_counter() - t0) * 1e3
print(f"fold\t{ms:.3f}\t{h}")

nums = gen()
t0 = time.perf_counter()
text = [repr(x) for x in nums]
ms = (time.perf_counter() - t0) * 1e3
print(f"show\t{ms:.3f}\t{checksum(text)}")

t0 = time.perf_counter()
h = checksum(text)
ms = (time.perf_counter() - t0) * 1e3
print(f"read\t{ms:.3f}\t{h}")
