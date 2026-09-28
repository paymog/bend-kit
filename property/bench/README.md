# Property benchmark

Run `bend bench/bench.bend` from `property/`. It calls `Prop.check` on 10,000 seeded `U32` samples, starting at seed 42, with a passing predicate. The output columns are operation, elapsed milliseconds, and checksum (10,000 for a full pass, 0 if a check fails). The passing case times generation and the runner; `check.bend` exercises shrinking separately.

On an M4 Pro with macOS 26.6.2 and Bend 2.0.32, `check` took 2.460375 ms and printed checksum `10000` (2026-09-28, one run). There is no cross-language timing: the standard libraries do not provide a property-testing runner with integrated shrinking. A benchmark against a different PRNG, generated stream, or shrink algorithm would not compare the same work or produce the same counterexample. C, Rust, Python, and JavaScript are omitted rather than replacing a property-testing framework with a hand-written implementation.
