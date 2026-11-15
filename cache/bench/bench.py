"""Cache benchmark: cachetools.TTLCache (see README.md)."""
import sys
import time

from cachetools import TTLCache

rounds = 1 << (int(sys.argv[1]) if len(sys.argv) > 1 else 12)
keys = [f"k{i}" for i in range(64)]
cache = TTLCache(maxsize=64, ttl=1e6)
chk = 0
t0 = time.perf_counter()
for i in range(rounds):
    v = i + 1
    for k in keys:
        cache[k] = (v, v)
    for k in keys:
        for _ in range(8):
            e = cache.get(k)
            if e is not None:
                chk += e[1]
chk &= 0xFFFFFFFF
t1 = time.perf_counter()
print(f"cache\t{(t1 - t0) * 1e3:.3f}\t{chk}")
