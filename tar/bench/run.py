#!/usr/bin/env python3
"""Write the input, build and run the tar benchmark; print a markdown table. See README.md."""
import io, os, statistics, subprocess, sys, tarfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ENTRIES = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
OPS = ["decode", "encode"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
BREW = "/opt/homebrew/opt/libarchive"
TAR_STREAM = "3.2.1"
BEND_MAX = 16777216  # bench.bend reads at most this many bytes

# name -> (build argv or None, run argv). Every program reads out/input.tar and prints `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "C": (["cc", "-O2", f"-I{BREW}/include", "bench.c", f"-L{BREW}/lib", "-larchive", "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (["sh", "-c", f"npm i -s --prefix out/js tar-stream@{TAR_STREAM} && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}

# Payload sizes around the 512-byte block boundary, plus a spread up to 8 KiB.
PREFIX_NAME = ("nested/" * 15 + "file.txt").encode()
SIZES = [0, 1, 511, 512, 513, 1024]


def entries(n):
    """(is_dir, name bytes, data bytes) in archive order."""
    out = []
    for i in range(n):
        d = f"dir{i // 20:04d}"
        if i % 20 == 0:
            out.append((True, d.encode(), b""))
            continue
        name = [
            f"{d}/file{i}.txt",
            f"{d}/fichier-{i}-ete-nihon.bin",  # ASCII: libarchive on macOS rewrites UTF-8 PAX paths to NFD
            f"{d}/" + "long-segment-" * 10 + f"{i}.dat",  # one 130+ byte component: no ustar prefix split, PAX path
            f"{d}/deep/a/b/c/{i}",
        ][i % 4]
        size = SIZES[i % 7] if i % 7 < len(SIZES) else (i * 7919) % 8192
        pattern = bytes((i + j) & 255 for j in range(256))
        out.append((False, name.encode(), (pattern * (size // 256 + 1))[:size]))
    return out


def write_tar(path, ents):
    # Python writes PAX entries; append one ustar prefix-split name.
    with tarfile.open(path, "w", format=tarfile.PAX_FORMAT, encoding="utf-8") as t:
        for is_dir, name, data in ents[:-1]:
            ti = tarfile.TarInfo(name.decode())
            ti.mtime = 0
            if is_dir:
                ti.type, ti.mode = tarfile.DIRTYPE, 0o755
                t.addfile(ti)
            else:
                ti.size, ti.mode = len(data), 0o644
                if len(data) == 513:
                    ti.pax_headers = {"size": "513"}
                t.addfile(ti, io.BytesIO(data))
    with tarfile.open(path, "a", format=tarfile.USTAR_FORMAT) as t:
        ti = tarfile.TarInfo(PREFIX_NAME.decode())
        ti.size = len(ents[-1][2])
        t.addfile(ti, io.BytesIO(ents[-1][2]))

    # Make PAX size authoritative rather than repeating the ustar size.
    with tarfile.open(path, "r:") as t, path.open("r+b") as f:
        for ti in t:
            if ti.isfile() and ti.size == 513:
                off = ti.offset_data - 512
                f.seek(off)
                block = bytearray(f.read(512))
                block[124:136] = b"00000000000\0"
                block[148:156] = b"        "
                block[148:156] = f"{sum(block):06o}\0 ".encode()
                f.seek(off)
                f.write(block)


# Checksum over the entries, in order (u32, wrapping). Per entry: fold the kind (1 file, 2 dir), then the name
# bytes and name length, then (files only) the data bytes and data length, where fold is h = h*31 + x.
# A directory's one trailing '/' is dropped. Finally add the entry count.
def checksum(ents):
    def fold(bs, h):
        for b in bs:
            h = (h * 31 + b) & 0xFFFFFFFF
        return (h * 31 + len(bs)) & 0xFFFFFFFF

    h = 0
    for is_dir, name, data in ents:
        if is_dir:
            h = fold(name[:-1] if name.endswith(b"/") else name, (h * 31 + 2) & 0xFFFFFFFF)
        else:
            h = fold(data, fold(name, (h * 31 + 1) & 0xFFFFFFFF))
    return str((h + len(ents)) & 0xFFFFFFFF)


def main():
    OUT.mkdir(exist_ok=True)
    ents = entries(ENTRIES - 1) + [(False, PREFIX_NAME, b"prefix")]
    write_tar(OUT / "input.tar", ents)
    size = (OUT / "input.tar").stat().st_size
    if size > BEND_MAX:
        sys.exit(f"input is {size:,} bytes; bench.bend reads at most {BEND_MAX:,}")
    want = checksum(ents)
    print(f"input {size:,} bytes, {ENTRIES} entries, checksum {want}", file=sys.stderr)

    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stdout}{b.stderr}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed ({r.returncode}):\n{r.stdout}{r.stderr}")
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines())})
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in OPS}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    # decode sums the entries read from input.tar; encode sums the entries read back from the program's own archive.
    for op in OPS:
        bad = [(n, checks[n].get(op)) for n in checks if checks[n].get(op) != want]
        if bad:
            sys.exit(f"checksum mismatch in {op}: want {want}, got {bad}")
        print(f"{op} checksum {want}", file=sys.stderr)

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        # A zero duration has no useful ratio.
        best = min(t[op] for t in table.values())
        cells = [f"{table[n][op]:,.1f}" + (f" ({table[n][op] / best:.1f}x)" if best > 0 else "") for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")


main()
