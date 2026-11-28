import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-journal@0.4.0.2/journal.bend as J
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-scheduler@0.4.4.0/queue.bend as Q
import bend-kit-files@0.4.0.3/files.bend as Files
import bend-kit-collections@0.1.6.0/heap.bend as H
import bend-kit-collections@0.1.6.0/omap.bend as O
import bend-kit-collections@0.1.6.0/hmap.bend as M
import ./runner.bend as R
import ./model.bend as Model
import ./example.bend as Example

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def same.if(eq: Bool, +got: String, +want: String, +name: String) -> IO(Unit):
  match eq:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name ++ ": got " ++ got ++ ", want " ++ want)

def same(+got: String, +want: String, +name: String) -> IO(Unit):
  same.if(String.eq(got, want), got, want, name)

# ---- a String payload, as its octets

def penc(s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def pdec(b: Bytes.Bytes) -> Maybe<&2, String>:
  Some{Bytes.to_string(b)}

def show.why(w: Model.Why) -> String:
  match w:
    case Model.WhySpent{}:
      "spent"
    case Model.WhyLate{}:
      "late"
    case Model.WhyUnsafe{}:
      "unsafe"
    case Model.WhyFailed{}:
      "failed"

def show.nats(xs: List<&2, Nat>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      " " ++ Nat.show(x) ++ show.nats(rest)

def show.brk(b: Retry.State) -> String:
  match b:
    case Retry.CircuitClosed{fs}:
      "closed" ++ show.nats(fs)
    case Retry.CircuitOpen{u}:
      "open " ++ Nat.show(u)
    case Retry.CircuitHalf{k}:
      "half " ++ Nat.show(k)

def show(m: Maybe<&2, Model.Op<String>>) -> String:
  match m:
    case None{}:
      "none"
    case Some{Model.Enqueue{d, x}}:
      "enqueue " ++ Nat.show(d) ++ " " ++ x
    case Some{Model.Select{n}}:
      "select " ++ Nat.show(n)
    case Some{Model.Complete{i}}:
      "complete " ++ Nat.show(i)
    case Some{Model.Cancel{i}}:
      "cancel " ++ Nat.show(i)
    case Some{Model.Requeue{i, d}}:
      "requeue " ++ Nat.show(i) ++ " " ++ Nat.show(d)
    case Some{Model.Defer{i, d}}:
      "defer " ++ Nat.show(i) ++ " " ++ Nat.show(d)
    case Some{Model.Abandon{i, w, at}}:
      "abandon " ++ Nat.show(i) ++ " " ++ show.why(w) ++ " " ++ Nat.show(at)
    case Some{Model.Revive{i, d}}:
      "revive " ++ Nat.show(i) ++ " " ++ Nat.show(d)
    case Some{Model.Purge{t}}:
      "purge " ++ Nat.show(t)
    case Some{Model.PurgeAll{}}:
      "purge all"
    case Some{Model.Break{k, b}}:
      "break " ++ k ++ " " ++ show.brk(b)

def rt(+op: Model.Op<String>) -> String:
  show(Model.decode(~String, ~pdec, Model.encode(~String, ~penc, op)))

def big() -> Nat:
  Nat.add(Nat.mul(1700n, 1000000000n), 123n)

def live(ops: List<&2, Model.Op<String>>, s: Model.State<String>) -> Model.State<String>:
  match ops:
    case Nil{}:
      s
    case Con{op, rest}:
      live(rest, Model.step(~String, s, op))

# Two tickets pending, one running, one requeued once, one cancelled, one dead, and three breakers.
def sample() -> Model.State<String>:
  live([Model.Enqueue{5n, "a"}, Model.Enqueue{big(), "b|c"}, Model.Enqueue{3n, ""}, Model.Select{10n}, Model.Requeue{2n, 20n}, Model.Select{30n}, Model.Enqueue{1n, "d"},
    Model.Enqueue{40n, "e"}, Model.Cancel{4n}, Model.Select{30n}, Model.Abandon{0n, Model.WhyUnsafe{}, big()}, Model.Break{"local", Retry.CircuitClosed{[7n]}},
    Model.Break{"λ:443", Retry.CircuitClosed{[1n, big()]}}, Model.Break{"h", Retry.CircuitHalf{2n}}, Model.Break{"local", Retry.CircuitOpen{big()}}], Model.new(String))

def colliding.breakers() -> Model.State<String>:
  live([Model.Break{"costarring", Retry.CircuitOpen{10n}}, Model.Break{"liquid", Retry.CircuitHalf{2n}}], Model.new(String))

# Three tickets abandoned at 10, 20, and 30, so that the dead-ticket trie has a branch.
def graveyard() -> Model.State<String>:
  live([Model.Enqueue{0n, "x"}, Model.Enqueue{0n, "y"}, Model.Enqueue{0n, "z"}, Model.Select{0n}, Model.Select{0n}, Model.Select{0n},
    Model.Abandon{0n, Model.WhyFailed{}, 10n}, Model.Abandon{1n, Model.WhySpent{}, 20n}, Model.Abandon{2n, Model.WhyLate{}, 30n}], Model.new(String))

def dead7() -> Model.Dead<String>:
  Model.Dead{Q.Ticket{7n, 0n, "x"}, Model.WhyFailed{}, 1n}

def next(s: Model.State<String>, n: Nat) -> Model.State<String>:
  Model.State{Q.State{old, h, run}, ts, ds, bs} = s
  Model.State{Q.State{n, h, run}, ts, ds, bs}

# s with its dead-ticket trie replaced by ds, which no op would build.
def regraved(s: Model.State<String>, ds: Model.Graves(String)) -> Model.State<String>:
  Model.State{q, ts, old, bs} = s
  next(Model.State{q, ts, ds, bs}, Nat.mul(1024n, Nat.mul(65536n, 65536n)))

def brk(s: Model.State<String>, +key: String) -> String:
  show.brk(Model.brk.get(String, s, key))

def hex(s: Model.State<String>) -> String:
  Bytes.to_hex(Model.encode.snap(~String, ~penc, s))

def shown.rec(m: Maybe<&2, Model.Rec<String>>) -> String:
  match m:
    case None{}:
      "none"
    case Some{Model.Snap{s}}:
      hex(s)
    case Some{Model.Do{op}}:
      "op " ++ show(Some{op})

def rec(b: Bytes.Bytes) -> String:
  shown.rec(Model.decode.rec(~String, ~pdec, b))

def fails(ts: List<&1, Nat & Model.Try>) -> Nat:
  match ts:
    case Nil{}:
      0n
    case Con{(i, Model.Try{f, st}), rest}:
      Nat.add(f, fails(rest))

def graves.go(ds: List<&2, Model.Dead<String>>) -> List<&2, String>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{Model.Dead{Q.Ticket{i, d, x}, w, at}, rest}:
      Con{Nat.show(i) ++ ":" ++ show.why(w) ++ ":" ++ x, graves.go(rest)}

# Each dead ticket as id:why:payload, sorted, then a space.
def graves(ds: Model.Graves(String)) -> String:
  String.join(List.sort(~String, ~String.is_le, graves.go(Model.dead.list(String, ds))), " ") ++ " "

def describe(s: Model.State<String>) -> String:
  Model.State{Q.State{+n, +h, +run}, +ts, +ds, +bs} = s
  "next=" ++ Nat.show(n) ++ " pending=" ++ Nat.show(Model.pending(String, Model.State{Q.State{n, h, run}, ts, ds, bs})) ++ " running=" ++ Nat.show(List.length(&2, Q.Ticket<String>, run)) ++
    " tries=" ++ U32.show(O.OMap.size(Nat, Model.Try, ts)) ++ " fails=" ++ Nat.show(fails(O.OMap.to_list(Nat, Model.Try, ts))) ++ " dead=" ++ Nat.show(M.HMap.size(Nat, Model.Dead<String>, ds))

def collision.entries(+n: Nat) -> List<&2, M.Entry<Nat, Model.Dead<String>>>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +id = Nat.mul(p, Nat.mul(65536n, 65536n))
      M.Entry{id, Model.Dead{Q.Ticket{id, 0n, Nat.show(p)}, Model.WhyFailed{}, p}} <> collision.entries(p)

def collision.count(m: Maybe<&2, Model.Rec<String>>) -> Nat:
  match m:
    case Some{Model.Snap{s}}:
      M.HMap.size(Nat, Model.Dead<String>, Model.dead(String, s))
    case _:
      0n

def queued(h: H.Heap<Q.Ticket<String>>, run: List<&2, Q.Ticket<String>>) -> Model.State<String>:
  Model.State{Q.State{Nat.add(Nat.mul(65536n, 65536n), 10n), h, run}, O.OMap.new(Nat, Model.Try), M.HMap.new(Nat, Model.Dead<String>), M.HMap.new(String, Retry.State)}

def leaf(+i: Nat, d: Nat, x: String) -> H.Heap<Q.Ticket<String>>:
  H.HNode{1n, Q.Ticket{i, d, x}, H.HLeaf{}, H.HLeaf{}}

def queue.snapshots() -> IO(Unit):
  do IO<Unit>:
    same(rec(Model.encode.snap(~String, ~penc, queued(
      H.HNode{3n, Q.Ticket{0n, 1n, "root"}, leaf(1n, 2n, "left"), leaf(1n, 3n, "right")}, []))),
      "none", "duplicate pending ids in separate subtrees do not decode")
    same(rec(Model.encode.snap(~String, ~penc, queued(
      H.HNode{2n, Q.Ticket{0n, 1n, "root"}, leaf(0n, 2n, "child"), H.HLeaf{}}, []))),
      "none", "a pending child with its ancestor id does not decode")
    same(rec(Model.encode.snap(~String, ~penc, queued(H.HLeaf{},
      [Q.Ticket{0n, 1n, "first"}, Q.Ticket{1n, 2n, "middle"}, Q.Ticket{0n, 3n, "last"}]))),
      "none", "nonadjacent duplicate running ids do not decode")
    same(rec(Model.encode.snap(~String, ~penc, queued(leaf(0n, 1n, "pending"), [Q.Ticket{0n, 2n, "running"}]))),
      "none", "an id shared by pending and running does not decode")
    same(rec(Model.encode.snap(~String, ~penc, queued(leaf(0n, 1n, "pending"), [Q.Ticket{Nat.mul(65536n, 65536n), big(), "running"}]))),
      hex(queued(leaf(0n, 1n, "pending"), [Q.Ticket{Nat.mul(65536n, 65536n), big(), "running"}])),
      "distinct 64-bit ids with equal low words keep the exact queue shape, payloads, and deadlines")

def fresh.snapshots() -> IO(Unit):
  do IO<Unit>:
    same(rec(Model.encode.snap(~String, ~penc, next(queued(leaf(0n, 1n, "pending"), []), 0n))),
      "none", "next zero cannot reuse the pending id on the first enqueue")
    same(rec(Model.encode.snap(~String, ~penc, next(queued(leaf(8n, 1n, "pending"), []), 7n))),
      "none", "next below a pending id does not decode")
    same(rec(Model.encode.snap(~String, ~penc, next(queued(H.HLeaf{}, [Q.Ticket{8n, 2n, "running"}]), 8n))),
      "none", "next equal to a running id does not decode")
    same(rec(Model.encode.snap(~String, ~penc, next(queued(H.HLeaf{}, [Q.Ticket{8n, 2n, "running"}]), 7n))),
      "none", "next below a running id does not decode")
    same(rec(Model.encode.snap(~String, ~penc, next(graveyard(), 2n))),
      "none", "next equal to a dead id does not decode")
    same(rec(Model.encode.snap(~String, ~penc, next(graveyard(), 1n))),
      "none", "next below a dead id does not decode")
    same(rec(Model.encode.snap(~String, ~penc, next(regraved(Model.new(String),
      M.HLeaf{0, [M.Entry{0n, dead7()}]}), 7n))),
      "none", "the dead payload ticket id is bounded even when its key differs")
    same(rec(Model.encode.snap(~String, ~penc, next(regraved(Model.new(String),
      M.HLeaf{7, [M.Entry{7n, Model.Dead{Q.Ticket{0n, 0n, "x"}, Model.WhyFailed{}, 1n}}]}), 7n))),
      "none", "the dead lookup key is bounded even when its ticket id differs")
    same(rec(Model.encode.snap(~String, ~penc, next(queued(leaf(8n, big(), "pending"), [Q.Ticket{7n, 2n, "running"}]), 9n))),
      hex(next(queued(leaf(8n, big(), "pending"), [Q.Ticket{7n, 2n, "running"}]), 9n)),
      "next one above every queue id preserves the full snapshot")

def registry.fixture(h: H.Heap<Q.Ticket<String>>, run: List<&2, Q.Ticket<String>>, +key: Nat, id: Nat) -> Model.State<String>:
  next(regraved(queued(h, run), M.HLeaf{Model.dead.hash(key),
    [M.Entry{key, Model.Dead{Q.Ticket{id, big(), "dead"}, Model.WhyFailed{}, 1n}}]}), 9n)

def registry.revived(m: Maybe<&2, Model.Rec<String>>, i: Nat) -> String:
  match m:
    case Some{Model.Snap{s}}:
      Bool.pick(String, Model.queue.unique(String, Model.step(~String, s, Model.Revive{i, 4n})), "unique", "duplicate")
    case _:
      "none"

def registry.snapshots() -> IO(Unit):
  do IO<Unit>:
    same(rec(Model.encode.snap(~String, ~penc, registry.fixture(leaf(0n, 1n, "pending"), [], 0n, 0n))),
      "none", "pending and dead cannot share an id")
    same(rec(Model.encode.snap(~String, ~penc, registry.fixture(H.HLeaf{}, [Q.Ticket{0n, 2n, "running"}], 0n, 0n))),
      "none", "running and dead cannot share an id")
    same(rec(Model.encode.snap(~String, ~penc, registry.fixture(H.HLeaf{}, [], 0n, 7n))),
      "none", "dead lookup keys must equal their stored ticket ids even below next")
    same(registry.revived(Model.decode.rec(~String, ~pdec, Model.encode.snap(~String, ~penc,
      next(registry.fixture(leaf(0n, 1n, "pending"), [], 0n, 0n), 2n))), 0n),
      "none", "the first revive cannot duplicate id zero from a snapshot with next two")
    same(rec(Model.encode.snap(~String, ~penc, registry.fixture(leaf(1n, big(), "pending"), [Q.Ticket{2n, 3n, "running"}], 0n, 0n))),
      hex(registry.fixture(leaf(1n, big(), "pending"), [Q.Ticket{2n, 3n, "running"}], 0n, 0n)),
      "disjoint registries preserve the full snapshot")
    same(registry.revived(Model.decode.rec(~String, ~pdec, Model.encode.snap(~String, ~penc,
      registry.fixture(leaf(1n, big(), "pending"), [Q.Ticket{2n, 3n, "running"}], 0n, 0n))), 0n),
      "unique", "the first revive of a valid snapshot keeps unique live ids")

def snapshots() -> IO(Unit):
  do IO<Unit>:
    queue.snapshots()
    fresh.snapshots()
    registry.snapshots()
    same(describe(sample()), "next=5 pending=2 running=1 tries=3 fails=1 dead=1", "the sample state has pending, running, retried, and dead tickets")
    same(graves(Model.dead(String, sample())), "0:unsafe:a ", "a dead ticket keeps its payload and why")
    same(rec(Model.encode.snap(~String, ~penc, sample())), hex(sample()), "a snapshot decodes to the same heap, running list, tries, dead tickets, and breakers")
    same(brk(sample(), "local"), "open 1700000000123", "a later Break replaces the target's breaker")
    same(brk(sample(), "λ:443"), "closed 1 1700000000123", "a Break keeps a closed breaker's failures")
    same(brk(sample(), "none"), "closed", "a target with no Break is closed")
    same(hex(live([Model.Break{"t", Retry.CircuitClosed{[7n]}}, Model.Break{"t", Retry.CircuitClosed{[]}}], Model.new(String))), hex(Model.new(String)), "a target that failed and then recovered leaves no breaker in the snapshot")
    same(brk(Model.calm(String, sample()), "h"), "half 0", "open counts no probe of a half-open breaker in flight")
    same(brk(Model.calm(String, sample()), "local"), "open 1700000000123", "open keeps an open breaker's until")
    same(U32.show(Model.brk.hash("costarring")), U32.show(Model.brk.hash("liquid")), "the breaker fixture has a hash collision")
    same(brk(colliding.breakers(), "costarring"), "open 10", "colliding targets keep separate breaker states")
    same(brk(colliding.breakers(), "liquid"), "half 2", "a later colliding target does not replace the first")
    same(rec(Model.encode.snap(~String, ~penc, colliding.breakers())), hex(colliding.breakers()), "colliding breaker snapshots round-trip without changing entry order")
    same(rec(Model.encode.snap(~String, ~penc, Model.new(String))), hex(Model.new(String)), "an empty snapshot round-trips")
    same(rec(Model.encode(~String, ~penc, Model.Cancel{8n})), "op cancel 8", "an op record decodes as an op")
    same(rec(Bytes.snd(Bytes.slice(Model.encode.snap(~String, ~penc, sample()), 0, 60))), "none", "a short snapshot does not decode")
    same(rec(Bytes.append(Model.encode.snap(~String, ~penc, sample()), Bytes.new(4))), "none", "a snapshot with octets after it does not decode")
    same(rec(Bytes.set(Model.encode.snap(~String, ~penc, sample()), 12, 2)), "none", "a snapshot flag other than 0 or 1 does not decode")
    same(graves(Model.dead(String, graveyard())), "0:failed:x 1:spent:y 2:late:z ", "each dead ticket keeps its payload and why")
    same(rec(Model.encode.snap(~String, ~penc, graveyard())), hex(graveyard()), "a snapshot decodes to the same dead-ticket trie")
    same(graves(Model.dead(String, Model.step(~String, graveyard(), Model.Purge{20n}))), "1:spent:y 2:late:z ", "a Purge drops only the tickets abandoned before its time")
    same(rec(Model.encode.snap(~String, ~penc, Model.step(~String, graveyard(), Model.Purge{20n}))), hex(Model.step(~String, graveyard(), Model.Purge{20n})), "a snapshot after a Purge round-trips")
    same(describe(Model.step(~String, graveyard(), Model.PurgeAll{})), "next=3 pending=0 running=0 tries=0 fails=0 dead=0", "a PurgeAll drops every dead ticket")
    same(describe(Model.step(~String, Model.step(~String, graveyard(), Model.Purge{20n}), Model.Revive{0n, 5n})), "next=3 pending=0 running=0 tries=0 fails=0 dead=2", "a purged ticket does not revive")
    same(describe(Model.step(~String, graveyard(), Model.Revive{1n, 5n})), "next=3 pending=1 running=0 tries=1 fails=0 dead=2", "a Revive takes one dead ticket by id")
    same(rec(Model.encode.snap(~String, ~penc, regraved(graveyard(), M.HLeaf{7, [M.Entry{7n, dead7()}, M.Entry{7n, dead7()}]}))), "none", "a snapshot with two entries for one id in a bucket does not decode")
    same(rec(Model.encode.snap(~String, ~penc, regraved(graveyard(), M.HLeaf{3, [M.Entry{7n, dead7()}]}))), "none", "a snapshot whose bucket hash does not match its keys does not decode")
    same(rec(Model.encode.snap(~String, ~penc, regraved(graveyard(), M.HLeaf{7, [M.Entry{7n, dead7()}]}))), hex(regraved(graveyard(), M.HLeaf{7, [M.Entry{7n, dead7()}]})), "a snapshot with a well-formed hand-built bucket decodes")
    same(rec(Model.encode.snap(~String, ~penc, regraved(Model.new(String), M.HLeaf{0, collision.entries(3n)}))),
      hex(regraved(Model.new(String), M.HLeaf{0, List.reverse(&2, M.Entry<Nat, Model.Dead<String>>, collision.entries(3n))})),
      "an unsorted colliding bucket decodes in id order and keeps each ticket")
    same(Nat.show(collision.count(Model.decode.rec(~String, ~pdec, Model.encode.snap(~String, ~penc,
      regraved(Model.new(String), M.HLeaf{0, collision.entries(1024n)}))))), "1024", "a snapshot with many colliding ids decodes")
    same(rec(Model.encode.snap(~String, ~penc, regraved(Model.new(String),
      M.HLeaf{0, M.Entry{0n, dead7()} <> List.append(&2, M.Entry<Nat, Model.Dead<String>>, collision.entries(3n), [M.Entry{0n, dead7()}])}))),
      "none", "a duplicate separated by other colliding ids does not decode")

def codec() -> IO(Unit):
  +t = big()
  do IO<Unit>:
    same(rt(Model.Enqueue{t, "a|b"}), "enqueue 1700000000123 a|b", "an Enqueue keeps a 41-bit deadline and its payload")
    same(rt(Model.Enqueue{0n, ""}), "enqueue 0 ", "an Enqueue keeps an empty payload")
    same(rt(Model.Select{t}), "select 1700000000123", "a Select keeps its now")
    same(rt(Model.Complete{7n}), "complete 7", "a Complete keeps its id")
    same(rt(Model.Cancel{8n}), "cancel 8", "a Cancel keeps its id")
    same(rt(Model.Requeue{9n, t}), "requeue 9 1700000000123", "a Requeue keeps its id and deadline")
    same(rt(Model.Defer{10n, t}), "defer 10 1700000000123", "a Defer keeps its id and deadline")
    same(rt(Model.Abandon{11n, Model.WhySpent{}, t}), "abandon 11 spent 1700000000123", "an Abandon keeps its id, a spent why, and its time")
    same(rt(Model.Abandon{11n, Model.WhyLate{}, 0n}), "abandon 11 late 0", "an Abandon keeps a late why")
    same(rt(Model.Abandon{11n, Model.WhyUnsafe{}, 0n}), "abandon 11 unsafe 0", "an Abandon keeps an unsafe why")
    same(rt(Model.Abandon{11n, Model.WhyFailed{}, 0n}), "abandon 11 failed 0", "an Abandon keeps a failed why")
    same(rt(Model.Revive{12n, t}), "revive 12 1700000000123", "a Revive keeps its id and deadline")
    same(rt(Model.Purge{t}), "purge 1700000000123", "a Purge keeps its time")
    same(rt(Model.PurgeAll{}), "purge all", "a PurgeAll round-trips")
    same(Bytes.to_hex(Model.snap.key(Bytes.new(0), "api.example.com:443")), "130000006170692e6578616d706c652e636f6d3a343433", "an ASCII target uses one octet per char and an octet length")
    same(Bytes.to_hex(Model.snap.key(Bytes.new(0), "λ€😀")), "09000000cebbe282acf09f9880", "a target uses standard two-, three-, and four-octet UTF-8")
    same(rt(Model.Break{"λ€😀", Retry.CircuitOpen{t}}), "break λ€😀 open 1700000000123", "a non-ASCII target round-trips through a Break")
    same(rec(Model.encode.snap(~String, ~penc, live([Model.Break{"λ€😀", Retry.CircuitHalf{2n}}], Model.new(String)))), hex(live([Model.Break{"λ€😀", Retry.CircuitHalf{2n}}], Model.new(String))), "a non-ASCII target round-trips through a snapshot")
    same(rec(Bytes.set.u32le(Model.encode.snap(~String, ~penc, sample()), 0, 7)), "none", "a legacy snapshot tag does not decode as UTF-8")
    same(show(Model.decode(~String, ~pdec, Bytes.set.u32le(Model.encode(~String, ~penc, Model.Break{"t", Retry.CircuitHalf{3n}}), 0, 10))), "none", "a legacy Break tag does not decode as UTF-8")
    same(show(Model.decode(~String, ~pdec, Bytes.set.u32le(Model.encode(~String, ~penc, Model.Break{"t", Retry.CircuitHalf{3n}}), 4, 4294967295))), "none", "a target length beyond its record does not decode")
    same(rt(Model.Break{"λ:443", Retry.CircuitClosed{[t, 5n]}}), "break λ:443 closed 1700000000123 5", "a Break keeps its target and a closed breaker's failures")
    same(rt(Model.Break{"", Retry.CircuitClosed{[]}}), "break  closed", "a Break keeps an empty target and no failures")
    same(rt(Model.Break{"t", Retry.CircuitOpen{t}}), "break t open 1700000000123", "a Break keeps an open breaker's until")
    same(rt(Model.Break{"t", Retry.CircuitHalf{3n}}), "break t half 3", "a Break keeps a half-open breaker's probes")
    same(show(Model.decode(~String, ~pdec, Bytes.set(Model.encode(~String, ~penc, Model.Break{"t", Retry.CircuitHalf{3n}}), 9, 3))), "none", "a Break with an unknown kind is not an op")
    same(show(Model.decode(~String, ~pdec, Bytes.append(Model.encode(~String, ~penc, Model.Break{"t", Retry.CircuitHalf{3n}}), Bytes.new(4)))), "none", "a Break with octets after it is not an op")
    same(show(Model.decode(~String, ~pdec, Bytes.snd(Bytes.slice(Model.encode(~String, ~penc, Model.Break{"t", Retry.CircuitHalf{3n}}), 0, 20)))), "none", "a short Break is not an op")
    same(show(Model.decode(~String, ~pdec, Bytes.set(Model.encode(~String, ~penc, Model.Abandon{11n, Model.WhySpent{}, 0n}), 12, 4))), "none", "an Abandon with an unknown why is not an op")
    same(show(Model.decode(~String, ~pdec, Bytes.snd(Bytes.slice(Model.encode(~String, ~penc, Model.Abandon{11n, Model.WhySpent{}, 0n}), 0, 20)))), "none", "an Abandon without its time is not an op")
    same(show(Model.decode(~String, ~pdec, Bytes.from_string("abc"))), "none", "a record shorter than a head is not an op")
    same(show(Model.decode(~String, ~pdec, Bytes.set(Model.encode(~String, ~penc, Model.Cancel{8n}), 0, 15))), "none", "an unknown tag is not an op")
    same(show(Model.decode(~String, ~pdec, Bytes.snd(Bytes.slice(Model.encode(~String, ~penc, Model.Cancel{8n}), 0, 16)))), "none", "a short Cancel is not an op")

# ---- jobs: "log|kind:name". work notes the job in log, runs it, then notes "end" and the job, and answers by kind.
# A slow job ("slow:" or "slowfail:") sleeps 1 s before it ends. A "fail:" or "slowfail:" job fails, and another try can help.
# A "dead:" job fails, and another try would repeat the failure. A "reject:" job is a client error.
def note.close(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (f, x) = r
  File.close(f)

def note(+log: String, +spec: String) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(log, "a"))
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, spec ++ "\n")
    note.close(r)

def outcome(+spec: String) -> Retry.Outcome:
  Bool.pick(Retry.Outcome, String.starts_with(spec, "dead:"), Retry.Failed{},
  Bool.pick(Retry.Outcome, String.starts_with(spec, "reject:"), Retry.Rejected{},
  Bool.pick(Retry.Outcome, Bool.or(String.starts_with(spec, "fail:"), String.starts_with(spec, "slowfail:")), Retry.Transient{Some{0n}}, Retry.Settled{})))

def work.go(xs: List<&2, String>) -> IO(Retry.Outcome):
  match xs:
    case Con{+log, Con{+spec, Nil{}}}:
      do IO<Retry.Outcome>:
        note(log, spec)
        IO.sleep(Bool.pick(U32, String.starts_with(spec, "slow"), 1000, 0))
        note(log, "end " ++ spec)
        return outcome(spec)
    case _:
      IO.pure(Retry.Outcome, Retry.Settled{})

def work(s: String) -> IO(Retry.Outcome):
  work.go(String.split(s, '|'))

# Every job has one breaker; a failing one opens it after two failures.
def target(s: String) -> String:
  "local"

def config(+threshold: Nat, +every: U32) -> R.Config:
  R.Config{Retry.Policy{3n, 1n, 4, None{}}, Retry.Circuit{threshold, 60000n, 60000n, 1n}, 5, every}

def config.idle() -> R.Config:
  R.Config{Retry.Policy{3n, 1n, 4, None{}}, Retry.Circuit{100n, 60000n, 60000n, 1n}, 1000, 0}

def opened.every(+path: String, +threshold: Nat, +every: U32, +max: U32) -> IO(R.Runner<String>):
  IO.try(R.Runner<String>, R.open(~String, ~penc, ~pdec, path, max, 1048576, config(threshold, every), 2n))

def opened(+path: String, +threshold: Nat) -> IO(R.Runner<String>):
  opened.every(path, threshold, 0, 4096)

def enq.got(y: R.Runner<String> & R.Out(Nat)) -> IO(R.Runner<String>):
  match y:
    case (r, Done{i}):
      IO.pure(R.Runner<String>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<String>, 1, "bad enqueue: " ++ m)

def enq(r: R.Runner<String>, +d: Nat, +x: String) -> IO(R.Runner<String>):
  do IO<R.Runner<String>>:
    y : R.Runner<String> & R.Out(Nat) <- R.enqueue(~String, ~penc, r, d, x)
    enq.got(y)

def ran(y: R.Ran(String)) -> IO(R.Runner<String>):
  match y:
    case (r, Done{u}):
      IO.pure(R.Runner<String>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<String>, 1, "bad drain: " ++ m)

def drain(r: R.Runner<String>) -> IO(R.Runner<String>):
  do IO<R.Runner<String>>:
    y : R.Ran(String) <- R.drain(~String, ~penc, ~target, ~work, 400n, r)
    ran(y)

def count(xs: List<&2, String>, +x: String) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{+h, t}:
      Nat.add(Bool.pick(Nat, String.eq(h, x), 1n, 0n), count(t, x))

def read.got(r: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  match r:
    case (f, Done{s}):
      do IO<String>:
        File.close(f)
        return s
    case (f, Fail{(c, m)}):
      do IO<String>:
        File.close(f)
        IO.die(String, 1, "bad read: " ++ m)

def read(+path: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    f : File <- IO.try(File, File.open(path, "r"))
    r : File & Result<&1, &1, U32 & String, String> <- File.read(f, 65536)
    s : String <- read.got(r)
    return String.split(s, '\n')

def counts(xs: List<&2, String>, ks: List<&2, String>) -> String:
  match ks:
    case Nil{}:
      ""
    case Con{+k, rest}:
      +ys = xs
      k ++ "=" ++ Nat.show(count(ys, k)) ++ " " ++ counts(ys, rest)

def view.of(x: R.Runner<String> & Model.State<String>) -> R.Runner<String> & String:
  (r, s) = x
  (r, describe(s))

def view(r: R.Runner<String>) -> R.Runner<String> & String:
  view.of(R.state(String, r))

def closed(+want: String, +name: String, x: R.Runner<String> & String) -> IO(Unit):
  (r, got) = x
  do IO<Unit>:
    same(got, want, name)
    R.close(String, r)

def held(x: R.Runner<String> & String, +want: String, +name: String) -> IO(R.Runner<String>):
  (r, got) = x
  do IO<R.Runner<String>>:
    same(got, want, name)
    return r

def dead.of(x: R.Runner<String> & Model.State<String>) -> R.Runner<String> & String:
  (r, s) = x
  (r, graves(Model.dead(String, s)))

def brk.of(x: R.Runner<String> & Model.State<String>) -> R.Runner<String> & String:
  (r, s) = x
  (r, brk(s, "local"))

# Three jobs: two succeed once. One fails every time; after the policy's 3 attempts it is dead, with its payload.
# It stays dead across a reopen, runs 3 attempts again after a revive, and a cancel drops it.
def durable(+dir: String) -> IO(Unit):
  +path = dir ++ "/jobs.journal"
  +log = dir ++ "/jobs.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|ok:a")
    r2 : R.Runner<String> <- enq(r1, 0n, log ++ "|fail:b")
    r3 : R.Runner<String> <- enq(r2, 0n, log ++ "|ok:c")
    r4 : R.Runner<String> <- drain(r3)
    closed("next=3 pending=0 running=0 tries=0 fails=0 dead=1", "drain completes the good jobs and keeps the failing one dead", view(r4))
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["ok:a", "fail:b", "ok:c"]), "ok:a=1 fail:b=3 ok:c=1 ", "a job runs once; a failing job runs the policy's 3 attempts")
    r5 : R.Runner<String> <- opened(path, 100n)
    r6 : R.Runner<String> <- held(view(r5), "next=3 pending=0 running=0 tries=0 fails=0 dead=1", "reopen replays the same state")
    r7 : R.Runner<String> <- held(dead.of(R.state(String, r6)), "1:spent:" ++ log ++ "|fail:b ", "the dead job keeps its payload across a reopen")
    y : R.Ran(String) <- R.revive(~String, ~penc, r7, 1n, 0n)
    r8 : R.Runner<String> <- ran(y)
    r9 : R.Runner<String> <- held(view(r8), "next=3 pending=1 running=0 tries=1 fails=0 dead=0", "revive makes the dead job pending with a new budget")
    r10 : R.Runner<String> <- drain(r9)
    ys : List<&2, String> <- read(log)
    same(counts(ys, ["ok:a", "fail:b", "ok:c"]), "ok:a=1 fail:b=6 ok:c=1 ", "the revived job runs 3 more attempts, and no other job runs again")
    r11 : R.Runner<String> <- held(view(r10), "next=3 pending=0 running=0 tries=0 fails=0 dead=1", "the revived job is dead again")
    z : R.Ran(String) <- R.cancel(~String, ~penc, r11, 1n)
    r12 : R.Runner<String> <- ran(z)
    closed("next=3 pending=0 running=0 tries=0 fails=0 dead=0", "cancel drops a dead job", view(r12))

