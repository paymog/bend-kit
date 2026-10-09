# WebSocket benchmark: frame (mask, encode, parse, unmask 64 KiB frames) and stream (decode frames from 64 KiB reads); see README.md.
import Base
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
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

def parsed(+w: U32, +len: U32, d: WS.Decode<Bytes.Bytes, Bytes.Cursor>) -> U32:
  match d:
    case WS.Got{WS.Frame{fin, op, p}, rest}:
      last(w, len, Bytes.get(p, 65535))
    case _:
      0

def wired(r: Bytes.Bytes & Maybe<&2, U32>) -> U32:
  (b, m) = r
  Bytes.Bytes{+n, buf} = b
  parsed(num(m), n, WS.parse(True{}, 1048576, Bytes.Cursor.new(Bytes.Bytes{n, buf})))

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

# Stream: 16384 unmasked frames of 1000 octets, as a client reads them in 65536-octet reads.

def wire1(e: Result<&1, &1, U32 & String, Bytes.Bytes>) -> Bytes.Bytes:
  match e:
    case Fail{x}:
      Bytes.new(0)
    case Done{w}:
      w

def build.add(n: Nat, r: Bytes.Bytes & Bytes.Bytes, acc: Bytes.Bytes) -> Bytes.Bytes:
  match n:
    case 0n:
      acc
    case 1n+p:
      (one, copy) = r
      build.add(p, Bytes.slice(one, 0, 1004), Bytes.append(acc, copy))

def build(n: Nat, one: Bytes.Bytes) -> Bytes.Bytes:
  build.add(n, Bytes.slice(one, 0, 1004), Bytes.new(0))

def got(r: Bytes.Bytes & Maybe<&2, U32>) -> U32:
  (b, m) = r
  Bytes.Bytes{+n, buf} = b
  (n + num(m) : U32)

type St is Type:
  SParse{input: Bytes.Cursor, src: Bytes.Bytes, pos: U32, sum: U32}
  SStep{d: WS.Decode<Bytes.Bytes, Bytes.Cursor>, src: Bytes.Bytes, pos: U32, sum: U32}
  SRead{eof: Bool, input: Bytes.Cursor, src: Bytes.Bytes, pos: U32, sum: U32}

def st.read(r: Bytes.Bytes & Bytes.Bytes, input: Bytes.Cursor, +pos: U32, +sum: U32) -> St:
  (src, chunk) = r
  SParse{WS.push(input, chunk), src, (pos + 65536 : U32), sum}

def st.need(input: Bytes.Cursor, src: Bytes.Bytes, +pos: U32, +sum: U32) -> St:
  Bytes.Bytes{+n, s} = src
  SRead{U32.is_le(n, pos), input, Bytes.Bytes{n, s}, pos, sum}

# Each frame adds its payload length and payload octet 999.
def stream(n: Nat, st: St) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      match st:
        case SParse{input, src, +pos, +sum}:
          stream(p, SStep{WS.parse(False{}, 1048576, input), src, pos, sum})
        case SStep{d, src, +pos, +sum}:
          match d:
            case WS.Need{input}:
              stream(p, st.need(input, src, pos, sum))
            case WS.Bad{code, why}:
              0
            case WS.Got{WS.Frame{fin, op, pl}, rest}:
              stream(p, SParse{rest, src, pos, (sum + got(Bytes.get(pl, 999)) : U32)})
        case SRead{eof, input, src, +pos, +sum}:
          match eof:
            case True{}:
              sum
            case False{}:
              stream(p, st.read(Bytes.slice(src, pos, 65536), input, pos, sum))

def lap(+op: String, t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ U32.show(chk))
    t1 : Time.Duration <- Time.mono()
    IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))

def start.stream(src: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("stream", t0, stream(1000000n, SParse{Bytes.Cursor.new(Bytes.new(0)), src, 0, 0}))

def start(r: Bytes.Bytes & Bytes.Bytes) -> IO(Unit):
  (src, one) = r
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("frame", t0, run(256n, Bytes.slice(src, 0, 65536), 0))
    start.stream(build(16384n, wire1(WS.encode(WS.Frame{True{}, 2, one}, None{}))))

def main() -> IO(Unit):
  start(Bytes.slice(fill(65536n, Bytes.new(65536), 0), 0, 1000))
