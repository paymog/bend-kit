# URL benchmark

This times `Url.parse` and `Url.encode` on one fixed origin-form path list, in Bend and in Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, `bun`, `node`, and `python3`. Cargo fetches `url` and `percent-encoding` on the first run. Binaries go to `out/`, which git ignores. The run takes about 10 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

The list has 16 strings (15 valid paths plus `nope`, which does not start with `/`). Each op runs 10,000 rounds over the full list: 160,000 parses, and 150,000 encodes (one encode per successful parse per round).

| # | path |
|---|---|
| 1 | `/` |
| 2 | `/health` |
| 3 | `/users` |
| 4 | `/users/42` |
| 5 | `/users/42/posts` |
| 6 | `/users/42/posts/99` |
| 7 | `/api/v1/items?page=2&sort=name` |
| 8 | `/x?a=1&b=2` |
| 9 | `/a%20b` |
| 10 | `/a%20b?q=hello%20world` |
| 11 | `/orgs/paymog/repos/bend-kit/issues/74` |
| 12 | `/search?q=hello+world&limit=10` |
| 13 | `/file/name%2Fwith%2Fslashes` |
| 14 | `/?empty=` |
| 15 | `/path?u=%2Fenc%2Foded` |
| 16 | `nope` (invalid) |

The parse checksum sums, over every parse, the decoded path length plus name length + value length + 1 per query pair. Failed parses add 0. The encode checksum sums `h = h*31 + c` over each encoded string (u32, wrapping), plus the string length, again wrapping. Both checksums are `2240000` and `2238082800`.

Query parsing does not treat `+` as space (RFC 3986 query, not form-urlencoded). Encoders write query keys in sorted order to match Bend's `Map.to_list`.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27. Median of three runs. Times are in ms for 10,000 rounds; `Nx` is the multiple of the fastest variant for that op.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| parse | 40.6 (1.3x) | 31.7 (1.0x) | 32.3 (1.0x) | 128.6 (4.1x) | 55.0 (1.7x) |
| encode | 10.8 (1.0x) | 53.5 (5.0x) | 70.3 (6.5x) | 289.1 (26.9x) | 90.8 (8.4x) |

Versions: Bend 2.0.31, rustc 1.91.0 with url 2.5.8 and percent-encoding 2.3.2, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | parse | encode |
|---|---|---|
| Bend | `Url.parse` | `Url.encode` |
| Rust | `Url::parse("http://x").join(origin)`, `path()` percent-decoded, query split by hand | `percent-encoding`, sorted query keys |
| JavaScript | split on `?` and `&`, `decodeURIComponent` | `encodeURIComponent`, sorted query keys |
| Python | `urlsplit`, `unquote`, manual query split | `quote` and `urlencode` with `quote_via=quote`, sorted keys |

C is left out. The C standard library has no URL parser for origin-form paths, and adding one would reimplement the Bend package.

Rust uses the `url` crate to resolve origin-form paths against a fixed base. `query_pairs` applies form-urlencoded rules (`+` as space), which disagrees with Bend, so the query string from `Url::query()` is split and percent-decoded by hand. `Url::path()` is percent-decoded the same way for the path checksum.
