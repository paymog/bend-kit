#!/usr/bin/env python3
"""Build and run the multipart benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OPS = ["encode", "decode"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program prints `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "Go": (["go", "build", "-o", OUT / "go", "bench.go"], [OUT / "go"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


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
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines())})
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = {checks[n][op] for n in checks if op in checks[n]}
        if len(seen) != 1:
            sys.exit(f"checksum mismatch in {op}: {[(n, checks[n].get(op)) for n in checks]}")
        print(f"{op} checksum {seen.pop()}", file=sys.stderr)

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        best = min(t[op] for t in table.values() if op in t)
        cells = [f"{table[n][op]:,.1f} ({table[n][op] / best:.1f}x)" if op in table[n] else "n/a" for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")


main()
