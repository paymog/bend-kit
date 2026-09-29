#!/usr/bin/env python3
"""Build and run the AEAD benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
BYTES = 4096 * 4096
OPS = ("aes-256-gcm", "chacha20-poly1305")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}
SSL = os.environ.get("OPENSSL_PREFIX", "/opt/homebrew/opt/openssl@3")

VARIANTS = {
    "C": (
        ["clang", "-O2", f"-I{SSL}/include", f"-L{SSL}/lib", "-lcrypto", "-o", OUT / "c", "bench.c"],
        [OUT / "c"],
    ),
    "Node": (None, ["node", "--no-warnings", "bench.js"]),
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
            got = {op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines() if len(l.split("\t")) == 3)}
            if set(got) != set(OPS):
                sys.exit(f"{name} printed {sorted(got)}, want {list(OPS)}:\n{r.stdout}")
            runs.append(got)
        table[name] = {op: statistics.median(run[op][0] for run in runs) for op in OPS}
        checks[name] = tuple(runs[0][op][1] for op in OPS)
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    for op, c in zip(OPS, next(iter(checks.values()))):
        print(f"{op} checksum {c}", file=sys.stderr)

    best = {op: min(t[op] for t in table.values()) or 0.001 for op in OPS}
    print("| variant | aes-256-gcm ms | MB/s | vs fastest | chacha20-poly1305 ms | MB/s | vs fastest |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    for n, t in table.items():
        a, c = t[OPS[0]], t[OPS[1]]
        mbs = lambda ms: BYTES / 1e6 / (ms / 1000)
        print(f"| {n} | {a:,.1f} | {mbs(a):,.0f} | {a / best[OPS[0]]:.1f}x | {c:,.1f} | {mbs(c):,.0f} | {c / best[OPS[1]]:.1f}x |")


if __name__ == "__main__":
    main()
