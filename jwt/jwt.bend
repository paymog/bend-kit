# JSON Web Tokens: HS256/384/512, RS256, and ES256 compact JWS sign and verify, claim checks, and JWKS keys over Hairpin. Source: https://github.com/paymog/bend-kit/tree/main/jwt
import Base
import bend-kit-crypto@0.2.0.0/crypto.bend as Crypto
import bend-kit-hairpin@0.2.1.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
# By hash, as hairpin imports them: bend-kit-json@0.5.0.1, -bytes@0.3.0.0.
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# RFC 7519 JWTs as RFC 7515 compact JWS. A token is ASCII text; header and claims are JSON objects.
# Times are unix seconds as U32 (to 2106). verify pins one alg: a header alg of "none", or of any other
# alg, fails. Each key kind serves only its algs, so a PEM public key can never become an HMAC secret.

type Alg is Data:
  HS256{}
  HS384{}
  HS512{}
  RS256{}
  ES256{}

# Hmac: the shared secret, at least the digest's size (RFC 7518 §3.2).
# Pem: a PEM "PUBLIC KEY" to verify, or an unencrypted PEM private key to sign.
# Rsa, Ec: JWK public key parts as big-endian octets (RFC 7518 §6.3, §6.2 on P-256).
type Key is Type:
  Hmac{secret: Bytes.Bytes}
  Pem{pem: Bytes.Bytes}
  Rsa{n: Bytes.Bytes, e: Bytes.Bytes}
  Ec{x: Bytes.Bytes, y: Bytes.Bytes}

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
  Net{e: Hairpin.Err}
  Status{code: U32}

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

# RFC 7515 §5.2 allows rejecting repeated names; a second "alg" is how parsers come to disagree.
def dup(l: List<&2, Field>) -> Bool:
  match l:
    case Nil{}:
      False{}
    case Con{Field{+n, x}, +t}:
      Bool.or(has(t, n), dup(t))

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

def parse.objs(hf: List<&2, Field>, ff: List<&2, Field>, cv: Json.Val, input: Bytes.Bytes, sig: Bytes.Bytes) ->
    Result<&1, &1, Err, Parts>:
  +h = hf
  +f = ff
  Bool.pick(Result<&1, &1, Err, Parts>, Bool.or(dup(h), dup(f)), Fail{Malformed{}}, Done{Parts{h, f, cv, input, sig}})

def parse.json(h: Maybe<&1, Json.Val>, f: Maybe<&1, Json.Val>, c: Maybe<&1, Json.Val>, input: Bytes.Bytes, sig: Bytes.Bytes) ->
    Result<&1, &1, Err, Parts>:
  match h f c:
    case Some{Json.Obj{hk}} Some{Json.Obj{fk}} Some{cv}:
      parse.objs(fields(hk, Nil{}), fields(fk, Nil{}), cv, input, sig)
    case _ _ _:
      Fail{Malformed{}}

