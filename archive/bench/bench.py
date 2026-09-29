"""ZIP read benchmark in Python with zipfile (see README.md)."""
import io
import time
import zipfile
from pathlib import Path

ZIP = Path("out/fixture.zip").read_bytes()


def chk(b: bytes, h: int) -> int:
    for x in b:
        h = (h * 31 + x) & 0xFFFFFFFF
    return h


def raw_name(i: zipfile.ZipInfo) -> bytes:
    return i.orig_filename.encode("utf-8" if i.flag_bits & 0x800 else "cp437")


t0 = time.perf_counter()
z = zipfile.ZipFile(io.BytesIO(ZIP))
entries = [(i, z.read(i)) for i in z.infolist()]  # read() checks each CRC-32
ms = (time.perf_counter() - t0) * 1000

h = 0
for i, data in entries:
    h = (h * 31 + i.compress_type) & 0xFFFFFFFF
    h = (h * 31 + i.CRC) & 0xFFFFFFFF
    h = chk(data, chk(raw_name(i), h))
print(f"read\t{ms:.3f}\t{h}")
print(f"entries\t0\t{len(entries)}")
print(f"bytes\t0\t{sum(len(d) for _, d in entries)}")
