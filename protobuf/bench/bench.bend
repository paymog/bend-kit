import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import bend-kit-time@0.1.2.0/time.bend as Time
import ../protobuf.bend as P
import ./out/schema.bend as S
import ./out/fixture.bend as Input

def sum.go(n: Nat, r: B.Bytes & Maybe<&2, U32>, +i: U32, total: U32) -> B.Bytes & U32:
  match n:
    case 0n:
      (b, byte) = r
      (b, total)
    case 1n+p:
      (b, byte) = r
      match byte:
        case None{}:
          (b, total)
        case Some{v}:
          sum.go(p, B.get(b, (i + 1 : U32)), (i + 1 : U32), (total + v : U32))

def sum(b: B.Bytes, total: U32) -> B.Bytes & U32:
  B.Bytes{+len, buf} = b
  sum.go(U32.to_nat(len), B.get(B.Bytes{len, buf}, 0), 0, total)

def step(b: B.Bytes) -> Result<&2, &1, P.Error, B.Bytes>:
  do Result<&2, &1, P.Error, B.Bytes>:
    message : S.PB_kit_bench_Sample <- S.decode_PB_kit_bench_Sample(b, 1048576, 64n)
    S.encode_PB_kit_bench_Sample(message, 1048576, 64n)

def checked(r: Result<&2, &1, P.Error, B.Bytes>, total: U32) -> Result<&2, &1, P.Error, B.Bytes & U32>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      Done{sum(b, total)}

def loop(n: Nat, r: Result<&2, &1, P.Error, B.Bytes & U32>) -> Result<&2, &1, P.Error, U32>:
  match n r:
    case _ Fail{e}:
      Fail{e}
    case 0n Done{(b, total)}:
      Done{total}
    case 1n+p Done{(b, total)}:
      loop(p, checked(step(b), total))

def report(r: Result<&2, &1, P.Error, U32>, elapsed: Time.Duration) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "protobuf benchmark failed")
    case Done{checksum}:
      IO.print(U32.show(checksum) ++ "\t" ++ Time.Duration.show_ms(elapsed))

def run(input: Maybe<&1, B.Bytes>) -> IO(Unit):
  match input:
    case None{}:
      IO.die(Unit, 1, "invalid fixture")
    case Some{b}:
      do IO<Unit>:
        start : Time.Duration <- Time.mono()
        result : Result<&2, &1, P.Error, U32> = loop(100n, Done{(b, 0)})
        end : Time.Duration <- Time.mono()
        report(result, Time.Duration.sub(end, start))

def main() -> IO(Unit):
  run(Input.bytes())
