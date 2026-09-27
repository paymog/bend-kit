"""Zlib benchmark in Python with gzip (see README.md)."""
import gzip
import time
from pathlib import Path

GZ = Path("out/payload.gz").read_bytes()
PLAIN = Path("out/plain.bin").read_bytes()


def chk(b: bytes) -> int:
    h = 0
    for x in b:
        h = (h * 31 + x) & 0xFFFFFFFF
    return h


t0 = time.perf_counter()
out = gzip.decompress(GZ)
ms = (time.perf_counter() - t0) * 1000
print(f"inflate\t{ms:.3f}\t{chk(out)}")

t0 = time.perf_counter()
packed = gzip.compress(PLAIN, compresslevel=6, mtime=0)
ms = (time.perf_counter() - t0) * 1000
print(f"deflate\t{ms:.3f}\t{chk(gzip.decompress(packed))}")
print(f"size\t0\t{len(packed)}")
