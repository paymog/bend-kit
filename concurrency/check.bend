import Base
import ./concurrency.bend as Conc

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

# CPU-bound work: n rounds of x = (x ^ x >> 13) * 1664525 + 1013904223, in wrapping u32.
def spin(n: Nat, +x: U32) -> U32:
  match n:
    case 0n:
      x
    case 1n+p:
      spin(p, ((x .^. (x >> 13n)) * 1664525 + 1013904223 : U32))

def job(x: U32) -> U32:
  spin(131072n, x)

def upto(n: Nat, acc: List<U32>) -> List<U32>:
  match n:
    case 0n:
      acc
    case 1n+(+p):
      upto(p, U32.from_nat(p) <> acc)

def hash(xs: List<U32>, h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case x <> t:
      hash(t, (h * 31 + x : U32))

def elapsed(t0: Nat, h: U32) -> IO(Nat & U32):
  do IO<Nat & U32>:
    t1 : Nat <- IO.now()
    return ((t1 - t0 : Nat), h)

# The same 64 jobs on w workers: the time in ms and a checksum of the results in order.
def speed.run(+w: U32) -> IO(Nat & U32):
  do IO<Nat & U32>:
    t0 : Nat <- IO.now()
    elapsed(t0, hash(Conc.par_map(~U32, ~U32, ~job, w, upto(64n, Nil{})), 0))

def speed.check(+threads: U32, one: Nat & U32, eight: Nat & U32) -> IO(Unit):
  (+t1, +h1) = one
  (+t8, +h8) = eight
  do IO<Unit>:
    IO.print("par_map: 1 worker " ++ Nat.show(t1) ++ " ms, 8 workers " ++ Nat.show(t8) ++ " ms, " ++ U32.show(threads) ++ " threads")
    require(U32.is_eq(h1, 3482193357), "par_map on 1 worker gave checksum " ++ U32.show(h1))
    require(U32.is_eq(h8, h1), "par_map on 8 workers gave checksum " ++ U32.show(h8))

def slow(ms: U32, +v: U32) -> IO(U32):
  do IO<U32>:
    IO.sleep(ms)
    return v

def timeouts.fired(+dt: Nat, m: Maybe<&1, U32>) -> IO(Unit):
  match m:
    case Some{v}:
      IO.die(Unit, 1, "timeout did not fire; the action answered " ++ U32.show(v))
    case None{}:
      do IO<Unit>:
        IO.print("timeout: deadline after " ++ Nat.show(dt) ++ " ms")

def timeouts.kept(m: Maybe<&1, U32>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "timeout fired before a quick action")
    case Some{+v}:
      require(U32.is_eq(v, 5), "timeout changed the result")

def timeouts.late(t0: Nat, m: Maybe<&1, U32>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    timeouts.fired((t1 - t0 : Nat), m)

def timeouts() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    missed : Maybe<&1, U32> <- Conc.timeout(U32, 50, slow(600, 1))
    timeouts.late(t0, missed)
    quick : Maybe<&1, U32> <- Conc.timeout(U32, 200, IO.pure(U32, 5))
    timeouts.kept(quick)

# Sends v on c after ms, then closes c.
def later(ms: U32, +v: U32, +c: Chan(U32)) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(ms)
    sent : Result<&1, &1, U32, Unit> <- Chan.send(U32, c, v)
    Chan.close(U32, c)

def picked(m: Maybe<&1, U32 & U32>, +i: U32, +v: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{(j, x)}:
      U32.is_eq(i, j) && U32.is_eq(v, x)

def ended(m: Maybe<&1, U32 & U32>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{p}:
      False{}

def selects.go(+a: Chan(U32), +b: Chan(U32)) -> IO(Unit):
  do IO<Unit>:
    IO.spawn(Unit, later(80, 7, a))
    IO.spawn(Unit, later(10, 9, b))
    sel : Chan(U32 & U32) <- Conc.select(U32, [a, b])
    +s : Chan(U32 & U32) = sel
    first : Maybe<&1, U32 & U32> <- Chan.recv(U32 & U32, s)
    second : Maybe<&1, U32 & U32> <- Chan.recv(U32 & U32, s)
    third : Maybe<&1, U32 & U32> <- Chan.recv(U32 & U32, s)
    require(picked(first, 1, 9), "select did not answer the first ready channel")
    require(picked(second, 0, 7), "select lost the slower channel")
    require(ended(third), "select did not close after its sources")

def selects() -> IO(Unit):
  do IO<Unit>:
    a : Chan(U32) <- Chan.new(U32, 0)
    b : Chan(U32) <- Chan.new(U32, 0)
    selects.go(a, b)

# A worker counts its jobs in its state; a job sleeps ms and answers 2 * ms.
def pool.job(s: U32, ms: U32) -> IO(U32 & U32):
  +ms = ms
  do IO<U32 & U32>:
    IO.sleep(ms)
    return ((s + 1 : U32), (ms * 2 : U32))

def same(xs: List<U32>, ys: List<U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      U32.is_eq(x, y) && same(xt, yt)
    case _ _:
      False{}

def sum(xs: List<U32>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      sum(t, (acc + x : U32))

def pools.check(+dt: Nat, r: List<U32> & List<U32>) -> IO(Unit):
  (states, outs) = r
  do IO<Unit>:
    IO.print("pool: 8 jobs of 400 ms total on 4 workers in " ++ Nat.show(dt) ++ " ms")
    require(same(outs, [200, 60, 120, 20, 200, 60, 120, 20]), "pool results are out of order")
    require(U32.is_eq(sum(states, 0), 8), "pool workers did not run every job once")

def pools.timed(t0: Nat, r: List<U32> & List<U32>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    pools.check((t1 - t0 : Nat), r)

def pools() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    r : List<U32> & List<U32> <- Conc.pool(~U32, ~U32, ~U32, ~pool.job, [0, 0, 0, 0], [100, 30, 60, 10, 100, 30, 60, 10])
    pools.timed(t0, r)

def main() -> IO(Unit):
  do IO<Unit>:
    threads : U32 <- IO.thread_count()
    one : Nat & U32 <- speed.run(1)
    eight : Nat & U32 <- speed.run(8)
    speed.check(threads, one, eight)
    timeouts()
    selects()
    pools()
    IO.print("concurrency ok")
