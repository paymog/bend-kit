# Webhook signatures: Standard Webhooks sign and verify, Stripe and GitHub verify, over the raw body. Source: https://github.com/paymog/bend-kit/tree/main/webhooks
import Base
import bend-kit-crypto@0.2.0.0/crypto.bend as Crypto
import bend-kit-time@0.1.0.0/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
# By hash, as http imports them: bend-kit-encoding@0.3.0.0, -bytes@0.3.0.0.
import 0xcfc8be7b076f41f95c8e118383892d55/encoding.bend as Enc
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http

# Every MAC is HMAC-SHA256 over the body exactly as received, never a re-encoding of parsed JSON.
# Headers are Http.Req headers: lowercase names, octet-string values. Each verify hands the body back.
# secrets: candidates, tried in turn, for key rotation. Every MAC comparison is Crypto.eq.ct.words.
# now is explicit, so a check is deterministic; a handler passes Time.now().

type Err is Data:
  Missing{name: String}
  BadSecret{}
  BadId{}
  BadTimestamp{}
  TooOld{}
  TooNew{}
  NoMatch{}
  CryptoErr{code: U32, msg: String}

# ---- headers and text

def field.head(xs: List<&2, String>) -> Maybe<&2, String>:
  match xs:
    case Nil{}:
      None{}
    case Con{v, t}:
      Some{v}

def field.of(r: Map<&2, List<&2, String>> & List<&2, String>) -> Maybe<&2, String>:
  (h, xs) = r
  field.head(xs)

def field(+h: Map<&2, List<&2, String>>, k: String) -> Maybe<&2, String>:
  field.of(Map.get(List<&2, String>, Nil{}, h, k))

def need(+name: String, m: Maybe<&2, String>) -> Result<&1, &1, Err, String>:
  match m:
    case None{}:
      Fail{Missing{name}}
    case Some{v}:
      Done{v}

# s after the prefix p, or None.
def strip(+p: String, +s: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.starts_with(s, p), Some{String.drop(s, String.length(p))}, None{})

def push(m: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match m:
    case None{}:
      rest
    case Some{s}:
      Con{s, rest}

def put(m: Map<&2, List<&2, String>>, k: String, v: String) -> Map<&2, List<&2, String>>:
  Map.set(&2, List<&2, String>, m, k, Con{v, Nil{}})

def digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), digits(t))

def ts.some(ok: Bool, m: Maybe<&2, Int.I64>) -> Result<&1, &1, Err, Int.I64>:
  match ok:
    case False{}:
      Fail{BadTimestamp{}}
    case True{}:
      match m:
        case None{}:
          Fail{BadTimestamp{}}
        case Some{t}:
          Done{t}

# Unix seconds: 1 to 18 ASCII digits, no sign, so the parse never overflows.
def ts.read(+s: String) -> Result<&1, &1, Err, Int.I64>:
  +n = String.length(s)
  ts.some(Bool.and(Bool.and(Nat.is_lt(0n, n), Nat.is_le(n, 18n)), digits(s)), Int.I64.read(s))

def window.pick(old: Bool, ahead: Bool) -> Result<&1, &1, Err, Unit>:
  match old:
    case True{}:
      Fail{TooOld{}}
    case False{}:
      Bool.pick(Result<&1, &1, Err, Unit>, ahead, Fail{TooNew{}}, Done{Unit{}})

# t within tol seconds of now, either way.
def window(+tol: U32, now: Time.Instant, t: Int.I64) -> Result<&1, &1, Err, Unit>:
  match now:
    case Time.Instant{n, ns}:
      +d = Int.I64.sub(n, t)
      +w = Int.I64.from_u32(tol)
      window.pick(Int.I64.is_gt(d, w), Int.I64.is_lt(d, Int.I64.neg(w)))

# A webhook id is not empty and has no '.', so id.timestamp.body reads one way.
def id.check(+id: String) -> Result<&1, &1, Err, Unit>:
  Bool.pick(Result<&1, &1, Err, Unit>, Bool.or(String.is_empty(id), String.contains(id, ".")), Fail{BadId{}}, Done{Unit{}})

