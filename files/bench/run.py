#!/usr/bin/env python3
"""Run file read/hash benchmarks from the files package directory."""

from pathlib import Path
import statistics
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent.parent
fixture = root / "bench/fixture.bin"
expected = 2166136261
for byte in (i * 73 + 255 for i in range(262144)):
    expected = ((expected ^ (byte & 255)) * 16777619) & 0xFFFFFFFF


def run(*args):
    start = time.perf_counter()
    text = subprocess.check_output(args, cwd=root, text=True).strip()
    return text, (time.perf_counter() - start) * 1000


try:
    fixture.write_bytes(bytes((i * 73 + 255) % 256 for i in range(262144)))
    with tempfile.TemporaryDirectory() as tmp:
        native = str(Path(tmp) / "bend-files")
        javascript = native + ".js"
        c = str(Path(tmp) / "files-c")
        rust = str(Path(tmp) / "files-rust")
        for command in (
            ("bend", "bench/bench.bend", "-o", native),
            ("bend", "bench/bench.bend", "-o", javascript),
            ("cc", "-O2", "bench/bench.c", "-o", c),
            ("rustc", "-O", "bench/bench.rs", "-o", rust),
        ):
            subprocess.run(command, cwd=root, check=True)
        for name, command in (
            ("Bend native", (native,)),
            ("Bend JS", ("bun", javascript)),
            ("C", (c,)),
            ("Rust", (rust,)),
            ("Python", ("python3", "bench/bench.py")),
            ("JavaScript", ("bun", "bench/bench.js")),
        ):
            samples = []
            operations = {}
            for _ in range(3):
                text, ms = run(*command)
                checksums = [int(line.split()[-1]) for line in text.splitlines()]
                if not checksums or any(value != expected for value in checksums):
                    raise RuntimeError(f"{name}: {text} != {expected}")
                for line in text.splitlines():
                    fields = line.split()
                    if len(fields) == 3:
                        operations.setdefault(fields[0], []).append(int(fields[1]))
                samples.append(ms)
            print(f"{name}\t{statistics.median(samples):.2f} ms process\t{expected}")
            for operation, times in operations.items():
                print(f"  {operation}\t{statistics.median(times):.0f} ms in process\t{expected}")
finally:
    fixture.unlink(missing_ok=True)
