"""WebSocket benchmark in Python: websockets' Frame.serialize (masked) and Frame.parse (server side)."""
import time
import websockets.frames as frames
from websockets.streams import StreamReader

# serialize draws its mask from secrets.token_bytes; pin it so every language sends the same octets.
frames.secrets.token_bytes = lambda n: b"\x37\xfa\x21\x3d"

src = bytes((i * 7) & 255 for i in range(65536))


def parse(wire):
    reader = StreamReader()
    reader.feed_data(wire)
    gen = frames.Frame.parse(reader.read_exact, mask=True)
    try:
        next(gen)
    except StopIteration as done:
        return done.value
    raise RuntimeError("incomplete frame")


t0 = time.perf_counter()
total = 0
for _ in range(256):
    wire = frames.Frame(frames.Opcode.BINARY, src).serialize(mask=True)
    got = parse(wire)
    total = (total + len(wire) + wire[20] + got.data[65535]) & 0xFFFFFFFF
t1 = time.perf_counter()
print(f"frame\t{(t1 - t0) * 1000:.3f}\t{total}")

# stream: unmasked frames of 1000 octets, fed to the parser in reads of 65536 octets.
wire = frames.Frame(frames.Opcode.BINARY, src[:1000]).serialize(mask=False) * 16384
t0 = time.perf_counter()
total = 0
reader = StreamReader()
gen = frames.Frame.parse(reader.read_exact, mask=False)
pos = 0
while True:
    try:
        next(gen)
    except StopIteration as done:
        total = (total + len(done.value.data) + done.value.data[999]) & 0xFFFFFFFF
        gen = frames.Frame.parse(reader.read_exact, mask=False)
        continue
    if pos >= len(wire):
        break
    reader.feed_data(wire[pos:pos + 65536])
    pos += 65536
t1 = time.perf_counter()
print(f"stream\t{(t1 - t0) * 1000:.3f}\t{total}")
