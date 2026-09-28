"""SSE parse benchmark in Python with sseclient-py (see README.md)."""
import time
from sseclient import SSEClient

data = open("out/stream.sse", "rb").read()


# sseclient-py reads an iterator of byte chunks, as a streaming HTTP response gives.
def pieces():
    for i in range(0, len(data), 65536):
        yield data[i : i + 65536]


t0 = time.perf_counter()
events = [(e.event, e.data) for e in SSEClient(pieces()).events()]
t1 = time.perf_counter()

h = 0
for name, text in events:
    h = (h * 31 + 1) & 0xFFFFFFFF
    for b in name.encode():
        h = (h * 31 + b) & 0xFFFFFFFF
    h = (h * 31 + 2) & 0xFFFFFFFF
    for b in text.encode():
        h = (h * 31 + b) & 0xFFFFFFFF
h = (h + len(events)) & 0xFFFFFFFF
print(f"parse\t{(t1 - t0) * 1000:.3f}\t{h}")
