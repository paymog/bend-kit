import Base
import ./text.bend as T

def show(es: List<&2, T.Edit<Char>>) -> String:
  match es:
    case Nil{}:
      ""
    case Con{T.Same{o, n}, t}:
      SCon{n, show(t)}
    case Con{T.Del{o}, t}:
      "-" ++ SCon{o, show(t)}
    case Con{T.Ins{n}, t}:
      "+" ++ SCon{n, show(t)}

def changes(es: List<&2, T.Edit<U32>>, +n: U32) -> U32:
  match es:
    case Nil{}:
      n
    case Con{T.Same{_, _}, t}:
      changes(t, n)
    case Con{_, t}:
      changes(t, (n + 1 : U32))

# Insert/delete distance by dynamic programming: the length a shortest script must have.
def indel.row(b: List<&2, U32>, up: List<&2, U32>, +x: U32, +diag: U32, +left: U32) -> List<&2, U32>:
  match b up:
    case Con{+y, bt} Con{+u, ut}:
      +v = U32.min(U32.min((u + 1 : U32), (left + 1 : U32)), Bool.pick(U32, U32.is_eq(x, y), diag, 1000000))
      v <> indel.row(bt, ut, x, u, v)
    case _ _:
      Nil{}

def indel.go(a: List<&2, U32>, +b: List<&2, U32>, prev: List<&2, U32>, +i: U32) -> U32:
  match a prev:
    case Con{+x, at} Con{+p0, pt}:
      +j = (i + 1 : U32)
      indel.go(at, b, j <> indel.row(b, pt, x, p0, j), j)
    case _ _:
      T.lev.last(prev, 0)

def indel(a: List<&2, U32>, +b: List<&2, U32>) -> U32:
  indel.go(a, b, T.lev.init(List.length(&2, U32, b), 0), 0)

def lcg(+x: U32) -> U32:
  ((x * 1103515245 + 12345 : U32) .&. 2147483647 : U32)

def gen.go(n: Nat, +x: U32, acc: List<&2, U32>) -> List<&2, U32> & U32:
  match n:
    case 0n:
      (acc, x)
    case 1n+p:
      +y = lcg(x)
      gen.go(p, y, ((y >> 16n : U32) % 3 : U32) <> acc)

# 0 to 15 items from {0, 1, 2}, and the next state.
def gen(+x: U32) -> List<&2, U32> & U32:
  +y = lcg(x)
  gen.go(U32.to_nat(((y >> 16n : U32) % 16 : U32)), y, Nil{})

# A key that collides: 0 and 2 share one, so diff_by must catch the bad pairs.
def parity(x: U32) -> U32:
  (x % 2 : U32)

def bad.two(+a: List<&2, U32>, p: List<&2, U32> & U32) -> U32 & U32:
  (+b, x) = p
  +d = indel(a, b)
  +ok1 = U32.is_eq(changes(T.diff(~U32, ~U32.is_eq, a, b), 0), d)
  +ok2 = U32.is_eq(changes(T.diff_by(~U32, ~U32.is_eq, ~parity, a, b), 0), d)
  (Bool.pick(U32, Bool.and(ok1, ok2), 0, 1), x)

def bad.one(p: List<&2, U32> & U32) -> U32 & U32:
  (a, x) = p
  bad.two(a, gen(x))

def bad(k: Nat, +n: U32, q: U32 & U32) -> U32:
  match k:
    case 0n:
      (e, x) = q
      (n + e : U32)
    case 1n+p:
      (e, x) = q
      bad(p, (n + e : U32), bad.one(gen(x)))

# Pieces that test cluster joins: combining marks, VS16, ZWJ, wide, Prepend, spacing marks, and spaces.
def piece(+k: U32) -> String:
  Bool.pick(String, U32.is_lt(k, 6),
    Bool.pick(String, U32.is_lt(k, 3), Bool.pick(String, U32.is_eq(k, 0), "a", Bool.pick(String, U32.is_eq(k, 1), "bc", " ")),
      Bool.pick(String, U32.is_eq(k, 3), "  ", Bool.pick(String, U32.is_eq(k, 4), "\u{301}", "\u{FE0F}"))),
    Bool.pick(String, U32.is_lt(k, 9), Bool.pick(String, U32.is_eq(k, 6), "日", Bool.pick(String, U32.is_eq(k, 7), "é", "\u{200D}")),
      Bool.pick(String, U32.is_eq(k, 9), "👍", Bool.pick(String, U32.is_eq(k, 10), "\u{600}", Bool.pick(String, U32.is_eq(k, 11), "\u{93E}", "\t")))))

def rtext.go(n: Nat, +x: U32, acc: String) -> String & U32:
  match n:
    case 0n:
      (acc, x)
    case 1n+p:
      +y = lcg(x)
      rtext.go(p, y, piece(((y >> 16n : U32) % 13 : U32)) ++ acc)

# 0 to 29 pieces, and the next state.
def rtext(+x: U32) -> String & U32:
  +y = lcg(x)
  rtext.go(U32.to_nat(((y >> 16n : U32) % 30 : U32)), y, "")

def wrap.same(+t: String, +w: U32) -> Bool:
  String.eq(String.join(T.wrap.fast(t, w), "\n"), String.join(T.wrap.slow(t, w), "\n"))

def wrap.diff(k: Nat, +n: U32, q: String & U32) -> U32:
  match k:
    case 0n:
      (t, x) = q
      n
    case 1n+p:
      (+t, +x) = q
      +w = (1 + ((x >> 8n : U32) % 12 : U32) : U32)
      wrap.diff(p, (n + Bool.pick(U32, wrap.same(t, w), 0, 1) : U32), rtext(x))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(show(T.diff_chars("ABCABBA", "CBABAC")))
    IO.print(T.unified("old.txt", "new.txt", T.diff_lines("a\nb\nc\nd", "a\nB\nc\nd\ne\n"), 3))
    IO.print("FNV-1a collision lines: " ++ T.unified("a", "b", T.diff_lines("x\naan1wu\ny\n", "x\naa0tfa\ny\n"), 0))
    IO.print("non-shortest diffs in 3000 random pairs: " ++ U32.show(bad(3000n, 0, (0, 7))))
    IO.print("distance kitten sitting: " ++ U32.show(T.distance("kitten", "sitting")))
    IO.print("wrap fast/slow mismatches in 3000 random texts: " ++ U32.show(wrap.diff(3000n, 0, rtext(11))))
    IO.print(String.join(T.wrap("The quick brown fox jumps over the lazy dog. 日本語の文章も折り返す。", 16), "\n"))
