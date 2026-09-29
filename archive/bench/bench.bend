# ZIP read benchmark: read every entry of out/fixture.zip (see README.md).
import Base
import ../../time/time.bend as Time
import ../../bytes/bytes.bend as Bytes
import ../archive.bend as A

def from_bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, from_bytes(t)}

# h = h*31 + b, u32, over n bytes of buf from i.
def sum.go(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      (a, v) = r
      sum.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (h * 31 + v : U32))

def sum(b: Bytes.Bytes, +h: U32) -> U32:
  Bytes.Bytes{+len, buf} = b
  sum.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, h)

# Per entry in central-directory order: method, crc, name bytes, data bytes. Also the entry and data byte counts.
def sum.entries(xs: List<&1, A.Entry>, +h: U32, +n: U32, +total: U32) -> U32 & U32 & U32:
  match xs:
    case Nil{}:
      (h, n, total)
    case Con{e, t}:
      A.Entry{name, data, +method, +crc} = e
      Bytes.Bytes{+dl, db} = data
      +h0 = (h * 31 + method : U32)
      +h1 = (h0 * 31 + crc : U32)
      sum.entries(t, sum(Bytes.Bytes{dl, db}, sum(name, h1)), (n + 1 : U32), (total + dl : U32))

def report(t0: Time.Duration, t1: Time.Duration, r: U32 & U32 & U32) -> IO(Unit):
  (h, n, total) = r
  do IO<Unit>:
    IO.print("read\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(h))
    IO.print("entries\t0\t" ++ U32.show(n))
    IO.print("bytes\t0\t" ++ U32.show(total))

def done(t0: Time.Duration, r: Result<&1, &1, U32 & String, List<&1, A.Entry>>) -> IO(Unit):
  match r:
    case Fail{e}:
      (code, msg) = e
      IO.print("read\t0\tfailed: " ++ msg)
    case Done{xs}:
      do IO<Unit>:
        t1 : Time.Duration <- Time.mono()
        report(t0, t1, sum.entries(xs, 0, 0, 0))

def run(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    r : Result<&1, &1, U32 & String, List<&1, A.Entry>> <- A.read(16777216, b)
    done(t0, r)

def bytes.of(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Nil{}
    case Done{xs}:
      xs

def got(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    run(Bytes.from_string(from_bytes(bytes.of(r))))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 16777216)
        got(m)

def main() -> IO(Unit):
  do IO<Unit>:
    z : Result<&1, &1, U32 & String, File> <- File.open("out/fixture.zip", "r")
    opened(z)