# A job whose failure another try would repeat is dead after one attempt, with its payload.
def failed(+dir: String) -> IO(Unit):
  +path = dir ++ "/failed.journal"
  +log = dir ++ "/failed.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|dead:f")
    r2 : R.Runner<String> <- drain(r1)
    r3 : R.Runner<String> <- held(view(r2), "next=1 pending=0 running=0 tries=0 fails=0 dead=1", "a failure that would repeat makes the job dead")
    closed("0:failed:" ++ log ++ "|dead:f ", "the dead job keeps its payload and a failed why", dead.of(R.state(String, r3)))
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["dead:f"]), "dead:f=1 ", "a failure that would repeat runs one attempt")

# One failure opens this breaker, but a client error is not the target's failure, so the next job still runs.
def rejected(+dir: String) -> IO(Unit):
  +path = dir ++ "/rejected.journal"
  +log = dir ++ "/rejected.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 1n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|reject:a")
    r2 : R.Runner<String> <- enq(r1, 0n, log ++ "|ok:b")
    r3 : R.Runner<String> <- drain(r2)
    r4 : R.Runner<String> <- held(view(r3), "next=2 pending=0 running=0 tries=0 fails=0 dead=1", "a client error makes its job dead, and the next job completes")
    r5 : R.Runner<String> <- held(brk.of(R.state(String, r4)), "closed", "a client error leaves the breaker closed")
    closed("0:failed:" ++ log ++ "|reject:a ", "the rejected job keeps its payload and a failed why", dead.of(R.state(String, r5)))
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["reject:a", "ok:b"]), "reject:a=1 ok:b=1 ", "a client error runs one attempt")

