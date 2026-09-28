# JSON log-line benchmark

This times Notch's JSON-lines renderer against JSON serialization in Rust, JavaScript, and Python. C has no standard or comparably popular JSON serializer, so it is left out. No lines are written to a sink during timing.

## Run

```sh
python3 run.py       # 3 runs per variant, median
python3 run.py 5     # 5 runs
```

You need `bend`, `cargo`, `bun`, `node`, and `python3`. Builds go to `out/`, which git ignores. The runner fails if a build or run fails, or if the checksums disagree.

## Work

20,000 records with a fixed timestamp, INFO level, `request done` message, and `svc=api` context field. A seeded u32 LCG (`s = s*1664525 + 1013904223`, starting at 1) supplies an `id`, a quoted `user` string (`u"` plus `id % 1000`), and an `ok` flag from the low bit. All programs generate IDs before timing, render the same compact JSON object (time, level, msg, svc, user, id, ok), and compute 32-bit FNV-1a over each UTF-8 line followed by `\n`. Rust uses `serde_json` with `preserve_order`; JavaScript uses `JSON.stringify`; Python uses `json.dumps` with compact separators. Each program prints the checksum.

## Results

M4 Pro, macOS, 2026-09-27. Bend 2.0.31, rustc 1.91.0 (`-C opt-level=3`), Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs, milliseconds:

| variant | json ms | µs per line | vs fastest |
|---:|---:|---:|---:|
| Rust | 14.2 | 0.71 | 1.0× |
| Bun | 36.7 | 1.84 | 2.6× |
| Node | 22.9 | 1.14 | 1.6× |
| Python | 235.2 | 11.76 | 16.5× |
| Bend | 45.0 | 2.25 | 3.2× |

Every program prints checksum `1359480221`. The clock has millisecond resolution in Bend; the others use sub-millisecond clocks. One machine, one thread.
