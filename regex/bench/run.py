#!/usr/bin/env python3
"""Build and run the regex benchmark; print a markdown table. See README.md."""
import os
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OPS = ["is_match", "is_match_early", "find_captures", "find_early", "redos", "large"]
TIMEOUT = {"is_match": 600, "is_match_early": 600, "find_captures": 600, "find_early": 600, "redos": 10, "large": 60}
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

VARIANTS = {
    "C": (["clang", "-O2", "-o", OUT / "c", "bench.c"], lambda op: [OUT / "c"]),
    "Python": (None, lambda op: ["python3", "bench.py"]),
    "Bun": (None, lambda op: ["bun", "bench.ts"]),
    "Node": (None, lambda op: ["node", "--no-warnings", "bench.ts"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], lambda op: [OUT / "bend"]),
}


def parse(text):
    got = {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[0] == "chk":
            got.setdefault(p[1], {})["chk"] = p[2]
        elif p[0] == "ms":
            got.setdefault(p[1], {})["ms"] = float(p[2])
        else:
            got[p[0]] = {"ms": float(p[1]), "chk": p[2]}
    return {op: (v["ms"], v.get("chk")) for op, v in got.items() if "ms" in v}


def run_op(name, cmd, op):
    args = cmd(op) + ([] if name == "Bend" else ["1048576"]) + [op]
    try:
        r = subprocess.run(args, cwd=HERE, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[op])
    except subprocess.TimeoutExpired:
        return "timeout", None
    if r.returncode != 0:
        sys.exit(f"{name} {op} failed:\n{r.stderr}")
    parsed = parse(r.stdout)
    if op not in parsed:
        sys.exit(f"{name} {op} missing from output:\n{r.stdout}")
    return parsed[op]


def main():
    OUT.mkdir(exist_ok=True)
    print("Bend smoke (4096 code points)...", file=sys.stderr)
    if subprocess.run(["bend", "smoke.bend", "-o", OUT / "smoke"], cwd=HERE, env=ENV).returncode:
        sys.exit("Bend smoke build failed")
    if subprocess.run([OUT / "smoke"], cwd=HERE, env=ENV).returncode:
        sys.exit("Bend smoke run failed")

    table, checks = {}, {}
    for name, (build, cmd) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV).returncode:
            sys.exit(f"build failed: {name}")
        table[name], checks[name] = {}, {}
        for op in OPS:
            times = []
            chk = None
            nruns = 1 if op == "redos" else RUNS
            for _ in range(nruns):
                ms, c = run_op(name, cmd, op)
                if ms != "timeout":
                    times.append(ms)
                if c is not None:
                    chk = c
            table[name][op] = statistics.median(times) if times else "timeout"
            if chk is not None:
                checks[name][op] = chk
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = {n: c[op] for n, c in checks.items() if op in c}
        if len(set(seen.values())) > 1:
            sys.exit(f"checksum mismatch in {op}: {seen}")

    names = list(VARIANTS)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        cells = []
        for n in names:
            t = table[n][op]
            cells.append("timeout" if t == "timeout" else f"{t:,.1f}")
        print(f"| {op} | " + " | ".join(cells) + " |")
    print()
    print("| op | checksum |")
    print("|---|---:|")
    for op in OPS:
        ref = next(c[op] for c in checks.values() if op in c)
        print(f"| {op} | {ref} |")


if __name__ == "__main__":
    main()