def parse.claims(hb: Bytes.Bytes, r: Bytes.Bytes & Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> Result<&1, &1, Err, Parts>:
  (c1, c2) = r
  parse.json(Json.parse.bytes(hb), Json.parse.bytes(c1), Json.parse.bytes(c2), input, sig)

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

# ---- signatures

def crypto.bytes(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, Err, Bytes.Bytes>:
  match r:
    case Fail{(c, w)}:
      Fail{Crypto{c, w}}
    case Done{(n, b)}:
      Done{Bytes.Bytes{n, b}}

def crypto.ok(r: Result<&1, &1, U32 & String, Bool>) -> Result<&1, &1, Err, Bool>:
  match r:
    case Fail{(c, w)}:
      Fail{Crypto{c, w}}
    case Done{b}:
      Done{b}

def mac.if(weak: Bool, +alg: String, +kn: U32, kb: Array<U32>, +dn: U32, db: Array<U32>) ->
    IO(Result<&1, &1, Err, Bytes.Bytes>):
  match weak:
    case True{}:
      IO.pure(Result<&1, &1, Err, Bytes.Bytes>, Fail{WeakKey{}})
    case False{}:
      do IO<Result<&1, &1, Err, Bytes.Bytes>>:
        r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.hmac.words(alg, kn, kb, dn, db)
        return crypto.bytes(r)

def mac(+alg: String, +min: U32, k: Bytes.Bytes, input: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bytes.Bytes>):
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+dn, db} = input
  mac.if(U32.is_lt(kn, min), alg, kn, kb, dn, db)

def mac.cmp(m: Result<&1, &1, Err, Bytes.Bytes>, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  match m:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Bool>, Fail{e})
    case Done{Bytes.Bytes{+mn, mb}}:
      Bytes.Bytes{+sn, sb} = sig
      do IO<Result<&1, &1, Err, Bool>>:
        ok : Bool <- Crypto.eq.ct.words(mn, mb, sn, sb)
        return Done{ok}

# The MAC compares in constant time.
def mac.check(+alg: String, +min: U32, k: Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  do IO<Result<&1, &1, Err, Bool>>:
    m : Result<&1, &1, Err, Bytes.Bytes> <- mac(alg, min, k, input)
    mac.cmp(m, sig)

def rsa.pem(p: Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  Bytes.Bytes{+pn, pb} = p
  Bytes.Bytes{+dn, db} = input
  Bytes.Bytes{+sn, sb} = sig
  do IO<Result<&1, &1, Err, Bool>>:
    r : Result<&1, &1, U32 & String, Bool> <- Crypto.rsa.verify.words("SHA256", pn, pb, dn, db, sn, sb)
    return crypto.ok(r)

def rsa.jwk(n: Bytes.Bytes, e: Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  Bytes.Bytes{+nn, nb} = n
  Bytes.Bytes{+en, eb} = e
  Bytes.Bytes{+dn, db} = input
  Bytes.Bytes{+sn, sb} = sig
  do IO<Result<&1, &1, Err, Bool>>:
    r : Result<&1, &1, U32 & String, Bool> <- Crypto.rsa.verify.jwk.words("SHA256", nn, nb, en, eb, dn, db, sn, sb)
    return crypto.ok(r)

def ec.pem(p: Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  Bytes.Bytes{+pn, pb} = p
  Bytes.Bytes{+dn, db} = input
  Bytes.Bytes{+sn, sb} = sig
  do IO<Result<&1, &1, Err, Bool>>:
    r : Result<&1, &1, U32 & String, Bool> <- Crypto.ecdsa.verify.words("SHA256", pn, pb, dn, db, sn, sb)
    return crypto.ok(r)

def ec.jwk(x: Bytes.Bytes, y: Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  Bytes.Bytes{+xn, xb} = x
  Bytes.Bytes{+yn, yb} = y
  Bytes.Bytes{+dn, db} = input
  Bytes.Bytes{+sn, sb} = sig
  do IO<Result<&1, &1, Err, Bool>>:
    r : Result<&1, &1, U32 & String, Bool> <- Crypto.ecdsa.verify.jwk.words("SHA256", xn, xb, yn, yb, dn, db, sn, sb)
    return crypto.ok(r)

# Does sig sign input under key for alg? A key of the wrong kind fails with KeyType before any crypto.
def sig.check(a: Alg, key: Key, input: Bytes.Bytes, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  match a key:
    case HS256{} Hmac{k}:
      mac.check("SHA256", 32, k, input, sig)
    case HS384{} Hmac{k}:
      mac.check("SHA384", 48, k, input, sig)
    case HS512{} Hmac{k}:
      mac.check("SHA512", 64, k, input, sig)
    case RS256{} Pem{p}:
      rsa.pem(p, input, sig)
    case RS256{} Rsa{n, e}:
      rsa.jwk(n, e, input, sig)
    case ES256{} Pem{p}:
      ec.pem(p, input, sig)
    case ES256{} Ec{x, y}:
      ec.jwk(x, y, input, sig)
    case _ _:
      IO.pure(Result<&1, &1, Err, Bool>, Fail{KeyType{}})

def rsa.sign(p: Bytes.Bytes, input: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bytes.Bytes>):
  Bytes.Bytes{+pn, pb} = p
  Bytes.Bytes{+dn, db} = input
  do IO<Result<&1, &1, Err, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.rsa.sign.words("SHA256", pn, pb, dn, db)
    return crypto.bytes(r)

def ec.sign(p: Bytes.Bytes, input: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bytes.Bytes>):
  Bytes.Bytes{+pn, pb} = p
  Bytes.Bytes{+dn, db} = input
  do IO<Result<&1, &1, Err, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.ecdsa.sign.words("SHA256", pn, pb, dn, db)
    return crypto.bytes(r)

# The signature of input under key for alg. RS256 and ES256 sign with a PEM private key.
def sig.make(a: Alg, key: Key, input: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bytes.Bytes>):
  match a key:
    case HS256{} Hmac{k}:
      mac("SHA256", 32, k, input)
    case HS384{} Hmac{k}:
      mac("SHA384", 48, k, input)
    case HS512{} Hmac{k}:
      mac("SHA512", 64, k, input)
    case RS256{} Pem{p}:
      rsa.sign(p, input)
    case ES256{} Pem{p}:
      ec.sign(p, input)
    case _ _:
      IO.pure(Result<&1, &1, Err, Bytes.Bytes>, Fail{KeyType{}})

# ---- sign and verify

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
      Bool.not(dup(fields(kvs, Nil{})))
    case _:
      False{}

def sign.if(ok: Bool, +a: Alg, key: Key, kid: Maybe<&2, String>, body: Bytes.Bytes) -> IO(Result<&1, &1, Err, String>):
  match ok:
    case False{}:
      IO.pure(Result<&1, &1, Err, String>, Fail{BadClaim{}})
    case True{}:
      +input = signing.input(a, kid, body)
      do IO<Result<&1, &1, Err, String>>:
        s : Result<&1, &1, Err, Bytes.Bytes> <- sig.make(a, key, Bytes.from_string(input))
        return sign.done(input, s)

def sign.body(+a: Alg, key: Key, kid: Maybe<&2, String>, r: Bytes.Bytes & Bytes.Bytes) -> IO(Result<&1, &1, Err, String>):
  (body, copy) = r
  sign.if(sign.obj(Json.parse.bytes(copy)), a, key, kid, body)

# A compact token of claims signed with key for a; kid names the key in the header. Claims that are not
# an object, or repeat a name, fail with BadClaim.
def sign(+a: Alg, key: Key, kid: Maybe<&2, String>, claims: Json.Val) -> IO(Result<&1, &1, Err, String>):
  sign.body(a, key, kid, Bytes.slice(Json.encode.bytes(claims), 0, 4294967295))

def claims.done(r: Result<&1, &1, Err, Unit>, v: Json.Val) -> Result<&1, &1, Err, Json.Val>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{u}:
      Done{v}

def check.sig(ok: Bool, +p: Policy, +now: U32, +f: List<&2, Field>, v: Json.Val) -> Result<&1, &1, Err, Json.Val>:
  match ok:
    case False{}:
      Fail{BadSig{}}
    case True{}:
      claims.done(claims.check(p, now, f), v)

def check.done(s: Result<&1, &1, Err, Bool>, +p: Policy, +now: U32, +f: List<&2, Field>, v: Json.Val) ->
    Result<&1, &1, Err, Json.Val>:
  match s:
    case Fail{e}:
      Fail{e}
    case Done{ok}:
      check.sig(ok, p, now, f, v)

def check.pinned(ok: Result<&1, &1, Err, Unit>, +p: Policy, key: Key, +now: U32, +f: List<&2, Field>, v: Json.Val,
    input: Bytes.Bytes, sig: Bytes.Bytes) -> IO(Result<&1, &1, Err, Json.Val>):
  match ok:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Json.Val>, Fail{e})
    case Done{u}:
      do IO<Result<&1, &1, Err, Json.Val>>:
        s : Result<&1, &1, Err, Bool> <- sig.check(policy.alg(p), key, input, sig)
        return check.done(s, p, now, f, v)

# The pinned alg, then the signature, then the claims.
def check(+p: Policy, key: Key, +now: U32, parts: Parts) -> IO(Result<&1, &1, Err, Json.Val>):
  Parts{+h, +f, v, input, sig} = parts
  check.pinned(head.check(policy.alg(p), h), p, key, now, f, v, input, sig)

def verify.parsed(+p: Policy, key: Key, +now: U32, r: Result<&1, &1, Err, Parts>) -> IO(Result<&1, &1, Err, Json.Val>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Json.Val>, Fail{e})
    case Done{parts}:
      check(p, key, now, parts)

# The claims of token when it is signed by key under p's alg and its claims hold at unix time now.
def verify(+p: Policy, key: Key, token: String, +now: U32) -> IO(Result<&1, &1, Err, Json.Val>):
  verify.parsed(p, key, now, parse(token))

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
    u : Unit <- Bool.pick(Maybe<&2, Unit>, dup(f), None{}, Some{Unit{}})
    kty : String <- str(field(f, "kty"))
    kid : String <- str(field(f, "kid"))
    s : Unit <- jwk.use(field(f, "use"))
    jwk.kty(kty, kid, f)

def jwk.of(v: Json.Val) -> Maybe<&2, Jwk>:
  match v:
    case Json.Obj{kvs}:
      jwk.fields(fields(kvs, Nil{}))
    case _:
      None{}

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

def jwk.key.of(rsa: Bool, a: Maybe<&1, Bytes.Bytes>, b: Maybe<&1, Bytes.Bytes>) -> Result<&1, &1, Err, Key>:
  match rsa a b:
    case True{} Some{n} Some{e}:
      Done{Rsa{n, e}}
    case False{} Some{x} Some{y}:
      Done{Ec{x, y}}
    case _ _ _:
      Fail{Malformed{}}

# A set member as a verify key.
def jwk.key(k: Jwk) -> Result<&1, &1, Err, Key>:
  Jwk{kid, +rsa, alg, +a, +b} = k
  jwk.key.of(rsa, unb64u(a), unb64u(b))

def jwk.found(m: Maybe<&2, Jwk>) -> Result<&1, &1, Err, Key>:
  match m:
    case None{}:
      Fail{NoKey{}}
    case Some{k}:
      jwk.key(k)

# A cached key set from the caller's own trusted url; a token never picks the url (jku and x5u are ignored).
# live: fetched once; at: the unix time of the last good fetch; ttl: seconds it stays fresh;
# tried: the unix time of the last fetch, good or not.
type Jwks is Data:
  Jwks{url: String, ttl: U32, live: Bool, at: U32, tried: Maybe<&2, U32>, keys: List<&2, Jwk>}

def jwks(url: String, +ttl: U32) -> Jwks:
  Jwks{url, ttl, False{}, 0, None{}, Nil{}}

def jwks.keys(s: Jwks) -> List<&2, Jwk>:
  Jwks{u, t, l, a, tr, ks} = s
  ks

def fetch.keys(m: Maybe<&2, List<&2, Jwk>>, c: Hairpin.Client, s: Jwks, +now: U32) -> Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>:
  match m:
    case None{}:
      (c, s, Fail{Malformed{}})
    case Some{ks}:
      Jwks{url, ttl, live, at, tried, old} = s
      (c, Jwks{url, ttl, True{}, now, tried, ks}, Done{Unit{}})

def fetch.body(ok: Bool, +status: U32, c: Hairpin.Client, s: Jwks, +now: U32, b: Bytes.Bytes) ->
    Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>:
  match ok:
    case False{}:
      (c, s, Fail{Status{status}})
    case True{}:
      fetch.keys(jwks.parse(b), c, s, now)

def fetch.res(c: Hairpin.Client, s: Jwks, +now: U32, r: Result<&1, &1, Hairpin.Err, Http.Res>) ->
    Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>:
  match r:
    case Fail{e}:
      (c, s, Fail{Net{e}})
    case Done{Http.Res{+status, h, b}}:
      fetch.body(U32.is_eq(status, 200), status, c, s, now, b)

def fetch.done(s: Jwks, +now: U32, x: Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res>) ->
    Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>:
  (c, r) = x
  fetch.res(c, s, now, r)

# GET the set now. On any failure the client and the old keys come back, with only tried moved to now.
def fetch(c: Hairpin.Client, s: Jwks, +now: U32) -> IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>):
  Jwks{+url, ttl, live, at, old, ks} = s
  do IO<Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>>:
    x : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c, url)
    return fetch.done(Jwks{url, ttl, live, at, Some{now}, ks}, now, x)

def key.after.r(r: Result<&1, &1, Err, Unit>, c: Hairpin.Client, +s: Jwks, +kid: String, +a: Alg) ->
    Hairpin.Client & Jwks & Result<&1, &1, Err, Key>:
  match r:
    case Fail{e}:
      (c, s, Fail{e})
    case Done{u}:
      (c, s, jwk.found(jwk.pick(jwks.keys(s), kid, a)))

def key.after(+kid: String, +a: Alg, x: Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>) ->
    Hairpin.Client & Jwks & Result<&1, &1, Err, Key>:
  (c, s, r) = x
  key.after.r(r, c, s, kid, a)

def key.refetch(go: Bool, c: Hairpin.Client, s: Jwks, +kid: String, +a: Alg, +now: U32) ->
    IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Key>):
  match go:
    case False{}:
      IO.pure(Hairpin.Client & Jwks & Result<&1, &1, Err, Key>, (c, s, Fail{NoKey{}}))
    case True{}:
      do IO<Hairpin.Client & Jwks & Result<&1, &1, Err, Key>>:
        x : Hairpin.Client & Jwks & Result<&1, &1, Err, Unit> <- fetch(c, s, now)
        return key.after(kid, a, x)

def key.go(cached: Bool, +go: Bool, c: Hairpin.Client, s: Jwks, found: Maybe<&2, Jwk>, +kid: String, +a: Alg, +now: U32) ->
    IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Key>):
  match cached:
    case True{}:
      IO.pure(Hairpin.Client & Jwks & Result<&1, &1, Err, Key>, (c, s, jwk.found(found)))
    case False{}:
      key.refetch(go, c, s, kid, a, now)

def since(+now: U32, m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      4294967295
    case Some{+t}:
      Bool.pick(U32, U32.is_le(t, now), (now - t : U32), 0)

# The verify key named kid for alg a. A known key stays usable through the 60 s fetch cooldown even
# when ttl is shorter. After that, refresh a stale set or an unknown kid at most once a minute.
# ponytail: fixed 60 s cooldown; make it a Jwks field if an issuer rotates faster.
def key(c: Hairpin.Client, s: Jwks, +kid: String, +a: Alg, +now: U32) -> IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Key>):
  Jwks{+url, +ttl, +live, +at, +tried, +ks} = s
  +found = jwk.pick(ks, kid, a)
  +fresh = Bool.and(live, Bool.and(U32.is_le(at, now), U32.is_lt((now - at : U32), Bool.pick(U32, U32.is_lt(ttl, 60), 60, ttl))))
  +cached = Bool.and(fresh, Maybe.is_some(&2, Jwk, found))
  key.go(cached, U32.is_le(60, since(now, tried)), c, Jwks{url, ttl, live, at, tried, ks}, found, kid, a, now)

def jwks.run(r: Result<&1, &1, Err, Key>, c: Hairpin.Client, s: Jwks, +p: Policy, +now: U32, parts: Parts) ->
    IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>):
  match r:
    case Fail{e}:
      IO.pure(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>, (c, s, Fail{e}))
    case Done{k}:
      do IO<Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>>:
        v : Result<&1, &1, Err, Json.Val> <- check(p, k, now, parts)
        return (c, s, v)

def jwks.keyed(+p: Policy, +now: U32, parts: Parts, x: Hairpin.Client & Jwks & Result<&1, &1, Err, Key>) ->
    IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>):
  (c, s, r) = x
  jwks.run(r, c, s, p, now, parts)

