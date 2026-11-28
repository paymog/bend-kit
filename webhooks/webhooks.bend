# Webhook signatures: Standard Webhooks sign and verify, Stripe and GitHub verify, over the raw body. Source: https://github.com/paymog/bend-kit/tree/main/webhooks
import Base
import bend-kit-crypto@0.2.2.2/crypto.bend as Crypto
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-encoding@0.5.0.3/encoding.bend as Enc
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-hairpin@0.19.1.0/hairpin.bend as Hairpin
import bend-kit-hairpin@0.19.1.0/pure.bend as HairpinPure
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-http@0.45.1.0/http.bend as Http
import bend-kit-http@0.45.1.0/pure.bend as HttpPure
import ./pure.bend as Pure

# Every MAC is HMAC-SHA256 over the body exactly as received, never a re-encoding of parsed JSON.
# Headers are HttpPure.Req headers: lowercase names, octet-string values. Each verify hands the body back.
# secrets: candidates, tried in turn, for key rotation. Every MAC comparison is Crypto.eq.ct.words.
# now is explicit, so a check is deterministic; a handler passes Http.clock.now().

type Err is Data:
  Missing{name: String}
  BadSecret{}
  BadId{}
  BadTimestamp{}
  TooOld{}
  TooNew{}
  NoMatch{}
  CryptoErr{code: U32, msg: String}

def err.from.pure(e: Pure.Err) -> Err:
  match e:
    case Pure.Missing{name}:
      Missing{name}
    case Pure.BadSecret{}:
      BadSecret{}
    case Pure.BadId{}:
      BadId{}
    case Pure.BadTimestamp{}:
      BadTimestamp{}
    case Pure.TooOld{}:
      TooOld{}
    case Pure.TooNew{}:
      TooNew{}
    case Pure.NoMatch{}:
      NoMatch{}
    case Pure.CryptoErr{code, msg}:
      CryptoErr{code, msg}

def result.from.pure(-A: Type, r: Result<&1, &1, Pure.Err, A>) -> Result<&1, &1, Err, A>:
  match r:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{v}:
      Done{v}

def field.head(xs: List<&2, String>) -> Maybe<&2, String>:
  Pure.field.head(xs)

def field.of(r: Map<&2, List<&2, String>> & List<&2, String>) -> Maybe<&2, String>:
  Pure.field.of(r)

def field(+h: Map<&2, List<&2, String>>, k: String) -> Maybe<&2, String>:
  Pure.field(h, k)

def need(+name: String, m: Maybe<&2, String>) -> Result<&1, &1, Err, String>:
  result.from.pure(String, Pure.need(name, m))

def strip(+p: String, +s: String) -> Maybe<&2, String>:
  Pure.strip(p, s)

