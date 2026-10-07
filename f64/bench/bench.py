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

XS = [f(h, l) for h, l in VALS]

def fold():
    h = 0
    for a in XS:
        for b in XS:
            h ^= hi(a + b) ^ hi(a * b) ^ hi(a / b)
    return h & 0xFFFFFFFF

t0 = time.perf_counter()
h = fold()
ms = (time.perf_counter() - t0) * 1e3
print(f"fold\t{ms:.3f}\t{h}")
