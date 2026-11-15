#!/usr/bin/env python3
"""Build and run the resources benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program runs 2^14 rounds.
VARIANTS = {
    "C": (["cc", "-O3", "-o", OUT / "c", "bench.c"], [OUT / "c", "14"]),
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rust/Cargo.toml", "--target-dir", OUT / "rust"], [OUT / "rust" / "release" / "resources-bench", "14"]),
    "Bun": (["sh", "-c", "npm install -s --prefix out/js async-sema@3.1.1 && cp bench.ts out/js/"], ["bun", OUT / "js" / "bench.ts", "14"]),
    "Node": (None, ["node", "--no-warnings", "--experimental-strip-types", OUT / "js" / "bench.ts", "14"]),
    "Python": (None, ["python3", "bench.py", "14"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend", "14"]),
}


def parse(text):
    """-> (ms, checksum). Baselines print `lease ms chk`; Bend prints `chk lease v` and `ms lease v`."""
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
        times[name] = statistics.median(ms for ms, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) > 1:
        sys.exit(f"checksum mismatch: {checks}")
    print("| op | " + " | ".join(times) + " |")
    print("|---|" + "---:|" * len(times))
    print("| lease | " + " | ".join(f"{t:,.1f}" for t in times.values()) + " |")
    print()
    print(f"checksum: {next(iter(checks.values()))}")


main()
