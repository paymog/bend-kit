# CBOR benchmark

This times `Cbor.decode` (Bytes to `Val`) and `Cbor.encode` (`Val` back to Bytes) on one fixed document, in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 20,000 records
python3 run.py 5        # 5 runs
python3 run.py 1 50     # 1 run on a 50-record document (small smoke run)
```

You need `bend`, `cc` with Homebrew `libcbor` in `/opt/homebrew`, `cargo`, `npm`, `bun`, `node`, and `uv`. On the first run, Cargo fetches `ciborium`, `npm` installs `cbor-x` into `out/js`, and `uv` fetches `cbor2`. Binaries go to `out/`, which git ignores. The full run takes about 10 seconds. It exits non-zero if a build or a run fails, or if a checksum differs from the input's.

## Input

`run.py` writes `out/doc.cbor`: a map `{"count": N, "items": [record(0), ..., record(N-1)]}` in preferred serialization (RFC 8949 §4.1: shortest heads, definite lengths). With N = 20,000 it is 4,361,963 bytes. Each record is a map with text keys and holds:

- unsigned and negative integers in every head width, including 64-bit (`4294967296 + i*1000003`, `-4294967297 - i`)
- a text string, and a UTF-8 text string with 2-, 3-, and 4-byte characters
- a byte string of 0 to 39 bytes
- a double (`i + 0.1`)
- `true`, `false`, and `null`
- tag 1234 around an integer
- an empty array, an empty map, and nested arrays

Every program decodes the file into its library's dynamic value, then encodes that value. Only the two calls are timed. The checksum is `h = h*31 + b` (u32, wrapping) over the encoded bytes, plus their length. Each decoded value re-encodes to the input byte for byte, so every checksum must equal the input's: `1559034770` for 20,000 records and `1626627876` for 50. Both ops print the same checksum.

The document leaves out half and single floats, `undefined`, other simple values, and indefinite lengths. `cbor2` and `cbor-x` re-encode a decoded half or single as a double, and `ciborium`'s `Value` has no `undefined`, so those constructs would not survive a round trip in every library. The doubles are chosen so that no narrower float holds them exactly, and every encoder keeps them 8 bytes wide.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27. `python3 run.py 5`, median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| decode | 22.9 (1.3x) | 33.2 (1.8x) | 37.5 (2.1x) | 28.5 (1.6x) | 73.8 (4.1x) | 18.0 (1.0x) |
| encode | 6.6 (1.0x) | 7.3 (1.1x) | 36.5 (5.5x) | 29.8 (4.5x) | 83.1 (12.5x) | 29.0 (4.4x) |

Versions: Bend 2.0.32, Apple clang 17.0.0 with libcbor 0.13.0, rustc 1.91.0 with ciborium 0.2.2, Bun 1.3.14 and Node 24.0.1 with cbor-x 1.6.6, Python 3.14.6 with cbor2 6.1.4.

Bend's `IO.now` counts whole ms, so Bend times are integers. Since cbor 0.1.0.1, `encode` first walks the value to bound its steps, so the checker can prove it ends; that took encode from 24 ms to 29 ms. On the 50-record run, most ops take under 1 ms and the table has no ratios. The Bend binary peaked at about 200 MB RSS on the full document (`/usr/bin/time -l out/bend`).

## The calls

| language | decode | encode |
|---|---|---|
| Bend | `Cbor.decode` | `Cbor.encode` |
| C | libcbor `cbor_load` | `cbor_serialize_alloc` |
| Rust | `ciborium::de::from_reader::<Value>` | `ciborium::ser::into_writer` |
| JavaScript | cbor-x `Decoder({mapsAsObjects: true}).decode` | `Encoder({mapsAsObjects: true, useRecords: false, variableMapSize: true}).encode` |
| Python | `cbor2.loads` | `cbor2.dumps` |

cbor-x needs `useRecords: false` and `variableMapSize: true` to write plain maps with shortest length heads. Its defaults write a record extension or 16-bit map lengths. The text keys are not integer-like, so JavaScript objects keep their order.
