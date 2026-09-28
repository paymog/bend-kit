# Pure generators: each takes a Rand.Rng and returns a value beside the next state.
import Base
# bend-kit-random@0.1.0.0
import bend-kit-random@0.1.0.0/random.bend as Rand
# bend-kit-bytes@0.3.1.0
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

# A generator is `Rand.Rng -> T & Rand.Rng`. The same seed replays the same value:
#   (xs, r) = Gen.list(~U32, ~Gen.u32, 8, Rand.seed(42))
# Sizes are capped at 1024 so lengths and Nats stay small enough to build and shrink.

# n, capped at 1024.
def cap(+n: U32) -> U32:
  U32.min(n, 1024)

# A uniform U32.
def u32(r: Rand.Rng) -> U32 & Rand.Rng:
  Rand.next(r)

# A uniform U32 in [lo, hi); lo when hi <= lo + 1.
def u32.range(+lo: U32, hi: U32, r: Rand.Rng) -> U32 & Rand.Rng:
  Rand.range(lo, hi, r)

# A uniform size in [0, min(max, 1024)].
def size(+max: U32, r: Rand.Rng) -> U32 & Rand.Rng:
  Rand.below((cap(max) + 1 : U32), r)

def nat.fin(xr: U32 & Rand.Rng) -> Nat & Rand.Rng:
  (x, r) = xr
  (U32.to_nat(x), r)

# A uniform Nat in [0, min(max, 1024)].
def nat(+max: U32, r: Rand.Rng) -> Nat & Rand.Rng:
  nat.fin(size(max, r))

def char.fin(xr: U32 & Rand.Rng) -> Char & Rand.Rng:
  (x, r) = xr
  (Chr{x}, r)

# A printable ASCII char, ' ' (32) through '~' (126).
def char(r: Rand.Rng) -> Char & Rand.Rng:
  char.fin(Rand.range(32, 127, r))

# n + 1 chars prepended to acc; cr holds the next char.
def string.go(n: Nat, acc: String, cr: Char & Rand.Rng) -> String & Rand.Rng:
  match n:
    case 0n:
      (c, r) = cr
      (SCon{c, acc}, r)
    case 1n+p:
      (c, r) = cr
      string.go(p, SCon{c, acc}, char(r))

# Exactly n printable ASCII chars.
def string.of(n: Nat, r: Rand.Rng) -> String & Rand.Rng:
  match n:
    case 0n:
      (SNil{}, r)
    case 1n+p:
      string.go(p, SNil{}, char(r))

def string.fin(nr: Nat & Rand.Rng) -> String & Rand.Rng:
  (n, r) = nr
  string.of(n, r)

# Printable ASCII of length in [0, min(max, 1024)].
def string(+max: U32, r: Rand.Rng) -> String & Rand.Rng:
  string.fin(nat(max, r))

# Byte i and the n bytes after it; xr holds byte i (Bytes.set keeps its low 8 bits).
def bytes.go(n: Nat, b: Bytes.Bytes, +i: U32, xr: U32 & Rand.Rng) -> Bytes.Bytes & Rand.Rng:
  match n:
    case 0n:
      (x, r) = xr
      (Bytes.set(b, i, x), r)
    case 1n+p:
      (x, r) = xr
      bytes.go(p, Bytes.set(b, i, x), (i + 1 : U32), Rand.next(r))

def bytes.start(n: Nat, +len: U32, r: Rand.Rng) -> Bytes.Bytes & Rand.Rng:
  match n:
    case 0n:
      (Bytes.new(0), r)
    case 1n+p:
      bytes.go(p, Bytes.new(len), 0, Rand.next(r))

# Exactly min(len, 1024) uniform octets, one draw each.
def bytes.of(+len: U32, r: Rand.Rng) -> Bytes.Bytes & Rand.Rng:
  +n = cap(len)
  bytes.start(U32.to_nat(n), n, r)

def bytes.fin(nr: U32 & Rand.Rng) -> Bytes.Bytes & Rand.Rng:
  (n, r) = nr
  bytes.of(n, r)

# Uniform octets, length in [0, min(max, 1024)].
def bytes(+max: U32, r: Rand.Rng) -> Bytes.Bytes & Rand.Rng:
  bytes.fin(size(max, r))

