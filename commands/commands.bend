# Retry-safe commands: deduplicate by command id, replay recorded results, and commit keyed rows, record, and outbox in one SQLite transaction. Source: https://github.com/paymog/bend-kit/tree/main/commands
import Base
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import bend-kit-sqlite@0.1.0.1/sqlite.bend as Sqlite
import ./model.bend as M

# ---- IO that can fail with a SQLite error

def Run(-A: Type) -> Type:
  IO(Result<&1, &1, U32 & String, A>)

def Run.pure(-A: Type, x: A) -> Run(A):
  IO.pure(Result<&1, &1, U32 & String, A>, Done{x})

def Run.fail(-A: Type, e: U32 & String) -> Run(A):
  IO.pure(Result<&1, &1, U32 & String, A>, Fail{e})

def Run.next(-A: Type, -B: Type, r: Result<&1, &1, U32 & String, A>, f: A -> Run(B)) -> Run(B):
  match r:
    case Done{x}:
      f(x)
    case Fail{e}:
      Run.fail(B, e)

def Run.bind(-A: Type, -B: Type, m: Run(A), f: A -> Run(B)) -> Run(B):
  IO.bind(Result<&1, &1, U32 & String, A>, Result<&1, &1, U32 & String, B>, m, r => Run.next(A, B, r, f))

# r's value, unless r or then z failed.
def first(-A: Type, r: Result<&1, &1, U32 & String, A>, z: Result<&1, &1, U32 & String, Unit>) -> Result<&1, &1, U32 & String, A>:
  match r z:
    case Fail{e} _:
      Fail{e}
    case Done{x} Fail{e}:
      Fail{e}
    case Done{x} Done{u}:
      Done{x}

def unit(-A: Type, r: Result<&1, &1, U32 & String, A>) -> Result<&1, &1, U32 & String, Unit>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{x}:
      Done{Unit{}}

# ---- SQLite helpers

# Steps a statement and ignores any row, then resets it, also after a failed step.
def exec(+stmt: U32) -> Run(Unit):
  do IO<Result<&1, &1, U32 & String, Unit>>:
    r : Result<&1, &1, U32 & String, Bool> <- Sqlite.stmt.step(stmt)
    z : Result<&1, &1, U32 & String, Unit> <- Sqlite.stmt.reset(stmt)
    return first(Unit, unit(Bool, r), z)

def once.run(-A: Type, +s: U32, body: U32 -> Run(A)) -> Run(A):
  do IO<Result<&1, &1, U32 & String, A>>:
    r : Result<&1, &1, U32 & String, A> <- body(s)
    z : Result<&1, &1, U32 & String, Unit> <- Sqlite.stmt.finalize(s)
    return first(A, r, z)

# Prepares one statement, runs body on it, and finalizes it, also after body fails.
def once(-A: Type, +db: U32, text: String, body: U32 -> Run(A)) -> Run(A):
  do Run<A>:
    s : U32 <- Sqlite.stmt.prepare(db, text)
    once.run(A, s, body)

def sql(+db: U32, text: String) -> Run(Unit):
  once(Unit, db, text, +s => exec(s))

def blob.of(lw: U32 & Array<U32>) -> Bytes.Bytes:
  (n, w) = lw
  Bytes.Bytes{n, w}

