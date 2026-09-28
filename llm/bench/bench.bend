# SSE parse benchmark: parse every event in one fixed recording (see README.md).
import Base
import ../sse.bend as Sse
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def m(+h: U32, +x: U32) -> U32:
  (h * 31 + x : U32)

def text(s: String, +h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{+c}, t}:
      text(t, m(h, c))

def data.go(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      (a, +b) = r
      data.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), m(h, b))

def data(+h: U32, d: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, buf} = d
  data.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, h)

# The checksum in run.py.
def walk(xs: List<&1, Sse.Message>, +h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{Sse.Message{name, d, id}, rest}:
      walk(rest, data(m(text(name, m(h, 1)), 2), d))

def piece(rd: Sse.Reader, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&1, Bytes.Bytes & Sse.Reader & Sse.Next>:
  (whole, p) = r
  Some{(whole, Sse.next(Sse.feed(rd, p)))}

# The next 64 KiB piece fed and parsed, or None past the end.
def more(last: Bool, whole: Bytes.Bytes, +at: U32, rd: Sse.Reader) -> Maybe<&1, Bytes.Bytes & Sse.Reader & Sse.Next>:
  match last:
    case True{}:
      None{}
    case False{}:
      piece(rd, Bytes.slice(whole, at, 65536))

# Feeds the recording to a Reader 64 KiB at a time, as a socket would, taking every whole event
# after each piece. Events come back newest first. Each step takes an event or a piece, so
# len / 2 + len / 65536 + 2 steps are enough.
def pump(n: Nat, st: Maybe<&1, Bytes.Bytes & Sse.Reader & Sse.Next>, +len: U32, +at: U32, acc: List<&1, Sse.Message>, +k: U32) -> List<&1, Sse.Message> & U32:
  match n:
    case 0n:
      (acc, k)
    case 1n+p:
      match st:
        case None{}:
          (acc, k)
        case Some{(whole, rd, nx)}:
          match nx:
            case Sse.Got{e}:
              pump(p, Some{(whole, Sse.next(rd))}, len, at, Con{e, acc}, (k + 1 : U32))
            case Sse.Want{}:
              pump(p, more(U32.is_le(len, at), whole, at, rd), len, (at + 65536 : U32), acc, k)

def lap(t0: Nat, t1: Nat, +sum: U32) -> IO(Unit):
  IO.print("parse\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(sum))

def summed(t0: Nat, r: List<&1, Sse.Message> & U32) -> IO(Unit):
  (xs, +k) = r
  do IO<Unit>:
    t1 : Nat <- IO.now()
    lap(t0, t1, (walk(List.reverse(&1, Sse.Message, xs), 0) + k : U32))

def start(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    t0 : Nat <- IO.now()
    summed(t0, pump(U32.to_nat((len / 2 + len / 65536 + 2 : U32)), Some{(Bytes.Bytes{len, buf}, (Sse.reader(), Sse.Want{}))}, len, 0, Nil{}, 0))

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
    f : Result<&1, &1, U32 & String, File> <- File.open("out/stream.sse", "r")
    opened(f)
