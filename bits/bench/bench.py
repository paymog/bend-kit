# Bits benchmark in Python: zlib.decompress on the raw DEFLATE payload. The standard library has no bit reader.
import time, zlib

data = open("out/payload.bin", "rb").read()
t = time.perf_counter()
out = zlib.decompress(data, -15)
ms = (time.perf_counter() - t) * 1e3
h = 0
for b in out:
    h = (h * 31 + b) & 0xFFFFFFFF
print(f"huffman\t{ms:.3f}\t{h}")
