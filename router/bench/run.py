#!/usr/bin/env python3
"""Build and run the router benchmark; print a markdown table. See README.md."""
import statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
sys.path.insert(0, str(HERE.parents[1] / "camber"))
from run_dispatch import guarded
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
R3 = subprocess.check_output(["pkg-config", "--cflags", "--libs", "r3"], text=True).split()
STARLETTE = "1.7.0"

# name -> (build argv or None, run argv). Every program prints `route<TAB>ms<TAB>checksum`.
VARIANTS = {
    "C": (["cc", "-O2", str(HERE / "bench.c"), *R3, "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--locked", "--manifest-path", str(HERE / "rs/Cargo.toml"), "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (None, ["bun", str(HERE / "bench.ts")]),
    "Node": (None, ["node", "--no-warnings", str(HERE / "bench.ts")]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"starlette=={STARLETTE}", "python3", str(HERE / "bench.py")]),
    "Bend": (["bend", str(HERE / "bench.bend"), "-o", OUT / "bend"], [OUT / "bend", "--threads", "1", "--gpu", "off"]),
}


def main():
    OUT.mkdir(exist_ok=True)
    times = {}
    for name, (build, run) in VARIANTS.items():
        if build:
            guarded(build, 180)
        runs = []
        for _ in range(RUNS):
            stdout, _, _ = guarded(run, 180)
            _, ms, chk = stdout.strip().split("\t")
            if chk != "3019866368":
                sys.exit(f"{name} checksum mismatch: {chk}")
            runs.append(float(ms))
        times[name] = statistics.median(runs)
        print(f"ran {name}", file=sys.stderr)

    print("checksum 3019866368", file=sys.stderr)

    best = min(times.values())
    print("| op | " + " | ".join(times) + " |")
    print("|---|" + "---:|" * len(times))
    print("| route | " + " | ".join(f"{t:,.1f} ({t / best:.1f}x)" for t in times.values()) + " |")


main()
