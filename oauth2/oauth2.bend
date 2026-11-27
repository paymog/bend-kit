# OAuth 2.0 client credentials, refresh, and authorization code with PKCE over Hairpin. Source: https://github.com/paymog/bend-kit/tree/main/oauth2
import Base
import bend-kit-crypto@0.2.2.2/crypto.bend as Crypto
import bend-kit-hairpin@0.19.0.2/hairpin.bend as Hairpin
import bend-kit-http@0.45.0.2/http.bend as Http
import bend-kit-http@0.45.0.2/pure.bend as HttpPure
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-json@0.7.3.2/json.bend as Json
import bend-kit-encoding@0.5.0.3/encoding.bend as Enc
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./pure.bend as Pure

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
  ErrNet{e: Hairpin.Err}
  ErrOAuth{status: U32, code: String, why: String}
  ErrReply{status: U32, body: String}
  ErrState{}
  ErrCrypto{code: U32, why: String}
  ErrExpired{}

type Got is Data:
  Got{access: String, kind: String, refresh: String, scope: String, expires: String, error: String, desc: String}

def config.to.pure(v: Config) -> Pure.Config:
  Config{t, i, s} = v
  Pure.Config{t, i, s}

def token.to.pure(v: Token) -> Pure.Token:
  Token{a, k, r, s, e} = v
  Pure.Token{a, k, r, s, e}

def token.from.pure(v: Pure.Token) -> Token:
  Pure.Token{a, k, r, s, e} = v
  Token{a, k, r, s, e}

def err.from.pure(v: Pure.Err) -> Err:
  match v:
    case Pure.ErrOAuth{s, c, w}:
      ErrOAuth{s, c, w}
    case Pure.ErrReply{s, b}:
      ErrReply{s, b}
    case Pure.ErrState{}:
      ErrState{}

def result.token.from.pure(v: Result<&1, &1, Pure.Err, Pure.Token>) -> Result<&1, &1, Err, Token>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{t}:
      Done{token.from.pure(t)}

def result.string.from.pure(v: Result<&1, &1, Pure.Err, String>) -> Result<&1, &1, Err, String>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{t}:
      Done{t}

def got.to.pure(v: Got) -> Pure.Got:
  Got{a, k, r, s, e, er, d} = v
  Pure.Got{a, k, r, s, e, er, d}

def maybe.got.to.pure(v: Maybe<&2, Got>) -> Maybe<&2, Pure.Got>:
  match v:
    case None{}:
      None{}
    case Some{x}:
      Some{got.to.pure(x)}

def got.from.pure(v: Pure.Got) -> Got:
  Pure.Got{a, k, r, s, e, er, d} = v
  Got{a, k, r, s, e, er, d}

def maybe.got.from.pure(v: Maybe<&2, Pure.Got>) -> Maybe<&2, Got>:
  match v:
    case None{}:
      None{}
    case Some{x}:
      Some{got.from.pure(x)}


# ---- base64url

def b64url.ch(+c: U32, t: String) -> String:
  Pure.b64url.ch(c, t)

def b64url.go(s: String) -> String:
  Pure.b64url.go(s)

# Base64url without padding (RFC 4648 §5, RFC 7636 Appendix A).
def b64url(b: Bytes.Bytes) -> String:
  Pure.b64url(b)

# ---- forms

def utf8(+s: String) -> String:
  Pure.utf8(s)

def field(m: Map<&2, String>, k: String, +v: String) -> Map<&2, String>:
  Pure.field(m, k, v)

def scoped(+scope: String, +m: Map<&2, String>) -> Map<&2, String>:
  Pure.scoped(scope, m)

def form(+k: String, +v: String) -> Map<&2, String>:
  Pure.form(k, v)

# RFC 6749 §2.3.1: id and secret are form-encoded before base64.
def basic(+id: String, +secret: String) -> String:
  Pure.basic(id, secret)

def auth.headers(+id: String, +secret: String) -> Map<&2, List<&2, String>>:
  +h = HttpPure.set(HttpPure.set(HttpPure.empty(), "content-type", "application/x-www-form-urlencoded"), "accept", "application/json")
  Bool.pick(Map<&2, List<&2, String>>, String.is_empty(secret), h, HttpPure.set(h, "authorization", basic(id, secret)))

def auth.body(+id: String, +secret: String, +m: Map<&2, String>) -> Map<&2, String>:
  Pure.auth.body(id, secret, m)

# The form body of a token request from cfg's client.
def body(+id: String, +secret: String, m: Map<&2, String>) -> String:
  Pure.body(id, secret, m)

# ---- token responses (RFC 6749 §5)


def got.put(g: Got, +k: String, +v: String) -> Got:
  got.from.pure(Pure.got.put(got.to.pure(g), k, v))

# A string's text, or a number's, as some servers send expires_in as "3600".
def got.text(v: Json.Val) -> String:
  Pure.got.text(v)

def got.go(kvs: List<&1, Bytes.Bytes & Json.Val>, g: Got) -> Got:
  got.from.pure(Pure.got.go(kvs, got.to.pure(g)))

def got.obj(v: Json.Val) -> Maybe<&2, Got>:
  maybe.got.from.pure(Pure.got.obj(v))

def got(m: Maybe<&1, Json.Val>) -> Maybe<&2, Got>:
  maybe.got.from.pure(Pure.got(m))

