# Postgres result decode benchmark: decode every message in one fixed recording (see README.md).
import Base
import ../codec.bend as C
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def m(+h: U32, +x: U32) -> U32:
  (h * 31 + x : U32)

def str.go(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      (a, +b) = r
      str.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), m(h, b))

# The length, then the bytes.
def str(+h: U32, t: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, buf} = t
  str.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, m(h, len))

def fields(xs: List<&1, C.Field>, +h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{C.Field{name, table, column, +oid, size, modifier, format}, rest}:
      fields(rest, m(str(h, name), oid))

def cols(xs: List<&1, Maybe<&1, Bytes.Bytes>>, +h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{None{}, rest}:
      cols(rest, m(h, 4))
    case Con{Some{b}, rest}:
      cols(rest, str(m(h, 5), b))

# The checksum in run.py.
def walk(xs: List<&1, C.Back>, +h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{C.RowDescription{fs}, rest}:
      walk(rest, m(fields(fs, m(h, 1)), 2))
    case Con{C.DataRow{cs}, rest}:
      walk(rest, m(cols(cs, m(h, 3)), 6))
    case Con{C.CommandComplete{tag}, rest}:
      walk(rest, str(m(h, 7), tag))
    case Con{C.ReadyForQuery{st}, rest}:
      walk(rest, h)
    # The recording holds no other message, so one here spoils the checksum.
    case Con{v, rest}:
      walk(rest, 0)

def piece(rd: C.Reader, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&1, Bytes.Bytes & C.Reader & C.Next>:
  (whole, p) = r
  Some{(whole, C.next(C.feed(rd, p)))}

# The next 64 KiB piece fed and decoded, or None past the end.
def more(last: Bool, whole: Bytes.Bytes, +at: U32, rd: C.Reader) -> Maybe<&1, Bytes.Bytes & C.Reader & C.Next>:
  match last:
    case True{}:
      None{}
    case False{}:
      piece(rd, Bytes.slice(whole, at, 65536))

# Feeds the recording to a Reader 64 KiB at a time, as a socket would, taking every whole message
# after each piece. Messages come back newest first. Each step takes a message (5 bytes or more)
# or a piece, so len / 5 + len / 65536 + 2 steps are enough.
def pump(n: Nat, st: Maybe<&1, Bytes.Bytes & C.Reader & C.Next>, +len: U32, +at: U32, acc: List<&1, C.Back>) -> List<&1, C.Back>:
  match n:
    case 0n:
      acc
    case 1n+p:
      match st:
        case None{}:
          acc
        case Some{(whole, rd, nx)}:
          match nx:
            case C.Got{v}:
              pump(p, Some{(whole, C.next(rd))}, len, at, Con{v, acc})
            case C.Bad{}:
              Nil{}
            case C.Want{}:
              pump(p, more(U32.is_le(len, at), whole, at, rd), len, (at + 65536 : U32), acc)

def lap(t0: Nat, t1: Nat, +sum: U32) -> IO(Unit):
  IO.print("decode\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(sum))

def summed(t0: Nat, xs: List<&1, C.Back>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    lap(t0, t1, walk(List.reverse(&1, C.Back, xs), 0))

def start(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    t0 : Nat <- IO.now()
    summed(t0, pump(U32.to_nat((len / 5 + len / 65536 + 2 : U32)), Some{(Bytes.Bytes{len, buf}, (C.reader(), C.Want{}))}, len, 0, Nil{}))

def octets(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, octets(t)}

def list(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Nil{}
    case Done{xs}:
      xs

# The file is packed into Bytes before the timer starts.
def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    start(Bytes.from_string(octets(list(r))))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 67108864)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    f : Result<&1, &1, U32 & String, File> <- File.open("out/result.pgwire", "r")
    opened(f)
