import Base
import ./f64.bend as F

def words(+x: F.F64) -> String:
  U32.show(F.F64.hi(x)) ++ " " ++ U32.show(F.F64.lo(x))

def integer(x: Maybe<&2, U32>) -> String:
  match x:
    case None{}:
      "none"
    case Some{n}:
      U32.show(n)

def line(h: Maybe<&2, U32>, l: Maybe<&2, U32>) -> IO(Unit):
  match h l:
    case Some{hi} Some{lo}:
      +x = {F.F64{hi, lo} : F.F64}
      IO.print(words(F.F64.floor(x)) ++ " " ++ words(F.F64.ceil(x)) ++ " " ++ words(F.F64.trunc(x)) ++ " " ++ integer(F.F64.to_u32(x)))
    case _ _:
      IO.die(Unit, 1, "Expected two U32 words")

def run(args: List<String>) -> IO(Unit):
  match args:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{h, Con{l, t}}:
      do IO<Unit>:
        line(U32.read(h), U32.read(l))
        run(t)
    case _:
      IO.die(Unit, 1, "Expected word pairs")

def skip(args: List<String>) -> IO(Unit):
  match args:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{p, t}:
      run(t)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    skip(args)
