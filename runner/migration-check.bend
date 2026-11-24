import Base
import ./model.bend as Model
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-encoding@0.5.0.1/encoding.bend as Encoding
import bend-kit-journal@0.3.1.3/journal.bend as J

def decode(b: Bytes.Bytes) -> Maybe<&2, String>:
  Some{Encoding.utf8.decode(b)}

def snapshot(s: Maybe<&2, Model.State<String>>) -> IO(String):
  match s:
    case None{}:
      IO.die(String, 1, "migration: record rejected")
    case Some{s}:
      IO.pure(String, Bytes.to_hex(Model.encode.snap(~String, ~(s => Encoding.utf8.encode(s)), s)))

def read.got(x: J.Journal & Maybe<&2, Model.State<String>>) -> IO(String):
  (j, s) = x
  do IO<String>:
    J.close(j)
    snapshot(s)

def read(+path: String) -> IO(String):
  do IO<String>:
    x : J.Journal & Maybe<&2, Model.State<String>> <- IO.try(J.Journal & Maybe<&2, Model.State<String>>,
      J.open(~Maybe<&2, Model.State<String>>, ~(s => b => Model.replay.step(~String, ~decode, s, b)), path, 1048576, 1048576, Some{Model.new(String)}))
    read.got(x)

def compare(ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "migration: replay changed state")
    case True{}:
      IO.print("ok migration replay before crash recovery")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{program, Con{actual, Con{expected, Nil{}}}}:
      do IO<Unit>:
        a : String <- read(actual)
        b : String <- read(expected)
        compare(String.eq(a, b))
    case xs:
      IO.die(Unit, 1, "usage: migration-check actual expected")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
