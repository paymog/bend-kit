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
parser.add_argument("--batch", action="store_true", help="warm up and batch each operation above 5 ms")
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
    """Read operation, batch milliseconds, last checksum, count, and checksum sum."""
    got = {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 5:
            continue
        op, ms, last, count, total = p
        ms, last, count, total = float(ms), int(last), int(count), int(total)
        if count < 1 or not math.isfinite(ms) or ms < 0 or total != (last * count) & 0xFFFFFFFF:
            sys.exit(f"invalid batch: {line}")
        if op in got:
            sys.exit(f"duplicate operation: {op}")
        got[op] = (ms / count, last, count, ms)
    for extra, reference in (("sum_bytewise", "sum"), ("sum_again", "sum"), ("find_swar", "find")):
        if extra in got and got[extra][1] != got.get(reference, (None, None))[1]:
            sys.exit(f"checksum mismatch in {extra}: {got[extra]} != {got.get(reference)}")
    return got


def main():
    OUT.mkdir(exist_ok=True)
    table, checks, batches = {}, {}, {}
    for name, (build, run, scale) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV).returncode != 0:
            sys.exit(f"build failed: {name}")
        expected = OPS if name != "Bend String" else OPS[:5] + ["equal"]
        if name == "Bend Array":
            expected = expected + ["sum_bytewise", "sum_again", "find_swar"]

        def sample(count):
            env = {**ENV, "BYTES_BENCH_COUNT": str(count), "BYTES_BENCH_WARMUP": "32" if args.batch else "0"}
            r = subprocess.run(run, cwd=HERE, env=env, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            result = parse(r.stdout)
            if set(result) != set(expected) or any(v[2] != count for v in result.values()):
                sys.exit(f"{name}: missing or unexpected operation/count: {result}")
            return result

        count = 32 if args.batch else 1
        runs = []
        repetitions = RUNS if args.batch or name not in ("Python", "Bend String") else 1
        while len(runs) < repetitions:
            result = sample(count)
            minimum = min(v[3] for v in result.values())
            if args.batch and minimum < 5:
                count *= max(2, min(16, math.ceil(10 / max(minimum, 0.000001))))
                if count > 16777216:
                    sys.exit(f"{name}: cannot reach the batch timer floor")
                runs.clear()
                continue
            if runs and {op: v[1] for op, v in result.items()} != {op: v[1] for op, v in runs[0].items()}:
                sys.exit(f"{name}: checksum mismatch between repetitions")
            runs.append(result)
        batches[name] = runs
        reported = [dict(x, sum=x["sum_bytewise"]) if "sum_bytewise" in x else x for x in runs]
        table[name] = {op: statistics.median(x[op][0] for x in reported) * scale for op in OPS if op in reported[0]}
        if scale == 1:
            checks[name] = {op: reported[0][op][1] for op in OPS if op in reported[0]}
        print(f"ran {name}: {count} operations per batch, {len(runs)} runs", file=sys.stderr)

    ref = next(iter(checks.values()))
    for name, c in checks.items():
        bad = [op for op in (OPS[:5] + ["equal"] if name == "Bend String" else OPS) if c.get(op) != ref.get(op)]
        if bad:
            sys.exit(f"checksum mismatch in {name}: {bad}")
    if args.batch:
        print("| variant | op | count | batch ms (median) | ms/op (median) | ms/op (min–max) |")
        print("|---|---|---:|---:|---:|---:|")
        for name, runs in batches.items():
            for op in runs[0]:
                times = [x[op][0] for x in runs]
                total = statistics.median(x[op][3] for x in runs)
                print(f"| {name} | {op} | {runs[0][op][2]} | {total:.6f} | {statistics.median(times):.9f} | {min(times):.9f}–{max(times):.9f} |")
        return

    best = {op: min(t[op] for t in table.values() if op in t) for op in OPS}
    names = list(table)
    timings_only = SELECTED or any(value <= 0 for value in best.values())
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---|" * len(names))
    for op in OPS:
        cells = [(f"{table[n][op]:.6f}" if timings_only else f"{table[n][op]:,.1f} ({table[n][op] / best[op]:.1f}x)") if op in table[n] else "n/a" for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")
    if timings_only:
        return
    growth = [f"{table[n][f'build_{B2}'] / table[n][f'build_{B1}']:.1f}x" if f"build_{B1}" in table[n] else "n/a" for n in names]
    print(("| build (1024 / 256) | " if SMALL else "| build (4M / 1M) | ") + " | ".join(growth) + " |")
    geo = []
    for n in names:
        rs = [table[n][op] / best[op] for op in OPS if op in table[n]]
        geo.append(f"{math.exp(sum(map(math.log, rs)) / len(rs)):.1f}x")
    print("| geomean vs fastest | " + " | ".join(geo) + " |")


main()
