# Parallel map and reduce over lists and arrays, a worker pool, select over channels, and timeouts.
import Base

#   import bend-kit-concurrency@0.1.0.0/concurrency.bend as Conc
#   ys = Conc.par_map(~U32, ~U32, ~work, 8, xs)
#
# par_map and par_reduce are pure. They split the input into at most `workers`
# balanced parts (rounded down to a power of two) and run the parts as parallel
# calls, so a native build spreads them over its `--threads`. Results keep the
# input order. par_reduce needs an associative f; the list form also needs z to
# be f's identity, since each part starts from z.
#
# pool, select, and timeout are IO, on Base's Chan, IO.spawn and IO.fork. Base
# has no cancellation: an abandoned computation keeps running, and the program
# exits only when every computation is done.

# The length of xs, beside xs.
def count.cons(-A: Type, h: A, r: Nat & List<A>) -> Nat & List<A>:
  (n, t) = r
  (1n+n, h <> t)

def count(-A: Type, xs: List<A>) -> Nat & List<A>:
  match xs:
    case Nil{}:
      (0n, Nil{})
    case h <> t:
      count.cons(A, h, count(A, t))

# The first n elements of xs, and the rest.
def split.cons(-A: Type, h: A, r: List<A> & List<A>) -> List<A> & List<A>:
  (l, rest) = r
  (h <> l, rest)

def split(-A: Type, xs: List<A>, n: Nat) -> List<A> & List<A>:
  match xs n:
    case Nil{} _:
      (Nil{}, Nil{})
    case h <> t 0n:
      (Nil{}, h <> t)
    case h <> t 1n+p:
      split.cons(A, h, split(A, t, p))

# lr holds two halves of nl and nr elements. Depth d runs 2^(d+1) parallel parts.
def par_map.list.go(
  ~A: Type, ~B: Type, ~f: A -> B, d: Nat, +nl: Nat, +nr: Nat, lr: List<A> & List<A>
) -> List<B>:
  match d:
    case 0n:
      (l, r) = lr
      lo hi = List.map(~A, ~B, ~f, l) List.map(~A, ~B, ~f, r)
      List.append(&1, B, lo, hi)
    case 1n+ +p:
      (l, r) = lr
      +hl = Nat.div(nl, 2n)
      +hr = Nat.div(nr, 2n)
      ls = split(A, l, hl)
      rs = split(A, r, hr)
      lo hi = par_map.list.go(~A, ~B, ~f, p, hl, Nat.sub(nl, hl), ls) par_map.list.go(~A, ~B, ~f, p, hr, Nat.sub(nr, hr), rs)
      List.append(&1, B, lo, hi)

def par_map.list.top(~A: Type, ~B: Type, ~f: A -> B, d: Nat, nx: Nat & List<A>) -> List<B>:
  match d:
    case 0n:
      (n, xs) = nx
      List.map(~A, ~B, ~f, xs)
    case 1n+p:
      (+n, xs) = nx
      +h = Nat.div(n, 2n)
      par_map.list.go(~A, ~B, ~f, p, h, Nat.sub(n, h), split(A, xs, h))

# List.map(f, xs), on at most `workers` parallel parts.
def par_map(~A: Type, ~B: Type, ~f: A -> B, workers: U32, xs: List<A>) -> List<B>:
  par_map.list.top(~A, ~B, ~f, U32.log2(workers), count(A, xs))

def fold(~A: Data, ~f: A -> A -> A, xs: List<A>, acc: A) -> A:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      fold(~A, ~f, t, f(acc, h))

def par_reduce.list.go(
  ~A: Data, ~f: A -> A -> A, d: Nat, +nl: Nat, +nr: Nat, +z: A, lr: List<A> & List<A>
) -> A:
  match d:
    case 0n:
      (l, r) = lr
      lo hi = fold(~A, ~f, l, z) fold(~A, ~f, r, z)
      f(lo, hi)
    case 1n+ +p:
      (l, r) = lr
      +hl = Nat.div(nl, 2n)
      +hr = Nat.div(nr, 2n)
      ls = split(A, l, hl)
      rs = split(A, r, hr)
      lo hi = par_reduce.list.go(~A, ~f, p, hl, Nat.sub(nl, hl), z, ls) par_reduce.list.go(~A, ~f, p, hr, Nat.sub(nr, hr), z, rs)
      f(lo, hi)

