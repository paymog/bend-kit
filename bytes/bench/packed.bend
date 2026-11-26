# Bytes benchmark: a packed Array<U32> byte buffer (see README.md).
import Base
import ../bytes.bend as Bytes
import ./batch.bend as Batch

# Bytes as Array<U32>, 4 bytes per slot, little-endian: byte i = (w[i/4] >> 8*(i%4)) & 255.
# L = 28: N = 2^28 bytes, 2^26 words.

type Config is Data:
  Config{lg: Nat, n: U32, reads: Nat, build1: U32, build2: U32}

def config(args: List<&1, String>) -> Config:
  match args:
    case program <> l <> r <> b1 <> b2 <> Nil{}:
      +lg = U32.to_nat(Maybe.default(&2, U32, U32.read(l), 28))
      Config{lg, U32.shln(1, lg),
        U32.to_nat(Maybe.default(&2, U32, U32.read(r), 16777216)),
        Maybe.default(&2, U32, U32.read(b1), 1000000),
        Maybe.default(&2, U32, U32.read(b2), 4000000)}
    case _:
      Config{28n, 268435456, 16777216n, 1000000, 4000000}

def lg(c: Config) -> Nat:
  match c:
    case Config{l, n, r, b1, b2}:
      l

def n(c: Config) -> U32:
  match c:
    case Config{l, n, r, b1, b2}:
      n

def reads(c: Config) -> Nat:
  match c:
    case Config{l, n, r, b1, b2}:
      r

def build1(c: Config) -> U32:
  match c:
    case Config{l, n, r, b1, b2}:
      b1

def build2(c: Config) -> U32:
  match c:
    case Config{l, n, r, b1, b2}:
      b2

def b8(+x: U32) -> U32:
  (x .&. 255 : U32)

def unpack(+w: U32) -> U32:
  (b8(w) + b8((w >> 8n : U32)) + b8((w >> 16n : U32)) + (w >> 24n : U32) : U32)

def packw(+t: U32) -> U32:
  (b8(t) .|. (b8((t + 31 : U32)) << 8n) .|. (b8((t + 62 : U32)) << 16n) .|. (b8((t + 93 : U32)) << 24n) : U32)

