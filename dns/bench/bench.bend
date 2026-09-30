# DNS benchmark: build one A query and parse one A response, N times (see README.md).
import Base
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ../dns.bend as Dns

def sum(s: String, acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      sum(t, (acc + c : U32))

def sum.some(m: Maybe<&2, String>, acc: U32) -> U32:
  match m:
    case None{}:
      acc
    case Some{s}:
      sum(s, acc)

def sum.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      (a, c) = r
      sum.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (acc + c : U32))

def sum.bytes(m: Maybe<&1, Bytes.Bytes>, acc: U32) -> U32:
  match m:
    case None{}:
      acc
    case Some{Bytes.Bytes{+len, buf}}:
      sum.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, acc)

# The id changes each round, so no round can reuse another's work.
def id(+i: U32) -> U32:
  (i .&. 65535 : U32)

def build(n: Nat, +i: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      build(p, (i + 1 : U32), sum.bytes(Dns.query(id(i), "www.example.com"), acc))

# The answer to the query above, id zeroed: one A record, 93.184.216.34, named by a pointer to the question.
def zero() -> String:
  "\u{0}\u{0}\u{81}\u{80}\u{0}\u{1}\u{0}\u{1}\u{0}\u{0}\u{0}\u{0}\u{3}www\u{7}example\u{3}com\u{0}\u{0}\u{1}\u{0}\u{1}\u{c0}\u{c}\u{0}\u{1}\u{0}\u{1}\u{0}\u{0}\u{0}\u{3c}\u{0}\u{4}\u{5d}\u{b8}\u{d8}\u{22}"

def response(+id: U32) -> Bytes.Bytes:
  Bytes.set.u16be(Bytes.from_string(zero()), 0, id)

def parse(n: Nat, +i: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      parse(p, (i + 1 : U32), sum.some(Dns.answer(id(i), response(id(i))), acc))

def lap(+name: String, t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ U32.show(chk))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\t" ++ name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def op.parse() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("parse", t0, parse(100000n, 0, 0))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("build", t0, build(100000n, 0, 0))
    op.parse()
