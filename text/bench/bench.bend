# Text benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../text.bend as T

def lcg(+x: U32) -> U32:
  ((x * 1103515245 + 12345 : U32) .&. 2147483647 : U32)

def letter(+y: U32) -> Char:
  Chr{(97 + ((y >> 16n : U32) % 26 : U32) : U32)}

# Cyrillic а to щ: one code point, one column, not ASCII.
def letter.u(+y: U32) -> Char:
  Chr{(1072 + ((y >> 16n : U32) % 26 : U32) : U32)}

def word.go(n: Nat, +u: Bool, +x: U32, acc: String) -> String & U32:
  match n:
    case 0n:
      (String.reverse(acc), x)
    case 1n+p:
      +y = lcg(x)
      word.go(p, u, y, SCon{Bool.pick(Char, u, letter.u(y), letter(y)), acc})

# 4 to 12 letters from the stream, and the next state. u picks Cyrillic letters.
def word.of(+u: Bool, +x: U32) -> String & U32:
  +y = lcg(x)
  word.go(U32.to_nat((4 + ((y >> 16n : U32) % 9 : U32) : U32)), u, y, SNil{})

def word(+x: U32) -> String & U32:
  word.of(False{}, x)

def line(name: String, +i: U32) -> String:
  name ++ " " ++ U32.show(i)

def old.go(n: Nat, +i: U32) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      line("line", i) <> old.go(p, (i + 1 : U32))

def hit(+i: U32, +m: U32, +r: U32) -> Bool:
  U32.is_eq((i % m : U32), r)

# Line i changes when i % 50 == 7, goes when i % 70 == 11, and gains a line after it when i % 90 == 13.
def new.go(n: Nat, +i: U32) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +keep = Bool.pick(List<&2, String>, hit(i, 70, 11), [], [line("line", i)])
      +base = Bool.pick(List<&2, String>, hit(i, 50, 7), [line("changed", i)], keep)
      +add = Bool.pick(List<&2, String>, hit(i, 90, 13), [line("added", i)], [])
      List.append(&2, String, base, List.append(&2, String, add, new.go(p, (i + 1 : U32))))

def changes(es: List<&2, T.Edit<String>>, +n: U32) -> U32:
  match es:
    case Nil{}:
      n
    case Con{T.Same{_, _}, t}:
      changes(t, n)
    case Con{_, t}:
      changes(t, (n + 1 : U32))

def step.c(+d1: String, p: String & U32) -> U32 & U32:
  (w2, x2) = p
  (T.distance(d1, w2), x2)

def step.b(p: String & U32) -> U32 & U32:
  (w1, x1) = p
  step.c(w1, word(x1))

def dist.go(k: Nat, +acc: U32, q: U32 & U32) -> U32:
  match k:
    case 0n:
      (d, x) = q
      (acc + d : U32)
    case 1n+p:
      (d, x) = q
      dist.go(p, (acc + d : U32), step.b(word(x)))

def text.go(k: Nat, +u: Bool, acc: List<&2, String>, p: String & U32) -> List<&2, String>:
  match k:
    case 0n:
      List.reverse(&2, String, acc)
    case 1n+q:
      (w, x) = p
      text.go(q, u, w <> acc, word.of(u, x))

def wrap.sum(ls: List<&2, String>, +n: U32, +c: U32) -> String:
  match ls:
    case Nil{}:
      U32.show(n) ++ ":" ++ U32.show(c)
    case Con{l, t}:
      wrap.sum(t, (n + 1 : U32), (c + U32.from_nat(String.length(l)) : U32))

def scale(args: List<&1, String>) -> U32:
  match args:
    case program <> n <> Nil{}:
      Maybe.default(&2, U32, U32.read(n), 1)
    case _:
      1

# The scale comes from argv, so no work can run before the clock starts.
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +s : U32 = scale(args)
    +a : String = String.join(old.go(U32.to_nat((s * 10000 : U32)), 0), "\n") ++ "\n"
    +b : String = String.join(new.go(U32.to_nat((s * 10000 : U32)), 0), "\n") ++ "\n"
    t0 : Time.Duration <- Time.mono()
    IO.print("chk\tdiff\t" ++ U32.show(changes(T.diff_lines(a, b), 0)))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tdiff\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    t2 : Time.Duration <- Time.mono()
    IO.print("chk\tdistance\t" ++ U32.show(dist.go(U32.to_nat((s * 20000 : U32)), 0, (0, 1))))
    t3 : Time.Duration <- Time.mono()
    IO.print("ms\tdistance\t" ++ Time.Duration.show_ms(Time.Duration.sub(t3, t2)))
    +text : String = String.join(text.go(U32.to_nat((s * 20000 : U32)), False{}, Nil{}, word(1)), " ")
    t4 : Time.Duration <- Time.mono()
    IO.print("chk\twrap\t" ++ wrap.sum(T.wrap(text, 72), 0, 0))
    t5 : Time.Duration <- Time.mono()
    IO.print("ms\twrap\t" ++ Time.Duration.show_ms(Time.Duration.sub(t5, t4)))
    +utext : String = String.join(text.go(U32.to_nat((s * 20000 : U32)), True{}, Nil{}, word.of(True{}, 1)), " ")
    t6 : Time.Duration <- Time.mono()
    IO.print("chk\twrap_utf\t" ++ wrap.sum(T.wrap(utext, 72), 0, 0))
    t7 : Time.Duration <- Time.mono()
    IO.print("ms\twrap_utf\t" ++ Time.Duration.show_ms(Time.Duration.sub(t7, t6)))
