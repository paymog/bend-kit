import Base
import ./f64.bend as F

def show(name: String, x: F.F64) -> IO(Unit):
  match x:
    case F.F64{hi, lo}:
      do IO<Unit>:
        IO.print(name)
        IO.print(U32.show(hi))
        IO.print(U32.show(lo))

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
