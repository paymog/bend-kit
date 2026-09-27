#!/usr/bin/env python3
"""Build and run the shortest F32 benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = "50000"
OPS = ["short"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Bend has N built in.
VARIANTS = {
    "C": (["cc", "-O2", "-o", OUT / "c", "bench.c"], [OUT / "c", N]),
    "Rust": (["rustc", "-C", "opt-level=3", "-o", OUT / "rs", "bench.rs"], [OUT / "rs", N]),
    "Bun": (None, ["bun", "bench.ts", N]),
    "Node": (None, ["node", "--no-warnings", "bench.ts", N]),
    "Python": (None, ["python3", "bench.py", N]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def parse(text):
    """-> {op: (ms, checksum)}. Baselines print `op ms chk`; Bend prints `chk op v` and `ms op v`."""
    got, chk, ms = {}, {}, {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[0] == "chk":
            chk[p[1]] = p[2]
        elif p[0] == "ms":
            ms[p[1]] = float(p[2])
        else:
            got[p[0]] = (float(p[1]), p[2])
    for op, t in ms.items():
        got[op] = (t, chk.get(op))
    return got


def main():
    OUT.mkdir(exist_ok=True)
    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            runs.append(parse(r.stdout))
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in OPS}
        checks[name] = {op: runs[0][op][1] for op in OPS}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = {n: c[op] for n, c in checks.items()}
        if len(set(seen.values())) > 1:
            sys.exit(f"checksum mismatch in {op}: {seen}")

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        print(f"| {op} | " + " | ".join(f"{table[n][op]:,.3f}" for n in names) + " |")
    print()
    print("| op | checksum |")
    print("|---|---:|")
    for op in OPS:
        print(f"| {op} | {checks['Bend'][op]} |")


main()
