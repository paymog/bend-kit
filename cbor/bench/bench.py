"""CBOR benchmark in Python with cbor2 (see README.md)."""
import time
import cbor2

data = open("out/doc.cbor", "rb").read()

t0 = time.perf_counter()
value = cbor2.loads(data)
t1 = time.perf_counter()
out = cbor2.dumps(value)
t2 = time.perf_counter()

# Checksum: h = h*31 + b, u32, then add the length.
h = 0
for b in out:
    h = (h * 31 + b) & 0xFFFFFFFF
h = (h + len(out)) & 0xFFFFFFFF
print(f"decode\t{(t1 - t0) * 1000:.3f}\t{h}")
print(f"encode\t{(t2 - t1) * 1000:.3f}\t{h}")
