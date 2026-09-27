# Unicode benchmark: NFC and grapheme clusters on one fixed input (see README.md).
import Base
import ../../time/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ../../encoding/encoding.bend as Enc
import ../unicode.bend as U

# Must match gen_input.py: ceil(1_000_000 / seed UTF-8 bytes) with seed bytes = 212.
def REPS() -> Nat:
  4717n

def of(xs: List<U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, of(t)}

# Same code-point sequence as gen_input.py SEED.
def seed() -> String:
  of([84, 104, 101, 32, 113, 117, 105, 99, 107, 32, 98, 114, 111, 119, 110, 32, 102, 111, 120, 32, 106, 117, 109, 112, 115, 32, 111, 118, 101, 114, 32, 116, 104, 101, 32, 108, 97, 122, 121, 32, 100, 111, 103, 46, 32, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 10, 99, 97, 102, 101, 769, 32, 110, 97, 305, 118, 101, 32, 99, 111, 776, 111, 112, 101, 114, 97, 116, 101, 32, 233, 241, 32, 4352, 4449, 4520, 32, 44032, 32, 54620, 44544, 32, 50504, 45397, 32, 2325, 2367, 2351, 2366, 32, 2342, 2375, 2357, 2344, 2366, 2327, 2352, 2368, 32, 128104, 8205, 128105, 8205, 128103, 8205, 128102, 32, 127995, 8205, 9792, 65039, 32, 127482, 127480, 32, 127468, 127463, 32, 10])

def rep(n: Nat, +seed: String, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      rep(p, seed, seed ++ acc)

def input() -> String:
  rep(REPS(), seed(), SNil{})

# Checksum over UTF-8 octets: h = h*31 + b, u32, then add the byte count.
def hash.oct(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{c}, t}:
      hash.oct(t, (h * 31 + c : U32), (n + 1 : U32))

def hash.bytes(b: Bytes.Bytes) -> U32:
  hash.oct(Bytes.to_string(b), 0, 0)

def count(+gs: List<&2, String>, n: U32) -> U32:
  match gs:
    case Nil{}:
      n
    case Con{h, t}:
      count(t, (n + 1 : U32))

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, +chk: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))

def op.nfc_done(t0: Time.Duration, out: String) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    lap("nfc", t0, t1, hash.bytes(Enc.utf8.encode(out)))

def op.nfc(+s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.nfc_done(t0, U.nfc(s))

def op.graphemes_done(t0: Time.Duration, gs: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    lap("graphemes", t0, t1, count(gs, 0))

def op.graphemes(+s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.graphemes_done(t0, U.graphemes(s))

def run(+s: String) -> IO(Unit):
  do IO<Unit>:
    op.nfc(s)
    op.graphemes(s)

def main() -> IO(Unit):
  run(input())
