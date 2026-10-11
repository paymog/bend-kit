#!/usr/bin/env python3
"""Build and run the journal recovery benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
# log2(records). 2^20 keeps native Bend near 300 ms. See README.md.
LG = sys.argv[2] if len(sys.argv) > 2 else "20"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program prints a recover checksum and a record count.
VARIANTS = {
    "C": (["clang", "-O2", "-o", OUT / "c", "bench.c", "-lz"], [OUT / "c", LG]),
    "Rust": (
        ["cargo", "build", "-q", "--release", "--manifest-path", "rust/Cargo.toml", "--target-dir", OUT / "rust"],
        [OUT / "rust" / "release" / "journal-bench", LG],
    ),
    "Bun": (None, ["bun", "bench.ts", LG]),
    "Node": (None, ["node", "--no-warnings", "bench.ts", LG]),
    "Python": (None, ["python3", "bench.py", LG]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend", LG]),
}


def wait_bend():
    # One bend process on this machine. A native compile grows without a bound.
    while subprocess.run(["pgrep", "-x", "bend"], capture_output=True).returncode == 0:
        time.sleep(5)


def parse(text):
    """-> (ms, checksum, records). Baselines print `recover ms chk n`; Bend prints chk, n, then ms."""
    ms = chk = n = None
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) == 3 and p[0] == "chk":
            chk = p[2]
        elif len(p) == 3 and p[0] == "n":
            n = p[2]
        elif len(p) == 3 and p[0] == "ms":
            ms = float(p[2])
        elif len(p) == 4 and p[0] == "recover":
            ms, chk, n = float(p[1]), p[2], p[3]
    return ms, chk, n


def main():
    OUT.mkdir(exist_ok=True)
    times, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if name == "Bend":
            wait_bend()
        if build and subprocess.run(build, cwd=HERE, env=ENV).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            got = parse(r.stdout)
            if None in got:
                sys.exit(f"{name} printed no result:\n{r.stdout}")
            runs.append(got)
        if len({(c, n) for _, c, n in runs}) != 1:
            sys.exit(f"{name} checksum changed between runs: {runs}")
        times[name] = statistics.median(ms for ms, _, _ in runs)
        checks[name] = (runs[0][1], runs[0][2])
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    best = min(times.values()) or 0.001
    print("| op | " + " | ".join(times) + " |")
    print("|---|" + "---:|" * len(times))
    print("| recover | " + " | ".join(f"{t:,.1f} ({t / best:.1f}x)" for t in times.values()) + " |")
    chk, n = next(iter(checks.values()))
    print()
    print(f"checksum: {chk}")
    print(f"records: {n}")


main()
