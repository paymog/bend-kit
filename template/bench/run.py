#!/usr/bin/env python3
"""Build and run the Mustache render benchmark; print a markdown table. See README.md."""
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
    "Python": (None, ["uv", "run", "-q", "--with", "chevron==0.14.0", "python", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def parse(text):
    """-> (ms, fnv, len). Baselines print `render ms fnv`; Bend prints `chk render v` and `ms render v`. All print `len render v`."""
    ms = chk = n = None
    for line in text.splitlines():
        p = line.split("\t")
        if p[0] == "render":
            ms, chk = float(p[1]), p[2]
        elif p[0] == "chk":
            chk = p[2]
        elif p[0] == "ms":
            ms = float(p[2])
        elif p[0] == "len":
            n = p[2]
    return ms, (chk, n)


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
        times[name] = statistics.median(ms for ms, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) > 1:
        sys.exit(f"checksum mismatch: {checks}")
    best = min(times.values())
    names = list(times)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    print("| render | " + " | ".join(f"{times[n]:,.1f} ({times[n] / best:.1f}x)" for n in names) + " |")
    chk, n = checks["Bend"]
    print(f"\nchecksum {chk}, {n} bytes out")


main()
