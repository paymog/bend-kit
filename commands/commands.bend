# Retry-safe commands: deduplicate by command id, replay recorded results, and commit keyed rows, record, and outbox in one SQLite transaction. Source: https://github.com/paymog/bend-kit/tree/main/commands
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-sqlite@0.1.0.1/sqlite.bend as Sqlite

# ---- the pure processor

type Outcome<-R: Type> is Type:
  Accepted{result: R}
  Refused{result: R}

# What the store keeps for one command id: its payload, its outcome, and when it was recorded.
type Record<-P: Type, -R: Type> is Type:
  Record{payload: P, outcome: Outcome<R>, at: U32}

type Reply<-R: Type> is Type:
  Fresh{outcome: Outcome<R>}
  Replayed{outcome: Outcome<R>}
  Conflict{}

# The domain's answer to a new command.
type Decision<-S: Type, -R: Type, -E: Type> is Type:
  Accept{state: S, result: R, effects: List<E>}
  Refuse{result: R}

# Write: commit the state, the record, and the effects together. Note: commit only the record. Keep: write nothing.
type Step<-S: Type, -P: Type, -R: Type, -E: Type> is Type:
  Write{state: S, record: Record<P, R>, reply: Reply<R>, effects: List<E>}
  Note{record: Record<P, R>, reply: Reply<R>}
  Keep{reply: Reply<R>}

def accepted(-S: Type, -P: Type, -R: Type, -E: Type, rr: R & R, s2: S, p: P, at: U32, es: List<E>) -> Step<S, P, R, E>:
  (r, r2) = rr
  Write{s2, Record{p, Accepted{r}, at}, Fresh{Accepted{r2}}, es}

def refused(-S: Type, -P: Type, -R: Type, -E: Type, rr: R & R, p: P, at: U32) -> Step<S, P, R, E>:
  (r, r2) = rr
  Note{Record{p, Refused{r}, at}, Fresh{Refused{r2}}}

def decided(~S: Type, ~P: Type, ~R: Type, ~E: Type, ~dup_r: R -> R & R, d: Decision<S, R, E>, p: P, at: U32) -> Step<S, P, R, E>:
  match d:
    case Accept{s2, r, es}:
      accepted(S, P, R, E, dup_r(r), s2, p, at, es)
    case Refuse{r}:
      refused(S, P, R, E, dup_r(r), p, at)

def fresh(
  ~S: Type, ~P: Type, ~R: Type, ~E: Type, ~dup_r: R -> R & R, ~decide: S -> P -> Decision<S, R, E>,
  pp: P & P, s: S, at: U32
) -> Step<S, P, R, E>:
  (p, p2) = pp
  decided(~S, ~P, ~R, ~E, ~dup_r, decide(s, p), p2, at)

def replayed(-R: Type, same: Bool, o: Outcome<R>) -> Reply<R>:
  match same:
    case True{}:
      Replayed{o}
    case False{}:
      Conflict{}

# One command, given the record that the store holds for its id and the domain state s.
# dup_p and dup_r copy a payload and a result: a new command's payload goes to decide and to the record.
def step(
  ~S: Type, ~P: Type, ~R: Type, ~E: Type, ~eq: P -> P -> Bool, ~dup_p: P -> P & P, ~dup_r: R -> R & R,
  ~decide: S -> P -> Decision<S, R, E>, found: Maybe<Record<P, R>>, s: S, p: P, at: U32
) -> Step<S, P, R, E>:
  match found:
    case None{}:
      fresh(~S, ~P, ~R, ~E, ~dup_r, ~decide, dup_p(p), s, at)
    case Some{Record{q, o, t}}:
      Keep{replayed(R, eq(q, p), o)}

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

def column(+s: U32, i: U32) -> Run(Bytes.Bytes):
  do Run<Bytes.Bytes>:
    lw : U32 & Array<U32> <- Sqlite.stmt.column.blob(s, i)
    return blob.of(lw)

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

# A database and its prepared statements. One Store serves one task at a time.
type Store is Data:
  Store{db: U32, begin: U32, commit: U32, rollback: U32, find: U32, read: U32, save: U32, del: U32, keep: U32, emit: U32}

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
    save : U32 <- Sqlite.stmt.prepare(db, "INSERT OR REPLACE INTO commands_rows (k, v) VALUES (?, ?)")
    del : U32 <- Sqlite.stmt.prepare(db, "DELETE FROM commands_rows WHERE k = ?")
    keep : U32 <- Sqlite.stmt.prepare(db, "INSERT INTO commands_seen (id, payload, kind, result, at) VALUES (?, ?, ?, ?, ?)")
    emit : U32 <- Sqlite.stmt.prepare(db, "INSERT INTO commands_outbox (id, effect) VALUES (?, ?)")
    return Store{db, begin, commit, rollback, find, read, save, del, keep, emit}

