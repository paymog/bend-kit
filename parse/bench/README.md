# Parser combinator benchmark

This times a JSON grammar written on parser combinators, on one fixed document. The Bend grammar is `../json.bend` on `Parse`. The other languages write the same grammar on a popular combinator library.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 4000 records
python3 run.py 5        # 5 runs
python3 run.py 1 40     # 1 run on a 40-record document; check this first after a change
```

You need `bend`, `cargo`, `bun`, and `uv`. Bun installs Parsimmon on first run, and `uv` fetches pyparsing. `run.py` writes the input to `out/doc.json` and the binaries to `out/`, which git ignores. It exits non-zero if a build fails, or if two languages print different checksums.

## Input

The input is the document from `json/bench`: `{"count": N, "items": [...]}` with N = 4000 records, pretty-printed by `json.dumps(indent=2)`, 1,361,421 bytes. Each record has a bool, a null, integers, a half, plain strings, a string with `\n`, `\t`, `\"`, and `\\` escapes, a nested object, and arrays.

Each program reads the file before the timer starts, and times the parse of the whole text. After the timer stops, it prints a checksum of the value as compact JSON with sorted keys: `h = h*31 + c` over the chars, in wrapping u32, plus the length. The checksum is `4114665117`, the same as the `json` bench.

## Results

M4 Pro, macOS 26.6.2, 2026-09-26. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest. Bend's peak RSS was 68 MB.

| op | Rust | Bun | Python | Bend |
|---|---:|---:|---:|---:|
| parse | 10.3 (1.0x) | 106.1 (10.3x) | 1,366.6 (132.6x) | 148.0 (14.4x) |

The hand-written state machine in `json/json.bend` took 42 ms on the same document (`json/bench`, Bend 2.0.28).

Versions: Bend 2.0.29, Rust 1.91.0 with nom 7.1.3, Bun 1.3.14 with Parsimmon 1.18.1, Python 3.14.6 with pyparsing 3.3.2.

## The libraries

| language | library | grammar |
|---|---|---|
| Bend | `Parse` | `../json.bend`: nesting through `Parse.rec` |
| Rust | nom | `rs/main.rs`: recursive `fn val` |
| JavaScript | Parsimmon | `bench.ts`: `P.createLanguage` |
| Python | pyparsing | `bench.py`: `pp.Forward` |

C has no popular parser combinator library, so it is left out.

## Caveats

- Bend strings are lists, one cell per char, and objects are `Map`s. The others use flat strings and hash or tree maps.
- The Rust program and Bend keep each number's text. JavaScript and Python convert numbers to doubles or ints.
- The Rust and Bend grammars decode string escapes char by char. The JavaScript and Python grammars match a whole string with one regex or `QuotedString`, then decode it.
- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- These are micro-benchmarks on one machine.
