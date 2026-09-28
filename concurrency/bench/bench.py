"""Concurrency benchmark: one CPU-bound job over 64 inputs, on 1 and 8 processes (see README.md)."""
import time
from concurrent.futures import ProcessPoolExecutor

N = 64
ROUNDS = 1 << 20
M = 0xFFFFFFFF


def job(x):
    for _ in range(ROUNDS):
        x = ((x ^ (x >> 13)) * 1664525 + 1013904223) & M
    return x


def op(name, workers):
    # Start the pool before the timer; the GIL rules out threads for CPU work.
    with ProcessPoolExecutor(workers) as ex:
        list(ex.map(abs, range(workers)))
        t0 = time.perf_counter()
        out = list(ex.map(job, range(N), chunksize=N // workers))
        ms = (time.perf_counter() - t0) * 1e3
    h = 0
    for x in out:
        h = (h * 31 + x) & M
    print(f"{name}\t{ms:.1f}\t{h}", flush=True)


if __name__ == "__main__":
    op("map_1", 1)
    op("map_8", 8)
