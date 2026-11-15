import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import ./commands.bend as C
import ./ledger.bend as L

# Writes inside a transaction, then dies before COMMIT.
def crash(st: C.Store) -> IO(Unit):
  C.Store{db, +begin, commit, rollback, find, read, +save, +del, +keep, emit} = st
  do IO<Unit>:
    IO.try(Unit, C.exec(begin))
    IO.try(Unit, C.rows.put([C.Row{Bytes.from_string("a"), Some{Bytes.from_string("999")}}], save, del))
    IO.try(Unit, C.seen.put(C.Record{Bytes.from_string("{\"account\":\"a\",\"credit\":1}"), C.Accepted{Bytes.from_string("999")}, 200}, keep, "evt_4"))
    IO.die(Unit, 9, "crash before COMMIT")

def fresh(r: C.Reply<Bytes.Bytes>) -> U32:
  match r:
    case C.Fresh{o}:
      1
    case _:
      0

# Credits 1 to account race under n ids from race_i. Prints how many replies were fresh.
def race(n: Nat, +st: C.Store, +i: U32, +k: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.print("fresh=" ++ U32.show(k))
    case 1n+m:
      do IO<Unit>:
        r : C.Reply<Bytes.Bytes> <- IO.try(C.Reply<Bytes.Bytes>, C.handle(~L.keys, ~L.decide, st, "race_" ++ U32.show(i), Bytes.from_string("{\"account\":\"race\",\"credit\":1}"), 200))
        race(m, st, (i + 1 : U32), (k + fresh(r) : U32))

def run(xs: List<String>) -> IO(Unit):
  match xs:
    case Con{prog, Con{+mode, Con{path, Nil{}}}}:
      do IO<Unit>:
        +st : C.Store <- IO.try(C.Store, C.open(path, 10000))
        Bool.pick(IO(Unit), String.eq(mode, "crash"), crash(st), race(400n, st, 0, 0))
    case _:
      IO.die(Unit, 2, "usage: child.bend <crash|race> <path>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