def close(st: Store) -> Run(Unit):
  Store{db, begin, commit, rollback, find, read, save, del, keep, emit} = st
  do Run<Unit>:
    Sqlite.stmt.finalize(begin)
    Sqlite.stmt.finalize(commit)
    Sqlite.stmt.finalize(rollback)
    Sqlite.stmt.finalize(find)
    Sqlite.stmt.finalize(read)
    Sqlite.stmt.finalize(save)
    Sqlite.stmt.finalize(del)
    Sqlite.stmt.finalize(keep)
    Sqlite.stmt.finalize(emit)
    Sqlite.db.close(db)

def outcome(accepted: Bool, r: Bytes.Bytes) -> Outcome<Bytes.Bytes>:
  match accepted:
    case True{}:
      Accepted{r}
    case False{}:
      Refused{r}

def seen.row(row: Bool, +find: U32) -> Run(Maybe<Record<Bytes.Bytes, Bytes.Bytes>>):
  match row:
    case False{}:
      Run.pure(Maybe<Record<Bytes.Bytes, Bytes.Bytes>>, None{})
    case True{}:
      do Run<Maybe<Record<Bytes.Bytes, Bytes.Bytes>>>:
        p : Bytes.Bytes <- column(find, 0)
        kind : U32 <- Sqlite.stmt.column.int(find, 1)
        r : Bytes.Bytes <- column(find, 2)
        at : U32 <- Sqlite.stmt.column.int(find, 3)
        return Some{Record{p, outcome(U32.is_eq(kind, 1), r), at}}

# The record for id, if the store holds one.
def seen.get(+find: U32, id: String) -> Run(Maybe<Record<Bytes.Bytes, Bytes.Bytes>>):
  do Run<Maybe<Record<Bytes.Bytes, Bytes.Bytes>>>:
    Sqlite.stmt.bind.text(find, 1, id)
    row : Bool <- Sqlite.stmt.step(find)
    m : Maybe<Record<Bytes.Bytes, Bytes.Bytes>> <- seen.row(row, find)
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

def seen.put.row(+keep: U32, id: String, p: Bytes.Bytes, kind: U32, r: Bytes.Bytes, at: U32) -> Run(Unit):
  do Run<Unit>:
    Sqlite.stmt.bind.text(keep, 1, id)
    bind(keep, 2, p)
    Sqlite.stmt.bind.int(keep, 3, kind)
    bind(keep, 4, r)
    Sqlite.stmt.bind.int(keep, 5, at)
    exec(keep)

def seen.put.of(o: Outcome<Bytes.Bytes>, +keep: U32, id: String, p: Bytes.Bytes, at: U32) -> Run(Unit):
  match o:
    case Accepted{r}:
      seen.put.row(keep, id, p, 1, r, at)
    case Refused{r}:
      seen.put.row(keep, id, p, 2, r, at)

def seen.put(rec: Record<Bytes.Bytes, Bytes.Bytes>, +keep: U32, id: String) -> Run(Unit):
  Record{p, o, at} = rec
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
  w: Step<List<Row>, Bytes.Bytes, Bytes.Bytes, Bytes.Bytes>, +commit: U32, +save: U32, +del: U32, +keep: U32, +emit: U32, +id: String
) -> Run(Reply<Bytes.Bytes>):
  match w:
    case Write{rs, rec, reply, es}:
      do Run<Reply<Bytes.Bytes>>:
        rows.put(rs, save, del)
        seen.put(rec, keep, id)
        outbox.put(es, emit, id)
        exec(commit)
        return reply
    case Note{rec, reply}:
      do Run<Reply<Bytes.Bytes>>:
        seen.put(rec, keep, id)
        exec(commit)
        return reply
    case Keep{reply}:
      do Run<Reply<Bytes.Bytes>>:
        exec(commit)
        return reply

def handle.new(
  ~keys: Bytes.Bytes -> List<Bytes.Bytes>,
  ~decide: List<Row> -> Bytes.Bytes -> Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  pp: Bytes.Bytes & Bytes.Bytes, +read: U32, at: U32, +commit: U32, +save: U32, +del: U32, +keep: U32, +emit: U32, +id: String
) -> Run(Reply<Bytes.Bytes>):
  (p, p2) = pp
  do Run<Reply<Bytes.Bytes>>:
    rs : List<Row> <- rows.get(keys(p), read)
    written(step(~List<Row>, ~Bytes.Bytes, ~Bytes.Bytes, ~Bytes.Bytes, ~same, ~Bytes.clone, ~Bytes.clone, ~decide, None{}, rs, p2, at), commit, save, del, keep, emit, id)

