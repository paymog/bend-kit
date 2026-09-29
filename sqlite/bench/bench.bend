# SQLite benchmark: N prepared inserts in one transaction, then N primary-key reads (see README.md).
import Base
import ../../time/time.bend as Time
import ../sqlite.bend as S

def lcg(+x: U32) -> U32:
  (x * 1664525 + 1013904223 : U32)

def lap(name: String, t0: Time.Duration, t1: Time.Duration, +c: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(c))

# Steps a statement once, then finalizes it.
def exec(+db: U32, sql: String) -> IO(Unit):
  do IO<Unit>:
    +st : U32 <- IO.try(U32, S.stmt.prepare(db, sql))
    row : Bool <- IO.try(Bool, S.stmt.step(st))
    IO.try(Unit, S.stmt.finalize(st))

# Steps a one-row query and returns its first column.
def one.int(+db: U32, sql: String) -> IO(U32):
  do IO<U32>:
    +st : U32 <- IO.try(U32, S.stmt.prepare(db, sql))
    row : Bool <- IO.try(Bool, S.stmt.step(st))
    +v : U32 <- IO.try(U32, S.stmt.column.int(st, 0))
    IO.try(Unit, S.stmt.finalize(st))
    return v

def one.text(+db: U32, sql: String) -> IO(String):
  do IO<String>:
    +st : U32 <- IO.try(U32, S.stmt.prepare(db, sql))
    row : Bool <- IO.try(Bool, S.stmt.step(st))
    v : String <- IO.try(String, S.stmt.column.text(st, 0))
    IO.try(Unit, S.stmt.finalize(st))
    return v

# Row i is (i, x_i >> 1) with x_0 = 1 and x_{i+1} = lcg(x_i).
def insert(n: Nat, +st: U32, +i: U32, +x: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        IO.try(Unit, S.stmt.bind.int(st, 1, i))
        IO.try(Unit, S.stmt.bind.int(st, 2, (x >> 1n : U32)))
        done : Bool <- IO.try(Bool, S.stmt.step(st))
        IO.try(Unit, S.stmt.reset(st))
        insert(p, st, (i + 1 : U32), lcg(x))

# Reads key k mod rows, stepping k by 7919; h = h*31 + v (u32).
def select(n: Nat, +st: U32, +rows: U32, +k: U32, +h: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, h)
    case 1n+p:
      do IO<U32>:
        IO.try(Unit, S.stmt.bind.int(st, 1, (k % rows : U32)))
        row : Bool <- IO.try(Bool, S.stmt.step(st))
        +v : U32 <- IO.try(U32, S.stmt.column.int(st, 0))
        IO.try(Unit, S.stmt.reset(st))
        select(p, st, rows, (k + 7919 : U32), (h * 31 + v : U32))

def run(+rows: U32, +db: U32) -> IO(Unit):
  do IO<Unit>:
    ver : String <- one.text(db, "SELECT sqlite_version()")
    IO.print("sqlite\t" ++ ver)
    exec(db, "CREATE TABLE t(k INTEGER PRIMARY KEY, v INTEGER NOT NULL)")
    +ins : U32 <- IO.try(U32, S.stmt.prepare(db, "INSERT INTO t VALUES (?1, ?2)"))
    t0 : Time.Duration <- Time.mono()
    exec(db, "BEGIN")
    insert(U32.to_nat(rows), ins, 0, 1)
    exec(db, "COMMIT")
    t1 : Time.Duration <- Time.mono()
    IO.try(Unit, S.stmt.finalize(ins))
    +count : U32 <- one.int(db, "SELECT count(*) FROM t")
    lap("insert", t0, t1, count)
    +sel : U32 <- IO.try(U32, S.stmt.prepare(db, "SELECT v FROM t WHERE k = ?1"))
    t2 : Time.Duration <- Time.mono()
    +h : U32 <- select(U32.to_nat(rows), sel, rows, 0, 0)
    t3 : Time.Duration <- Time.mono()
    lap("select", t2, t3, h)
    IO.try(Unit, S.stmt.finalize(sel))
    IO.try(Unit, S.db.close(db))

def rows.of(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      100000
    case Some{n}:
      n

# The optional first argument is the row count.
def rows(xs: List<String>) -> U32:
  match xs:
    case Con{prog, Con{s, rest}}:
      rows.of(U32.read(s))
    case _:
      100000

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +db : U32 <- IO.try(U32, S.db.open(":memory:"))
    run(rows(args), db)
