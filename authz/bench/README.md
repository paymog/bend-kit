# Authorization benchmark

This times the pure `authz` policy evaluator against Casbin in Rust, Python, and JavaScript. The policy permits DELETE by the owner or any request with the admin role, forbids the suspended role, and combines rules with deny-overrides and default deny.

## Run

```sh
python3 run.py       # 3 runs per variant, median; lg = 8
python3 run.py 5     # 5 runs per variant
python3 run.py 5 10  # 5 runs, lg = 10
```

You need `bend`, clang (for Bend's native target), `cargo`, `rustc`, `bun`, `node` with `--experimental-strip-types`, `npm`, and `python3` with pip. The runner installs Python `casbin==1.43.0` into `out/py` and npm `casbin@5.51.1` into `out/js`. Cargo fetches `casbin =2.20.0` and `futures =0.3.31` (only for asynchronous setup). Build and install outputs go under the git-ignored `out/`. Rust's dependency lockfile pins transitive dependencies. A failed build, install, run, missing output, or checksum mismatch exits non-zero.

## The op

Each program builds 64 requests before reading the clock. For i = 0..63, subject is `u{i % 7}`, owner is `u{i % 5}`, action is `[GET, DELETE, PUT][i % 3]`, and resource is `doc`. Exactly one role is present: admin when i % 11 = 0, otherwise suspended when i % 13 = 0, otherwise editor. There is no missing context.

The timed loop evaluates all 64 requests R = 2^lg times. At the default lg = 8, that is 16,384 decisions. It counts allowed decisions in u32; nine requests are allowed per round. Every repetition must equal `9 * R` modulo 2^32, not merely agree with the other variants.

| language | policy evaluation |
|---|---|
| Bend | `Az.granted(policy, request)` |
| Rust | Casbin `CoreApi::enforce`, synchronous, uncached |
| Python | Casbin `Enforcer.enforce`, uncached |
| JavaScript (Bun and Node) | Casbin `Enforcer.enforceSync`, uncached |

The Casbin model compares subject with owner for DELETE, and checks the single role against admin and suspended policy rows. Its effect is `some(where (p.eft == allow)) && !some(where (p.eft == deny))`. Model parsing, enforcer construction, and policy insertion are outside the timed section. C is omitted: it has no standard or popular authorization library suitable for this comparison; hand-writing the policy would not be a library baseline.

## Results

Apple M4 Pro, macOS 26.6.2 (arm64), 2026-10-11. Five runs (`python3 run.py 5`), median, in ms; lg = 8.

Versions: Bend 2.0.36, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Casbin versions: Rust 2.20.0, JavaScript 5.51.1, Python 1.43.0.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| authz | 36.096 | 38.339 | 54.206 | 820.624 | 7.629 |

All 25 executions produced checksum **2304** (9 allowed requests × 256 rounds).

## Caveats

- One machine, one small fixed fixture, sequential loops; this is not an application throughput measurement.
- Casbin interprets a matcher string and traverses policy rows; Bend compiles a concrete policy. The numbers compare these implementations, not language speed in isolation.
- No authentication, storage, role lookup, request construction, policy loading, or network IO is timed. Missing-context fail-closed behavior is outside this fixture.
- Clocks are `Time.mono` in Bend, `Instant` in Rust, `perf_counter_ns` in Python, and `performance.now` in JavaScript. Output is printed after the ending clock read.
- Process startup is excluded. JavaScript samples include any JIT warm-up inside their loops; there is no separate warm-up run.
