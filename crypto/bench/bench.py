"""Crypto benchmark in Python: SHA-256 of 16 MiB of zero bytes with hashlib."""
import hashlib, time

data = bytes(16_777_216)
t0 = time.perf_counter()
h = hashlib.sha256(data).hexdigest()
t1 = time.perf_counter()
print(f"sha256\t{(t1 - t0) * 1000:.3f}\t{h}")
