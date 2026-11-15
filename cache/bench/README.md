# Cache benchmark

This times the hot path of a keyed cache: store a fetched value for a key, then read it back while it is fresh. It compares `cache` against TTL caches in Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend` (2.0.36, the CI pin), `cargo`, `bun`, `node`, `npm`, and `python3`. `run.py` installs `lru-cache@11.5.3` into `out/js` and `cachetools==7.2.1` into `out/py`, and cargo fetches `moka`. Binaries go to `out/`, which git ignores. It exits non-zero if a build or install fails, or if two programs disagree on the checksum.

## The op

Each program runs R = 2^12 rounds over 64 keys, `k0` to `k63`. A round stores version `i + 1` for every key, then reads every key 8 times. That is 64 stores and 512 reads a round, 2,359,296 operations in all. Every read hits. The checksum is the sum of the values read, in u32.

| language | store | read |
|---|---|---|
| Bend | `Cache.start`, then `Cache.complete` with `Found{v, v}` | `Cache.read` |
| Rust | `moka::sync::Cache::insert` | `get` |
| Python | `cachetools.TTLCache.__setitem__` | `get` |
| JavaScript | `lru-cache` `set` | `get` |

No standard library has a cache with expiry, so each baseline is the most used TTL cache for its language: `moka` 0.12.16 for Rust, `cachetools` 7.2.1 for Python, and `lru-cache` 11.5.3 for JavaScript. C has neither a standard nor a dominant TTL cache library, so C is left out. Each baseline has a TTL of about 11 days, and the Bend policy has a TTL of 1,000,000 clock units, so nothing expires.

## Results

M4 Pro, macOS 26.6.2, 2026-10-11. Five runs (`python3 run.py 5`), median, in ms. The load average was about 20 during the runs, from other work on the machine, so treat the numbers as rough.

Versions: Bend 2.0.36, rustc 1.91.0, moka 0.12.16, Bun 1.3.14, Node 24.0.1, lru-cache 11.5.3, Python 3.14.6, cachetools 7.2.1.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| fill + read | 225.7 | 68.7 | 50.7 | 3,371.6 | 2,057.8 |

Every program prints the checksum 1048576.

## Reading it

- The work differs. `cache` also issues a generation for each fetch and checks it at completion; the baselines do not. The baselines read the clock on each operation; the Bend loop passes clock 0, because the pure core takes the clock as an argument.
- Keys are Bend `String`s, which are lists of characters. A lookup walks an `OMap` and compares keys character by character. `lru-cache` and `moka` hash the key once. A cache keyed by a `U32` or by `Bytes` would be faster; this one keeps `String` keys because config keys and URLs are short text.
- `moka` is thread-safe and pays for synchronization on each call. The Bend loop has one owner and takes no lock.

## Caveats

- Bend times itself with `Time.mono`. It reads R from argv, so the work cannot run before the clock starts.
- One machine, one size, every read a hit.
