# Regex benchmark

Times `Regex.is_match` and `Regex.find` on fixed inputs against POSIX `regex.h`, Python `re`, and JavaScript `RegExp`.

## Run

```sh
python3 run.py      # 3 runs per case, median; Bend smoke (4096 code points) first
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `python3`, `bun`, and `node`. Binaries go to `out/`, which git ignores. `run.py` exits non-zero if a build fails or the checksums disagree. The `redos` case uses a 10 s per-run timeout; backtracking engines that hang are recorded as `timeout`.

## Input

Text is built deterministically at **N = 2^20** code points (about 1 MiB of ASCII):

1. Fill with `x`.
2. At **N − 50**, write `user@host.com` (13 code points).
3. At **N − 20**, write `helloworld12` (12 code points).

The ReDoS input is **100 000** `a` with no trailing `b`. The `large` input is **1000** `x` then one `y`.

## Cases

| case | Bend / Python / JS pattern | POSIX ERE (C) | work | checksum |
|---|---|---|---|---|
| `is_match` | `hello\w+` | `hello[[:alnum:]_]+` | is there a match (late in the text) | 1 if a match, else 0 |
| `is_match_early` | `x` | `x` | is there a match (at position 0) | 1 if a match, else 0 |
| `is_match_live` | `xy` | `xy` | is there a match (none; each char can start one) | 0 |
| `find_captures` | `(\w+)@(\w+)\.com` | `([[:alnum:]_]+)@([[:alnum:]_]+)\.com` | leftmost match with two captures | hash of groups 0–2 spans |
| `find_early` | `(x)x` | `(x)x` | leftmost match with one capture, at position 0 | hash of groups 0–1 spans |
| `redos` | `(a*)*b` | `(a*)*b` | no match on 100k `a` | 0 |
| `large` | `(?:x?){1000}y` | `((x?){250}){4}y` | about 2000 instructions; each char walks a closure over most of them | u32 hash of group-0 span |

Hash: for each group, if missing then `h = h * 31`; else `h = h * 31 + start` then `h = h * 31 + end` (u32 wrap). Positions are byte offsets in every language; the input is ASCII. Bend times `Regex.find.bytes` and `Regex.is_match.bytes` on a `Bytes` buffer built before the clock starts. The `is_match` cases use `Regex.is_match.bytes` in Bend, `REG_NOSUB` in C, `search(...) is not None` in Python, and `RegExp.test` in JavaScript.

Compile the pattern **outside** the timed region. Bend uses a native build (`bend bench.bend -o out/bend`); the checker runner is not used for the 1 MiB input.

## Rust

Rust's standard library has no regular expression engine, so Rust is left out.

## Results

Apple M4 Pro, macOS, 2026-09-26. Median of three runs (`python3 run.py 3`). Times are ms for one match on the 1 MiB text (or 100k `a` for `redos`, 1001 chars for `large`).

Versions: Bend 2.0.29, Apple clang 17.0.0, Python 3.14.6, Bun 1.3.14, Node v24.0.1.

| op | C | Python | Bun | Node | Bend |
|---|---:|---:|---:|---:|---:|
| is_match | 0.0 | 0.3 | 0.2 | 0.2 | 1.0 |
| is_match_early | 0.0 | 0.0 | 0.1 | 0.1 | 0.0 |
| is_match_live | 9.3 | 1.0 | 0.1 | 7.8 | 78.0 |
| find_captures | 15.8 | 2.8 | 0.8 | 0.7 | 214.0 |
| find_early | 0.0 | 0.0 | 0.2 | 0.2 | 0.0 |
| redos | 3.1 | timeout | 878.7 | timeout | 21.0 |
| large | 2,301.4 | 0.0 | 0.1 | 0.1 | 931.0 |

Checksums (1 MiB text; 1001 chars for `large`): `is_match` 1, `is_match_early` 1, `is_match_live` 0, `find_captures` 3021334545, `find_early` 1923, `redos` 0, `large` 1001. All non-timeout variants agree.

### Program size

The program and the visited set are binary tries keyed by pc, so a closure step costs O(log pc), not O(m). `(?:x?){k}y` on 200 `x` then `y`, Bend ms, one run each:

| k | 125 | 250 | 500 | 1000 |
|---|---:|---:|---:|---:|
| list (0.1.0.0) | 149 | 600 | 2537 | 15224 |
| trie (0.2.0.0) | 17 | 38 | 88 | 222 |

The list grows about 4–6× per doubling of k (m²); the trie grows about 2.3× (m log m). On `large`, 0.1.0.0 takes 65 374 ms. The trie costs a little on tiny patterns, where every hot pc is near the list head: `is_match` was about 140 ms with lists.

### History

Bend times in ms, median of three runs of the same bench against each version of `regex.bend`. Rows up to #100 time the `String` API.

| change | is_match | is_match_early | is_match_live | find_captures | find_early |
|---|---:|---:|---:|---:|---:|
| before #97 (0.2.0.0) | 174 | 17 | 282 | 750 | 17 |
| #97: stop once the match is settled; `is_match` skips captures | 152 | 7 | 267 | 748 | 7 |
| #98: skip chars that cannot start a match | 33 | 7 | 266 | 757 | 7 |
| #100: bit-parallel NFA for `is_match` | 42 | 7 | 85 | 757 | 6 |
| #144: match over `Bytes`; skip with a byte table | 1 | 0 | 76 | 760 | 0 |
| #153: lazy DFA with capture operations for `find` | 1 | 0 | 78 | 214 | 0 |

## Caveats

- The skip only helps while no match is in progress. Where every char keeps threads live (`is_match_live`, and `find_captures`, where each `x` is a `\w`), each char still takes a step: a cached DFA transition for `find`, the bit NFA for `is_match`. That per-char cost is the gap to C and V8. `is_match` keeps the bit NFA on small programs: on `is_match_live` the DFA took about 136 ms against its 78.
- `large` has about 1000 DFA states, more than the cache holds (8 for a text under 4 KiB, 256 above), so most of its chars take the plain Pike step.
- POSIX ERE has no `\w`; `[[:alnum:]_]` is the documented equivalent for ASCII word characters.
- `IO.now` in Bend is whole milliseconds; C and the scripting languages use sub-ms clocks.
