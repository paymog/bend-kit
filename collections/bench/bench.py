"""Collections benchmark: Python (see README.md). omap uses sortedcontainers.SortedDict."""
import heapq, sys, time
from collections import deque

from sortedcontainers import SortedDict

L = int(sys.argv[1]) if len(sys.argv) > 1 else 20
N = 1 << L
M = 0xFFFFFFFF


def lcg(x):
    return (x * 1664525 + 1013904223) & M


def mix(acc, x):
    return (acc * 31 + x) & M


def lap(name, t0, chk):
    print(f"{name}\t{(time.perf_counter() - t0) * 1000:.3f}\t{chk}")


t0 = time.perf_counter()
m, x = SortedDict(), 1
for i in range(N):
    x = lcg(x)
    m[x] = i
lap("omap_put", t0, len(m))

t0 = time.perf_counter()
x, acc = 1, 0
for _ in range(N):
    x = lcg(x)
    acc = (acc + m.get(x, 0)) & M
lap("omap_get", t0, acc)
del m

t0 = time.perf_counter()
m, x = {}, 1
for i in range(N):
    x = lcg(x)
    m[x] = i
lap("hmap_put", t0, len(m))

t0 = time.perf_counter()
x, acc = 1, 0
for _ in range(N):
    x = lcg(x)
    acc = (acc + m.get(x, 0)) & M
lap("hmap_get", t0, acc)

t0 = time.perf_counter()
v = []
for i in range(N):
    v.append(i)
lap("vec_push", t0, len(v))

t0 = time.perf_counter()
x, acc = 1, 0
for _ in range(N):
    x = lcg(x)
    acc = (acc + v[x >> (32 - L)]) & M
lap("vec_get", t0, acc)

t0 = time.perf_counter()
d = deque()
for i in range(N):
    d.append(i)
lap("deque_push", t0, len(d))

t0 = time.perf_counter()
acc = 0
for _ in range(N // 2):
    acc = mix(acc, d.popleft())
for _ in range(N // 2):
    acc = mix(acc, d.pop())
lap("deque_pop", t0, acc)

t0 = time.perf_counter()
h, x = [], 1
for _ in range(N):
    x = lcg(x)
    heapq.heappush(h, x)
lap("heap_push", t0, len(h))

t0 = time.perf_counter()
acc = 0
for _ in range(N):
    acc = mix(acc, heapq.heappop(h))
lap("heap_pop", t0, acc)
