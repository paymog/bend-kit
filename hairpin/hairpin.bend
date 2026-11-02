# Hairpin: an HTTP client with a base URL, default headers, a pool, cookies, mTLS, redirects, and proven retries. Source: https://github.com/paymog/bend-kit/tree/main/hairpin
import Base
import bend-kit-http@0.38.1.1/http.bend as Http
import bend-kit-time@0.3.0.0/time.bend as Time
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-json@0.7.0.0/json.bend as Json
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-retry@0.3.0.0/retry.bend as Retry

# base: "" for none. headers: lowercase names. ms: the step timeout. policy: attempts, backoff, and deadline of each request.
# ca: a PEM CA file to trust; "" trusts the default store.
type Opts is Data:
  Opts{base: String, headers: Map<&2, List<&2, String>>, ms: U32, mode: Http.Mode, policy: Retry.Policy, cert: Maybe<&2, Http.Cert>, ca: String}

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
  Client{Opts{"", Http.empty(), 30000, Http.ModeFollow{}, policy(), None{}, ""}, Http.pool.new.with(cap), None{}, Retry.BreakerOff{}}

def new() -> Client:
  new.with(8)

def base(c: Client, url: String) -> Client:
  Client{Opts{b, h, ms, mode, p, cert, ca}, pool, j, br} = c
  Client{Opts{url, h, ms, mode, p, cert, ca}, pool, j, br}

# A default header. It replaces an earlier default of the same name; a request header of that name replaces it.
def header(c: Client, k: String, v: String) -> Client:
  Client{Opts{b, h, ms, mode, p, cert, ca}, pool, j, br} = c
  Client{Opts{b, Http.set(h, String.to_lower(k), v), ms, mode, p, cert, ca}, pool, j, br}

def timeout(c: Client, ms: U32) -> Client:
  Client{Opts{b, h, old, mode, p, cert, ca}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, p, cert, ca}, pool, j, br}

def redirect(c: Client, mode: Http.Mode) -> Client:
  Client{Opts{b, h, ms, old, p, cert, ca}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, p, cert, ca}, pool, j, br}

# Up to n retries after the first attempt: n + 1 attempts in all.
def retry(c: Client, n: U32) -> Client:
  Client{Opts{b, h, ms, mode, Retry.Policy{old, base, cap, d}, cert, ca}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, Retry.Policy{1n+U32.to_nat(n), base, cap, d}, cert, ca}, pool, j, br}

# No attempt of a request starts ms or more after the request starts.
def deadline(c: Client, ms: U32) -> Client:
  Client{Opts{b, h, t, mode, Retry.Policy{a, base, cap, old}, cert, ca}, pool, j, br} = c
  Client{Opts{b, h, t, mode, Retry.Policy{a, base, cap, Some{U32.to_nat(ms)}}, cert, ca}, pool, j, br}

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
  Client{Opts{b, h, ms, mode, p, old, ca}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, p, Some{Http.Cert{chain, key}}, ca}, pool, j, br}

# Path to a PEM CA file, trusted in place of the default store. Like the certificate, it follows same-origin redirects only.
def ca(c: Client, path: String) -> Client:
  Client{Opts{b, h, ms, mode, p, cert, old}, pool, j, br} = c
  Client{Opts{b, h, ms, mode, p, cert, path}, pool, j, br}

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

# Close a stream from open.as. A body read to its end gives its connection to the client's pool.
def stream.close(c: Client, st: Http.Stream) -> IO(Client):
  Client{o, pool, j, br} = c
  do IO<Client>:
    p : Http.Pool <- Http.pool.stream.close(pool, st)
    return Client{o, p, j, br}

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

