# commands benchmark: N new commands, then the same N again as duplicates, through commands.handle (see README.md).
import Base
import ../../time/time.bend as Time
import ../commands.bend as C
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-sqlite@0.1.0.1/sqlite.bend as S

def lcg(+x: U32) -> U32:
  (x * 1664525 + 1013904223 : U32)

def num(b: Bytes.Bytes) -> U32:
  Maybe.default(&2, U32, Bytes.u32.read(b), 0)

def total() -> Bytes.Bytes:
  Bytes.from_string("total")

# Every command reads the one row "total".
def keys(p: Bytes.Bytes) -> List<Bytes.Bytes>:
  [total()]

def sum(rs: List<C.Row>) -> U32:
  match rs:
    case Con{C.Row{k, Some{v}}, rest}:
      num(v)
    case _:
      0

# A running total: each payload is an amount, and the result is the new total.
def decide(rs: List<C.Row>, p: Bytes.Bytes) -> C.Decision<List<C.Row>, Bytes.Bytes, Bytes.Bytes>:
  +t = (sum(rs) + num(p) : U32)
  C.Accept{[C.Row{total(), Some{Bytes.u32.show(t)}}], Bytes.u32.show(t), [Bytes.append(Bytes.from_string("total="), Bytes.u32.show(t))]}

def got(m: Maybe<Bytes.Bytes>) -> U32:
  match m:
    case Some{v}:
      num(v)
    case None{}:
      0

def lap(name: String, t0: Time.Duration, t1: Time.Duration, +c: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(c))

# The result of an accepted reply of the wanted kind, or exit.
def result(fresh: Bool, r: C.Reply<Bytes.Bytes>) -> IO(U32):
  match fresh r:
    case True{} C.Fresh{C.Accepted{s}}:
      IO.pure(U32, num(s))
    case False{} C.Replayed{C.Accepted{s}}:
      IO.pure(U32, num(s))
    case _ _:
      IO.die(U32, 1, "unexpected reply")

# Command i has id cmd_i and amount (x_i >> 1) % 1000, with x_0 = 1 and x_{i+1} = lcg(x_i). h = h*31 + result.
def run(n: Nat, +fresh: Bool, +st: C.Store, +i: U32, +x: U32, +h: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, h)
    case 1n+p:
      do IO<U32>:
        r : C.Reply<Bytes.Bytes> <- IO.try(C.Reply<Bytes.Bytes>, C.handle(~keys, ~decide, st, "cmd_" ++ U32.show(i), Bytes.u32.show(((x >> 1n) % 1000 : U32)), 200))
        +v : U32 <- result(fresh, r)
        run(p, fresh, st, (i + 1 : U32), lcg(x), (h * 31 + v : U32))

def rows.of(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      10000
    case Some{n}:
      n

# The arguments are the database path and the command count.
def args(xs: List<String>) -> String & U32:
  match xs:
    case Con{prog, Con{path, Con{s, rest}}}:
      (path, rows.of(U32.read(s)))
    case _:
      ("out/bend.db", 10000)

def bench(+st: C.Store, +n: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    f : U32 <- run(U32.to_nat(n), True{}, st, 0, 1, 0)
    t1 : Time.Duration <- Time.mono()
    t : Maybe<Bytes.Bytes> <- IO.try(Maybe<Bytes.Bytes>, C.get(st, total()))
    lap("fresh", t0, t1, got(t))
    t2 : Time.Duration <- Time.mono()
    +h : U32 <- run(U32.to_nat(n), False{}, st, 0, 1, 0)
    t3 : Time.Duration <- Time.mono()
    lap("replay", t2, t3, h)
    IO.try(Unit, C.close(st))

def version() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32, S.db.open(":memory:"))
    +q : U32 <- IO.try(U32, S.stmt.prepare(db, "SELECT sqlite_version()"))
    row : Bool <- IO.try(Bool, S.stmt.step(q))
    v : String <- IO.try(String, S.stmt.column.text(q, 0))
    IO.print("sqlite\t" ++ v)
    IO.try(Unit, S.stmt.finalize(q))
    IO.try(Unit, S.db.close(db))

def start(a: String & U32) -> IO(Unit):
  (path, +n) = a
  do IO<Unit>:
    version()
    +st : C.Store <- IO.try(C.Store, C.open(path, 10000))
    bench(st, n)

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    start(args(xs))
