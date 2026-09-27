"""Integer benchmark: the Python side (see README.md). Argument: N."""
import sys
import time

n = int(sys.argv[1]) if len(sys.argv) > 1 else 16384
M64 = (1 << 64) - 1
M32 = (1 << 32) - 1
a, c, m = 6364136223846793005, 1442695040888963407, 1000003

t0 = time.perf_counter()
x = 1
for _ in range(n):
    x = (x * a + c) & M64
print(f"lcg\t{(time.perf_counter() - t0) * 1e3:.3f}\t{x}")

xs, s = [], 1
for _ in range(n):
    hi = (s * 1664525 + 1013904223) & M32
    lo = (hi * 1664525 + 1013904223) & M32
    s = lo
    xs.append(hi << 32 | lo)
t0 = time.perf_counter()
acc = 0
for x in xs:
    acc = (acc + x % m) & M64
print(f"rem\t{(time.perf_counter() - t0) * 1e3:.3f}\t{acc}")
