# Runner replay benchmark: the Bend side (see README.md).
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-journal@0.3.0.1/journal.bend as J
import bend-kit-scheduler@0.4.3.0/queue.bend as Q
import bend-kit-collections@0.1.5.0/heap.bend as H
import bend-kit-time@0.3.0.0/time.bend as Time
import ../runner.bend as R

def penc(x: U32) -> Bytes.Bytes:
  Bytes.set.u32le(Bytes.new(4), 0, x)

def pdec.of(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (b, m) = r
  m

def pdec(b: Bytes.Bytes) -> Maybe<&2, U32>:
  pdec.of(Bytes.get.u32le(b, 0))

# The log, the live state it leads to, and the ids that died, newest first: frames are appended as the live runner would.
type Gen is Type:
  Gen{log: Bytes.Bytes, state: R.State<U32>, ids: List<&2, Nat>}

def put(g: Gen, +op: R.Op<U32>) -> Gen:
  Gen{b, s, ids} = g
  Gen{Bytes.append(b, J.frame(R.encode(~U32, ~penc, op))), R.step(~U32, s, op), ids}

# Enqueue i with deadline (i * 37) % 1024 and payload i.
def enqueues(k: Nat, g: Gen, +i: U32) -> Gen:
  match k:
    case 0n:
      g
    case 1n+p:
      enqueues(p, put(g, R.Enqueue{U32.to_nat(((i * 37 : U32) % 1024 : U32)), i}), (i + 1 : U32))

def head(xs: List<&2, Q.Ticket<U32>>) -> Nat:
  match xs:
    case Con{t, rest}:
      Q.id(U32, t)
    case Nil{}:
      0n

def after(+k: Nat, +half: Nat, +id: Nat) -> R.Op<U32>:
  Bool.pick(R.Op<U32>, Nat.is_lt(k, half), R.Complete{id}, R.Requeue{id, Nat.add(2048n, k)})

def finish(g: Gen, +k: Nat, +half: Nat) -> Gen:
  Gen{b, +s, ids} = g
  put(Gen{b, s, ids}, after(k, half, head(Q.running(U32, R.queue(U32, s)))))

# Select at 1024 takes the next ticket; the first half complete, the rest requeue at 2048 + k.
def rounds(k: Nat, g: Gen, +j: Nat, +half: Nat) -> Gen:
  match k:
    case 0n:
      g
    case 1n+p:
      rounds(p, finish(put(g, R.Select{1024n}), j, half), 1n+j, half)

# The log, and the journal that compacting it writes: one frame that holds the snapshot of the final state.
def logs(g: Gen) -> Bytes.Bytes & Bytes.Bytes:
  Gen{b, s, ids} = g
  (b, J.frame(R.encode.snap(~U32, ~penc, s)))

def build(+n: Nat) -> Bytes.Bytes & Bytes.Bytes:
  logs(rounds(n, enqueues(n, Gen{Bytes.new(0), R.new(U32), Nil{}}, 0), 0n, Nat.div(n, 2n)))

# Retry gives up on the running ticket at k.
def die(g: Gen, +k: Nat) -> Gen:
  Gen{b, +s, ids} = g
  +id = head(Q.running(U32, R.queue(U32, s)))
  put(Gen{b, s, Con{id, ids}}, R.Abandon{id, R.WhyFailed{}, k})

# Select at 1024 takes the next ticket, and it dies at k.
def deaths(k: Nat, g: Gen, +j: Nat) -> Gen:
  match k:
    case 0n:
      g
    case 1n+p:
      deaths(p, die(put(g, R.Select{1024n}), j), 1n+j)

def purge.at(now: Bool, g: Gen, +half: Nat) -> Gen:
  match now:
    case True{}:
      put(g, R.Purge{half})
    case False{}:
      g

# The ticket that died at k: below a quarter it is cancelled; from half on it is revived at 4096 + k,
# after one Purge of every ticket that died before half.
def settle(cancel: Bool, revive: Bool, g: Gen, +id: Nat, +k: Nat, +half: Nat) -> Gen:
  match cancel revive:
    case True{} r:
      put(g, R.Cancel{id})
    case False{} True{}:
      put(purge.at(Nat.is_eq(k, half), g, half), R.Revive{id, Nat.add(4096n, k)})
    case False{} False{}:
      g

def settles(ids: List<&2, Nat>, g: Gen, +k: Nat, +n: Nat) -> Gen:
  match ids:
    case Nil{}:
      g
    case Con{+id, rest}:
      settles(rest, settle(Nat.is_lt(k, Nat.div(n, 4n)), Nat.is_le(Nat.div(n, 2n), k), g, id, k, Nat.div(n, 2n)), 1n+k, n)

def log.of(g: Gen) -> Bytes.Bytes:
  Gen{b, s, ids} = g
  b

def dead.log(g: Gen, +n: Nat) -> Bytes.Bytes:
  Gen{b, s, ids} = g
  log.of(settles(List.reverse(&2, Nat, ids), Gen{b, s, Nil{}}, 0n, n))

# Every job dies; a quarter are cancelled, a quarter purged in one record, and half revived.
def build.dead(+n: Nat) -> Bytes.Bytes:
  dead.log(deaths(n, enqueues(n, Gen{Bytes.new(0), R.new(U32), Nil{}}, 0), 0n), n)

# Sum of id * 31 + deadline over the pending tickets, and their count.
def sum(h: H.Heap<Q.Ticket<U32>>, +acc: Nat) -> Nat:
  match h:
    case H.HLeaf{}:
      acc
    case H.HNode{n, Q.Ticket{+i, +d, x}, l, r}:
      sum(l, sum(r, Nat.add(acc, Nat.add(Nat.mul(i, 31n), d))))

def shown(+op: String, m: Maybe<&2, R.State<U32>>, t0: Time.Duration) -> IO(Unit):
  match m:
    case Some{R.State{Q.State{next, +h, run}, ts, ds, bs}}:
      do IO<Unit>:
        IO.print("chk\t" ++ op ++ "\t" ++ Nat.show(Nat.mod(sum(h, 0n), Nat.mul(65536n, 65536n))))
        IO.print("n\t" ++ op ++ "\t" ++ Nat.show(H.Heap.size(Q.Ticket<U32>, h)) ++ "/" ++ Nat.show(next))
        t1 : Time.Duration <- Time.mono()
        IO.print("ms\t" ++ op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    case None{}:
      IO.die(Unit, 1, "replay met a record that is not a runner record")

def at(+op: String, t0: Time.Duration, r: J.Replay<Maybe<&2, R.State<U32>>, J.Cur>) -> IO(Unit):
  J.Replay{acc, t, rest} = r
  shown(op, acc, t0)

def lg(args: List<&1, String>) -> Nat:
  match args:
    case program <> k <> Nil{}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(k), 15))
    case _:
      15n

# open's fold over b. A snapshot is one record, so max is the 1 GiB cap of the input, as open reads with limit.
def replay(b: Bytes.Bytes) -> J.Replay<Maybe<&2, R.State<U32>>, J.Cur>:
  J.replay.bytes(~Maybe<&2, R.State<U32>>, ~(a => p => R.replay.step(~U32, ~pdec, a, p)), 1073741824, b, Some{R.new(U32)})

def timed(x: Bytes.Bytes & Bytes.Bytes, dead: Bytes.Bytes) -> IO(Unit):
  (full, small) = x
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    at("replay", t0, replay(full))
    t1 : Time.Duration <- Time.mono()
    at("compacted", t1, replay(small))
    t2 : Time.Duration <- Time.mono()
    at("dead", t2, replay(dead))

def sized(+n: Nat) -> IO(Unit):
  timed(build(n), build.dead(n))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    sized(Nat.pow(2n, lg(args)))
