# Crypto benchmark: SHA-256 of 16 MiB of zero bytes, and PBKDF2-HMAC-SHA-256 with 100,000 iterations (see README.md).
import Base
import ../../time/time.bend as Time
import ../crypto.bend as C
import ../../bytes/bytes.bend as Bytes

def lap(+op: String, t0: Time.Duration, t1: Time.Duration, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print(op ++ "\t0\tfailed")
    case Done{(+len, buf)}:
      IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ Bytes.to_hex(Bytes.Bytes{len, buf}))

def sha(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.sha256.words(len, buf)
    t1 : Time.Duration <- Time.mono()
    lap("sha256", t0, t1, r)

def kdf(p: Bytes.Bytes, s: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+pn, pb} = p
  Bytes.Bytes{+sn, sb} = s
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.pbkdf2.words("SHA256", pn, pb, sn, sb, 100000, 32)
    t1 : Time.Duration <- Time.mono()
    lap("pbkdf2", t0, t1, r)

def main() -> IO(Unit):
  do IO<Unit>:
    sha(Bytes.new(16777216))
    kdf(Bytes.from_string("password"), Bytes.from_string("salt"))
