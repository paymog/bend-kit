import sys

source, destination, size, chunk = sys.argv[1:]
cap, chunk = int(size), int(chunk)
assert 1 <= chunk <= 1048576
count = 0
with open(source, "rb", buffering=0) as src, open(destination, "wb", buffering=0) as dst:
    while count < cap:
        block = src.read(min(chunk, cap - count))
        if not block:
            break
        view = memoryview(block)
        while view:
            n = dst.write(view)
            if not n:
                raise OSError("zero-byte write")
            view = view[n:]
        count += len(block)
    assert src.read(1) == b"", "cap exceeded"
checksum = 2166136261
with open(destination, "rb") as output:
    while block := output.read(chunk):
        for byte in block:
            checksum = ((checksum ^ byte) * 16777619) & 0xffffffff
print(count, checksum)
