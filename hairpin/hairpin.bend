# Hairpin: an HTTP client with a base URL, default headers, a pool, cookies, mTLS, redirects, and proven retries. Source: https://github.com/paymog/bend-kit/tree/main/hairpin
import Base
import bend-kit-http@0.23.0.1/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
# By hash, as http imports them: bend-kit-url@0.4.1.0, -json@0.5.0.1, -bytes@0.3.0.0.
import 0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend as Url
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ./retry.bend as Retry

# base: "" for none. headers: lowercase names. ms: the step timeout. policy: attempts, backoff, and deadline of each request.
type Opts is Data:
  Opts{base: String, headers: Map<&2, List<&2, String>>, ms: U32, mode: Http.Mode, policy: Retry.Policy, cert: Maybe<&2, Http.Cert>}

# breaker: the circuit breaker of every request on this client.
type Client is Type:
  Client{opts: Opts, pool: Http.Pool, jar: Maybe<&2, Http.Jar>, breaker: Retry.Breaker}

# ErrHttp: the last attempt failed. ErrDenied: no attempt started, for why.
type Err is Data:
  ErrHttp{error: Http.Err}
  ErrDenied{why: Retry.Deny}

# One attempt, the first included; backoff from 500 ms, doubled to at most 30 s; no deadline.
def policy() -> Retry.Policy:
  Retry.Policy{1n, 500n, 30000, None{}}

# A pool of up to cap idle sockets per origin, no base, no default headers, 30 s steps, follow redirects,
# no retries, and no circuit breaker.
def new.with(+cap: U32) -> Client:
  Client{Opts{"", Http.empty(), 30000, Http.ModeFollow{}, policy(), None{}}, Http.pool.new.with(cap), None{}, Retry.BreakerOff{}}

def new() -> Client:
  new.with(8)

def base(c: Client, url: String) -> Client:
  Client{Opts{b, h, ms, mode, p, cert}, pool, j, br} = c
  Client{Opts{url, h, ms, mode, p, cert}, pool, j, br}

# A default header. It replaces an earlier default of the same name; a request header of that name replaces it.
def header(c: Client, k: String, v: String) -> Client:
  Client{Opts{b, h, ms, mode, p, cert}, pool, j, br} = c
  Client{Opts{b, Http.set(h, String.to_lower(k), v), ms, mode, p, cert}, pool, j, br}

def timeout(c: Client, ms: U32) -> Client:
  Client{Opts{b, h, old, mode, p, cert}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, p, cert}, pool, j, br}

def redirect(c: Client, mode: Http.Mode) -> Client:
  Client{Opts{b, h, ms, old, p, cert}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, p, cert}, pool, j, br}

# Up to n retries after the first attempt: n + 1 attempts in all.
def retry(c: Client, n: U32) -> Client:
  Client{Opts{b, h, ms, mode, Retry.Policy{old, base, cap, d}, cert}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, Retry.Policy{1n+U32.to_nat(n), base, cap, d}, cert}, pool, j, br}

# No attempt of a request starts ms or more after the request starts.
def deadline(c: Client, ms: U32) -> Client:
  Client{Opts{b, h, t, mode, Retry.Policy{a, base, cap, old}, cert}, pool, j, br} = c
  Client{Opts{b, h, t, mode, Retry.Policy{a, base, cap, Some{U32.to_nat(ms)}}, cert}, pool, j, br}

# A circuit breaker in front of every request, starting closed.
def circuit(c: Client, circ: Retry.Circuit) -> Client:
  Client{o, pool, j, old} = c
  Client{o, pool, j, Retry.Breaker.new(circ)}

# The breaker, for inspection.
def breaker.of(c: Client) -> Client & Retry.Breaker:
  Client{o, pool, j, +br} = c
  (Client{o, pool, j, br}, br)

# Paths to a PEM client chain and its private key, presented to every HTTPS origin.
def cert(c: Client, chain: String, key: String) -> Client:
  Client{Opts{b, h, ms, mode, p, old}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, p, Some{Http.Cert{chain, key}}}, pool, j, br}

