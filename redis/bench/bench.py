"""RESP decode benchmark in Python with redis-py's RESP3 parser (see README.md)."""
import time
from redis._parsers.resp3 import _RESP3Parser
from redis._parsers.socket import SocketBuffer
from redis.exceptions import ConnectionError


# redis-py reads replies from a socket; this one hands out the file 64 KiB at a time.
class Sock:
    def __init__(self, data):
        self.data, self.at = memoryview(data), 0

    def recv(self, n):
        chunk = self.data[self.at : self.at + n].tobytes()
        self.at += len(chunk)
        return chunk

    def settimeout(self, t):
        pass


def m(h, x):
    return (h * 31 + x) & 0xFFFFFFFF


# The pre-order checksum in run.py.
def walk(v, h):
    if v is None:
        return m(h, 3)
    if isinstance(v, bool):
        return m(m(h, 8), int(v))
    if isinstance(v, int):
        return m(m(h, 2), v & 0xFFFFFFFF)
    if isinstance(v, bytes):
        h = m(m(h, 1), len(v))
        for b in v:
            h = m(h, b)
        return h
    if isinstance(v, list):
        h = m(h, 4)
        for x in v:
            h = walk(x, h)
        return m(h, 5)
    h = m(h, 6)
    for a, b in v.items():
        h = walk(b, walk(a, h))
    return m(h, 7)


data = open("out/replies.resp", "rb").read()

t0 = time.perf_counter()
parser = _RESP3Parser(65536)
parser._buffer = SocketBuffer(Sock(data), 65536, None)
replies = []
# The fake socket returns b"" at the end of the file, which redis-py reports as a closed connection.
try:
    while True:
        replies.append(parser.read_response(disable_decoding=True))
except ConnectionError:
    pass
t1 = time.perf_counter()

h = 0
for v in replies:
    h = walk(v, h)
h = (h + len(replies)) & 0xFFFFFFFF
print(f"decode\t{(t1 - t0) * 1000:.3f}\t{h}")
