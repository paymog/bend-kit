#!/usr/bin/env python3
"""Build and run the commands benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = sys.argv[2] if len(sys.argv) > 2 else "10000"
FILE = len(sys.argv) > 3 and sys.argv[3] == "file"
OPS = ("fresh", "replay", "range_small", "overflow_small", "range_large", "overflow_large")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
DB = OUT / "bench.db" if FILE else ":memory:"

# name -> (build argv or None, run argv). Each prints `sqlite<TAB>version`, then `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "C": (["cc", "-O2", "-o", OUT / "c", "bench.c", "-lsqlite3"], [OUT / "c", DB, N]),
    "Rust": (["rustc", "--edition", "2021", "-C", "opt-level=3", "-o", OUT / "rs", "bench.rs"], [OUT / "rs", DB, N]),
    "Bun": (None, ["bun", "bench.ts", DB, N]),
    "Python": (None, ["python3", "bench.py", DB, N]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend", DB, N]),
}


def fresh_db():
    if not FILE:
        return
    for suffix in ("", "-journal"):
        Path(f"{DB}{suffix}").unlink(missing_ok=True)


def main():
    OUT.mkdir(exist_ok=True)
    table, checks, libs = {}, {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr or b.stdout}")
        runs = []
        for _ in range(RUNS):
            fresh_db()
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            rows = [l.split("\t") for l in r.stdout.splitlines()]
            libs[name] = next(f[1] for f in rows if f[0] == "sqlite")
            runs.append({f[0]: (float(f[1]), f[2]) for f in rows if len(f) == 3})
            result = runs[-1]
            missing = [op for op in OPS if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        table[name] = {op: statistics.median(run[op][0] for run in runs) for op in OPS}
        checks[name] = tuple(runs[0][op][1] for op in OPS)
        print(f"ran {name}", file=sys.stderr)
    fresh_db()

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    row_hash = 0
    for byte in b"".join(f"pick_{i}={i+1};".encode() for i in range(8)):
        row_hash = (row_hash * 31 + byte) & 0xFFFFFFFF
    for op in OPS[2:]:
        expected = 0
        for _ in range(int(N)):
            expected = (expected * 31 + (18 if op.startswith("overflow") else row_hash)) & 0xFFFFFFFF
        if int(next(iter(checks.values()))[OPS.index(op)]) != expected:
            sys.exit(f"{op}: expected checksum {expected}, got {checks}")
    for op, c in zip(OPS, next(iter(checks.values()))):
        print(f"{op} checksum {c}", file=sys.stderr)

    n = int(N)
    best = {op: min(t[op] for t in table.values()) or 0.001 for op in OPS}
    print("| variant | SQLite | fresh ms | commands/s | vs fastest | replay ms | duplicates/s | vs fastest |")
    print("|---:|---:|---:|---:|---:|---:|---:|---:|")
    for name, t in table.items():
        f, r = t["fresh"], t["replay"]
        print(
            f"| {name} | {libs[name]} | {f:,.1f} | {n / (f / 1000):,.0f} | {f / best['fresh']:.1f}x"
            f" | {r:,.1f} | {n / (r / 1000):,.0f} | {r / best['replay']:.1f}x |"
        )
    print("\n| variant | range small ms | overflow small ms | range large ms | overflow large ms |")
    print("|---|---:|---:|---:|---:|")
    for name, t in table.items():
        print(f"| {name} | " + " | ".join(f"{t[op]:.3f}" for op in OPS[2:]) + " |")


if __name__ == "__main__":
    main()
