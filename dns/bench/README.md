# DNS benchmark

Times `Dns.query` and `Dns.answer` on one fixed message, with no socket, against a popular DNS message library in C, Rust, JavaScript, and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `cargo`, `npm`, `bun`, `node`, `uv`, and `python3`. The runner builds Rust with `--locked` against `rs/Cargo.lock`, installs `dns-packet` 5.6.1 and its pinned dependency with `npm ci` from `js/package-lock.json`, and runs Python with `uv run --with dnspython==2.8.0`. Binaries and packages go to `out/`, which git ignores. It exits non-zero if a build fails or the checksums disagree.

## The ops

Each op runs 100,000 rounds. Round `i` uses the id `i & 65535`, so no round can reuse the work of another.

| op | work | checksum |
|---|---|---|
| `build` | build the A/IN query for `www.example.com` with recursion desired (33 bytes) | sum of every query byte |
| `parse` | check the header of a 49-byte response, skip the question, and return the first A/IN answer (`93.184.216.34`, named by a pointer) as dotted text | sum of every character of the dotted text |

Checksum math is u32 and wraps. The response is the id followed by the same 47 bytes in every variant: `zero()` in `bench.bend` (with a zero id), `TAIL` in the others.

Every library builds the query from the name as text and the type, with recursion desired and no EDNS, so every variant emits the same 33 bytes. To parse, the program checks the id, QR, opcode, TC, and rcode, and returns the first A/IN answer. hickory-proto, dns-packet, and dnspython decode every record into objects first; libresolv indexes the sections and reads the answer in place.

- C: `res_mkquery` builds, and `ns_initparse` and `ns_parserr` parse. Both come from libresolv, which ships with macOS and glibc. `res_mkquery` sets a random id, so the program overwrites the first two bytes. `snprintf` makes the dotted text.
- Rust: `rs/main.rs` with [hickory-proto](https://crates.io/crates/hickory-proto) 0.26.3. `Message::new` plus `add_query` and `to_vec` build; `Message::from_vec` parses. `Ipv4Addr`'s `Display` makes the dotted text.
- Bun and Node: `bench.mjs` with [dns-packet](https://www.npmjs.com/package/dns-packet) 5.6.1. `encode` builds; `decode` parses and returns the address as dotted text.
- Python: `bench.py` with [dnspython](https://www.dnspython.org/) 2.8.0. `make_query` plus `to_wire` build; `from_wire` parses, and the A rdata's `address` is the dotted text.
- Bend: `bench.bend` calls `Dns.query` and `Dns.answer` from `../dns.bend`. Both use `Bytes`. Each parse round builds its message with `Bytes.from_string` and writes the id with `Bytes.set.u16be`, because `Dns.answer` consumes its buffer.

## Results

M4 Pro, macOS 26.6.2, 2026-09-29. Median of five runs (`python3 run.py 5`). Times are in ms for 100,000 rounds; `Nx` is the multiple of the fastest variant.

Versions: Bend 2.0.32, Apple clang 17.0.0, rustc 1.91.0, hickory-proto 0.26.3, Bun 1.3.14, Node 24.0.1, dns-packet 5.6.1, @leichtgewicht/ip-codec 2.0.5, Python 3.14.6, dnspython 2.8.0.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| build | 19.8 (1.0x) | 32.1 (1.6x) | 44.1 (2.2x) | 44.0 (2.2x) | 2,122.2 (107.2x) | 45.8 (2.3x) |
| parse | 13.4 (1.0x) | 21.2 (1.6x) | 60.6 (4.5x) | 61.8 (4.6x) | 3,015.3 (225.0x) | 20.6 (1.5x) |

Checksums: build 167500816, parse 65900000. All variants agree.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- Before `Bytes` (dns 0.4.0.2), Bend messages were `String`s, one `Char` list cell per byte: build took 91.9 ms and parse 101.9 ms.
