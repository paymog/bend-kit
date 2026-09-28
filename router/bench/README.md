# Router benchmark

This times `route` on one fixed route table and one fixed request list, in Bend and in JavaScript (Bun and Node) with `URLPattern`.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 15 seconds. It exits non-zero if a build fails or the checksums disagree.

## Input

The table has 8 routes, tried in order. The first route whose method and path both match wins.

| # | method | pattern |
|---|---|---|
| 1 | GET | `/health` |
| 2 | GET | `/users` |
| 3 | POST | `/users` |
| 4 | GET | `/users/:id` |
| 5 | PUT | `/users/:id` |
| 6 | GET | `/users/:id/posts` |
| 7 | GET | `/users/:id/posts/:post` |
| 8 | GET | `/orgs/:org/repos/:repo/issues/:num` |

The 16 requests are in `requests()` in `bench.bend` and `REQUESTS` in `bench.ts`. Eleven match a route and five match none: three have a wrong method, one is a truncated path, and one is an unknown path. Each program runs the 16 requests 10,000 times, which is 160,000 requests.

The checksum is `h = h*31 + x` in wrapping u32. For each request, `x` is the 1-based index of the matched route, or 0 for no match. Then each param value is folded in, one character at a time, in the route's param order. The checksum is `3019866368`.

## Results

Apple M4 Pro, macOS 26.6.2, 2026-09-27. Median of three runs. Times are in ms for 160,000 requests; `Nx` is the multiple of the fastest variant.

| op | Bun | Node | Bend |
|---|---:|---:|---:|
| route | 505.1 (1.0x) | 1,157.6 (2.3x) | 985.7 (2.0x) |

Versions: Bend 2.0.31, Bun 1.3.14, Node 24.0.1.

## The calls

- Bend: `bench.bend` calls `R.route(want, method, pattern, path)` from `../router.bend` for each route until one returns `Some`, then reads the params with `Map.get`.
- JavaScript: `bench.ts` compares the method with `!==`, then calls `URLPattern.exec({ pathname })` and reads `pathname.groups`. `URLPattern` is a WHATWG standard and a global in Bun and Node.

C, Rust, and Python are left out. Their standard libraries have no route or path-pattern matcher.

## Caveats

- `bench.ts` builds each `URLPattern` once, before the timer starts. `route` takes the pattern as a string and splits it on every call, so Bend pays that cost inside the timer.
- `URLPattern` compiles each pattern to a regular expression and supports much more syntax than `:name` segments.
- Bend drops empty segments, so it matches `/users/42/` and `//users/42` like `/users/42`. `URLPattern` does not. No request here has an empty segment.
- Bend strings are lists, one cell per character. JavaScript strings are flat buffers.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.