# One try: the redirect loop on the pool, with the jar, the certificate, and the CA file, then the body decoded.
def once(+ms: U32, +mode: Http.Mode, +cert: Maybe<&2, Http.Cert>, +ca: String, +enc: String, p: Http.Pool, j: Maybe<&2, Http.Jar>,
    +method: String, +u: Maybe<&2, Url.Abs>, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>):
  do IO<Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>>:
    now : Maybe<&2, Http.Jar> <- jar.now(j)
    x : Http.Pool & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, Http.Jar> <-
      Http.pool.hops(mode, ms, Http.Hops{p, Http.fetch.start(method, headers, body, u, enc), cert, now, ca})
    once.final(enc, x)

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
      Bool.pick(Retry.Outcome, idem, Retry.Transient{hint.ms(Http.retry.after(after, now))}, Retry.Unsafe{})

def lift(-R: Type, r: Result<&1, &1, Http.Err, R>) -> Result<&1, &1, Err, R>:
  match r:
    case Fail{e}:
      Fail{ErrHttp{e}}
    case Done{res}:
      Done{res}

# The live state of one request between attempts. R: a response or a stream. last: the result of the last
# attempt, None before the first.
type Step<-R: Type> is Type:
  Step{pool: Http.Pool, jar: Maybe<&2, Http.Jar>, breaker: Retry.Breaker, budget: Retry.Budget, body: Bytes.Bytes,
    last: Maybe<&1, Result<&1, &1, Err, R>>, plan: Retry.Plan}

# The clock, read only when a decision depends on it; 0 otherwise, which no such decision reads.
def clock(need: Bool) -> IO(Nat):
  match need:
    case True{}:
      Time.mono.ms()
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
    case Retry.Failed{}:
      False{}
    case Retry.Rejected{}:
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

# The wall clock dates a Retry-After, so it is read only for Again.
def outcome.io(+idem: Bool, v: Verdict) -> IO(Retry.Outcome):
  match v:
    case VerdictAgain{after}:
      do IO<Retry.Outcome>:
        wall : Time.Instant <- Time.now()
        return outcome(idem, VerdictAgain{after}, wall)
    case VerdictOk{}:
      IO.pure(Retry.Outcome, Retry.Settled{})
    case VerdictCaller{}:
      IO.pure(Retry.Outcome, Retry.Rejected{})
    case VerdictTarget{}:
      IO.pure(Retry.Outcome, Retry.Failed{})

# Jitter for the backoff, drawn only when a retry may follow.
def jitter.io(need: Bool) -> IO(Nat):
  match need:
    case True{}:
      do IO<Nat>:
        rnd : Result<&1, &1, U32 & String, U32> <- IO.random_u32()
        return U32.to_nat(Http.retry.jitter(rnd))
    case False{}:
      IO.pure(Nat, 0n)

def settle.at(-R: Type, +now: Nat, +rnd: Nat, +p: Retry.Policy, +n: Nat, +o: Retry.Outcome, br: Retry.Breaker, +b: Retry.Budget,
    body: Bytes.Bytes, pool: Http.Pool, jar: Maybe<&2, Http.Jar>, r: Result<&1, &1, Http.Err, R>) -> Step<R>:
  Step{pool, jar, Retry.Breaker.done(br, now, Retry.failed(o)), b, body, Some{lift(R, r)}, Retry.plan(o, p, b, n, now, rnd)}

# The attempt has ended: tell the breaker, and plan the next step.
def settle.outcome(-R: Type, +p: Retry.Policy, +n: Nat, +o: Retry.Outcome, +br: Retry.Breaker, b: Retry.Budget, body: Bytes.Bytes,
    pool: Http.Pool, jar: Maybe<&2, Http.Jar>, r: Result<&1, &1, Http.Err, R>) -> IO(Step<R>):
  do IO<Step<R>>:
    now : Nat <- clock(Bool.or(breaker.on(br), transient(o)))
    rnd : Nat <- jitter.io(transient(o))
    return settle.at(R, now, rnd, p, n, o, br, b, body, pool, jar, r)

def settle.judged(-R: Type, +p: Retry.Policy, +idem: Bool, +n: Nat, br: Retry.Breaker, b: Retry.Budget, body: Bytes.Bytes,
    pool: Http.Pool, jar: Maybe<&2, Http.Jar>, j: Result<&1, &1, Http.Err, R> & Verdict) -> IO(Step<R>):
  (r, +v) = j
  do IO<Step<R>>:
    o : Retry.Outcome <- outcome.io(idem, v)
    settle.outcome(R, p, n, o, br, b, body, pool, jar, r)

