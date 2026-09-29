#!/usr/bin/env python3
"""Build and run the BigInt benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OP = "modsq"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}
SSL = os.environ.get("OPENSSL_PREFIX", "/opt/homebrew/opt/openssl@3")

# name -> (build argv or None, run argv).
VARIANTS = {
    "C": (["cc", "-O2", f"-I{SSL}/include", "-o", OUT / "c", "bench.c", f"-L{SSL}/lib", "-lcrypto"], [OUT / "c"]),
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"],
             [OUT / "rs" / "release" / "bench"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def parse(text):
    """-> (ms, checksum). Baselines print `op ms chk`; Bend prints `chk op v`, then `ms op v`."""
    ms = chk = None
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[0] == "chk" and p[1] == OP:
            chk = p[2]
        elif p[0] == "ms" and p[1] == OP:
            ms = float(p[2])
        elif p[0] == OP:
            ms, chk = float(p[1]), p[2]
    if ms is None or chk is None:
        sys.exit(f"no {OP} result in:\n{text}")
    return ms, chk


def main():
    OUT.mkdir(exist_ok=True)
    times, checks = {}, {}
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
            runs.append(parse(r.stdout))
        if len({c for _, c in runs}) != 1:
            sys.exit(f"{name} checksum changed between runs: {runs}")
        times[name] = statistics.median(t for t, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")

    best = min(times.values()) or 0.001
    print(f"| variant | {OP} ms | vs fastest |")
    print("|---|---:|---:|")
    for name, t in times.items():
        print(f"| {name} | {t:,.3f} | {t / best:,.1f}x |")
    print()
    print(f"checksum: {next(iter(checks.values()))}")


main()
