import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import ./hash.bend as Hash

def fill(n: Nat, b: Bytes.Bytes, +i: U32, +seed: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, i, ((i * 73 + seed) .&. 255 : U32)), (i + 1 : U32), seed)

def bits(n: Nat, +h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      bits(p, ((h >> 1n) .^. Bool.pick(U32, U32.is_eq((h .&. 1 : U32), 1), 3988292384, 0) : U32))

def reference(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> U32:
  match n:
    case 0n:
      (h .^. 4294967295 : U32)
    case 1n+p:
      (a, +c) = r
      reference(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), bits(8n, (h .^. c : U32)))

def expected(b: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, a} = b
  reference(U32.to_nat(len), Bytes.peek(a, 0), 0, 4294967295)

def compare(r: Bytes.Bytes & U32) -> Bool:
  (b, h) = r
  U32.is_eq(h, expected(b))

def check(+len: U32, +seed: U32) -> Bool:
  b = fill(U32.to_nat(len), Bytes.Bytes{len, [4294967295 : U32*128n]}, 0, seed)
  compare(Hash.crc32(b))

def lengths(n: Nat, +len: U32, ok: Bool) -> Bool:
  match n:
    case 0n:
      ok
    case 1n+p:
      lengths(p, (len + 1 : U32), ok && check(len, 0) && check(len, 197))

def finish(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok CRC-32 lengths 0 through 257, two byte patterns, dirty padding")
    case False{}:
      IO.die(Unit, 1, "FAIL CRC-32 boundaries")

def main() -> IO(Unit):
  finish(lengths(258n, 0, True{}))
