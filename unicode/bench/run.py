#!/usr/bin/env python3
"""Build and run the unicode benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
if len(sys.argv) > 2:
    sys.exit("usage: run.py [runs] (input size is fixed at 1,000,000 bytes)")
TARGET = 1_000_000
OPS = ["nfc", "graphemes"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}

VARIANTS = {
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
}

OP_VARIANTS = {
    "nfc": list(VARIANTS),
    "graphemes": ["Bend", "Bun", "Node"],
}


def mbps(ms: float, nbytes: int) -> float:
    return (nbytes / 1_000_000) / (ms / 1000.0)


def main():
    OUT.mkdir(exist_ok=True)
    r = subprocess.run(
        [sys.executable, "gen_input.py", str(TARGET)],
        cwd=HERE,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        sys.exit(r.stderr or "gen_input failed")
    nbytes = (OUT / "input.txt").stat().st_size
    print(r.stderr.strip(), file=sys.stderr)

    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            proc = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if proc.returncode != 0:
                sys.exit(f"{name} failed:\n{proc.stderr or proc.stdout}")
            lines = [l for l in proc.stdout.splitlines() if len(l.split("\t")) == 3]
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in lines)})
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        names = OP_VARIANTS[op]
        seen = {checks[n][op] for n in names if op in checks[n]}
        if len(seen) != 1:
            sys.exit(f"checksum mismatch in {op}: {[(n, checks[n].get(op)) for n in names]}")
        print(f"{op} checksum {seen.pop()}", file=sys.stderr)

    names = list(VARIANTS)
    print("| op | " + " | ".join(f"{n} ms" for n in names) + " | " + " | ".join(f"{n} MB/s" for n in names) + " |")
    print("|---|" + "---:|" * (len(names) * 2))
    for op in OPS:
        ms_cells, mb_cells = [], []
        for n in names:
            if op not in table[n] or n not in OP_VARIANTS[op]:
                ms_cells.append("n/a")
                mb_cells.append("n/a")
            else:
                ms = table[n][op]
                ms_cells.append(f"{ms:,.1f}")
                mb_cells.append(f"{mbps(ms, nbytes):,.2f}")
        print(f"| {op} | " + " | ".join(ms_cells + mb_cells) + " |")


if __name__ == "__main__":
    main()