# Every request stores and sends cookies through jar. Its clock moves to Time.now() before each try.
def jar(c: Client, jar: Http.Jar) -> Client:
  Client{o, pool, old, br} = c
  Client{o, pool, Some{jar}, br}

# The jar, if the client has one.
def jar.of(c: Client) -> Client & Maybe<&2, Http.Jar>:
  Client{o, pool, +j, br} = c
  (Client{o, pool, j, br}, j)

def close(c: Client) -> IO(Unit):
  Client{o, pool, j, br} = c
  Http.pool.close(pool)

def ms.of(r: U32 & U32 & U32) -> Nat:
  (hi, lo, ns) = r
  Nat.add(Nat.mul(Nat.add(Nat.mul(U32.to_nat(hi), 1n+4294967295n), U32.to_nat(lo)), 1000n), U32.to_nat((ns / 1000000 : U32)))

# Milliseconds on the monotonic clock that Retry budgets and breakers use.
def now.ms() -> IO(Nat):
  do IO<Nat>:
    r : U32 & U32 & U32 <- Time.mono.raw()
    return ms.of(r)

def target.pick(none: Bool, b: String, ref: String) -> Maybe<&2, String>:
  match none:
    case True{}:
      Some{ref}
    case False{}:
      Http.resolve(b, ref)

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
  Http.req.put(Map.to_list(&2, List<&2, String>, headers), Http.req.put(Map.to_list(&2, List<&2, String>, defaults), Http.empty()))

def jar.now(j: Maybe<&2, Http.Jar>) -> IO(Maybe<&2, Http.Jar>):
  match j:
    case None{}:
      IO.pure(Maybe<&2, Http.Jar>, None{})
    case Some{jar}:
      do IO<Maybe<&2, Http.Jar>>:
        now : Time.Instant <- Time.now()
        return Some{Http.jar.at(jar, now)}

def once.final(+enc: String, x: Http.Pool & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, Http.Jar>) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>):
  (p, r, j) = x
  do IO<Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>>:
    d : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch.final(enc, r)
    return (p, j, d)

# One try: the redirect loop on the pool, with the jar and the certificate, then the body decoded.
def once(+ms: U32, +mode: Http.Mode, +cert: Maybe<&2, Http.Cert>, +enc: String, p: Http.Pool, j: Maybe<&2, Http.Jar>,
    +method: String, +u: Maybe<&2, Url.Abs>, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>):
  do IO<Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>>:
    now : Maybe<&2, Http.Jar> <- jar.now(j)
    x : Http.Pool & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, Http.Jar> <-
      Http.pool.hops(mode, ms, Http.Hops{p, Http.fetch.start(method, headers, body, u, enc), cert, now})
    once.final(enc, x)

def hint.ms(m: Maybe<&2, U32>) -> Maybe<&2, Nat>:
  match m:
    case None{}:
      None{}
    case Some{ms}:
      Some{U32.to_nat(ms)}

# m is Http.retry.judge's verdict for an idempotent request: Some{Retry-After} when another try may help.
# A non-idempotent request with that verdict is Unsafe: the breaker counts it, but it never repeats.
def outcome(+idem: Bool, m: Maybe<&2, String>, now: Time.Instant) -> Retry.Outcome:
  match m:
    case None{}:
      Retry.Settled{}
    case Some{+v}:
      Bool.pick(Retry.Outcome, idem, Retry.Transient{hint.ms(Http.retry.after(v, now))}, Retry.Unsafe{})

