#!/usr/bin/env python3
"""Build and run the OAuth2 benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = 10_000
OPS = ("pkce", "parse")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}
SSL = os.environ.get("OPENSSL_PREFIX", "/opt/homebrew/opt/openssl@3")

VARIANTS = {
    "C": (
        ["clang", "-O2", f"-I{SSL}/include", f"-L{SSL}/lib", "-lcrypto", "-o", OUT / "c", "bench.c"],
        [OUT / "c"],
    ),
    "Rust": (
        ["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"],
        [OUT / "rs" / "release" / "bench"],
    ),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def main():
    OUT.mkdir(exist_ok=True)
    table, checks = {}, {op: {} for op in OPS}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines() if len(l.split("\t")) == 3)})
        table[name] = {op: statistics.median(run[op][0] for run in runs) for op in OPS if op in runs[0]}
        for op in table[name]:
            checks[op][name] = runs[0][op][1]
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        if len(set(checks[op].values())) != 1:
            sys.exit(f"{op} checksum mismatch: {checks[op]}")
        print(f"{op} checksum {next(iter(checks[op].values()))}", file=sys.stderr)

    best = {op: min(t[op] for t in table.values() if op in t) or 0.001 for op in OPS}
    cell = lambda t, op: f"{t[op]:,.1f} | {N / (t[op] / 1000):,.0f} | {t[op] / best[op]:.1f}x" if op in t else "— | — | —"
    print("| variant | pkce ms | per s | vs fastest | parse ms | per s | vs fastest |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    for n, t in table.items():
        print(f"| {n} | {cell(t, 'pkce')} | {cell(t, 'parse')} |")


if __name__ == "__main__":
    main()
