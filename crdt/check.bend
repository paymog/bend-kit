# Three replicas count events and exchange CBOR states with duplicates,
# reordering, and a stale copy. All three converge to the same state. The
# dense GCounter runs replicas 0, 1, and 2; the KCounter runs sparse IDs.
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-cbor@0.3.0.0/cbor.bend as Cbor
import ./crdt.bend as Crdt

def A() -> Nat:
  0n

def B() -> Nat:
  1n

def C() -> Nat:
  2n

# A replica accepts at most this many entries from the wire.
def CAP() -> U32:
  8

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def show.counts(s: List<&2, U32>) -> List<&2, String>:
  match s:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      Con{U32.show(c), show.counts(t)}

def show(m: Maybe<&2, List<&2, U32>>) -> String:
  match m:
    case None{}:
      "none"
    case Some{s}:
      "[" ++ String.join(show.counts(s), ", ") ++ "]"

def show.total(m: Maybe<&2, U32>) -> String:
  match m:
    case None{}:
      "overflow"
    case Some{v}:
      U32.show(v)

def show.value(m: Maybe<&2, List<&2, U32>>) -> String:
  match m:
    case None{}:
      "none"
    case Some{s}:
      show.total(Crdt.GCounter.value(s))

# A local event at replica i.
def bump(m: Maybe<&2, List<&2, U32>>, i: Nat) -> Maybe<&2, List<&2, U32>>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Crdt.GCounter.inc(s, i)

def bumps(n: Nat, m: Maybe<&2, List<&2, U32>>, +i: Nat) -> Maybe<&2, List<&2, U32>>:
  match n:
    case 0n:
      m
    case 1n+p:
      bumps(p, bump(m, i), i)

