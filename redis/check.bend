import Base
import ./redis.bend as R
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import ./pure.bend as Pure

# The laws run in the checker. This runs the codec on the runtime at sizes the checker would not reach.

def items(n: Nat, +i: U32) -> List<&1, Bytes.Bytes>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{Bytes.from_string("item-" ++ U32.show(i)), items(p, (i + 1 : U32))}

def arr(+n: U32) -> Bytes.Bytes:
  R.encode.command(items(U32.to_nat(n), 0))

def bulk(+n: U32) -> Bytes.Bytes:
  R.encode.command([Bytes.new(n)])

def got.of(r: R.Reader & R.Next) -> R.Reader & Maybe<&1, R.Val>:
  (rd, n) = r
  match n:
    case R.Got{v}:
      (rd, Some{v})
    case R.Want{}:
      (rd, None{})
    case R.Broken{}:
      (rd, None{})

def keep(m: Maybe<&1, R.Val>, found: Maybe<&1, R.Val>) -> Maybe<&1, R.Val>:
  match m:
    case Some{v}:
      Some{v}
    case None{}:
      found

def chunks.step(n: Nat, +k: U32, +at: U32, found: Maybe<&1, R.Val>, r: R.Reader & Maybe<&1, R.Val>, rest: Bytes.Bytes & Bytes.Bytes) -> Maybe<&1, R.Val>:
  match n:
    case 0n:
      (rd, m) = r
      keep(m, found)
    case 1n+p:
      (rd, m) = r
      (whole, piece) = rest
      chunks.step(p, k, (at + k : U32), keep(m, found), got.of(R.next(R.feed(rd, piece))), Bytes.slice(whole, (at + k : U32), k))

# Feeds b to a reader k bytes at a time, decoding after each piece.
def chunks(b: Bytes.Bytes, +k: U32) -> Maybe<&1, R.Val>:
  Bytes.Bytes{+len, buf} = b
  chunks.step(U32.to_nat(((len / k) + 1 : U32)), k, 0, None{}, (R.reader(), None{}), Bytes.slice(Bytes.Bytes{len, buf}, 0, k))

def same.eq(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, ok) = r
  ok

def same.enc(a: Bytes.Bytes, m: Maybe<&1, Bytes.Bytes>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      same.eq(Bytes.eq(a, x))

# The decoded reply encodes back to the bytes fed in.
def same(a: Bytes.Bytes, m: Maybe<&1, R.Val>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      same.enc(a, R.encode(v))

def fixtures(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+s, rest}:
      Bool.and(same(Bytes.from_string(s), chunks(Bytes.from_string(s), 1)), fixtures(rest))

def resp3() -> Bool:
  fixtures([
    "+OK\r\n", "-ERR wrong type\r\n",
    ":0\r\n", ":-1\r\n", ":9223372036854775807\r\n", ":-9223372036854775808\r\n",
    "$4\r\na\r\nb\r\n", "$0\r\n\r\n", "*2\r\n*0\r\n_\r\n",
    "_\r\n", "#t\r\n", "#f\r\n", ",-1.5e-3\r\n", "(3492890328409238509324850943850943825024385\r\n",
    "!3\r\nERR\r\n", "=8\r\ntxt:a\r\nb\r\n",
    "%1\r\n+k\r\n:1\r\n", "%0\r\n", "~2\r\n+a\r\n+b\r\n",
    "|1\r\n+k\r\n:1\r\n*1\r\n$1\r\nv\r\n", ">2\r\n+message\r\n+hi\r\n"
  ])

def retained.finish(r: R.Reader & R.Next) -> Bool:
  (rd, nx) = r
  match nx:
    case R.Got{R.Arr{xs}}:
      Nat.is_eq(List.length(&1, R.Val, xs), 100n)
    case _:
      False{}

def retained.go(n: Nat, r: R.Reader & R.Next) -> Bool:
  match n:
    case 0n:
      retained.finish(r)
    case 1n+p:
      (rd, nx) = r
      match nx:
        case R.Want{}:
          retained.go(p, R.next(R.feed(rd, R.text(":1\r\n"))))
        case _:
          False{}

# Poison a completed item's tag: resuming must use the value in the aggregate frame.
def retained.start(r: R.Reader & R.Next) -> Bool:
  (rd, nx) = r
  R.Reader{state} = rd
  Pure.Reader{buf, pos, st} = state
  retained.go(99n, (R.Reader{Pure.Reader{Bytes.set(buf, 6, 63), pos, st}}, nx))

def pipeline.last(+want: String, r: R.Reader & R.Next) -> Bool:
  (rd, nx) = r
  match nx:
    case R.Got{v}:
      same(R.text(want), Some{v})
    case _:
      False{}

def pipeline.wait(+tail: String, +want: String, r: R.Reader & R.Next) -> Bool:
  (rd, nx) = r
  match nx:
    case R.Want{}:
      pipeline.last(want, R.next(R.feed(rd, R.text(tail))))
    case _:
      False{}

def pipeline.first(+tail: String, +want: String, r: R.Reader & R.Next) -> Bool:
  (rd, nx) = r
  match nx:
    case R.Got{v}:
      pipeline.wait(tail, want, R.next(rd))
    case _:
      False{}

def pipeline(+head: String, +tail: String, +want: String) -> Bool:
  pipeline.first(tail, want, R.next(R.feed(R.reader(), R.text("+OK\r\n" ++ head))))

def verdict(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "fail " ++ name)

def main() -> IO(Unit):
  do IO<Unit>:
    verdict("RESP3 public codec in 1-byte reads", resp3())
    verdict("completed aggregate items survive 100 small reads", retained.start(R.next(R.feed(R.reader(), R.text("*100\r\n:1\r\n")))))
    verdict("partial line survives pipeline compaction", pipeline("*2\r\n:1\r\n+ab\r", "\n", "*2\r\n:1\r\n+ab\r\n"))
    verdict("partial bulk survives pipeline compaction", pipeline("*2\r\n:1\r\n$3\r\nab", "c\r\n", "*2\r\n:1\r\n$3\r\nabc\r\n"))
    verdict("empty pipeline head survives compaction", pipeline("", ":1\r\n", ":1\r\n"))
    verdict("500 items in 7-byte reads", same(arr(500), chunks(arr(500), 7)))
    verdict("20000 items in 65536-byte reads", same(arr(20000), chunks(arr(20000), 65536)))
    verdict("1 MiB bulk in 65536-byte reads", same(bulk(1048576), chunks(bulk(1048576), 65536)))
