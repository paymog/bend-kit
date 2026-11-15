#!/usr/bin/env python3
"""Build and run the crdt benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv, run argv). Every program runs 2^14 rounds of each op.
VARIANTS = {
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rust/Cargo.toml", "--target-dir", OUT / "rust"], [OUT / "rust" / "release" / "crdt-bench", "14"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend", "14"]),
}
OPS = ["gossip", "gossip-sparse"]


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
