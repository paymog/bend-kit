# Router benchmark

This times `route` on one fixed route table and one fixed request list, in Bend, in C with [r3](https://github.com/c9s/r3), in Rust with [matchit](https://crates.io/crates/matchit), in JavaScript (Bun and Node) with `URLPattern`, and in Python with [Starlette](https://www.starlette.io/) routing.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `pkg-config`, `cargo`, `bun`, `node`, `uv`, `python3`, and r3 (`brew install r3` on macOS). Cargo fetches matchit 0.9.2, pinned by `rs/Cargo.lock`. `uv` fetches Starlette 1.7.0 on first run. No variant opens a socket or file. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails or the checksums disagree.

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

The 16 requests are in `requests()` in `bench.bend` and the same list in every other program. Eleven match a route and five match none: three have a wrong method, one is a truncated path, and one is an unknown path. Each program runs the 16 requests 10,000 times, which is 160,000 requests.

The checksum is `h = h*31 + x` in wrapping u32. For each request, `x` is the 1-based index of the matched route, or 0 for no match. Then each param value is folded in, one character at a time, in the route's param order. The checksum is `3019866368`.

## Results

Apple M4 Pro, macOS 26.6, 2026-09-28. Median of five runs (`python3 run.py 5`). Times are in ms for 160,000 requests; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| route | 34.1 (7.8x) | 4.4 (1.0x) | 498.8 (113.4x) | 1,151.7 (261.8x) | 431.4 (98.0x) | 977.9 (222.2x) |

Versions: Bend 2.0.32, Apple clang 17.0.0, r3 1.3.4, rustc 1.91.0, matchit 0.9.2, Bun 1.3.14, Node 24.0.1, Python 3.14.6, Starlette 1.7.0.

## The calls

- Bend: `bench.bend` calls `R.route(want, method, pattern, path)` from `../router.bend` for each route until one returns `Some`, then reads the params with `Map.get`.
- C: `bench.c` inserts each route with `r3_tree_insert_route(tree, METHOD_*, pattern, index)` and calls `r3_tree_compile` once. Per request it calls `match_entry_create(path)`, sets `request_method`, calls `r3_tree_match_route`, reads `entry->vars`, and frees the entry.
- Rust: `rs/main.rs` inserts each distinct pattern once into a `matchit::Router`, with the value a list of `(method, index)` in table order, as axum does. Per request it calls `router.at(path)`, takes the first entry whose method matches, and reads `params.iter()`.
- JavaScript: `bench.ts` compares the method with `!==`, then calls `URLPattern.exec({ pathname })` and reads `pathname.groups`. `URLPattern` is a WHATWG standard and a global in Bun and Node.
- Python: `bench.py` builds one `starlette.routing.Route(pattern, endpoint, methods=[method])` per route and an ASGI scope dict per request, before the timer. Per request it calls `route.matches(scope)` on each route in order until one returns `Match.FULL`, as Starlette's `Router` does, then reads `path_params`. Werkzeug is left out: its `Map` sorts rules by its own weights, not table order.

## Caveats

- `bench.ts`, `bench.c`, `rs/main.rs`, and `bench.py` build their patterns once, before the timer starts. `route` takes the pattern as a string and splits it on every call, so Bend pays that cost inside the timer.
- r3 and matchit are radix trees that match all routes in one walk and rank static segments over params; Bend, `URLPattern`, and Starlette try routes one by one. No request here matches two patterns, so both orders give the same route.
- Starlette compiles each pattern to a regular expression. `bench.py` calls `Route.matches` directly, skipping Starlette's ASGI app and middleware.
- r3 allocates a match entry and one string per captured param on every request.
- `URLPattern` compiles each pattern to a regular expression and supports much more syntax than `:name` segments.
- Bend drops empty segments, so it matches `/users/42/` and `//users/42` like `/users/42`. `URLPattern` does not. No request here has an empty segment.
- Bend strings are lists, one cell per character. JavaScript strings are flat buffers.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.
