#!/usr/bin/env python3
"""Build and run the wire benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
R = 64
N = 1_048_576
# One timed op: R round trips, each send N bytes and recv N bytes.
BYTES = R * N * 2
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}

VARIANTS = {
    "C": (["clang", "-O2", "-pthread", "-o", OUT / "c", "bench.c"], [OUT / "c"]),
    "Rust": (
        ["rustc", "-C", "opt-level=3", "-o", OUT / "rs", "bench.rs"],
        [OUT / "rs"],
    ),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def mbps(ms: float) -> float:
    return (BYTES / 1_000_000) / (ms / 1000.0)


def main():
    OUT.mkdir(exist_ok=True)
    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            lines = [l for l in r.stdout.splitlines() if len(l.split("\t")) == 3]
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in lines)})
            result = runs[-1]
            missing = [op for op in ("echo",) if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    for op in table[next(iter(table))]:
        seen = {checks[n].get(op) for n in checks}
        if len(seen) != 1:
            sys.exit(f"checksum mismatch in {op}: {[(n, checks[n].get(op)) for n in checks]}")
        print(f"{op} checksum {seen.pop()}", file=sys.stderr)

    names = list(table)
    op = "echo"
    best_ms = min(table[n][op] for n in names) or 0.001
    best_mbps = max(mbps(table[n][op]) for n in names)
    print("| variant | echo ms | echo MB/s | vs fastest |")
    print("|---:|---:|---:|---:|")
    for n in names:
        ms = table[n][op]
        rate = mbps(ms)
        print(
            f"| {n} | {ms:,.1f} | {rate:,.0f} | "
            f"{ms / best_ms:.1f}x ms, {rate / best_mbps:.2f}x MB/s |"
        )


if __name__ == "__main__":
    main()
