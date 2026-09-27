import Base
import ./int.bend as Int

def some(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "none"
    case Some{s}:
      s

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Int.U64.show(Int.U64.MAX()))
    IO.print(Int.I64.show(Int.I64.MIN()))
    IO.print(Int.U8.show(Int.U8.add(Int.U8.MAX(), Int.U8.from_u32(1))))
    IO.print(Int.I32.show(Int.I32.div(Int.I32.from_u32(4294967289), Int.I32.from_u32(2))))
    IO.print(Int.I32.show(Int.I32.mod(Int.I32.from_u32(4294967289), Int.I32.from_u32(2))))
    IO.print(some(Maybe.map(&2, Int.U64, String, Int.U64.show,
      Int.U64.read("18446744073709551615"))))
    IO.print(some(Maybe.map(&2, Int.U64, String, Int.U64.show,
      Int.U64.read("18446744073709551616"))))
    IO.print(some(Maybe.map(&2, Int.I64, String, Int.I64.show,
      Int.I64.read("-9223372036854775808"))))
    IO.print(Int.U16.show(Int.U16.saturating_mul(Int.U16.from_u32(300), Int.U16.from_u32(300))))
    IO.print(Int.I64.show(Int.I64.shr(Int.I64.MIN(), 63n)))