def status(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> U32:
  match r:
    case Done{(s, o)}:
      s
    case Fail{e}:
      0

# A child completes x, then dies inside y's attempt. On reopen y runs again, and x does not.
def crash(+dir: String) -> IO(Unit):
  +path = dir ++ "/crash.journal"
  +log = path ++ ".log"
  do IO<Unit>:
    c : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("bend", ["crash.bend", "attempt", path], "", 65536, 120000)
    ok(U32.is_eq(status(c), 9), "the child dies inside an attempt")
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["ok:x", "crash:y"]), "ok:x=1 crash:y=1 ", "the child ran x, then started y")
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- held(view(r0), "next=2 pending=1 running=0 tries=1 fails=1 dead=0", "reopen requeues the running y as a failed attempt, and x stays complete")
    r2 : R.Runner<String> <- drain(r1)
    closed("next=2 pending=0 running=0 tries=0 fails=0 dead=0", "the requeued y completes", view(r2))
    ys : List<&2, String> <- read(log)
    same(counts(ys, ["ok:x", "crash:y"]), "ok:x=1 crash:y=2 ", "y runs again after the crash, and the completed x does not")

def left(y: R.Ran(String)) -> IO(R.Runner<String>):
  match y:
    case (r, Fail{(c, m)}):
      do IO<R.Runner<String>>:
        same(m, "runner: drain ran out of rounds", "drain stops while the breaker holds the jobs back")
        return r
    case (r, Done{u}):
      IO.die(R.Runner<String>, 1, "bad breaker: drain finished while the breaker was open")