def expiry(now: Time.Instant, m: Maybe<&2, U32>) -> Maybe<&2, Time.Instant>:
  Pure.expiry(now, m)

# A 2xx with an access token of type Bearer (RFC 6750 §4, case-insensitive), the only kind request sends.
def good(+status: U32, g: Got) -> Bool:
  Pure.good(status, got.to.pure(g))

# §6: a refresh reply without refresh_token keeps the old one. b: the body, decoded only for an error.
def token.pick(ok: Bool, +status: U32, +old: String, now: Time.Instant, b: Bytes.Bytes, g: Got) -> Result<&1, &1, Err, Token>:
  result.token.from.pure(Pure.token.pick(ok, status, old, now, b, got.to.pure(g)))

def token.of(+status: U32, +old: String, now: Time.Instant, b: Bytes.Bytes, m: Maybe<&2, Got>) -> Result<&1, &1, Err, Token>:
  result.token.from.pure(Pure.token.of(status, old, now, b, maybe.got.to.pure(m)))

def parse.copy(+status: U32, +old: String, now: Time.Instant, r: Bytes.Bytes & Bytes.Bytes) -> Result<&1, &1, Err, Token>:
  result.token.from.pure(Pure.parse.copy(status, old, now, r))

# A token endpoint's reply at status, requested at now. old: the refresh token to keep when none comes back.
def parse(+status: U32, +old: String, now: Time.Instant, b: Bytes.Bytes) -> Result<&1, &1, Err, Token>:
  result.token.from.pure(Pure.parse(status, old, now, b))

def reply(+old: String, now: Time.Instant, r: Result<&1, &1, Hairpin.Err, HttpPure.Res>) -> Result<&1, &1, Err, Token>:
  match r:
    case Fail{e}:
      Fail{ErrNet{e}}
    case Done{res}:
      HttpPure.Res{+status, h, b} = res
      parse(status, old, now, b)

def grant.done(+old: String, now: Time.Instant, x: Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res>) ->
    Hairpin.Client & Result<&1, &1, Err, Token>:
  (h, r) = x
  (h, reply(old, now, r))

# POST m to the token endpoint. Hairpin sends a POST once.
def grant(h: Hairpin.Client, cfg: Config, m: Map<&2, String>, +old: String) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  Config{url, +id, +secret} = cfg
  do IO<Hairpin.Client & Result<&1, &1, Err, Token>>:
    now : Time.Instant <- Http.clock.now()
    x : Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res> <-
      Hairpin.request(h, "POST", url, auth.headers(id, secret), HttpPure.from_string(body(id, secret, m)))
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
  Pure.expiring.at(e, now, skew)

# Does tok lapse within skew seconds of now? A token without expires_in never does.
def expiring(tok: Token, now: Time.Instant, +skew: U32) -> Bool:
  Pure.expiring(token.to.pure(tok), now, skew)

def fresh.go(due: Bool, h: Hairpin.Client, cfg: Config, +tok: Token) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  match due:
    case True{}:
      refresh(h, cfg, tok, "")
    case False{}:
      IO.pure(Hairpin.Client & Result<&1, &1, Err, Token>, (h, Done{tok}))

# tok, or a refreshed one when it lapses within skew seconds.
def fresh(h: Hairpin.Client, cfg: Config, +tok: Token, +skew: U32) -> IO(Hairpin.Client & Result<&1, &1, Err, Token>):
  do IO<Hairpin.Client & Result<&1, &1, Err, Token>>:
    now : Time.Instant <- Http.clock.now()
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
    now : Time.Instant <- Http.clock.now()
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
  Pure.qmark(s)

# RFC 6749 §4.1.1 with RFC 7636 §4.3: the URL to send the user to. endpoint may carry its own query.
def authorize.url(cfg: Config, +endpoint: String, +redirect: String, +scope: String, +state: String, +challenge: String) -> String:
  Pure.authorize.url(config.to.pure(cfg), endpoint, redirect, scope, state, challenge)

def param.of(r: Map<&2, String> & String) -> String:
  Pure.param.of(r)

def param(+m: Map<&2, String>, k: String) -> String:
  Pure.param(m, k)

def callback.pick(+err: String, desc: String, +got: String, +code: String, +state: String) -> Result<&1, &1, Err, String>:
  result.string.from.pure(Pure.callback.pick(err, desc, got, code, state))

def callback.m(+state: String, m: Maybe<&2, Url.Url>) -> Result<&1, &1, Err, String>:
  result.string.from.pure(Pure.callback.m(state, m))

def callback.frag(+state: String, r: String & String) -> Result<&1, &1, Err, String>:
  result.string.from.pure(Pure.callback.frag(state, r))

def callback.q(+state: String, r: String & String) -> Result<&1, &1, Err, String>:
  result.string.from.pure(Pure.callback.q(state, r))

# §4.1.2: the code in the redirect to redirect_uri, once its state matches ours; the server's error if it sent one.
def callback(url: String, +state: String) -> Result<&1, &1, Err, String>:
  result.string.from.pure(Pure.callback(url, state))

# ---- bearer requests (RFC 6750 §2.1)

def bearer(tok: Token, h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  Token{a, k, r, s, e} = tok
  HttpPure.set(h, "authorization", "Bearer " ++ a)

# Hairpin.request with Authorization: Bearer <access>, over any authorization header in headers.
def request(c: Hairpin.Client, tok: Token, +method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res>):
  Hairpin.request(c, method, url, bearer(tok, headers), body)
