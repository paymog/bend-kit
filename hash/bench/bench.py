# Hash benchmark in Python (see README.md). run.py sets PYTHONHASHSEED=0, which makes hash(bytes) SipHash-1-3 with a zero key.
import time, zlib

N = 16777213
buf = bytes(i % 251 for i in range(N))


def run(name, width, f):
    t0 = time.perf_counter()
    h = f()
    t1 = time.perf_counter()
    print(f"{name}\t{(t1 - t0) * 1000:.3f}\t{h:0{width}x}")


run("crc32", 8, lambda: zlib.crc32(buf))
run("adler32", 8, lambda: zlib.adler32(buf))
run("siphash13", 16, lambda: hash(buf) & (2**64 - 1))
