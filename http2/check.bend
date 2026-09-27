import Base
import ./http2.bend as H
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def ensure(ok: Bool, +why: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ why)
    case False{}:
      IO.die(Unit, 1, why)

def received(d: H.Decode) -> IO(Unit):
  match d:
    case H.Need{b}:
      IO.die(Unit, 1, "complete frame requested more bytes")
    case H.Bad{H.Error{code, connection, stream}}:
      IO.die(Unit, 1, "valid frame failed: " ++ U32.show(code))
    case H.Got{H.Frame{+kind, +flags, +stream, Bytes.Bytes{+len, buf}}, Bytes.Bytes{+rest, tail}}:
      ensure(Bool.and(U32.is_eq(kind, 0), Bool.and(U32.is_eq(flags, 1), Bool.and(U32.is_eq(stream, 1), Bool.and(U32.is_eq(len, 16384), U32.is_eq(rest, 0))))), "16 KiB DATA payload and frame boundary")

def encoded(r: Result<&1, &1, H.Error, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{H.Error{code, connection, stream}}:
      IO.die(Unit, 1, "valid frame failed to encode: " ++ U32.show(code))
    case Done{b}:
      received(H.parse(16384, b))

def main() -> IO(Unit):
  encoded(H.encode(16384, H.Frame{0, 1, 1, Bytes.new(16384)}))
