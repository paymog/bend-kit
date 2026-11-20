# For each argument, prints read's words, show of that value, and read's words for the shown text. See text_check.py.
import Base
import ./f64.bend as F

def words(x: F.F64) -> String:
  match x:
    case F.F64{h, l}:
      U32.show(h) ++ " " ++ U32.show(l)

def line.back(m: Maybe<&2, F.F64>) -> String:
  match m:
    case None{}:
      "none"
    case Some{x}:
      words(x)

def line.m(m: Maybe<&2, F.F64>) -> String:
  match m:
    case None{}:
      "none"
    case Some{+x}:
      +s = F.F64.show(x)
      words(x) ++ "\t" ++ s ++ "\t" ++ line.back(F.F64.read(s))

def run(xs: List<String>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{s, t}:
      do IO<Unit>:
        IO.print(line.m(F.F64.read(s)))
        run(t)

def skip(xs: List<String>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{p, t}:
      run(t)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    skip(args)
