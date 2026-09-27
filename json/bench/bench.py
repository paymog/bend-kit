import json, time

with open("out/doc.json", "rb") as f:
    RAW = f.read()


def chk(s: str) -> int:
    h = 0
    for c in s:
        h = (h * 31 + ord(c)) & 0xFFFFFFFF
    return (h + len(s)) & 0xFFFFFFFF


def enc(v) -> str:
    return json.dumps(v, separators=(",", ":"), ensure_ascii=False)


t0 = time.perf_counter()
v = json.loads(RAW)
ms = (time.perf_counter() - t0) * 1000
print(f"parse.bytes\t{ms:.3f}\t{chk(enc(v))}")

t0 = time.perf_counter()
out = enc(v).encode()
ms = (time.perf_counter() - t0) * 1000
print(f"encode.bytes\t{ms:.3f}\t{chk(out.decode('latin-1'))}")
