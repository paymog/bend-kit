import Base
import ./jwt.bend as Jwt
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Signatures need libcrypto, so they run here: RFC 7515 A.1-A.3 verify, sign round trips, and rejections.
# The RSA 2048 and P-256 PEM pairs are throwaway test keys.

def name(e: Jwt.Err) -> String:
  match e:
    case Jwt.Malformed{}:
      "Malformed"
    case Jwt.AlgMismatch{}:
      "AlgMismatch"
    case Jwt.Crit{}:
      "Crit"
    case Jwt.KeyType{}:
      "KeyType"
    case Jwt.WeakKey{}:
      "WeakKey"
    case Jwt.BadSig{}:
      "BadSig"
    case Jwt.BadClaim{}:
      "BadClaim"
    case Jwt.Expired{}:
      "Expired"
    case Jwt.NotYet{}:
      "NotYet"
    case Jwt.Future{}:
      "Future"
    case Jwt.BadIss{}:
      "BadIss"
    case Jwt.BadAud{}:
      "BadAud"
    case Jwt.NoKey{}:
      "NoKey"
    case Jwt.Crypto{c, w}:
      "Crypto " ++ U32.show(c) ++ " " ++ w
    case Jwt.Net{x}:
      "Net"
    case Jwt.Status{c}:
      "Status " ++ U32.show(c)

def ok(b: Bool, +label: String, +got: String) -> IO(Unit):
  match b:
    case True{}:
      IO.print("ok " ++ label)
    case False{}:
      IO.die(Unit, 1, label ++ " gave " ++ got)

def show(r: Result<&1, &1, Jwt.Err, Json.Val>) -> String:
  match r:
    case Fail{e}:
      name(e)
    case Done{v}:
      "Done"

# want is "Done" or the Err's name.
def expect(+label: String, +want: String, r: Result<&1, &1, Jwt.Err, Json.Val>) -> IO(Unit):
  +got = show(r)
  ok(String.eq(got, want), label, got)

