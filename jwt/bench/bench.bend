# JWT verify benchmark: one fixed HS256 and one fixed RS256 token, 10,000 verifies each (see README.md).
import Base
import ../../time/time.bend as Time
import ../jwt.bend as Jwt
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import 0x584fc27920487ceab242392391418d7f/json.bend as Json

def N() -> Nat:
  10000n

def secret() -> String:
  "bend-kit-jwt-bench-hs256-secret-0123456789"

def pem() -> String:
  "-----BEGIN PUBLIC KEY-----\n" ++
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnAfhVvP/esxVFB9kHsuw\n" ++
    "I83x79PE8FzlNOOogtlz08Pwjjf14zxEB46KHCy344mFXAFGuerTLiqRXlxd2/i8\n" ++
    "ITk4L6hCsktjri3VBK+KkTii7dh9LbqwE083DHLL5TyUr+1Br7KmIzP76T2VaQ2c\n" ++
    "7l+Iv8IAH8COhDf4x8raeTFDP67DyxsoHmxBdkSEKbdG9Tbl17fw44uxnqHko/5y\n" ++
    "FmfFuzgjQ1NhQ0yymUC5uzdS+s333dXwMjxl+k/BQvcfEYc0EdaUiwrgtSBrgkqd\n" ++
    "wpLIyVPQ59xLs5KDBEdNtRGv98IuBzwIImco3i8Ad+YB826w3NrehEinid91F7eg\n" ++
    "yQIDAQAB\n" ++
    "-----END PUBLIC KEY-----\n"

def hs256() -> String:
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.DiAMBIAhI-CRSG3YSeQgSUn9D0fEYLlpbvvw5Ogd7GI"

def rs256() -> String:
  "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.Hmu8V5e7RcP-BEzxtCkvda0si-bTm8UbP-yhSTvLdZq0i1gORUFRsS8_F8qJCLsjOf1cH6EsCUb4y7Sh1F4b_FMDrwtlSBAEnR1riEikfg_Yu63SDUPRnY9bdI3QJ933aPJcL1t-D3yX7_nBA2IDau8Tag26nmLNSlM3yYmPROVEtxpDm26YVwESoIaS_kCzmVqzmAdqnCkLPloDdTeWaWkeRwmYmJkXmftSLj4ZqqkgtYWhTMeq6AhXUK53NVW_4oXEhVSH0cbLlxLRDX-dFSk8mdaaT4WoRNLurQuf9kInVNudrRv-a5cxUMjifN-sJHq9RZrbvVBnhInwdEWymw"

def token(rs: Bool) -> String:
  match rs:
    case True{}:
      rs256()
    case False{}:
      hs256()

# A Key is not copyable and verify takes it, so each verify builds its key from the fixed text.
def key(rs: Bool) -> Jwt.Key:
  match rs:
    case True{}:
      Jwt.Pem{Bytes.from_string(pem())}
    case False{}:
      Jwt.Hmac{Bytes.from_string(secret())}

def iat.num(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{x}:
      x
    case None{}:
      0

def iat.val(m: Maybe<&1, Json.Val>) -> U32:
  match m:
    case Some{v}:
      iat.num(Json.u32(v))
    case None{}:
      0

# The verified iat claim; 0 on a failed verify, which breaks the checksum.
def iat(r: Result<&1, &1, Jwt.Err, Json.Val>) -> U32:
  match r:
    case Fail{e}:
      0
    case Done{c}:
      iat.val(Json.get(c, "iat"))

# Checksum: the sum of the verified iat claims, u32.
def loop(n: Nat, +rs: Bool, +acc: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, acc)
    case 1n+p:
      do IO<U32>:
        r : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Bool.pick(Jwt.Alg, rs, Jwt.RS256{}, Jwt.HS256{})), key(rs), token(rs), 1700000000)
        loop(p, rs, (acc + iat(r) : U32))

def run(+op: String, +rs: Bool) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    s : U32 <- loop(N(), rs, 0)
    t1 : Time.Duration <- Time.mono()
    IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(s))

def main() -> IO(Unit):
  do IO<Unit>:
    run("hs256", False{})
    run("rs256", True{})
