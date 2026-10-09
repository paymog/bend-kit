# Hairpin benchmark

This times two loops of 1000 sequential requests on one client against a local keep-alive server, in Bend (`Hairpin`) and in C, Rust, JavaScript (Bun and Node), and Python.

- `get_1000`: GETs with a base URL and a default header, on a reused connection.
- `retry_1000`: GETs of a URL that answers each request first with 503 and `Retry-After: 0`, then with 200. Each logical request takes one retry, so this times the retry path: classification, the retry policy, and a second attempt.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang` with libcurl, `cargo`, `bun`, `node`, and `uv`. Cargo fetches `reqwest`, `bun install --frozen-lockfile` fetches `ky` into `node_modules/` (git ignores it), and `uv` fetches `httpx` and `requests` on the first run. `run.py` starts `server.mjs` on Node at `127.0.0.1:47840` and stops it at the end. Binaries go to `out/`, which git ignores. The run exits non-zero if a build fails, or if two languages print different checksums.

## Input

The base URL is `http://127.0.0.1:47840/api/`. `get_1000` requests `item` with `x-bench: 1` as a default header; the server answers 200 with 1024 bytes when both are right, and 400 with no body otherwise. `retry_1000` requests `flaky`; the server answers 503 with `Retry-After: 0` and no body, then 200 with 1024 bytes, in turn.

The checksum sums the status and the body length of the final response of every request, in wrapping u32. A failed request adds 0. Both checksums are `1224000`: a client that does not retry ends half of its requests on a 503 and prints `863500`.

## The calls

| language | client | base URL | default header | retry |
|---|---|---|---|---|
| Bend | `Hairpin.get(c, "item")` | `Hairpin.base` | `Hairpin.header` | `Hairpin.retry(c, 2)` with `Hairpin.circuit` |
| C | libcurl, one easy handle | `curl_url_set` resolves `item` | `CURLOPT_HTTPHEADER` | none: libcurl does not retry on a status |
| Rust | `reqwest::blocking::Client` | `Url::join` | `default_headers` | `reqwest::retry::for_host`, 2 retries of a GET 503, no budget |
| JavaScript | `fetch` (undici in Node); `ky` for retries | `new URL("item", base)` | headers on each call | `ky` `retry: {limit: 2, statusCodes: [503]}` |
| Python | `httpx.Client`; `requests.Session` for retries | `base_url` | `headers` | urllib3 `Retry(total=2, status_forcelist=[503], backoff_factor=0)` |

Only Hairpin and httpx hold the base URL and the default headers in the client. The others resolve the URL and pass the headers in glue code. httpx retries only failed connects, so Python's retry row uses `requests` with urllib3's `Retry`, the usual way to retry on a status in Python. C has no `retry_1000` time.

## Results

M4 Pro, macOS 26.6.2, 2026-10-08. Median of five runs, milliseconds for 1000 requests; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| get_1000 | 35.0 (1.0x) | 41.0 (1.2x) | 61.6 (1.8x) | 127.4 (3.6x) | 227.1 (6.5x) | 80.8 (2.3x) |
| retry_1000 | - | 65.5 (1.0x) | 1,471.9 (22.5x) | 1,557.6 (23.8x) | 535.9 (8.2x) | 198.7 (3.0x) |

Versions: Bend 2.0.35 with `hairpin` 0.2.0.0 and `http` 0.23.0.1, Apple clang 17.0.0 with libcurl 8.7.1, rustc 1.91.0 with reqwest 0.12.28, Bun 1.3.14, Node 24.0.1, ky 2.1.0, Python 3.14.6 with httpx 0.28.1, requests 2.34.2, and urllib3 2.6.3.

## Caveats

- The server is Node, so every client pays the same server cost.
- Hairpin sends `accept-encoding: gzip, deflate, br, zstd` and checks for the brotli and zstd libraries on each request. The server sends no coding.
- Hairpin reads the clock only when a decision needs it: with no deadline and no breaker, a success reads none. `retry_1000` has a breaker, so it reads the monotonic clock, the wall clock (for `Retry-After`), and the random source on each 503.
- ky waits on a timer even for `Retry-After: 0`, so its row is mostly timer delay.
- Bend times itself with `Time.mono.raw`, a nanosecond clock.
- These are micro-benchmarks on one machine.
