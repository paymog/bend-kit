# JSON benchmark

This times `Json.parse.bytes` and `Json.encode.bytes` on one fixed document, in Bend and in C, Rust, JavaScript (Bun and Node), and Python. Bend also times `Json.unique.keys` between parsing and encoding.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 4000 records
python3 run.py 5        # 5 runs
python3 run.py 1 40     # 1 run on a 40-record document; check this first after a change
```

You need `bend`, `cc`, `pkg-config`, `cJSON`, `cargo`, `bun`, `node`, and `python3`. On the first run, Cargo fetches `serde_json` at the versions pinned in `rs/Cargo.lock`. `run.py` writes the input to `out/doc.json` and the binaries to `out/`, which git ignores. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

`run.py` writes `{"count": N, "items": [...]}` with N = 4000 records, pretty-printed by `json.dumps(indent=2)`: 1,361,421 bytes. Each record has a bool, a null, integers, a half (`i + 0.5`), plain strings, a string with `\n`, `\t`, `\"`, and `\\` escapes, a nested object, and arrays.

The document is ASCII only, and its numbers are integers or exact halves. So every encoder prints the same compact text.

Each program reads the file before any timer starts. `parse.bytes` starts from the file's bytes, and `encode.bytes` ends with UTF-8 bytes; in JavaScript and Python that includes the UTF-8 decode or encode. C and Rust parse the bytes directly and encode straight to bytes. Bend packs the file into `Bytes` before the timer starts. After each timer stops, the program prints a checksum of the compact encoding: `h = h*31 + c` over the bytes, in wrapping u32, plus the length. A Bend `Val` can be used only once, so Bend prints the checksum of its one `encode.bytes` output for both ops. All six variants print `4114665117` for each op.

## Results

M4 Pro, macOS 26.6, 2026-09-28. Median of five runs (`python3 run.py 5`). Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| parse.bytes | 3.2 (1.4x) | 3.1 (1.4x) | 2.3 (1.0x) | 2.8 (1.2x) | 4.6 (2.0x) | 4.8 (2.2x) |
| encode.bytes | 3.1 (4.9x) | 0.6 (1.0x) | 0.9 (1.4x) | 1.4 (2.2x) | 4.1 (6.5x) | 3.9 (6.2x) |

Before strings, numbers, and keys were `Bytes` (json 0.4.0.0, same machine and Bend version), Bend took 12 ms to parse and 9 ms to encode. The parser takes a run of whitespace, plain string bytes, or digits in one inner loop. On a document ten times as big (`python3 run.py 1 40000`), that cut `parse.bytes` from 49 ms to 32 ms. The encoder walked a work list until json 0.5.0.2; it now recurses on the `Val`, which took `encode.bytes` from 5.9 ms to 3.9 ms.

Versions: Bend 2.0.32, Apple clang 17.0.0, cJSON 1.7.19, rustc 1.91.0, serde_json 1.0.151, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## Packed-word read experiment (2026-09-29)

The parser was not changed. A fresh run on the 1,361,421-byte document measured `parse.bytes` at 5.0 ms before and 5.0 ms after the decision (the same implementation; median of five runs). A native Bend probe summed every input byte with `Bytes.peek`, then summed the same bytes while retaining a word and loading only at four-byte boundaries. Both sums were 72,604,734. Over five warmed runs, the medians were 0.249 ms for `Bytes.peek` and 0.565 ms for the cached-word loop. The entire direct scan cost about 0.25 ms, versus 5.0 ms for parsing; caching added a branch per byte and was slower in isolation. We kept the simpler parser.

## The calls

| language | parse.bytes | encode.bytes |
|---|---|---|
| Bend | `Json.parse.bytes` | `Json.encode.bytes` |
| C | cJSON `cJSON_ParseWithLength` | `cJSON_PrintUnformatted` |
| Rust | `serde_json::from_slice::<Value>` | `serde_json::to_vec` |
| JavaScript | `TextDecoder` then `JSON.parse` | `JSON.stringify` then `TextEncoder` |
| Python | `json.loads` on `bytes` | `json.dumps(v, separators=(",", ":"), ensure_ascii=False)`, then `.encode()` |

## Caveats

