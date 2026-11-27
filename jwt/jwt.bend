# JSON Web Tokens: HS256/384/512, RS256, and ES256 compact JWS sign and verify, claim checks, and JWKS keys over Hairpin. Source: https://github.com/paymog/bend-kit/tree/main/jwt
import Base
import bend-kit-crypto@0.2.2.2/crypto.bend as Crypto
import bend-kit-hairpin@0.19.0.3/hairpin.bend as Hairpin
import bend-kit-http@0.45.0.3/pure.bend as HttpPure
import bend-kit-json@0.7.3.2/json.bend as Json
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./pure.bend as Pure

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

# A compact JWS: the header and claim members, the claims, the signing input, and the signature.
type Parts is Type:
  Parts{head: List<&2, Field>, facts: List<&2, Field>, claims: Json.Val, input: Bytes.Bytes, sig: Bytes.Bytes}

# A usable public key from a set: its kid, RSA or EC P-256, its alg ("" when the set gives none), and its
# two base64url parts (n and e, or x and y).
type Jwk is Data:
  Jwk{kid: String, rsa: Bool, alg: String, a: String, b: String}

def alg.to.pure(v: Alg) -> Pure.Alg:
  match v:
    case HS256{}:
      Pure.HS256{}
    case HS384{}:
      Pure.HS384{}
    case HS512{}:
      Pure.HS512{}
    case RS256{}:
      Pure.RS256{}
    case ES256{}:
      Pure.ES256{}

def alg.from.pure(v: Pure.Alg) -> Alg:
  match v:
    case Pure.HS256{}:
      HS256{}
    case Pure.HS384{}:
      HS384{}
    case Pure.HS512{}:
      HS512{}
    case Pure.RS256{}:
      RS256{}
    case Pure.ES256{}:
      ES256{}

def policy.to.pure(v: Policy) -> Pure.Policy:
  match v:
    case Policy{x0, x1, x2, x3}:
      Pure.Policy{alg.to.pure(x0), x1, x2, x3}

def lit.from.pure(v: Pure.Lit) -> Lit:
  match v:
    case Pure.LStr{x0}:
      LStr{x0}
    case Pure.LNum{x0}:
      LNum{x0}
    case Pure.LStrs{x0}:
      LStrs{x0}
    case Pure.LOther{}:
      LOther{}

def lit.to.pure(v: Lit) -> Pure.Lit:
  match v:
    case LStr{x0}:
      Pure.LStr{x0}
    case LNum{x0}:
      Pure.LNum{x0}
    case LStrs{x0}:
      Pure.LStrs{x0}
    case LOther{}:
      Pure.LOther{}

def field.from.pure(v: Pure.Field) -> Field:
  match v:
    case Pure.Field{x0, x1}:
      Field{x0, lit.from.pure(x1)}

def maybe.lit.from.pure(v: Maybe<&2, Pure.Lit>) -> Maybe<&2, Lit>:
  match v:
    case None{}:
      None{}
    case Some{x}:
      Some{lit.from.pure(x)}

def maybe.lit.to.pure(v: Maybe<&2, Lit>) -> Maybe<&2, Pure.Lit>:
  match v:
    case None{}:
      None{}
    case Some{x}:
      Some{lit.to.pure(x)}

def err.from.pure(v: Pure.Err) -> Err:
  match v:
    case Pure.Malformed{}:
      Malformed{}
    case Pure.AlgMismatch{}:
      AlgMismatch{}
    case Pure.Crit{}:
      Crit{}
    case Pure.KeyType{}:
      KeyType{}
    case Pure.WeakKey{}:
      WeakKey{}
    case Pure.BadSig{}:
      BadSig{}
    case Pure.BadClaim{}:
      BadClaim{}
    case Pure.Expired{}:
      Expired{}
    case Pure.NotYet{}:
      NotYet{}
    case Pure.Future{}:
      Future{}
    case Pure.BadIss{}:
      BadIss{}
    case Pure.BadAud{}:
      BadAud{}
    case Pure.NoKey{}:
      NoKey{}
    case Pure.Crypto{x0, x1}:
      Crypto{x0, x1}

def result.err.string.from.pure(v: Result<&1, &1, Pure.Err, String>) -> Result<&1, &1, Err, String>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{x}:
      Done{x}

