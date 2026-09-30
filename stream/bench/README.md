# Bounded file-copy benchmark

From the repository root:

```sh
python3 stream/bench/run.py --size 262147 --chunk 16384 --rounds 3
```

Requires Bend, a C compiler, Rust, Python 3.11+, and Bun. The driver builds each
program once, runs a 259-byte smoke copy first, then measures three sequential
copies per language. There is never more than one Bend process. All temporary
inputs, outputs, and executables are removed on exit. This is manual, not CI.

The fixed input is 262,147 bytes with octet `i` equal to `(i * 73 + 255) % 256`.
It includes NUL, 0xff, and a non-word-aligned final chunk. Each program copies
at most the given cap through a 16,384-byte buffer and probes one byte after
reaching the cap to require exact EOF. Bend uses `Stream.file.file`; C, Rust,
Python, and JavaScript use ordinary standard-library file reads and writes.
No whole-input buffering, octet-String loop, or hand SIMD is involved.

Every program prints the completed count and FNV-1a32 of its output. Bend
reuses the published hash package. The shared driver independently checks
both values, the output length, and SHA-256 after every copy.
Reported medians include process startup, open/read/write/close, output
checksumming, and printing. Compiler time and the driver's independent
verification are excluded. Copies use warm filesystem caches and no fsync,
so these are not durable-storage throughput measurements.

## Recorded run

Run on macOS arm64 with Bend 2.0.34, Apple clang 17.0.0, Rust 1.91.0,
Python 3.14.6, and Bun 1.3.14. All three rounds matched completed counts,
FNV-1a32 `4053525081`, and output SHA-256
`a4717222fc9a8fb054a2f35224d23124418bf26aadb2843243cd3dd66a4346b2`.

| Language | Median copy + checksum process ms |
|---|---:|
| Bend | 4.356 |
| C | 6.977 |
| Rust | 5.342 |
| Python | 36.992 |
| JavaScript (Bun) | 17.737 |

Each 259-byte smoke used its own matching expected checksum. Times include
checksum work and process startup; they do not isolate transfer throughput.

## Native cap-fuel memory

A compiled 259-byte file copy with chunk 64 reported `Complete 259` and
identical bytes at caps 259 and 4,294,967,295. `/usr/bin/time -l` measured
1,785,856 bytes maximum RSS for each process. This supports the native
constant-size Nat fuel representation; the pure laws do not prove it.

With chunk 1024 and the same maximal cap, native copies of 259 and
8,388,611 bytes matched SHA-256 and used 1,818,624 and 1,884,160 bytes RSS.
The large input at cap 100 returned `Limit 100`, consumed exactly one probe
byte, and used 1,785,856 bytes RSS rather than buffering the full input.

Bun copies of 8,388,611, 33,554,435, and 67,108,867 bytes at chunk 1024
and maximal cap matched SHA-256. Peak RSS was 82,493,440, 83,853,312, and
84,852,736 bytes. These measurements include Bun's runtime and GC overhead;
they support bounded steady-state storage but are not allocation proofs.