def root(-A: Data, h: H.Heap<Q.Ticket<A>>) -> Nat:
  match h:
    case H.HLeaf{}:
      0n
    case H.HNode{n, t, l, r}:
      Q.deadline(A, t)

def deferred(+now: Nat, x: R.Runner<String> & Model.State<String>) -> IO(R.Runner<String>):
  (r, s) = x
  Model.State{q, ts, ds, bs} = s
  do IO<R.Runner<String>>:
    ok(Nat.is_le(Nat.add(now, 50000n), root(String, Q.pending(String, q))), "a held job waits for the breaker's cooldown")
    return r

# Two jobs of one target fail at once. The first failure opens the breaker, so no third attempt starts.
def breaker(+dir: String) -> IO(Unit):
  +path = dir ++ "/breaker.journal"
  +log = dir ++ "/breaker.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 1n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|fail:p")
    r2 : R.Runner<String> <- enq(r1, 0n, log ++ "|fail:q")
    y : R.Ran(String) <- R.drain(~String, ~penc, ~target, ~work, 20n, r2)
    r3 : R.Runner<String> <- left(y)
    now : Nat <- R.clock()
    r4 : R.Runner<String> <- deferred(now, R.state(String, r3))
    closed("next=2 pending=2 running=0 tries=2 fails=2 dead=0", "a deferral counts no failure", view(r4))
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["fail:p", "fail:q"]), "fail:p=1 fail:q=1 ", "an open breaker starts no attempt")

