#!/usr/bin/env python3
"""Measure collision fallback stages on the pinned native Bend runtime."""
import json
import statistics
import subprocess
from pathlib import Path

here = Path(__file__).resolve().parent
out = here / "out"
out.mkdir(exist_ok=True)
version = subprocess.check_output(["bend", "version"], text=True).strip()
assert version == "bend 2.0.40", version
subprocess.run(["bend", "collision.bend", "-o", str(out / "collision.c")], cwd=here, check=True)
source = (out / "collision.c").read_text()
needle = "INLINE u64 heap_alloc(Env e, u32 cls) {"
assert source.count(needle) == 1, "The native allocator changed. Review the instrumentation."
instrumented = source.replace(needle, "#define COLLISION_COUNTS\nstatic unsigned long long collision_calls, collision_bytes;\n" + needle + "\n  collision_calls++;\n  collision_bytes += 8ull << cls;")
(out / "collision-counted.c").write_text(instrumented)
for name in ("collision", "collision-counted"):
    subprocess.run(["clang", "-O2", "-pthread", str(out / f"{name}.c"), "-o", str(out / name)], check=True)

def run(name, mode, size):
    result = subprocess.run([str(out / name), mode, str(size), "+RTS", "--threads", "1", "-RTS"], capture_output=True, text=True, check=True)
    values = dict(line.split("\t", 1) for line in result.stdout.splitlines() if "\t" in line)
    assert values["roundtrip"] == "True", result.stdout
    assert values["checksum"] == str(2 * ((size + 92) // 100)), result.stdout
    assert values["hash script exact"] == ("False" if mode == "collision" else "True"), result.stdout
    assert values["public roundtrip"] == "True", result.stdout
    return values

# The suffix keeps the known FNV collision and includes non-UTF-8 octets.
def fnv(data):
    h = 2166136261
    for byte in data:
        h = ((h ^ byte) * 16777619) & 0xffffffff
    return h
suffix = b"x" * 128 + b"\0\xff\x80\r\n"
assert fnv(b"aan1wu" + suffix) == fnv(b"aa0tfa" + suffix)
assert fnv(b"aan1wu" + suffix) != fnv(b"aa0tfb" + suffix)
for mode in ("collision", "control"):
    run("collision", mode, 8)
    run("collision-counted", mode, 8)

samples = {mode: [] for mode in ("collision", "control")}
for pair in range(5):
    order = ("collision", "control") if pair % 2 == 0 else ("control", "collision")
    for mode in order:
        timed = run("collision", mode, 10000)
        counted = run("collision-counted", mode, 10000)
        sample = {key: float(value) for key, value in timed.items() if key.endswith(" ms")}
        sample.update({key: [int(n) for n in value.split(":")] for key, value in counted.items() if key.endswith(" allocations")})
        samples[mode].append(sample)
        print(pair + 1, mode, json.dumps(sample), flush=True)
for mode, runs in samples.items():
    print("median", mode, json.dumps({key: statistics.median(run[key] for run in runs) if not isinstance(runs[0][key], list) else [statistics.median(run[key][i] for run in runs) for i in range(2)] for key in runs[0]}))
(out / "collision-samples.json").write_text(json.dumps({"compiler": version, "samples": samples}, indent=2) + "\n")
