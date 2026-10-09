import Base
import ./jwt.bend as Jwt
import ../hairpin/hairpin.bend as Hairpin
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# JWKS fetch and cache against the local server jwks-check.sh runs. The set's tried time shows whether a
# call fetched. Two throwaway P-256 keys: "a" in a.json, "a" and "b" in b.json.

def name(e: Jwt.Err) -> String:
  match e:
    case Jwt.AlgMismatch{}:
      "AlgMismatch"
    case Jwt.BadSig{}:
      "BadSig"
    case Jwt.NoKey{}:
      "NoKey"
    case Jwt.Status{c}:
      "Status " ++ U32.show(c)
    case Jwt.Crypto{c, w}:
      "Crypto " ++ U32.show(c) ++ " " ++ w
    case Jwt.Net{x}:
      "Net"
    case _:
      "other"

def show(r: Result<&1, &1, Jwt.Err, Json.Val>) -> String:
  match r:
    case Fail{e}:
      name(e)
    case Done{v}:
      "Done"

def tried.show(m: Maybe<&2, U32>) -> String:
  match m:
    case None{}:
      "never"
    case Some{x}:
      U32.show(x)

def tried(s: Jwt.Jwks) -> String:
  Jwt.Jwks{u, t, l, a, tr, ks} = s
  tried.show(tr)

def ok(b: Bool, +label: String, +got: String) -> IO(Unit):
  match b:
    case True{}:
      IO.print("ok " ++ label)
    case False{}:
      IO.die(Unit, 1, label ++ " gave " ++ got)

def step(+label: String, +want: String, +fetched: String, x: Hairpin.Client & Jwt.Jwks & Result<&1, &1, Jwt.Err, Json.Val>) ->
    IO(Hairpin.Client & Jwt.Jwks):
  (c, +s, r) = x
  +got = show(r)
  +tr = tried(s)
  do IO<Hairpin.Client & Jwt.Jwks>:
    ok(String.eq(got, want), label, got)
    ok(String.eq(tr, fetched), label ++ ": last fetch at " ++ fetched, tr)
    return (c, s)

# verify.jwks at now; want is "Done" or the Err's name, fetched the set's tried time after.
def run(+label: String, +want: String, +fetched: String, +p: Jwt.Policy, +token: String, +now: U32,
    y: Hairpin.Client & Jwt.Jwks) -> IO(Hairpin.Client & Jwt.Jwks):
  (c, s) = y
  do IO<Hairpin.Client & Jwt.Jwks>:
    x : Hairpin.Client & Jwt.Jwks & Result<&1, &1, Jwt.Err, Json.Val> <- Jwt.verify.jwks(p, c, s, token, now)
    step(label, want, fetched, x)

def sh.code(+code: U32, +prog: String, +err: String) -> IO(Unit):
  match code:
    case 0:
      IO.pure(Unit, Unit{})
    case _:
      IO.die(Unit, 1, prog ++ " exited " ++ U32.show(code) ++ ": " ++ err)

def sh.err(+code: U32, +prog: String, out: String & String) -> IO(Unit):
  (o, +err) = out
  sh.code(code, prog, err)

def sh.status(+prog: String, r: U32 & (String & String)) -> IO(Unit):
  (+code, out) = r
  sh.err(code, prog, out)

# prog must exit 0, so a failed rm or cp cannot leave the server's file as it was.
def sh(+prog: String, args: List<&1, String>) -> IO(Unit):
  do IO<Unit>:
    r : U32 & (String & String) <- IO.try(U32 & (String & String), Process.run(prog, args, "", 4096, 5000))
    sh.status(prog, r)

def ec.a() -> Jwt.Key:
  Jwt.Pem{Bytes.from_string("-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg59CCYA5n/LhMCuLm\nZwX1fT1Ual7DTtoTZp5++RlPk/2hRANCAAT23iq969ZHQ9PWKa7W5bOGGLOov5/X\nuh5HnWiB0pU68R7MarPryfE6GPKwIihjNAksKiH6J7mdPXAZCLFTfg4y\n-----END PRIVATE KEY-----\n")}

