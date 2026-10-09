import Base
import bend-kit-random@0.1.0.1/random.bend as Rand
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./property.bend as Prop
import ./generate.bend as Gen
import ./shrink.bend as Shrink

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def sum(xs: List<&2, U32>) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{h, t}:
      (h + sum(t) : U32)

# Planted defect: the sum ignores everything past the second item.
def buggy(xs: List<&2, U32>) -> U32:
  sum(List.take(&2, U32, xs, 2n))

def sum.test(+xs: List<&2, U32>) -> List<&2, U32> & Bool:
  (xs, U32.is_eq(sum(xs), buggy(xs)))

def copy(+xs: List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  (xs, xs)

def generate(r: Rand.Rng) -> List<&2, U32> & Rand.Rng:
  Gen.list(~U32, ~Gen.u32, 8, r)

def shrink(xs: List<&2, U32>) -> List<&1, List<&2, U32>>:
  Shrink.list(~U32, ~Shrink.u32, xs)

def show(xs: List<&2, U32>) -> String:
  List.show(~&2, ~U32, ~U32.show, xs)

def same(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      U32.is_eq(x, y) && same(xt, yt)
    case _ _:
      False{}

def minimal(result: Maybe<&1, Prop.Failure<List<&2, U32>>>) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{Prop.Failure{seed, trial, value}}:
      U32.is_eq(seed, 42) && same(value, [0, 0, 1])

def bytes.copy.pair(r: Bytes.Bytes & U32) -> Bytes.Bytes & Bytes.Bytes:
  (b, len) = r
  Bytes.slice(b, 0, len)

def bytes.copy(b: Bytes.Bytes) -> Bytes.Bytes & Bytes.Bytes:
  bytes.copy.pair(Bytes.length(b))

def bytes.test.eq(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bytes.Bytes & Bool:
  (original, rebuilt, ok) = r
  (original, ok)

def bytes.test.pair(r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & Bool:
  (original, probe) = r
  bytes.test.eq(Bytes.eq(original, Bytes.from_string(Bytes.to_string(probe))))

def bytes.test(b: Bytes.Bytes) -> Bytes.Bytes & Bool:
  bytes.test.pair(bytes.copy(b))

def main() -> IO(Unit):
  do IO<Unit>:
    require(minimal(Prop.check(~List<&2, U32>, ~generate, ~(xs => copy(xs)), ~shrink, ~(xs => sum.test(xs)), 42, 100n)), "planted bug did not shrink to [0, 0, 1]")
    failed : Bool <- Prop.run(~List<&2, U32>, ~generate, ~(xs => copy(xs)), ~shrink, ~(xs => sum.test(xs)), ~show, 42, 100n)
    require(Bool.not(failed), "planted bug passed")
    valid : Bool <- Prop.run(~Bytes.Bytes, ~(r => Gen.bytes(16, r)), ~bytes.copy,
      ~Shrink.bytes, ~bytes.test, ~Bytes.to_hex, 42, 100n)
    require(valid, "bytes generator failed a round trip")
    IO.print("property ok")
