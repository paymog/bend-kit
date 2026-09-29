"""Postgres result decode benchmark in Python with psycopg (see README.md).
psycopg parses only what libpq reads from a connection, so a thread replays the recording over a Unix socket."""
import os, socket, tempfile, threading, time
import psycopg

# AuthenticationOk, the ParameterStatus values libpq and psycopg read, BackendKeyData, ReadyForQuery.
def msg(tag, body):
    return tag + (len(body) + 4).to_bytes(4, "big") + body


HELLO = b"".join([
    msg(b"R", b"\0\0\0\0"),
    *(msg(b"S", k + b"\0" + v + b"\0") for k, v in [
        (b"client_encoding", b"UTF8"), (b"server_encoding", b"UTF8"), (b"server_version", b"18.0"),
        (b"standard_conforming_strings", b"on"), (b"integer_datetimes", b"on"), (b"DateStyle", b"ISO"),
    ]),
    msg(b"K", b"\0\0\0\x01\0\0\0\x02"),
    msg(b"Z", b"I"),
])


def read_n(c, n):
    b = b""
    while len(b) < n:
        k = c.recv(n - len(b))
        if not k:
            raise EOFError
        b += k
    return b


# Skips one message whose length word follows `skip` bytes (0 for the startup packet, 1 for a typed message).
def drop(c, skip):
    hd = read_n(c, skip + 4)
    read_n(c, int.from_bytes(hd[skip:], "big") - 4)


def replay(lsock, data):
    c, _ = lsock.accept()
    drop(c, 0)
    c.sendall(HELLO)
    drop(c, 1)  # the Query
    c.sendall(data)
    while c.recv(65536):  # until Terminate and close
        pass
    c.close()


def m(h, x):
    return (h * 31 + x) & 0xFFFFFFFF


def s(h, b):
    h = m(h, len(b))
    for x in b:
        h = m(h, x)
    return h


# psycopg loads int4/int8 as int, bool as bool, text as str; these give back the text-format bytes.
def text(v):
    if isinstance(v, bool):
        return b"t" if v else b"f"
    if isinstance(v, int):
        return str(v).encode()
    return v.encode()


data = open("out/result.pgwire", "rb").read()
d = tempfile.mkdtemp(prefix="pgbench.")
path = os.path.join(d, ".s.PGSQL.5432")
lsock = socket.socket(socket.AF_UNIX)
lsock.bind(path)
lsock.listen(1)
server = threading.Thread(target=replay, args=(lsock, data))
server.start()

# autocommit: otherwise psycopg sends a BEGIN first, which the replay would answer with the recording.
conn = psycopg.connect(host=d, port=5432, user="bench", dbname="bench", autocommit=True)
# ClientCursor sends a simple Query, as PQexec does in bench.c.
cur = psycopg.ClientCursor(conn)
t0 = time.perf_counter()
cur.execute("SELECT id, name, balance, note, active FROM accounts")
rows = cur.fetchall()
t1 = time.perf_counter()

# The checksum in run.py.
h = m(0, 1)
for col in cur.description:
    h = m(s(h, col.name.encode()), col.type_code)
h = m(h, 2)
for r in rows:
    h = m(h, 3)
    for v in r:
        h = m(h, 4) if v is None else s(m(h, 5), text(v))
    h = m(h, 6)
h = s(m(h, 7), cur.statusmessage.encode())
print(f"decode\t{(t1 - t0) * 1000:.3f}\t{h}")

conn.close()
server.join()
os.unlink(path)
os.rmdir(d)
