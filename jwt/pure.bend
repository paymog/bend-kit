import Base
import bend-kit-json@0.7.3.1/json.bend as Json
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

# RFC 7519 JWTs as RFC 7515 compact JWS. A token is ASCII text; header and claims are JSON objects.
# Times are unix seconds as U32 (to 2106). verify pins one alg: a header alg of "none", or of any other
# alg, fails. Each key kind serves only its algs, so a PEM public key can never become an HMAC secret.

type Alg is Data:
  HS256{}
  HS384{}
  HS512{}
  RS256{}
  ES256{}

type Err is Data:
  Malformed{}
  AlgMismatch{}
  Crit{}
  KeyType{}
  WeakKey{}
  BadSig{}
  BadClaim{}
  Expired{}
  NotYet{}
  Future{}
  BadIss{}
  BadAud{}
  NoKey{}
  Crypto{code: U32, why: String}
# What verify accepts: the one alg, the issuer and audience when Some, and leeway seconds of clock skew.
type Policy is Data:
  Policy{alg: Alg, iss: Maybe<&2, String>, aud: Maybe<&2, String>, leeway: U32}

def policy(a: Alg) -> Policy:
  Policy{a, None{}, None{}, 0}

def iss(p: Policy, s: String) -> Policy:
  Policy{a, old, u, l} = p
  Policy{a, Some{s}, u, l}

def aud(p: Policy, s: String) -> Policy:
  Policy{a, i, old, l} = p
  Policy{a, i, Some{s}, l}

def leeway(p: Policy, +n: U32) -> Policy:
  Policy{a, i, u, old} = p
  Policy{a, i, u, n}

def policy.alg(p: Policy) -> Alg:
  Policy{a, i, u, l} = p
  a

def alg.name(a: Alg) -> String:
  match a:
    case HS256{}:
      "HS256"
    case HS384{}:
      "HS384"
    case HS512{}:
      "HS512"
    case RS256{}:
      "RS256"
    case ES256{}:
      "ES256"

# ---- base64url (RFC 4648 §5), unpadded, as RFC 7515 §2 requires

def b64u.push(+c: U32, acc: String) -> String:
  match c:
    case 61:
      acc
    case 43:
      SCon{'-', acc}
    case 47:
      SCon{'_', acc}
    case _:
      SCon{Chr{c}, acc}

def b64u.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      b64u.go(t, b64u.push(c, acc))

def b64u(b: Bytes.Bytes) -> String:
  b64u.go(Bytes.to_base64(b), SNil{})

# The standard alphabet's char for c. '+', '/', '=' and NUL become NUL, which no decoder accepts.
def unb64u.c(+c: U32) -> U32:
  match c:
    case 45:
      43
    case 95:
      47
    case 43:
      0
    case 47:
      0
    case 61:
      0
    case _:
      c

# Padding for n mod 4 chars; 1 is never a whole group, so it gets a NUL.
def unb64u.pad(+r: U32, acc: String) -> String:
  match r:
    case 2:
      SCon{'=', SCon{'=', acc}}
    case 3:
      SCon{'=', acc}
    case 1:
      SCon{Chr{0}, acc}
    case _:
      acc

def unb64u.go(s: String, acc: String, +n: U32) -> String:
  match s:
    case SNil{}:
      String.reverse(unb64u.pad((n .&. 3 : U32), acc))
    case SCon{Chr{+c}, t}:
      unb64u.go(t, SCon{Chr{unb64u.c(c)}, acc}, (n + 1 : U32))

