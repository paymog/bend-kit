#!/usr/bin/env python3
"""Build and run the websocket benchmark; print a markdown table. See README.md."""
import json, os, shutil, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
MB = 256 * 65536 / 1e6
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1", "PYTHONPATH": str(OUT / "py")}


def setup():
    OUT.mkdir(exist_ok=True)
    js = OUT / "js"
    js.mkdir(exist_ok=True)
    (js / "package.json").write_text(json.dumps({"private": True, "type": "module", "dependencies": {"ws": "8.22.0"}}))
    shutil.copy(HERE / "bench.ts", js / "bench.ts")
    steps = [
        (["bun", "install", "--silent"], js),
        ([sys.executable, "-m", "pip", "install", "-q", "--target", str(OUT / "py"), "websockets==17.1"], HERE),
        (["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", str(OUT / "rs")], HERE),
        (["bend", "bench.bend", "-o", str(OUT / "bend")], HERE),
    ]
    for cmd, cwd in steps:
        if subprocess.run(cmd, cwd=cwd, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {' '.join(cmd)}")


VARIANTS = {
    "Rust": ([OUT / "rs" / "release" / "bench"], HERE),
    "Node": (["node", "--no-warnings", "bench.ts"], OUT / "js"),
    "Python": ([sys.executable, "bench.py"], HERE),
    "Bend": ([OUT / "bend"], HERE),
}


def main():
    setup()
    table, checks = {}, {}
    for name, (cmd, cwd) in VARIANTS.items():
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(cmd, cwd=cwd, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            op, ms, c = next(l for l in r.stdout.splitlines() if l.startswith("frame\t")).split("\t")
            runs.append((float(ms), c))
        table[name] = statistics.median(ms for ms, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    print(f"frame checksum {next(iter(checks.values()))}", file=sys.stderr)

    best = min(table.values()) or 0.001
    print("| variant | frame ms | MB/s | vs fastest |")
    print("|---:|---:|---:|---:|")
    for n, ms in table.items():
        print(f"| {n} | {ms:,.1f} | {MB / (ms / 1000):,.0f} | {ms / best:.1f}x |")


if __name__ == "__main__":
    main()
