# WebSocket benchmark: mask and encode, then parse and unmask, 256 frames of 64 KiB (see README.md).
import Base
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ../websocket.bend as WS

def fill(n: Nat, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, i, (i * 7 : U32)), (i + 1 : U32))

def num(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{x}:
      x
    case None{}:
      0

def last(+w: U32, +len: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> U32:
  (b, m) = r
  (len + w + num(m) : U32)

def parsed(+w: U32, +len: U32, d: WS.Decode) -> U32:
  match d:
    case WS.Got{WS.Frame{fin, op, p}, rest}:
      last(w, len, Bytes.get(p, 65535))
    case _:
      0

def wired(r: Bytes.Bytes & Maybe<&2, U32>) -> U32:
  (b, m) = r
  Bytes.Bytes{+n, buf} = b
  parsed(num(m), n, WS.parse(True{}, 1048576, Bytes.Bytes{n, buf}))

def one(e: Result<&1, &1, U32 & String, Bytes.Bytes>) -> U32:
  match e:
    case Fail{x}:
      0
    case Done{b}:
      wired(Bytes.get(b, 20))

# Each frame adds its wire length, wire octet 20, and decoded payload octet 65535.
def run(n: Nat, r: Bytes.Bytes & Bytes.Bytes, +sum: U32) -> U32:
  match n:
    case 0n:
      sum
    case 1n+p:
      (src, copy) = r
      +v = one(WS.encode(WS.Frame{True{}, 2, copy}, Some{1025636919}))
      run(p, Bytes.slice(src, 0, 65536), (sum + v : U32))

def lap(t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ U32.show(chk))
    t1 : Time.Duration <- Time.mono()
    IO.print("frame\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))

def start(src: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap(t0, run(256n, Bytes.slice(src, 0, 65536), 0))

def main() -> IO(Unit):
  start(fill(65536n, Bytes.new(65536), 0))
