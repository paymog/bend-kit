#!/usr/bin/env python3
"""Build and run the runner replay benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
# log2(jobs). The log holds 3 records per job.
LG = sys.argv[2] if len(sys.argv) > 2 else "16"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program prints a checksum and pending/next.
VARIANTS = {
    "Rust": (
        ["cargo", "build", "-q", "--release", "--manifest-path", "rust/Cargo.toml", "--target-dir", OUT / "rust"],
        [OUT / "rust" / "release" / "runner-bench", LG],
    ),
    "Python": (None, ["python3", "bench.py", LG]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend", LG]),
}


def wait_bend():
    # One bend process on this machine. A native compile grows without a bound.
    while subprocess.run(["pgrep", "-x", "bend"], capture_output=True).returncode == 0:
        time.sleep(5)


def parse(text):
    """-> {op: (ms, checksum, pending/next)}. Baselines print `op ms chk n`; Bend prints chk, n, then ms per op."""
    got = {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) == 3 and p[0] in ("chk", "n", "ms"):
            got.setdefault(p[1], {})[p[0]] = float(p[2]) if p[0] == "ms" else p[2]
        elif len(p) == 4 and p[0] in ("replay", "dead"):
            got[p[0]] = {"ms": float(p[1]), "chk": p[2], "n": p[3]}
    return {op: (d.get("ms"), d.get("chk"), d.get("n")) for op, d in got.items()}


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
            if not got or any(None in v for v in got.values()):
                sys.exit(f"{name} printed no result:\n{r.stdout}")
            runs.append(got)
        for op in runs[0]:
            if len({(g[op][1], g[op][2]) for g in runs}) != 1:
                sys.exit(f"{name} {op} checksum changed between runs: {runs}")
            times[(op, name)] = statistics.median(g[op][0] for g in runs)
            checks.setdefault("replay" if op == "compacted" else op, set()).add(runs[0][op][1:])
        print(f"ran {name}", file=sys.stderr)

    if any(len(c) != 1 for c in checks.values()):
        sys.exit(f"checksum mismatch: {checks}")
    names = list(VARIANTS)
    best = min(times.values()) or 0.001
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in dict.fromkeys(op for op, _ in times):
        cells = [f"{times[(op, n)]:,.1f} ({times[(op, n)] / best:.1f}x)" if (op, n) in times else "-" for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")
    print()
    for op, c in checks.items():
        chk, n = next(iter(c))
        print(f"{op}: checksum {chk}, pending/next {n}")


if __name__ == "__main__":
    main()
