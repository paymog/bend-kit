# scrypt benchmark in Python: one 32-octet key from N = 16384, r = 8, p = 1, with hashlib.scrypt.
import hashlib, time

t0 = time.perf_counter()
key = hashlib.scrypt(b"pleaseletmein", salt=b"SodiumChloride", n=16384, r=8, p=1, maxmem=64 << 20, dklen=32)
t1 = time.perf_counter()
print(f"scrypt\t{(t1 - t0) * 1e3:.3f}\t{key.hex()}")
