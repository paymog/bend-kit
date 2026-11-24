#!/usr/bin/env python3
"""Build and run the cache benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
LG = sys.argv[2] if len(sys.argv) > 2 else "12"
if RUNS < 1 or not LG.isdecimal() or not 0 <= int(LG) <= 12:
    sys.exit("usage: run.py [runs >= 1] [0 <= log2(rounds) <= 12]")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "PYTHONPATH": str(OUT / "py")}

# name -> (build argv or None, run argv). Every program takes log2(rounds).
VARIANTS = {
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rust/Cargo.toml", "--target-dir", OUT / "rust"], [OUT / "rust" / "release" / "cache-bench", LG]),
    "Bun": (["sh", "-c", "npm install -s --prefix out/js lru-cache@11.5.3 && cp bench.ts out/js/"], ["bun", OUT / "js" / "bench.ts", LG]),
    "Node": (None, ["node", "--no-warnings", "--experimental-strip-types", OUT / "js" / "bench.ts", LG]),
    "Python": ([sys.executable, "-m", "pip", "install", "-q", "--target", OUT / "py", "cachetools==7.2.1"], [sys.executable, "bench.py", LG]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend", LG]),
}


def parse(text):
    """-> (ms, checksum). Baselines print `cache ms chk`; Bend prints `chk cache v` and `ms cache v`."""
    ms = chk = None
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[0] == "chk":
            chk = p[2]
        elif p[0] == "ms":
            ms = float(p[2])
        else:
            ms, chk = float(p[1]), p[2]
    return ms, chk


def main():
    OUT.mkdir(exist_ok=True)
    times, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            runs.append(parse(r.stdout))
            result = runs[-1]
            if any(value is None for value in result):
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum: {result}")
            if result[1:] != runs[0][1:]:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result[1:]} != {runs[0][1:]}")
        times[name] = statistics.median(ms for ms, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) > 1:
        sys.exit(f"checksum mismatch: {checks}")
    print("| op | " + " | ".join(times) + " |")
    print("|---|" + "---:|" * len(times))
    print("| fill + read | " + " | ".join(f"{t:,.1f}" for t in times.values()) + " |")
    print()
    print(f"checksum: {next(iter(checks.values()))}")


main()
