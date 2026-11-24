import Base
import ../../time/time.bend as Time
import ../f32array.bend as A
import ../io.bend as F

def copy(n: Nat, pair: A.F32Array & Maybe<&2, F32>, dest: A.F32Array, +at: U32) -> A.F32Array:
  match n:
    case 0n:
      dest
    case 1n+p:
      (source, value) = pair
      match value:
        case None{}:
          dest
        case Some{x}:
          copy(p, A.get(source, (at + 1 : U32)), A.set(dest, (at + 1 : U32), x), (at + 1 : U32))

def checksum(pair: A.F32Array & F32) -> F32:
  (array, value) = pair
  value

def report(pair: File & A.F32Array & Result<&1, &1, U32 & String, Unit>, t0: Time.Duration) -> IO(Unit):
  (file, array, result) = pair
  do IO<Unit>:
    IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, result))
    IO.print("sum " ++ F32.show(checksum(A.sum(array))))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms " ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    File.close(file)

def allocated(pair: File & Result<&1, &1, U32 & String, A.F32Array>, dest: A.F32Array, n: U32, t0: Time.Duration) -> IO(Unit):
  (file, result) = pair
  match result:
    case Fail{e}:
      report((file, dest, Fail{e}), t0)
    case Done{source}:
      report((file, copy(U32.to_nat(n), A.get(source, 0), dest, 0), Done{Unit{}}), t0)

def run(direct: Bool, file: File, +n: U32, dest: A.F32Array, t0: Time.Duration) -> IO(Unit):
  match direct:
    case True{}:
      do IO<Unit>:
        pair : File & A.F32Array & Result<&1, &1, U32 & String, Unit> <- F.read.le.at.into(file, 0, 0, n, dest, 1)
        report(pair, t0)
    case False{}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, A.F32Array> <- F.read.le.at(file, 0, 0, n)
        allocated(pair, dest, n, t0)

def prepared(direct: Bool, file: File, +n: U32, dest: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    run(direct, file, n, dest, t0)

def number(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{n}:
      n
    case None{}:
      0

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case _ <> mode <> count <> Nil{}:
      +n = number(U32.read(count))
      do IO<Unit>:
        file : File <- IO.try(File, File.open("load.bin", "r"))
        prepared(String.eq(mode, "into"), file, n, A.new((n + 2 : U32)))
    case _:
      IO.die(Unit, 1, "usage: load into|copy N")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