def result.err.unit.from.pure(v: Result<&1, &1, Pure.Err, Unit>) -> Result<&1, &1, Err, Unit>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{x}:
      Done{x}

def result.err.maybe.u32.from.pure(v: Result<&1, &1, Pure.Err, Maybe<&2, U32>>) -> Result<&1, &1, Err, Maybe<&2, U32>>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{x}:
      Done{x}

def result.err.maybe.string.from.pure(v: Result<&1, &1, Pure.Err, Maybe<&2, String>>) -> Result<&1, &1, Err, Maybe<&2, String>>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{x}:
      Done{x}

def result.err.maybe.list.string.from.pure(v: Result<&1, &1, Pure.Err, Maybe<&2, List<&2, String>>>) -> Result<&1, &1, Err, Maybe<&2, List<&2, String>>>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{x}:
      Done{x}

def jwk.from.pure(v: Pure.Jwk) -> Jwk:
  match v:
    case Pure.Jwk{x0, x1, x2, x3, x4}:
      Jwk{x0, x1, x2, x3, x4}

def jwk.to.pure(v: Jwk) -> Pure.Jwk:
  match v:
    case Jwk{x0, x1, x2, x3, x4}:
      Pure.Jwk{x0, x1, x2, x3, x4}

def jwks.list.to.pure(v: List<&2, Jwk>) -> List<&2, Pure.Jwk>:
  match v:
    case Nil{}:
      Nil{}
    case x <> xs:
      Con{jwk.to.pure(x), jwks.list.to.pure(xs)}

def jwks.list.from.pure(v: List<&2, Pure.Jwk>) -> List<&2, Jwk>:
  match v:
    case Nil{}:
      Nil{}
    case x <> xs:
      Con{jwk.from.pure(x), jwks.list.from.pure(xs)}

def maybe.list.jwk.from.pure(v: Maybe<&2, List<&2, Pure.Jwk>>) -> Maybe<&2, List<&2, Jwk>>:
  match v:
    case None{}:
      None{}
    case Some{x}:
      Some{jwks.list.from.pure(x)}

def policy.from.pure(v: Pure.Policy) -> Policy:
  match v:
    case Pure.Policy{x0, x1, x2, x3}:
      Policy{alg.from.pure(x0), x1, x2, x3}

def field.to.pure(v: Field) -> Pure.Field:
  match v:
    case Field{x0, x1}:
      Pure.Field{x0, lit.to.pure(x1)}

def fields.from.pure(v: List<&2, Pure.Field>) -> List<&2, Field>:
  match v:
    case Nil{}:
      Nil{}
    case x <> xs:
      Con{field.from.pure(x), fields.from.pure(xs)}

def parts.from.pure(v: Pure.Parts) -> Parts:
  match v:
    case Pure.Parts{x0, x1, x2, x3, x4}:
      Parts{fields.from.pure(x0), fields.from.pure(x1), x2, x3, x4}

def maybe.jwk.from.pure(v: Maybe<&2, Pure.Jwk>) -> Maybe<&2, Jwk>:
  match v:
    case None{}:
      None{}
    case Some{x}:
      Some{jwk.from.pure(x)}

def maybe.jwk.to.pure(v: Maybe<&2, Jwk>) -> Maybe<&2, Pure.Jwk>:
  match v:
    case None{}:
      None{}
    case Some{x}:
      Some{jwk.to.pure(x)}

def fields.to.pure(v: List<&2, Field>) -> List<&2, Pure.Field>:
  match v:
    case Nil{}:
      Nil{}
    case x <> xs:
      Con{field.to.pure(x), fields.to.pure(xs)}

def result.err.parts.from.pure(v: Result<&1, &1, Pure.Err, Pure.Parts>) -> Result<&1, &1, Err, Parts>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{x}:
      Done{parts.from.pure(x)}

def policy(a: Alg) -> Policy:
  policy.from.pure(Pure.policy(alg.to.pure(a)))

def iss(p: Policy, s: String) -> Policy:
  policy.from.pure(Pure.iss(policy.to.pure(p), s))

def aud(p: Policy, s: String) -> Policy:
  policy.from.pure(Pure.aud(policy.to.pure(p), s))

