#!/usr/bin/env python3
"""Build and run the time benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = 4096
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}

VARIANTS = {
    "C": (["cc", "-O2", "-o", OUT / "c", "bench.c"], [OUT / "c"]),
    "Rust": (
        ["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"],
        [OUT / "rs" / "release" / "bench"],
    ),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "--experimental-strip-types", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


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
            op, ms, c = next(l for l in r.stdout.splitlines() if len(l.split("\t")) == 3).split("\t")
            runs.append((float(ms), c))
        table[name] = statistics.median(ms for ms, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    print(f"trip checksum {next(iter(checks.values()))}", file=sys.stderr)

    best = min(table.values()) or 0.001
    print("| variant | trip ms | us per trip | vs fastest |")
    print("|---:|---:|---:|---:|")
    for n, ms in table.items():
        print(f"| {n} | {ms:,.1f} | {ms * 1000 / N:,.2f} | {ms / best:.1f}x |")


if __name__ == "__main__":
    main()
