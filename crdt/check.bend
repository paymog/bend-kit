# Three replicas count events and exchange CBOR states with duplicates,
# reordering, and a stale copy. All three converge to the same state.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
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
