# Multipart benchmark: encode and decode one fixed form (see README.md).
import Base
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ../multipart.bend as Mp

def B() -> String:
  "bend-kit-0123456789abcdef0123456789abcdef"

# 2^20 bytes: x = x * 1103515245 + 12345 from x = 1, each byte x >> 24.
def blob.go(n: Nat, a: Array<U32>, +i: U32, +x: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      +y = (x * 1103515245 + 12345 : U32)
      blob.go(p, Bytes.poke(a, i, (y >> 24n : U32)), (i + 1 : U32), y)

def blob() -> Bytes.Bytes:
  Bytes.Bytes{1048576, blob.go(1048576n, Bytes.alloc(1048576), 0, 1)}

def form() -> List<&1, Mp.Part>:
  [Mp.Part{"title", None{}, None{}, Bytes.from_string("hello multipart")}, Mp.Part{"blob", Some{"blob.bin"}, Some{"application/octet-stream"}, blob()}, Mp.Part{"note", None{}, None{}, Bytes.from_string("end")}]

# Checksum: h = h*31 + byte, u32, then add the length.
def hash.go(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (a, v) = r
      (a, h)
    case 1n+p:
      (a, +v) = r
      hash.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (h * 31 + v : U32))

def hash.fin(r: Array<U32> & U32) -> U32:
  (a, h) = r
  h

def hash(b: Bytes.Bytes, +h: U32) -> U32:
  Bytes.Bytes{+len, buf} = b
  hash.fin(hash.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, h))

def sum.of(r: Bytes.Bytes & U32) -> U32:
  (b, +n) = r
  (hash(b, 0) + n : U32)

def enc.sum(r: Result<&1, &1, String, Bytes.Bytes>) -> U32:
  match r:
    case Fail{e}:
      0
    case Done{b}:
      sum.of(Bytes.length(b))

def part.len(r: Bytes.Bytes & U32, +h: U32, +n: U32) -> U32 & U32:
  (b, +m) = r
  (hash(b, h), (n + m : U32))

# Over each part: its name's bytes, then its body's.
def part.add(p: Mp.Part, acc: U32 & U32) -> U32 & U32:
  Mp.Part{+name, f, c, body} = p
  (+h, +n) = acc
  part.len(Bytes.length(body), hash(Bytes.from_string(name), h), (n + Bytes.count(name, 0) : U32))

def parts.sum(ps: List<&1, Mp.Part>, acc: U32 & U32) -> U32:
  match ps:
    case Nil{}:
      (h, n) = acc
      (h + n : U32)
    case Con{p, t}:
      parts.sum(t, part.add(p, acc))

def dec.sum(r: Result<&1, &1, String, List<&1, Mp.Part>>) -> U32:
  match r:
    case Fail{e}:
      0
    case Done{ps}:
      parts.sum(ps, (0, 0))

def body(r: Result<&1, &1, String, Bytes.Bytes>) -> Bytes.Bytes:
  match r:
    case Fail{e}:
      Bytes.new(0)
    case Done{b}:
      b

# Bend evaluates strictly: the output is built before t1 is read. The checksum is not timed.
def stop.enc(+name: String, t0: Time.Duration, r: Result<&1, &1, String, Bytes.Bytes>) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(enc.sum(r)))

def stop.dec(+name: String, t0: Time.Duration, r: Result<&1, &1, String, List<&1, Mp.Part>>) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(dec.sum(r)))

def op.decode(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop.dec("decode", t0, Mp.decode(B(), b))

def op.encode(parts: List<&1, Mp.Part>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop.enc("encode", t0, Mp.encode(B(), parts))
    op.decode(body(Mp.encode(B(), form())))

def main() -> IO(Unit):
  op.encode(form())
