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

def matches(value: Maybe<&2, F32>, expected: F32) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{x}:
      F32.is_eq(x, expected)

def valid(n: Nat, pair: A.F32Array & Maybe<&2, F32>, +at: U32, +len: U32, ok: Bool) -> Bool:
  match n:
    case 0n:
      ok
    case 1n+p:
      (array, value) = pair
      +expected = Bool.pick(F32, Bool.or(U32.is_eq(at, 0), U32.is_eq(at, (len + 1 : U32))),
        0.0, (U32.to_f32(((at - 1 : U32) % 8 : U32)) - 2.0 : F32))
      valid(p, A.get(array, (at + 1 : U32)), (at + 1 : U32), len,
        Bool.and(ok, matches(value, expected)))

def report.sum(pair: A.F32Array & F32, file: File, +n: U32, t0: Time.Duration) -> IO(Unit):
  (array, sum) = pair
  do IO<Unit>:
    IO.print("sum " ++ F32.show(sum))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms " ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    IO.print("valid " ++ Bool.show(valid(U32.to_nat((n + 2 : U32)), A.get(array, 0), 0, n, True{})))
    File.close(file)

def report(pair: File & A.F32Array & Result<&1, &1, U32 & String, Unit>, n: U32, t0: Time.Duration) -> IO(Unit):
  (file, array, result) = pair
  do IO<Unit>:
    IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, result))
    report.sum(A.sum(array), file, n, t0)

def allocated(pair: File & Result<&1, &1, U32 & String, A.F32Array>, dest: A.F32Array, +n: U32, t0: Time.Duration) -> IO(Unit):
  (file, result) = pair
  match result:
    case Fail{e}:
      report((file, dest, Fail{e}), n, t0)
    case Done{source}:
      report((file, copy(U32.to_nat(n), A.get(source, 0), dest, 0), Done{Unit{}}), n, t0)

def run(direct: Bool, bf16: Bool, file: File, +n: U32, dest: A.F32Array, t0: Time.Duration) -> IO(Unit):
  match direct:
    case True{}:
      do IO<Unit>:
        pair : File & A.F32Array & Result<&1, &1, U32 & String, Unit> <- F.read.at.into.with(file, 0, 0, n, Bool.pick(U32, bf16, 2, 4), dest, 1)
        report(pair, n, t0)
    case False{}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, A.F32Array> <- F.read.at.with(file, 0, 0, n, Bool.pick(U32, bf16, 2, 4))
        allocated(pair, dest, n, t0)

def prepared(direct: Bool, bf16: Bool, file: File, +n: U32, dest: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    run(direct, bf16, file, n, dest, t0)

def number(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{n}:
      n
    case None{}:
      0

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case _ <> mode <> format <> count <> Nil{}:
      +n = number(U32.read(count))
      do IO<Unit>:
        file : File <- IO.try(File, File.open("load.bin", "r"))
        prepared(String.eq(mode, "into"), String.eq(format, "bf16"), file, n, A.new((n + 2 : U32)))
    case _:
      IO.die(Unit, 1, "usage: load into|copy f32|bf16 N")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
