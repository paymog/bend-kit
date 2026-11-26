import Base
import ../text.bend as T
import ../byte_check.bend as Check
import ./bench.bend as Bench
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def materialized(a: Bytes.Bytes & String, b: Bytes.Bytes & String, t0: Time.Duration) -> IO(Unit):
  (_, old) = a
  (_, new) = b
  do IO<Unit>:
    IO.print("materialized bytes\t" ++ Nat.show(Nat.add(String.length(old), String.length(new))))
    t1 : Time.Duration <- Time.mono()
    IO.print("materialize ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def packed.result(r: Bytes.Bytes & Bytes.Bytes & List<&2, T.Edit<T.ByteRange>>, t0: Time.Duration) -> IO(Unit):
  (a, b, es1) = r
  +es = {es1 : List<&2, T.Edit<T.ByteRange>>}
  do IO<Unit>:
    IO.print("checksum\t" ++ U32.show(Check.changed(es)))
    t1 : Time.Duration <- Time.mono()
    IO.print("diff ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    t2 : Time.Duration <- Time.mono()
    materialized(Check.collect(T.before(T.ByteRange, es), (a, Nil{})), Check.collect(T.after(T.ByteRange, es), (b, Nil{})), t2)

def packed(a: Bytes.Bytes, b: Bytes.Bytes, t0: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("convert ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    t2 : Time.Duration <- Time.mono()
    packed.result(T.diff_bytes(a, b), t2)


def baseline(a: String, b: String, t0: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    IO.print("checksum\t" ++ U32.show(Bench.changes(T.diff_lines(a, b), 0)))
    t1 : Time.Duration <- Time.mono()
    IO.print("diff ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def run.pick(is_packed: Bool, a: String, b: String, t0: Time.Duration) -> IO(Unit):
  match is_packed:
    case True{}:
      packed(Bytes.from_string(a), Bytes.from_string(b), t0)
    case False{}:
      baseline(a, b, t0)

def run(mode: String, a: String, b: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    run.pick(String.eq(mode, "packed"), a, b, t0)

def args(as: List<&1, String>) -> IO(Unit):
  match as:
    case _ <> mode <> n <> Nil{}:
      +size = Maybe.default(&2, U32, U32.read(n), 10000)
      run(mode, String.join(Bench.old.go(U32.to_nat(size), 0), "\n") ++ "\n", String.join(Bench.new.go(U32.to_nat(size), 0), "\n") ++ "\n")
    case _:
      IO.die(Unit, 1, "usage: packed baseline|packed 10000")

def main() -> IO(Unit):
  do IO<Unit>:
    as : List<&1, String> <- IO.args()
    args(as)