- Bend objects are lists of fields in document order, and so are cJSON objects. `serde_json::Value` objects are sorted maps (the input's keys are already sorted), and JavaScript and Python use hash maps.
- Bend keeps each number's text. C and JavaScript convert numbers to doubles, Rust and Python to ints or doubles, and they print them back.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.

## Strict bounded parsing (0.5.1.0)

`Json.parse.strict.bytes(body, cap)` parses UTF-8 bytes with the same state
machine as `Json.parse.bytes`. It rejects unpaired surrogate escapes instead
of replacing them. `cap` counts nested arrays and objects, including empty
containers; a scalar has depth zero. Choose `64` for Camber's default.
The opening-container transition rejects a depth overflow before parsing
its contents, not by traversing a completed tree. Both policies preserve
number text and ordered repeated object entries. Applications still own
duplicate-key validation. `parse.bytes` retains the separate RFC §8.2
replacement policy required by the unchanged human-owned laws.

Verification with Bend 2.0.35:

```sh
scripts/check.sh json
bend json/check.bend -o /tmp/json-325-native
/tmp/json-325-native --threads 1
bend json/check.bend -o /tmp/json-325.js
bun /tmp/json-325.js
scripts/publish.sh --check json
(cd json/bench && python3 run.py 1 40)
```

The package entry and all existing plus five added concrete proofs print
`ALL PROOFS CHECK`; there are no unsafe/foreign proof exclusions in this
package gate. These are pure parsing proofs, not host-IO attestations.
The compiled native and JS consumers each pass all 31 strict cases: lone
high/low surrogates (also in keys), valid pairs, array/object/empty depth
64 versus 65, configured cap 65, cap zero, sibling depth restoration,
depth 4,096 rejection, invalid UTF-8/BOM/empty rejection, exact number
spellings, valid fixtures, and preserved repeated entries. The oversized
case returns `None` at the opening transition, without building that
subtree. This does not bound aggregate admitted memory or input-buffer size.

The existing 40-record, 13,312-byte benchmark agrees across C, Rust, Bun,
Node, Python, and Bend on checksum `356421233` for parsing and encoding.
One-run native Bend times are 0.2 ms parse and 0.1 ms encode; this is a small
correctness smoke, not a replacement for the historical performance results.
The publication check reports `bend-kit-json@0.5.1.0 will publish`; merge CI
owns publication.

## Key uniqueness cost measurement

The existing Bend benchmark applies `unique.keys` to the parsed value and times
that call separately. It encodes the returned value, prints the same checksum
for all three phases, and requires a true verdict. The runner compares that
encoding checksum with the existing C, Rust, Bun, Node and Python outputs. The
key-check timing is a Bend-only measurement; the other programs measure their
existing parse and encode operations.

The optional third runner argument writes one object with that many distinct
ASCII keys. Keys are `k` followed by an eight-digit index, inserted in increasing
order. Values are the corresponding integers. Each invocation writes and reads
one fixed document using the existing benchmark programs.

```sh
python3 run.py 1 40
python3 run.py 3
for fields in 8 16 32 64 128 256 512; do
  python3 run.py 3 0 "$fields"
done
```

These field counts select measurement fixtures.

Measured on 2026-10-10 on an AMD EPYC 7551 with 32 cores and 64 logical CPUs,
Linux 6.14.0-37-generic x86_64. Existing host workloads continued during the
measurements. Versions: Bend 2.0.36, Ubuntu clang 19.1.1 for Bend native builds,
GCC 13.3.0 for the C variant, cJSON 1.7.19, rustc 1.94.1, serde_json 1.0.151,
Bun 1.3.13, Node 24.13.0 and Python 3.12.3.

The small input used one run. The ordinary input and each field-count fixture
used three runs and report medians. All six variants completed every invocation
and agreed on the parse and encode checksum. The Bend uniqueness phase prints
the checksum of that same encoded result. Consumer cases separately check the
uniqueness verdict and the returned value.

| Input | Bytes | Runs | Bend parse ms | Bend uniqueness ms | Bend encode ms | Checksum | Runner max RSS KiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| 40 records | 13312 | 1 | 0.9 | 0.758 | 0.8 | 356421233 | 719072 |
| 4000 records | 1361421 | 3 | 19.8 | 21.676 | 15.7 | 4114665117 | 700296 |
| 8 fields | 146 | 3 | 0.3 | 0.227 | 0.3 | 1815190181 | 687508 |
| 16 fields | 296 | 3 | 0.4 | 0.273 | 0.4 | 2421764943 | 734180 |
| 32 fields | 600 | 3 | 0.3 | 0.421 | 0.5 | 2298712047 | 733520 |
| 64 fields | 1208 | 3 | 0.4 | 0.959 | 0.5 | 1488746991 | 721424 |
| 128 fields | 2452 | 3 | 0.4 | 3.046 | 0.5 | 3549227667 | 700712 |
| 256 fields | 5012 | 3 | 0.2 | 5.496 | 0.3 | 3590427347 | 733060 |
| 512 fields | 10132 | 3 | 0.7 | 27.684 | 0.3 | 808511251 | 731260 |

The runner reports parse and encode times to one decimal place and uniqueness
to three decimal places. Maximum RSS covers each complete runner invocation,
including builds and all language child processes. It measures that invocation's
resource use. The key scan performs `n * (n - 1) / 2` comparisons in an object
with distinct keys, and rebuilds its member list during the scan. Key byte length
adds comparison work. These measurements describe this implementation and host.
