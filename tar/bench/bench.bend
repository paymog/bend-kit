# Tar benchmark: decode one fixed archive written by Python's tarfile, and encode its entries back (see README.md).
import Base
import ../tar.bend as Tar
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ../../time/time.bend as Time

# h = h*31 + b over the first n bytes of the buffer.
def fold.go(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (a, b) = r
      (a, h)
    case 1n+p:
      (a, +b) = r
      fold.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (h * 31 + b : U32))

def fold.fin(+len: U32, +m: U32, r: Array<U32> & U32) -> Bytes.Bytes & U32:
  (a, h) = r
  (Bytes.Bytes{len, a}, (h * 31 + m : U32))

# Folds the first m bytes, then m.
def fold(b: Bytes.Bytes, +m: U32, +h: U32) -> Bytes.Bytes & U32:
  Bytes.Bytes{+len, buf} = b
  fold.fin(len, m, fold.go(U32.to_nat(m), Bytes.peek(buf, 0), 0, h))

def fold.all(b: Bytes.Bytes, +h: U32) -> Bytes.Bytes & U32:
  Bytes.Bytes{+len, buf} = b
  fold(Bytes.Bytes{len, buf}, len, h)

def trim.of(r: Bytes.Bytes & Bool) -> Bytes.Bytes & U32:
  (b, hit) = r
  Bytes.Bytes{+len, buf} = b
  (Bytes.Bytes{len, buf}, Bool.pick(U32, hit, (len - 1 : U32), len))

# The name's length less one trailing '/'.
def trim(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  trim.of(Bytes.ends_with(b, "/"))

# Checksum (see run.py): kind, name bytes and length, then file data bytes and length.
type State is Type:
  State{acc: List<&1, Tar.Entry>, h: U32, k: U32}

def file.done(name: Bytes.Bytes, acc: List<&1, Tar.Entry>, +k: U32, r: Bytes.Bytes & U32) -> State:
  (data, +h) = r
  State{Con{Tar.File{name, data}, acc}, h, (k + 1 : U32)}

def file.name(data: Bytes.Bytes, acc: List<&1, Tar.Entry>, +k: U32, r: Bytes.Bytes & U32) -> State:
  (name, +h) = r
  file.done(name, acc, k, fold.all(data, h))

def dir.done(acc: List<&1, Tar.Entry>, +k: U32, r: Bytes.Bytes & U32) -> State:
  (name, +h) = r
  State{Con{Tar.Dir{name}, acc}, h, (k + 1 : U32)}

def dir.name(acc: List<&1, Tar.Entry>, +h: U32, +k: U32, r: Bytes.Bytes & U32) -> State:
  (name, +m) = r
  dir.done(acc, k, fold(name, m, (h * 31 + 2 : U32)))

def entry(e: Tar.Entry, st: State) -> State:
  match e:
    case Tar.File{name, data}:
      State{acc, +h, +k} = st
      file.name(data, acc, k, fold.all(name, (h * 31 + 1 : U32)))
    case Tar.Dir{name}:
      State{acc, +h, +k} = st
      dir.name(acc, h, k, trim(name))

def sum.done(st: State) -> List<&1, Tar.Entry> & U32:
  State{acc, +h, +k} = st
  (List.reverse(&1, Tar.Entry, acc), (h + k : U32))

def sum(xs: List<&1, Tar.Entry>, st: State) -> List<&1, Tar.Entry> & U32:
  match xs:
    case Nil{}:
      sum.done(st)
    case Con{e, t}:
      sum(t, entry(e, st))

def show.sum(r: List<&1, Tar.Entry> & U32) -> String:
  (ys, +h) = r
  U32.show(h)

def show(m: Maybe<&1, List<&1, Tar.Entry>>) -> String:
  match m:
    case None{}:
      "failed"
    case Some{xs}:
      show.sum(sum(xs, State{Nil{}, 0, 0}))

# The encoded archive is read back and summed, untimed.
def reread(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "failed"
    case Some{b}:
      show(Tar.decode(b))

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, +sum: String) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ sum)

def op.encoded(+dt: String, +sd: String, t2: Time.Duration, t3: Time.Duration, out: Maybe<&1, Bytes.Bytes>) -> IO(Unit):
  +se = reread(out)
  do IO<Unit>:
    IO.print("decode\t" ++ dt ++ "\t" ++ sd)
    lap("encode", t2, t3, se)

# Bend evaluates strictly: the output is built before t3 is read.
def op.encode(+dt: String, +sd: String, t2: Time.Duration, xs: List<&1, Tar.Entry>) -> IO(Unit):
  out = Tar.encode(xs)
  do IO<Unit>:
    t3 : Time.Duration <- Time.mono()
    op.encoded(dt, sd, t2, t3, out)

# The decoded entries are summed between the two timed spans.
def op.summed(+dt: String, r: List<&1, Tar.Entry> & U32) -> IO(Unit):
  (xs, +h) = r
  +sd = U32.show(h)
  do IO<Unit>:
    t2 : Time.Duration <- Time.mono()
    op.encode(dt, sd, t2, xs)

def op.decoded(t0: Time.Duration, m: Maybe<&1, List<&1, Tar.Entry>>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("decode\t0\tfailed")
    case Some{xs}:
      do IO<Unit>:
        t1 : Time.Duration <- Time.mono()
        op.summed(Time.Duration.show_ms(Time.Duration.sub(t1, t0)), sum(xs, State{Nil{}, 0, 0}))

# The file is read as octets and packed into Bytes before the timer starts.
def op.decode(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.decoded(t0, Tar.decode(b))

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

def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    op.decode(Bytes.from_string(octets(list(r))))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 16777216)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    f : Result<&1, &1, U32 & String, File> <- File.open("out/input.tar", "r")
    opened(f)
