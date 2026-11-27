import Base
import bend-kit-http@0.45.0.3/pure.bend as Pure
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-retry@0.3.0.0/retry.bend as Retry

def target.pick(none: Bool, b: String, ref: String) -> Maybe<&2, String>:
  match none:
    case True{}:
      Some{ref}
    case False{}:
      Pure.resolve(b, ref)

# ref against the base (RFC 3986 §5.2); with no base, ref as given. None when the base is not absolute.
def target(+b: String, ref: String) -> Maybe<&2, String>:
  target.pick(String.is_empty(b), b, ref)

def target.abs(m: Maybe<&2, String>) -> Maybe<&2, Url.Abs>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Url.absolute(s)

# The defaults under the request headers, names lowercased; a request header replaces a default of its name.
# Host, Connection, Content-Length, and Transfer-Encoding are the client's own, so both sides drop them.
def merge(defaults: Map<&2, List<&2, String>>, headers: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  Pure.req.put(Map.to_list(&2, List<&2, String>, headers), Pure.req.put(Map.to_list(&2, List<&2, String>, defaults), Pure.empty()))

def hint.ms(m: Maybe<&2, U32>) -> Maybe<&2, Nat>:
  match m:
    case None{}:
      None{}
    case Some{ms}:
      Some{U32.to_nat(ms)}

# A judge's verdict on one attempt. Ok: a success. Caller: the request is at fault (a 4xx), so it stops
# and the breaker does not count it. Target: the target failed in a way another try would repeat, so it
# stops and the breaker counts it. Again: another try may help; after is the Retry-After value, "" for none.
type Verdict is Data:
  VerdictOk{}
  VerdictCaller{}
  VerdictTarget{}
  VerdictAgain{after: String}

# Ok is Settled, Caller is Rejected, and Target is Failed. Again is Transient for an idempotent request, else Unsafe.
def outcome(+idem: Bool, v: Verdict, now: Time.Instant) -> Retry.Outcome:
  match v:
    case VerdictOk{}:
      Retry.Settled{}
    case VerdictCaller{}:
      Retry.Rejected{}
    case VerdictTarget{}:
      Retry.Failed{}
    case VerdictAgain{+after}:
      Bool.pick(Retry.Outcome, idem, Retry.Transient{hint.ms(Pure.retry.after(after, now))}, Retry.Unsafe{})

# A status that Pure.retry.judge does not retry: below 400 is Ok, a 4xx is Caller, and the rest is Target.
def judge.status(+s: U32) -> Verdict:
  Bool.pick(Verdict, U32.is_lt(s, 400), VerdictOk{}, Bool.pick(Verdict, U32.is_lt(s, 500), VerdictCaller{}, VerdictTarget{}))

def judge.settled(r: Result<&1, &1, Pure.Err, Pure.Res>) -> Result<&1, &1, Pure.Err, Pure.Res> & Verdict:
  match r:
    case Fail{e}:
      (Fail{e}, VerdictTarget{})
    case Done{res}:
      Pure.Res{+s, h, b} = res
      (Done{Pure.Res{s, h, b}}, judge.status(s))

def judge.of(x: Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, String>) -> Result<&1, &1, Pure.Err, Pure.Res> & Verdict:
  (r, m) = x
  match m:
    case Some{after}:
      (r, VerdictAgain{after})
    case None{}:
      judge.settled(r)

# The default judge: Pure.retry.judge, as if the request were idempotent, picks Again; outcome then applies idem.
def judge(r: Result<&1, &1, Pure.Err, Pure.Res>) -> Result<&1, &1, Pure.Err, Pure.Res> & Verdict:
  judge.of(Pure.retry.judge(True{}, r))

