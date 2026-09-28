# Shrinkers: each maps a value to its simpler candidates, simplest first.
# Candidates come as List<&1, T> for every T, so Data and affine types share one runner.
# A shrinker never lists its input, so a runner that takes the first failing candidate and
# shrinks again halts at a value none of whose candidates fail.
# Numbers try 0, then the halving steps n - n/2, n - n/4, ..., n - 1: at most 33 candidates,
# and n - 1 is always among them, so a descent reaches the exact failure boundary.
# Lists try [], then drop chunks of n/2, n/4, ..., 1 elements (about 2n candidates), then
# simplify one element at a time, left to right, through the element's own shrinker.
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

# (n - d), then (n - d/2), ..., while d > 0; stop tells whether d is 0.
def u32.go(f: Nat, stop: Bool, +n: U32, +d: U32) -> List<&1, U32>:
  match f stop:
    case 0n _:
      Nil{}
    case 1n+p True{}:
      Nil{}
    case 1n+p False{}:
      +h = (d >> 1n : U32)
      (n - d : U32) <> u32.go(p, U32.is_eq(h, 0), n, h)

# 0, n - n/2, n - n/4, ..., n - 1. None for 0.
def u32(n: U32) -> List<&1, U32>:
  +m = n
  u32.go(33n, U32.is_eq(m, 0), m, m)

def nat.go(f: Nat, stop: Bool, +n: Nat, +d: Nat) -> List<&1, Nat>:
  match f stop:
    case 0n _:
      Nil{}
    case 1n+p True{}:
      Nil{}
    case 1n+p False{}:
      +h = Nat.div(d, 2n)
      (n - d : Nat) <> nat.go(p, Nat.is_eq(h, 0n), n, h)

# 0n, n - n/2, n - n/4, ..., n - 1. None for 0n.
def nat(n: Nat) -> List<&1, Nat>:
  +m = n
  nat.go(m, Nat.is_eq(m, 0n), m, m)

# Every run of k elements at offsets o, o + k, ... that fits in n; stop tells whether o + k > n.
def list.chunks(-A: Data, f: Nat, stop: Bool, +o: Nat, +k: Nat, +n: Nat, +xs: List<&2, A>) -> List<&1, List<&2, A>>:
  match f stop:
    case 0n _:
      Nil{}
    case 1n+p True{}:
      Nil{}
    case 1n+p False{}:
      +e = (o + k : Nat)
      List.append(&2, A, List.take(&2, A, xs, o), List.drop(&2, A, xs, e))
        <> list.chunks(A, p, Nat.is_gt((e + k : Nat), n), e, k, n, xs)

# Chunk deletions for k = n, n/2, ..., 1; k = n is the lone candidate [].
def list.dels(-A: Data, f: Nat, stop: Bool, +k: Nat, +n: Nat, +xs: List<&2, A>) -> List<&1, List<&2, A>>:
  match f stop:
    case 0n _:
      Nil{}
    case 1n+p True{}:
      Nil{}
    case 1n+p False{}:
      +h = Nat.div(k, 2n)
      List.append(&1, List<&2, A>, list.chunks(A, n, Nat.is_gt(k, n), 0n, k, n, xs),
        list.dels(A, p, Nat.is_eq(h, 0n), h, n, xs))

def list.heads(-A: Data, cs: List<&1, A>, +t: List<&2, A>) -> List<&1, List<&2, A>>:
  match cs:
    case Nil{}:
      Nil{}
    case c <> r:
      (c <> t) <> list.heads(A, r, t)

def list.cons(-A: Data, +h: A, rs: List<&1, List<&2, A>>) -> List<&1, List<&2, A>>:
  match rs:
    case Nil{}:
      Nil{}
    case r <> t:
      (h <> r) <> list.cons(A, h, t)

# One element replaced by one of its candidates: the head's first, then the tail's.
def list.ones(~A: Data, ~shrink: A -> List<&1, A>, +xs: List<&2, A>) -> List<&1, List<&2, A>>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      List.append(&1, List<&2, A>, list.heads(A, shrink(h), t),
        list.cons(A, h, list.ones(~A, ~shrink, t)))

# [], chunk deletions (halves down to single elements), then single-element simplifications.
def list(~A: Data, ~shrink: A -> List<&1, A>, xs: List<&2, A>) -> List<&1, List<&2, A>>:
  +ys = xs
  +n = List.length(&2, A, ys)
  List.append(&1, List<&2, A>, list.dels(A, n, Nat.is_eq(n, 0n), n, n, ys),
    list.ones(~A, ~shrink, ys))

def maybe.some(-A: Data, xs: List<&1, A>) -> List<&1, Maybe<&2, A>>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> t:
      Some{x} <> maybe.some(A, t)

# None, then Some of each candidate of x. None for None.
def maybe(~A: Data, ~shrink: A -> List<&1, A>, m: Maybe<&2, A>) -> List<&1, Maybe<&2, A>>:
  match m:
    case None{}:
      Nil{}
    case Some{x}:
      None{} <> maybe.some(A, shrink(x))

def char.lift(xs: List<&1, U32>, +base: U32) -> List<&1, Char>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> t:
      Chr{(base + x : U32)} <> char.lift(t, base)

def char.of(o: Cmp, +c: U32) -> List<&1, Char>:
  match o:
    case LT{}:
      Chr{97} <> char.lift(u32(c), 0)
    case EQ{}:
      Nil{}
    case GT{}:
      char.lift(u32((c - 97 : U32)), 97)

# Toward 'a': a code above it halves toward it; one below tries 'a', then halves toward 0.
def char(c: Char) -> List<&1, Char>:
  match c:
    case Chr{+x}:
      char.of(U32.cmp(x, 97), x)

def string.of(xs: List<&1, List<&2, Char>>) -> List<&1, String>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> t:
      String.from_list(x) <> string.of(t)

# A String as a list of Chars under char.
def string(s: String) -> List<&1, String>:
  string.of(list(~Char, ~char, String.to_list(s)))

def bytes.codes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{x}, t}:
      x <> bytes.codes(t)

def bytes.chars(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case x <> t:
      SCon{Chr{x}, bytes.chars(t)}

def bytes.of(xs: List<&1, List<&2, U32>>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> t:
      Bytes.from_string(bytes.chars(x)) <> bytes.of(t)

# Bytes is affine, so this never copies b: it reads the octets out once and builds each
# candidate as a fresh buffer, shrinking the octets as a list with bytes toward 0.
def bytes(b: Bytes.Bytes) -> List<&1, Bytes.Bytes>:
  bytes.of(list(~U32, ~u32, bytes.codes(Bytes.to_string(b))))
