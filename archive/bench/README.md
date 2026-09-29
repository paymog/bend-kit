# ZIP read benchmark

This times reading every entry of one fixed ZIP file, in Bend (`Archive.read`), in C with libarchive, and in Python with `zipfile`. JavaScript is omitted: neither Bun nor Node ships a ZIP reader.

## Run

```sh
python3 run.py              # 3 runs per variant, median, 1 MiB text entry
python3 run.py 5            # 5 runs
python3 run.py 1 65536      # 1 run on a 64 KiB text entry; check the checksum first after a change
```

You need `bend`, `cc`, `python3`, and libarchive (`brew install libarchive`; set `LIBARCHIVE_PREFIX` to use another install). `run.py` writes `out/fixture.zip` and the binaries to `out/`, which git ignores. It exits non-zero if a build fails, if a variant cannot read the fixture, or if any variant's checksum, entry count, or data byte count differs from Python's.

## Input

`run.py` writes the fixture with Python `zipfile`, every entry dated 2026-01-01 00:00:00, deflate level 6. Entries, in archive order:

- `empty-stored` (stored, 0 bytes) and `empty-deflated` (deflated, 0 bytes).
- `hello.txt` (stored, 11 bytes).
- `text.txt` (deflated): **N = 1,048,576** bytes of words from a fixed 89-word list, picked by an LCG with seed **0xDEADBEEF**, separated by spaces and ~1/16 newlines.
- `noise.bin` (stored): N/4 LCG bytes, seed **0xC0FFEE01**.
- `noise-deflated.bin` (deflated): 4096 LCG bytes, seed **0xBADF00D**, so deflate cannot shrink it.
- `names/cafe.txt` (stored): a short path name.
- `docs/000.txt` … `docs/063.txt` (deflated): 64 text entries of 512 + 61·i bytes, seed 0xA000 + i.

At the default N: **71** entries, **1,470,576** data bytes, **654,999** zip bytes with CRC-32 **cdde9f56** under Python 3's bundled zlib (another zlib may give other deflate bytes; the data and checksum stay the same).

Each program reads `out/fixture.zip` before the timer starts. The timed op, **`read`**, parses the central directory and inflates or copies every entry: one `Archive.read(16777216, input)` call, one `zipfile.ZipFile` plus `read()` of each entry, or one libarchive `zip_seekable` pass. Each checks every entry's CRC-32.

After the timer stops, each program prints a checksum over the entries in archive order: `h = h*31 + x` in wrapping u32, over the method (0 or 8), the CRC-32, each name byte, then each data byte. Names are the raw ASCII bytes from the archive. libarchive does not expose the method or the CRC, so `bench.c` takes the method from libarchive's per-entry format name and recomputes the CRC with zlib. Expected at the default N: **569062501**.

Throughput is data bytes (after inflate) per second, decimal MB/s.

Bend reads the file with `File.read_bytes` and turns it into `Bytes` before the timer starts; entry names and data stay `Bytes`.

## Results

Apple M-series arm64, macOS 25.6.0; Bend 2.0.32, Apple clang 17.0.0, libarchive 3.8.2, Python 3.14.6. Median of three runs with `python3 run.py`.

| variant | read ms | MB/s |
|---:|---:|---:|
| C (libarchive) | 1.7 | 873 |
| Python | 1.8 | 800 |
| Bend | 6.4 | 230 |
