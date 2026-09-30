#!/usr/bin/env python3
"""Sequential bounded file-copy benchmark; checksum verification is outside timing."""
import argparse
import hashlib
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def sha256(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def fnv32(path):
    value = 2166136261
    with path.open("rb") as handle:
        while block := handle.read(65536):
            for byte in block:
                value = ((value ^ byte) * 16777619) & 0xffffffff
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=262147)
    parser.add_argument("--chunk", type=int, default=16384)
    parser.add_argument("--rounds", type=int, default=3)
    args = parser.parse_args()
    if not (0 <= args.size <= 0xffffffff and 1 <= args.chunk <= 1048576 and args.rounds > 0):
        parser.error("size must fit U32; chunk must be 1..1048576; rounds must be positive")
    print(f"Command: python3 stream/bench/run.py --size {args.size} --chunk {args.chunk} --rounds {args.rounds}")
    for command in (("bend", "version"), ("cc", "--version"), ("rustc", "--version"),
                    (sys.executable, "--version"), ("bun", "--version")):
        text = subprocess.check_output(command, text=True).strip()
        print(f"Version {' '.join(command)}: {text.splitlines()[0]}")
    with tempfile.TemporaryDirectory(prefix="bend-stream-bench-") as directory:
        tmp = Path(directory)
        bend, c, rust = (tmp / name for name in ("bend-copy", "c-copy", "rust-copy"))
        for command in (("bend", "bench/bench.bend", "-o", str(bend)),
                        ("cc", "-O2", "bench/bench.c", "-o", str(c)),
                        ("rustc", "-O", "bench/bench.rs", "-o", str(rust))):
            subprocess.run(command, cwd=ROOT, check=True)
        commands = (("Bend", (str(bend),)), ("C", (str(c),)), ("Rust", (str(rust),)),
                    ("Python", (sys.executable, str(ROOT / "bench/bench.py"))),
                    ("JavaScript (Bun)", ("bun", str(ROOT / "bench/bench.js"))))
        source, output = tmp / "input.bin", tmp / "output.bin"
        pattern = bytes((i * 73 + 255) % 256 for i in range(65536))

        def fixture(size):
            with source.open("wb") as file:
                for _ in range(size // len(pattern)):
                    file.write(pattern)
                file.write(pattern[:size % len(pattern)])
            return sha256(source), fnv32(source)

        def copy(command, size, expected):
            start = time.perf_counter()
            text = subprocess.check_output((*command, str(source), str(output), str(size), str(args.chunk)),
                                           text=True, cwd=ROOT, timeout=120).strip()
            elapsed = (time.perf_counter() - start) * 1000
            count, checksum = (int(field) for field in text.split())
            if count != size or checksum != expected[1] or output.stat().st_size != size or sha256(output) != expected[0]:
                raise RuntimeError(f"{command}: count/content/checksum mismatch: {text!r}")
            return elapsed

        # Small input first; no concurrent Bend processes or whole-input transfer buffers.
        expected = fixture(259)
        for _, command in commands:
            copy(command, 259, expected)
        expected = fixture(args.size)
        print(f"Input: {args.size} bytes; chunk: {args.chunk}; rounds: {args.rounds}; SHA-256: {expected[0]}; FNV-1a32: {expected[1]}")
        print("| Language | Median copy + checksum process ms | FNV-1a32 | Output SHA-256 |")
        print("|---|---:|---:|---|")
        for name, command in commands:
            samples = [copy(command, args.size, expected) for _ in range(args.rounds)]
            print(f"| {name} | {statistics.median(samples):.3f} | {expected[1]} | {expected[0]} |")


if __name__ == "__main__":
    main()
