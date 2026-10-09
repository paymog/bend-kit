"""Resources benchmark: threading.BoundedSemaphore (see README.md)."""
import sys
import threading
import time

rounds = 1 << (int(sys.argv[1]) if len(sys.argv) > 1 else 14)
pool = threading.BoundedSemaphore(64)
admitted = refused = 0
t0 = time.perf_counter()
for _ in range(rounds):
    for _ in range(65):
        if pool.acquire(blocking=False):
            admitted += 1
        else:
            refused += 1
    for _ in range(64):
        pool.release()
chk = (admitted * 31 + refused) & 0xFFFFFFFF
t1 = time.perf_counter()
print(f"lease\t{(t1 - t0) * 1e3:.3f}\t{chk}")
