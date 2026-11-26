import os
import sys
import time

L = int(sys.argv[1]) if len(sys.argv) > 1 else 28
N = 1 << L
READS = int(sys.argv[2]) if len(sys.argv) > 2 else 1 << 24
B1 = int(sys.argv[3]) if len(sys.argv) > 3 else 1000000
B2 = int(sys.argv[4]) if len(sys.argv) > 4 else 4000000
COUNT = max(1, int(os.getenv("BYTES_BENCH_COUNT", "1")))
WARMUP = int(os.getenv("BYTES_BENCH_WARMUP", "0"))


def measure(name, operation):
    for _ in range(WARMUP):
        operation()
    total = 0
    t0 = time.perf_counter_ns()
    for _ in range(COUNT):
        last = operation()
        total = (total + last) & 0xFFFFFFFF
    ms = (time.perf_counter_ns() - t0) / 1e6
    print(f"{name}\t{ms:.6f}\t{last}\t{COUNT}\t{total}")


def fill_buf(n):
    b = bytearray(n)
    for i in range(n):
        b[i] = (i * 31 + 7) & 255
    b[n - 4:n] = bytes([13, 10, 13, 10])
    return b, b[12345 % n] + b[n - 1]


measure("fill", lambda: fill_buf(N)[1])
b, _ = fill_buf(N)


def sum_bytes():
    total = 0
    for byte in b:
        total = (total + byte) & 0xFFFFFFFF
    return total


def slice_bytes():
    out = bytearray(b[N // 4 + 1:N // 4 + 1 + N // 2])
    return out[0] + out[-1]


def concat_bytes():
    out = bytearray()
    chunk_size = min(N, 65536)
    for k in range(N // chunk_size):
        out += bytes([k & 255]) * chunk_size
    assert len(out) == N
    return out[0] + out[-1]


def random_bytes():
    x, acc = 1, 0
    for _ in range(READS):
        x = (x * 1664525 + 1013904223) & 0xFFFFFFFF
        acc = (acc + b[x >> (32 - L)]) & 0xFFFFFFFF
    return acc


def build(size):
    out = bytearray()
    for i in range(size):
        out.append(i & 255)
    return size + out[-1]


measure("sum", sum_bytes)
needle = bytes([13, 10, 13, 10])
measure("find", lambda: b.find(needle))
measure("slice", slice_bytes)
measure("concat", concat_bytes)
measure("random", random_bytes)
c = bytearray(b)
measure("equal", lambda: int(b == c))
for size in (B1, B2):
    measure(f"build_{size}", lambda: build(size))
