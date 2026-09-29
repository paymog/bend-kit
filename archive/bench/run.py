#!/usr/bin/env python3
"""Write the ZIP fixture, build and run the read benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys, zipfile, zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
TEXT = int(sys.argv[2]) if len(sys.argv) > 2 else 1_048_576
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
LIBARCHIVE = os.environ.get("LIBARCHIVE_PREFIX") or subprocess.run(
    ["brew", "--prefix", "libarchive"], capture_output=True, text=True, check=True
).stdout.strip()

# name -> (build argv or None, run argv). Every program reads out/fixture.zip and prints
# `read<TAB>ms<TAB>checksum`, `entries<TAB>0<TAB>count`, `bytes<TAB>0<TAB>data bytes`.
VARIANTS = {
    "C (libarchive)": (
        ["cc", "-O2", f"-I{LIBARCHIVE}/include", "bench.c", f"-L{LIBARCHIVE}/lib", "-larchive", "-lz", "-o", OUT / "c"],
        [OUT / "c"],
    ),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}

WORDS = (
    b"the of and to in is it that was for on are with as be at by this had not but from or have an they "
    b"which you were her all she there would their we him been has when who will more no if out so said "
    b"what up its about into than them can only other new some could time these two may then do first any "
    b"my now such like our over man me even most made after also did many before must through back years"
).split()


def lcg(x: int) -> int:
    return (x * 1664525 + 1013904223) & 0xFFFFFFFF


def text(n: int, seed: int) -> bytes:
    out, x = bytearray(), seed
    while len(out) < n:
        x = lcg(x)
        out += WORDS[(x >> 8) % len(WORDS)] + (b"\n" if x & 15 == 0 else b" ")
    return bytes(out[:n])


def noise(n: int, seed: int) -> bytes:
    out, x = bytearray(n), seed
    for i in range(n):
        x = lcg(x)
        out[i] = x >> 24
    return bytes(out)


S, D = zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED


def entries(n: int) -> list[tuple[str, int, bytes]]:
    """(name, method, data) in archive order."""
    docs = [(f"docs/{i:03}.txt", D, text(512 + i * 61, 0xA000 + i)) for i in range(64)]
    return [
        ("empty-stored", S, b""),
        ("empty-deflated", D, b""),
        ("hello.txt", S, b"hello, zip\n"),
        ("text.txt", D, text(n, 0xDEADBEEF)),
        ("noise.bin", S, noise(n // 4, 0xC0FFEE01)),
        ("noise-deflated.bin", D, noise(4096, 0xBADF00D)),
        ("names/cafe.txt", S, "cafe\n".encode()),
        *docs,
    ]


def fixture(items: list[tuple[str, int, bytes]]) -> bytes:
    path = OUT / "fixture.zip"
    with zipfile.ZipFile(path, "w") as z:
        for name, method, data in items:
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = method
            z.writestr(info, data, compresslevel=6)
    return path.read_bytes()


def mbps(n: int, ms: float) -> float:
    return (n / 1_000_000) / (ms / 1000.0) if ms else float("inf")


def main():
    OUT.mkdir(exist_ok=True)
    items = entries(TEXT)
    zip_bytes = fixture(items)
    data = sum(len(d) for _, _, d in items)
    print(f"{len(items)} entries, {data:,} data bytes, zip {len(zip_bytes):,} bytes, crc32 {zlib.crc32(zip_bytes):08x}", file=sys.stderr)

    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr or b.stdout}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            lines = [l.split("\t") for l in r.stdout.splitlines() if len(l.split("\t")) == 3]
            runs.append({op: (ms, c) for op, ms, c in lines})
        if "read" not in runs[0] or "failed" in runs[0]["read"][1]:
            sys.exit(f"{name} did not read the fixture: {runs[0]}")
        table[name] = statistics.median(float(x["read"][0]) for x in runs)
        checks[name] = tuple(runs[0].get(k, ("", "missing"))[1] for k in ("read", "entries", "bytes"))
        print(f"ran {name}", file=sys.stderr)

    want = (checks["Python"][0], str(len(items)), str(data))
    bad = {n: c for n, c in checks.items() if c != want}
    if bad:
        sys.exit(f"checksum mismatch: want (checksum, entries, bytes) {want}, got {bad}")
    print(f"checksum {want[0]}, entries {want[1]}, bytes {want[2]}", file=sys.stderr)

    print("| variant | read ms | MB/s |")
    print("|---:|---:|---:|")
    for n, ms in table.items():
        print(f"| {n} | {ms:,.1f} | {mbps(data, ms):,.0f} |")


if __name__ == "__main__":
    main()
