import Base
import ./oauth2.bend as O
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
import 0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend as Url
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# A local authorization server on 127.0.0.1:47851, then every flow against it through Hairpin.

def ok(b: Bool, +name: String) -> IO(Unit):
  match b:
    case True{}:
      IO.print("ok   " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def show(e: O.Err) -> String:
  match e:
    case O.ErrNet{x}:
      "net"
    case O.ErrOAuth{+s, c, w}:
      "oauth " ++ U32.show(s) ++ " " ++ c ++ ": " ++ w
    case O.ErrReply{+s, b}:
      "reply " ++ U32.show(s) ++ " " ++ b
    case O.ErrState{}:
      "state"
    case O.ErrCrypto{+c, w}:
      "crypto " ++ U32.show(c) ++ " " ++ w
    case O.ErrExpired{}:
      "expired"

def BASE() -> String:
  "http://127.0.0.1:47851"

def REDIRECT() -> String:
  "http://127.0.0.1:47851/cb"

# ---- the server. Each reply closes its connection, so each request is one accept.

def res(+status: U32, h: Map<&2, List<&2, String>>, body: String) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{status, Http.set(h, "connection", "close"), Bytes.from_string(body)})

def json(+status: U32, body: String) -> IO(Http.Res):
  res(status, Http.set(Http.empty(), "content-type", "application/json"), body)

def oops(+status: U32, +code: String) -> IO(Http.Res):
  json(status, "{\"error\":\"" ++ code ++ "\",\"error_description\":\"" ++ code ++ " from the test server\"}")

def query(m: Maybe<&2, Url.Url>) -> Map<&2, String>:
  match m:
    case None{}:
      Map.new(&2, String)
    case Some{Url.Url{p, q}}:
      q

def form(b: Bytes.Bytes) -> Map<&2, String>:
  query(Url.parse("/?" ++ Bytes.to_string(b)))

def conf.auth(+auth: String) -> Bool:
  String.eq(auth, O.basic("app", "s3cret"))

# Basic for the confidential client, or client_id alone for the public one.
def client.auth(+auth: String, +f: Map<&2, String>) -> Bool:
  Bool.or(conf.auth(auth), Bool.and(String.is_empty(auth), String.eq(O.param(f, "client_id"), "app")))

def s.cc(+auth: String, +f: Map<&2, String>) -> IO(Http.Res):
  Bool.pick(IO(Http.Res), conf.auth(auth),
    json(200, "{\"access_token\":\"cc-1\",\"token_type\":\"Bearer\",\"expires_in\":3600,\"scope\":\"" ++ O.param(f, "scope") ++ "\"}"),
    oops(401, "invalid_client"))

# RFC 7636 §4.6: the server hashes code_verifier and compares it with the challenge. This server's code is the challenge.
def s.code.done(c: Result<&1, &1, O.Err, String>, good: Bool, +code: String) -> IO(Http.Res):
  match c:
    case Fail{e}:
      oops(500, "server_error")
    case Done{+want}:
      Bool.pick(IO(Http.Res), Bool.and(good, String.eq(want, code)),
        json(200, "{\"access_token\":\"ac-1\",\"token_type\":\"Bearer\",\"refresh_token\":\"rt-1\",\"expires_in\":0}"),
        oops(400, "invalid_grant"))

def s.code(+auth: String, +f: Map<&2, String>) -> IO(Http.Res):
  do IO<Http.Res>:
    c : Result<&1, &1, O.Err, String> <- O.challenge(O.param(f, "code_verifier"))
    s.code.done(c, Bool.and(client.auth(auth, f), String.eq(O.param(f, "redirect_uri"), REDIRECT())), O.param(f, "code"))

# No refresh_token in the reply, so the client keeps rt-1.
def s.refresh(+auth: String, +f: Map<&2, String>) -> IO(Http.Res):
  Bool.pick(IO(Http.Res), Bool.and(client.auth(auth, f), String.eq(O.param(f, "refresh_token"), "rt-1")),
    json(200, "{\"access_token\":\"ac-2\",\"token_type\":\"Bearer\",\"expires_in\":\"3600\"}"),
    oops(400, "invalid_grant"))

def s.token(+auth: String, +f: Map<&2, String>) -> IO(Http.Res):
  +g = O.param(f, "grant_type")
  Bool.pick(IO(Http.Res), String.eq(g, "client_credentials"), s.cc(auth, f),
    Bool.pick(IO(Http.Res), String.eq(g, "authorization_code"), s.code(auth, f),
      Bool.pick(IO(Http.Res), String.eq(g, "refresh_token"), s.refresh(auth, f), oops(400, "unsupported_grant_type"))))