# A failing job opens the breaker, and the runner closes. After a reopen the breaker is still open,
# so a new job of the same target waits for the cooldown and starts no attempt.
def breaker.restart(+dir: String) -> IO(Unit):
  +path = dir ++ "/restart.journal"
  +log = dir ++ "/restart.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 1n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|fail:p")
    y : R.Ran(String) <- R.drain(~String, ~penc, ~target, ~work, 20n, r1)
    r2 : R.Runner<String> <- left(y)
    R.close(String, r2)
    r3 : R.Runner<String> <- opened(path, 1n)
    r4 : R.Runner<String> <- enq(r3, 0n, log ++ "|ok:r")
    z : R.Ran(String) <- R.drain(~String, ~penc, ~target, ~work, 20n, r4)
    r5 : R.Runner<String> <- left(z)
    now : Nat <- R.clock()
    r6 : R.Runner<String> <- deferred(now, R.state(String, r5))
    R.close(String, r6)
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["fail:p", "ok:r"]), "fail:p=1 ok:r=0 ", "a reopen keeps the open breaker, and no attempt starts before the cooldown ends")

def stat.size(r: Result<&1, &1, U32 & String, Files.Info>) -> IO(U32):
  match r:
    case Done{Files.Info{k, (hi, lo), t}}:
      do IO<U32>:
        ok(U32.is_eq(hi, 0), "the journal size fits U32")
        return lo
    case Fail{e}:
      IO.die(U32, 1, "stat failed")

def size(+path: String) -> IO(U32):
  do IO<U32>:
    r : Result<&1, &1, U32 & String, Files.Info> <- Files.stat(path)
    stat.size(r)

def compacted(y: R.Ran(String)) -> IO(R.Runner<String>):
  match y:
    case (r, Done{u}):
      IO.pure(R.Runner<String>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<String>, 1, "bad compact: " ++ m)

# The runner back, and the hex of its state's snapshot: equal hex means an equal state.
def state.hex(x: R.Runner<String> & Model.State<String>) -> R.Runner<String> & String:
  (r, s) = x
  (r, hex(s))

def closed.hex(x: R.Runner<String> & String) -> IO(String):
  (r, h) = x
  do IO<String>:
    R.close(String, r)
    return h

def len.of(r: Bytes.Bytes & U32) -> U32:
  (b, n) = r
  n

def state.size(x: R.Runner<String> & Model.State<String>) -> R.Runner<String> & String:
  (r, s) = x
  (r, U32.show((12 + len.of(Bytes.length(Model.encode.snap(~String, ~penc, s))) : U32)))

def far() -> Nat:
  Nat.mul(4000n, 1000000000n)

def compaction.replaced(x: R.Swap) -> IO(Unit):
  match x:
    case R.Moved{j}:
      J.close(j)
    case _:
      IO.die(Unit, 1, "bad failed-reopen fixture: the snapshot did not replace the journal")

def compaction.error(+code: U32, +message: String, x: R.Ran(String)) -> IO(R.Runner<String>):
  match x:
    case (r, Fail{(c, m)}):
      do IO<R.Runner<String>>:
        same(U32.show(c) ++ " " ++ m, U32.show(code) ++ " " ++ message, "failed compaction returns the original reopen error")
        return r
    case (r, Done{u}):
      IO.die(R.Runner<String>, 1, "bad failed-reopen fixture: compaction succeeded")

def compaction.reopen.failed(x: R.Out(J.Journal & Unit), r: R.Runner<String>) -> IO(R.Runner<String>):
  match x:
    case Fail{(+code, +message)}:
      R.Runner{R.Log{j, path, +limit, +base}, s, p, c, ib, fs} = r
      do IO<R.Runner<String>>:
        y : R.Log & R.Out(Unit) <- R.compact.moved(R.swap.reopened(Fail{(code, message)}), j, 4096, path, limit, base)
        compaction.error(code, message, R.compact.done(String, y, s, p, c, ib, fs))
    case Done{(j, u)}:
      do IO<R.Runner<String>>:
        J.close(j)
        R.close(String, r)
        IO.die(R.Runner<String>, 1, "bad failed-reopen fixture: the zero file limit allowed a snapshot")