def par_reduce.list.top(~A: Data, ~f: A -> A -> A, d: Nat, +z: A, nx: Nat & List<A>) -> A:
  match d:
    case 0n:
      (n, xs) = nx
      fold(~A, ~f, xs, z)
    case 1n+p:
      (+n, xs) = nx
      +h = Nat.div(n, 2n)
      par_reduce.list.go(~A, ~f, p, h, Nat.sub(n, h), z, split(A, xs, h))

# The left fold of xs from z, on at most `workers` parallel parts. f must be
# associative and z its identity.
def par_reduce(~A: Data, ~f: A -> A -> A, workers: U32, +z: A, xs: List<A>) -> A:
  par_reduce.list.top(~A, ~f, U32.log2(workers), z, count(A, xs))

# An Array is a balanced tree, so each ANode above depth d is a parallel call.
def par_map.array.go(~A: Type, ~B: Type, ~f: A -> B, a: Array<A>, d: Nat) -> Array<B>:
  match a d:
    case ALeaf{x} _:
      ALeaf{f(x)}
    case ANode{xs, ys} 0n:
      ANode{par_map.array.go(~A, ~B, ~f, xs, 0n), par_map.array.go(~A, ~B, ~f, ys, 0n)}
    case ANode{xs, ys} 1n+ +p:
      lo hi = par_map.array.go(~A, ~B, ~f, xs, p) par_map.array.go(~A, ~B, ~f, ys, p)
      ANode{lo, hi}

# f on every slot of a, on at most `workers` parallel parts. Slots keep their index.
def par_map.array(~A: Type, ~B: Type, ~f: A -> B, workers: U32, a: Array<A>) -> Array<B>:
  par_map.array.go(~A, ~B, ~f, a, U32.log2(workers))

def par_reduce.array.go(~A: Type, ~f: A -> A -> A, a: Array<A>, d: Nat) -> A:
  match a d:
    case ALeaf{x} _:
      x
    case ANode{xs, ys} 0n:
      f(par_reduce.array.go(~A, ~f, xs, 0n), par_reduce.array.go(~A, ~f, ys, 0n))
    case ANode{xs, ys} 1n+ +p:
      lo hi = par_reduce.array.go(~A, ~f, xs, p) par_reduce.array.go(~A, ~f, ys, p)
      f(lo, hi)

# The slots of a combined in index order with an associative f, on at most
# `workers` parallel parts. An Array is never empty, so no identity is needed.
def par_reduce.array(~A: Type, ~f: A -> A -> A, workers: U32, a: Array<A>) -> A:
  par_reduce.array.go(~A, ~f, a, U32.log2(workers))

# A pool worker between channel steps. It owns its state s alone.
type Worker<-S: Type, -A: Type, -B: Type> is Type:
  WIdle{s: S}
  WGot{s: S, got: Maybe<&1, A & Chan(B)>}
  WDone{sb: S & B, reply: Chan(B)}

# Takes jobs until the queue is closed and empty, then answers its state.
# Each job takes three steps, so 3 * (jobs + 1) fuel is enough.
def pool.worker(
  ~S: Type, ~A: Type, ~B: Type, ~work: S -> A -> IO(S & B), fuel: Nat,
  +q: Chan(A & Chan(B)), w: Worker<S, A, B>
) -> IO(S):
  match fuel:
    case 0n:
      IO.die(S, 1, "Conc.pool: a worker ran out of fuel")
    case 1n+p:
      match w:
        case WIdle{s}:
          do IO<S>:
            got : Maybe<&1, A & Chan(B)> <- Chan.recv(A & Chan(B), q)
            pool.worker(~S, ~A, ~B, ~work, p, q, WGot{s, got})
        case WGot{s, got}:
          match got:
            case None{}:
              IO.pure(S, s)
            case Some{(a, reply)}:
              do IO<S>:
                sb : S & B <- work(s, a)
                pool.worker(~S, ~A, ~B, ~work, p, q, WDone{sb, reply})
        case WDone{sb, reply}:
          (s, b) = sb
          do IO<S>:
            sent : Bool <- Chan.send(B, reply, b)
            pool.worker(~S, ~A, ~B, ~work, p, q, WIdle{s})

