# Hash benchmark: each hash over one fixed input (see README.md).
import Base
import ../../time/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ../hash.bend as Hash

# 2^24 - 3 bytes, byte i = i mod 251: every tail path runs.
def size() -> U32:
  16777213

def fill(n: Nat, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, i, (i % 251 : U32)), (i + 1 : U32))

def input() -> Bytes.Bytes:
  fill(U32.to_nat(size()), Bytes.new(size()), 0)

def hex.go(n: Nat, +x: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      +d = (x .&. 15 : U32)
      hex.go(p, (x >> 4n : U32), SCon{Chr{Bool.pick(U32, U32.is_lt(d, 10), (48 + d : U32), (87 + d : U32))}, acc})

def hex(+x: U32) -> String:
  hex.go(8n, x, "")

def hex64(w: Hash.W64) -> String:
  match w:
    case Hash.W64{hi, lo}:
      hex(hi) ++ hex(lo)

# Bend evaluates strictly: the hash is done before t1 is read.
def stop(+name: String, t0: Time.Duration, r: Bytes.Bytes & U32) -> IO(Bytes.Bytes):
  (b, +h) = r
  do IO<Bytes.Bytes>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ hex(h))
    return b

def stop64(+name: String, t0: Time.Duration, r: Bytes.Bytes & Hash.W64) -> IO(Bytes.Bytes):
  (b, h) = r
  do IO<Bytes.Bytes>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ hex64(h))
    return b

def main() -> IO(Unit):
  do IO<Unit>:
    b0 : Bytes.Bytes = input()
    t0 : Time.Duration <- Time.mono()
    b1 : Bytes.Bytes <- stop("crc32", t0, Hash.crc32(b0))
    t1 : Time.Duration <- Time.mono()
    b2 : Bytes.Bytes <- stop("adler32", t1, Hash.adler32(b1))
    t2 : Time.Duration <- Time.mono()
    b3 : Bytes.Bytes <- stop("fnv1a32", t2, Hash.fnv1a32(b2))
    t3 : Time.Duration <- Time.mono()
    b4 : Bytes.Bytes <- stop64("fnv1a64", t3, Hash.fnv1a64(b3))
    t4 : Time.Duration <- Time.mono()
    b5 : Bytes.Bytes <- stop("xxh32", t4, Hash.xxh32(b4, 0))
    t5 : Time.Duration <- Time.mono()
    b6 : Bytes.Bytes <- stop64("xxh64", t5, Hash.xxh64(b5, Hash.W64{0, 0}))
    t6 : Time.Duration <- Time.mono()
    b7 : Bytes.Bytes <- stop64("siphash13", t6, Hash.siphash13(b6, Hash.W64{0, 0}, Hash.W64{0, 0}))
    return Unit{}
