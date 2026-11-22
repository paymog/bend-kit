#!/usr/bin/env python3
"""Build and run the text benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}

# name -> (build argv or None, run argv).
VARIANTS = {
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "cargo"],
             [OUT / "cargo" / "release" / "rs"]),
    "Bun": (["bun", "install", "--frozen-lockfile"], ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["uv", "run", "-q", "--with", "rapidfuzz==3.14.3", "python", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}
OPS = ["diff", "distance", "wrap", "wrap_utf"]


def parse(text):
    """-> {op: (ms, checksum)}. Baselines print `op ms chk`; Bend prints `chk op v` and `ms op v`."""
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
    return {op: (ms[op], chk[op]) for op in ms}


def main():
    OUT.mkdir(exist_ok=True)
    times, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            runs.append(parse(r.stdout))
            result = runs[-1]
            missing = [op for op in runs[0] if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        times[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        if len({c[op] for c in checks.values() if op in c}) > 1:
            sys.exit(f"checksum mismatch in {op}: {checks}")
    names = list(times)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        print(f"| {op} | " + " | ".join(f"{times[n][op]:,.1f}" if op in times[n] else "—" for n in names) + " |")
    print()
    for op in OPS:
        print(f"checksum {op}: {checks['Bend'][op]}")


main()