def lift(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Err, Http.Res>:
  match r:
    case Fail{e}:
      Fail{ErrHttp{e}}
    case Done{res}:
      Done{res}

# The live state of one request between attempts. last: the result of the last attempt, None before the first.
type Step is Type:
  Step{pool: Http.Pool, jar: Maybe<&2, Http.Jar>, breaker: Retry.Breaker, budget: Retry.Budget, body: Bytes.Bytes,
    last: Maybe<&1, Result<&1, &1, Err, Http.Res>>, plan: Retry.Plan}

# The clock, read only when a decision depends on it; 0 otherwise, which no such decision reads.
def clock(need: Bool) -> IO(Nat):
  match need:
    case True{}:
      now.ms()
    case False{}:
      IO.pure(Nat, 0n)

def breaker.on(br: Retry.Breaker) -> Bool:
  match br:
    case Retry.BreakerOff{}:
      False{}
    case Retry.BreakerOn{c, s}:
      True{}

def transient(o: Retry.Outcome) -> Bool:
  match o:
    case Retry.Transient{after}:
      True{}
    case Retry.Settled{}:
      False{}
    case Retry.Unsafe{}:
      False{}

def some(m: Maybe<&2, Nat>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{t}:
      True{}

def deadline.some(b: Retry.Budget) -> Bool:
  Retry.Budget{l, d} = b
  some(d)

# The wall clock dates a Retry-After, so it is read only for a transient failure.
def outcome.io(+idem: Bool, m: Maybe<&2, String>) -> IO(Retry.Outcome):
  match m:
    case None{}:
      IO.pure(Retry.Outcome, Retry.Settled{})
    case Some{v}:
      do IO<Retry.Outcome>:
        wall : Time.Instant <- Time.now()
        return outcome(idem, Some{v}, wall)

# Jitter for the backoff, drawn only when a retry may follow.
def jitter.io(need: Bool) -> IO(Nat):
  match need:
    case True{}:
      do IO<Nat>:
        rnd : Result<&1, &1, U32 & String, U32> <- IO.random_u32()
        return U32.to_nat(Http.retry.jitter(rnd))
    case False{}:
      IO.pure(Nat, 0n)

def settle.at(+now: Nat, +rnd: Nat, +p: Retry.Policy, +n: Nat, +o: Retry.Outcome, br: Retry.Breaker, +b: Retry.Budget,
    body: Bytes.Bytes, pool: Http.Pool, jar: Maybe<&2, Http.Jar>, r: Result<&1, &1, Http.Err, Http.Res>) -> Step:
  Step{pool, jar, Retry.Breaker.done(br, now, Retry.failed(o)), b, body, Some{lift(r)}, Retry.plan(o, p, b, n, now, rnd)}

# The attempt has ended: tell the breaker, and plan the next step.
def settle.outcome(+p: Retry.Policy, +n: Nat, +o: Retry.Outcome, +br: Retry.Breaker, b: Retry.Budget, body: Bytes.Bytes,
    pool: Http.Pool, jar: Maybe<&2, Http.Jar>, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Step):
  do IO<Step>:
    now : Nat <- clock(Bool.or(breaker.on(br), transient(o)))
    rnd : Nat <- jitter.io(transient(o))
    return settle.at(now, rnd, p, n, o, br, b, body, pool, jar, r)

def settle.judged(+p: Retry.Policy, +idem: Bool, +n: Nat, br: Retry.Breaker, b: Retry.Budget, body: Bytes.Bytes,
    pool: Http.Pool, jar: Maybe<&2, Http.Jar>, j: Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) -> IO(Step):
  (r, m) = j
  do IO<Step>:
    o : Retry.Outcome <- outcome.io(idem, m)
    settle.outcome(p, n, o, br, b, body, pool, jar, r)

# The default judge: Http.retry.judge, as if the request were idempotent; outcome then applies idem.
def judge(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  Http.retry.judge(True{}, r)

def settle(~judge: Result<&1, &1, Http.Err, Http.Res> -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>,
    +p: Retry.Policy, +idem: Bool, +n: Nat, br: Retry.Breaker, b: Retry.Budget, body: Bytes.Bytes,
    x: Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>) -> IO(Step):
  (pool, jar, r) = x
  settle.judged(p, idem, n, br, b, body, pool, jar, judge(r))

def attempt.run(~judge: Result<&1, &1, Http.Err, Http.Res> -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>,
    +o: Opts, +enc: String, +idem: Bool, +method: String, +u: Maybe<&2, Url.Abs>,
    +headers: Map<&2, List<&2, String>>, +n: Nat, pool: Http.Pool, jar: Maybe<&2, Http.Jar>, br: Retry.Breaker,
    b: Retry.Budget, r: Bytes.Bytes & Bytes.Bytes) -> IO(Step):
  Opts{base, h, +ms, +mode, +p, +cert} = o
  (body, spare) = r
  do IO<Step>:
    x : Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res> <- once(ms, mode, cert, enc, pool, jar, method, u, headers, spare)
    settle(~judge, p, idem, n, br, b, body, x)

def denied(why: Retry.Deny, last: Maybe<&1, Result<&1, &1, Err, Http.Res>>) -> Maybe<&1, Result<&1, &1, Err, Http.Res>>:
  match last:
    case None{}:
      Some{Fail{ErrDenied{why}}}
    case Some{r}:
      Some{r}

def attempt.gate(~judge: Result<&1, &1, Http.Err, Http.Res> -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>,
    x: Retry.Breaker & Retry.Budget & Retry.Gate, +o: Opts, +enc: String, +idem: Bool, +method: String,
    +u: Maybe<&2, Url.Abs>, +headers: Map<&2, List<&2, String>>, +n: Nat, pool: Http.Pool, jar: Maybe<&2, Http.Jar>,
    body: Bytes.Bytes, last: Maybe<&1, Result<&1, &1, Err, Http.Res>>) -> IO(Step):
  (br, b, g) = x
  match g:
    case Retry.GateNo{why}:
      IO.pure(Step, Step{pool, jar, br, b, body, denied(why, last), Retry.PlanStop{}})
    case Retry.GateGo{}:
      attempt.run(~judge, o, enc, idem, method, u, headers, n, pool, jar, br, b, Bytes.slice(body, 0, 4294967295))

# Ask the gate; when it admits, make attempt n (0 first) of this layer. With no deadline and no breaker,
# admission does not read the clock.
def attempt(~judge: Result<&1, &1, Http.Err, Http.Res> -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>,
    +o: Opts, +enc: String, +idem: Bool, +method: String, +u: Maybe<&2, Url.Abs>,
    +headers: Map<&2, List<&2, String>>, +n: Nat, s: Step) -> IO(Step):
  Step{pool, jar, +br, +b, body, last, plan} = s
  do IO<Step>:
    now : Nat <- clock(Bool.or(breaker.on(br), deadline.some(b)))
    attempt.gate(~judge, Retry.admit(br, b, now), o, enc, idem, method, u, headers, n, pool, jar, body, last)

def pause(ms: Nat) -> IO(Unit):
  match ms:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+k:
      IO.sleep(U32.from_nat(1n+k))

# left: attempts this layer may still make. n: attempts made so far. Each turn follows the plan of the last step.
def go(~judge: Result<&1, &1, Http.Err, Http.Res> -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>,
    left: Nat, +n: Nat, +o: Opts, +enc: String, +idem: Bool, +method: String, +u: Maybe<&2, Url.Abs>,
    +headers: Map<&2, List<&2, String>>, s: Step) -> IO(Step):
  match left:
    case 0n:
      IO.pure(Step, s)
    case 1n+rest:
      Step{pool, jar, br, b, body, last, plan} = s
      match plan:
        case Retry.PlanStop{}:
          IO.pure(Step, Step{pool, jar, br, b, body, last, Retry.PlanStop{}})
        case Retry.PlanWait{ms}:
          do IO<Step>:
            pause(ms)
            next : Step <- attempt(~judge, o, enc, idem, method, u, headers, n, Step{pool, jar, br, b, body, last, Retry.PlanStop{}})
            go(~judge, rest, 1n+n, o, enc, idem, method, u, headers, next)

def result.of(m: Maybe<&1, Result<&1, &1, Err, Http.Res>>) -> Result<&1, &1, Err, Http.Res>:
  match m:
    case None{}:
      Fail{ErrDenied{Retry.DenySpent{}}}
    case Some{r}:
      r

def request.done(+o: Opts, s: Step) -> Client & Retry.Budget & Result<&1, &1, Err, Http.Res>:
  Step{pool, jar, br, b, body, last, plan} = s
  (Client{o, pool, jar, br}, b, result.of(last))

def attempts(p: Retry.Policy) -> Nat:
  Retry.Policy{a, base, cap, d} = p
  a

# The budget of one plain request: the policy's attempts, and its deadline from now. The clock is read only for a deadline.
def budget(c: Client) -> IO(Client & Retry.Budget):
  Client{+o, pool, jar, br} = c
  Opts{base, h, ms, mode, Retry.Policy{+a, bs, cap, +d}, cert} = o
  do IO<Client & Retry.Budget>:
    now : Nat <- clock(some(d))
    return (Client{o, pool, jar, br}, Retry.Budget.new(a, now, d))

# One request inside a caller's retry layer, with every choice explicit. Every attempt takes from b, the
# caller's shared budget, and obeys its deadline; the client's own policy caps the attempts of this call.
# The budget left comes back beside the result: pass it to the next call, so nested layers never reset or
# multiply it. The client's own deadline does not apply here; b's does.
# judge: Some{Retry-After} when another attempt may help. idem: the request is safe to repeat, so a judged
# failure is retried; else the breaker counts it and it never repeats. enc: the Accept-Encoding codings.
def request.as(~judge: Result<&1, &1, Http.Err, Http.Res> -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>,
    c: Client, b: Retry.Budget, +idem: Bool, +enc: String, +method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Client & Retry.Budget & Result<&1, &1, Err, Http.Res>):
  Client{+o, pool, jar, br} = c
  Opts{+base, +h, ms, mode, +p, cert} = o
  +u = target.abs(target(base, url))
  +hs = merge(h, headers)
  do IO<Client & Retry.Budget & Result<&1, &1, Err, Http.Res>>:
    s : Step <- go(~judge, attempts(p), 0n, o, enc, idem, method, u, hs, Step{pool, jar, br, b, body, None{}, Retry.PlanWait{0n}})
    return request.done(o, s)

# request.as with judge, the idempotency of method, and every coding Http decodes.
def request.in(c: Client, b: Retry.Budget, +method: String, url: String, headers: Map<&2, List<&2, String>>,
    body: Bytes.Bytes) -> IO(Client & Retry.Budget & Result<&1, &1, Err, Http.Res>):
  do IO<Client & Retry.Budget & Result<&1, &1, Err, Http.Res>>:
    enc : String <- Http.codings()
    request.as(~judge, c, b, Http.pool.idempotent(method), enc, method, url, headers, body)

def request.drop(x: Client & Retry.Budget & Result<&1, &1, Err, Http.Res>) -> Client & Result<&1, &1, Err, Http.Res>:
  (c, b, r) = x
  (c, r)

def request.budget(+method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes,
    x: Client & Retry.Budget) -> IO(Client & Retry.Budget & Result<&1, &1, Err, Http.Res>):
  (c, b) = x
  request.in(c, b, method, url, headers, body)

# url resolves against the base; headers go over the defaults. Redirects follow the client's mode, at most 20.
# Each request gets a fresh budget from budget(c). Before each attempt the deadline, the
# budget, and the breaker must admit it. GET, HEAD, OPTIONS, TRACE, PUT, and DELETE try again after a connect
# error, a timeout, or 408, 429, 500, 502, 503, or 504, as Http.retry.judge says, on the same pool.
# When the attempts run out, the last result comes back; when none started, ErrDenied says why.
def request(c: Client, +method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Client & Result<&1, &1, Err, Http.Res>):
  do IO<Client & Result<&1, &1, Err, Http.Res>>:
    y : Client & Retry.Budget <- budget(c)
    x : Client & Retry.Budget & Result<&1, &1, Err, Http.Res> <- request.budget(method, url, headers, body, y)
    return request.drop(x)

def get(c: Client, url: String) -> IO(Client & Result<&1, &1, Err, Http.Res>):
  request(c, "GET", url, Http.empty(), Bytes.new(0))

# POST v as compact JSON, with content-type: application/json.
def post.json(c: Client, url: String, v: Json.Val) -> IO(Client & Result<&1, &1, Err, Http.Res>):
  request(c, "POST", url, Http.set(Http.empty(), "content-type", "application/json"), Json.encode.bytes(v))
