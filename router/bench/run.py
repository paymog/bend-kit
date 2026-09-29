#!/usr/bin/env python3
"""Build and run the router benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
R3 = subprocess.check_output(["pkg-config", "--cflags", "--libs", "r3"], text=True).split()
STARLETTE = "1.7.0"

# name -> (build argv or None, run argv). Every program prints `route<TAB>ms<TAB>checksum`.
VARIANTS = {
    "C": (["cc", "-O2", "bench.c", *R3, "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--locked", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"starlette=={STARLETTE}", "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


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
            _, ms, chk = r.stdout.strip().split("\t")
            runs.append(float(ms))
            checks[name] = chk
        times[name] = statistics.median(runs)
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    print(f"checksum {checks['Bend']}", file=sys.stderr)

    best = min(times.values())
    print("| op | " + " | ".join(times) + " |")
    print("|---|" + "---:|" * len(times))
    print("| route | " + " | ".join(f"{t:,.1f} ({t / best:.1f}x)" for t in times.values()) + " |")


main()