def leeway(p: Policy, +n: U32) -> Policy:
  policy.from.pure(Pure.leeway(policy.to.pure(p), n))

def policy.alg(p: Policy) -> Alg:
  alg.from.pure(Pure.policy.alg(policy.to.pure(p)))

def alg.name(a: Alg) -> String:
  Pure.alg.name(alg.to.pure(a))

# ---- base64url (RFC 4648 §5), unpadded, as RFC 7515 §2 requires

def b64u.push(+c: U32, acc: String) -> String:
  Pure.b64u.push(c, acc)

def b64u.go(s: String, acc: String) -> String:
  Pure.b64u.go(s, acc)

def b64u(b: Bytes.Bytes) -> String:
  Pure.b64u(b)

# The standard alphabet's char for c. '+', '/', '=' and NUL become NUL, which no decoder accepts.
def unb64u.c(+c: U32) -> U32:
  Pure.unb64u.c(c)

# Padding for n mod 4 chars; 1 is never a whole group, so it gets a NUL.
def unb64u.pad(+r: U32, acc: String) -> String:
  Pure.unb64u.pad(r, acc)

def unb64u.go(s: String, acc: String, +n: U32) -> String:
  Pure.unb64u.go(s, acc, n)

def unb64u.same(+s: String, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  Pure.unb64u.same(s, r)

def unb64u.canon(+s: String, m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  Pure.unb64u.canon(s, m)

# Strict: only the URL-safe alphabet, no '=', and only the canonical text of its octets, so pad bits are 0.
def unb64u(+s: String) -> Maybe<&1, Bytes.Bytes>:
  Pure.unb64u(s)

# ---- JSON members as copyable facts

def secs.digit(+acc: U32, +d: U32) -> U32:
  Pure.secs.digit(acc, d)

def secs.up(+acc: U32, frac: Bool) -> U32:
  Pure.secs.up(acc, frac)

# The JSON parser has checked the grammar, so only digits and one '.' need telling apart.
def secs.go(s: String, +acc: U32, +frac: Bool, +point: Bool, +ok: Bool) -> Maybe<&2, U32>:
  Pure.secs.go(s, acc, frac, point, ok)

def secs(s: String) -> Maybe<&2, U32>:
  Pure.secs(s)

def str.of(v: Json.Val) -> Maybe<&2, String>:
  Pure.str.of(v)

def strs.push(s: Maybe<&2, String>, acc: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  Pure.strs.push(s, acc)

def strs(xs: List<&1, Json.Val>, acc: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  Pure.strs(xs, acc)

def lit(v: Json.Val) -> Lit:
  lit.from.pure(Pure.lit(v))

# An object's members, names as octets, last first.
def fields(kvs: List<&1, Bytes.Bytes & Json.Val>, acc: List<&2, Field>) -> List<&2, Field>:
  fields.from.pure(Pure.fields(kvs, fields.to.pure(acc)))

def field(l: List<&2, Field>, +k: String) -> Maybe<&2, Lit>:
  maybe.lit.from.pure(Pure.field(fields.to.pure(l), k))

def has(l: List<&2, Field>, +k: String) -> Bool:
  Pure.has(fields.to.pure(l), k)

def str(m: Maybe<&2, Lit>) -> Maybe<&2, String>:
  Pure.str(maybe.lit.to.pure(m))

# ---- parsing

# RFC 7515 §5.2 allows rejecting repeated names; a second "alg" is how parsers come to disagree.
# parse.claims rejects them at every depth with Json.unique.parsed before members get here.
def parse.json(h: Maybe<&1, Json.Val>, f: Maybe<&1, Json.Val>, c: Maybe<&1, Json.Val>, input: Bytes.Bytes, sig: Bytes.Bytes) -> Result<&1, &1, Err, Parts>:
  result.err.parts.from.pure(Pure.parse.json(h, f, c, input, sig))

def parse.claims(hb: Bytes.Bytes, r: Bytes.Bytes & Bytes.Bytes, input: Bytes.Bytes, sig: Bytes.Bytes) -> Result<&1, &1, Err, Parts>:
  result.err.parts.from.pure(Pure.parse.claims(hb, r, input, sig))

def parse.segs(h: Maybe<&1, Bytes.Bytes>, c: Maybe<&1, Bytes.Bytes>, s: Maybe<&1, Bytes.Bytes>, input: Bytes.Bytes) -> Result<&1, &1, Err, Parts>:
  result.err.parts.from.pure(Pure.parse.segs(h, c, s, input))

def parse.split(xs: List<&2, String>) -> Result<&1, &1, Err, Parts>:
  result.err.parts.from.pure(Pure.parse.split(xs))

# Three strict base64url segments, the first two JSON objects with no repeated names.
def parse(token: String) -> Result<&1, &1, Err, Parts>:
  result.err.parts.from.pure(Pure.parse(token))

# ---- checks

def fail.if(bad: Bool, +e: Err) -> Result<&1, &1, Err, Unit>:
  match bad:
    case True{}:
      Fail{e}
    case False{}:
      Done{Unit{}}

def head.alg(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, String>:
  result.err.string.from.pure(Pure.head.alg(maybe.lit.to.pure(m)))

# The header's alg is exactly the pinned one, and it asks for no extension: crit (RFC 7515 §4.1.11) and
# b64 (RFC 7797) change how the token must be read, and neither is implemented.
def head.check(+a: Alg, +h: List<&2, Field>) -> Result<&1, &1, Err, Unit>:
  result.err.unit.from.pure(Pure.head.check(alg.to.pure(a), fields.to.pure(h)))

def when(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, Maybe<&2, U32>>:
  result.err.maybe.u32.from.pure(Pure.when(maybe.lit.to.pure(m)))

def text(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, Maybe<&2, String>>:
  result.err.maybe.string.from.pure(Pure.text(maybe.lit.to.pure(m)))

# RFC 7519 §4.1.3: aud is one string or an array of them.
def auds(m: Maybe<&2, Lit>) -> Result<&1, &1, Err, Maybe<&2, List<&2, String>>>:
  result.err.maybe.list.string.from.pure(Pure.auds(maybe.lit.to.pure(m)))

# exp (RFC 7519 §4.1.4): now must be before it; late by at least leeway fails.
def late(+now: U32, +lw: U32, m: Maybe<&2, U32>) -> Bool:
  Pure.late(now, lw, m)

# nbf and iat: at most leeway seconds in the future.
def early(+now: U32, +lw: U32, m: Maybe<&2, U32>) -> Bool:
  Pure.early(now, lw, m)

def octets(s: String) -> String:
  Pure.octets(s)

def iss.bad(want: Maybe<&2, String>, got: Maybe<&2, String>) -> Bool:
  Pure.iss.bad(want, got)

def aud.has(l: List<&2, String>, +a: String) -> Bool:
  Pure.aud.has(l, a)

# RFC 7519 §4.1.3: a token with an aud that does not name us fails, as does one without aud when we want one.
def aud.bad(want: Maybe<&2, String>, got: Maybe<&2, List<&2, String>>) -> Bool:
  Pure.aud.bad(want, got)

# The registered claims of c at unix time now.
def claims.check(p: Policy, +now: U32, +c: List<&2, Field>) -> Result<&1, &1, Err, Unit>:
  result.err.unit.from.pure(Pure.claims.check(policy.to.pure(p), now, fields.to.pure(c)))

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
  result.err.unit.from.pure(Pure.inspect(policy.to.pure(p), token, now))

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
  Pure.header.kid(m)

# {"alg":..,"typ":"JWT"}, then "kid" when given.
def header(a: Alg, kid: Maybe<&2, String>) -> Json.Val:
  Pure.header(alg.to.pure(a), kid)

# header.body in base64url, body being the compact JSON claims: the text the signature covers.
def signing.input(a: Alg, kid: Maybe<&2, String>, body: Bytes.Bytes) -> String:
  Pure.signing.input(alg.to.pure(a), kid, body)

def sign.done(+input: String, s: Result<&1, &1, Err, Bytes.Bytes>) -> Result<&1, &1, Err, String>:
  match s:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      Done{input ++ "." ++ b64u(b)}

# verify accepts only an object with no repeated names, so sign makes no other kind.
def sign.obj(m: Maybe<&1, Json.Val>) -> Bool:
  Pure.sign.obj(m)

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
  sign.if(sign.obj(Json.unique.parsed(Json.parse.bytes(copy))), a, key, kid, body)

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

def jwk.two(+rsa: Bool, +kid: String, +alg: String, a: Maybe<&2, String>, b: Maybe<&2, String>) -> Maybe<&2, Jwk>:
  maybe.jwk.from.pure(Pure.jwk.two(rsa, kid, alg, a, b))

# An alg member that is not a string can match no pinned alg.
def jwk.alg(m: Maybe<&2, Lit>) -> String:
  Pure.jwk.alg(maybe.lit.to.pure(m))

def jwk.use(m: Maybe<&2, Lit>) -> Maybe<&2, Unit>:
  Pure.jwk.use(maybe.lit.to.pure(m))

def jwk.kty(+kty: String, +kid: String, +f: List<&2, Field>) -> Maybe<&2, Jwk>:
  maybe.jwk.from.pure(Pure.jwk.kty(kty, kid, fields.to.pure(f)))

def jwk.fields(+f: List<&2, Field>) -> Maybe<&2, Jwk>:
  maybe.jwk.from.pure(Pure.jwk.fields(fields.to.pure(f)))

def jwk.obj(m: Maybe<&1, Json.Val>) -> Maybe<&2, Jwk>:
  maybe.jwk.from.pure(Pure.jwk.obj(m))

# A key whose members repeat a name, at any depth, is skipped.
def jwk.of(v: Json.Val) -> Maybe<&2, Jwk>:
  maybe.jwk.from.pure(Pure.jwk.of(v))

def jwk.push(m: Maybe<&2, Jwk>, acc: List<&2, Jwk>) -> List<&2, Jwk>:
  jwks.list.from.pure(Pure.jwk.push(maybe.jwk.to.pure(m), jwks.list.to.pure(acc)))

def jwks.go(xs: List<&1, Json.Val>, acc: List<&2, Jwk>) -> List<&2, Jwk>:
  jwks.list.from.pure(Pure.jwks.go(xs, jwks.list.to.pure(acc)))

def jwks.arr(m: Maybe<&1, Json.Val>) -> Maybe<&2, List<&2, Jwk>>:
  maybe.list.jwk.from.pure(Pure.jwks.arr(m))

def jwks.doc(m: Maybe<&1, Json.Val>) -> Maybe<&2, List<&2, Jwk>>:
  maybe.list.jwk.from.pure(Pure.jwks.doc(m))

# The signing keys of a JWK Set document; members it cannot use (enc keys, other curves, oct) are skipped.
# None when the document is not {"keys": [...]}.
def jwks.parse(b: Bytes.Bytes) -> Maybe<&2, List<&2, Jwk>>:
  maybe.list.jwk.from.pure(Pure.jwks.parse(b))

def fam(a: Alg) -> U32:
  Pure.fam(alg.to.pure(a))

def jwk.fits(k: Jwk, +kid: String, +a: Alg) -> Bool:
  Pure.jwk.fits(jwk.to.pure(k), kid, alg.to.pure(a))

# The first key named kid that can check alg a. RFC 7515 §4.1.4 leaves kid matching to exact comparison.
def jwk.pick(ks: List<&2, Jwk>, +kid: String, +a: Alg) -> Maybe<&2, Jwk>:
  maybe.jwk.from.pure(Pure.jwk.pick(jwks.list.to.pure(ks), kid, alg.to.pure(a)))

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

def fetch.res(c: Hairpin.Client, s: Jwks, +now: U32, r: Result<&1, &1, Hairpin.Err, HttpPure.Res>) ->
    Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>:
  match r:
    case Fail{e}:
      (c, s, Fail{Net{e}})
    case Done{HttpPure.Res{+status, h, b}}:
      fetch.body(U32.is_eq(status, 200), status, c, s, now, b)

def fetch.done(s: Jwks, +now: U32, x: Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res>) ->
    Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>:
  (c, r) = x
  fetch.res(c, s, now, r)

# GET the set now. On any failure the client and the old keys come back, with only tried moved to now.
def fetch(c: Hairpin.Client, s: Jwks, +now: U32) -> IO(Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>):
  Jwks{+url, ttl, live, at, old, ks} = s
  do IO<Hairpin.Client & Jwks & Result<&1, &1, Err, Unit>>:
    x : Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res> <- Hairpin.get(c, url)
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
