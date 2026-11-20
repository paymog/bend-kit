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
The `sparse_hit` input is **N − 9** `x` followed by `@host.org`, with a match near the end.


## Cases

| case | Bend / Python / JS pattern | POSIX ERE (C) | work | checksum |
|---|---|---|---|---|
| `is_match` | `hello\w+` | `hello[[:alnum:]_]+` | is there a match (late in the text) | 1 if a match, else 0 |
| `is_match_early` | `x` | `x` | is there a match (at position 0) | 1 if a match, else 0 |
| `is_match_live` | `xy` | `xy` | is there a match (none; each char can start one) | 0 |
| `find_captures` | `(\w+)@(\w+)\.com` | `([[:alnum:]_]+)@([[:alnum:]_]+)\.com` | leftmost match with two captures | hash of groups 0–2 spans |
| `find_early` | `(x)x` | `(x)x` | leftmost match with one capture, at position 0 | hash of groups 0–1 spans |
| `sparse` | `x@host\.org` | `x@host\.org` | no match on 1 MiB of `x` with an unrelated `@host.com`; `x` can start everywhere | 0 |
| `sparse_hit` | `x.{0,4}@host\.org` | `x.{0,4}@host\.org` | a rare literal after many possible starts; find the leftmost span | hash of group-0 span |
| `redos` | `(a*)*b` | `(a*)*b` | no match on 100k `a` | 0 |
| `large` | `(?:x?){1000}y` | `((x?){250}){4}y` | about 2000 instructions; each char walks a closure over most of them | u32 hash of group-0 span |

Hash: for each group, if missing then `h = h * 31`; else `h = h * 31 + start` then `h = h * 31 + end` (u32 wrap). Positions are byte offsets in every language; the input is ASCII. Bend times `Regex.find.bytes` and `Regex.is_match.bytes` on a `Bytes` buffer built before the clock starts. The `is_match` cases use `Regex.is_match.bytes` in Bend, `REG_NOSUB` in C, `search(...) is not None` in Python, and `RegExp.test` in JavaScript.

Compile the pattern **outside** the timed region. Bend uses a native build (`bend bench.bend -o out/bend`); the checker runner is not used for the 1 MiB input.

## Rust

Rust's standard library has no regular expression engine, so Rust is left out.

## Results

Apple M3 Max, macOS, 2026-11-18, regex 0.9.0.0. Median of five runs (`python3 run.py 5`). Times are ms for one match on the 1 MiB text (or 100k `a` for `redos`, 1001 chars for `large`).

Versions: Bend 2.0.38 (the CI pin), Apple clang 21.0.0, Python 3.15.2, Bun 1.4.4, Node v24.22.2.

| op | C | Python | Bun | Node | Bend |
|---|---:|---:|---:|---:|---:|
| is_match | 0.0 | 0.3 | 0.1 | 0.2 | 2.0 |
| is_match_early | 0.0 | 0.0 | 0.1 | 0.1 | 0.1 |
| is_match_live | 9.9 | 1.4 | 0.1 | 8.2 | 2.0 |
| find_captures | 17.8 | 5.7 | 0.9 | 0.8 | 169.8 |
| find_early | 0.0 | 0.0 | 0.2 | 0.2 | 0.5 |
| sparse | 12.5 | 1.4 | 0.2 | 0.2 | 2.0 |
| sparse_hit | 76.8 | 10.1 | 6.0 | 12.7 | 2.4 |
| redos | 3.9 | timeout | 524.2 | timeout | 0.3 |
| large | 2,640.9 | 0.0 | 0.1 | 0.1 | 1,197.0 |

### Bend versions

The Bend column for regex 0.8.0.0 and 0.9.0.0, built with two compilers, same machine and day, median of five runs of each `out/bend <case>`:

| case | 0.8.0.0, bend 2.0.38 | 0.9.0.0, bend 2.0.38 | 0.8.0.0, bend 2.0.40 | 0.9.0.0, bend 2.0.40 |
|---|---:|---:|---:|---:|
| is_match | 1.2 | 1.9 | 1.2 | 0.3 |
| is_match_early | 0.1 | 0.1 | 0.1 | 0.1 |
| is_match_live | 98.8 | 1.9 | 95.9 | 0.3 |
| find_captures | 159.4 | 165.8 | 153.4 | 156.1 |
| find_early | 0.4 | 0.5 | 0.4 | 0.5 |
| sparse | 1.2 | 1.9 | 1.2 | 0.3 |
| sparse_hit | 1.6 | 2.4 | 1.6 | 0.8 |
| redos | 0.2 | 0.2 | 0.2 | 0.1 |
| large | 1,162.0 | 1,165.9 | 1,153.6 | 1,138.4 |