def column.result(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{lw}:
      Done{blob.of(lw)}

def column(+s: U32, i: U32) -> Run(Bytes.Bytes):
  do IO<Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Sqlite.stmt.column.blob(s, i)
    return column.result(r)

def bind(+s: U32, i: U32, b: Bytes.Bytes) -> Run(Unit):
  Bytes.Bytes{n, w} = b
  Sqlite.stmt.bind.blob(s, i, n, w)

def same.of(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, ok) = r
  ok

# The payload comparison that handle gives step: every byte, NUL included.
def same(a: Bytes.Bytes, b: Bytes.Bytes) -> Bool:
  same.of(Bytes.eq(a, b))

# ---- the store

# A row of the store's key-value table. Read: Some is the value, None means no row. Written: Some puts the value, None deletes the row.
type Row is Type:
  Row{key: Bytes.Bytes, value: Maybe<Bytes.Bytes>}

type Read is Type:
  Keys{keys: List<Bytes.Bytes>}
  Range{lower: Bytes.Bytes, upper: Bytes.Bytes, max_rows: U32}

# A database and its prepared statements. One Store serves one task at a time.
type Store is Data:
  Store{db: U32, begin: U32, commit: U32, rollback: U32, find: U32, read: U32, range: U32, save: U32, del: U32, keep: U32, emit: U32}

# Opens or creates the tables at path.
# wait is how many ms a write waits for another connection's transaction before it fails with SQLITE_BUSY (5).
def open(path: String, wait: U32) -> Run(Store):
  do Run<Store>:
    +db : U32 <- Sqlite.db.open(path)
    sql(db, "PRAGMA busy_timeout = " ++ U32.show(wait))
    sql(db, "CREATE TABLE IF NOT EXISTS commands_rows (k BLOB PRIMARY KEY, v BLOB NOT NULL) WITHOUT ROWID")
    sql(db, "CREATE TABLE IF NOT EXISTS commands_seen (id TEXT PRIMARY KEY, payload BLOB NOT NULL, kind INTEGER NOT NULL, result BLOB NOT NULL, at INTEGER NOT NULL)")
    sql(db, "CREATE INDEX IF NOT EXISTS commands_seen_at ON commands_seen (at)")
    sql(db, "CREATE TABLE IF NOT EXISTS commands_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL, effect BLOB NOT NULL)")
    begin : U32 <- Sqlite.stmt.prepare(db, "BEGIN IMMEDIATE")
    commit : U32 <- Sqlite.stmt.prepare(db, "COMMIT")
    rollback : U32 <- Sqlite.stmt.prepare(db, "ROLLBACK")
    find : U32 <- Sqlite.stmt.prepare(db, "SELECT payload, kind, result, at FROM commands_seen WHERE id = ?")
    read : U32 <- Sqlite.stmt.prepare(db, "SELECT v FROM commands_rows WHERE k = ?")
    range : U32 <- Sqlite.stmt.prepare(db, "SELECT k, v FROM commands_rows WHERE k >= ? AND k < ? ORDER BY k")
    save : U32 <- Sqlite.stmt.prepare(db, "INSERT OR REPLACE INTO commands_rows (k, v) VALUES (?, ?)")
    del : U32 <- Sqlite.stmt.prepare(db, "DELETE FROM commands_rows WHERE k = ?")
    keep : U32 <- Sqlite.stmt.prepare(db, "INSERT INTO commands_seen (id, payload, kind, result, at) VALUES (?, ?, ?, ?, ?)")
    emit : U32 <- Sqlite.stmt.prepare(db, "INSERT INTO commands_outbox (id, effect) VALUES (?, ?)")
    return Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit}

def close(st: Store) -> Run(Unit):
  Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit} = st
  do Run<Unit>:
    Sqlite.stmt.finalize(begin)
    Sqlite.stmt.finalize(commit)
    Sqlite.stmt.finalize(rollback)
    Sqlite.stmt.finalize(find)
    Sqlite.stmt.finalize(read)
    Sqlite.stmt.finalize(range)
    Sqlite.stmt.finalize(save)
    Sqlite.stmt.finalize(del)
    Sqlite.stmt.finalize(keep)
    Sqlite.stmt.finalize(emit)
    Sqlite.db.close(db)

def outcome(accepted: Bool, r: Bytes.Bytes) -> M.Outcome<Bytes.Bytes>:
  match accepted:
    case True{}:
      M.Accepted{r}
    case False{}:
      M.Refused{r}

def seen.row(row: Bool, +find: U32) -> Run(Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>>):
  match row:
    case False{}:
      Run.pure(Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>>, None{})
    case True{}:
      do Run<Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>>>:
        p : Bytes.Bytes <- column(find, 0)
        kind : U32 <- Sqlite.stmt.column.int(find, 1)
        r : Bytes.Bytes <- column(find, 2)
        at : U32 <- Sqlite.stmt.column.int(find, 3)
        return Some{M.Record{p, outcome(U32.is_eq(kind, 1), r), at}}

