# Seeded pseudo-random numbers: xoshiro128**, unbiased ranges, floats and shuffles. Not for cryptography.
import Base

# A pure generator: each draw returns the value beside the next state.
#   import ./random/random.bend as Rand
#   (x, r) = Rand.next(Rand.seed(42))

# xoshiro128** state (https://prng.di.unimi.it/xoshiro128starstar.c). It is never all zero.
type Rng is Data:
  Rng{a: U32, b: U32, c: U32, d: U32}

def rotl(+x: U32, l: Nat, r: Nat) -> U32:
  ((x << l) .|. (x >> r) : U32)

# splitmix32's output mixer, a bijection on U32.
def mix(+z: U32) -> U32:
  +y = ((z .^. (z >> 16n)) * 569420461 : U32)
  +w = ((y .^. (y >> 15n)) * 1935289751 : U32)
  (w .^. (w >> 15n) : U32)

# The first four splitmix32 outputs from s. Distinct seeds give distinct states.
def seed(+s: U32) -> Rng:
  Rng{mix((s + 2654435769 : U32)), mix((s + 1013904242 : U32)),
    mix((s + 3668340011 : U32)), mix((s + 2027808484 : U32))}

def from_state.if(zero: Bool, a: U32, b: U32, c: U32, d: U32) -> Rng:
  match zero:
    case True{}:
      seed(0)
    case False{}:
      Rng{a, b, c, d}

# The state (a, b, c, d) as is, to replay a reference stream. All zero gives seed(0).
def from_state(+a: U32, +b: U32, +c: U32, +d: U32) -> Rng:
  from_state.if(U32.is_zero((a .|. b .|. c .|. d : U32)), a, b, c, d)

# One xoshiro128** step: a uniform U32 and the next state.
def next(r: Rng) -> U32 & Rng:
  match r:
    case Rng{+a, +b, +c, +d}:
      +c1 = (c .^. a : U32)
      +d1 = (d .^. b : U32)
      ((rotl((b * 5 : U32), 7n, 25n) * 9 : U32),
        Rng{(a .^. d1 : U32), (b .^. c1 : U32), (c1 .^. (b << 9n) : U32),
          rotl(d1, 11n, 21n)})

def Bool.case(-A: Type, b: Bool, t: Unit -> A, f: Unit -> A) -> A:
  match b:
    case True{}:
      t(Unit{})
    case False{}:
      f(Unit{})

# Rejects draws below t = 2^32 mod n, as OpenBSD's arc4random_uniform does.
def below.go(fuel: Nat, +n: U32, +t: U32, xr: U32 & Rng) -> U32 & Rng:
  match fuel:
    case 0n:
      (x, r) = xr
      ((x % n : U32), r)
    case 1n+p:
      (+x, +r) = xr
      Bool.case(U32 & Rng, U32.is_ge(x, t),
        u => ((x % n : U32), r),
        u => below.go(p, n, t, next(r)))

def below.if(small: Bool, +n: U32, r: Rng) -> U32 & Rng:
  match small:
    case True{}:
      (0, r)
    case False{}:
      below.go(64n, n, ((0 - n : U32) % n : U32), next(r))

# A uniform U32 in [0, n). Each draw is rejected with odds under 1/2, so after
# 64 rejections, odds 2^-64, it takes x mod n. For n < 2 it is 0 and r is unchanged.
def below(+n: U32, r: Rng) -> U32 & Rng:
  below.if(U32.is_lt(n, 2), n, r)

def range.fin(lo: U32, xr: U32 & Rng) -> U32 & Rng:
  (x, r) = xr
  ((lo + x : U32), r)

# A uniform U32 in [lo, hi). For hi <= lo + 1 it is lo and r is unchanged.
def range(+lo: U32, hi: U32, r: Rng) -> U32 & Rng:
  range.fin(lo, below((hi - lo : U32), r))

def unit.fin(xr: U32 & Rng) -> F32 & Rng:
  (x, r) = xr
  (F32.div(U32.to_f32((x >> 8n : U32)), 16777216.0), r)

