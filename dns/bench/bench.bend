# DNS benchmark: build one A query and parse one A response, N times (see README.md).
import Base
import ../../time/time.bend as Time
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

# The id changes each round, so no round can reuse another's work.
def id(+i: U32) -> U32:
  (i .&. 65535 : U32)

def build(n: Nat, +i: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      build(p, (i + 1 : U32), sum.some(Dns.query(id(i), "www.example.com"), acc))

# The answer to the query above: one A record, 93.184.216.34, named by a pointer to the question.
def tail() -> String:
  "\u{81}\u{80}\u{0}\u{1}\u{0}\u{1}\u{0}\u{0}\u{0}\u{0}\u{3}www\u{7}example\u{3}com\u{0}\u{0}\u{1}\u{0}\u{1}\u{c0}\u{c}\u{0}\u{1}\u{0}\u{1}\u{0}\u{0}\u{0}\u{3c}\u{0}\u{4}\u{5d}\u{b8}\u{d8}\u{22}"

def response(+id: U32) -> String:
  SCon{Chr{U32.shrn(id, 8n)}, SCon{Chr{(id .&. 255 : U32)}, tail()}}

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
