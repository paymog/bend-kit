# Pure OAuth 2.0 forms, token responses, authorization URLs, and callback state checks.
import Base
import bend-kit-time@0.3.0.3/pure.bend as Time
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-json@0.7.3.0/json.bend as Json
import bend-kit-encoding@0.5.0.1/encoding.bend as Enc
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

type Config is Data:
  Config{token: String, id: String, secret: String}

type Token is Data:
  Token{access: String, kind: String, refresh: String, scope: String, expires: Maybe<&2, Time.Instant>}

type Err is Data:
  ErrOAuth{status: U32, code: String, why: String}
  ErrReply{status: U32, body: String}
  ErrState{}

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

def b64url(b: Bytes.Bytes) -> String:
  b64url.go(Bytes.to_base64(b))

def utf8(+s: String) -> String:
  Bytes.to_string(Enc.utf8.encode(s))

def field(m: Map<&2, String>, k: String, +v: String) -> Map<&2, String>:
  Map.set(&2, String, m, k, utf8(v))

def scoped(+scope: String, +m: Map<&2, String>) -> Map<&2, String>:
  Bool.pick(Map<&2, String>, String.is_empty(scope), m, field(m, "scope", scope))

def form(+k: String, +v: String) -> Map<&2, String>:
  field(Map.new(&2, String), k, v)

def basic(+id: String, +secret: String) -> String:
  "Basic " ++ Bytes.to_base64(Bytes.from_string(Url.pct.encode_q(utf8(id)) ++ ":" ++ Url.pct.encode_q(utf8(secret))))

def auth.body(+id: String, +secret: String, +m: Map<&2, String>) -> Map<&2, String>:
  Bool.pick(Map<&2, String>, String.is_empty(secret), field(m, "client_id", id), m)

def body(+id: String, +secret: String, m: Map<&2, String>) -> String:
  Url.form(auth.body(id, secret, m))

type Got is Data:
  Got{access: String, kind: String, refresh: String, scope: String, expires: String, error: String, desc: String}

def got.put(g: Got, +k: String, +v: String) -> Got:
  Got{a, t, r, s, e, er, d} = g
  Got{Bool.pick(String, String.eq(k, "access_token"), v, a), Bool.pick(String, String.eq(k, "token_type"), v, t),
    Bool.pick(String, String.eq(k, "refresh_token"), v, r), Bool.pick(String, String.eq(k, "scope"), v, s),
    Bool.pick(String, String.eq(k, "expires_in"), v, e), Bool.pick(String, String.eq(k, "error"), v, er),
    Bool.pick(String, String.eq(k, "error_description"), v, d)}

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

def good(+status: U32, g: Got) -> Bool:
  Got{a, t, r, s, e, er, d} = g
  Bool.and(Bool.and(U32.is_le(200, status), U32.is_lt(status, 300)), Bool.and(Bool.not(String.is_empty(a)), String.eq(String.to_lower(t), "bearer")))

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

def parse(+status: U32, +old: String, now: Time.Instant, b: Bytes.Bytes) -> Result<&1, &1, Err, Token>:
  parse.copy(status, old, now, Bytes.slice(b, 0, 4294967295))

def expiring.at(e: Maybe<&2, Time.Instant>, now: Time.Instant, +skew: U32) -> Bool:
  match e:
    case None{}:
      False{}
    case Some{at}:
      Bool.not(Cmp.is_lt(Time.Instant.cmp(Time.Instant.add(now, Time.Duration.of_secs(Time.i64(skew))), at)))

def expiring(tok: Token, now: Time.Instant, +skew: U32) -> Bool:
  Token{a, k, r, s, e} = tok
  expiring.at(e, now, skew)

def qmark(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.or(U32.is_eq(c, 63), qmark(t))

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

def callback(url: String, +state: String) -> Result<&1, &1, Err, String>:
  callback.q(state, Url.take_to(url, 63))
