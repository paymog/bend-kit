# Journal recovery benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-hash@0.1.0.0/hash.bend as Hash
import ../journal.bend as J

# Payload length is 16 + (i * 7 mod 48). Octet j is (i * 31 + j) & 255.
def fill(k: Nat, b: Bytes.Bytes, +i: U32, +j: U32) -> Bytes.Bytes:
  match k:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, j, ((((i * 31 : U32) + j : U32) .&. 255) : U32)), i, (j + 1 : U32))

def payload(+i: U32) -> Bytes.Bytes:
  +len = (16 + (((i * 7 : U32) % 48) : U32) : U32)
  fill(U32.to_nat(len), Bytes.new(len), i, 0)

def log(k: Nat, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match k:
    case 0n:
      b
    case 1n+p:
      log(p, Bytes.append(b, J.frame(payload(i))), (i + 1 : U32))

def octet(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{x}:
      x
    case None{}:
      0

def folded(r: Bytes.Bytes & Maybe<&2, U32>, +len: U32, acc: U32) -> U32:
  (b, m) = r
  (acc * 31 + len + octet(m) : U32)

def step.of(r: Bytes.Bytes & U32, acc: U32) -> U32:
  (p, +len) = r
  folded(Bytes.get(p, 0), len, acc)

# acc * 31 + len + first payload octet, in u32.
def step(acc: U32, p: Bytes.Bytes) -> U32:
  step.of(Bytes.length(p), acc)

def bad(+why: String) -> Bool:
  False{}

def clean(t: J.Tail) -> Bool:
  match t:
    case J.Clean{}:
      True{}
    case J.Torn{}:
      False{}
    case J.Corrupt{why}:
      bad(why)

def shown(ok: Bool, +acc: U32, +n: U32, t0: Time.Duration) -> IO(Unit):
  match ok:
    case True{}:
      do IO<Unit>:
        IO.print("chk\trecover\t" ++ U32.show(acc))
        IO.print("n\trecover\t" ++ U32.show(n))
        t1 : Time.Duration <- Time.mono()
        IO.print("ms\trecover\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    case False{}:
      IO.die(Unit, 1, "recover did not read a clean log")

def at(t0: Time.Duration, +n: U32, r: J.Replay<U32, J.Cur>) -> IO(Unit):
  J.Replay{+acc, t, rest} = r
  J.Cur{b, +pos} = rest
  Bytes.Bytes{+len, buf} = b
  shown(Bool.and(clean(t), U32.is_eq(pos, len)), acc, n, t0)

# log2(records) from argv, so the replay cannot run before the clock starts.
def lg(args: List<&1, String>) -> Nat:
  match args:
    case program <> k <> Nil{}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(k), 20))
    case _:
      20n

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +n : Nat = Nat.pow(2n, lg(args))
    b : Bytes.Bytes = log(n, Bytes.new(0), 0)
    t0 : Time.Duration <- Time.mono()
    at(t0, U32.from_nat(n), J.replay.bytes(~U32, ~step, 64, b, 0))
