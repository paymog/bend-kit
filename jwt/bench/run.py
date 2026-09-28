#!/usr/bin/env python3
"""Build and run the JWT verify benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = 10_000
OPS = ("hs256", "rs256")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}
# libjwt 3 flags from pkg-config; set PKG_CONFIG_PATH for a non-default install.
JWT = subprocess.run(["pkg-config", "--cflags", "--libs", "libjwt"], capture_output=True, text=True, check=True).stdout.split()

# name -> (build argv or None, run argv). Every program prints `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "C": (["cc", "-O2", "-o", OUT / "c", "bench.c", *JWT], [OUT / "c"]),
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"],
             [OUT / "rs" / "release" / "bench"]),
    "Bun": (["bun", "install", "--silent", "--frozen-lockfile"], ["bun", "bench.ts"]),
    "Node": (None, ["node", "bench.ts"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", "pyjwt[crypto]==2.15.1", "python", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def main():
    OUT.mkdir(exist_ok=True)
    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr or b.stdout}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            got = {op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines() if l.count("\t") == 2)}
            if set(got) != set(OPS):
                sys.exit(f"{name} printed {r.stdout!r}")
            runs.append(got)
        table[name] = {op: statistics.median(run[op][0] for run in runs) for op in OPS}
        checks[name] = tuple(runs[0][op][1] for op in OPS)
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    for op, c in zip(OPS, next(iter(checks.values()))):
        print(f"{op} checksum {c}", file=sys.stderr)

    best = {op: min(t[op] for t in table.values()) or 0.001 for op in OPS}
    print("| variant | hs256 ms | us/verify | vs fastest | rs256 ms | us/verify | vs fastest |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    for n, t in table.items():
        h, r = t["hs256"], t["rs256"]
        print(f"| {n} | {h:,.1f} | {h * 1000 / N:,.2f} | {h / best['hs256']:.1f}x | {r:,.1f} | {r * 1000 / N:,.2f} | {r / best['rs256']:.1f}x |")


if __name__ == "__main__":
    main()
