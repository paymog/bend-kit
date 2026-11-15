# Retry benchmark

There is no benchmark. `retry` runs a few `Nat` comparisons once per attempt, and each attempt is a network call or other IO that takes milliseconds. The policy is not a hot path, so there is nothing useful to time in Bend, C, Rust, Python, or JavaScript. `hairpin/bench` times the whole retry path, policy included, as `retry_1000`.

`bend PROOF.bend --check-only` from `retry/` checks every law. On an M4 Pro with macOS 26.6.2 and Bend 2.0.36, it took 0.36 s and peaked at 169 MB RSS (2026-10-11, one run).
