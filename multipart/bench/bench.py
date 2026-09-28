"""Multipart benchmark: Python (see README.md). The stdlib has no form-data encoder, so encode is left out."""
import email.parser
import email.policy
import time

B = b"bend-kit-0123456789abcdef0123456789abcdef"


def blob() -> bytes:
    out, x = bytearray(1 << 20), 1
    for i in range(len(out)):
        x = (x * 1103515245 + 12345) & 0xFFFFFFFF
        out[i] = x >> 24
    return bytes(out)


def body() -> bytes:
    d = b"--" + B + b"\r\nContent-Disposition: form-data; name=\""
    return (d + b"title\"\r\n\r\nhello multipart\r\n"
            + d + b"blob\"; filename=\"blob.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n" + blob() + b"\r\n"
            + d + b"note\"\r\n\r\nend\r\n--" + B + b"--\r\n")


def chk(h: int, xs: bytes) -> int:
    for x in xs:
        h = (h * 31 + x) & 0xFFFFFFFF
    return h


def main():
    msg = b"Content-Type: multipart/form-data; boundary=" + B + b"\r\n\r\n" + body()
    t0 = time.perf_counter()
    m = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(msg)
    parts = [(p.get_param("name", header="content-disposition").encode(), p.get_payload(decode=True)) for p in m.iter_parts()]
    ms = (time.perf_counter() - t0) * 1000
    h, n = 0, 0
    for name, b in parts:
        h = chk(chk(h, name), b)
        n += len(name) + len(b)
    print(f"decode\t{ms:.3f}\t{(h + n) & 0xFFFFFFFF}")


main()