# Queues each job with its own reply channel, and answers the replies in order.
def pool.put(~A: Type, ~B: Type, xs: List<A>, +q: Chan(A & Chan(B))) -> IO(List<Chan(B)>):
  match xs:
    case Nil{}:
      IO.pure(List<Chan(B)>, Nil{})
    case x <> rest:
      do IO<List<Chan(B)>>:
        reply : Chan(B) <- Chan.new(B, 1)
        +r : Chan(B) = reply
        sent : Bool <- Chan.send(A & Chan(B), q, (x, r))
        replies : List<Chan(B)> <- pool.put(~A, ~B, rest, q)
        return r <> replies

def pool.start(
  ~S: Type, ~A: Type, ~B: Type, ~work: S -> A -> IO(S & B), states: List<S>,
  +fuel: Nat, +q: Chan(A & Chan(B))
) -> IO(List<Chan(S)>):
  match states:
    case Nil{}:
      IO.pure(List<Chan(S)>, Nil{})
    case s <> rest:
      do IO<List<Chan(S)>>:
        c : Chan(S) <- IO.fork(S, pool.worker(~S, ~A, ~B, ~work, fuel, q, WIdle{s}))
        cs : List<Chan(S)> <- pool.start(~S, ~A, ~B, ~work, rest, fuel, q)
        return c <> cs

def pool.join(-A: Type, cs: List<Chan(A)>) -> IO(List<A>):
  match cs:
    case Nil{}:
      IO.pure(List<A>, Nil{})
    case c <> rest:
      do IO<List<A>>:
        x : A <- IO.join(A, c)
        xs : List<A> <- pool.join(A, rest)
        return x <> xs

def pool.run(
  ~S: Type, ~A: Type, ~B: Type, ~work: S -> A -> IO(S & B), states: List<S>,
  nx: Nat & List<A>
) -> IO(List<S> & List<B>):
  (+n, xs) = nx
  do IO<List<S> & List<B>>:
    queue : Chan(A & Chan(B)) <- Chan.new(A & Chan(B), U32.from_nat(n))
    +q : Chan(A & Chan(B)) = queue
    replies : List<Chan(B)> <- pool.put(~A, ~B, xs, q)
    Chan.close(A & Chan(B), q)
    workers : List<Chan(S)> <- pool.start(~S, ~A, ~B, ~work, states, Nat.mul(3n, 1n+n), q)
    outs : List<B> <- pool.join(B, replies)
    done : List<S> <- pool.join(S, workers)
    return (done, outs)

# Runs work(s, x) for every x in xs, on one worker per state in states. A
# worker owns its state and threads it through its jobs, so an affine handle
# such as a connection pool is never shared. Answers the final states in
# worker order and the results in the order of xs.
def pool(
  ~S: Type, ~A: Type, ~B: Type, ~work: S -> A -> IO(S & B), states: List<S>, xs: List<A>
) -> IO(List<S> & List<B>):
  match states:
    case Nil{}:
      IO.die(List<S> & List<B>, 1, "Conc.pool: no workers")
    case s <> rest:
      pool.run(~S, ~A, ~B, ~work, s <> rest, count(A, xs))

# A select relay between channel steps.
type Relay<-A: Type> is Type:
  RWait{}
  RGot{got: Maybe<&1, A>}
  RSent{ok: Bool}