def compaction.refused(x: R.Runner<String> & R.Out(Nat)) -> IO(R.Runner<String>):
  match x:
    case (r, Fail{(c, m)}):
      do IO<R.Runner<String>>:
        same(U32.show(c) ++ " " ++ m, "5 journal: an append failed; reopen the journal", "the replaced old journal refuses an append")
        return r
    case (r, Done{i}):
      IO.die(R.Runner<String>, 1, "bad compaction: the replaced old journal accepted an append")

def compaction.stranded.state(x: R.Runner<String> & Model.State<String>, +path: String) -> IO(Unit):
  (r, +s) = x
  do IO<Unit>:
    moved : R.Swap <- R.swap(path, 1048576, Model.encode.snap(~String, ~penc, s))
    compaction.replaced(moved)
    failed : R.Out(J.Journal & Unit) <- J.open(~Unit, ~(a => b => a), path, 1048576, 0, Unit{})
    r1 : R.Runner<String> <- compaction.reopen.failed(failed, r)
    r2 : R.Runner<String> <- held(state.hex(R.state(String, r1)), hex(s), "failed compaction keeps the live state")
    appended : R.Runner<String> & R.Out(Nat) <- R.enqueue(~String, ~penc, r2, far(), "refused")
    r3 : R.Runner<String> <- compaction.refused(appended)
    closed(hex(s), "a refused append does not change the live state", state.hex(R.state(String, r3)))
    r4 : R.Runner<String> <- opened(path, 100n)
    r5 : R.Runner<String> <- held(state.hex(R.state(String, r4)), hex(s), "reopen recovers every acknowledged job from the renamed snapshot")
    r6 : R.Runner<String> <- enq(r5, far(), "after reopen")
    want : String <- closed.hex(state.hex(R.state(String, r6)))
    r7 : R.Runner<String> <- opened(path, 100n)
    closed(want, "appends resume durably after reopening the snapshot", state.hex(R.state(String, r7)))

# A zero read limit fails only the check's reopen, after a real snapshot rename.
def compaction.stranded(+dir: String) -> IO(Unit):
  +path = dir ++ "/stranded.journal"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, far(), "acknowledged a")
    r2 : R.Runner<String> <- enq(r1, far(), "acknowledged b")
    compaction.stranded.state(R.state(String, r2), path)

# Three jobs drain, a fourth waits; compaction keeps only the live state, and reopen replays it, then the records after it.
# max fits the longest op record: an Enqueue, 12 octets and the payload, or a Break of "local" with three failures, 60 octets.
# The snapshot of one waiting job does not fit it.
def compaction(+dir: String) -> IO(Unit):
  +path = dir ++ "/compact.journal"
  +log = dir ++ "/compact.log"
  +max = (Bytes.count(log, 0) + 60 : U32)
  do IO<Unit>:
    r0 : R.Runner<String> <- opened.every(path, 100n, 0, max)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|ok:a")
    r2 : R.Runner<String> <- enq(r1, 0n, log ++ "|fail:b")
    r3 : R.Runner<String> <- enq(r2, 0n, log ++ "|ok:c")
    r4 : R.Runner<String> <- drain(r3)
    r5 : R.Runner<String> <- enq(r4, far(), log ++ "|ok:d")
    before : U32 <- size(path)
    y : R.Ran(String) <- R.compact(~String, ~penc, r5)
    r6 : R.Runner<String> <- compacted(y)
    +after : U32 <- size(path)
    ok(U32.is_lt(after, before), "compaction shrinks the journal")
    ok(U32.is_gt(after, (max + 12 : U32)), "the snapshot is larger than max")
    left : Bool <- Files.exists(path ++ ".compact")
    ok(Bool.not(left), "compaction leaves no temporary file")
    r7 : R.Runner<String> <- enq(r6, far(), log ++ "|ok:e")
    want : String <- closed.hex(state.hex(R.state(String, r7)))
    r8 : R.Runner<String> <- opened.every(path, 100n, 0, max)
    r9 : R.Runner<String> <- held(state.hex(R.state(String, r8)), want, "reopen replays the snapshot and the records after it to the same state")
    closed("next=5 pending=2 running=0 tries=2 fails=0 dead=1", "the compacted journal keeps the waiting and dead jobs and drops the finished ones", view(r9))
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["ok:a", "fail:b", "ok:c"]), "ok:a=1 fail:b=3 ok:c=1 ", "no finished job runs again after compaction")

# compact = 1: every tick compacts, so after the drain the journal is one snapshot frame.
def compaction.auto(+dir: String) -> IO(Unit):
  +path = dir ++ "/auto.journal"
  +log = dir ++ "/auto.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened.every(path, 100n, 1, 4096)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|ok:a")
    r2 : R.Runner<String> <- enq(r1, 0n, log ++ "|fail:b")
    r3 : R.Runner<String> <- drain(r2)
    n : U32 <- size(path)
    r4 : R.Runner<String> <- held(state.size(R.state(String, r3)), U32.show(n), "the journal is one frame that holds the snapshot")
    closed("next=2 pending=0 running=0 tries=0 fails=0 dead=1", "tick compacts and keeps the state", view(r4))
    r5 : R.Runner<String> <- opened(path, 100n)
    closed("next=2 pending=0 running=0 tries=0 fails=0 dead=1", "reopen after automatic compaction replays the same state", view(r5))

# Two jobs die, then a third. A purge at a time between them drops the first two as one record.
# It survives a reopen and a compaction, and a later purge of all dead jobs survives a reopen.
def purged(+dir: String) -> IO(Unit):
  +path = dir ++ "/purge.journal"
  +log = dir ++ "/purge.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|dead:a")
    r2 : R.Runner<String> <- enq(r1, 0n, log ++ "|dead:b")
    r3 : R.Runner<String> <- drain(r2)
    t : Nat <- R.clock()
    IO.sleep(5)
    r4 : R.Runner<String> <- enq(r3, 0n, log ++ "|dead:c")
    r5 : R.Runner<String> <- drain(r4)
    y : R.Ran(String) <- R.purge(~String, ~penc, r5, Nat.add(t, 1n))
    r6 : R.Runner<String> <- ran(y)
    closed("next=3 pending=0 running=0 tries=0 fails=0 dead=1", "purge drops the jobs that died before its time", view(r6))
    r7 : R.Runner<String> <- opened(path, 100n)
    r8 : R.Runner<String> <- held(dead.of(R.state(String, r7)), "2:failed:" ++ log ++ "|dead:c ", "a purge survives a reopen")
    z : R.Ran(String) <- R.compact(~String, ~penc, r8)
    r9 : R.Runner<String> <- compacted(z)
    R.close(String, r9)
    r10 : R.Runner<String> <- opened(path, 100n)
    r11 : R.Runner<String> <- held(dead.of(R.state(String, r10)), "2:failed:" ++ log ++ "|dead:c ", "a purge survives compaction")
    p : R.Ran(String) <- R.purge.all(~String, ~penc, r11)
    r12 : R.Runner<String> <- ran(p)
    R.close(String, r12)
    r13 : R.Runner<String> <- opened(path, 100n)
    closed("next=3 pending=0 running=0 tries=0 fails=0 dead=0", "a purge of all dead jobs survives a reopen", view(r13))

def found.hex(m: Maybe<&2, Model.State<String>>) -> String:
  match m:
    case None{}:
      "none"
    case Some{s}:
      hex(s)

def found(m: J.Journal & Maybe<&2, Model.State<String>>) -> IO(String):
  (j, s) = m
  do IO<String>:
    J.close(j)
    return found.hex(s)

# The state in the snapshot file that a crashed compaction left behind.
def snapshot.hex(+path: String) -> IO(String):
  do IO<String>:
    m : J.Journal & Maybe<&2, Model.State<String>> <- IO.try(J.Journal & Maybe<&2, Model.State<String>>,
      J.open(~Maybe<&2, Model.State<String>>, ~(a => b => Model.replay.step(~String, ~pdec, a, b)), path, 1048576, 1048576, Some{Model.new(String)}))
    found(m)

