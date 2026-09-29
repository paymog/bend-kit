# scrypt benchmark: one 32-octet key from N = 16384, r = 8, p = 1 (see README.md).
import Base
import ../../../time/time.bend as Time
import ../../crypto.bend as C
import ../../../bytes/bytes.bend as Bytes

def derive(p: Bytes.Bytes, s: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+plen, pass} = p
  Bytes.Bytes{+slen, salt} = s
  C.scrypt.words(plen, pass, slen, salt, 16384, 8, 1, 67108864, 32)

# Checksum: the derived key in hex, taken after the timer stops.
def report(t0: Time.Duration, t1: Time.Duration, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "scrypt failed: " ++ why)
    case Done{(+len, buf)}:
      IO.print("scrypt\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ Bytes.to_hex(Bytes.Bytes{len, buf}))

def run(p: Bytes.Bytes, s: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(p, s)
    t1 : Time.Duration <- Time.mono()
    report(t0, t1, r)

def main() -> IO(Unit):
  run(Bytes.from_string("pleaseletmein"), Bytes.from_string("SodiumChloride"))