# The record for id, if the store holds one.
def seen.get(+find: U32, id: String) -> Run(Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>>):
  do Run<Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>>>:
    Sqlite.stmt.bind.text(find, 1, id)
    row : Bool <- Sqlite.stmt.step(find)
    m : Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>> <- seen.row(row, find)
    Sqlite.stmt.reset(find)
    return m

def row.of(row: Bool, +read: U32) -> Run(Maybe<Bytes.Bytes>):
  match row:
    case False{}:
      Run.pure(Maybe<Bytes.Bytes>, None{})
    case True{}:
      do Run<Maybe<Bytes.Bytes>>:
        v : Bytes.Bytes <- column(read, 0)
        return Some{v}

# The value at key k, if a row holds it.
def row.get(+read: U32, k: Bytes.Bytes) -> Run(Maybe<Bytes.Bytes>):
  do Run<Maybe<Bytes.Bytes>>:
    bind(read, 1, k)
    row : Bool <- Sqlite.stmt.step(read)
    m : Maybe<Bytes.Bytes> <- row.of(row, read)
    Sqlite.stmt.reset(read)
    return m

def row.at(+read: U32, kk: Bytes.Bytes & Bytes.Bytes) -> Run(Row):
  (k, k2) = kk
  do Run<Row>:
    v : Maybe<Bytes.Bytes> <- row.get(read, k)
    return Row{k2, v}

# One row for each key, in order.
def rows.get(ks: List<Bytes.Bytes>, +read: U32) -> Run(List<Row>):
  match ks:
    case Nil{}:
      Run.pure(List<Row>, Nil{})
    case Con{k, rest}:
      do Run<List<Row>>:
        r : Row <- row.at(read, Bytes.clone(k))
        rs : List<Row> <- rows.get(rest, read)
        return Con{r, rs}

def range.rows(n: Nat, row: Bool, +s: U32) -> Run(List<Row>):
  match n row:
    case _ False{}:
      Run.pure(List<Row>, Nil{})
    case 0n True{}:
      Run.fail(List<Row>, (18, "command range exceeds max_rows"))
    case 1n+p True{}:
      do Run<List<Row>>:
        k : Bytes.Bytes <- column(s, 0)
        v : Bytes.Bytes <- column(s, 1)
        more : Bool <- Sqlite.stmt.step(s)
        rest : List<Row> <- range.rows(p, more, s)
        return Con{Row{k, Some{v}}, rest}

def range.run(+s: U32, lower: Bytes.Bytes, upper: Bytes.Bytes, n: U32) -> Run(List<Row>):
  do Run<List<Row>>:
    bind(s, 1, lower)
    bind(s, 2, upper)
    row : Bool <- Sqlite.stmt.step(s)
    range.rows(U32.to_nat(n), row, s)

def range.read(+s: U32, lower: Bytes.Bytes, upper: Bytes.Bytes, n: U32) -> Run(List<Row>):
  do IO<Result<&1, &1, U32 & String, List<Row>>>:
    r : Result<&1, &1, U32 & String, List<Row>> <- range.run(s, lower, upper, n)
    z : Result<&1, &1, U32 & String, Unit> <- Sqlite.stmt.reset(s)
    return first(List<Row>, r, z)

def rows.read(r: Read, range: U32, read: U32) -> Run(List<Row>):
  match r:
    case Keys{ks}:
      rows.get(ks, read)
    case Range{lo, hi, n}:
      range.read(range, lo, hi, n)

def seen.put.row(+keep: U32, id: String, p: Bytes.Bytes, kind: U32, r: Bytes.Bytes, at: U32) -> Run(Unit):
  do Run<Unit>:
    Sqlite.stmt.bind.text(keep, 1, id)
    bind(keep, 2, p)
    Sqlite.stmt.bind.int(keep, 3, kind)
    bind(keep, 4, r)
    Sqlite.stmt.bind.int(keep, 5, at)
    exec(keep)

def seen.put.of(o: M.Outcome<Bytes.Bytes>, +keep: U32, id: String, p: Bytes.Bytes, at: U32) -> Run(Unit):
  match o:
    case M.Accepted{r}:
      seen.put.row(keep, id, p, 1, r, at)
    case M.Refused{r}:
      seen.put.row(keep, id, p, 2, r, at)

