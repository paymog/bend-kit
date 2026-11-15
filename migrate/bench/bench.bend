# Migration benchmark: parse a JSON array of records, decode and upgrade each to v3, and encode (see README.md).
import Base
import ../../time/time.bend as Time
import ../migrate.bend as M
import bend-kit-json@0.7.0.0/json.bend as Json
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

# Checksum: h = h*31 + c, u32, then add the length.
def hash(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{c}, t}:
      hash(t, (h * 31 + c : U32), (n + 1 : U32))

def v3(p: M.V3 & M.Dropped) -> Json.Val:
  (r, d) = p
  M.V3.json(r)

# A record that fails to decode becomes null, so its checksum differs from the other languages.
def one(r: Result<&1, &1, M.Error, M.Record>) -> Json.Val:
  match r:
    case Fail{e}:
      Json.Null{}
    case Done{x}:
      v3(M.Record.upgrade(x))

def all(xs: List<&1, Json.Val>) -> List<&1, Json.Val>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{v, t}:
      Con{one(M.decode.val(v)), all(t)}

def migrate(m: Maybe<&1, Json.Val>) -> Json.Val:
  match m:
    case Some{Json.Arr{xs}}:
      Json.Arr{all(xs)}
    case _:
      Json.Null{}

def done(t0: Time.Duration, t1: Time.Duration, out: Bytes.Bytes) -> IO(Unit):
  IO.print("migrate\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(hash(Bytes.to_string(out), 0, 0)))

# Bend evaluates strictly: the output is built before t1 is read.
def run(t0: Time.Duration, b: Bytes.Bytes) -> IO(Unit):
  out = Json.encode.bytes(migrate(Json.parse.strict.bytes(b, 2)))
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    done(t0, t1, out)

def start(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    run(t0, b)

def text(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Fail{e}:
      SNil{}
    case Done{s}:
      s

def read(m: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    start(Bytes.from_string(text(r)))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, String> <- File.read(f, 67108864)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    f : Result<&1, &1, U32 & String, File> <- File.open("out/doc.json", "r")
    opened(f)
