# Profile one bounded range path without the fresh and replay passes.
import Base
import ./bench.bend as B
import ../commands.bend as C
import ../model.bend as M
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

def run(+overflow: Bool, +n: U32) -> IO(Unit):
  do IO<Unit>:
    +st : C.Store <- IO.try(C.Store, C.open(":memory:", 10000))
    B.range.seed(st, 100000)
    t0 : Time.Duration <- Time.mono()
    h : U32 <- B.range.run(U32.to_nat(n), st, overflow, 0, 0)
    t1 : Time.Duration <- Time.mono()
    B.lap("profile", t0, t1, h)
    B.range.check(st, Bool.pick(U32, overflow, 0, n))
    r : M.Reply<Bytes.Bytes> <- IO.try(M.Reply<Bytes.Bytes>, C.handle(~B.range.keys, ~B.range.decide, st, "overflow", Bytes.from_string("8"), 200))
    v : U32 <- B.result(True{}, r)
    IO.try(Unit, C.close(st))

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case Con{prog, Con{mode, Con{n, rest}}}:
      run(String.eq(mode, "overflow"), B.rows.of(U32.read(n)))
    case _:
      IO.die(Unit, 1, "usage: profile range|overflow count")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