def push(m: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  Pure.push(m, rest)

def put(m: Map<&2, List<&2, String>>, k: String, v: String) -> Map<&2, List<&2, String>>:
  Pure.put(m, k, v)

def digits(s: String) -> Bool:
  Pure.digits(s)

def ts.some(ok: Bool, m: Maybe<&2, Int.I64>) -> Result<&1, &1, Err, Int.I64>:
  result.from.pure(Int.I64, Pure.ts.some(ok, m))

def ts.read(+s: String) -> Result<&1, &1, Err, Int.I64>:
  result.from.pure(Int.I64, Pure.ts.read(s))

def window.pick(old: Bool, ahead: Bool) -> Result<&1, &1, Err, Unit>:
  result.from.pure(Unit, Pure.window.pick(old, ahead))

def window(+tol: U32, now: Time.Instant, t: Int.I64) -> Result<&1, &1, Err, Unit>:
  result.from.pure(Unit, Pure.window(tol, now, t))

def id.check(+id: String) -> Result<&1, &1, Err, Unit>:
  result.from.pure(Unit, Pure.id.check(id))

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

def pad(+s: String) -> String:
  Pure.pad(s)

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

def std.sigs(xs: List<&2, String>) -> List<&2, String>:
  Pure.std.sigs(xs)

def std.check(+tol: U32, now: Time.Instant, +h: Map<&2, List<&2, String>>) -> Result<&1, &1, Err, String & String & List<&2, String>>:
  result.from.pure(String & String & List<&2, String>, Pure.std.check(tol, now, h))

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
  result.from.pure(String & String, Pure.sign.check(id, ts))

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
  Pure.stripe.t(s, r)

def stripe.v.push(s: String, r: List<&2, String> & List<&2, String>) -> List<&2, String> & List<&2, String>:
  Pure.stripe.v.push(s, r)

def stripe.v(m: Maybe<&2, String>, r: List<&2, String> & List<&2, String>) -> List<&2, String> & List<&2, String>:
  Pure.stripe.v(m, r)

def stripe.item(t: Maybe<&2, String>, v: Maybe<&2, String>, r: List<&2, String> & List<&2, String>) -> List<&2, String> & List<&2, String>:
  Pure.stripe.item(t, v, r)

def stripe.items(xs: List<&2, String>) -> List<&2, String> & List<&2, String>:
  Pure.stripe.items(xs)

def stripe.single(ts: List<&2, String>, vs: List<&2, String>) -> Result<&1, &1, Err, String & List<&2, String>>:
  result.from.pure(String & List<&2, String>, Pure.stripe.single(ts, vs))

def stripe.one(r: List<&2, String> & List<&2, String>) -> Result<&1, &1, Err, String & List<&2, String>>:
  result.from.pure(String & List<&2, String>, Pure.stripe.one(r))

def stripe.when(+tol: U32, now: Time.Instant, p: String & List<&2, String>) -> Result<&1, &1, Err, Unit & String & List<&2, String>>:
  result.from.pure(Unit & String & List<&2, String>, Pure.stripe.when(tol, now, p))

def stripe.check(+tol: U32, now: Time.Instant, +h: Map<&2, List<&2, String>>) -> Result<&1, &1, Err, Unit & String & List<&2, String>>:
  result.from.pure(Unit & String & List<&2, String>, Pure.stripe.check(tol, now, h))

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
  result.from.pure(Unit & String & List<&2, String>, Pure.github.check(h))

# Done when x-hub-signature-256 is sha256=<hex> of the body under a secret's UTF-8. GitHub signs no timestamp.
def github.verify(secrets: List<&2, String>, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Err, Unit>):
  run(Unit, github.check(headers), False{}, True{}, secrets, Bytes.slice(body, 0, 4294967295))

type SendErr is Data:
  SendSign{err: Err}
  SendNet{err: Hairpin.Err}

def send.result(x: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res>) ->
    Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>:
  (c, b, r) = x
  match r:
    case Fail{e}:
      (c, b, Fail{SendNet{e}})
    case Done{res}:
      (c, b, Done{res})

# A timeout, a refused connect, 408, 429, or any 5xx may clear.
def send.again(r: Result<&1, &1, HttpPure.Err, HttpPure.Res>) ->
    Result<&1, &1, HttpPure.Err, HttpPure.Res> & Maybe<&2, String>:
  match r:
    case Fail{e}:
      HttpPure.retry.judge(True{}, Fail{e})
    case Done{res}:
      HttpPure.Res{+status, +headers, body} = res
      +again = Bool.or(HttpPure.retry.status(status), U32.is_eq((status / 100 : U32), 5))
      (Done{HttpPure.Res{status, headers, body}}, Bool.pick(Maybe<&2, String>, again, Some{HttpPure.header(headers, "retry-after")}, None{}))

def send.judge(r: Result<&1, &1, HttpPure.Err, HttpPure.Res>) -> Result<&1, &1, HttpPure.Err, HttpPure.Res> & HairpinPure.Verdict:
  HairpinPure.judge.of(send.again(r))

# Receivers deduplicate on the event ID, so the POST is safe to repeat.
def send.signed(c: Hairpin.Client, b: Retry.Budget, +url: String, r: Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>>) ->
    IO(Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>):
  (body, signed) = r
  match signed:
    case Fail{e}:
      IO.pure(Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>, (c, b, Fail{SendSign{e}}))
    case Done{+h}:
      do IO<Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>>:
        enc : String <- Http.codings()
        x : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res> <-
          Hairpin.request.as(~send.judge, Hairpin.redirect(c, HttpPure.ModeManual{}), b, True{}, enc, "POST", url,
            HttpPure.set(h, "content-type", "application/json"), body)
        return send.result(x)

def send.at(c: Hairpin.Client, b: Retry.Budget, url: String, id: String, secret: String, body: Bytes.Bytes, now: Time.Instant) ->
    IO(Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>):
  match now:
    case Time.Instant{secs, nanos}:
      do IO<Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>>:
        signed : Bytes.Bytes & Result<&1, &1, Err, Map<&2, List<&2, String>>> <- sign(id, secs, body, secret)
        send.signed(c, b, url, signed)

# One event and one signature per delivery, inside a caller's retry layer. Every attempt takes from b and
# reuses this event ID, timestamp, headers, and raw body; the client's retry setting caps this delivery.
# The budget left comes back: pass it to the next delivery of the same operation.
def send.in(c: Hairpin.Client, b: Retry.Budget, url: String, id: String, secret: String, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>):
  do IO<Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>>:
    now : Time.Instant <- Http.clock.now()
    send.at(c, b, url, id, secret, body, now)

def send.drop(x: Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>) -> Hairpin.Client & Result<&1, &1, SendErr, HttpPure.Res>:
  (c, b, r) = x
  (c, r)

def send.budget(url: String, id: String, secret: String, body: Bytes.Bytes, y: Hairpin.Client & Retry.Budget) ->
    IO(Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res>):
  (c, b) = y
  send.in(c, b, url, id, secret, body)

# n extra attempts, on a budget of n + 1 and the client's deadline, with Hairpin's backoff. The client comes back with retry n.
def send.with(+n: U32, c: Hairpin.Client, url: String, id: String, secret: String, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, SendErr, HttpPure.Res>):
  do IO<Hairpin.Client & Result<&1, &1, SendErr, HttpPure.Res>>:
    y : Hairpin.Client & Retry.Budget <- Hairpin.budget(Hairpin.retry(c, n))
    x : Hairpin.Client & Retry.Budget & Result<&1, &1, SendErr, HttpPure.Res> <- send.budget(url, id, secret, body, y)
    return send.drop(x)

# Three extra attempts by default.
def send(c: Hairpin.Client, url: String, id: String, secret: String, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, SendErr, HttpPure.Res>):
  send.with(3, c, url, id, secret, body)