# A duplicate reads no rows: step ignores them when found is Some.
def handle.found(
  ~keys: Bytes.Bytes -> List<Bytes.Bytes>,
  ~decide: List<Row> -> Bytes.Bytes -> Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  found: Maybe<Record<Bytes.Bytes, Bytes.Bytes>>, +read: U32, payload: Bytes.Bytes, at: U32,
  +commit: U32, +save: U32, +del: U32, +keep: U32, +emit: U32, +id: String
) -> Run(Reply<Bytes.Bytes>):
  match found:
    case None{}:
      handle.new(~keys, ~decide, Bytes.clone(payload), read, at, commit, save, del, keep, emit, id)
    case Some{rec}:
      written(step(~List<Row>, ~Bytes.Bytes, ~Bytes.Bytes, ~Bytes.Bytes, ~same, ~Bytes.clone, ~Bytes.clone, ~decide, Some{rec}, Nil{}, payload, at), commit, save, del, keep, emit, id)

def handle.txn(
  ~keys: Bytes.Bytes -> List<Bytes.Bytes>,
  ~decide: List<Row> -> Bytes.Bytes -> Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  st: Store, +id: String, payload: Bytes.Bytes, at: U32
) -> Run(Reply<Bytes.Bytes>):
  Store{db, begin, commit, rollback, find, read, save, del, keep, emit} = st
  do Run<Reply<Bytes.Bytes>>:
    exec(begin)
    found : Maybe<Record<Bytes.Bytes, Bytes.Bytes>> <- seen.get(find, id)
    handle.found(~keys, ~decide, found, read, payload, at, commit, save, del, keep, emit, id)

# On failure, resets the read statements and rolls back. Rollback errors are ignored: the transaction may not have started.
def handle.end(r: Result<&1, &1, U32 & String, Reply<Bytes.Bytes>>, st: Store) -> Run(Reply<Bytes.Bytes>):
  match r:
    case Done{x}:
      Run.pure(Reply<Bytes.Bytes>, x)
    case Fail{e}:
      Store{db, begin, commit, rollback, find, read, save, del, keep, emit} = st
      do IO<Result<&1, &1, U32 & String, Reply<Bytes.Bytes>>>:
        a : Result<&1, &1, U32 & String, Unit> <- Sqlite.stmt.reset(find)
        b : Result<&1, &1, U32 & String, Unit> <- Sqlite.stmt.reset(read)
        c : Result<&1, &1, U32 & String, Unit> <- exec(rollback)
        return Fail{e}

# Runs one command in one transaction: find its record, read the rows that keys names, decide, and commit rows, record, and effects.
# at is the record's time for prune, in seconds. decide sees the committed rows, one for each key in order, and the payload.
def handle(
  ~keys: Bytes.Bytes -> List<Bytes.Bytes>,
  ~decide: List<Row> -> Bytes.Bytes -> Decision<List<Row>, Bytes.Bytes, Bytes.Bytes>,
  +st: Store, id: String, payload: Bytes.Bytes, at: U32
) -> Run(Reply<Bytes.Bytes>):
  do IO<Result<&1, &1, U32 & String, Reply<Bytes.Bytes>>>:
    r : Result<&1, &1, U32 & String, Reply<Bytes.Bytes>> <- handle.txn(~keys, ~decide, st, id, payload, at)
    handle.end(r, st)

# The committed value at key k.
def get(st: Store, k: Bytes.Bytes) -> Run(Maybe<Bytes.Bytes>):
  Store{db, begin, commit, rollback, find, read, save, del, keep, emit} = st
  row.get(read, k)

def prune.run(+s: U32, before: U32) -> Run(Unit):
  do Run<Unit>:
    Sqlite.stmt.bind.int(s, 1, before)
    exec(s)

# Forgets every record made before the time before. A later retry of a forgotten id runs as a new command.
def prune(st: Store, before: U32) -> Run(Unit):
  Store{db, begin, commit, rollback, find, read, save, del, keep, emit} = st
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
  Store{db, begin, commit, rollback, find, read, save, del, keep, emit} = st
  once(Maybe<Pending>, db, "SELECT seq, id, effect FROM commands_outbox ORDER BY seq LIMIT 1", +s => outbox.first(s))

def outbox.ack.run(+s: U32, seq: U32) -> Run(Unit):
  do Run<Unit>:
    Sqlite.stmt.bind.int(s, 1, seq)
    exec(s)

# Removes a delivered effect. Deliver before ack: a crash between them delivers the effect again.
def outbox.ack(st: Store, seq: U32) -> Run(Unit):
  Store{db, begin, commit, rollback, find, read, save, del, keep, emit} = st
  once(Unit, db, "DELETE FROM commands_outbox WHERE seq = ?", +s => outbox.ack.run(s, seq))
