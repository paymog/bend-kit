"""Tar benchmark in Python with the standard library's tarfile (see README.md)."""
import io, tarfile, time

data = open("out/input.tar", "rb").read()


def decode(b):
    ents = []
    with tarfile.open(fileobj=io.BytesIO(b), mode="r:", encoding="utf-8") as t:
        for m in t:
            if m.isreg():
                ents.append((False, m.name, t.extractfile(m).read()))
            elif m.isdir():
                ents.append((True, m.name, b""))
            else:
                raise ValueError(f"unexpected member type {m.type!r}")
    return ents


def encode(ents):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.PAX_FORMAT, encoding="utf-8") as t:
        for is_dir, name, body in ents:
            ti = tarfile.TarInfo(name)
            if is_dir:
                ti.type, ti.mode = tarfile.DIRTYPE, 0o755
                t.addfile(ti)
            else:
                ti.size, ti.mode = len(body), 0o644
                t.addfile(ti, io.BytesIO(body))
    return buf.getvalue()


# Checksum (see run.py): per entry fold kind, name bytes + length, file data bytes + length; add the count.
def checksum(ents):
    def fold(bs, h):
        for b in bs:
            h = (h * 31 + b) & 0xFFFFFFFF
        return (h * 31 + len(bs)) & 0xFFFFFFFF

    h = 0
    for is_dir, name, body in ents:
        name = name.encode()
        if is_dir:
            h = fold(name[:-1] if name.endswith(b"/") else name, (h * 31 + 2) & 0xFFFFFFFF)
        else:
            h = fold(body, fold(name, (h * 31 + 1) & 0xFFFFFFFF))
    return (h + len(ents)) & 0xFFFFFFFF


t0 = time.perf_counter()
ents = decode(data)
t1 = time.perf_counter()
out = encode(ents)
t2 = time.perf_counter()

print(f"decode\t{(t1 - t0) * 1000:.3f}\t{checksum(ents)}")
print(f"encode\t{(t2 - t1) * 1000:.3f}\t{checksum(decode(out))}")