# A status that Http.retry.judge does not retry: below 400 is Ok, a 4xx is Caller, and the rest is Target.
def judge.status(+s: U32) -> Verdict:
  Bool.pick(Verdict, U32.is_lt(s, 400), VerdictOk{}, Bool.pick(Verdict, U32.is_lt(s, 500), VerdictCaller{}, VerdictTarget{}))

def judge.settled(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Http.Err, Http.Res> & Verdict:
  match r:
    case Fail{e}:
      (Fail{e}, VerdictTarget{})
    case Done{res}:
      Http.Res{+s, h, b} = res
      (Done{Http.Res{s, h, b}}, judge.status(s))

def judge.of(x: Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) -> Result<&1, &1, Http.Err, Http.Res> & Verdict:
  (r, m) = x
  match m:
    case Some{after}:
      (r, VerdictAgain{after})
    case None{}:
      judge.settled(r)

# The default judge: Http.retry.judge, as if the request were idempotent, picks Again; outcome then applies idem.
def judge(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Http.Err, Http.Res> & Verdict:
  judge.of(Http.retry.judge(True{}, r))

def settle(~R: Type, ~judge: Result<&1, &1, Http.Err, R> -> Result<&1, &1, Http.Err, R> & Verdict,
    +p: Retry.Policy, +idem: Bool, +n: Nat, br: Retry.Breaker, b: Retry.Budget, body: Bytes.Bytes,
    x: Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, R>) -> IO(Step<R>):
  (pool, jar, r) = x
  settle.judged(R, p, idem, n, br, b, body, pool, jar, judge(r))

# The inputs of one attempt. u: the target, None when it is not absolute. headers: the merged headers.
type Call is Data:
  Call{enc: String, method: String, u: Maybe<&2, Url.Abs>, headers: Map<&2, List<&2, String>>}

# One attempt that reads a whole response: the redirect loop on the pool, with the jar and the certificate.
def try.res(o: Opts, call: Call, pool: Http.Pool, jar: Maybe<&2, Http.Jar>, body: Bytes.Bytes) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>):
  Opts{base, h, +ms, +mode, p, +cert, +ca} = o
  Call{+enc, +method, +u, +headers} = call
  once(ms, mode, cert, ca, enc, pool, jar, method, u, headers, body)

# One attempt that opens a stream on the pool: the redirect loop with the mode, the jar, and the certificate,
# then the body decoded by enc.
def try.stream(o: Opts, call: Call, pool: Http.Pool, jar: Maybe<&2, Http.Jar>, body: Bytes.Bytes) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream>):
  Opts{base, h, +ms, mode, p, cert, ca} = o
  Call{+enc, method, u, headers} = call
  do IO<Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream>>:
    now : Maybe<&2, Http.Jar> <- jar.now(jar)
    r : Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream> <-
      Http.stream.hops(mode, ms, (pool, Http.StreamHops{Http.stream.start(method, Http.accept.enc(headers, enc), body, u), cert, now, ca}))
    Http.stream.init.pool(enc, r)

def close.res(r: Http.Res) -> IO(Unit):
  IO.pure(Unit, Unit{})

def close.last(~R: Type, ~close: R -> IO(Unit), last: Maybe<&1, Result<&1, &1, Err, R>>) -> IO(Unit):
  match last:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{r}:
      match r:
        case Fail{e}:
          IO.pure(Unit, Unit{})
        case Done{x}:
          close(x)

def attempt.run(~R: Type, ~judge: Result<&1, &1, Http.Err, R> -> Result<&1, &1, Http.Err, R> & Verdict,
    ~try: Opts -> Call -> Http.Pool -> Maybe<&2, Http.Jar> -> Bytes.Bytes -> IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, R>),
    +o: Opts, +call: Call, +idem: Bool, +n: Nat, pool: Http.Pool, jar: Maybe<&2, Http.Jar>, br: Retry.Breaker,
    b: Retry.Budget, r: Bytes.Bytes & Bytes.Bytes) -> IO(Step<R>):
  Opts{base, h, ms, mode, +p, cert, ca} = o
  (body, spare) = r
  do IO<Step<R>>:
    x : Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, R> <- try(o, call, pool, jar, spare)
    settle(~R, ~judge, p, idem, n, br, b, body, x)

