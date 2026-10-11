#!/usr/bin/env python3
"""Build and run the authorization benchmark; print a markdown table."""
import os
import shutil
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}


def command(argv, capture=False):
    result = subprocess.run(argv, cwd=HERE, env=ENV, capture_output=capture, text=True)
    if result.returncode:
        sys.exit(f"command failed: {argv}\n{result.stderr or ''}")
    return result.stdout


def parse(text):
    ms = chk = None
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[:2] == ["chk", "authz"]:
            chk = int(p[2])
        elif p[:2] == ["ms", "authz"]:
            ms = float(p[2])
        elif p[0] == "authz":
            ms, chk = float(p[1]), int(p[2])
    if ms is None or chk is None:
        sys.exit(f"missing benchmark output:\n{text}")
    return ms, chk


def main():
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    lg = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    if runs < 1 or not 0 <= lg <= 26:
        sys.exit("usage: python3 run.py [positive runs] [lg: 0..26]")
    OUT.mkdir(exist_ok=True)
    command(["python3", "-m", "pip", "install", "--quiet", "--target", OUT / "py", "--upgrade", "casbin==1.43.0"])
    command(["npm", "install", "--silent", "--prefix", OUT / "js", "casbin@5.51.1"])
    shutil.copyfile(HERE / "bench.ts", OUT / "js" / "bench.ts")
    command(["cargo", "build", "-q", "--release", "--manifest-path", "rust/Cargo.toml", "--target-dir", OUT / "rust"])
    command(["bend", "bench.bend", "-o", OUT / "bend"])
    variants = {
        "Rust": [OUT / "rust" / "release" / "authz-bench", str(lg)],
        "Bun": ["bun", OUT / "js" / "bench.ts", str(lg)],
        "Node": ["node", "--no-warnings", "--experimental-strip-types", OUT / "js" / "bench.ts", str(lg)],
        "Python": ["python3", "bench.py", str(lg)],
        "Bend": [OUT / "bend", str(lg)],
    }
    times, checks = {}, {}
    # Nine of the 64 fixture requests are allowed; check every repetition too.
    expected = (9 * (1 << lg)) & 0xffffffff
    for name, argv in variants.items():
        samples = [parse(command(argv, capture=True)) for _ in range(runs)]
        checks[name] = [chk for _, chk in samples]
        if any(chk != expected for _, chk in samples):
            sys.exit(f"checksum mismatch: expected {expected}, {checks}")
        times[name] = statistics.median(ms for ms, _ in samples)
        print(f"ran {name}", file=sys.stderr)
    print("| op | " + " | ".join(times) + " |")
    print("|---|" + "---:|" * len(times))
    print("| authz | " + " | ".join(f"{ms:,.3f}" for ms in times.values()) + " |")
    print(f"\nchecksum: {expected}")


if __name__ == "__main__":
    main()