# n + 1 items prepended to acc; hr holds the next item.
def list.go(~T: Data, ~gen: Rand.Rng -> T & Rand.Rng, n: Nat, acc: List<&2, T>, hr: T & Rand.Rng) -> List<&2, T> & Rand.Rng:
  match n:
    case 0n:
      (h, r) = hr
      (h <> acc, r)
    case 1n+p:
      (h, r) = hr
      list.go(~T, ~gen, p, h <> acc, gen(r))

# Exactly n items from gen. The first draw ends up last; replay is unaffected.
def list.of(~T: Data, ~gen: Rand.Rng -> T & Rand.Rng, n: Nat, r: Rand.Rng) -> List<&2, T> & Rand.Rng:
  match n:
    case 0n:
      (Nil{}, r)
    case 1n+p:
      list.go(~T, ~gen, p, Nil{}, gen(r))

def list.fin(~T: Data, ~gen: Rand.Rng -> T & Rand.Rng, nr: Nat & Rand.Rng) -> List<&2, T> & Rand.Rng:
  (n, r) = nr
  list.of(~T, ~gen, n, r)

# Items from gen, length in [0, min(max, 1024)].
def list(~T: Data, ~gen: Rand.Rng -> T & Rand.Rng, +max: U32, r: Rand.Rng) -> List<&2, T> & Rand.Rng:
  list.fin(~T, ~gen, nat(max, r))

def maybe.some(~T: Data, hr: T & Rand.Rng) -> Maybe<&2, T> & Rand.Rng:
  (h, r) = hr
  (Some{h}, r)

def maybe.if(~T: Data, ~gen: Rand.Rng -> T & Rand.Rng, none: Bool, r: Rand.Rng) -> Maybe<&2, T> & Rand.Rng:
  match none:
    case True{}:
      (None{}, r)
    case False{}:
      maybe.some(~T, gen(r))

def maybe.pick(~T: Data, ~gen: Rand.Rng -> T & Rand.Rng, xr: U32 & Rand.Rng) -> Maybe<&2, T> & Rand.Rng:
  (+x, r) = xr
  maybe.if(~T, ~gen, U32.is_eq(x, 0), r)

# None one time in four, else Some from gen.
def maybe(~T: Data, ~gen: Rand.Rng -> T & Rand.Rng, r: Rand.Rng) -> Maybe<&2, T> & Rand.Rng:
  maybe.pick(~T, ~gen, Rand.below(4, r))

def map.fin(~A: Type, ~B: Type, ~f: A -> B, ar: A & Rand.Rng) -> B & Rand.Rng:
  (a, r) = ar
  (f(a), r)

# gen's value through f.
def map(~A: Type, ~B: Type, ~f: A -> B, ~gen: Rand.Rng -> A & Rand.Rng, r: Rand.Rng) -> B & Rand.Rng:
  map.fin(~A, ~B, ~f, gen(r))

def bind.fin(~A: Type, ~B: Type, ~k: A -> Rand.Rng -> B & Rand.Rng, ar: A & Rand.Rng) -> B & Rand.Rng:
  (a, r) = ar
  k(a, r)

# gen's value picks the next generator: bind(~Nat, ~List<&2, U32>, ~(r => Gen.nat(8, r)), ~(n => r => Gen.list.of(~U32, ~Gen.u32, n, r)), r).
def bind(~A: Type, ~B: Type, ~gen: Rand.Rng -> A & Rand.Rng, ~k: A -> Rand.Rng -> B & Rand.Rng, r: Rand.Rng) -> B & Rand.Rng:
  bind.fin(~A, ~B, ~k, gen(r))

def pair.snd(~A: Type, ~B: Type, a: A, br: B & Rand.Rng) -> (A & B) & Rand.Rng:
  (b, r) = br
  ((a, b), r)

def pair.fst(~A: Type, ~B: Type, ~gb: Rand.Rng -> B & Rand.Rng, ar: A & Rand.Rng) -> (A & B) & Rand.Rng:
  (a, r) = ar
  pair.snd(~A, ~B, a, gb(r))

# ga's value then gb's, drawn in that order.
def pair(~A: Type, ~B: Type, ~ga: Rand.Rng -> A & Rand.Rng, ~gb: Rand.Rng -> B & Rand.Rng, r: Rand.Rng) -> (A & B) & Rand.Rng:
  pair.fst(~A, ~B, ~gb, ga(r))
