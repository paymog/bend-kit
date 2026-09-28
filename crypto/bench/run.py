#!/usr/bin/env python3
"""Build and run the crypto benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = 16_777_216
OPS = ("sha256", "pbkdf2")
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
    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines() if len(l.split("\t")) == 3)})
        table[name] = {op: statistics.median(run[op][0] for run in runs) for op in OPS}
        checks[name] = tuple(runs[0][op][1] for op in OPS)
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    for op, c in zip(OPS, next(iter(checks.values()))):
        print(f"{op} checksum {c}", file=sys.stderr)

    best = {op: min(t[op] for t in table.values()) or 0.001 for op in OPS}
    print("| variant | sha256 ms | MB/s | vs fastest | pbkdf2 ms | vs fastest |")
    print("|---:|---:|---:|---:|---:|---:|")
    for n, t in table.items():
        s, k = t["sha256"], t["pbkdf2"]
        print(f"| {n} | {s:,.1f} | {N / 1e6 / (s / 1000):,.0f} | {s / best['sha256']:.1f}x | {k:,.1f} | {k / best['pbkdf2']:.1f}x |")


if __name__ == "__main__":
    main()
