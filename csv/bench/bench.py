import csv, io, time

data = open("out/doc.csv", "rb").read()


def checksum(b):
    h = 0
    for c in b:
        h = (h * 31 + c) & 0xFFFFFFFF
    return (h + len(b)) & 0xFFFFFFFF


# latin-1 maps each octet to one code point, as Bend reads one Char per octet.
t0 = time.perf_counter()
rows = list(csv.reader(io.StringIO(data.decode("latin-1"), newline="")))
t1 = time.perf_counter()
buf = io.StringIO(newline="")
csv.writer(buf, lineterminator="\r\n").writerows(rows)
out = buf.getvalue().encode("latin-1")
t2 = time.perf_counter()

sum_ = checksum(out)
print(f"parse\t{(t1 - t0) * 1000:.3f}\t{sum_}")
print(f"encode\t{(t2 - t1) * 1000:.3f}\t{sum_}")
