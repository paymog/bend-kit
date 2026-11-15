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


t0 = time.perf_counter()
run(1)
t1 = time.perf_counter()
print(f"fresh\t{(t1 - t0) * 1e3:.3f}\t{int(db.execute('SELECT v FROM commands_rows WHERE k = ?', (b'total',)).fetchone()[0])}")
t0 = time.perf_counter()
h = run(2)
t1 = time.perf_counter()
print(f"replay\t{(t1 - t0) * 1e3:.3f}\t{h}")
db.close()
