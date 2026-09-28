# OAuth2 benchmark: a chain of 10,000 PKCE S256 challenges, and 10,000 parses of one token response (see README.md).
import Base
import ../../time/time.bend as Time
import ../oauth2.bend as O
import bend-kit-time@0.1.0.0/time.bend as HT
import 0x4eed9d7ac6ece61523d747a9d804e4f0/int.bend as Int
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def got(r: Result<&1, &1, O.Err, String>) -> String:
  match r:
    case Fail{e}:
      "failed"
    case Done{s}:
      s

# v_{i+1} = S256(v_i): each challenge is itself a valid 43-char verifier.
def chain(n: Nat, +v: String) -> IO(String):
  match n:
    case 0n:
      IO.pure(String, v)
    case 1n+k:
      do IO<String>:
        r : Result<&1, &1, O.Err, String> <- O.challenge(v)
        chain(k, got(r))

def tally(t: Result<&1, &1, O.Err, O.Token>, acc: U32 & Maybe<&2, O.Token>) -> U32 & Maybe<&2, O.Token>:
  match t:
    case Fail{e}:
      acc
    case Done{tok}:
      (+g, last) = acc
      ((g + 1 : U32), Some{tok})

def parses(n: Nat, acc: U32 & Maybe<&2, O.Token>, r: Bytes.Bytes & Bytes.Bytes) -> U32 & Maybe<&2, O.Token>:
  match n:
    case 0n:
      acc
    case 1n+k:
      (b, c) = r
      parses(k, tally(O.parse(200, "", HT.Instant.epoch(), c), acc), Bytes.slice(b, 0, 4294967295))

def secs(e: Maybe<&2, HT.Instant>) -> String:
  match e:
    case None{}:
      "none"
    case Some{HT.Instant{s, n}}:
      Int.I64.show(s)

# good, then the last token's access length, refresh token, scope, and expires_in.
def sum(r: U32 & Maybe<&2, O.Token>) -> String:
  (+g, m) = r
  match m:
    case None{}:
      U32.show(g)
    case Some{O.Token{a, k, rt, s, e}}:
      U32.show(g) ++ " " ++ Nat.show(String.length(a)) ++ " " ++ rt ++ " " ++ s ++ " " ++ secs(e)

def rep(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+k:
      SCon{'A', rep(k)}

def body() -> String:
  "{\"access_token\":\"" ++ rep(1024n) ++ "\",\"token_type\":\"Bearer\",\"expires_in\":3600,\"refresh_token\":\"tGzv3JOkF0XG5Qx2TlKWIA\",\"scope\":\"openid profile email\"}"

def lap(+op: String, t0: Time.Duration, t1: Time.Duration, +out: String) -> IO(Unit):
  IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ out)

def main() -> IO(Unit):
  +b = body()
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    v : String <- chain(10000n, "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    t1 : Time.Duration <- Time.mono()
    lap("pkce", t0, t1, v)
    t2 : Time.Duration <- Time.mono()
    r : U32 & Maybe<&2, O.Token> <- IO.pure(U32 & Maybe<&2, O.Token>, parses(10000n, (0, None{}), Bytes.slice(Bytes.from_string(b), 0, 4294967295)))
    t3 : Time.Duration <- Time.mono()
    lap("parse", t2, t3, sum(r))
