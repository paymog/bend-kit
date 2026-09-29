"""SQLite benchmark in Python: N prepared inserts in one transaction, then N primary-key reads, through sqlite3."""
import sqlite3, sys, time

n = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
db = sqlite3.connect(":memory:", isolation_level=None)
print(f"sqlite\t{sqlite3.sqlite_version}")
db.execute("CREATE TABLE t(k INTEGER PRIMARY KEY, v INTEGER NOT NULL)")

x = 1
t0 = time.perf_counter()
db.execute("BEGIN")
for i in range(n):
    db.execute("INSERT INTO t VALUES (?1, ?2)", (i, x >> 1))
    x = (x * 1664525 + 1013904223) & 0xFFFFFFFF
db.execute("COMMIT")
t1 = time.perf_counter()
print(f"insert\t{(t1 - t0) * 1e3:.3f}\t{db.execute('SELECT count(*) FROM t').fetchone()[0]}")

h, k = 0, 0
t0 = time.perf_counter()
for _ in range(n):
    h = (h * 31 + db.execute("SELECT v FROM t WHERE k = ?1", (k % n,)).fetchone()[0]) & 0xFFFFFFFF
    k += 7919
t1 = time.perf_counter()
print(f"select\t{(t1 - t0) * 1e3:.3f}\t{h}")
db.close()
