#!/usr/bin/env python3
"""Compare prebuilt fixed-tree decoders on the same payload and verify every checksum."""
import statistics
import subprocess
import sys
from pathlib import Path
import run


def main():
    binaries = [Path(arg).resolve() for arg in sys.argv[1:]]
    if not binaries:
        sys.exit("usage: python3 compare.py BINARY [BINARY ...]")
    plain = run.plain_bytes(1_048_576)
    payload = run.deflate_fixed(plain)
    assert run.zlib.decompress(payload, -15) == plain
    run.OUT.mkdir(exist_ok=True)
    (run.OUT / "payload.bin").write_bytes(payload)
    want = {"huffman": str(run.checksum(plain)),
            "fields": str(run.checksum(run.fields13(payload)))}
    times = {binary: {op: [] for op in want} for binary in binaries}
    for repetition in range(21):
        order = binaries[repetition % len(binaries):] + binaries[:repetition % len(binaries)]
        for binary in order:
            result = subprocess.run([binary], cwd=run.HERE, env=run.ENV,
                                    capture_output=True, text=True, check=True)
            rows = [line.split("\t") for line in result.stdout.splitlines() if line.count("\t") == 2]
            assert {op: checksum for op, ms, checksum in rows} == want, (binary, rows, want)
            for op, ms, checksum in rows:
                times[binary][op].append(float(ms))
    print("| binary | huffman ms | fields ms |")
    print("|---|---:|---:|")
    for binary, operations in times.items():
        print(f"| {binary.name} | " + " | ".join(f"{statistics.median(samples):.6f}" for samples in operations.values()) + " |")


if __name__ == "__main__":
    main()
