# Regex benchmark: match and search on fixed inputs (see README.md).
import Base
import ../../time/time.bend as Time
import ../regex.bend as R
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def mix(+acc: U32, +x: U32) -> U32:
  (acc * 31 + x : U32)

def chk_sp(m: Maybe<&2, R.Span>, +acc: U32) -> U32:
  match m:
    case None{}:
      (acc * 31 : U32)
    case Some{R.Span{start, end}}:
      mix(mix(acc, start), end)

def chk_spans(xs: List<&2, Maybe<&2, R.Span>>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      chk_spans(t, chk_sp(h, acc))

def chk_find(m: Maybe<&2, List<&2, Maybe<&2, R.Span>>>) -> U32:
  match m:
    case None{}:
      0
    case Some{xs}:
      chk_spans(xs, 0)

def text(+size: Nat) -> String:
  +e = (size - 50n : Nat)
  +h = (size - 20n : Nat)
  String.repeat("x", e) ++ "user@host.com" ++ String.repeat("x", (h - e - 13n : Nat)) ++ "helloworld12" ++ String.repeat("x", (size - h - 12n : Nat))

def lap(+name: String, t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ U32.show(chk))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\t" ++ name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def chk_bfind(p: Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, R.Span>>>) -> U32:
  (b, m) = p
  chk_find(m)

def chk_bhit(p: Bytes.Bytes & Bool) -> U32:
  (b, x) = p
  Bool.pick(U32, x, 1, 0)

# The text becomes Bytes before the clock starts.
def with_re(m: Maybe<&2, R.Regex>, +s: String, +name: String) -> IO(Unit):
  match m:
    case None{}:
      IO.print("error")
    case Some{re}:
      do IO<Unit>:
        b : Bytes.Bytes = Bytes.from_string(s)
        t0 : Time.Duration <- Time.mono()
        lap(name, t0, chk_bfind(R.find.bytes(re, b)))

def with_hit(m: Maybe<&2, R.Regex>, +s: String, +name: String) -> IO(Unit):
  match m:
    case None{}:
      IO.print("error")
    case Some{re}:
      do IO<Unit>:
        b : Bytes.Bytes = Bytes.from_string(s)
        t0 : Time.Duration <- Time.mono()
        lap(name, t0, chk_bhit(R.is_match.bytes(re, b)))

def op.is_match(+s: String) -> IO(Unit):
  with_hit(R.compile("hello\\w+"), s, "is_match")

def op.is_match_early(+s: String) -> IO(Unit):
  with_hit(R.compile("x"), s, "is_match_early")

def op.is_match_live(+s: String) -> IO(Unit):
  with_hit(R.compile("xy"), s, "is_match_live")

def op.find_captures(+s: String) -> IO(Unit):
  with_re(R.compile("(\\w+)@(\\w+)\\.com"), s, "find_captures")

def op.find_early(+s: String) -> IO(Unit):
  with_re(R.compile("(x)x"), s, "find_early")

def op.sparse(+s: String) -> IO(Unit):
  with_re(R.compile("x@host\\.org"), s, "sparse")
def op.sparse_hit(+s: String) -> IO(Unit):
  with_re(R.compile("x.{0,4}@host\\.org"), String.repeat("x", (String.length(s) - 9n : Nat)) ++ "@host.org", "sparse_hit")


def op.redos() -> IO(Unit):
  do IO<Unit>:
    with_re(R.compile("(a*)*b"), String.repeat("a", 100000n), "redos")

# About 2000 instructions: each char walks a closure over most of the program.
def op.large() -> IO(Unit):
  do IO<Unit>:
    with_re(R.compile("(?:x?){1000}y"), String.repeat("x", 1000n) ++ "y", "large")

def run_all(+s: String) -> IO(Unit):
  do IO<Unit>:
    op.is_match(s)
    op.is_match_early(s)
    op.is_match_live(s)
    op.find_captures(s)
    op.sparse(s)
    op.sparse_hit(s)
    op.find_early(s)
    op.redos()
    op.large()

def run_text(+s: String, +only: String) -> IO(Unit):
  match only:
    case "":
      run_all(s)
    case "is_match":
      op.is_match(s)
    case "is_match_early":
      op.is_match_early(s)
    case "is_match_live":
      op.is_match_live(s)
    case "find_captures":
      op.find_captures(s)
    case "find_early":
      op.find_early(s)
    case "sparse":
      op.sparse(s)
    case "sparse_hit":
      op.sparse_hit(s)
    case "redos":
      op.redos()
    case "large":
      op.large()
    case _:
      IO.print("error")

def first(args: List<&1, String>) -> String:
  match args:
    case Con{h, t}:
      h
    case Nil{}:
      ""

def run(+size: Nat, +only: String) -> IO(Unit):
  run_text(text(size), only)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(1048576n, first(List.tail(&1, String, args)))
