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
short = buf[:16]
run("crc32_short", 8, lambda: [zlib.crc32(short) for _ in range(100000)][-1])
run("adler32", 8, lambda: zlib.adler32(buf))
run("siphash13", 16, lambda: hash(buf) & (2**64 - 1))


def repeat_crc(data):
    h = 0
    for _ in range(100000):
        h = zlib.crc32(data)
    return h


for pattern in ("zero", "incrementing", "mixed"):
    for length in (0, 1, 3, 4, 7, 8, 15, 16, 17, 31, 32, 33):
        data = bytes(
            0 if pattern == "zero" else i if pattern == "incrementing"
            else ((i * 73 + 19) ^ (i * i * 11)) & 255
            for i in range(length)
        )
        run(f"crc32_{pattern}_{length}", 8, lambda: repeat_crc(data))
