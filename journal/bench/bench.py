# Journal recovery benchmark: zlib.crc32 and struct.unpack_from (see README.md).
import struct
import sys
import time
import zlib
lg = int(sys.argv[1]) if len(sys.argv) > 1 else 20
n = 1 << lg
parts = []
for i in range(n):
    plen = 16 + ((i * 7) % 48)
    payload = bytes((i * 31 + j) & 255 for j in range(plen))
    parts.append(struct.pack("<III", plen, (~plen) & 0xFFFFFFFF, zlib.crc32(payload) & 0xFFFFFFFF))
    parts.append(payload)
buf = b"".join(parts)

view = memoryview(buf)
t0 = time.perf_counter()
acc = 0
count = 0
off = 0
end = len(buf)
while off + 12 <= end:
    plen, nlen, want = struct.unpack_from("<III", view, off)
    if nlen != ((~plen) & 0xFFFFFFFF) or plen > 64 or off + 12 + plen > end:
        raise SystemExit("bad frame")
    payload = view[off + 12 : off + 12 + plen]
    if (zlib.crc32(payload) & 0xFFFFFFFF) != want:
        raise SystemExit("bad frame")
    acc = (acc * 31 + plen + payload[0]) & 0xFFFFFFFF
    count += 1
    off += 12 + plen
if off != end or count != n:
    raise SystemExit("bad frame")
t1 = time.perf_counter()
print(f"recover\t{(t1 - t0) * 1e3:.3f}\t{acc}\t{count}")
