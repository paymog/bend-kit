# CSV benchmark

This times `Csv.parse` and `Csv.encode` on one fixed document, in Bend, Rust, and Python.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 20000 rows
python3 run.py 5        # 5 runs
python3 run.py 1 50     # 1 run on 50 rows; check this first after a change
```

You need `bend`, `cargo`, and `python3`. `run.py` writes the input to `out/doc.csv` and the binaries to `out/`, which git ignores. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

`run.py` writes 20000 rows of five fields with Python's `csv.writer` (CRLF line ends, quotes only where needed): 664,194 bytes. The third field cycles through plain text, a comma, doubled quotes, an embedded CRLF, and an empty field, so a fifth of the rows need each kind of quoting.

Each program reads the file before any timer starts. `parse` starts from the file's bytes and ends with all rows in memory. `encode` writes those rows back to bytes. Python decodes and encodes as Latin-1, one code point per octet, and that is timed. After each timer stops, the program prints a checksum of the encoded output: `h = h*31 + c` over the bytes, in wrapping u32, plus the length. The rows are affine in Bend, so Bend prints the checksum of its one `encode` output for both ops. All three checksums are `2571236663`, which is the checksum of the input itself: every encoder writes the document back byte for byte.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | Rust | Python | Bend |
|---|---:|---:|---:|
| parse | 1.6 (1.0x) | 7.6 (4.7x) | 6.0 (3.7x) |
| encode | 0.6 (1.0x) | 6.1 (10.0x) | 11.0 (18.0x) |

Versions: Bend 2.0.31, Rust 1.91.0 with `csv` 1.4.0, Python 3.14.6. Bend peaks at 25 MB of RSS.

## The calls

| language | parse | encode |
|---|---|---|
| Bend | `Csv.parse` | `Csv.encode` |
| Rust | `csv::ReaderBuilder` (no headers, flexible), `byte_records` | `csv::WriterBuilder` with `Terminator::CRLF`, `write_byte_record` |
| Python | `csv.reader` over `io.StringIO` | `csv.writer(lineterminator="\r\n").writerows` |

C and JavaScript are left out. Their standard libraries have no CSV codec.

## Caveats

- `Csv.encode` builds a list of small pieces (fields, commas, line ends) and joins them with one `Bytes.concat`. Most pieces land at an unaligned offset, where `Bytes.copy` copies byte by byte. That is most of the encode time.
- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- These are micro-benchmarks on one machine.
