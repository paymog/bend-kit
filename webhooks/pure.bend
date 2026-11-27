# Pure webhook headers, timestamps, and signature framing.
import Base
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

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

# '=' up to a multiple of four chars.
def pad(+s: String) -> String:
  +r = (String.length(s) % 4n : Nat)
  s ++ Bool.pick(String, Nat.is_eq(r, 2n), "==", Bool.pick(String, Nat.is_eq(r, 3n), "=", ""))

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

def sign.check(+id: String, +ts: Int.I64) -> Result<&1, &1, Err, String & String>:
  do Result<&1, &1, Err, String & String>:
    u : Unit <- id.check(id)
    w : Unit <- Bool.pick(Result<&1, &1, Err, Unit>, Int.I64.is_neg(ts), Fail{BadTimestamp{}}, Done{Unit{}})
    return (id, Int.I64.show(ts))

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

def github.check(+h: Map<&2, List<&2, String>>) -> Result<&1, &1, Err, Unit & String & List<&2, String>>:
  do Result<&1, &1, Err, Unit & String & List<&2, String>>:
    sig : String <- need("x-hub-signature-256", field(h, "x-hub-signature-256"))
    return (Unit{}, "", push(strip("sha256=", sig), Nil{}))

