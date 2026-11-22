import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import ./commands.bend as C
import ./model.bend as M
import ./ledger.bend as L

def ok(c: Bool, msg: String) -> IO(Unit):
  match c:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, msg)

def same(+got: String, +want: String, msg: String) -> IO(Unit):
  ok(String.eq(got, want), msg ++ ": got " ++ got ++ ", want " ++ want)

def handled(+st: C.Store, id: String, p: String, at: U32, +want: String, msg: String) -> IO(Unit):
  do IO<Unit>:
    r : M.Reply<Bytes.Bytes> <- IO.try(M.Reply<Bytes.Bytes>, C.handle(~L.keys, ~L.decide, st, id, Bytes.from_string(p), at))
    same(L.reply.show(r), want, msg)

def shown(m: Maybe<Bytes.Bytes>) -> String:
  match m:
    case Some{v}:
      Bytes.to_string(v)
    case None{}:
      "none"

# The committed value at key k, or "none".
def holds(+st: C.Store, k: String, +want: String, msg: String) -> IO(Unit):
  do IO<Unit>:
    v : Maybe<Bytes.Bytes> <- IO.try(Maybe<Bytes.Bytes>, C.get(st, Bytes.from_string(k)))
    same(shown(v), want, msg)

def status(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> U32:
  match r:
    case Done{(s, out)}:
      s
    case Fail{e}:
      255

def taken(+st: C.Store, m: Maybe<C.Pending>) -> IO(String):
  match m:
    case None{}:
      IO.pure(String, "")
    case Some{C.Pending{+seq, id, e}}:
      do IO<String>:
        IO.try(Unit, C.outbox.ack(st, seq))
        return id ++ ":" ++ Bytes.to_string(e) ++ " "

# Delivers and acks up to n effects, oldest first. Answers how many, and their ids and effects.
def drain(n: Nat, +st: C.Store, +k: U32, log: String) -> IO(U32 & String):
  match n:
    case 0n:
      IO.pure(U32 & String, (k, log))
    case 1n+m:
      do IO<U32 & String>:
        p : Maybe<C.Pending> <- IO.try(Maybe<C.Pending>, C.outbox.next(st))
        +t : String <- taken(st, p)
        drain(m, st, (k + Bool.pick(U32, String.eq(t, ""), 0, 1) : U32), log ++ t)

def credit(a: String, n: String) -> String:
  "{\"account\":\"" ++ a ++ "\",\"credit\":" ++ n ++ "}"

def debit(a: String, n: String) -> String:
  "{\"account\":\"" ++ a ++ "\",\"debit\":" ++ n ++ "}"

def nul() -> String:
  SCon{Chr{0}, SNil{}}

def path() -> String:
  "commands-check.db"

def rm() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("rm", ["-f", path(), path() ++ "-journal"], "", 4096, 10000)
    ok(U32.is_eq(status(r), 0), "rm the check database")

def duplicates() -> IO(Unit):
  do IO<Unit>:
    +st : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    handled(st, "evt_1", credit("a", "500"), 100, "fresh accepted 500", "a new event applies")
    handled(st, "evt_1", credit("a", "500"), 200, "replayed accepted 500", "a duplicate replays the recorded result")
    handled(st, "evt_1", credit("a", "900"), 200, "conflict", "an id reused with another payload is rejected")
    holds(st, "a", "500", "a duplicate and a conflict keep the state")
    handled(st, "evt_2", debit("a", "800"), 200, "fresh refused insufficient funds", "an overdraft is refused")
    handled(st, "evt_2", debit("a", "800"), 200, "replayed refused insufficient funds", "a refusal replays")
    handled(st, "evt_3", debit("a", "200"), 200, "fresh accepted 300", "a debit applies")
    handled(st, "evt_bad", "{\"account\":\"a\"}", 200, "fresh refused invalid payload", "a payload without an amount is refused")
    handled(st, "evt_dup", "{\"account\":\"a\",\"credit\":1,\"credit\":2}", 200, "fresh refused invalid payload", "a payload with a repeated key is refused")
    handled(st, "evt_nul", "{}" ++ nul() ++ "a", 200, "fresh refused invalid payload", "a payload with a NUL byte is recorded")
    handled(st, "evt_nul", "{}" ++ nul() ++ "a", 200, "replayed refused invalid payload", "a payload with a NUL byte deduplicates")
    handled(st, "evt_nul", "{}" ++ nul() ++ "b", 200, "conflict", "the bytes after a NUL byte count")
    holds(st, "a", "300", "refusals keep the state")
    holds(st, "b", "none", "an account no command touched has no row")
    IO.try(Unit, C.close(st))

def restart() -> IO(Unit):
  do IO<Unit>:
    +st : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    holds(st, "a", "300", "reopening keeps the committed rows")
    handled(st, "evt_1", credit("a", "500"), 300, "replayed accepted 500", "a retry after a restart replays")
    IO.try(Unit, C.close(st))

def crash() -> IO(Unit):
  do IO<Unit>:
    c : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("bend", ["child.bend", "crash", path()], "", 65536, 120000)
    ok(U32.is_eq(status(c), 9), "the child dies before COMMIT")
    +st : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    holds(st, "a", "300", "the uncommitted row is rolled back")
    handled(st, "evt_4", credit("a", "1"), 200, "fresh accepted 301", "the uncommitted record is rolled back")
    IO.try(Unit, C.close(st))

def busy(r: Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>>) -> IO(Unit):
  match r:
    case Fail{(+code, m)}:
      ok(U32.is_eq(code, 5), "the second writer waits, then fails with SQLITE_BUSY: " ++ U32.show(code) ++ " " ++ m)
    case Done{x}:
      IO.die(Unit, 1, "the second writer ran inside the first writer's transaction")

# Writer a is inside its transaction for evt_5 and has found no record. Writer b delivers evt_5 too.
def inflight.go(a: C.Store, +b: C.Store) -> IO(Unit):
  C.Store{db, +begin, +commit, rollback, +find, +read, +save, +del, +keep, +emit} = a
  do IO<Unit>:
    IO.try(Unit, C.exec(begin))
    found : Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>> <- IO.try(Maybe<M.Record<Bytes.Bytes, Bytes.Bytes>>, C.seen.get(find, "evt_5"))
    ok(Maybe.is_none(&1, M.Record<Bytes.Bytes, Bytes.Bytes>, found), "evt_5 is new")
    r : Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>> <- C.handle(~L.keys, ~L.decide, b, "evt_5", Bytes.from_string(credit("a", "7")), 200)
    busy(r)
    rs : List<C.Row> <- IO.try(List<C.Row>, C.rows.get([Bytes.from_string("a")], read))
    step : M.Step<List<C.Row>, Bytes.Bytes, Bytes.Bytes, Bytes.Bytes> = M.step(~List<C.Row>, ~Bytes.Bytes, ~Bytes.Bytes, ~Bytes.Bytes, ~C.same, ~Bytes.clone, ~Bytes.clone, ~L.decide, None{}, rs, Bytes.from_string(credit("a", "7")), 200)
    w : M.Reply<Bytes.Bytes> <- IO.try(M.Reply<Bytes.Bytes>, C.written(step, commit, save, del, keep, emit, "evt_5"))
    same(L.reply.show(w), "fresh accepted 308", "the first writer commits")
    handled(b, "evt_5", credit("a", "7"), 200, "replayed accepted 308", "the second writer's retry replays")

def inflight() -> IO(Unit):
  do IO<Unit>:
    +a : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    +b : C.Store <- IO.try(C.Store, C.open(path(), 100))
    inflight.go(a, b)
    IO.try(Unit, C.close(a))
    IO.try(Unit, C.close(b))

def race.cmd() -> String:
  "bend child.bend race " ++ path() ++ " & a=$!; bend child.bend race " ++ path() ++ "; b=$?; wait $a; exit $(($? | b))"

def race.ran(c: Result<&1, &1, U32 & String, U32 & (String & String)>) -> IO(Unit):
  match c:
    case Done{(+code, (+o, e))}:
      do IO<Unit>:
        IO.print("race: " ++ o)
        ok(U32.is_eq(code, 0), "both racers finish: " ++ o ++ e)
    case Fail{(code, m)}:
      IO.die(Unit, 1, "the racers did not start: " ++ m)

def drained(+st: C.Store, r: U32 & String) -> IO(Unit):
  (+k, +log) = r
  do IO<Unit>:
    ok(U32.is_eq(k, 404), "the outbox holds one effect per applied command: " ++ U32.show(k))
    ok(String.starts_with(log, "evt_1:a=500 evt_3:a=300 evt_4:a=301 evt_5:a=308 "), "the outbox keeps commit order: " ++ log)
    p : Maybe<C.Pending> <- IO.try(Maybe<C.Pending>, C.outbox.next(st))
    ok(Maybe.is_none(&1, C.Pending, p), "ack removes delivered effects")
    IO.try(Unit, C.close(st))

def race() -> IO(Unit):
  do IO<Unit>:
    c : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("/bin/sh", ["-c", race.cmd()], "", 65536, 240000)
    race.ran(c)
    +st : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    holds(st, "a", "308", "the ledger keeps its balance")
    holds(st, "race", "400", "400 ids sent twice by two processes apply once each")
    r : U32 & String <- drain(500n, st, 0, "")
    drained(st, r)

def retention() -> IO(Unit):
  do IO<Unit>:
    +st : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    IO.try(Unit, C.prune(st, 150))
    handled(st, "evt_1", credit("a", "500"), 400, "fresh accepted 808", "a pruned id runs as a new command")
    handled(st, "evt_3", debit("a", "200"), 400, "replayed accepted 300", "a record inside the window still replays")
    IO.try(Unit, C.close(st))

# Adds 100,000 rows of 100 each, keyed acct_0 to acct_99999.
def seed(st: C.Store) -> IO(Unit):
  C.Store{+db, begin, commit, rollback, find, read, save, del, keep, emit} = st
  IO.try(Unit, C.sql(db, "INSERT INTO commands_rows (k, v) WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < 99999) SELECT CAST('acct_' || i AS BLOB), CAST('100' AS BLOB) FROM n"))

# A credit reads and writes only its account's row, among 100,000.
def many() -> IO(Unit):
  do IO<Unit>:
    +st : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    seed(st)
    handled(st, "evt_many", credit("acct_77777", "5"), 400, "fresh accepted 105", "a credit applies among 100,000 accounts")
    holds(st, "acct_77777", "105", "the credited account has its new balance")
    holds(st, "acct_77776", "100", "a neighbor keeps its balance")
    handled(st, "evt_many", credit("acct_77777", "5"), 400, "replayed accepted 105", "a duplicate among 100,000 accounts replays")
    IO.try(Unit, C.close(st))

def selection(p: Bytes.Bytes) -> C.Read:
  C.Range{Bytes.from_string("acct_7777"), Bytes.from_string("acct_7778"), Maybe.default(&2, U32, Bytes.u32.read(p), 0)}

def selected(rs: List<C.Row>) -> String:
  match rs:
    case Nil{}:
      ""
    case Con{C.Row{k, Some{v}}, rest}:
      Bytes.to_string(k) ++ "=" ++ Bytes.to_string(v) ++ ";" ++ selected(rest)
    case Con{C.Row{k, None{}}, rest}:
      "missing;" ++ selected(rest)

def summarize(rs: List<C.Row>, p: Bytes.Bytes) -> M.Decision<List<C.Row>, Bytes.Bytes, Bytes.Bytes>:
  M.Accept{[], Bytes.from_string(selected(rs)), []}

def limited(r: Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>>) -> IO(Unit):
  match r:
    case Fail{(code, msg)}:
      ok(U32.is_eq(code, 18), "a full range fails with SQLITE_TOOBIG")
    case Done{x}:
      IO.die(Unit, 1, "a full range must not give decide a partial state")

def empty.selection(p: Bytes.Bytes) -> C.Read:
  C.Range{Bytes.from_string("absent/"), Bytes.from_string("absent0"), 0}

def ranges() -> IO(Unit):
  do IO<Unit>:
    +st : C.Store <- IO.try(C.Store, C.open(path(), 10000))
    too_many : Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>> <- C.handle(~selection, ~summarize, st, "range", Bytes.from_string("10"), 500)
    limited(too_many)
    zero : Result<&1, &1, U32 & String, M.Reply<Bytes.Bytes>> <- C.handle(~selection, ~summarize, st, "zero", Bytes.from_string("0"), 500)
    limited(zero)
    r : M.Reply<Bytes.Bytes> <- IO.try(M.Reply<Bytes.Bytes>, C.handle(~selection, ~summarize, st, "range", Bytes.from_string("11"), 500))
    same(L.reply.show(r), "fresh accepted acct_7777=100;acct_77770=100;acct_77771=100;acct_77772=100;acct_77773=100;acct_77774=100;acct_77775=100;acct_77776=100;acct_77777=105;acct_77778=100;acct_77779=100;", "a prefix reads exactly its rows in key order and a failed read records nothing")
    replay : M.Reply<Bytes.Bytes> <- IO.try(M.Reply<Bytes.Bytes>, C.handle(~empty.selection, ~summarize, st, "range", Bytes.from_string("11"), 500))
    same(L.reply.show(replay), "replayed accepted acct_7777=100;acct_77770=100;acct_77771=100;acct_77772=100;acct_77773=100;acct_77774=100;acct_77775=100;acct_77776=100;acct_77777=105;acct_77778=100;acct_77779=100;", "a retry replays without reading its range")
    e : M.Reply<Bytes.Bytes> <- IO.try(M.Reply<Bytes.Bytes>, C.handle(~empty.selection, ~summarize, st, "empty", Bytes.from_string("0"), 500))
    same(L.reply.show(e), "fresh accepted ", "an empty range fits a zero bound")
    IO.try(Unit, C.close(st))

def main() -> IO(Unit):
  do IO<Unit>:
    rm()
    duplicates()
    restart()
    crash()
    inflight()
    race()
    retention()
    many()
    ranges()
    rm()
    IO.print("commands check ok")