# A child completes x, writes the snapshot, and dies before the rename. Reopen gives the state of the snapshot, and x does not run again.
def crash.snapshot(+dir: String) -> IO(Unit):
  +path = dir ++ "/snap.journal"
  +log = path ++ ".log"
  do IO<Unit>:
    c : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("bend", ["crash.bend", "snapshot", path], "", 65536, 120000)
    ok(U32.is_eq(status(c), 9), "the child dies after the snapshot is durable and before the rename")
    +want : String <- snapshot.hex(path ++ ".compact")
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- held(state.hex(R.state(String, r0)), want, "reopen after a crash inside compaction gives the same state")
    y : R.Ran(String) <- R.compact(~String, ~penc, r1)
    r2 : R.Runner<String> <- compacted(y)
    R.close(String, r2)
    r3 : R.Runner<String> <- opened(path, 100n)
    r4 : R.Runner<String> <- held(state.hex(R.state(String, r3)), want, "a later compaction replaces the stale snapshot and keeps the state")
    r5 : R.Runner<String> <- held(view(r4), "next=2 pending=1 running=0 tries=1 fails=0 dead=0", "x stays complete, and y waits")
    z : R.Ran(String) <- R.cancel(~String, ~penc, r5, 1n)
    r6 : R.Runner<String> <- ran(z)
    r7 : R.Runner<String> <- drain(r6)
    R.close(String, r7)
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["ok:x", "ok:y"]), "ok:x=1 ok:y=0 ", "the completed x does not run again")

# A child completes x, compacts, then dies inside z's attempt. Reopen replays the snapshot and z's records, and requeues z.
def crash.compacted(+dir: String) -> IO(Unit):
  +path = dir ++ "/compacted.journal"
  +log = path ++ ".log"
  do IO<Unit>:
    c : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("bend", ["crash.bend", "compacted", path], "", 65536, 120000)
    ok(U32.is_eq(status(c), 9), "the child dies inside an attempt after compaction")
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- held(view(r0), "next=2 pending=1 running=0 tries=1 fails=1 dead=0", "reopen requeues the running z, and x stays complete")
    r2 : R.Runner<String> <- drain(r1)
    R.close(String, r2)
    xs : List<&2, String> <- read(log)
    same(counts(xs, ["ok:x", "crash:z"]), "ok:x=1 crash:z=2 ", "z runs again after the crash, and the completed x does not")

def ticked(t: R.Runner<String> & R.Out(Bool)) -> IO(R.Runner<String>):
  match t:
    case (r, Done{b}):
      IO.pure(R.Runner<String>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<String>, 1, "bad tick: " ++ m)

# The most attempts that run at once in a log: a job line starts one, and an "end" line ends one.
def peak(xs: List<&2, String>, +cur: Nat, +best: Nat) -> Nat:
  match xs:
    case Nil{}:
      best
    case Con{+h, t}:
      +c = Bool.pick(Nat, String.starts_with(h, "end "), Nat.sub(cur, 1n), Bool.pick(Nat, String.eq(h, ""), cur, Nat.add(cur, 1n)))
      peak(t, c, Bool.pick(Nat, Nat.is_lt(best, c), c, best))

def last(xs: List<&2, String>, +acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case Con{+h, t}:
      last(t, Bool.pick(String, String.eq(h, ""), acc, h))

# Capacity 2: a slow job and five fast jobs. One tick runs them all, and the fast jobs finish in the free unit while the slow one runs.
def overlap(+dir: String) -> IO(Unit):
  +path = dir ++ "/overlap.journal"
  +log = dir ++ "/overlap.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|slow:s")
    r2 : R.Runner<String> <- enq(r1, 0n, log ++ "|ok:f1")
    r3 : R.Runner<String> <- enq(r2, 0n, log ++ "|ok:f2")
    r4 : R.Runner<String> <- enq(r3, 0n, log ++ "|ok:f3")
    r5 : R.Runner<String> <- enq(r4, 0n, log ++ "|ok:f4")
    r6 : R.Runner<String> <- enq(r5, 0n, log ++ "|ok:f5")
    t : R.Runner<String> & R.Out(Bool) <- R.tick(~String, ~penc, ~target, ~work, r6)
    r7 : R.Runner<String> <- ticked(t)
    closed("next=6 pending=0 running=0 tries=0 fails=0 dead=0", "one tick runs a slow job and five fast jobs", view(r7))
    +ys : List<&2, String> <- read(log)
    same(Nat.show(peak(ys, 0n, 0n)), "2", "no more attempts run at once than the capacity")
    same(last(ys, ""), "end slow:s", "the fast jobs finish while the slow job runs")

def answered(+log: String, y: R.Out(Nat)) -> IO(Unit):
  match y:
    case Done{i}:
      note(log, "answered " ++ Nat.show(i))
    case Fail{(c, m)}:
      note(log, "refused " ++ m)

def cancelled(+log: String, y: R.Out(Unit)) -> IO(Unit):
  match y:
    case Done{u}:
      note(log, "cancelled")
    case Fail{(c, m)}:
      note(log, "refused " ++ m)

# Another fiber enqueues job n 200 ms into an attempt that runs 1 s.
def adder(ib: Chan(R.Msg<String>), +log: String) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(200)
    y : R.Out(Nat) <- R.ask.enqueue(String, ib, 0n, log ++ "|ok:n")
    answered(log, y)

# Another fiber cancels ticket 0 200 ms into its attempt.
def canceller(ib: Chan(R.Msg<String>), +log: String) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(200)
    y : R.Out(Unit) <- R.ask.cancel(String, ib, 0n)
    cancelled(log, y)

# Starts act with the runner's inbox on its own fiber, then drains, then waits for act.
def beside(x: R.Runner<String> & Chan(R.Msg<String>), act: Chan(R.Msg<String>) -> IO(Unit)) -> IO(R.Runner<String>):
  (r, ib) = x
  do IO<R.Runner<String>>:
    ch : Chan(Unit) <- IO.fork(Unit, act(ib))
    r2 : R.Runner<String> <- drain(r)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    return r2

# Capacity 2: while a slow job runs, another fiber enqueues a job. The enqueue answers before the slow job ends, and the new job runs in the same drain.
def asks(+dir: String) -> IO(Unit):
  +path = dir ++ "/asks.journal"
  +log = dir ++ "/asks.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|slow:s")
    r2 : R.Runner<String> <- beside(R.inbox(String, r1), ib => adder(ib, log))
    closed("next=2 pending=0 running=0 tries=0 fails=0 dead=0", "a job that another fiber enqueues runs in the same drain", view(r2))
    +ys : List<&2, String> <- read(log)
    same(counts(ys, ["answered 1", "ok:n", "end ok:n"]), "answered 1=1 ok:n=1 end ok:n=1 ", "the enqueue answers its id, and the new job runs once")
    same(last(ys, ""), "end slow:s", "the enqueue answers, and the new job ends, before the slow job ends")

# Another fiber cancels a failing job while its attempt runs. Its outcome does not requeue it, and the cancel survives a reopen.
def asks.cancel(+dir: String) -> IO(Unit):
  +path = dir ++ "/cancel.journal"
  +log = dir ++ "/cancel.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|slowfail:c")
    r2 : R.Runner<String> <- beside(R.inbox(String, r1), ib => canceller(ib, log))
    closed("next=1 pending=0 running=0 tries=0 fails=0 dead=0", "a ticket cancelled while it runs stays cancelled after its attempt ends", view(r2))
    +ys : List<&2, String> <- read(log)
    same(counts(ys, ["slowfail:c", "cancelled"]), "slowfail:c=1 cancelled=1 ", "the cancel answers, and the failed attempt does not run again")
    r3 : R.Runner<String> <- opened(path, 100n)
    closed("next=1 pending=0 running=0 tries=0 fails=0 dead=0", "reopen replays the cancel", view(r3))

def reviver(ib: Chan(R.Msg<String>), +log: String) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(200)
    u : Unit <- IO.try(Unit, R.ask.revive(String, ib, 0n, 0n))
    note(log, "revived")

def asks.revive(+dir: String) -> IO(Unit):
  +path = dir ++ "/ask-revive.journal"
  +log = dir ++ "/ask-revive.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|dead:r")
    r2 : R.Runner<String> <- drain(r1)
    r3 : R.Runner<String> <- enq(r2, 0n, log ++ "|slow:s")
    r4 : R.Runner<String> <- beside(R.inbox(String, r3), ib => reviver(ib, log))
    closed("next=2 pending=0 running=0 tries=0 fails=0 dead=1", "the revived ticket runs in the same drain", view(r4))
    +ys : List<&2, String> <- read(log)
    same(counts(ys, ["revived", "dead:r", "end dead:r"]), "revived=1 dead:r=2 end dead:r=2 ", "revive answers and runs the original payload again")
    same(last(ys, ""), "end slow:s", "revive answers and its attempt ends before the slow job ends")

def purge.ask(all: Bool, ib: Chan(R.Msg<String>), +before: Nat) -> IO(R.Out(Unit)):
  match all:
    case True{}:
      R.ask.purge.all(String, ib)
    case False{}:
      R.ask.purge(String, ib, before)

