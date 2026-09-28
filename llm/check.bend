import Base
import ./sse.bend as Sse
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# The laws run in the checker. This runs the parser on the runtime at sizes the checker would not reach.

# n events, each "data: <i>\n\n" on CRLF ends.
def events(n: Nat, +i: U32, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match n:
    case 0n:
      acc
    case 1n+p:
      events(p, (i + 1 : U32), Con{Bytes.from_string("event: e\r\ndata: " ++ U32.show(i) ++ "\r\n\r\n"), acc})

def many(+n: U32) -> Bytes.Bytes:
  Bytes.concat(List.reverse(&1, Bytes.Bytes, events(U32.to_nat(n), 0, Nil{})))

# One event whose data line holds n bytes.
def big(+n: U32) -> Bytes.Bytes:
  Bytes.concat([Bytes.from_string("data: "), Bytes.new(n), Bytes.from_string("\n\n")])

# f: at least the events left. c counts events; t sums their data lengths.
def drain(f: Nat, r: Sse.Reader & Sse.Next, +c: U32, +t: U32) -> Sse.Reader & U32 & U32:
  match f:
    case 0n:
      (rd, n) = r
      (rd, c, t)
    case 1n+p:
      (rd, n) = r
      match n:
        case Sse.Got{e}:
          Sse.Message{name, data, id} = e
          Bytes.Bytes{+len, buf} = data
          drain(p, Sse.next(rd), (c + 1 : U32), (t + len : U32))
        case Sse.Want{}:
          (rd, c, t)

def step(f: Nat, +k: U32, +at: U32, r: Sse.Reader & U32 & U32, rest: Bytes.Bytes & Bytes.Bytes) -> U32 & U32:
  match f:
    case 0n:
      (rd, c, t) = r
      (c, t)
    case 1n+p:
      (rd, c, t) = r
      (whole, piece) = rest
      step(p, k, (at + k : U32), drain(Nat.add(U32.to_nat(k), 1n), Sse.next(Sse.feed(rd, piece)), c, t), Bytes.slice(whole, (at + k : U32), k))

# Feeds b to a reader k bytes at a time, reading every event after each piece.
def chunks(b: Bytes.Bytes, +k: U32) -> U32 & U32:
  Bytes.Bytes{+len, buf} = b
  step(U32.to_nat(((len / k) + 1 : U32)), k, 0, (Sse.reader(), 0, 0), Bytes.slice(Bytes.Bytes{len, buf}, 0, k))

def verdict.of(good: Bool, +name: String, +gc: U32, +gt: U32) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.print("fail " ++ name ++ ": " ++ U32.show(gc) ++ " events, " ++ U32.show(gt) ++ " bytes")

def verdict(+name: String, r: U32 & U32, +c: U32, +t: U32) -> IO(Unit):
  (+gc, +gt) = r
  verdict.of(Bool.and(U32.is_eq(gc, c), U32.is_eq(gt, t)), name, gc, gt)

def main() -> IO(Unit):
  do IO<Unit>:
    verdict("20000 events in 7-byte reads", chunks(many(20000), 7), 20000, 88890)
    verdict("20000 events in 65536-byte reads", chunks(many(20000), 65536), 20000, 88890)
    verdict("1 MiB data line in 65536-byte reads", chunks(big(1048576), 65536), 1, 1048576)