def b(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def u(+s: String) -> Bytes.Bytes:
  Maybe.default(&1, Bytes.Bytes, Jwt.unb64u(s), Bytes.new(0))

# RFC 7515 A.1's 64-octet HMAC key.
def hk() -> Jwt.Key:
  Jwt.Hmac{u("AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow")}

# RFC 7515 A.2's RSA and A.3's P-256 public keys, as JWK parts.
def rk() -> Jwt.Key:
  Jwt.Rsa{u("ofgWCuLjybRlzo0tZWJjNiuSfb4p4fAkd_wWJcyQoTbji9k0l8W26mPddxHmfHQp-Vaw-4qPCJrcS2mJPMEzP1Pt0Bm4d4QlL-yRT-SFd2lZS-pCgNMsD1W_YpRPEwOWvG6b32690r2jZ47soMZo9wGzjb_7OMg0LOL-bSf63kpaSHSXndS5z5rexMdbBYUsLA9e-KXBdQOS-UTo7WTBEMa2R2CapHg665xsmtdVMTBQY4uDZlxvb3qCo5ZwKh9kG4LT6_I5IhlJH7aGhyxXFvUK-DWNmoudF8NAco9_h9iaGNj8q2ethFkMLs91kzk2PAcDTW9gb54h4FRWyuXpoQ"), u("AQAB")}

def ek() -> Jwt.Key:
  Jwt.Ec{u("f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU"), u("x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0")}

def rsa.priv() -> Jwt.Key:
  Jwt.Pem{b("-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCTd71Sa4SxbVJb\nCNzATIpNQYXXEslBIfsRZfvMU6c1fH+Yh2KLop67HUoTedZw5rQBLIWmPqaOD8aT\ner8VUzm1kLg9HByupYVWMHyOk4e5FbppuqUwpKSA9NnUEhamL2c6cTr+mvPQikK7\nI4ai4WawXa5WmVHVv4p15WYzCUQz5R6kdMKZ7hGdCScpwztN/Y3Q7AbvPnuYEVb+\ngiFqh5apInJ0UG4XU6ylFN/816djehgm26LSxeZatT6LT4CuqXW+JFMHa5jipNQ7\nfUwOOOnKWxu3G7JiFbf1FtQcX7OIC2SHK2W6d6YaJhnF9oiMo9WXj84odHED9R1g\nL1aLH5GdAgMBAAECggEAD86pA5m02pP+XPXBO/e4Z3mbkCdaXVn4ILBO4mMhLFGR\nF9eDT7Z5z1LfauEHhIimSO3t0Zkrn1S/k3V34CBQsk62AQ7vYCUr+sYtw9a6mLNk\njQrNxD4RyCT26I2b0eqI5THYAgy4D+WSK58uQm1o5YTVOEEtDX1/qQ2S++uFXQ6L\noODoduH3rKMrVmn1tVSg9fdP8mWKUC5rjAaNDwVGUVeLYKBk9NaqDteVDmCM6rBE\nUFw/3KFvTBogP/32VTt+psVXERUqM1jESwWksaniuHaFYudN3rdb4pPgAD7w6IKt\nAUImkbRUhowrenOBoUTreYd39JOlqsuUh/q3vElZHQKBgQDJX6hYGwat6o7INnyi\nNZpYsn7d5Trd5htzTsHxShJm2Cx7lrqy8EjwgdIf49fzj6uHB7vCZnaxMT0ugoUz\n34IwBWWWiJDQCI2PWDj1mO/J4VsgOZ6fmS7IzxC0WfCjf8t2K/koQW7jtkN4wTgl\n5YID3nQH+MaCGjC73OyhUG7FGwKBgQC7eJk0GLTvNXQj7jxtLEWt77w0Ygnbp82Y\nYfHtYcjqoNOu7JtlCISZLA5jUdM7vqC5QcvMa9MqByA58ACfRMrJ4m8ni2seQGtQ\n2SN6YMjWW+P262ggvbTONTqKvyf/G2WFCxe3l8IEt79s/oNGT0ngpcvzOdxsZpse\nE3Mcwj/HpwKBgEU6L2Nqlxc+5asKoDobd146rsaVwXD7ZEB1uNK8hir48gHixXgy\nhsC3wIbaCyleILeg/vlLxE4SAVh14lj844KiuFPRywbZieDXkW1NEFI0uOERLejr\n/ltmY/W8Xa+3hTiw0Uz3gamixPtEYYsVpWazGOyMp6GeY1aSEn86aXo1AoGAZQ6d\nh3fKESi/cp7589/pr9mLmrE+nynVqk8iGtSbed84PRNOsSfmUqttFh0FwS8BdNwD\nAC8fpYgx1wmJTFHI/wsQ4EBHfgc70lk6xr1lhigCuxgrCXs5++61oBVrehlKoG1a\nW51y+RgUGK0aFsynBnJZfsOyDr1A4PWbF+WefAECgYBD6vyPKaRHBoF21L3DCYXD\no1JyxC3zVj3PxSeOBFsqfMyLpiE24uDoWgK4QOI0/CnBf5YmZlN7IEHTGt6Myf/G\nwlz7/WsuapuwdGfbbBw1IcB4BGtsRzRgHKp9plsAMgG2foSqhELYv+uABxENduo5\nwzNw/lDBcGXW/zMfAKgxEQ==\n-----END PRIVATE KEY-----\n")}

def rsa.pub() -> Jwt.Key:
  Jwt.Pem{b("-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAk3e9UmuEsW1SWwjcwEyK\nTUGF1xLJQSH7EWX7zFOnNXx/mIdii6Keux1KE3nWcOa0ASyFpj6mjg/Gk3q/FVM5\ntZC4PRwcrqWFVjB8jpOHuRW6abqlMKSkgPTZ1BIWpi9nOnE6/prz0IpCuyOGouFm\nsF2uVplR1b+KdeVmMwlEM+UepHTCme4RnQknKcM7Tf2N0OwG7z57mBFW/oIhaoeW\nqSJydFBuF1OspRTf/NenY3oYJtui0sXmWrU+i0+Arql1viRTB2uY4qTUO31MDjjp\nylsbtxuyYhW39RbUHF+ziAtkhytlunemGiYZxfaIjKPVl4/OKHRxA/UdYC9Wix+R\nnQIDAQAB\n-----END PUBLIC KEY-----\n")}

def ec.priv() -> Jwt.Key:
  Jwt.Pem{b("-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg59CCYA5n/LhMCuLm\nZwX1fT1Ual7DTtoTZp5++RlPk/2hRANCAAT23iq969ZHQ9PWKa7W5bOGGLOov5/X\nuh5HnWiB0pU68R7MarPryfE6GPKwIihjNAksKiH6J7mdPXAZCLFTfg4y\n-----END PRIVATE KEY-----\n")}

def ec.pub() -> Jwt.Key:
  Jwt.Pem{b("-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE9t4qvevWR0PT1imu1uWzhhizqL+f\n17oeR51ogdKVOvEezGqz68nxOhjysCIoYzQJLCoh+ie5nT1wGQixU34OMg==\n-----END PUBLIC KEY-----\n")}

def rfc.hs() -> String:
  "eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

def rfc.rs() -> String:
  "eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.cC4hiUPoj9Eetdgtv3hF80EGrhuB__dzERat0XF9g2VtQgr9PJbu3XOiZj5RZmh7AAuHIm4Bh-0Qc_lF5YKt_O8W2Fp5jujGbds9uJdbF9CUAr7t1dnZcAcQjbKBYNX4BAynRFdiuB--f_nZLgrnbyTyWzO75vRK5h6xBArLIARNPvkSjtQBMHlb1L07Qe7K0GarZRmB_eSN9383LcOLn6_dO--xi12jzDwusC-eOkHWEsqtFZESc6BfI7noOPqvhJ1phCnvWh6IeYI2w9QOYEUipUTI8np6LbgGY9Fs98rqVt5AXLIhWkWywlVmtVrBp0igcN_IoypGlUPQGe77Rw"

def rfc.es() -> String:
  "eyJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8ISlSApmWQxfKTUJqPP3-Kg6NU1Q"

def claims() -> Json.Val:
  Json.Obj{[(Json.utf8("iss"), Json.Str{Json.utf8("me")}), (Json.utf8("aud"), Json.Str{Json.utf8("api")}), (Json.utf8("exp"), Json.Num{Json.utf8("2000000000")})]}

def pol(+a: Jwt.Alg) -> Jwt.Policy:
  Jwt.aud(Jwt.iss(Jwt.policy(a), "me"), "api")

def trip.go(+label: String, +a: Jwt.Alg, pub: Jwt.Key, +now: U32, +want: String, r: Result<&1, &1, Jwt.Err, String>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, label ++ " sign failed: " ++ name(e))
    case Done{t}:
      do IO<Unit>:
        v : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(pol(a), pub, t, now)
        expect(label, want, v)

# sign with priv, then verify with pub at now.
def trip(+label: String, +a: Jwt.Alg, priv: Jwt.Key, pub: Jwt.Key, +now: U32, +want: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, Jwt.Err, String> <- Jwt.sign(a, priv, Some{"k1"}, claims())
    trip.go(label, a, pub, now, want, r)

def signs(+label: String, +want: String, r: Result<&1, &1, Jwt.Err, String>) -> IO(Unit):
  match r:
    case Fail{e}:
      +got = name(e)
      ok(String.eq(got, want), label, got)
    case Done{t}:
      ok(String.eq("Done", want), label, t)

def same(+label: String, +want: String, +got: String) -> IO(Unit):
  ok(String.eq(got, want), label, got)

def joe() -> Bytes.Bytes:
  Json.encode.bytes(Json.Obj{[(Json.utf8("iss"), Json.Str{Json.utf8("joe")})]})

def main() -> IO(Unit):
  do IO<Unit>:
    # The header sign writes over {"iss":"joe"}: {"alg":..,"typ":"JWT"}, then kid when given.
    same("signing input", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJqb2UifQ", Jwt.signing.input(Jwt.HS256{}, None{}, joe()))
    same("signing input with kid", "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImsxIn0.eyJpc3MiOiJqb2UifQ", Jwt.signing.input(Jwt.ES256{}, Some{"k1"}, joe()))
    # RFC 7515 A.1-A.3 (the RFC 7519 §3.1 claims): authentic, before exp.
    r1 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.iss(Jwt.policy(Jwt.HS256{}), "joe"), hk(), rfc.hs(), 1300819000)
    expect("rfc7515 A.1 HS256", "Done", r1)
    r2 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.RS256{}), rk(), rfc.rs(), 1300819000)
    expect("rfc7515 A.2 RS256 jwk", "Done", r2)
    r3 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.ES256{}), ek(), rfc.es(), 1300819000)
    expect("rfc7515 A.3 ES256 jwk", "Done", r3)
    # Rejections.
    r4 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.HS256{}), hk(), rfc.hs(), 1300819380)
    expect("rfc7519 expired", "Expired", r4)
    r5 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.HS256{}), hk(), "eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXg", 1300819000)
    expect("hs256 tampered signature", "BadSig", r5)
    r6 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.HS256{}), hk(), "eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", 1300819000)
    expect("hs256 header swapped", "BadSig", r6)
    r7 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.RS256{}), hk(), rfc.rs(), 1300819000)
    expect("rs256 with an hmac key", "KeyType", r7)
    r8 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.HS256{}), rsa.pub(), rfc.hs(), 1300819000)
    expect("hs256 with a pem key", "KeyType", r8)
    r9 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.RS256{}), rk(), rfc.hs(), 1300819000)
    expect("hs256 token pinned to rs256", "AlgMismatch", r9)
    r10 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.HS256{}), hk(), "eyJhbGciOiJub25lIn0.eyJpc3MiOiJqb2UifQ.", 0)
    expect("alg none", "AlgMismatch", r10)
    r11 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.ES256{}), ek(), rfc.rs(), 1300819000)
    expect("rs256 token pinned to es256", "AlgMismatch", r11)
    r12 : Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify(Jwt.policy(Jwt.RS256{}), rsa.pub(), rfc.rs(), 1300819000)
    expect("rfc rs256 under another rsa key", "BadSig", r12)
    # Round trips, and the rejections a verifier with the wrong expectations gives.
    trip("hs256 round trip", Jwt.HS256{}, hk(), hk(), 1700000000, "Done")
    trip("hs512 round trip", Jwt.HS512{}, hk(), hk(), 1700000000, "Done")
    trip("hs384 round trip", Jwt.HS384{}, hk(), hk(), 1700000000, "Done")
    trip("rs256 round trip", Jwt.RS256{}, rsa.priv(), rsa.pub(), 1700000000, "Done")
    trip("es256 round trip", Jwt.ES256{}, ec.priv(), ec.pub(), 1700000000, "Done")
    trip("round trip expired", Jwt.HS256{}, hk(), hk(), 2000000000, "Expired")
    trip("es256 wrong key", Jwt.ES256{}, ec.priv(), ek(), 1700000000, "BadSig")
    s1 : Result<&1, &1, Jwt.Err, String> <- Jwt.sign(Jwt.HS256{}, Jwt.Hmac{b("short")}, None{}, claims())
    signs("hs256 short secret", "WeakKey", s1)
    s2 : Result<&1, &1, Jwt.Err, String> <- Jwt.sign(Jwt.HS256{}, hk(), None{}, Json.Arr{[]})
    signs("claims not an object", "BadClaim", s2)
    s3 : Result<&1, &1, Jwt.Err, String> <- Jwt.sign(Jwt.HS256{}, hk(), None{}, Json.Obj{[(Json.utf8("a"), Json.Null{}), (Json.utf8("a"), Json.Null{})]})
    signs("claims repeat a name", "BadClaim", s3)
    s4 : Result<&1, &1, Jwt.Err, String> <- Jwt.sign(Jwt.RS256{}, hk(), None{}, claims())
    signs("rs256 with an hmac key", "KeyType", s4)