# The bytes a replica sends.
def send(m: Maybe<&2, List<&2, U32>>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Crdt.GCounter.encode(s)

def merge.in(s: List<&2, U32>, d: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match d:
    case None{}:
      None{}
    case Some{t}:
      Some{Crdt.GCounter.merge(s, t)}

def recv.go(s: List<&2, U32>, w: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, List<&2, U32>>:
  match w:
    case None{}:
      None{}
    case Some{b}:
      merge.in(s, Crdt.GCounter.decode(b, CAP()))

# Decodes the bytes at the receiver and merges them into its state.
def recv(m: Maybe<&2, List<&2, U32>>, w: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, List<&2, U32>>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      recv.go(s, w)

def expect(+m: Maybe<&2, List<&2, U32>>, +want: String, +total: String, +name: String) -> IO(Unit):
  do IO<Unit>:
    +got : String = show(m)
    ok(String.eq(got, want), name ++ " holds " ++ got)
    +sum : String = show.value(m)
    ok(String.eq(sum, total), name ++ " counts " ++ sum)

def decode.hex.go(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, List<&2, U32>>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Crdt.GCounter.decode(b, CAP())

def decode.hex(+hex: String) -> Maybe<&2, List<&2, U32>>:
  decode.hex.go(Bytes.from_hex(hex))

def rejects(+hex: String, +name: String) -> IO(Unit):
  ok(String.eq(show(decode.hex(hex)), "none"), name)

# KCounter replicas with IDs that are far apart.
def KA() -> U32:
  7

def KB() -> U32:
  1000000

def KC() -> U32:
  4000000000

def kenc(id: U32) -> Cbor.Val:
  Cbor.UInt{Cbor.W64{0, id}}

def kdec.word(ok: Bool, +lo: U32) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{lo}
    case False{}:
      None{}

def kdec(v: Cbor.Val) -> Maybe<&2, U32>:
  match v:
    case Cbor.UInt{w}:
      Cbor.W64{+hi, +lo} = w
      kdec.word(U32.is_eq(hi, 0), lo)
    case _:
      None{}

def kshow.entries(s: Crdt.KCounter<U32>) -> List<&2, String>:
  match s:
    case Crdt.KNil{}:
      Nil{}
    case Crdt.KCon{id, c, r}:
      Con{U32.show(id) ++ ": " ++ U32.show(c), kshow.entries(r)}

def kshow(m: Maybe<&2, Crdt.KCounter<U32>>) -> String:
  match m:
    case None{}:
      "none"
    case Some{s}:
      "{" ++ String.join(kshow.entries(s), ", ") ++ "}"

def kshow.value(m: Maybe<&2, Crdt.KCounter<U32>>) -> String:
  match m:
    case None{}:
      "none"
    case Some{s}:
      show.total(Crdt.KCounter.value(U32, s))

def kbump(m: Maybe<&2, Crdt.KCounter<U32>>, +id: U32) -> Maybe<&2, Crdt.KCounter<U32>>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Crdt.KCounter.inc(~U32, ~U32.cmp, s, id)

def kbumps(n: Nat, m: Maybe<&2, Crdt.KCounter<U32>>, +id: U32) -> Maybe<&2, Crdt.KCounter<U32>>:
  match n:
    case 0n:
      m
    case 1n+p:
      kbumps(p, kbump(m, id), id)

def ksend(m: Maybe<&2, Crdt.KCounter<U32>>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Crdt.KCounter.encode(~U32, ~kenc, s)

def kmerge.in(s: Crdt.KCounter<U32>, d: Maybe<&2, Crdt.KCounter<U32>>) -> Maybe<&2, Crdt.KCounter<U32>>:
  match d:
    case None{}:
      None{}
    case Some{t}:
      Some{Crdt.KCounter.merge(~U32, ~U32.cmp, s, t)}

def kdecode(b: Bytes.Bytes) -> Maybe<&2, Crdt.KCounter<U32>>:
  Crdt.KCounter.decode(~U32, ~U32.cmp, ~kdec, b, CAP())

def krecv.go(s: Crdt.KCounter<U32>, w: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, Crdt.KCounter<U32>>:
  match w:
    case None{}:
      None{}
    case Some{b}:
      kmerge.in(s, kdecode(b))

def krecv(m: Maybe<&2, Crdt.KCounter<U32>>, w: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, Crdt.KCounter<U32>>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      krecv.go(s, w)

def kexpect(+m: Maybe<&2, Crdt.KCounter<U32>>, +want: String, +total: String, +name: String) -> IO(Unit):
  do IO<Unit>:
    +got : String = kshow(m)
    ok(String.eq(got, want), name ++ " holds " ++ got)
    +sum : String = kshow.value(m)
    ok(String.eq(sum, total), name ++ " counts " ++ sum)

def kdecode.hex.go(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, Crdt.KCounter<U32>>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      kdecode(b)

def krejects(+hex: String, +name: String) -> IO(Unit):
  ok(String.eq(kshow(kdecode.hex.go(Bytes.from_hex(hex))), "none"), name)

def ksparse() -> IO(Unit):
  do IO<Unit>:
    +zero : Maybe<&2, Crdt.KCounter<U32>> = Some{Crdt.KCounter.new(U32)}
    +a0 : Maybe<&2, Crdt.KCounter<U32>> = kbumps(3n, zero, KA())
    +b0 : Maybe<&2, Crdt.KCounter<U32>> = kbumps(2n, zero, KB())
    +c0 : Maybe<&2, Crdt.KCounter<U32>> = kbumps(1n, zero, KC())
    kexpect(a0, "{7: 3}", "3", "replica 7 after 3 events")
    kexpect(b0, "{1000000: 2}", "2", "replica 1000000 after 2 events")
    kexpect(c0, "{4000000000: 1}", "1", "replica 4000000000 after 1 event")
    # The same exchange as the dense counters, on sparse IDs.
    +b1 : Maybe<&2, Crdt.KCounter<U32>> = krecv(krecv(b0, ksend(a0)), ksend(a0))
    +c1 : Maybe<&2, Crdt.KCounter<U32>> = krecv(c0, ksend(b1))
    +a1 : Maybe<&2, Crdt.KCounter<U32>> = krecv(a0, ksend(c1))
    +b2 : Maybe<&2, Crdt.KCounter<U32>> = krecv(b1, ksend(c1))
    +c2 : Maybe<&2, Crdt.KCounter<U32>> = krecv(c1, ksend(a0))
    +all : String = "{7: 3, 1000000: 2, 4000000000: 1}"
    kexpect(a1, all, "6", "replica 7 after the exchange")
    kexpect(b2, all, "6", "replica 1000000 after a duplicate and a relay")
    kexpect(c2, all, "6", "replica 4000000000 after a stale copy")
    +a2 : Maybe<&2, Crdt.KCounter<U32>> = kbump(a1, KA())
    +c3 : Maybe<&2, Crdt.KCounter<U32>> = krecv(c2, ksend(a2))
    +b3 : Maybe<&2, Crdt.KCounter<U32>> = krecv(krecv(b2, ksend(c3)), ksend(a1))
    +more : String = "{7: 4, 1000000: 2, 4000000000: 1}"
    kexpect(a2, more, "7", "replica 7 after one more event")
    kexpect(b3, more, "7", "replica 1000000 after reordered updates")
    kexpect(c3, more, "7", "replica 4000000000 after the update")
    IO.print("sparse wire " ++ Bytes.to_hex(Maybe.default(&1, Bytes.Bytes, ksend(a2), Bytes.from_string(""))))
    krejects("a207001a000f424001", "the sparse wire rejects a count of 0")
    krejects("a21a000f4240010701", "the sparse wire rejects IDs out of order")
    krejects("a20701", "the sparse wire rejects a truncated map")
    krejects("8107", "the sparse wire rejects an array")
    krejects("a12001", "the sparse wire rejects an ID that dec refuses")

def pn.show.value(m: Maybe<&1, Bool & U32>) -> String:
  match m:
    case None{}:
      "overflow"
    case Some{(negative, n)}:
      Bool.pick(String, negative, "-", "") ++ U32.show(n)

def pn.show(m: Maybe<&2, Crdt.PNCounter>) -> String:
  match m:
    case None{}:
      "none"
    case Some{s}:
      pn.show.value(Crdt.PNCounter.value(s))

def pn.decode(m: Maybe<&1, Bytes.Bytes>, cap: U32) -> Maybe<&2, Crdt.PNCounter>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Crdt.PNCounter.decode(b, cap)

def pn.recv(m: Maybe<&2, Crdt.PNCounter>, d: Maybe<&2, Crdt.PNCounter>) -> Maybe<&2, Crdt.PNCounter>:
  do Maybe<&2, Crdt.PNCounter>:
    s : Crdt.PNCounter <- m
    t : Crdt.PNCounter <- d
    return Crdt.PNCounter.merge(s, t)

def pn.rejects(hex: String, cap: U32, name: String) -> IO(Unit):
  ok(String.eq(pn.show(pn.decode(Bytes.from_hex(hex), cap)), "none"), name)

def pn.check() -> IO(Unit):
  do IO<Unit>:
    +a : Crdt.PNCounter = Crdt.PN{[1], []}
    +b : Crdt.PNCounter = Crdt.PN{[], [0, 1]}
    +b2 : Crdt.PNCounter = Crdt.PN{[], [0, 2]}
    ok(String.eq(pn.show(Crdt.PNCounter.inc(Crdt.PNCounter.new(), 0n)), "1"), "PN increment")
    ok(String.eq(pn.show(Crdt.PNCounter.dec(Crdt.PNCounter.new(), 1n)), "-1"), "PN decrement")
    ok(String.eq(pn.show(Some{a}), "1"), "PN starts above zero")
    +zero : Maybe<&2, Crdt.PNCounter> = pn.recv(Some{a}, pn.decode(Crdt.PNCounter.encode(b), CAP()))
    ok(String.eq(pn.show(zero), "0"), "PN reaches zero")
    +negative : Maybe<&2, Crdt.PNCounter> = pn.recv(Some{a}, pn.decode(Crdt.PNCounter.encode(b2), CAP()))
    +reordered : Maybe<&2, Crdt.PNCounter> = pn.recv(pn.recv(negative, pn.decode(Crdt.PNCounter.encode(b), CAP())),
      pn.decode(Crdt.PNCounter.encode(b2), CAP()))
    ok(String.eq(pn.show(reordered), "-1"), "PN crosses zero despite reordered and duplicate states")
    ok(String.eq(pn.show(pn.recv(Some{b2}, pn.decode(Crdt.PNCounter.encode(a), CAP()))), "-1"),
      "PN peers converge across the wire")
    ok(String.eq(pn.show(pn.recv(Some{Crdt.PN{[3], []}}, reordered)), "1"), "PN crosses back above zero")
    ok(String.eq(pn.show(Crdt.PNCounter.inc(Crdt.PN{[4294967295], []}, 0n)), "none"), "PN increment overflow")
    ok(String.eq(pn.show(Crdt.PNCounter.dec(Crdt.PN{[], [4294967295]}, 0n)), "none"), "PN decrement overflow")
    ok(String.eq(pn.show(Some{Crdt.PN{[4294967295, 1], []}}), "overflow"), "PN positive total overflow")
    ok(String.eq(pn.show(Some{Crdt.PN{[], [4294967295, 1]}}), "overflow"), "PN negative total overflow")
    pn.rejects("82810080", 8, "PN rejects a positive trailing zero")
    pn.rejects("82808100", 8, "PN rejects a negative trailing zero")
    pn.rejects("82808120", 8, "PN rejects a negative component")
    pn.rejects("8280811b0000000100000000", 8, "PN rejects a wide component")
    pn.rejects("8280820101", 1, "PN caps the negative half")
    pn.rejects("8282010180", 1, "PN caps the positive half")
    pn.rejects("8180", 8, "PN rejects a missing half")
    pn.rejects("83808080", 8, "PN rejects an extra half")
    pn.rejects("820180", 8, "PN rejects a non-array half")
    pn.rejects("a0", 8, "PN rejects a non-array state")
    pn.rejects("8280", 8, "PN rejects truncated bytes")

def main() -> IO(Unit):
  do IO<Unit>:
    +zero : Maybe<&2, List<&2, U32>> = Some{Crdt.GCounter.new()}
    +a0 : Maybe<&2, List<&2, U32>> = bumps(3n, zero, A())
    +b0 : Maybe<&2, List<&2, U32>> = bumps(2n, zero, B())
    +c0 : Maybe<&2, List<&2, U32>> = bumps(1n, zero, C())
    expect(a0, "[3]", "3", "A after 3 events")
    expect(b0, "[0, 2]", "2", "B after 2 events")
    expect(c0, "[0, 0, 1]", "1", "C after 1 event")
    # B gets A twice, C gets B, A gets C, B gets C, and C gets a stale copy of A.
    +b1 : Maybe<&2, List<&2, U32>> = recv(recv(b0, send(a0)), send(a0))
    +c1 : Maybe<&2, List<&2, U32>> = recv(c0, send(b1))
    +a1 : Maybe<&2, List<&2, U32>> = recv(a0, send(c1))
    +b2 : Maybe<&2, List<&2, U32>> = recv(b1, send(c1))
    +c2 : Maybe<&2, List<&2, U32>> = recv(c1, send(a0))
    expect(a1, "[3, 2, 1]", "6", "A after the exchange")
    expect(b2, "[3, 2, 1]", "6", "B after a duplicate and a relay")
    expect(c2, "[3, 2, 1]", "6", "C after a stale copy")
    # A counts on. C hears first, then B hears from C and, late, from A.
    +a2 : Maybe<&2, List<&2, U32>> = bump(a1, A())
    +c3 : Maybe<&2, List<&2, U32>> = recv(c2, send(a2))
    +b3 : Maybe<&2, List<&2, U32>> = recv(recv(b2, send(c3)), send(a1))
    expect(a2, "[4, 2, 1]", "7", "A after one more event")
    expect(b3, "[4, 2, 1]", "7", "B after reordered updates")
    expect(c3, "[4, 2, 1]", "7", "C after the update")
    IO.print("wire " ++ Bytes.to_hex(Maybe.default(&1, Bytes.Bytes, send(a2), Bytes.from_string(""))))
    ok(String.eq(show(Crdt.GCounter.inc([7, 4294967295], B())), "none"), "an increment past 4294967295 fails")
    ok(String.eq(show.total(Crdt.GCounter.value([4294967295, 1])), "overflow"), "a total past 4294967295 fails")
    rejects("820300", "the wire rejects a trailing 0")
    rejects("8a01010101010101010101", "the wire rejects more than 8 replicas")
    rejects("811b0000000100000000", "the wire rejects a count past 4294967295")
    rejects("8120", "the wire rejects a negative count")
    rejects("a0", "the wire rejects a map")
    rejects("8203", "the wire rejects truncated bytes")
    ok(String.eq(show(decode.hex("83030005")), "[3, 0, 5]"), "the wire accepts a gap")
    ksparse()
    pn.check()