# §4.1.2: back to redirect_uri with a code, here the challenge itself, and the state.
def s.authorize(+q: Map<&2, String>) -> IO(Http.Res):
  +good = Bool.and(Bool.and(String.eq(O.param(q, "response_type"), "code"), String.eq(O.param(q, "client_id"), "app")),
    Bool.and(String.eq(O.param(q, "code_challenge_method"), "S256"), String.eq(O.param(q, "redirect_uri"), REDIRECT())))
  +to = Bool.pick(String, good, "?code=" ++ O.param(q, "code_challenge"), "?error=invalid_request") ++ "&state=" ++ O.param(q, "state")
  res(302, Http.set(Http.empty(), "location", REDIRECT() ++ to), "")

def s.route(m: Maybe<&2, Url.Url>, +auth: String, body: Bytes.Bytes) -> IO(Http.Res):
  match m:
    case None{}:
      oops(400, "invalid_request")
    case Some{Url.Url{+p, +q}}:
      Bool.pick(IO(Http.Res), String.eq(p, "/token"), s.token(auth, form(body)),
        Bool.pick(IO(Http.Res), String.eq(p, "/authorize"), s.authorize(q),
          res(200, Http.empty(), auth)))

# /api answers with the Authorization header it got.
def s(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, +headers, body} = req
  s.route(Url.parse(path), Http.header(headers, "authorization"), body)

def serve(n: Nat, l: Listener) -> IO(Unit):
  match n:
    case 0n:
      Listener.close(l)
    case 1n+k:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l1 : Listener <- Http.conn(~s, 1048576n, a)
        serve(k, l1)

# ---- the client

def conf() -> O.Config:
  O.Config{BASE() ++ "/token", "app", "s3cret"}

def public() -> O.Config:
  O.Config{BASE() ++ "/token", "app", ""}

def tok(+what: String, x: Hairpin.Client & Result<&1, &1, O.Err, O.Token>) -> IO(Hairpin.Client & O.Token):
  (c, r) = x
  match r:
    case Fail{e}:
      IO.die(Hairpin.Client & O.Token, 1, "FAIL " ++ what ++ ": " ++ show(e))
    case Done{t}:
      IO.pure(Hairpin.Client & O.Token, (c, t))

def str(+what: String, r: Result<&1, &1, O.Err, String>) -> IO(String):
  match r:
    case Fail{e}:
      IO.die(String, 1, "FAIL " ++ what ++ ": " ++ show(e))
    case Done{s}:
      IO.pure(String, s)

def expires(e: Maybe<&2, Time.Instant>) -> Bool:
  match e:
    case None{}:
      False{}
    case Some{t}:
      True{}

def want(+name: String, +access: String, +refresh: String, +scope: String, y: Hairpin.Client & O.Token) -> IO(Hairpin.Client & O.Token):
  (c, +t) = y
  O.Token{+a, k, +r, +s, e} = t
  do IO<Hairpin.Client & O.Token>:
    ok(Bool.and(Bool.and(String.eq(a, access), String.eq(r, refresh)), Bool.and(String.eq(s, scope), expires(e))),
      name ++ " (" ++ a ++ " refresh " ++ r ++ " scope " ++ s ++ ")")
    return (c, t)

def res.body(+name: String, +status: U32, +body: String, x: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) -> IO(Hairpin.Client & String):
  (c, r) = x
  match r:
    case Fail{e}:
      IO.die(Hairpin.Client & String, 1, "FAIL " ++ name ++ ": request failed")
    case Done{Http.Res{+s, +h, b}}:
      +seen = Bytes.to_string(b)
      do IO<Hairpin.Client & String>:
        ok(Bool.and(U32.is_eq(s, status), String.eq(seen, body)), name ++ " (" ++ U32.show(s) ++ " " ++ seen ++ ")")
        return (c, Http.header(h, "location"))

def invalid_grant(x: Hairpin.Client & Result<&1, &1, O.Err, O.Token>) -> IO(Hairpin.Client):
  (c, r) = x
  match r:
    case Fail{O.ErrOAuth{+s, +code, w}}:
      do IO<Hairpin.Client>:
        ok(Bool.and(U32.is_eq(s, 400), String.eq(code, "invalid_grant")), "wrong code_verifier refused: " ++ code)
        return c
    case Fail{e}:
      IO.die(Hairpin.Client, 1, "FAIL wrong verifier: " ++ show(e))
    case Done{t}:
      IO.die(Hairpin.Client, 1, "FAIL wrong verifier got a token")

def cc.fresh(y: Hairpin.Client & O.Token) -> IO(Hairpin.Client & O.Token):
  (c, t) = y
  do IO<Hairpin.Client & O.Token>:
    x : Hairpin.Client & Result<&1, &1, O.Err, O.Token> <- O.fresh.cc(c, conf(), "read", t, 30)
    y2 : Hairpin.Client & O.Token <- tok("fresh.cc", x)
    want("fresh.cc keeps a live token, no request", "cc-1", "", "read", y2)