def seen.put(rec: M.Record<Bytes.Bytes, Bytes.Bytes>, +keep: U32, id: String) -> Run(Unit):
  M.Record{p, o, at} = rec
  seen.put.of(o, keep, id, p, at)

def outbox.put(es: List<Bytes.Bytes>, +emit: U32, +id: String) -> Run(Unit):
  match es:
    case Nil{}:
      Run.pure(Unit, Unit{})
    case Con{e, rest}:
      do Run<Unit>:
        Sqlite.stmt.bind.text(emit, 1, id)
        bind(emit, 2, e)
        exec(emit)
        outbox.put(rest, emit, id)

def row.put(v: Maybe<Bytes.Bytes>, +save: U32, +del: U32, k: Bytes.Bytes) -> Run(Unit):
  match v:
    case Some{x}:
      do Run<Unit>:
        bind(save, 1, k)
        bind(save, 2, x)
        exec(save)
    case None{}:
      do Run<Unit>:
        bind(del, 1, k)
        exec(del)

# Writes the rows in order, so a later row for a key wins.
def rows.put(rs: List<Row>, +save: U32, +del: U32) -> Run(Unit):
  match rs:
    case Nil{}:
      Run.pure(Unit, Unit{})
    case Con{Row{k, v}, rest}:
      do Run<Unit>:
        row.put(v, save, del, k)
        rows.put(rest, save, del)

# Applies a step inside the open transaction, then commits it.
def written(
  w: M.Step<List<Row>, Bytes.Bytes, Bytes.Bytes, Bytes.Bytes>, +commit: U32, +save: U32, +del: U32, +keep: U32, +emit: U32, +id: String
) -> Run(M.Reply<Bytes.Bytes>):
  match w:
    case M.Write{rs, rec, reply, es}:
      do Run<M.Reply<Bytes.Bytes>>:
        rows.put(rs, save, del)
        seen.put(rec, keep, id)
        outbox.put(es, emit, id)
        exec(commit)
        return reply
    case M.Note{rec, reply}:
      do Run<M.Reply<Bytes.Bytes>>:
        seen.put(rec, keep, id)
        exec(commit)
        return reply
    case M.Keep{reply}:
      do Run<M.Reply<Bytes.Bytes>>:
        exec(commit)
        return reply

def handle.new(
  ~keys: Bytes.Bytes -> Read,
  ~decide: List<Row> -> Bytes.Bytes -> M.Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  pp: Bytes.Bytes & Bytes.Bytes, range: U32, +read: U32, at: U32, +commit: U32, +save: U32, +del: U32, +keep: U32, +emit: U32, +id: String
) -> Run(M.Reply<Bytes.Bytes>):
  (p, p2) = pp
  do Run<M.Reply<Bytes.Bytes>>:
    rs : List<Row> <- rows.read(keys(p), range, read)
    written(M.step(~List<Row>, ~Bytes.Bytes, ~Bytes.Bytes, ~Bytes.Bytes, ~same, ~Bytes.clone, ~Bytes.clone, ~decide, None{}, rs, p2, at), commit, save, del, keep, emit, id)

# A duplicate reads no rows: step ignores them when found is Some.
def handle.found(
  ~keys: Bytes.Bytes -> Read,
  ~decide: List<Row> -> Bytes.Bytes -> M.Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  found: Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>>, range: U32, +read: U32, payload: Bytes.Bytes, at: U32,
  +commit: U32, +save: U32, +del: U32, +keep: U32, +emit: U32, +id: String
) -> Run(M.Reply<Bytes.Bytes>):
  match found:
    case None{}:
      handle.new(~keys, ~decide, Bytes.clone(payload), range, read, at, commit, save, del, keep, emit, id)
    case Some{rec}:
      written(M.step(~List<Row>, ~Bytes.Bytes, ~Bytes.Bytes, ~Bytes.Bytes, ~same, ~Bytes.clone, ~Bytes.clone, ~decide, Some{rec}, Nil{}, payload, at), commit, save, del, keep, emit, id)

