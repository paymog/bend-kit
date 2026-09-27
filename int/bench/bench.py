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

n2 = int(sys.argv[2]) if len(sys.argv) > 2 else 10000000
t0 = time.perf_counter()
x, acc = 1, 0
for _ in range(n2):
    x = (x * 1664525 + 1013904223) & M32
    s = x - (1 << 32) if x >> 31 else x
    q = abs(s) // 1000
    acc = (acc + (-q if s < 0 else q)) & M32
acc = acc - (1 << 32) if acc >> 31 else acc
print(f"i32\t{(time.perf_counter() - t0) * 1e3:.3f}\t{acc}")
t0 = time.perf_counter()
x = 1
for _ in range(n2):
    x = (x * 25173 + 13849) & 0xFFFF
print(f"u16\t{(time.perf_counter() - t0) * 1e3:.3f}\t{x}")
t0 = time.perf_counter()
x = 1
for _ in range(n2):
    x = (x * 77 + 13) & 0xFF
print(f"u8\t{(time.perf_counter() - t0) * 1e3:.3f}\t{x}")