def byte.of(+sh: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (b, w) = r
  (b, b8(U32.shrn(w, U32.to_nat(sh))))

# The Bytes read API: one byte at index i.
def byte(a: Array<U32>, +i: U32) -> Array<U32> & U32:
  byte.of(((i .&. 3 : U32) * 8 : U32), Array.get(U32, a, (i >> 2n : U32)))

def add2.of(+x: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (b, y) = r
  (b, (x + y : U32))

def add2(r: Array<U32> & U32, +j: U32) -> Array<U32> & U32:
  (b, x) = r
  add2.of(x, byte(b, j))

# fill
def fill(n: Nat, a: Array<U32>, +j: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill(p, Array.set(U32, a, j, packw((j * 124 + 7 : U32))), (j + 1 : U32))

def fill.all(+cfg: Config) -> Array<U32>:
  Array.set(U32, fill(U32.to_nat((n(cfg) / 4 : U32)), Array.new(U32, Nat.sub(lg(cfg), 2n), 0), 0), (n(cfg) / 4 - 1 : U32), 168626701)

# sum, word at a time
def sum.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      (b, acc)
    case 1n+p:
      (b, +v) = r
      sum.go(p, Array.get(U32, b, (i + 1 : U32)), (i + 1 : U32), (acc + unpack(v) : U32))

# sum through byte(): what a caller of a Bytes.get API pays
def sumb.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      (b, acc)
    case 1n+p:
      (b, +v) = r
      sumb.go(p, byte(b, (i + 1 : U32)), (i + 1 : U32), (acc + v : U32))

# find \r\n\r\n with a 4-byte shift window; pattern is at the end, so no early exit is needed
def find.b(st: U32 & U32, +c: U32, +idx: U32) -> U32 & U32:
  (win, +res) = st
  +w2 = ((win << 8n) .|. c : U32)
  (w2, Bool.pick(U32, Bool.and(U32.is_eq(w2, 218762506), U32.is_eq(res, 4294967295)), (idx - 3 : U32), res))

def find.w(st: U32 & U32, +w: U32, +base: U32) -> U32 & U32:
  find.b(find.b(find.b(find.b(st, b8(w), base), b8((w >> 8n : U32)), (base + 1 : U32)), b8((w >> 16n : U32)), (base + 2 : U32)), (w >> 24n : U32), (base + 3 : U32))

def find.fin(b: Array<U32>, st: U32 & U32) -> Array<U32> & U32:
  (win, res) = st
  (b, res)

def find.go(n: Nat, r: Array<U32> & U32, st: U32 & U32, +i: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      find.fin(b, st)
    case 1n+p:
      (b, +v) = r
      find.go(p, Array.get(U32, b, (i + 1 : U32)), find.w(st, v, (i * 4 : U32)), (i + 1 : U32))

# find, SWAR: a word with no 13 byte holds no byte of a match, so skip it and reset the window
def has13(+w: U32) -> Bool:
  +v = (w .^. 218959117 : U32)
  U32.is_ne(((v - 16843009 : U32) .&. (v .^. 4294967295 : U32) .&. 2155905152 : U32), 0)

def findw.step(hit: Bool, st: U32 & U32, +w: U32, +base: U32) -> U32 & U32:
  match hit:
    case True{}:
      find.w(st, w, base)
    case False{}:
      (win, res) = st
      (0, res)

def findw.go(n: Nat, r: Array<U32> & U32, st: U32 & U32, +i: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      find.fin(b, st)
    case 1n+p:
      (b, +v) = r
      findw.go(p, Array.get(U32, b, (i + 1 : U32)), findw.step(has13(v), st, v, (i * 4 : U32)), (i + 1 : U32))

# slice bytes [N/4+1, N/4+1+N/2): unaligned, so each out word joins two source words
def slice.go(n: Nat, r: Array<U32> & U32, +prev: U32, out: Array<U32>, +j: U32, +k: U32) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      (b, w) = r
      (b, out)
    case 1n+p:
      (b, +w) = r
      slice.go(p, Array.get(U32, b, (k + 1 : U32)), w, Array.set(U32, out, j, ((prev >> 8n) .|. (w << 24n) : U32)), (j + 1 : U32), (k + 1 : U32))

def slice.start(+cfg: Config, r: Array<U32> & U32) -> Array<U32> & Array<U32>:
  (b, w0) = r
  slice.go(U32.to_nat((n(cfg) / 8 : U32)), Array.get(U32, b, (n(cfg) / 16 + 1 : U32)), w0, Array.new(U32, Nat.sub(lg(cfg), 3n), 0), 0, (n(cfg) / 16 + 1 : U32))

# concat: fresh chunks of min(N, 64 KiB), kept in a list, flattened once
def fillc(n: Nat, a: Array<U32>, +j: U32, +w: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fillc(p, Array.set(U32, a, j, w), (j + 1 : U32), w)

def chunk(+depth: Nat, +k: U32) -> Array<U32>:
  fillc(U32.to_nat(U32.shln(1, depth)), Array.new(U32, depth, 0), 0, (b8(k) * 16843009 : U32))

def collect(n: Nat, +depth: Nat, +k: U32, acc: List<Array<U32>>) -> List<Array<U32>>:
  match n:
    case 0n:
      acc
    case 1n+p:
      collect(p, depth, (k + 1 : U32), Con{chunk(depth, k), acc})

def copyc(n: Nat, r: Array<U32> & U32, out: Array<U32>, +j: U32, +off: U32) -> Array<U32>:
  match n:
    case 0n:
      out
    case 1n+p:
      (c, w) = r
      copyc(p, Array.get(U32, c, (j + 1 : U32)), Array.set(U32, out, (off + j : U32), w), (j + 1 : U32), off)

def flatten(xs: List<Array<U32>>, +words: U32, out: Array<U32>, +off: U32) -> Array<U32>:
  match xs:
    case Nil{}:
      out
    case Con{c, t}:
      flatten(t, words, copyc(U32.to_nat(words), Array.get(U32, c, 0), out, 0, off), (off - words : U32))

def concat(+cfg: Config) -> Array<U32>:
  +depth = Nat.min(Nat.sub(lg(cfg), 2n), 14n)
  +words = U32.shln(1, depth)
  flatten(collect(U32.to_nat((n(cfg) / 4 / words : U32)), depth, 0, Nil{}), words, Array.new(U32, Nat.sub(lg(cfg), 2n), 0), (n(cfg) / 4 - words : U32))

# random reads through byte()
def rnd.go(n: Nat, +shift: Nat, r: Array<U32> & U32, +x: U32, acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      (b, (acc + v : U32))
    case 1n+p:
      (b, v) = r
      +x2 = (x * 1664525 + 1013904223 : U32)
      rnd.go(p, shift, byte(b, U32.shrn(x2, shift)), x2, (acc + v : U32))

# equal, word at a time
def eq.fin(r1: Array<U32> & U32, r2: Array<U32> & U32, ok: Bool) -> Array<U32> & (Array<U32> & U32):
  (a, x) = r1
  (c, y) = r2
  (a, (c, Bool.pick(U32, Bool.and(ok, U32.is_eq(x, y)), 1, 0)))

def eq.go(n: Nat, r1: Array<U32> & U32, r2: Array<U32> & U32, +i: U32, ok: Bool) -> Array<U32> & (Array<U32> & U32):
  match n:
    case 0n:
      eq.fin(r1, r2, ok)
    case 1n+p:
      (a, +x) = r1
      (c, +y) = r2
      eq.go(p, Array.get(U32, a, (i + 1 : U32)), Array.get(U32, c, (i + 1 : U32)), (i + 1 : U32), Bool.and(ok, U32.is_eq(x, y)))

def eq.start(+cfg: Config, ac: Array<U32> & Array<U32>) -> Array<U32> & (Array<U32> & U32):
  (a, c) = ac
  eq.go(U32.to_nat((n(cfg) / 4 : U32)), (a, 0), (c, 0), 4294967295, True{})

def build.go(n: Nat, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      build.go(p, Bytes.append(b, Bytes.set(Bytes.new(1), 0, (i .&. 255 : U32))), (i + 1 : U32))

def build.check(r: Bytes.Bytes & Maybe<&2, U32>, +n: U32) -> U32:
  (b, v) = r
  match v:
    case Some{x}:
      (n + x : U32)
    case None{}:
      0

def step.build(+n: U32) -> U32 & U32:
  (n, build.check(Bytes.get(build.go(U32.to_nat(n), Bytes.new(0), 0), (n - 1 : U32)), n))

def step.fill(+cfg: Config, old: Array<U32>) -> Array<U32> & U32:
  add2(byte(fill.all(cfg), (12345 % n(cfg) : U32)), (n(cfg) - 1 : U32))

def step.sum(+cfg: Config, a: Array<U32>) -> Array<U32> & U32:
  sum.go(U32.to_nat((n(cfg) / 4 : U32)), Array.get(U32, a, 0), 0, 0)

def step.sumb(+cfg: Config, a: Array<U32>) -> Array<U32> & U32:
  sumb.go(U32.to_nat(n(cfg)), byte(a, 0), 0, 0)

def step.find(+cfg: Config, a: Array<U32>) -> Array<U32> & U32:
  find.go(U32.to_nat((n(cfg) / 4 : U32)), Array.get(U32, a, 0), (0, 4294967295), 0)

def step.findw(+cfg: Config, a: Array<U32>) -> Array<U32> & U32:
  findw.go(U32.to_nat((n(cfg) / 4 : U32)), Array.get(U32, a, 0), (0, 4294967295), 0)
def keep(a: Array<U32>, r: Array<U32> & U32) -> Array<U32> & U32:
  (out, value) = r
  (a, value)

def step.slice.done(+cfg: Config, r: Array<U32> & Array<U32>) -> Array<U32> & U32:
  (a, s) = r
  keep(a, add2(byte(s, 0), (n(cfg) / 2 - 1 : U32)))

def step.slice(+cfg: Config, a: Array<U32>) -> Array<U32> & U32:
  step.slice.done(cfg, slice.start(cfg, Array.get(U32, a, (n(cfg) / 16 : U32))))

def step.concat(+cfg: Config, a: Array<U32>) -> Array<U32> & U32:
  keep(a, add2(byte(concat(cfg), 0), (n(cfg) - 1 : U32)))

def step.random(+cfg: Config, a: Array<U32>) -> Array<U32> & U32:
  rnd.go(reads(cfg), Nat.sub(32n, lg(cfg)), (a, 0), 1, 0)

def run.array.done(cfg: Config, r: Array<U32> & U32) -> (Config & Array<U32>) & U32:
  (out, value) = r
  ((cfg, out), value)

def run.array(~step: Config -> Array<U32> -> Array<U32> & U32, state: Config & Array<U32>) -> (Config & Array<U32>) & U32:
  (+cfg, a) = state
  run.array.done(cfg, step(cfg, a))

def run.equal.done(cfg: Config, r: Array<U32> & (Array<U32> & U32)) -> (Config & (Array<U32> & Array<U32>)) & U32:
  (a, (c, value)) = r
  ((cfg, (a, c)), value)

def run.equal(state: Config & (Array<U32> & Array<U32>)) -> (Config & (Array<U32> & Array<U32>)) & U32:
  (+cfg, ac) = state
  run.equal.done(cfg, eq.start(cfg, ac))

def finish(+cfg: Config, ac: Array<U32> & Array<U32>) -> IO(Unit):
  do IO<Unit>:
    unused : Config & (Array<U32> & Array<U32>) <- Batch.run(~(Config & (Array<U32> & Array<U32>)), ~run.equal, "equal", (cfg, ac))
    b1 : U32 <- Batch.run(~U32, ~(n => step.build(n)), "build_" ++ U32.show(build1(cfg)), build1(cfg))
    b2 : U32 <- Batch.run(~U32, ~(n => step.build(n)), "build_" ++ U32.show(build2(cfg)), build2(cfg))
    return Unit{}

def finish.state(state: Config & Array<U32>) -> IO(Unit):
  (cfg, a) = state
  finish(cfg, Array.clone(U32, a))

def start(+cfg: Config) -> IO(Unit):
  do IO<Unit>:
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.fill(cfg, a))), "fill", (cfg, Array.new(U32, 0n, 0)))
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.sum(cfg, a))), "sum", state)
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.sumb(cfg, a))), "sum_bytewise", state)
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.sum(cfg, a))), "sum_again", state)
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.find(cfg, a))), "find", state)
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.findw(cfg, a))), "find_swar", state)
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.slice(cfg, a))), "slice", state)
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.concat(cfg, a))), "concat", state)
    state : Config & Array<U32> <- Batch.run(~(Config & Array<U32>), ~run.array(~(cfg => a => step.random(cfg, a))), "random", state)
    finish.state(state)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    start(config(args))