# ---- keys and signatures

def b64.same(+s: String, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  (b, c) = r
  Bool.pick(Maybe<&1, Bytes.Bytes>, String.eq(Bytes.to_base64(c), s), Some{b}, None{})

def b64.canon(+s: String, m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      b64.same(s, Bytes.slice(b, 0, 4294967295))

# Padded standard base64, only in its canonical text: Bytes.from_base64 alone accepts nonzero pad bits.
def b64(+s: String) -> Maybe<&1, Bytes.Bytes>:
  b64.canon(s, Bytes.from_base64(s))

# '=' up to a multiple of four chars.
def pad(+s: String) -> String:
  +r = (String.length(s) % 4n : Nat)
  s ++ Bool.pick(String, Nat.is_eq(r, 2n), "==", Bool.pick(String, Nat.is_eq(r, 3n), "=", ""))

def nonempty.of(b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  Bytes.Bytes{+n, a} = b
  Bool.pick(Maybe<&1, Bytes.Bytes>, U32.is_eq(n, 0), None{}, Some{Bytes.Bytes{n, a}})

def nonempty(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      nonempty.of(b)

# A Standard Webhooks secret: whsec_ then base64 of the key, padded or not. The prefix is optional.
def key.std(+s: String) -> Maybe<&1, Bytes.Bytes>:
  nonempty(b64(pad(Bool.pick(String, String.starts_with(s, "whsec_"), String.drop(s, 6n), s))))

# std: a Standard Webhooks secret. Otherwise the secret's UTF-8 is the key, as Stripe and GitHub use it.
def key(+std: Bool, +s: String) -> Maybe<&1, Bytes.Bytes>:
  match std:
    case True{}:
      key.std(s)
    case False{}:
      nonempty(Some{Enc.utf8.encode(s)})

# A signature's octets: hex (Stripe, GitHub) or canonical base64 (Standard Webhooks).
def decode(+hex: Bool, +s: String) -> Maybe<&1, Bytes.Bytes>:
  match hex:
    case True{}:
      Bytes.from_hex(s)
    case False{}:
      b64(s)

def mac.of(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, Err, Bytes.Bytes>:
  match r:
    case Fail{(c, w)}:
      Fail{CryptoErr{c, w}}
    case Done{(n, b)}:
      Done{Bytes.Bytes{n, b}}

def mac(k: Bytes.Bytes, data: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bytes.Bytes>):
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+dn, db} = data
  do IO<Result<&1, &1, Err, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.hmac.words("SHA256", kn, kb, dn, db)
    return mac.of(r)

def ct.go(m: Bytes.Bytes, s: Bytes.Bytes) -> IO(Bool):
  Bytes.Bytes{+mn, mb} = m
  Bytes.Bytes{+sn, sb} = s
  Crypto.eq.ct.words(mn, mb, sn, sb)

# A signature that does not decode matches nothing.
def ct(s: Maybe<&1, Bytes.Bytes>, m: Bytes.Bytes) -> IO(Bool):
  match s:
    case None{}:
      IO.pure(Bool, False{})
    case Some{b}:
      ct.go(m, b)

# Does any signature equal the MAC? r holds the MAC and a copy; every signature is compared.
def any.sig(sigs: List<&2, String>, +hex: Bool, r: Bytes.Bytes & Bytes.Bytes) -> IO(Bool):
  match sigs:
    case Nil{}:
      IO.pure(Bool, False{})
    case Con{s, t}:
      (m1, m2) = r
      do IO<Bool>:
        ok : Bool <- ct(decode(hex, s), m2)
        rest : Bool <- any.sig(t, hex, Bytes.slice(m1, 0, 4294967295))
        return Bool.or(ok, rest)

def key.cmp(r: Result<&1, &1, Err, Bytes.Bytes>, +hex: Bool, +sigs: List<&2, String>) -> IO(Result<&1, &1, Err, Bool>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Bool>, Fail{e})
    case Done{m}:
      do IO<Result<&1, &1, Err, Bool>>:
        ok : Bool <- any.sig(sigs, hex, Bytes.slice(m, 0, 4294967295))
        return Done{ok}

def key.check(k: Maybe<&1, Bytes.Bytes>, +hex: Bool, +sigs: List<&2, String>, msg: Bytes.Bytes) -> IO(Result<&1, &1, Err, Bool>):
  match k:
    case None{}:
      IO.pure(Result<&1, &1, Err, Bool>, Fail{BadSecret{}})
    case Some{b}:
      do IO<Result<&1, &1, Err, Bool>>:
        r : Result<&1, &1, Err, Bytes.Bytes> <- mac(b, msg)
        key.cmp(r, hex, sigs)

def both.done(+x: Bool, b: Result<&1, &1, Err, Bool>) -> Result<&1, &1, Err, Bool>:
  match b:
    case Fail{e}:
      Fail{e}
    case Done{y}:
      Done{Bool.or(x, y)}

# A bad secret fails the check, even when another secret matches.
def both(a: Result<&1, &1, Err, Bool>, b: Result<&1, &1, Err, Bool>) -> Result<&1, &1, Err, Bool>:
  match a:
    case Fail{e}:
      Fail{e}
    case Done{x}:
      both.done(x, b)

# Does any signature sign the message under any secret? r holds the message and a copy.
def any.key(keys: List<&2, String>, +std: Bool, +hex: Bool, +sigs: List<&2, String>, r: Bytes.Bytes & Bytes.Bytes) ->
    IO(Result<&1, &1, Err, Bool>):
  match keys:
    case Nil{}:
      IO.pure(Result<&1, &1, Err, Bool>, Done{False{}})
    case Con{k, t}:
      (m1, m2) = r
      do IO<Result<&1, &1, Err, Bool>>:
        a : Result<&1, &1, Err, Bool> <- key.check(key(std, k), hex, sigs, m2)
        b : Result<&1, &1, Err, Bool> <- any.key(t, std, hex, sigs, Bytes.slice(m1, 0, 4294967295))
        return both(a, b)

def found(-A: Data, r: Result<&1, &1, Err, Bool>, v: A) -> Result<&1, &1, Err, A>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{ok}:
      Bool.pick(Result<&1, &1, Err, A>, ok, Done{v}, Fail{NoMatch{}})

# The body back beside a failure.
def back(-A: Data, r: Bytes.Bytes & Bytes.Bytes, e: Err) -> IO(Bytes.Bytes & Result<&1, &1, Err, A>):
  (keep, copy) = r
  IO.pure(Bytes.Bytes & Result<&1, &1, Err, A>, (keep, Fail{e}))

def run.mac(-A: Data, v: A, pre: String, +sigs: List<&2, String>, +std: Bool, +hex: Bool, secrets: List<&2, String>,
    r: Bytes.Bytes & Bytes.Bytes) -> IO(Bytes.Bytes & Result<&1, &1, Err, A>):
  (keep, copy) = r
  do IO<Bytes.Bytes & Result<&1, &1, Err, A>>:
    hit : Result<&1, &1, Err, Bool> <-
      any.key(secrets, std, hex, sigs, Bytes.slice(Bytes.append(Bytes.from_string(pre), copy), 0, 4294967295))
    return (keep, found(A, hit, v))

# c: the header checks' answer, the signed prefix before the body, and the candidate signatures.
def run(-A: Data, c: Result<&1, &1, Err, A & String & List<&2, String>>, +std: Bool, +hex: Bool, secrets: List<&2, String>,
    r: Bytes.Bytes & Bytes.Bytes) -> IO(Bytes.Bytes & Result<&1, &1, Err, A>):
  match c:
    case Fail{e}:
      back(A, r, e)
    case Done{(v, pre, sigs)}:
      run.mac(A, v, pre, sigs, std, hex, secrets, r)

# ---- Standard Webhooks (https://www.standardwebhooks.com)

# The v1 entries of a space-separated webhook-signature; other versions are skipped.
def std.sigs(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      push(strip("v1,", x), std.sigs(t))

def std.check(+tol: U32, now: Time.Instant, +h: Map<&2, List<&2, String>>) -> Result<&1, &1, Err, String & String & List<&2, String>>:
  do Result<&1, &1, Err, String & String & List<&2, String>>:
    +id : String <- need("webhook-id", field(h, "webhook-id"))
    +ts : String <- need("webhook-timestamp", field(h, "webhook-timestamp"))
    sig : String <- need("webhook-signature", field(h, "webhook-signature"))
    u : Unit <- id.check(id)
    t : Int.I64 <- ts.read(ts)
    w : Unit <- window(tol, now, t)
    return (id, id ++ "." ++ ts ++ ".", std.sigs(String.split(sig, ' ')))

# Done with the webhook-id when a v1 signature in webhook-signature signs id.timestamp.body under a secret,
# and webhook-timestamp is within tol seconds of now.
def verify.with(+tol: U32, secrets: List<&2, String>, now: Time.Instant, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, String>):
  run(String, std.check(tol, now, headers), True{}, False{}, secrets, Bytes.slice(body, 0, 4294967295))

# verify.with a 300 s tolerance.
def verify(secrets: List<&2, String>, now: Time.Instant, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, String>):
  verify.with(300, secrets, now, headers, body)

def sign.check(+id: String, +ts: Int.I64) -> Result<&1, &1, Err, String & String>:
  do Result<&1, &1, Err, String & String>:
    u : Unit <- id.check(id)
    w : Unit <- Bool.pick(Result<&1, &1, Err, Unit>, Int.I64.is_neg(ts), Fail{BadTimestamp{}}, Done{Unit{}})
    return (id, Int.I64.show(ts))

def sign.headers(+id: String, +ts: String, m: Result<&1, &1, Err, Bytes.Bytes>) -> Result<&1, &1, Err, Map<&2, List<&2, String>>>:
  match m:
    case Fail{e}:
      Fail{e}
    case Done{s}:
      Done{put(put(put(Map.new(&2, List<&2, String>), "webhook-id", id), "webhook-timestamp", ts), "webhook-signature", "v1," ++ Bytes.to_base64(s))}

def sign.mac(k: Bytes.Bytes, +id: String, +ts: String, r: Bytes.Bytes & Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>>):
  (keep, copy) = r
  do IO<Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>>>:
    m : Result<&1, &1, Err, Bytes.Bytes> <- mac(k, Bytes.append(Bytes.from_string(id ++ "." ++ ts ++ "."), copy))
    return (keep, sign.headers(id, ts, m))

def sign.key(k: Maybe<&1, Bytes.Bytes>, +id: String, +ts: String, r: Bytes.Bytes & Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>>):
  match k:
    case None{}:
      back(Map<&2, List<&2, String>>, r, BadSecret{})
    case Some{b}:
      sign.mac(b, id, ts, r)

def sign.go(c: Result<&1, &1, Err, String & String>, +secret: String, r: Bytes.Bytes & Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>>):
  match c:
    case Fail{e}:
      back(Map<&2, List<&2, String>>, r, e)
    case Done{(id, ts)}:
      sign.key(key.std(secret), id, ts, r)

# The webhook-id, webhook-timestamp, and webhook-signature ("v1,<base64 MAC>") headers for body.
# id: not empty, no '.'. ts: unix seconds, not negative. secret: whsec_<base64>; send the prefix.
def sign(+id: String, +ts: Int.I64, body: Bytes.Bytes, +secret: String) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>>):
  sign.go(sign.check(id, ts), secret, Bytes.slice(body, 0, 4294967295))

# ---- Stripe (https://docs.stripe.com/webhooks#verify-manually)

def stripe.t(s: String, r: List<&2, String> & List<&2, String>) -> List<&2, String> & List<&2, String>:
  (ts, vs) = r
  (Con{s, ts}, vs)

def stripe.v.push(s: String, r: List<&2, String> & List<&2, String>) -> List<&2, String> & List<&2, String>:
  (ts, vs) = r
  (ts, Con{s, vs})

def stripe.v(m: Maybe<&2, String>, r: List<&2, String> & List<&2, String>) -> List<&2, String> & List<&2, String>:
  match m:
    case None{}:
      r
    case Some{s}:
      stripe.v.push(s, r)

def stripe.item(t: Maybe<&2, String>, v: Maybe<&2, String>, r: List<&2, String> & List<&2, String>) ->
    List<&2, String> & List<&2, String>:
  match t:
    case None{}:
      stripe.v(v, r)
    case Some{s}:
      stripe.t(s, r)

# The t= and v1= values of comma-separated items; other schemes (v0) are skipped.
def stripe.items(xs: List<&2, String>) -> List<&2, String> & List<&2, String>:
  match xs:
    case Nil{}:
      (Nil{}, Nil{})
    case Con{+x, rest}:
      stripe.item(strip("t=", x), strip("v1=", x), stripe.items(rest))

def stripe.single(ts: List<&2, String>, vs: List<&2, String>) -> Result<&1, &1, Err, String & List<&2, String>>:
  match ts:
    case Nil{}:
      Fail{BadTimestamp{}}
    case Con{t, Nil{}}:
      Done{(t, vs)}
    case Con{t, more}:
      Fail{BadTimestamp{}}

# Exactly one t=: a second one would leave the signed timestamp ambiguous.
def stripe.one(r: List<&2, String> & List<&2, String>) -> Result<&1, &1, Err, String & List<&2, String>>:
  (ts, vs) = r
  stripe.single(ts, vs)

def stripe.when(+tol: U32, now: Time.Instant, p: String & List<&2, String>) -> Result<&1, &1, Err, Unit & String & List<&2, String>>:
  (+ts, vs) = p
  do Result<&1, &1, Err, Unit & String & List<&2, String>>:
    t : Int.I64 <- ts.read(ts)
    w : Unit <- window(tol, now, t)
    return (Unit{}, ts ++ ".", vs)

def stripe.check(+tol: U32, now: Time.Instant, +h: Map<&2, List<&2, String>>) -> Result<&1, &1, Err, Unit & String & List<&2, String>>:
  do Result<&1, &1, Err, Unit & String & List<&2, String>>:
    sig : String <- need("stripe-signature", field(h, "stripe-signature"))
    p : String & List<&2, String> <- stripe.one(stripe.items(String.split(sig, ',')))
    stripe.when(tol, now, p)

# Done when a v1 hex signature in stripe-signature signs t.body under a secret (the whsec_ text itself, as UTF-8),
# and t is within tol seconds of now.
def stripe.verify.with(+tol: U32, secrets: List<&2, String>, now: Time.Instant, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Unit>):
  run(Unit, stripe.check(tol, now, headers), False{}, True{}, secrets, Bytes.slice(body, 0, 4294967295))

# stripe.verify.with a 300 s tolerance, Stripe's default.
def stripe.verify(secrets: List<&2, String>, now: Time.Instant, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Unit>):
  stripe.verify.with(300, secrets, now, headers, body)

# ---- GitHub (https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries)

def github.check(+h: Map<&2, List<&2, String>>) -> Result<&1, &1, Err, Unit & String & List<&2, String>>:
  do Result<&1, &1, Err, Unit & String & List<&2, String>>:
    sig : String <- need("x-hub-signature-256", field(h, "x-hub-signature-256"))
    return (Unit{}, "", push(strip("sha256=", sig), Nil{}))

# Done when x-hub-signature-256 is sha256=<hex> of the body under a secret's UTF-8. GitHub signs no timestamp.
def github.verify(secrets: List<&2, String>, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Unit>):
  run(Unit, github.check(headers), False{}, True{}, secrets, Bytes.slice(body, 0, 4294967295))

type SendErr is Data:
  SendSign{err: Err}
  SendNet{err: Http.Err}

def send.result(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, SendErr, Http.Res>:
  match r:
    case Fail{e}:
      Fail{SendNet{e}}
    case Done{res}:
      Done{res}

def send.judge(r: Result<&1, &1, Http.Err, Http.Res>) ->
    Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  match r:
    case Fail{e}:
      Http.retry.judge(True{}, Fail{e})
    case Done{res}:
      Http.Res{+status, +headers, body} = res
      +again = Bool.or(Http.retry.status(status), U32.is_eq((status / 100 : U32), 5))
      (Done{Http.Res{status, headers, body}}, Bool.pick(Maybe<&2, String>, again, Some{Http.header(headers, "retry-after")}, None{}))

def send.tried.of(body: Bytes.Bytes, c: Hairpin.Client,
    r: Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) ->
    Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  (judged, again) = r
  (c, body, judged, again)

def send.tried(body: Bytes.Bytes, r: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) ->
    Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  (c, result) = r
  send.tried.of(body, c, send.judge(result))

def send.try.copy(c: Hairpin.Client, url: String, +headers: Map<&2, List<&2, String>>,
    pair: Bytes.Bytes & Bytes.Bytes) ->
    IO(Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>):
  (body, spare) = pair
  do IO<Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>>:
    r : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- Hairpin.request(c, "POST", url, headers, spare)
    return send.tried(body, r)

def send.try(c: Hairpin.Client, url: String, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>):
  send.try.copy(c, url, headers, Bytes.slice(body, 0, 4294967295))

def send.go(left: Nat, +n: Nat, +url: String, +headers: Map<&2, List<&2, String>>,
    r: Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) ->
    IO(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>):
  match left:
    case 0n:
      (c, body, result, again) = r
      IO.pure(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>, (c, send.result(result)))
    case 1n+rest:
      (c, body, result, again) = r
      match again:
        case None{}:
          IO.pure(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>, (c, send.result(result)))
        case Some{after}:
          do IO<Hairpin.Client & Result<&1, &1, SendErr, Http.Res>>:
            Http.retry.sleep(after, n)
            tried : Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String> <-
              send.try(c, url, headers, body)
            send.go(rest, 1n+n, url, headers, tried)

def send.signed(n: U32, c: Hairpin.Client, +url: String, r: Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>>) ->
    IO(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>):
  (body, signed) = r
  match signed:
    case Fail{e}:
      IO.pure(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>, (c, Fail{SendSign{e}}))
    case Done{+h}:
      +headers = Http.set(h, "content-type", "application/json")
      do IO<Hairpin.Client & Result<&1, &1, SendErr, Http.Res>>:
        first : Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String> <-
          send.try(Hairpin.redirect(c, Http.ModeManual{}), url, headers, body)
        send.go(U32.to_nat(n), 0n, url, headers, first)

# One event and one signature per delivery. n extra attempts use HTTP's backoff on timeouts and 5xx.
# Every attempt reuses this event ID, timestamp, headers, and raw body.
def send.at(n: U32, c: Hairpin.Client, url: String, id: String, secret: String, body: Bytes.Bytes, now: Time.Instant) ->
    IO(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>):
  match now:
    case Time.Instant{secs, nanos}:
      do IO<Hairpin.Client & Result<&1, &1, SendErr, Http.Res>>:
        signed : Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>> <- sign(id, secs, body, secret)
        send.signed(n, c, url, signed)

def send.with(n: U32, c: Hairpin.Client, url: String, id: String, secret: String, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>):
  do IO<Hairpin.Client & Result<&1, &1, SendErr, Http.Res>>:
    now : Time.Instant <- Time.now()
    send.at(n, c, url, id, secret, body, now)

# Three extra attempts by default.
def send(c: Hairpin.Client, url: String, id: String, secret: String, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, SendErr, Http.Res>):
  send.with(3, c, url, id, secret, body)