def unb64u.same(+s: String, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  (b, c) = r
  Bool.pick(Maybe<&1, Bytes.Bytes>, String.eq(b64u(c), s), Some{b}, None{})

def unb64u.canon(+s: String, m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      unb64u.same(s, Bytes.slice(b, 0, 4294967295))

# Strict: only the URL-safe alphabet, no '=', and only the canonical text of its octets, so pad bits are 0.
def unb64u(+s: String) -> Maybe<&1, Bytes.Bytes>:
  unb64u.canon(s, Bytes.from_base64(unb64u.go(s, SNil{}, 0)))

# ---- JSON members as copyable facts

# A NumericDate (RFC 7519 §2) rounded up to whole seconds and capped at the U32 top, or None when it is
# negative or has an exponent. Up is exact against a whole now: now >= t iff now >= ceil(t).
type Lit is Data:
  LStr{s: String}
  LNum{t: Maybe<&2, U32>}
  LStrs{xs: Maybe<&2, List<&2, String>>}
  LOther{}

# One member: its name as octets, and what the checks need of its value.
type Field is Data:
  Field{name: String, val: Lit}

def secs.digit(+acc: U32, +d: U32) -> U32:
  Bool.pick(U32, Bool.or(U32.is_lt(429496729, acc), Bool.and(U32.is_eq(acc, 429496729), U32.is_lt(5, d))), 4294967295, (acc * 10 + d : U32))

def secs.up(+acc: U32, frac: Bool) -> U32:
  Bool.pick(U32, Bool.and(frac, U32.is_lt(acc, 4294967295)), (acc + 1 : U32), acc)

# The JSON parser has checked the grammar, so only digits and one '.' need telling apart.
def secs.go(s: String, +acc: U32, +frac: Bool, +point: Bool, +ok: Bool) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      Bool.pick(Maybe<&2, U32>, ok, Some{secs.up(acc, frac)}, None{})
    case SCon{Chr{+c}, t}:
      +d = Bool.and(U32.is_le(48, c), U32.is_le(c, 57))
      +dot = U32.is_eq(c, 46)
      secs.go(t, Bool.pick(U32, Bool.or(point, Bool.not(d)), acc, secs.digit(acc, (c - 48 : U32))),
        Bool.or(frac, Bool.and(point, Bool.and(d, U32.is_ne(c, 48)))), Bool.or(point, dot),
        Bool.and(ok, Bool.or(d, Bool.and(dot, Bool.not(point)))))

def secs(s: String) -> Maybe<&2, U32>:
  secs.go(s, 0, False{}, False{}, True{})

def str.of(v: Json.Val) -> Maybe<&2, String>:
  match v:
    case Json.Str{s}:
      Some{Bytes.to_string(s)}
    case _:
      None{}

def strs.push(s: Maybe<&2, String>, acc: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match s acc:
    case Some{x} Some{l}:
      Some{Con{x, l}}
    case _ _:
      None{}

def strs(xs: List<&1, Json.Val>, acc: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      strs(t, strs.push(str.of(x), acc))

def lit(v: Json.Val) -> Lit:
  match v:
    case Json.Str{s}:
      LStr{Bytes.to_string(s)}
    case Json.Num{s}:
      LNum{secs(Bytes.to_string(s))}
    case Json.Arr{xs}:
      LStrs{strs(xs, Some{Nil{}})}
    case _:
      LOther{}

# An object's members, names as octets, last first.
def fields(kvs: List<&1, Bytes.Bytes & Json.Val>, acc: List<&2, Field>) -> List<&2, Field>:
  match kvs:
    case Nil{}:
      acc
    case (k, v) <> t:
      fields(t, Con{Field{Bytes.to_string(k), lit(v)}, acc})

def field(l: List<&2, Field>, +k: String) -> Maybe<&2, Lit>:
  match l:
    case Nil{}:
      None{}
    case Field{n, x} <> t:
      Bool.pick(Maybe<&2, Lit>, String.eq(n, k), Some{x}, field(t, k))

def has(l: List<&2, Field>, +k: String) -> Bool:
  match l:
    case Nil{}:
      False{}
    case Field{n, x} <> t:
      Bool.or(String.eq(n, k), has(t, k))

def str(m: Maybe<&2, Lit>) -> Maybe<&2, String>:
  match m:
    case Some{LStr{s}}:
      Some{s}
    case _:
      None{}

# ---- parsing

# A compact JWS: the header and claim members, the claims, the signing input, and the signature.
type Parts is Type:
  Parts{head: List<&2, Field>, facts: List<&2, Field>, claims: Json.Val, input: Bytes.Bytes, sig: Bytes.Bytes}

# RFC 7515 §5.2 allows rejecting repeated names; a second "alg" is how parsers come to disagree.
# parse.claims rejects them at every depth with Json.unique.parsed before members get here.
def parse.json(h: Maybe<&1, Json.Val>, f: Maybe<&1, Json.Val>, c: Maybe<&1, Json.Val>, input: Bytes.Bytes, sig: Bytes.Bytes) ->
    Result<&1, &1, Err, Parts>:
  match h f c:
    case Some{Json.Obj{hk}} Some{Json.Obj{fk}} Some{cv}:
      Done{Parts{fields(hk, Nil{}), fields(fk, Nil{}), cv, input, sig}}
    case _ _ _:
      Fail{Malformed{}}

def parse.claims(hb: Bytes.Bytes, r: Bytes.Bytes & Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> Result<&1, &1, Err, Parts>:
  (c1, c2) = r
  parse.json(Json.unique.parsed(Json.parse.bytes(hb)), Json.unique.parsed(Json.parse.bytes(c1)), Json.parse.bytes(c2), input, sig)

def parse.segs(h: Maybe<&1, Bytes.Bytes>, c: Maybe<&1, Bytes.Bytes>, s: Maybe<&1, Bytes.Bytes>, input: Bytes.Bytes) ->
    Result<&1, &1, Err, Parts>:
  match h c s:
    case Some{hb} Some{cb} Some{sb}:
      parse.claims(hb, Bytes.slice(cb, 0, 4294967295), input, sb)
    case _ _ _:
      Fail{Malformed{}}

def parse.split(xs: List<&2, String>) -> Result<&1, &1, Err, Parts>:
  match xs:
    case Con{+h, Con{+c, Con{+s, Nil{}}}}:
      parse.segs(unb64u(h), unb64u(c), unb64u(s), Bytes.from_string(h ++ "." ++ c))
    case _:
      Fail{Malformed{}}

# Three strict base64url segments, the first two JSON objects with no repeated names.
def parse(token: String) -> Result<&1, &1, Err, Parts>:
  parse.split(String.split(token, '.'))

# ---- checks

def fail.if(bad: Bool, +e: Err) -> Result<&1, &1, Err, Unit>:
  match bad:
    case True{}:
      Fail{e}
    case False{}:
      Done{Unit{}}

def head.alg(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, String>:
  match m:
    case Some{LStr{s}}:
      Done{s}
    case _:
      Fail{Malformed{}}

# The header's alg is exactly the pinned one, and it asks for no extension: crit (RFC 7515 §4.1.11) and
# b64 (RFC 7797) change how the token must be read, and neither is implemented.
def head.check(+a: Alg, +h: List<&2, Field>) -> Result<&1, &1, Err, Unit>:
  do Result<&1, &1, Err, Unit>:
    got : String <- head.alg(field(h, "alg"))
    u : Unit <- fail.if(Bool.not(String.eq(got, alg.name(a))), AlgMismatch{})
    fail.if(Bool.or(has(h, "crit"), has(h, "b64")), Crit{})

def when(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, Maybe<&2, U32>>:
  match m:
    case None{}:
      Done{None{}}
    case Some{LNum{Some{t}}}:
      Done{Some{t}}
    case Some{_}:
      Fail{BadClaim{}}

def text(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, Maybe<&2, String>>:
  match m:
    case None{}:
      Done{None{}}
    case Some{LStr{s}}:
      Done{Some{s}}
    case Some{_}:
      Fail{BadClaim{}}

# RFC 7519 §4.1.3: aud is one string or an array of them.
def auds(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, Maybe<&2, List<&2, String>>>:
  match m:
    case None{}:
      Done{None{}}
    case Some{LStr{s}}:
      Done{Some{[s]}}
    case Some{LStrs{Some{xs}}}:
      Done{Some{xs}}
    case Some{_}:
      Fail{BadClaim{}}

# exp (RFC 7519 §4.1.4): now must be before it; late by at least leeway fails.
def late(+now: U32, +lw: U32, m: Maybe<&2, U32>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+t}:
      Bool.and(U32.is_le(t, now), U32.is_le(lw, (now - t : U32)))

# nbf and iat: at most leeway seconds in the future.
def early(+now: U32, +lw: U32, m: Maybe<&2, U32>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+t}:
      Bool.and(U32.is_lt(now, t), U32.is_lt(lw, (t - now : U32)))

def octets(s: String) -> String:
  Bytes.to_string(Json.utf8(s))

def iss.bad(want: Maybe<&2, String>, got: Maybe<&2, String>) -> Bool:
  match want got:
    case None{} _:
      False{}
    case Some{w} Some{g}:
      Bool.not(String.eq(octets(w), g))
    case Some{w} None{}:
      True{}

def aud.has(l: List<&2, String>, +a: String) -> Bool:
  match l:
    case Nil{}:
      False{}
    case x <> t:
      Bool.or(String.eq(x, a), aud.has(t, a))

# RFC 7519 §4.1.3: a token with an aud that does not name us fails, as does one without aud when we want one.
def aud.bad(want: Maybe<&2, String>, got: Maybe<&2, List<&2, String>>) -> Bool:
  match want got:
    case None{} None{}:
      False{}
    case None{} Some{l}:
      True{}
    case Some{w} None{}:
      True{}
    case Some{w} Some{l}:
      Bool.not(aud.has(l, octets(w)))

# The registered claims of c at unix time now.
def claims.check(p: Policy, +now: U32, +c: List<&2, Field>) -> Result<&1, &1, Err, Unit>:
  Policy{a, +wi, +wa, +lw} = p
  do Result<&1, &1, Err, Unit>:
    exp : Maybe<&2, U32> <- when(field(c, "exp"))
    nbf : Maybe<&2, U32> <- when(field(c, "nbf"))
    iat : Maybe<&2, U32> <- when(field(c, "iat"))
    gi : Maybe<&2, String> <- text(field(c, "iss"))
    ga : Maybe<&2, List<&2, String>> <- auds(field(c, "aud"))
    u1 : Unit <- fail.if(late(now, lw, exp), Expired{})
    u2 : Unit <- fail.if(early(now, lw, nbf), NotYet{})
    u3 : Unit <- fail.if(early(now, lw, iat), Future{})
    u4 : Unit <- fail.if(iss.bad(wi, gi), BadIss{})
    fail.if(aud.bad(wa, ga), BadAud{})

def inspect.parts(+p: Policy, +now: U32, r: Result<&1, &1, Err, Parts>) -> Result<&1, &1, Err, Unit>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{Parts{+h, +f, v, input, sig}}:
      do Result<&1, &1, Err, Unit>:
        u : Unit <- head.check(policy.alg(p), h)
        claims.check(p, now, f)

# The header and claims of token, without its signature: the pure half of verify.
def inspect(p: Policy, token: String, +now: U32) -> Result<&1, &1, Err, Unit>:
  inspect.parts(p, now, parse(token))

def header.kid(m: Maybe<&2, String>) -> List<&1, Bytes.Bytes & Json.Val>:
  match m:
    case None{}:
      Nil{}
    case Some{k}:
      [(Json.utf8("kid"), Json.Str{Json.utf8(k)})]

# {"alg":..,"typ":"JWT"}, then "kid" when given.
def header(a: Alg, kid: Maybe<&2, String>) -> Json.Val:
  Json.Obj{Con{(Json.utf8("alg"), Json.Str{Json.utf8(alg.name(a))}), Con{(Json.utf8("typ"), Json.Str{Json.utf8("JWT")}), header.kid(kid)}}}

# header.body in base64url, body being the compact JSON claims: the text the signature covers.
def signing.input(a: Alg, kid: Maybe<&2, String>, body: Bytes.Bytes) -> String:
  b64u(Json.encode.bytes(header(a, kid))) ++ "." ++ b64u(body)

def sign.done(+input: String, s: Result<&1, &1, Err, Bytes.Bytes>) -> Result<&1, &1, Err, String>:
  match s:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      Done{input ++ "." ++ b64u(b)}

# verify accepts only an object with no repeated names, so sign makes no other kind.
def sign.obj(m: Maybe<&1, Json.Val>) -> Bool:
  match m:
    case Some{Json.Obj{kvs}}:
      True{}
    case _:
      False{}

# ---- JWKS (RFC 7517)

# A usable public key from a set: its kid, RSA or EC P-256, its alg ("" when the set gives none), and its
# two base64url parts (n and e, or x and y).
type Jwk is Data:
  Jwk{kid: String, rsa: Bool, alg: String, a: String, b: String}

def jwk.two(+rsa: Bool, +kid: String, +alg: String, a: Maybe<&2, String>, b: Maybe<&2, String>) -> Maybe<&2, Jwk>:
  match a b:
    case Some{x} Some{y}:
      Some{Jwk{kid, rsa, alg, x, y}}
    case _ _:
      None{}

# An alg member that is not a string can match no pinned alg.
def jwk.alg(m: Maybe<&2, Lit>) -> String:
  match m:
    case None{}:
      ""
    case Some{LStr{s}}:
      s
    case Some{_}:
      "?"

def jwk.use(m: Maybe<&2, Lit>) -> Maybe<&2, Unit>:
  match m:
    case None{}:
      Some{Unit{}}
    case Some{LStr{s}}:
      Bool.pick(Maybe<&2, Unit>, String.eq(s, "sig"), Some{Unit{}}, None{})
    case Some{_}:
      None{}

def jwk.kty(+kty: String, +kid: String, +f: List<&2, Field>) -> Maybe<&2, Jwk>:
  +alg = jwk.alg(field(f, "alg"))
  +ec = Bool.and(String.eq(kty, "EC"), String.eq(Maybe.default(&2, String, str(field(f, "crv")), ""), "P-256"))
  Bool.pick(Maybe<&2, Jwk>, String.eq(kty, "RSA"), jwk.two(True{}, kid, alg, str(field(f, "n")), str(field(f, "e"))),
    Bool.pick(Maybe<&2, Jwk>, ec, jwk.two(False{}, kid, alg, str(field(f, "x")), str(field(f, "y"))), None{}))

def jwk.fields(+f: List<&2, Field>) -> Maybe<&2, Jwk>:
  do Maybe<&2, Jwk>:
    kty : String <- str(field(f, "kty"))
    kid : String <- str(field(f, "kid"))
    s : Unit <- jwk.use(field(f, "use"))
    jwk.kty(kty, kid, f)

def jwk.obj(m: Maybe<&1, Json.Val>) -> Maybe<&2, Jwk>:
  match m:
    case Some{Json.Obj{kvs}}:
      jwk.fields(fields(kvs, Nil{}))
    case _:
      None{}

# A key whose members repeat a name, at any depth, is skipped.
def jwk.of(v: Json.Val) -> Maybe<&2, Jwk>:
  jwk.obj(Json.unique.parsed(Some{v}))

def jwk.push(m: Maybe<&2, Jwk>, acc: List<&2, Jwk>) -> List<&2, Jwk>:
  match m:
    case None{}:
      acc
    case Some{k}:
      Con{k, acc}

def jwks.go(xs: List<&1, Json.Val>, acc: List<&2, Jwk>) -> List<&2, Jwk>:
  match xs:
    case Nil{}:
      List.reverse(&2, Jwk, acc)
    case x <> t:
      jwks.go(t, jwk.push(jwk.of(x), acc))

def jwks.arr(m: Maybe<&1, Json.Val>) -> Maybe<&2, List<&2, Jwk>>:
  match m:
    case Some{Json.Arr{xs}}:
      Some{jwks.go(xs, Nil{})}
    case _:
      None{}

def jwks.doc(m: Maybe<&1, Json.Val>) -> Maybe<&2, List<&2, Jwk>>:
  match m:
    case Some{v}:
      jwks.arr(Json.get(v, "keys"))
    case None{}:
      None{}

# The signing keys of a JWK Set document; members it cannot use (enc keys, other curves, oct) are skipped.
# None when the document is not {"keys": [...]}.
def jwks.parse(b: Bytes.Bytes) -> Maybe<&2, List<&2, Jwk>>:
  jwks.doc(Json.parse.bytes(b))

def fam(a: Alg) -> U32:
  match a:
    case RS256{}:
      1
    case ES256{}:
      2
    case _:
      0

def jwk.fits(k: Jwk, +kid: String, +a: Alg) -> Bool:
  Jwk{k2, +rsa, +ka, x, y} = k
  Bool.and(Bool.and(String.eq(k2, kid), U32.is_eq(fam(a), Bool.pick(U32, rsa, 1, 2))),
    Bool.or(String.eq(ka, ""), String.eq(ka, alg.name(a))))

# The first key named kid that can check alg a. RFC 7515 §4.1.4 leaves kid matching to exact comparison.
def jwk.pick(ks: List<&2, Jwk>, +kid: String, +a: Alg) -> Maybe<&2, Jwk>:
  match ks:
    case Nil{}:
      None{}
    case Con{+k, t}:
      Bool.pick(Maybe<&2, Jwk>, jwk.fits(k, kid, a), Some{k}, jwk.pick(t, kid, a))

