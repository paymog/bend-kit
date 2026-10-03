# Router benchmark

This times prepared route resolution on one fixed table and request list in Bend, C with [r3](https://github.com/c9s/r3), Rust with [matchit](https://crates.io/crates/matchit), JavaScript (Bun and Node) with `URLPattern`, and Python with [Starlette](https://www.starlette.io/) routing.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `pkg-config`, `cargo`, `bun`, `node`, `uv`, `python3`, and r3 (`brew install r3` on macOS). Cargo fetches matchit 0.9.2, pinned by `rs/Cargo.lock`. `uv` fetches Starlette 1.7.0 on first run. No timed variant opens a socket or file. Binaries go to `out/`, which git ignores. The runner reuses Camber's host guard: commands have a 180-second deadline and a sampled 20 GiB RSS limit. Every trial must produce checksum `3019866368`.

## Input

The table has eight registrations. Bend prepares patterns and method sets before timing, chooses the most specific path first, then chooses its method. This corpus has no overlapping path shapes, so its outcomes also agree with the other controls' selection rules.

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

## Historical pairwise results

Apple M4 Pro, macOS 26.6, 2026-09-28. Median of five runs (`python3 run.py 5`). Times are in ms for 160,000 requests; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| route | 34.1 (7.8x) | 4.4 (1.0x) | 498.8 (113.4x) | 1,151.7 (261.8x) | 431.4 (98.0x) | 977.9 (222.2x) |

Versions: Bend 2.0.32, Apple clang 17.0.0, r3 1.3.4, rustc 1.91.0, matchit 0.9.2, Bun 1.3.14, Node 24.0.1, Python 3.14.6, Starlette 1.7.0.

## The calls

- Bend: `bench.bend` calls `R.prepare` once before timing, then `R.resolve` per request. A selected action carries its route index and capture-name order. It reads captures with `Map.get`; a miss or method failure folds zero.
- C: `bench.c` inserts each route with `r3_tree_insert_route(tree, METHOD_*, pattern, index)` and calls `r3_tree_compile` once. Per request it calls `match_entry_create(path)`, sets `request_method`, calls `r3_tree_match_route`, reads `entry->vars`, and frees the entry.
- Rust: `rs/main.rs` inserts each distinct pattern once into a `matchit::Router`, with the value a list of `(method, index)` in table order, as axum does. Per request it calls `router.at(path)`, takes the first entry whose method matches, and reads `params.iter()`.
- JavaScript: `bench.ts` compares the method with `!==`, then calls `URLPattern.exec({ pathname })` and reads `pathname.groups`. `URLPattern` is a WHATWG standard and a global in Bun and Node.
- Python: `bench.py` builds one `starlette.routing.Route(pattern, endpoint, methods=[method])` per route and an ASGI scope dict per request, before the timer. Per request it calls `route.matches(scope)` on each route in order until one returns `Match.FULL`, as Starlette's `Router` does, then reads `path_params`. Werkzeug is left out: its `Map` sorts rules by its own weights, not table order.

## Caveats

- Every variant builds its route patterns before timing. Bend validates and decodes each raw target inside the timer; the controls receive pathname inputs and do not implement the same strict target/query contract.
- r3 and matchit are radix trees. Bend scans prepared paths; `URLPattern` and Starlette try routes one by one. No request here matches two path shapes, so all selection rules agree on this corpus.
- Starlette compiles each pattern to a regular expression. `bench.py` calls `Route.matches` directly, skipping Starlette's ASGI app and middleware.
- r3 allocates a match entry and one string per captured param on every request.
- `URLPattern` compiles each pattern to a regular expression and supports much more syntax than `:name` segments.
- Current Bend preserves slash distinctions and validates percent escapes and UTF-8. The historical pairwise implementation collapsed empty segments. This corpus has no escapes, queries, or empty segments and does not benchmark those differences.
- Bend strings are lists, one cell per character. JavaScript strings are flat buffers.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.

## Prepared-router results

Apple M4 Pro, macOS 26.6.2, 2026-10-02. Each run used three trials per variant. Times are median milliseconds for 160,000 requests. The final runner checks the fixed checksum on every trial.

| Run | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| Initial cutover | 33.5 | 4.3 | 524.9 | 1,148.7 | 457.9 | 479.2 |
| Final checksum-guarded run | 33.1 | 4.2 | 513.0 | 1,170.1 | 444.3 | 472.5 |

Versions: Bend 2.0.34, Apple clang 17.0.0, r3 1.3.3, rustc 1.91.0, matchit 0.9.2, Bun 1.3.14, Node 24.0.1, Python 3.14.6, Starlette 1.7.0. The historical result used another Bend version; this is not an isolated attribution of speedup to preparation.

## Prepared routing contract

The local `router` release is `0.2.0.0`. CI publishes it after merge; no manual publication is required. Existing hub hashes refer to the earlier pairwise API.

- `Entry<A>{method, pattern, action, groups}` carries a copyable action and ordered group IDs, not a closure or resource handle.
- `prepare(~A, entries)` returns `Result<Error, Table<A>>`. Construction rejects invalid patterns/method tokens, duplicate method/shape pairs, repeated parameter names, and conflicting group ancestry for one shape.
- A pattern is `/` or literal/whole-parameter segments. Names match `[A-Za-z_][A-Za-z0-9_]*`. One final empty segment is allowed; interior empty segments are rejected. Literal text is decoded Unicode, with no NUL or `/`.
- `resolve(~A, table, method, raw_target)` returns a parsed target and `Found`, `NotFound`, `MethodMissing`, or generated `Options`. Target errors return `BadTarget`.
- Path selection precedes method selection. Literals outrank parameters at the first differing segment, independent of registration order. Each method retains its own parameter names.
- Matching preserves case, interior/trailing slashes, and dot segments. Parameters require nonempty segments. Targets support origin form and absolute form; an empty absolute path becomes `/`. Only OPTIONS accepts `*`.
- Raw targets must be printable ASCII without `#`. Path segments split before one strict UTF-8 percent-decoding pass; malformed escapes, NUL, and decoded `/` fail. Path `+` stays literal.
- Parsed query fields retain duplicates and order, split at the first `=`, ignore empty fields, allow empty keys, and decode `+` as space. Invalid UTF-8, escapes, or NUL fail.
- Explicit HEAD/OPTIONS win. Otherwise HEAD selects GET, and OPTIONS returns the path's sorted, deduplicated Allow set. A known path without a method returns that same Allow set with `MethodMissing`. `OPTIONS *` uses the union across the table.
- Results retain group ancestry, but the caller runs policy, maps HTTP outcomes, replaces Host from absolute authority, and suppresses HEAD bodies at transport. `Found.method` describes the selected handler; the request's original method must remain intact.
- `describe(~A, table)` returns method, pattern, ancestry, and method-specific patterns hidden by more-specific overlapping routes, without serving.
- `route(want, method, pattern, target)` remains a pairwise operation using the same validation and capture implementation. It has no generated-method or table-precedence behavior, and `*` does not match a path pattern.

Use `prepare` to construct tables. Bend exposes data constructors, so the type is not an unforgeable validation certificate. Preparation merges shapes in O(routes²); resolution scans O(routes × segments). These are measured baseline choices, not an indexed-router claim.

`bend router/check.bend` exercises the new behavior, including reverse registration order and path-first method hiding. Native and JavaScript builds of that check also pass. The unchanged human-owned laws cover only their original concrete literal fixtures; they do not prove the new prepared-table or target-parser contract.
