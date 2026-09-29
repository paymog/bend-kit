# OAuth 2.0 client credentials, refresh, and authorization code with PKCE over Hairpin. Source: https://github.com/paymog/bend-kit/tree/main/oauth2
import Base
import bend-kit-crypto@0.1.1.0/crypto.bend as Crypto
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
# By hash, as hairpin imports them: bend-kit-url@0.4.1.0, -json@0.5.0.1, -encoding@0.3.0.0, -bytes@0.3.0.0.
import 0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend as Url
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0xcfc8be7b076f41f95c8e118383892d55/encoding.bend as Enc
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# RFC 6749 and RFC 7636. Text is a String of code points; form values go out as UTF-8.
# token: the token endpoint URL. secret: "" for a public client, which sends client_id in the body;
# a confidential client authenticates with HTTP Basic (RFC 6749 §2.3.1).
type Config is Data:
  Config{token: String, id: String, secret: String}

# kind: token_type, as "Bearer". refresh: "" for none. scope: "" when the server did not say.
# expires: when the access token lapses, counted from just before the request; None without expires_in.
type Token is Data:
  Token{access: String, kind: String, refresh: String, scope: String, expires: Maybe<&2, Time.Instant>}

# ErrNet: the request did not complete. ErrOAuth: an RFC 6749 §5.2 error with its status, or a §4.1.2.1
# error in a callback, status 0. ErrReply: not a Bearer token response, with its status and text. ErrState: the
# callback's state is not ours (§10.12). ErrCrypto: the random source or SHA-256 failed. ErrExpired: the
# token lapsed and has no refresh token.
type Err is Data:
  ErrNet{e: Http.Err}
  ErrOAuth{status: U32, code: String, why: String}
  ErrReply{status: U32, body: String}
  ErrState{}
  ErrCrypto{code: U32, why: String}
  ErrExpired{}

# ---- base64url

def b64url.ch(+c: U32, t: String) -> String:
  match c:
    case 43:
      SCon{Chr{45}, t}
    case 47:
      SCon{Chr{95}, t}
    case 61:
      t
    case _:
      SCon{Chr{c}, t}

