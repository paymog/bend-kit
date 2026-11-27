import Base
import ../text.bend as T
import ./bench.bend as Bench
import ../../time/time.bend as Time

def edges() -> Bool:
  Bool.and(String.eq(String.join(T.lines(""), "|"), ""),
    Bool.and(String.eq(String.join(T.lines("a\n\nb"), "|"), "a\n|\n|b"),
      Bool.and(String.eq(String.join(T.lines("\n"), "|"), "\n"),
        Bool.and(String.eq(String.join(T.lines("猫😀\na\n"), "|"), "猫😀\n|a\n"),
          String.eq(String.join(T.lines("Ċ\nx\r\n😀"), "|"), "Ċ\n|x\r\n|😀")))))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +s : U32 = Bench.scale(args)
    Bool.pick(IO(Unit), edges(), IO.pure(Unit, Unit{}), IO.die(Unit, 1, "line split regression"))
    IO.print("edges\tTrue")
    +a : String = String.join(Bench.old.go(U32.to_nat((s * 10000 : U32)), 0), "\n") ++ "\n"
    +b : String = String.join(Bench.new.go(U32.to_nat((s * 10000 : U32)), 0), "\n") ++ "\n"
    t0 : Time.Duration <- Time.mono()
    IO.print("chk\tsplit\t" ++ Nat.show(Nat.add(List.length(&2, String, T.lines(a)), List.length(&2, String, T.lines(b)))))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tsplit\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
