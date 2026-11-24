#!/usr/bin/env python3
"""Build and run the crdt benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
LG = sys.argv[2] if len(sys.argv) > 2 else "14"
if RUNS < 1 or not LG.isdecimal() or not 0 <= int(LG) <= 14:
    sys.exit("usage: run.py [runs >= 1] [0 <= log2(rounds) <= 14]")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv, run argv). Every program takes log2(rounds) of each op.
VARIANTS = {
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rust/Cargo.toml", "--target-dir", OUT / "rust"], [OUT / "rust" / "release" / "crdt-bench", LG]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend", LG]),
}
OPS = ["gossip", "gossip-sparse", "gossip-pn", "read-pn-exact"]


def parse(text):
    """-> {op: (ms, checksum)}. Rust prints `op ms chk`; Bend prints `chk op v` and `ms op v`."""
    ms, chk = {}, {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[0] == "chk":
            chk[p[1]] = p[2]
        elif p[0] == "ms":
            ms[p[1]] = float(p[2])
        else:
            ms[p[0]], chk[p[0]] = float(p[1]), p[2]
    return {op: (ms[op], chk[op]) for op in OPS}


def main():
    OUT.mkdir(exist_ok=True)
    times, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if subprocess.run(build, cwd=HERE, env=ENV, stdout=subprocess.DEVNULL).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            runs.append(parse(r.stdout))
            result = runs[-1]
            missing = [op for op in OPS if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        times[name] = {op: statistics.median(x[op][0] for x in runs) for op in OPS}
        checks[name] = {op: runs[0][op][1] for op in OPS}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        if len({c[op] for c in checks.values()}) > 1:
            sys.exit(f"checksum mismatch in {op}: {checks}")
    print("| op | " + " | ".join(times) + " |")
    print("|---|" + "---:|" * len(times))
    for op in OPS:
        print(f"| {op} | " + " | ".join(f"{t[op]:,.1f}" for t in times.values()) + " |")
    print()
    for op in OPS:
        print(f"checksum {op}: {next(iter(checks.values()))[op]}")


main()