def ec.b() -> Jwt.Key:
  Jwt.Pem{Bytes.from_string("-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgl8h43WURdywaVWsJ\nSqxbF33SLmU9GpPRPFXPqdZrz+GhRANCAAQM9VuszrXlj80fSvnunfTa68R2rH51\nK8tZJQqwnImyZVkz6b/E0Yu0YQOi0aKtsqkMvxPQpvKjQAawZIlgG6hN\n-----END PRIVATE KEY-----\n")}

def claims() -> Json.Val:
  Json.Obj{[(Json.utf8("iss"), Json.Str{Json.utf8("me")}), (Json.utf8("aud"), Json.Str{Json.utf8("api")}), (Json.utf8("exp"), Json.Num{Json.utf8("2000000000")})]}

def tok.of(r: Result<&1, &1, Jwt.Err, String>) -> IO(String):
  match r:
    case Fail{e}:
      IO.die(String, 1, "sign failed: " ++ name(e))
    case Done{t}:
      IO.pure(String, t)

def tok(key: Jwt.Key, +kid: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, Jwt.Err, String> <- Jwt.sign(Jwt.ES256{}, key, Some{kid}, claims())
    tok.of(r)

def pol() -> Jwt.Policy:
  Jwt.aud(Jwt.iss(Jwt.policy(Jwt.ES256{}), "me"), "api")

def close(y: Hairpin.Client & Jwt.Jwks) -> IO(Unit):
  (c, s) = y
  Hairpin.close(c)

def go(+dir: String, +ta: String, +tb: String, +tf: String, +tz: String) -> IO(Unit):
  +keys = dir ++ "/keys.json"
  do IO<Unit>:
    sh("cp", [dir ++ "/a.json", keys])
    y1 : Hairpin.Client & Jwt.Jwks <- run("first use fetches", "Done", "1000", pol(), ta, 1000, (Hairpin.new(), Jwt.jwks("http://127.0.0.1:8751/keys.json", 30)))
    sh("rm", [keys])
    y2 : Hairpin.Client & Jwt.Jwks <- run("fresh set answers from cache", "Done", "1000", pol(), ta, 1010, y1)
    y3 : Hairpin.Client & Jwt.Jwks <- run("alg pinned before any fetch", "AlgMismatch", "1000", Jwt.policy(Jwt.RS256{}), ta, 1020, y2)
    sh("cp", [dir ++ "/b.json", keys])
    y4 : Hairpin.Client & Jwt.Jwks <- run("unknown kid inside the cooldown", "NoKey", "1000", pol(), tb, 1030, y3)
    y4b : Hairpin.Client & Jwt.Jwks <- run("known kid survives ttl during cooldown", "Done", "1000", pol(), ta, 1040, y4)
    y5 : Hairpin.Client & Jwt.Jwks <- run("rotated kid refetches", "Done", "1070", pol(), tb, 1070, y4b)
    y6 : Hairpin.Client & Jwt.Jwks <- run("kid b signed by key a", "BadSig", "1070", pol(), tf, 1080, y5)
    y7 : Hairpin.Client & Jwt.Jwks <- run("unknown kid after the cooldown", "NoKey", "1200", pol(), tz, 1200, y6)
    sh("rm", [keys])
    y8 : Hairpin.Client & Jwt.Jwks <- run("stale set, endpoint gone", "Status 404", "1600", pol(), ta, 1600, y7)
    y9 : Hairpin.Client & Jwt.Jwks <- run("failed fetch still cools down", "NoKey", "1600", pol(), ta, 1610, y8)
    close(y9)

def main() -> IO(Unit):
  do IO<Unit>:
    dir : String <- IO.try(String, IO.get_env("JWKS_DIR"))
    ta : String <- tok(ec.a(), "a")
    tb : String <- tok(ec.b(), "b")
    tf : String <- tok(ec.a(), "b")
    tz : String <- tok(ec.a(), "zzz")
    go(dir, ta, tb, tf, tz)
