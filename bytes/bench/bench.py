import sys
import time

L = int(sys.argv[1]) if len(sys.argv) > 1 else 28
N = 1 << L
READS = int(sys.argv[2]) if len(sys.argv) > 2 else 1 << 24
B1 = int(sys.argv[3]) if len(sys.argv) > 3 else 1000000
B2 = int(sys.argv[4]) if len(sys.argv) > 4 else 4000000


def fill_buf(n: int) -> tuple[bytearray, int]:
    # Tile bytes(range(256)) then overwrite with the spec formula (same result as per-index fill).
    tile = bytes(range(256))
    reps = (n + 255) // 256
    b = bytearray((tile * reps)[:n])
    for i in range(n):
        b[i] = (i * 31 + 7) & 255
    b[n - 4 : n] = bytes([13, 10, 13, 10])
    cs = b[12345 % n] + b[n - 1]
    return b, cs


t0 = time.perf_counter()
b, cs = fill_buf(N)
print(f"fill\t{(time.perf_counter() - t0) * 1000:.6f}\t{cs}")

t0 = time.perf_counter()
s = 0
for byte in b:
    s = (s + byte) & 0xFFFFFFFF
print(f"sum\t{(time.perf_counter() - t0) * 1000:.6f}\t{s}")

needle = bytes([13, 10, 13, 10])
t0 = time.perf_counter()
find_idx = b.find(needle)
print(f"find\t{(time.perf_counter() - t0) * 1000:.6f}\t{find_idx}")

slice_start = N // 4 + 1
slice_len = N // 2
t0 = time.perf_counter()
s_buf = bytearray(b[slice_start : slice_start + slice_len])
cs = s_buf[0] + s_buf[-1]
print(f"slice\t{(time.perf_counter() - t0) * 1000:.6f}\t{cs}")

t0 = time.perf_counter()
out = bytearray()
chunk_size = min(N, 65536)
chunks = N // chunk_size
for k in range(chunks):
    out += bytes([k & 255]) * chunk_size
if len(out) != N:
    sys.exit(1)
cs = out[0] + out[-1]
print(f"concat\t{(time.perf_counter() - t0) * 1000:.6f}\t{cs}")

x, acc = 1, 0
shift = 32 - L
t0 = time.perf_counter()
for _ in range(READS):
    x = (x * 1664525 + 1013904223) & 0xFFFFFFFF
    idx = x >> shift
    acc = (acc + b[idx]) & 0xFFFFFFFF
print(f"random\t{(time.perf_counter() - t0) * 1000:.6f}\t{acc}")

c = bytearray(b)
t0 = time.perf_counter()
eq = b == c
print(f"equal\t{(time.perf_counter() - t0) * 1000:.6f}\t{1 if eq else 0}")

for size in (B1, B2):
    t0 = time.perf_counter()
    built = bytearray()
    for i in range(size):
        built.append(i & 255)
    cs = size + built[-1]
    print(f"build_{size}\t{(time.perf_counter() - t0) * 1000:.6f}\t{cs}")
