#!/usr/bin/env python3
"""Build popular-library implementations, then compare the fixed-fixture checksum."""
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent
OUT = HERE / "out"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "CARGO_TARGET_DIR": str(OUT / "target"),
       "PYTHONPATH": str(OUT)}


def command(argv, cwd=HERE):
    result = subprocess.run(list(map(str, argv)), cwd=cwd, env=ENV,
                            text=True, capture_output=True)
    if result.returncode:
        sys.exit(f"{argv[0]} failed:\n{result.stdout}\n{result.stderr}")
    return result.stdout.strip()


def main():
    if not __debug__:
        raise SystemExit("Run without -O; assertions are the checks")
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    OUT.mkdir(exist_ok=True)
    command(["protoc", f"-I{HERE}", f"--python_out={OUT}", f"--c_out={OUT}", "bench.proto"])
    command(["protoc", f"-I{HERE}", f"--plugin=protoc-gen-bend={PACKAGE / 'protoc-gen-bend'}",
             f"--bend_out=runtime_import=../../protobuf.bend:{OUT}", "bench.proto"])
    sys.path.insert(0, str(OUT))
    sys.path.insert(0, str(PACKAGE))
    import bench_pb2
    from fixture import sample
    raw = sample(bench_pb2).SerializeToString(deterministic=True)
    (OUT / "fixture.bin").write_bytes(raw)
    (OUT / "fixture.bend").write_text(
        'import Base\nimport bend-kit-bytes@0.3.2.0/bytes.bend as B\n'
        'def bytes() -> Maybe<&1, B.Bytes>:\n  B.from_hex("' + raw.hex() + '")\n')
    shutil.copy(HERE / "package.json", OUT / "package.json")
    command(["bun", "install"], cwd=OUT)
    flags = command(["pkg-config", "--cflags", "--libs", "libprotobuf-c"]).split()
    shutil.copy(HERE / "bench.js", OUT / "bench.js")
    shutil.copy(HERE / "bench.proto", OUT / "bench.proto")
    command(["cc", "-O2", f"-I{OUT}", HERE / "bench.c", OUT / "bench.pb-c.c",
             "-o", OUT / "c", *flags])
    command(["cargo", "build", "--release", "--manifest-path", HERE / "Cargo.toml"])
    command(["bend", HERE / "bench.bend", "-o", OUT / "bend"])
    variants = {
        "Bend": [OUT / "bend"],
        "C (protobuf-c)": [OUT / "c", "100"],
        "Rust (prost)": [OUT / "target" / "release" / "bench", "100"],
        "Python (official)": [sys.executable, HERE / "bench.py", "100"],
        "JavaScript (protobufjs/Bun)": ["bun", OUT / "bench.js", "100"],
    }
    expected = sum(raw) * 100
    print(f"Input: {len(raw)} bytes; 100 decode/encode iterations; checksum {expected}.")
    print("| implementation | median loop ms | checksum |")
    print("|---|---:|---:|")
    for name, argv in variants.items():
        times = []
        for _ in range(runs):
            checksum, elapsed = command(argv, cwd=OUT).split("\t")
            times.append(float(elapsed))
            assert int(checksum) == expected, f"{name}: checksum {checksum} != {expected}"
        print(f"| {name} | {statistics.median(times):.3f} | {expected} |")


if __name__ == "__main__":
    main()