# Forwards each value of src to out as (i, value), then reports on done.
# It stops when src closes, or when out is closed under it.
def select.relay(
  -A: Type, fuel: Nat, +i: U32, +src: Chan(A), +out: Chan(U32 & A),
  +done: Chan(Unit), r: Relay<A>
) -> IO(Bool):
  match fuel:
    case 0n:
      Chan.send(Unit, done, Unit{})
    case 1n+p:
      match r:
        case RWait{}:
          do IO<Bool>:
            got : Maybe<&1, A> <- Chan.recv(A, src)
            select.relay(A, p, i, src, out, done, RGot{got})
        case RGot{got}:
          match got:
            case None{}:
              Chan.send(Unit, done, Unit{})
            case Some{x}:
              do IO<Bool>:
                ok : Bool <- Chan.send(U32 & A, out, (i, x))
                select.relay(A, p, i, src, out, done, RSent{ok})
        case RSent{ok}:
          match ok:
            case True{}:
              select.relay(A, p, i, src, out, done, RWait{})
            case False{}:
              Chan.send(Unit, done, Unit{})

# ponytail: relay fuel is the largest Nat literal, and a value takes three
# steps, so a relay stops after about 1.4 billion values. Drop the fuel if
# Base gains an unbounded loop.
def select.start(
  -A: Type, chans: List<Chan(A)>, +i: U32, +out: Chan(U32 & A), +done: Chan(Unit)
) -> IO(Nat):
  match chans:
    case Nil{}:
      IO.pure(Nat, 0n)
    case src <> rest:
      do IO<Nat>:
        IO.spawn(Bool, select.relay(A, 4294967295n, i, src, out, done, RWait{}))
        n : Nat <- select.start(A, rest, (i + 1 : U32), out, done)
        return 1n+n

# Closes out once all n relays have reported.
def select.close(-A: Type, n: Nat, +out: Chan(U32 & A), +done: Chan(Unit)) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        Chan.close(U32 & A, out)
        Chan.close(Unit, done)
    case 1n+p:
      do IO<Unit>:
        got : Maybe<&1, Unit> <- Chan.recv(Unit, done)
        select.close(A, p, out, done)

def select.go(-A: Type, chans: List<Chan(A)>, +out: Chan(U32 & A), +done: Chan(Unit)) ->
  IO(Chan(U32 & A)):
  do IO<Chan(U32 & A)>:
    n : Nat <- select.start(A, chans, 0, out, done)
    IO.spawn(Unit, select.close(A, n, out, done))
    return out

# One channel that carries (i, value) for each value received on chans[i], in
# the order they arrive. Chan.recv on it waits for whichever source is ready
# first, and answers None once every source is closed. The selector owns the
# receiving side of its sources. Close it to stop early: each relay then drops
# the one value it holds, if any, and stops.
def select(-A: Type, chans: List<Chan(A)>) -> IO(Chan(U32 & A)):
  do IO<Chan(U32 & A)>:
    out : Chan(U32 & A) <- Chan.new(U32 & A, 0)
    done : Chan(Unit) <- Chan.new(Unit, 0)
    select.go(A, chans, out, done)

def timeout.won(-A: Type, +c: Chan(Maybe<&1, A>), got: Maybe<&1, Maybe<&1, A>>) ->
  IO(Maybe<&1, A>):
  match got:
    case None{}:
      IO.pure(Maybe<&1, A>, None{})
    case Some{m}:
      do IO<Maybe<&1, A>>:
        Chan.close(Maybe<&1, A>, c)
        return m

# Some{result} if act finishes within ms milliseconds, else None at the
# deadline. act is not cancelled: it runs on, its late result is dropped, and
# the program waits for it (and for the timer) before it exits.
def timeout(-A: Type, ms: U32, act: IO(A)) -> IO(Maybe<&1, A>):
  do IO<Maybe<&1, A>>:
    chan : Chan(Maybe<&1, A>) <- Chan.new(Maybe<&1, A>, 0)
    +c : Chan(Maybe<&1, A>) = chan
    IO.spawn(Bool, IO.bind(A, Bool, act, x => Chan.send(Maybe<&1, A>, c, Some{x})))
    IO.spawn(Bool, IO.bind(Unit, Bool, IO.sleep(ms), u => Chan.send(Maybe<&1, A>, c, None{})))
    got : Maybe<&1, Maybe<&1, A>> <- Chan.recv(Maybe<&1, A>, c)
    timeout.won(A, c, got)
