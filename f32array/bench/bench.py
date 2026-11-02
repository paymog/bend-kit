import time

import numpy as np

N = 1 << 22


def ms(t):
    return (time.perf_counter() - t) * 1000


def ends(x):
    return int(x[N - 1] + x[12345])


i = np.arange(N, dtype=np.uint32)
src = ((i + 3) & 3).astype(np.float32)
b = ((i * 5 + 3) & 3).astype(np.float32)
data = src.astype("<f4").tobytes()

t = time.perf_counter()
a = np.frombuffer(data, dtype="<f4").copy()
print(f"from_bytes\t{ms(t):.6f}\t{ends(a)}")

t = time.perf_counter()
s = a.sum()
print(f"sum\t{ms(t):.6f}\t{int(s)}")

t = time.perf_counter()
m = a.max()
print(f"max\t{ms(t):.6f}\t{int(m)}")

t = time.perf_counter()
d = np.dot(a, b)
print(f"dot\t{ms(t):.6f}\t{int(d)}")

t = time.perf_counter()
a *= 2.0
print(f"map\t{ms(t):.6f}\t{ends(a)}")

t = time.perf_counter()
a += b
print(f"add\t{ms(t):.6f}\t{ends(a)}")

t = time.perf_counter()
out = a.astype("<f4").tobytes()
print(f"to_bytes\t{ms(t):.6f}\t{len(out) + out[-1]}")
