#!/usr/bin/env python3
"""Build and run the IP address benchmark serially; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OPS = ["addr", "cidr"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program prints `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "C": (["cc", "-O2", "bench.c", "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["rustc", "-O", "--edition", "2021", "bench.rs", "-o", OUT / "rs"], [OUT / "rs"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def main():
    OUT.mkdir(exist_ok=True)
    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr or b.stdout}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            got = {f[0]: (float(f[1]), f[2]) for f in (l.split("\t") for l in r.stdout.splitlines()) if len(f) == 3}
            if set(got) != set(OPS):
                sys.exit(f"{name} printed ops {sorted(got)}, want {OPS}:\n{r.stdout}")
            runs.append(got)
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in OPS}
        checks[name] = {op: {x[op][1] for x in runs} for op in OPS}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = set().union(*(checks[n][op] for n in checks))
        if len(seen) != 1:
            sys.exit(f"checksum mismatch in {op}: {[(n, sorted(checks[n][op])) for n in checks]}")
        print(f"{op} checksum {seen.pop()}", file=sys.stderr)

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        best = min(t[op] for t in table.values())
        print(f"| {op} | " + " | ".join(f"{table[n][op]:,.1f} ({table[n][op] / best:.1f}x)" for n in names) + " |")


if __name__ == "__main__":
    main()
