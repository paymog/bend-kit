#!/usr/bin/env python3
"""Build and run the tty width/pad_right benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = "20000"
OPS = ["width", "pad"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Bend has N built in.
VARIANTS = {
    "C": (["cc", "-O2", "-o", OUT / "c", "bench.c"], [OUT / "c", N]),
    "Python": (None, [sys.executable, "bench.py", N]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def parse(text):
    """-> ({op: ms}, {key: checksum}) from `ms<TAB>op<TAB>v` and `chk<TAB>key<TAB>v` lines."""
    ms, chk = {}, {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) == 3 and p[0] in ("ms", "chk"):
            (ms if p[0] == "ms" else chk)[p[1]] = float(p[2]) if p[0] == "ms" else p[2]
    return ms, chk


def main():
    OUT.mkdir(exist_ok=True)
    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stdout}{b.stderr}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            runs.append(parse(r.stdout))
        table[name] = {op: statistics.median(ms[op] for ms, _ in runs) for op in OPS}
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    keys = sorted(checks["C"])
    for name, c in checks.items():
        if c != checks["C"]:
            sys.exit(f"checksum mismatch: {checks}")

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        print(f"| {op} | " + " | ".join(f"{table[n][op]:,.3f}" for n in names) + " |")
    print()
    print("| check | value |")
    print("|---|---:|")
    for k in keys:
        print(f"| {k} | {checks['C'][k]} |")


main()