def denied(-R: Type, why: Retry.Deny, last: Maybe<&1, Result<&1, &1, Err, R>>) -> Maybe<&1, Result<&1, &1, Err, R>>:
  match last:
    case None{}:
      Some{Fail{ErrDenied{why}}}
    case Some{r}:
      Some{r}

# A refused stream closes only when the next attempt is admitted, so a denied attempt still returns it.
def attempt.gate(~R: Type, ~judge: Result<&1, &1, Http.Err, R> -> Result<&1, &1, Http.Err, R> & Verdict,
    ~try: Opts -> Call -> Http.Pool -> Maybe<&2, Http.Jar> -> Bytes.Bytes -> IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, R>),
    ~close: R -> IO(Unit),
    x: Retry.Breaker & Retry.Budget & Retry.Gate, +o: Opts, +call: Call, +idem: Bool, +n: Nat, pool: Http.Pool,
    jar: Maybe<&2, Http.Jar>, body: Bytes.Bytes, last: Maybe<&1, Result<&1, &1, Err, R>>) -> IO(Step<R>):
  (br, b, g) = x
  match g:
    case Retry.GateNo{why}:
      IO.pure(Step<R>, Step{pool, jar, br, b, body, denied(R, why, last), Retry.PlanStop{}})
    case Retry.GateGo{}:
      do IO<Step<R>>:
        close.last(~R, ~close, last)
        attempt.run(~R, ~judge, ~try, o, call, idem, n, pool, jar, br, b, Bytes.slice(body, 0, 4294967295))

# Ask the gate; when it admits, make attempt n (0 first) of this layer. With no deadline and no breaker,
# admission does not read the clock.
def attempt(~R: Type, ~judge: Result<&1, &1, Http.Err, R> -> Result<&1, &1, Http.Err, R> & Verdict,
    ~try: Opts -> Call -> Http.Pool -> Maybe<&2, Http.Jar> -> Bytes.Bytes -> IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, R>),
    ~close: R -> IO(Unit),
    +o: Opts, +call: Call, +idem: Bool, +n: Nat, s: Step<R>) -> IO(Step<R>):
  Step{pool, jar, +br, +b, body, last, plan} = s
  do IO<Step<R>>:
    now : Nat <- clock(Bool.or(breaker.on(br), deadline.some(b)))
    attempt.gate(~R, ~judge, ~try, ~close, Retry.admit(br, b, now), o, call, idem, n, pool, jar, body, last)

def pause(ms: Nat) -> IO(Unit):
  match ms:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+k:
      IO.sleep(U32.from_nat(1n+k))

# left: attempts this layer may still make. n: attempts made so far. Each turn follows the plan of the last step.
def go(~R: Type, ~judge: Result<&1, &1, Http.Err, R> -> Result<&1, &1, Http.Err, R> & Verdict,
    ~try: Opts -> Call -> Http.Pool -> Maybe<&2, Http.Jar> -> Bytes.Bytes -> IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, R>),
    ~close: R -> IO(Unit),
    left: Nat, +n: Nat, +o: Opts, +call: Call, +idem: Bool, s: Step<R>) -> IO(Step<R>):
  match left:
    case 0n:
      IO.pure(Step<R>, s)
    case 1n+rest:
      Step{pool, jar, br, b, body, last, plan} = s
      match plan:
        case Retry.PlanStop{}:
          IO.pure(Step<R>, Step{pool, jar, br, b, body, last, Retry.PlanStop{}})
        case Retry.PlanWait{ms}:
          do IO<Step<R>>:
            pause(ms)
            next : Step<R> <- attempt(~R, ~judge, ~try, ~close, o, call, idem, n, Step{pool, jar, br, b, body, last, Retry.PlanStop{}})
            go(~R, ~judge, ~try, ~close, rest, 1n+n, o, call, idem, next)

