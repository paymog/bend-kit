import Base
import ./fmt.bend as Fmt

def f32(x: U32) -> F32:
  match x:
    case U32{w}:
      F32{w}

def same(+b: U32, m: Maybe<&2, F32>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{y}:
      U32.is_eq(F32.bits(y), b)

# NaN and infinity are fixed words, so only finite values count.
def ok(+b: U32) -> Bool:
  Bool.or(U32.is_eq(U32.and(b, 2139095040), 2139095040),
    same(b, F32.read(Fmt.F32.shortest(f32(b)))))

def bad(f: Nat, +b: U32, +n: U32) -> U32:
  match f:
    case 0n:
      n
    case 1n+g:
      bad(g, U32.add(b, 2654435761),
        U32.add(n, Bool.pick(U32, ok(b), 0, 1)))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Fmt.Builder.build(Fmt.Builder.add(Fmt.Builder.add(Fmt.Builder.new(), "ab"), "cd")))
    IO.print(Fmt.Fmt.format("{} of {}", ["3", "7"]))
    IO.print(Fmt.F32.shortest(f32(2139095039)))
    IO.print("round-trip failures in 5000 words: " ++ U32.show(bad(5000n, 1, 0)))
