# Encoding benchmark: UTF-8 and hex over one fixed input (see README.md).
import Base
import ../../time/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ../encoding.bend as Enc

def of(xs: List<U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, of(t)}

def rep(n: Nat, +seed: String, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      rep(p, seed, seed ++ acc)

# Each input is its 16-code-point seed repeated 2^18 times.
def text() -> String:
  rep(262144n, of([72, 101, 108, 108, 111, 32, 233, 32, 937, 32, 8364, 32, 20013, 32, 128512, 10]), SNil{})

def octets() -> String:
  rep(262144n, of([72, 101, 108, 108, 111, 32, 195, 169, 32, 206, 169, 32, 226, 130, 172, 32, 228, 184, 173, 32, 240, 159, 152, 128, 10]), SNil{})

def hex() -> String:
  rep(262144n, "48656c6c6f20c3a920cea920e282ac20e4b8ad20f09f98800a", SNil{})

# Checksum: h = h*31 + c, u32, then add the length.
def hash(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{c}, t}:
      hash(t, (h * 31 + c : U32), (n + 1 : U32))

def some(b: Maybe<&1, Bytes.Bytes>) -> String:
  match b:
    case None{}:
      SNil{}
    case Some{x}:
      Bytes.to_string(x)

# Bend evaluates strictly: the output is built before t1 is read. The checksum is not timed.
def stop(+name: String, t0: Time.Duration, s: String) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(hash(s, 0, 0)))

def stop.b(+name: String, t0: Time.Duration, b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(hash(Bytes.to_string(b), 0, 0)))

def stop.m(+name: String, t0: Time.Duration, b: Maybe<&1, Bytes.Bytes>) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(hash(some(b), 0, 0)))

def op.hex_decode(+s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop.m("hex_decode", t0, Bytes.from_hex(s))

def op.hex_encode(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("hex_encode", t0, Bytes.to_hex(b))
    op.hex_decode(hex())

def op.utf8_decode(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("utf8_decode", t0, Enc.utf8.decode(b))
    op.hex_encode(Bytes.from_string(octets()))

def op.utf8_encode(+s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop.b("utf8_encode", t0, Enc.utf8.encode(s))
    op.utf8_decode(Bytes.from_string(octets()))

def main() -> IO(Unit):
  op.utf8_encode(text())
