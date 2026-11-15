# Gateway benchmark

This times the hot path of the gateway: a guarded cache hit. Each request is authorized, takes one unit of admission, reads a fresh entry, and gives the unit back. It compares `gateway` against the obvious loop over each language's standard hash map.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend` (2.0.36, the CI pin), `cargo`, `bun`, `node`, and `python3`. Nothing is installed: every baseline uses only its standard library. Binaries go to `out/`, which git ignores. `run.py` exits non-zero if a build fails, or if two programs disagree on the checksum.

## The op

Each program fills 64 keys, `k0` to `k63`, with the key itself as the value. Then it runs R = 2^10 rounds; a round requests every key 8 times. That is 524,288 requests, and every one is allowed and hits. The checksum is the sum of the lengths of the values served, in u32.

| language | authorize | admit | read |
|---|---|---|---|
| Bend | `Az.granted` on a deny-overrides policy (in `G.begin`) | `Res.reserve`, `Res.combine`, then `Res.split` and `Res.release` | `Cache.read` |
| Rust | `roles.iter().any(...)` | a `u32` counter | `std::collections::HashMap::get`, then an expiry compare |
| JavaScript | `Array.includes` | a counter | `Map.get`, then an expiry compare |
| Python | `in` on a list | a counter | `dict.get`, then an expiry compare |

C has no standard hash map, and no single library is the obvious choice, so C is left out.

## Results

M4 Pro, macOS 26.6.2, 2026-10-13. Five runs (`python3 run.py 5`), median, in ms. The load average was about 45 to 60 during the runs, from other work on the machine, so treat the numbers as rough.

Versions: Bend 2.0.36, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| guarded hit | 5.9 | 11.0 | 14.0 | 83.3 | 431.9 |

Every program prints the checksum 1490944.

## Reading it

- The work differs. The baselines check a role and move a counter. `gateway` evaluates an `authz` policy tree, keeps the lent units in an affine joined grant, and reads a `cache` slot with generations. Those are what the laws are about.
- Keys are Bend `String`s, which are lists of characters. A cache read walks an `OMap` and compares keys character by character; the baselines hash the key once.
- The Bend loop passes clock 0, because the pure core takes the clock as an argument. The baselines compare against a constant too.

## Caveats

- Bend times itself with `Time.mono`. It reads R from argv, so the work cannot run before the clock starts.
- One machine, one size, every request a hit. The served app adds the Camber dispatch, one `Gate` actor call, and the socket; this bench does not time those.
