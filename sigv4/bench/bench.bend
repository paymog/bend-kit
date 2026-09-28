# SigV4 signing benchmark: sign one fixed S3 PUT 10,000 times (see README.md).
import Base
import ../../time/time.bend as Time
import ../sigv4.bend as Sigv4
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def sign() -> IO(Result<&1, &1, U32 & String, String & String>):
  Sigv4.authorize(Sigv4.Credentials{"AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", ""}, "us-east-1", "s3", "20130524T000000Z", "PUT", "/test.txt", "x-id=PutObject", "examplebucket.s3.amazonaws.com", Bytes.from_string("Welcome to Amazon S3."))

# The signature, the last 64 hex digits of the Authorization value, or exit with the signer's error.
def signature(r: Result<&1, &1, U32 & String, String & String>) -> IO(String):
  match r:
    case Fail{(+code, msg)}:
      IO.die(String, code, "sigv4: " ++ msg)
    case Done{(auth, hash)}:
      IO.pure(String, String.reverse(String.take(String.reverse(auth), 64n)))

def loop(n: Nat, last: String) -> IO(String):
  match n:
    case 0n:
      IO.pure(String, last)
    case 1n+p:
      do IO<String>:
        r : Result<&1, &1, U32 & String, String & String> <- sign()
        s : String <- signature(r)
        loop(p, s)

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    sig : String <- loop(10000n, "")
    t1 : Time.Duration <- Time.mono()
    IO.print("sign\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ sig)
