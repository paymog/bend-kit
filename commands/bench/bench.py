"""commands benchmark in Python: N new commands, then the same N as duplicates, each in one BEGIN IMMEDIATE transaction, through sqlite3."""
import sqlite3, sys, time

path = sys.argv[1] if len(sys.argv) > 1 else "out/py.db"
n = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
db = sqlite3.connect(path, isolation_level=None)
print(f"sqlite\t{sqlite3.sqlite_version}")
db.execute("PRAGMA busy_timeout = 10000")
db.execute("CREATE TABLE IF NOT EXISTS commands_rows (k BLOB PRIMARY KEY, v BLOB NOT NULL) WITHOUT ROWID")
db.execute("CREATE TABLE IF NOT EXISTS commands_seen (id TEXT PRIMARY KEY, payload BLOB NOT NULL, kind INTEGER NOT NULL, result BLOB NOT NULL, at INTEGER NOT NULL)")
db.execute("CREATE INDEX IF NOT EXISTS commands_seen_at ON commands_seen (at)")
db.execute("CREATE TABLE IF NOT EXISTS commands_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL, effect BLOB NOT NULL)")


def handle(cmd, payload):
    """1 for a new command, 2 for a duplicate, 0 for a conflict, with the recorded or new total."""
    db.execute("BEGIN IMMEDIATE")
    row = db.execute("SELECT payload, kind, result, at FROM commands_seen WHERE id = ?", (cmd,)).fetchone()
    if row:
        db.execute("COMMIT")
        return (2 if row[0] == payload else 0), int(row[2])
    prev = db.execute("SELECT v FROM commands_rows WHERE k = ?", (b"total",)).fetchone()
    total = ((int(prev[0]) if prev else 0) + int(payload)) & 0xFFFFFFFF
    db.execute("INSERT OR REPLACE INTO commands_rows (k, v) VALUES (?, ?)", (b"total", str(total).encode()))
    db.execute("INSERT INTO commands_seen (id, payload, kind, result, at) VALUES (?, ?, ?, ?, ?)", (cmd, payload, 1, str(total).encode(), 200))
    db.execute("INSERT INTO commands_outbox (id, effect) VALUES (?, ?)", (cmd, f"total={total}".encode()))
    db.execute("COMMIT")
    return 1, total


def run(want):
    """Command i has id cmd_i and amount (x_i >> 1) % 1000. h = h*31 + result."""
    x, h = 1, 0
    for i in range(n):
        kind, r = handle(f"cmd_{i}", str((x >> 1) % 1000).encode())
        if kind != want:
            sys.exit("unexpected reply")
        h = (h * 31 + r) & 0xFFFFFFFF
        x = (x * 1664525 + 1013904223) & 0xFFFFFFFF
    return h


def range_handle(cmd, limit):
    db.execute("BEGIN IMMEDIATE")
    assert db.execute("SELECT payload, kind, result, at FROM commands_seen WHERE id = ?", (cmd,)).fetchone() is None
    rows = []
    cursor = db.execute("SELECT k, v FROM commands_rows WHERE k >= ? AND k < ? ORDER BY k", (b"pick_", b"pick`"))
    for row in cursor:
        if len(rows) == limit:
            cursor.close()
            db.execute("ROLLBACK")
            return 18
        rows.append(row)
    h = 0
    for k, v in rows:
        for b in k + b"=" + v + b";":
            h = (h * 31 + b) & 0xFFFFFFFF
    db.execute("INSERT INTO commands_seen (id, payload, kind, result, at) VALUES (?, ?, 1, ?, 200)", (cmd, str(limit).encode(), str(h).encode()))
    db.execute("COMMIT")
    return h


def ranges(count, label):
    for table in ("commands_rows", "commands_seen", "commands_outbox"):
        db.execute(f"DELETE FROM {table}")
    db.execute("INSERT INTO commands_rows WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i+1 FROM n WHERE i<7) SELECT CAST('pick_'||i AS BLOB), CAST(i+1 AS BLOB) FROM n")
    db.execute(f"INSERT INTO commands_rows WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i+1 FROM n WHERE i<{count-1}) SELECT CAST('z_'||i AS BLOB), CAST('100' AS BLOB) FROM n")
    for overflow in (False, True):
        h = 0
        t0 = time.perf_counter()
        for i in range(n):
            r = range_handle("overflow" if overflow else f"range_{i}", 7 if overflow else 8)
            assert not overflow or r == 18
            h = (h * 31 + r) & 0xFFFFFFFF
        elapsed = (time.perf_counter() - t0) * 1e3
        print(f"{'overflow' if overflow else 'range'}_{label}\t{elapsed:.3f}\t{h}")
    assert db.execute("SELECT count(*) FROM commands_seen").fetchone()[0] == n
    assert db.execute("SELECT count(*) FROM commands_outbox").fetchone()[0] == 0
    assert range_handle("overflow", 8) != 18


t0 = time.perf_counter()
run(1)
t1 = time.perf_counter()
print(f"fresh\t{(t1 - t0) * 1e3:.3f}\t{int(db.execute('SELECT v FROM commands_rows WHERE k = ?', (b'total',)).fetchone()[0])}")
t0 = time.perf_counter()
h = run(2)
t1 = time.perf_counter()
print(f"replay\t{(t1 - t0) * 1e3:.3f}\t{h}")
ranges(100, "small")
ranges(100000, "large")
db.close()
