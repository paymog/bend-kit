#!/usr/bin/env python3
"""Build and run the bytes benchmark; print a markdown table. See README.md."""
import argparse, math, os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("runs", nargs="?", type=int, default=3)
parser.add_argument("--small", action="store_true")
parser.add_argument("--log2-size", type=int, choices=range(8, 29), metavar="8..28")
args = parser.parse_args()
RUNS = args.runs
SMALL = args.small
SELECTED = args.log2_size is not None
LG = str(args.log2_size if SELECTED else (16 if SMALL else 28))
B1, B2 = (256, 1024) if SMALL else (1000000, 4000000)
SIZES = [LG, "256" if SMALL else "16777216", str(B1), str(B2)]
if RUNS < 1:
    sys.exit("runs must be positive")
OPS = ["fill", "sum", "find", "slice", "concat", "random", "equal", f"build_{B1}", f"build_{B2}"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv, scale). scale multiplies ms: string.bend runs at 64 MiB, the rest at 256 MiB.
VARIANTS = {
    "C": (["clang", "-O2", "-o", OUT / "c", "bench.c"], [OUT / "c", *SIZES], 1),
    "Rust": (["rustc", "-C", "opt-level=3", "-C", "target-cpu=native", "-o", OUT / "rs", "bench.rs"], [OUT / "rs", *SIZES], 1),
    "Go": (["go", "build", "-o", OUT / "go", "bench.go"], [OUT / "go", *SIZES], 1),
    "Bun": (None, ["bun", "bench.ts", *SIZES], 1),
    "Node": (None, ["node", "bench.ts", *SIZES], 1),
    "Python": (None, ["python3", "bench.py", *SIZES], 1),
    "Bend Array": (["bend", "packed.bend", "-o", OUT / "packed"], [OUT / "packed", *SIZES], 1),
    "Bend String": (["bend", "string.bend", "-o", OUT / "string"], [OUT / "string", LG if SMALL or SELECTED else "26"], 1 if SMALL or SELECTED else 4),
}


def parse(text):
    """-> {op: (ms, checksum)}. Baselines print `op ms chk`; Bend prints `chk op v` then `ms op v`."""
    got, chk = {}, {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[0] == "chk":
            chk[p[1]] = p[2]
        elif p[0] == "ms":
            got[p[1]] = (float(p[2]), chk.get(p[1]))
        else:
            got[p[0]] = (float(p[1]), p[2])
    # Bend's byte-API sum is what a Bytes.get caller pays; report it as `sum`.
    for extra, reference in (("sum_bytewise", "sum"), ("sum_again", "sum"), ("find_swar", "find")):
        if extra in got and got[extra][1] != got.get(reference, (None, None))[1]:
            sys.exit(f"checksum mismatch in {extra}: {got[extra]} != {got.get(reference)}")
    if "sum_bytewise" in got:
        got["sum"] = got["sum_bytewise"]
    return got


def main():
    OUT.mkdir(exist_ok=True)
    table, checks = {}, {}
    for name, (build, run, scale) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(1 if name in ("Python", "Bend String") else RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            runs.append(parse(r.stdout))
            result = runs[-1]
            expected = OPS if name != "Bend String" else OPS[:5] + ["equal"]
            if name == "Bend Array":
                expected = expected + ["sum_bytewise", "sum_again", "find_swar"]
            missing = [op for op in expected if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        table[name] = {op: statistics.median(x[op][0] for x in runs) * scale for op in OPS if op in runs[0]}
        if scale == 1:
            checks[name] = {op: runs[0][op][1] for op in OPS if op in runs[0]}
        print(f"ran {name}", file=sys.stderr)

    ref = next(iter(checks.values()))
    for name, c in checks.items():
        bad = [op for op in (OPS[:5] + ["equal"] if name == "Bend String" else OPS) if c.get(op) != ref.get(op)]
        if bad:
            sys.exit(f"checksum mismatch in {name}: {bad}")

    best = {op: min(t[op] for t in table.values() if op in t) for op in OPS}
    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---|" * len(names))
    for op in OPS:
        cells = [(f"{table[n][op]:.6f}" if SELECTED else f"{table[n][op]:,.1f} ({table[n][op] / best[op]:.1f}x)") if op in table[n] else "n/a" for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")
    if SELECTED:
        return
    growth = [f"{table[n][f'build_{B2}'] / table[n][f'build_{B1}']:.1f}x" if f"build_{B1}" in table[n] else "n/a" for n in names]
    print(("| build (1024 / 256) | " if SMALL else "| build (4M / 1M) | ") + " | ".join(growth) + " |")
    geo = []
    for n in names:
        rs = [table[n][op] / best[op] for op in OPS if op in table[n]]
        geo.append(f"{math.exp(sum(map(math.log, rs)) / len(rs)):.1f}x")
    print("| geomean vs fastest | " + " | ".join(geo) + " |")


main()
