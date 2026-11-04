import Base
import ./f64.bend as F

def show(name: String, x: F.F64) -> IO(Unit):
  match x:
    case F.F64{hi, lo}:
      do IO<Unit>:
        IO.print(name)
        IO.print(U32.show(hi))
        IO.print(U32.show(lo))

def read.m(m: Maybe<&2, F.F64>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{x}:
      IO.print(F.F64.show(x))

def read(+s: String) -> IO(Unit):
  do IO<Unit>:
    IO.print(s)
    read.m(F.F64.read(s))

def main() -> IO(Unit):
  +one = F.F64.one()
  do IO<Unit>:
    show("one+one", F.F64.add(one, F.F64.one()))
    show("from3", F.F64.from_u32(3))
    show("neg0", F.F64.add(F.F64{2147483648, 0}, F.F64{2147483648, 0}))
    show("cancel", F.F64.add(one, F.F64.neg(F.F64.one())))
    show("inf-inf", F.F64.sub(F.F64.inf(), F.F64.inf()))
    show("mul", F.F64.mul(F.F64{1073217536, 0}, F.F64{1073217536, 0}))
    show("div", F.F64.div(one, F.F64.from_u32(3)))
    show("ovf", F.F64.add(F.F64{2146435071, 4294967295}, F.F64{2146435071, 4294967295}))
    show("sub2", F.F64.add(F.F64{0, 1}, F.F64{0, 1}))
    show("div0", F.F64.div(one, F.F64.zero()))
    show("zero0", F.F64.div(F.F64.zero(), F.F64.zero()))
    show("mul0", F.F64.mul(F.F64{2147483648, 0}, one))
    show("tie", F.F64.add(one, F.F64{1017118720, 0}))
    IO.print(F.F64.show(F.F64.div(one, F.F64.from_u32(3))))
    IO.print(F.F64.show(F.F64{2146435071, 4294967295}))
    IO.print(F.F64.show(F.F64{1048576, 0}))
    read("123.456e-2")
    read("0.000001")
    read("1e400")
    read("-1e-400")
    read("nan")
    read("1.5x")