def result.of(-R: Type, m: Maybe<&1, Result<&1, &1, Err, R>>) -> Result<&1, &1, Err, R>:
  match m:
    case None{}:
      Fail{ErrDenied{Retry.DenySpent{}}}
    case Some{r}:
      r

def request.done(-R: Type, +o: Opts, s: Step<R>) -> Client & Retry.Budget & Result<&1, &1, Err, R>:
  Step{pool, jar, br, b, body, last, plan} = s
  (Client{o, pool, jar, br}, b, result.of(R, last))

def attempts(p: Retry.Policy) -> Nat:
  Retry.Policy{a, base, cap, d} = p
  a

# The budget of one plain request: the policy's attempts, and its deadline from now. The clock is read only for a deadline.
def budget(c: Client) -> IO(Client & Retry.Budget):
  Client{+o, pool, jar, br} = c
  Opts{base, h, ms, mode, Retry.Policy{+a, bs, cap, +d}, cert, ca} = o
  do IO<Client & Retry.Budget>:
    now : Nat <- clock(some(d))
    return (Client{o, pool, jar, br}, Retry.Budget.new(a, now, d))

def run(~R: Type, ~judge: Result<&1, &1, Http.Err, R> -> Result<&1, &1, Http.Err, R> & Verdict,
    ~try: Opts -> Call -> Http.Pool -> Maybe<&2, Http.Jar> -> Bytes.Bytes -> IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, R>),
    ~close: R -> IO(Unit),
    c: Client, b: Retry.Budget, +idem: Bool, enc: String, method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Client & Retry.Budget & Result<&1, &1, Err, R>):
  Client{+o, pool, jar, br} = c
  Opts{+base, +h, ms, mode, +p, cert, ca} = o
  +call = {Call{enc, method, target.abs(target(base, url)), merge(h, headers)} : Call}
  do IO<Client & Retry.Budget & Result<&1, &1, Err, R>>:
    s : Step<R> <- go(~R, ~judge, ~try, ~close, attempts(p), 0n, o, call, idem, Step{pool, jar, br, b, body, None{}, Retry.PlanWait{0n}})
    return request.done(R, o, s)

# One request inside a caller's retry layer, with every choice explicit. Every attempt takes from b, the
# caller's shared budget, and obeys its deadline; the client's own policy caps the attempts of this call.
# The budget left comes back beside the result: pass it to the next call, so nested layers never reset or
# multiply it. The client's own deadline does not apply here; b's does.
# judge: the Verdict on each attempt; Hairpin.judge is the default. idem: the request is safe to repeat, so
# Again is retried; else the breaker counts it and it never repeats. enc: the Accept-Encoding codings.
def request.as(~judge: Result<&1, &1, Http.Err, Http.Res> -> Result<&1, &1, Http.Err, Http.Res> & Verdict,
    c: Client, b: Retry.Budget, +idem: Bool, +enc: String, +method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Client & Retry.Budget & Result<&1, &1, Err, Http.Res>):
  run(~Http.Res, ~judge, ~try.res, ~close.res, c, b, idem, enc, method, url, headers, body)

# A streamed request under the same budget, deadline, backoff, and breaker as request.as. The stream opens on
# the client's pool. It follows the client's redirect mode, presents its certificate, and sends and stores
# cookies through its jar, as request.as does. judge reads the status and headers through Http.stream.res.
# A refused stream closes before the next attempt; the last one comes back open, so the caller can read its
# body. Close it with stream.close to give its connection back to the pool.
def open.as(~judge: Result<&1, &1, Http.Err, Http.Stream> -> Result<&1, &1, Http.Err, Http.Stream> & Verdict,
    c: Client, b: Retry.Budget, +idem: Bool, +enc: String, +method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Client & Retry.Budget & Result<&1, &1, Err, Http.Stream>):
  run(~Http.Stream, ~judge, ~try.stream, ~Http.stream.close, c, b, idem, enc, method, url, headers, body)

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