# A uniform F32 in [0, 1), from the draw's top 24 bits.
def unit(r: Rng) -> F32 & Rng:
  unit.fin(next(r))

def shuffle.fill(~T: Data, xs: List<&2, T>, +i: U32, a: Array<T>) -> Array<T>:
  match xs:
    case Nil{}:
      a
    case Con{h, t}:
      shuffle.fill(~T, t, (i + 1 : U32), Array.set(T, a, i, h))

def shuffle.swap.set(~T: Data, +i: U32, +j: U32, xi: T, ax: Array<T> & T) -> Array<T>:
  (a, xj) = ax
  Array.set(T, Array.set(T, a, i, xj), j, xi)

def shuffle.swap(~T: Data, +i: U32, +j: U32, ax: Array<T> & T) -> Array<T>:
  (a, xi) = ax
  shuffle.swap.set(~T, i, j, xi, Array.get(T, a, j))

# Fisher-Yates: at slot i, jr is below(i + 1); slot i swaps with slot j.
# At k = 0, i is 0 and below(1) drew nothing.
def shuffle.go(~T: Data, k: Nat, +i: U32, a: Array<T>, jr: U32 & Rng) -> Array<T> & Rng:
  match k:
    case 0n:
      (j, r) = jr
      (a, r)
    case 1n+p:
      (+j, r) = jr
      shuffle.go(~T, p, (i - 1 : U32), shuffle.swap(~T, i, j, Array.get(T, a, i)),
        below(i, r))

# Slots [0, k] of the array, with ax the read of slot k, prepended to acc.
def shuffle.read(~T: Data, k: Nat, ax: Array<T> & T, acc: List<&2, T>) -> List<&2, T>:
  match k:
    case 0n:
      (a, x) = ax
      x <> acc
    case 1n+(+p):
      (a, x) = ax
      shuffle.read(~T, p, Array.get(T, a, U32.from_nat(p)), x <> acc)

def shuffle.fin(~T: Data, +m: U32, ar: Array<T> & Rng) -> List<&2, T> & Rng:
  (a, r) = ar
  (shuffle.read(~T, U32.to_nat(m), Array.get(T, a, m), Nil{}), r)

def shuffle.run(~T: Data, +h: T, +xs: List<&2, T>, r: Rng) -> List<&2, T> & Rng:
  +m = (U32.from_nat(List.length(&2, T, xs)) - 1 : U32)
  shuffle.fin(~T, m,
    shuffle.go(~T, U32.to_nat(m), m,
      shuffle.fill(~T, xs, 0, Array.new(T, Nat.add(1n, U32.log2(m)), h)),
      below((m + 1 : U32), r)))

# A uniform permutation of xs. Every draw is below(i + 1), so a list of n
# items uses n - 1 draws.
def shuffle(~T: Data, xs: List<&2, T>, r: Rng) -> List<&2, T> & Rng:
  match xs:
    case Nil{}:
      (Nil{}, r)
    case Con{+h, t}:
      shuffle.run(~T, h, h <> t, r)

# 16 bytes from the OS (getentropy, or crypto.getRandomValues in JS).
def entropy() -> IO(Result<&1, &1, U32 & String, U32 & U32 & U32 & U32>):
  import "./effs/random.c"
  import "./effs/random.js"

def from_os.fin(e: Result<&1, &1, U32 & String, U32 & U32 & U32 & U32>) ->
  Result<&1, &1, U32 & String, Rng>:
  match e:
    case Fail{err}:
      Fail{err}
    case Done{(a, b, c, d)}:
      Done{from_state(a, b, c, d)}

# A generator seeded from OS entropy, for when runs need not repeat.
def from_os() -> IO(Result<&1, &1, U32 & String, Rng>):
  do IO<Result<&1, &1, U32 & String, Rng>>:
    e : Result<&1, &1, U32 & String, U32 & U32 & U32 & U32> <- entropy()
    return from_os.fin(e)
