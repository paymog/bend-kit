#!/usr/bin/env python3
"""Compare prebuilt fixed-tree decoders on the same payload and verify every checksum."""
import argparse
import statistics
import subprocess
from pathlib import Path
import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mixed", action="store_true")
    parser.add_argument("--size", type=int, default=1_048_576)
    parser.add_argument("--rounds", type=int, default=21)
    parser.add_argument("binaries", nargs="+", type=Path)
    args = parser.parse_args()
    binaries = [binary.resolve() for binary in args.binaries]
    plain = run.plain_bytes(args.size)
    payload = run.deflate_fixed(plain)
    assert run.zlib.decompress(payload, -15) == plain
    run.OUT.mkdir(exist_ok=True)
    (run.OUT / "payload.bin").write_bytes(payload)
    want = {"huffman": str(run.checksum(plain)),
            "fields": str(run.checksum(run.fields13(payload)))}
    if args.mixed:
        values = ((int.from_bytes(payload[i:i + 2], "little") & 8191)
                  if (i // 2) % 2 == 0
                  else (int.from_bytes(payload[i:i + 2], "big") >> 3)
                  for i in range(0, len(payload) - 1, 2))
        want["mixed"] = str(run.checksum(values))
    print("checksums:", want, flush=True)
    times = {binary: {op: [] for op in want} for binary in binaries}
    for repetition in range(args.rounds):
        order = binaries[repetition % len(binaries):] + binaries[:repetition % len(binaries)]
        for binary in order:
            result = subprocess.run([binary], cwd=run.HERE, env=run.ENV,
                                    capture_output=True, text=True, check=True)
            rows = [line.split("\t") for line in result.stdout.splitlines() if line.count("\t") == 2]
            assert {op: checksum for op, ms, checksum in rows} == want, (binary, rows, want)
            for op, ms, checksum in rows:
                times[binary][op].append(float(ms))
    print("| binary | " + " | ".join(op + " ms" for op in want) + " |")
    print("|---|" + "---:|" * len(want))
    for binary, operations in times.items():
        print(f"| {binary.name} | " + " | ".join(f"{statistics.median(samples):.6f}" for samples in operations.values()) + " |")
    for binary in binaries[1:]:
        paired = {op: statistics.median((b / a - 1) * 100 for a, b in
                  zip(times[binaries[0]][op], times[binary][op])) for op in want}
        print(binary.name, "paired changes (%):", paired)


if __name__ == "__main__":
    main()
