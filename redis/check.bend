import Base
import ./redis.bend as R
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

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

def verdict(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.print("fail " ++ name)

def main() -> IO(Unit):
  do IO<Unit>:
    verdict("500 items in 7-byte reads", same(arr(500), chunks(arr(500), 7)))
    verdict("20000 items in 65536-byte reads", same(arr(20000), chunks(arr(20000), 65536)))
    verdict("1 MiB bulk in 65536-byte reads", same(bulk(1048576), chunks(bulk(1048576), 65536)))