def purger(+all: Bool, ib: Chan(R.Msg<String>), +before: Nat, +log: String) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(200)
    u : Unit <- IO.try(Unit, purge.ask(all, ib, before))
    note(log, "purged")

def asks.purge(+dir: String) -> IO(Unit):
  +path = dir ++ "/ask-purge.journal"
  +log = dir ++ "/ask-purge.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|dead:a")
    r2 : R.Runner<String> <- drain(r1)
    +t : Nat <- R.clock()
    IO.sleep(5)
    r3 : R.Runner<String> <- enq(r2, 0n, log ++ "|dead:b")
    r4 : R.Runner<String> <- drain(r3)
    r5 : R.Runner<String> <- enq(r4, 0n, log ++ "|slow:s")
    r6 : R.Runner<String> <- beside(R.inbox(String, r5), ib => purger(False{}, ib, Nat.add(t, 1n), log))
    closed("next=3 pending=0 running=0 tries=0 fails=0 dead=1", "ask.purge retains the newer grave", view(r6))
    r7 : R.Runner<String> <- opened(path, 100n)
    r8 : R.Runner<String> <- held(dead.of(R.state(String, r7)), "1:failed:" ++ log ++ "|dead:b ", "ask.purge survives reopen")
    r9 : R.Runner<String> <- enq(r8, 0n, log ++ "|slow:s")
    r10 : R.Runner<String> <- beside(R.inbox(String, r9), ib => purger(True{}, ib, 0n, log))
    closed("next=4 pending=0 running=0 tries=0 fails=0 dead=0", "ask.purge.all removes the remaining grave", view(r10))
    +ys : List<&2, String> <- read(log)
    same(counts(ys, ["purged"]), "purged=2 ", "both purge asks answer while the runner drains")
    same(last(ys, ""), "end slow:s", "purge.all answers before the slow job ends")
    r11 : R.Runner<String> <- opened(path, 100n)
    closed("next=4 pending=0 running=0 tries=0 fails=0 dead=0", "ask.purge.all survives reopen", view(r11))

def refused(y: R.Out(Unit)) -> IO(Unit):
  match y:
    case Done{u}:
      IO.die(Unit, 1, "a closed runner accepted an ask")
    case Fail{(c, m)}:
      same(U32.show(c) ++ " " ++ m, "32 runner: the runner closed", "close refuses the queued ask")

def closing.ask(x: R.Runner<String> & Chan(R.Msg<String>), act: Chan(R.Msg<String>) -> IO(R.Out(Unit))) -> IO(Unit):
  (r, ib) = x
  do IO<Unit>:
    ch : Chan(Unit) <- IO.fork(Unit, IO.bind(R.Out(Unit), Unit, act(ib), refused))
    IO.sleep(100)
    R.close(String, r)
    u : Unit <- IO.join(Unit, ch)
    return Unit{}

def asks.close.admin(+dir: String) -> IO(Unit):
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(dir ++ "/close-revive.journal", 100n)
    closing.ask(R.inbox(String, r0), ib => R.ask.revive(String, ib, 0n, 0n))
    r1 : R.Runner<String> <- opened(dir ++ "/close-purge.journal", 100n)
    closing.ask(R.inbox(String, r1), ib => R.ask.purge(String, ib, 0n))
    r2 : R.Runner<String> <- opened(dir ++ "/close-purge-all.journal", 100n)
    closing.ask(R.inbox(String, r2), ib => R.ask.purge.all(String, ib))

def asker(ib: Chan(R.Msg<String>), +log: String) -> IO(Unit):
  do IO<Unit>:
    y : R.Out(Nat) <- R.ask.enqueue(String, ib, 0n, log ++ "|ok:late")
    answered(log, y)

def joined(m: Maybe<&1, Unit>) -> String:
  match m:
    case None{}:
      "timed out"
    case Some{u}:
      "returned"

# Starts an asker beside the idle runner, closes the runner, and says whether the asker returned within 3 s.
def closing(x: R.Runner<String> & Chan(R.Msg<String>), +log: String) -> IO(String):
  (r, ib) = x
  do IO<String>:
    ch : Chan(Unit) <- IO.fork(Unit, asker(ib, log))
    IO.sleep(100)
    R.close(String, r)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    return joined(m)

# Another fiber enqueues while no tick runs, then the owner closes. The ask fails, and no Enqueue reaches the journal.
def asks.close(+dir: String) -> IO(Unit):
  +path = dir ++ "/close.journal"
  +log = dir ++ "/close.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- opened(path, 100n)
    j : String <- closing(R.inbox(String, r0), log)
    same(j, "returned", "an ask in the inbox at close returns")
    ys : List<&2, String> <- read(log)
    same(counts(ys, ["refused runner: the runner closed"]), "refused runner: the runner closed=1 ", "close answers the ask with a failure")
    r2 : R.Runner<String> <- opened(path, 100n)
    closed("next=0 pending=0 running=0 tries=0 fails=0 dead=0", "reopen finds no Enqueue for the refused ask", view(r2))

def prompt(+log: String, m: Maybe<&1, R.Out(Nat)>) -> IO(Unit):
  match m:
    case None{}:
      note(log, "late")
    case Some{y}:
      answered(log, y)

# Another fiber enqueues job n 100 ms into the drain's idle wait, and needs its answer within 500 ms.
def waker(ib: Chan(R.Msg<String>), +log: String) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(100)
    m : Maybe<&1, R.Out(Nat)> <- IO.within(R.Out(Nat), 500, R.ask.enqueue(String, ib, 0n, log ++ "|ok:n"))
    prompt(log, m)

# Idle 1 s, and one job due in 1.5 s. An ask during the idle wait answers at once, and its job runs in the same drain.
def asks.idle(+dir: String) -> IO(Unit):
  +path = dir ++ "/idle.journal"
  +log = dir ++ "/idle.log"
  +c = config.idle()
  do IO<Unit>:
    r0 : R.Runner<String> <- IO.try(R.Runner<String>, R.open(~String, ~penc, ~pdec, path, 4096, 1048576, c, 2n))
    now : Nat <- R.clock()
    r1 : R.Runner<String> <- enq(r0, Nat.add(now, 1500n), log ++ "|ok:d")
    r2 : R.Runner<String> <- beside(R.inbox(String, r1), ib => waker(ib, log))
    closed("next=2 pending=0 running=0 tries=0 fails=0 dead=0", "a job enqueued during the idle wait runs in the same drain", view(r2))
    +ys : List<&2, String> <- read(log)
    same(counts(ys, ["answered 1", "late", "end ok:n"]), "answered 1=1 late=0 end ok:n=1 ", "an ask during the idle wait answers within 500 ms")
    same(last(ys, ""), "end ok:d", "the asked job ends before the job due later")

# Idle 1 s, and one job due in 100 ms. The drain starts it near its deadline, not after the whole idle wait.
def asks.due(+dir: String) -> IO(Unit):
  +path = dir ++ "/due.journal"
  +log = dir ++ "/due.log"
  do IO<Unit>:
    r0 : R.Runner<String> <- IO.try(R.Runner<String>, R.open(~String, ~penc, ~pdec, path, 4096, 1048576, config.idle(), 2n))
    +t0 : Nat <- R.clock()
    r1 : R.Runner<String> <- enq(r0, Nat.add(t0, 100n), log ++ "|ok:d")
    r2 : R.Runner<String> <- drain(r1)
    t1 : Nat <- R.clock()
    closed("next=1 pending=0 running=0 tries=0 fails=0 dead=0", "a job due before idle ends runs", view(r2))
    same(Bool.pick(String, Nat.is_lt(Nat.sub(t1, t0), 600n), "early", "late"), "early", "the drain starts a job due in 100 ms well before idle ends")

def all(+dir: String) -> IO(Unit):
  do IO<Unit>:
    durable(dir)
    failed(dir)
    rejected(dir)
    purged(dir)
    crash(dir)
    breaker(dir)
    breaker.restart(dir)
    overlap(dir)
    asks(dir)
    asks.cancel(dir)
    asks.revive(dir)
    asks.purge(dir)
    asks.close(dir)
    asks.close.admin(dir)
    asks.idle(dir)
    asks.due(dir)
    compaction(dir)
    compaction.auto(dir)
    compaction.stranded(dir)
    crash.snapshot(dir)
    crash.compacted(dir)
    Example.run(dir ++ "/hooks.journal")

def main() -> IO(Unit):
  do IO<Unit>:
    codec()
    snapshots()
    dir : String <- IO.try(String, Files.temp_dir())
    all(dir)
