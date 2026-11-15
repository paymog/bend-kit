# Lemmas benchmark

There is no benchmark. `lemmas` holds proofs and helper definitions that only the checker uses. It has no runtime hot path, so there is nothing to time in Bend, C, Rust, Python, or JavaScript.

`bend PROOF.bend --check-only` from `lemmas/` checks every law. On an M4 Pro with macOS 26.6.2 and Bend 2.0.36, it took 0.41 s and peaked at 168 MB RSS (2026-10-08, one run).