def b64url.go(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      b64url.ch(c, b64url.go(t))

# Base64url without padding (RFC 4648 §5, RFC 7636 Appendix A).
def b64url(b: Bytes.Bytes) -> String:
  b64url.go(Bytes.to_base64(b))

# ---- forms

def utf8(+s: String) -> String:
  Bytes.to_string(Enc.utf8.encode(s))

def field(m: Map<&2, String>, k: String, +v: String) -> Map<&2, String>:
  Map.set(&2, String, m, k, utf8(v))

def scoped(+scope: String, +m: Map<&2, String>) -> Map<&2, String>:
  Bool.pick(Map<&2, String>, String.is_empty(scope), m, field(m, "scope", scope))

def form(+k: String, +v: String) -> Map<&2, String>:
  field(Map.new(&2, String), k, v)

# RFC 6749 §2.3.1: id and secret are form-encoded before base64.
def basic(+id: String, +secret: String) -> String:
  "Basic " ++ Bytes.to_base64(Bytes.from_string(Url.pct.encode_q(utf8(id)) ++ ":" ++ Url.pct.encode_q(utf8(secret))))

def auth.headers(+id: String, +secret: String) -> Map<&2, List<&2, String>>:
  +h = Http.set(Http.set(Http.empty(), "content-type", "application/x-www-form-urlencoded"), "accept", "application/json")
  Bool.pick(Map<&2, List<&2, String>>, String.is_empty(secret), h, Http.set(h, "authorization", basic(id, secret)))

def auth.body(+id: String, +secret: String, +m: Map<&2, String>) -> Map<&2, String>:
  Bool.pick(Map<&2, String>, String.is_empty(secret), field(m, "client_id", id), m)

# The form body of a token request from cfg's client.
def body(+id: String, +secret: String, m: Map<&2, String>) -> String:
  Url.form(auth.body(id, secret, m))

# ---- token responses (RFC 6749 §5)

type Got is Data:
  Got{access: String, kind: String, refresh: String, scope: String, expires: String, error: String, desc: String}

def got.put(g: Got, +k: String, +v: String) -> Got:
  Got{a, t, r, s, e, er, d} = g
  Got{Bool.pick(String, String.eq(k, "access_token"), v, a), Bool.pick(String, String.eq(k, "token_type"), v, t),
    Bool.pick(String, String.eq(k, "refresh_token"), v, r), Bool.pick(String, String.eq(k, "scope"), v, s),
    Bool.pick(String, String.eq(k, "expires_in"), v, e), Bool.pick(String, String.eq(k, "error"), v, er),
    Bool.pick(String, String.eq(k, "error_description"), v, d)}

# A string's text, or a number's, as some servers send expires_in as "3600".
def got.text(v: Json.Val) -> String:
  match v:
    case Json.Str{s}:
      Enc.utf8.decode(s)
    case Json.Num{s}:
      Bytes.to_string(s)
    case other:
      ""

def got.go(kvs: List<&1, Bytes.Bytes & Json.Val>, g: Got) -> Got:
  match kvs:
    case Nil{}:
      g
    case Con{(k, v), t}:
      got.go(t, got.put(g, Bytes.to_string(k), got.text(v)))

def got.obj(v: Json.Val) -> Maybe<&2, Got>:
  match v:
    case Json.Obj{kvs}:
      Some{got.go(kvs, Got{"", "", "", "", "", "", ""})}
    case other:
      None{}

def got(m: Maybe<&1, Json.Val>) -> Maybe<&2, Got>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      got.obj(v)

def expiry(now: Time.Instant, m: Maybe<&2, U32>) -> Maybe<&2, Time.Instant>:
  match m:
    case None{}:
      None{}
    case Some{n}:
      Some{Time.Instant.add(now, Time.Duration.of_secs(Time.i64(n)))}

# A 2xx with an access token of type Bearer (RFC 6750 §4, case-insensitive), the only kind request sends.
def good(+status: U32, g: Got) -> Bool:
  Got{a, t, r, s, e, er, d} = g
  Bool.and(Bool.and(U32.is_le(200, status), U32.is_lt(status, 300)), Bool.and(Bool.not(String.is_empty(a)), String.eq(String.to_lower(t), "bearer")))

# §6: a refresh reply without refresh_token keeps the old one. b: the body, decoded only for an error.
def token.pick(ok: Bool, +status: U32, +old: String, now: Time.Instant, b: Bytes.Bytes, g: Got) -> Result<&1, &1, Err, Token>:
  match ok:
    case True{}:
      Got{a, t, +r, s, e, er, d} = g
      Done{Token{a, t, Bool.pick(String, String.is_empty(r), old, r), s, expiry(now, Json.u32.num(e))}}
    case False{}:
      Got{a, t, r, s, e, +er, d} = g
      Fail{Bool.pick(Err, String.is_empty(er), ErrReply{status, Enc.utf8.decode(b)}, ErrOAuth{status, er, d})}

def token.of(+status: U32, +old: String, now: Time.Instant, b: Bytes.Bytes, m: Maybe<&2, Got>) -> Result<&1, &1, Err, Token>:
  match m:
    case None{}:
      Fail{ErrReply{status, Enc.utf8.decode(b)}}
    case Some{+g}:
      token.pick(good(status, g), status, old, now, b, g)

def parse.copy(+status: U32, +old: String, now: Time.Instant, r: Bytes.Bytes & Bytes.Bytes) -> Result<&1, &1, Err, Token>:
  (b, c) = r
  token.of(status, old, now, b, got(Json.parse.bytes(c)))

# A token endpoint's reply at status, requested at now. old: the refresh token to keep when none comes back.
def parse(+status: U32, +old: String, now: Time.Instant, b: Bytes.Bytes) -> Result<&1, &1, Err, Token>:
  parse.copy(status, old, now, Bytes.slice(b, 0, 4294967295))

def reply(+old: String, now: Time.Instant, r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Err, Token>:
  match r:
    case Fail{e}:
      Fail{ErrNet{e}}
    case Done{res}:
      Http.Res{+status, h, b} = res
      parse(status, old, now, b)

def grant.done(+old: String, now: Time.Instant, x: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) ->
    Hairpin.Client & Result<&1, &1, Err, Token>:
  (h, r) = x
  (h, reply(old, now, r))

# POST m to the token endpoint. Hairpin sends a POST once.
def grant(h: Hairpin.Client, cfg: Config, m: Map<&2, String>, +old: String) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  Config{url, +id, +secret} = cfg
  do IO<Hairpin.Client & Result<&1, &1, Err, Token>>:
    now : Time.Instant <- Time.now()
    x : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <-
      Hairpin.request(h, "POST", url, auth.headers(id, secret), Http.from_string(body(id, secret, m)))
    return grant.done(old, now, x)

# ---- grants

# RFC 6749 §4.4. scope: "" for the server's default.
def client_credentials(h: Hairpin.Client, cfg: Config, +scope: String) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  grant(h, cfg, scoped(scope, form("grant_type", "client_credentials")), "")

# RFC 6749 §4.1.3 with RFC 7636 §4.5: the code from callback, the same redirect_uri, and the verifier.
def code(h: Hairpin.Client, cfg: Config, +code: String, +redirect: String, +verifier: String) ->
    IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  grant(h, cfg, field(field(field(form("grant_type", "authorization_code"), "code", code), "redirect_uri", redirect), "code_verifier", verifier), "")

def refresh.go(none: Bool, h: Hairpin.Client, cfg: Config, +r: String, +scope: String) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  match none:
    case True{}:
      IO.pure(Hairpin.Client & Result<&1, &1, Err, Token>, (h, Fail{ErrExpired{}}))
    case False{}:
      grant(h, cfg, scoped(scope, field(form("grant_type", "refresh_token"), "refresh_token", r)), r)

# RFC 6749 §6. scope: "" keeps the granted scope. ErrExpired when tok has no refresh token.
def refresh(h: Hairpin.Client, cfg: Config, tok: Token, +scope: String) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  Token{a, k, +r, s, e} = tok
  refresh.go(String.is_empty(r), h, cfg, r, scope)

def expiring.at(e: Maybe<&2, Time.Instant>, now: Time.Instant, +skew: U32) -> Bool:
  match e:
    case None{}:
      False{}
    case Some{at}:
      Bool.not(Cmp.is_lt(Time.Instant.cmp(Time.Instant.add(now, Time.Duration.of_secs(Time.i64(skew))), at)))

# Does tok lapse within skew seconds of now? A token without expires_in never does.
def expiring(tok: Token, now: Time.Instant, +skew: U32) -> Bool:
  Token{a, k, r, s, e} = tok
  expiring.at(e, now, skew)

def fresh.go(due: Bool, h: Hairpin.Client, cfg: Config, +tok: Token) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  match due:
    case True{}:
      refresh(h, cfg, tok, "")
    case False{}:
      IO.pure(Hairpin.Client & Result<&1, &1, Err, Token>, (h, Done{tok}))

# tok, or a refreshed one when it lapses within skew seconds.
def fresh(h: Hairpin.Client, cfg: Config, +tok: Token, +skew: U32) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  do IO<Hairpin.Client & Result<&1, &1, Err, Token>>:
    now : Time.Instant <- Time.now()
    fresh.go(expiring(tok, now, skew), h, cfg, tok)

def fresh.cc.go(due: Bool, h: Hairpin.Client, cfg: Config, +scope: String, +tok: Token) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  match due:
    case True{}:
      client_credentials(h, cfg, scope)
    case False{}:
      IO.pure(Hairpin.Client & Result<&1, &1, Err, Token>, (h, Done{tok}))

# tok, or a new client-credentials token when it lapses within skew seconds (§4.4.3: no refresh token).
def fresh.cc(h: Hairpin.Client, cfg: Config, +scope: String, +tok: Token, +skew: U32) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  do IO<Hairpin.Client & Result<&1, &1, Err, Token>>:
    now : Time.Instant <- Time.now()
    fresh.cc.go(expiring(tok, now, skew), h, cfg, scope, tok)

# ---- authorization code with PKCE (RFC 7636)

def random.of(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, Err, String>:
  match r:
    case Fail{(c, why)}:
      Fail{ErrCrypto{c, why}}
    case Done{(len, buf)}:
      Done{b64url(Bytes.Bytes{len, buf})}

# n octets from the OS secure random source, as base64url.
def random(+n: U32) -> IO(Result<&1, &1, Err, String>):
  do IO<Result<&1, &1, Err, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.random.words(n)
    return random.of(r)

# §4.1: 32 random octets, 43 unreserved chars.
def verifier() -> IO(Result<&1, &1, Err, String>):
  random(32)

# An unguessable state for the authorization request (RFC 6749 §10.12).
def state() -> IO(Result<&1, &1, Err, String>):
  random(16)

def challenge.words(b: Bytes.Bytes) -> IO(Result<&1, &1, Err, String>):
  Bytes.Bytes{+len, buf} = b
  do IO<Result<&1, &1, Err, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.sha256.words(len, buf)
    return random.of(r)

# §4.2 S256: BASE64URL(SHA256(ASCII(verifier))).
def challenge(+verifier: String) -> IO(Result<&1, &1, Err, String>):
  challenge.words(Bytes.from_string(verifier))

def qmark(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.or(U32.is_eq(c, 63), qmark(t))

# RFC 6749 §4.1.1 with RFC 7636 §4.3: the URL to send the user to. endpoint may carry its own query.
def authorize.url(cfg: Config, +endpoint: String, +redirect: String, +scope: String, +state: String, +challenge: String) -> String:
  Config{t, +id, s} = cfg
  +q = field(field(field(field(field(form("response_type", "code"), "client_id", id), "redirect_uri", redirect), "state", state),
    "code_challenge", challenge), "code_challenge_method", "S256")
  endpoint ++ Bool.pick(String, qmark(endpoint), "&", "?") ++ Url.form(scoped(scope, q))

def param.of(r: Map<&2, String> & String) -> String:
  (n, v) = r
  v

def param(+m: Map<&2, String>, k: String) -> String:
  param.of(Map.get(String, "", m, k))

def callback.pick(+err: String, desc: String, +got: String, +code: String, +state: String) -> Result<&1, &1, Err, String>:
  Bool.pick(Result<&1, &1, Err, String>, Bool.not(String.eq(got, state)), Fail{ErrState{}},
    Bool.pick(Result<&1, &1, Err, String>, Bool.not(String.is_empty(err)), Fail{ErrOAuth{0, err, desc}},
      Bool.pick(Result<&1, &1, Err, String>, String.is_empty(code), Fail{ErrReply{0, "no code"}}, Done{code})))

def callback.m(+state: String, m: Maybe<&2, Url.Url>) -> Result<&1, &1, Err, String>:
  match m:
    case None{}:
      Fail{ErrReply{0, "bad callback query"}}
    case Some{Url.Url{p, +q}}:
      callback.pick(param(q, "error"), param(q, "error_description"), param(q, "state"), param(q, "code"), state)

def callback.frag(+state: String, r: String & String) -> Result<&1, &1, Err, String>:
  (q, f) = r
  callback.m(state, Url.parse("/?" ++ q))

def callback.q(+state: String, r: String & String) -> Result<&1, &1, Err, String>:
  (p, rest) = r
  callback.frag(state, Url.take_to(rest, 35))

# §4.1.2: the code in the redirect to redirect_uri, once its state matches ours; the server's error if it sent one.
def callback(url: String, +state: String) -> Result<&1, &1, Err, String>:
  callback.q(state, Url.take_to(url, 63))

# ---- bearer requests (RFC 6750 §2.1)

def bearer(tok: Token, h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  Token{a, k, r, s, e} = tok
  Http.set(h, "authorization", "Bearer " ++ a)

# Hairpin.request with Authorization: Bearer <access>, over any authorization header in headers.
def request(c: Hairpin.Client, tok: Token, +method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>):
  Hairpin.request(c, method, url, bearer(tok, headers), body)