def handle.txn(
  ~keys: Bytes.Bytes -> Read,
  ~decide: List<Row> -> Bytes.Bytes -> M.Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  st: Store, +id: String, payload: Bytes.Bytes, at: U32
) -> Run(M.Reply<Bytes.Bytes>):
  Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit} = st
  do Run<M.Reply<Bytes.Bytes>>:
    exec(begin)
    found : Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>> <- seen.get(find, id)
    handle.found(~keys, ~decide, found, range, read, payload, at, commit, save, del, keep, emit, id)

# On failure, resets the read statements and rolls back. Rollback errors are ignored: the transaction may not have started.
def handle.end(r: Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>>, st: Store) -> Run(M.Reply<Bytes.Bytes>):
  match r:
    case Done{x}:
      Run.pure(M.Reply<Bytes.Bytes>, x)
    case Fail{e}:
      Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit} = st
      do IO<Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>>>:
        a : Result<&1, &1, U32 & String, Unit> <- Sqlite.stmt.reset(find)
        b : Result<&1, &1, U32 & String, Unit> <- Sqlite.stmt.reset(read)
        c : Result<&1, &1, U32 & String, Unit> <- exec(rollback)
        return Fail{e}

# Runs one command in one transaction: find its record, read the rows that keys names, decide, and commit rows, record, and effects.
# at is the record's time for prune, in seconds. decide sees the selected rows and the payload.
def handle(
  ~keys: Bytes.Bytes -> Read,
  ~decide: List<Row> -> Bytes.Bytes -> M.Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  +st: Store, id: String, payload: Bytes.Bytes, at: U32
) -> Run(M.Reply<Bytes.Bytes>):
  do IO<Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>>>:
    r : Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>> <- handle.txn(~keys, ~decide, st, id, payload, at)
    handle.end(r, st)

# The committed value at key k.
def get(st: Store, k: Bytes.Bytes) -> Run(Maybe<Bytes.Bytes>):
  Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit} = st
  row.get(read, k)

def prune.run(+s: U32, before: U32) -> Run(Unit):
  do Run<Unit>:
    Sqlite.stmt.bind.int(s, 1, before)
    exec(s)

# Forgets every record made before the time before. A later retry of a forgotten id runs as a new command.
def prune(st: Store, before: U32) -> Run(Unit):
  Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit} = st
  once(Unit, db, "DELETE FROM commands_seen WHERE at < ?", +s => prune.run(s, before))

# An undelivered effect: its sequence number, its command id, and the effect.
type Pending is Type:
  Pending{seq: U32, id: String, effect: Bytes.Bytes}

def outbox.row(row: Bool, +s: U32) -> Run(Maybe<Pending>):
  match row:
    case False{}:
      Run.pure(Maybe<Pending>, None{})
    case True{}:
      do Run<Maybe<Pending>>:
        seq : U32 <- Sqlite.stmt.column.int(s, 0)
        id : String <- Sqlite.stmt.column.text(s, 1)
        e : Bytes.Bytes <- column(s, 2)
        return Some{Pending{seq, id, e}}

def outbox.first(+s: U32) -> Run(Maybe<Pending>):
  do Run<Maybe<Pending>>:
    row : Bool <- Sqlite.stmt.step(s)
    outbox.row(row, s)

# The oldest undelivered effect.
def outbox.next(st: Store) -> Run(Maybe<Pending>):
  Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit} = st
  once(Maybe<Pending>, db, "SELECT seq, id, effect FROM commands_outbox ORDER BY seq LIMIT 1", +s => outbox.first(s))

def outbox.ack.run(+s: U32, seq: U32) -> Run(Unit):
  do Run<Unit>:
    Sqlite.stmt.bind.int(s, 1, seq)
    exec(s)

# Removes a delivered effect. Deliver before ack: a crash between them delivers the effect again.
def outbox.ack(st: Store, seq: U32) -> Run(Unit):
  Store{db, begin, commit, rollback, find, read, range, save, del, keep, emit} = st
  once(Unit, db, "DELETE FROM commands_outbox WHERE seq = ?", +s => outbox.ack.run(s, seq))