def api.done(x: Hairpin.Client & String) -> Hairpin.Client:
  (c, loc) = x
  c

def api(y: Hairpin.Client & O.Token) -> IO(Hairpin.Client):
  (c, t) = y
  do IO<Hairpin.Client>:
    x : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- O.request(c, t, "GET", BASE() ++ "/api", Http.empty(), Bytes.new(0))
    z : Hairpin.Client & String <- res.body("request sends Authorization: Bearer", 200, "Bearer cc-1", x)
    return api.done(z)

def callback.ok(c: Hairpin.Client, +code: String) -> IO(Hairpin.Client & String):
  do IO<Hairpin.Client & String>:
    ok(String.eq(code, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"), "callback code checked against state")
    return (Hairpin.redirect(c, Http.ModeFollow{}), code)

def callback(+st: String, x: Hairpin.Client & String) -> IO(Hairpin.Client & String):
  (c, loc) = x
  do IO<Hairpin.Client & String>:
    code : String <- str("callback", O.callback(loc, st))
    callback.ok(c, code)

def verifier.ok(+v: String) -> IO(Unit):
  ok(Nat.is_eq(String.length(v), 43n), "verifier is 43 base64url chars: " ++ v)

# The RFC 7636 verifier, so the server's code is the Appendix B challenge.
def authz(+st: String, c: Hairpin.Client) -> IO(Hairpin.Client & String):
  do IO<Hairpin.Client & String>:
    ch : Result<&1, &1, O.Err, String> <- O.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    cc : String <- str("challenge", ch)
    x : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <-
      Hairpin.get(Hairpin.redirect(c, Http.ModeManual{}), O.authorize.url(public(), BASE() ++ "/authorize", REDIRECT(), "openid", st, cc))
    z : Hairpin.Client & String <- res.body("authorize redirects to redirect_uri", 302, "", x)
    callback(st, z)

def exchange(y: Hairpin.Client & String) -> IO(Hairpin.Client & O.Token):
  (c, +code) = y
  do IO<Hairpin.Client & O.Token>:
    x : Hairpin.Client & Result<&1, &1, O.Err, O.Token> <- O.code(c, public(), code, REDIRECT(), "wrong-verifier-wrong-verifier-wrong-verifier")
    c1 : Hairpin.Client <- invalid_grant(x)
    x2 : Hairpin.Client & Result<&1, &1, O.Err, O.Token> <- O.code(c1, public(), code, REDIRECT(), "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    y2 : Hairpin.Client & O.Token <- tok("code", x2)
    want("authorization code with PKCE S256", "ac-1", "rt-1", "", y2)

# ac-1 has expires_in 0, so it is due and fresh refreshes it.
def renew(+name: String, +access: String, y: Hairpin.Client & O.Token) -> IO(Hairpin.Client & O.Token):
  (c, t) = y
  do IO<Hairpin.Client & O.Token>:
    x : Hairpin.Client & Result<&1, &1, O.Err, O.Token> <- O.fresh(c, public(), t, 30)
    y2 : Hairpin.Client & O.Token <- tok(name, x)
    want(name, access, "rt-1", "", y2)

def close(y: Hairpin.Client & O.Token) -> IO(Unit):
  (c, t) = y
  Hairpin.close(c)

def main() -> IO(Unit):
  do IO<Unit>:
    rv : Result<&1, &1, O.Err, String> <- O.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    v0 : String <- str("RFC 7636 challenge", rv)
    ok(String.eq(v0, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"), "RFC 7636 Appendix B S256 challenge through SHA-256")
    rs : Result<&1, &1, O.Err, String> <- O.verifier()
    v1 : String <- str("verifier", rs)
    verifier.ok(v1)
    rst : Result<&1, &1, O.Err, String> <- O.state()
    st : String <- str("state", rst)
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47851))
    IO.spawn(Unit, serve(6n, l))
    x1 : Hairpin.Client & Result<&1, &1, O.Err, O.Token> <- O.client_credentials(Hairpin.new(), conf(), "read")
    y1 : Hairpin.Client & O.Token <- tok("client credentials", x1)
    z1 : Hairpin.Client & O.Token <- want("client credentials with Basic auth", "cc-1", "", "read", y1)
    z2 : Hairpin.Client & O.Token <- cc.fresh(z1)
    c3 : Hairpin.Client <- api(z2)
    y4 : Hairpin.Client & String <- authz(st, c3)
    z5 : Hairpin.Client & O.Token <- exchange(y4)
    z6 : Hairpin.Client & O.Token <- renew("fresh refreshes an expiring token, keeps rt-1", "ac-2", z5)
    z7 : Hairpin.Client & O.Token <- renew("fresh keeps a live token, no request", "ac-2", z6)
    close(z7)
