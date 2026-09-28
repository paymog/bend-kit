# Hairpin benchmark

This times 1000 sequential GETs on one client against a local keep-alive server, in Bend (`Hairpin.get`) and in C, Rust, JavaScript (Bun and Node), and Python. Each client has a base URL and a default header, and reuses its connection.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang` with libcurl, `cargo`, `bun`, `node`, and `uv`. Cargo fetches `reqwest` and `uv` fetches `httpx` on the first run. `run.py` starts `server.mjs` on Node at `127.0.0.1:47840` and stops it at the end. Binaries go to `out/`, which git ignores. The run exits non-zero if a build fails, or if two languages print different checksums.

## Input

The base URL is `http://127.0.0.1:47840/api/` and each request is for `item`, so the URL is `http://127.0.0.1:47840/api/item`. Each request sends `x-bench: 1` as a default header. The server answers 200 with 1024 bytes when both are right, and 400 with no body otherwise.

The checksum sums the status and the body length of every response, in wrapping u32. A failed request adds 0. The checksum is `1224000`.

## The calls

| language | client | base URL | default header |
|---|---|---|---|
| Bend | `Hairpin.get(c, "item")` | `Hairpin.base` | `Hairpin.header` |
| C | libcurl, one easy handle | `curl_url_set` resolves `item` | `CURLOPT_HTTPHEADER` |
| Rust | `reqwest::blocking::Client` | `Url::join` | `default_headers` |
| JavaScript | `fetch` (undici in Node) | `new URL("item", base)` | headers on each call |
| Python | `httpx.Client` | `base_url` | `headers` |

Only Hairpin and httpx hold the base URL and the default headers in the client. The others resolve the URL and pass the headers in glue code.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27. Median of three runs, milliseconds for 1000 requests; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| get_1000 | 37.3 (1.0x) | 43.7 (1.2x) | 47.9 (1.3x) | 143.2 (3.8x) | 249.5 (6.7x) | 77.3 (2.1x) |

Versions: Bend 2.0.31 with `hairpin` 0.1.0.0 and `http` 0.23.0.0, Apple clang 17.0.0 with libcurl 8.7.1, rustc 1.91.0 with reqwest 0.12.28, Bun 1.3.14, Node 24.0.1, Python 3.14.6 with httpx 0.28.1.

## Caveats

- The server is Node, so every client pays the same server cost.
- Hairpin sends `accept-encoding: gzip, deflate, br, zstd` and checks for the brotli and zstd libraries on each request. The server sends no coding.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.