def jwks.kid(k: Maybe<&2, String>, +p: Policy, c: Hairpin.Client, s: Jwks, +now: U32, parts: Parts) ->
    IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>):
  match k:
    case None{}:
      IO.pure(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>, (c, s, Fail{NoKey{}}))
    case Some{+kid}:
      do IO<Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>>:
        x : Hairpin.Client & Jwks & Result<&1, &1, Err, Key> <- key(c, s, kid, policy.alg(p), now)
        jwks.keyed(p, now, parts, x)

def jwks.pinned(ok: Result<&1, &1, Err, Unit>, +p: Policy, c: Hairpin.Client, s: Jwks, +now: U32, +h: List<&2, Field>,
    parts: Parts) -> IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>):
  match ok:
    case Fail{e}:
      IO.pure(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>, (c, s, Fail{e}))
    case Done{u}:
      jwks.kid(str(field(h, "kid")), p, c, s, now, parts)

def jwks.parsed(+p: Policy, c: Hairpin.Client, s: Jwks, +now: U32, r: Result<&1, &1, Err, Parts>) ->
    IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>):
  match r:
    case Fail{e}:
      IO.pure(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>, (c, s, Fail{e}))
    case Done{Parts{+h, f, v, input, sig}}:
      jwks.pinned(head.check(policy.alg(p), h), p, c, s, now, h, Parts{h, f, v, input, sig})

# verify with the key the token's kid names in the set. The alg is pinned before any fetch.
# The client and the set (refreshed or not) always come back.
def verify.jwks(+p: Policy, c: Hairpin.Client, s: Jwks, token: String, +now: U32) ->
    IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Json.Val>):
  jwks.parsed(p, c, s, now, parse(token))