In 0.9.0.0, `is_match`, `is_match_live`, `sparse` and `sparse_hit` spend nearly all their time in the required-literal scan over `Bytes`, which reads the buffer a 32-bit word at a time: no literal in the text means no automaton runs, and `is_match` of `hello\w+` runs the bit NFA from the literal. That scan takes about 1.9 ms per MiB built with bend 2.0.38 and 0.3 ms with 2.0.40. 0.8.0.0 has no such scan: `is_match` skips with the byte table and `sparse` searches for one required byte, about 1.2 ms per MiB with either compiler. So built with bend 2.0.38, `is_match`, `sparse` and `sparse_hit` are about 0.7 ms per MiB slower in 0.9.0.0 than in 0.8.0.0; built with 2.0.40 they are about four times faster. With the scan switched off, 0.9.0.0 built with 2.0.38 gives the times of 0.8.0.0 on these three cases.

Checksums (1 MiB text; 1001 chars for `large`). All non-timeout variants agree.

| op | checksum |
|---|---:|
| is_match | 1 |
| is_match_early | 1 |
| is_match_live | 0 |
| find_captures | 3021334545 |
| find_early | 1923 |
| sparse | 0 |
| sparse_hit | 33553998 |
| redos | 0 |
| large | 1001 |

### Program size

The program and the visited set are binary tries keyed by pc, so a closure step costs O(log pc), not O(m). `(?:x?){k}y` on 200 `x` then `y`, Bend ms, one run each:

| k | 125 | 250 | 500 | 1000 |
|---|---:|---:|---:|---:|
| list (0.1.0.0) | 149 | 600 | 2537 | 15224 |
| trie (0.2.0.0) | 17 | 38 | 88 | 222 |

The list grows about 4–6× per doubling of k (m²); the trie grows about 2.3× (m log m). On `large`, 0.1.0.0 takes 65 374 ms. The trie costs a little on tiny patterns, where every hot pc is near the list head: `is_match` was about 140 ms with lists.

### History

Bend times in ms, median of three runs of the same bench against each version of `regex.bend`. Rows up to #100 time the `String` API.

| change | is_match | is_match_early | is_match_live | find_captures | find_early | redos |
|---|---:|---:|---:|---:|---:|---:|
| before #97 (0.2.0.0) | 174 | 17 | 282 | 750 | 17 | — |
| #97: stop once the match is settled; `is_match` skips captures | 152 | 7 | 267 | 748 | 7 | — |
| #98: skip chars that cannot start a match | 33 | 7 | 266 | 757 | 7 | — |
| #100: bit-parallel NFA for `is_match` | 42 | 7 | 85 | 757 | 6 | — |
| #144: match over `Bytes`; skip with a byte table | 1 | 0 | 76 | 760 | 0 | — |
| #153: lazy DFA with capture operations for `find` | 1 | 0 | 78 | 214 | 0 | 21 |
| #163: spin through unchanged DFA transitions | 1 | 0 | 78 | 223 | 1 | 21 |
| #163: reuse arrays for live DFA threads | 1 | 0 | 78 | 143 | 1 | 14 |

## Caveats

- Identity transitions alone did not help `find_captures`: it saves a capture end on each `x`. Reusable thread arrays reduce its time from 223 to 143 ms and `redos` from 21 to 14 ms, without changing capture results. The small-program VM takes 128 ms on `is_match_live`; the bit NFA remains at 78 ms.
- `large` is 1001 bytes, so it uses the plain VM. Enlarging its cache was slower (4,208 ms versus 1,055 ms) because this case does not revisit most learned states. Long texts with large programs can use up to 2048 states; 262,144 transition slots cost at least 2 MiB.
- The required-literal scan rejects `sparse` without running an automaton, and on `sparse_hit` it starts the automata a few bytes before `@host.org`. The required-byte scan and the reverse bitset DFA apply only where the literal scan leaves the start at byte 0, such as a pattern with an unbounded prefix before its literal; in `find_captures` the reverse scan gives up at its 4096-byte bound, because the match's `\w+` reaches back over the whole text of `x`.
- POSIX ERE has no `\w`; `[[:alnum:]_]` is the documented equivalent for ASCII word characters.
- Bend times itself with `Time.mono`, a nanosecond clock.
