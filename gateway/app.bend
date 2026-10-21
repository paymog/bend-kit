# The gateway as a Camber application: one guarded GET route that reads through to an upstream.
import Base
import ./gateway.bend as G
import bend-kit-authz@0.1.0.0/authz.bend as Az
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-cache@0.2.0.0/cache.bend as Cache
import bend-kit-camber@0.13.0.0/camber.bend as C
import bend-kit-http@0.36.0.0/http.bend as H
import bend-kit-hairpin@0.10.0.0/hairpin.bend as Hairpin
import bend-kit-retry@0.2.0.0/retry.bend as Retry
import bend-kit-time@0.2.0.0/time.bend as Time
import bend-kit-bytes@0.3.2.0/bytes.bend as B

# One operation on the shared gate. OpPeek reports the units lent.
type Op is Data:
  OpBegin{policy: Az.Policy, req: Az.Request, key: String, now: Nat}
  OpFinish{pending: G.Pending, upstream: G.Upstream}
  OpPeek{}

type Reply is Data:
  RDenied{}
  RBusy{}
  RFresh{entry: Cache.Entry<String>}
  RFetch{pending: G.Pending}
  RSettled{}
  RHeld{held: Nat}

# The gate's settings: how many requests it admits at once, and how long results stay fresh.
type Setup is Data:
  Setup{capacity: Nat, ttl: Cache.Policy}

# attempts and deadline (ms) make each request's retry budget.
type Config is Data:
  Config{store: C.Context<G.Gate, Unit, Op, String, Reply>, policy: Az.Policy, attempts: Nat, deadline: Nat}

type Action is Data:
  Read{}

# What one upstream fetch gave, as data.
type Got is Data:
  GotBody{body: String}
  GotMissing{}
  GotStatus{status: U32}
  GotOpen{}
  GotError{}

# Store
# -----

def store.open(setup: Setup, index: Nat) -> IO(Result<&2, &1, String, G.Gate>):
  Setup{capacity, ttl} = setup
  IO.pure(Result<&2, &1, String, G.Gate>, Done{G.new(1n, capacity, ttl)})

def store.close(gate: G.Gate) -> IO(Unit):
  IO.pure(Unit, Unit{})

def store.began(b: G.Begin) -> G.Gate & Result<&2, &2, String, Reply>:
  match b:
    case G.Denied{g}:
      (g, Done{RDenied{}})
    case G.Busy{g}:
      (g, Done{RBusy{}})
    case G.Fresh{g, e}:
      (g, Done{RFresh{e}})
    case G.Fetch{g, p}:
      (g, Done{RFetch{p}})

def store.finished(f: G.Finish) -> G.Gate & Result<&2, &2, String, Reply>:
  match f:
    case G.Settled{g}:
      (g, Done{RSettled{}})
    case G.Unheld{g}:
      (g, Fail{"finish without a reservation"})

def store.held(g: G.Gate) -> G.Gate & Result<&2, &2, String, Reply>:
  G.Gate{pool, held, cache} = g
  Res.Pool{o, c, +h} = pool
  (G.Gate{Res.Pool{o, c, h}, held, cache}, Done{RHeld{h}})

def store.work(gate: G.Gate, principal: Unit, op: Op) -> IO(G.Gate & Result<&2, &2, String, Reply>):
  match op:
    case OpBegin{policy, req, key, now}:
      IO.pure(G.Gate & Result<&2, &2, String, Reply>, store.began(G.begin(policy, req, gate, key, now)))
    case OpFinish{p, u}:
      IO.pure(G.Gate & Result<&2, &2, String, Reply>, store.finished(G.finish(gate, p, u)))
    case OpPeek{}:
      IO.pure(G.Gate & Result<&2, &2, String, Reply>, store.held(gate))

def store.start(setup: Setup) -> IO(Result<&2, &1, String, C.Owner<G.Gate, Unit, Op, String, Reply>>):
  C.start(~Setup, ~G.Gate, ~Unit, ~Op, ~String, ~Reply, ~store.open, ~store.work, ~store.close, setup, 1n, 64)

def call.again(out: C.Outcome<String, Reply>, next: Unit -> IO(C.Outcome<String, Reply>)) -> IO(C.Outcome<String, Reply>):
  match out:
    case C.Exhausted{}:
      do IO<C.Outcome<String, Reply>>:
        IO.sleep(1)
        next(Unit{})
    case C.Success{r}:
      IO.pure(C.Outcome<String, Reply>, C.Success{r})
    case C.Expected{e}:
      IO.pure(C.Outcome<String, Reply>, C.Expected{e})
    case C.Stopped{}:
      IO.pure(C.Outcome<String, Reply>, C.Stopped{})

# The gate serves one operation at a time and refuses the rest, so a caller tries
# again. A finish must land: a dropped finish would keep its unit forever.
def call.go(fuel: Nat, +store: C.Context<G.Gate, Unit, Op, String, Reply>, +op: Op) -> IO(C.Outcome<String, Reply>):
  match fuel:
    case 0n:
      C.call(G.Gate, Unit, Op, String, Reply, store, Unit{}, op)
    case 1n+p:
      do IO<C.Outcome<String, Reply>>:
        out : C.Outcome<String, Reply> <- C.call(G.Gate, Unit, Op, String, Reply, store, Unit{}, op)
        call.again(out, u => call.go(p, store, op))

def call(store: C.Context<G.Gate, Unit, Op, String, Reply>, op: Op) -> IO(C.Outcome<String, Reply>):
  call.go(60000n, store, op)

# Request
# -------

def present(value: String) -> Maybe<&2, String>:
  match value:
    case "":
      None{}
    case other:
      Some{other}

def split(s: String, cur: String) -> List<&2, String>:
  match s:
    case SNil{}:
      [cur]
    case SCon{Chr{44}, rest}:
      cur <> split(rest, "")
    case SCon{c, rest}:
      split(rest, cur ++ SCon{c, SNil{}})

def roles(value: String) -> Maybe<&2, List<&2, String>>:
  match value:
    case "":
      None{}
    case other:
      Some{split(other, "")}

# x-subject and x-roles stand for a verified identity; verify it first (for example with jwt).
def request(method: String, target: String, +headers: Map<&2, List<&2, String>>) -> Az.Request:
  Az.Request{present(H.header(headers, "x-subject")), roles(H.header(headers, "x-roles")), None{}, method, target}

# Readers may read. A suspended role always denies.
def readers() -> Az.Policy:
  Az.DenyOverrides{Az.Permit{Az.AllOf{Az.Action{"GET"}, Az.Role{"reader"}}}, Az.Forbid{Az.Role{"suspended"}}}

# Response
# --------

def plain(+status: U32, +cache: String, body: String) -> H.Res:
  H.Res{status, H.set(H.empty(), "x-cache", cache), H.from_string(body)}

def entry.res(e: Cache.Entry<String>) -> H.Res:
  match e:
    case Cache.Hit{v, body, x}:
      plain(200, "hit", body)
    case Cache.Miss{x}:
      plain(404, "hit", "")

def got.code(code: U32, +status: U32, body: B.Bytes) -> Got:
  match code:
    case 200:
      GotBody{H.to_string(body)}
    case 404:
      GotMissing{}
    case _:
      GotStatus{status}

def got(r: Result<&1, &1, Hairpin.Err, H.Res>) -> Got:
  match r:
    case Done{H.Res{+status, headers, body}}:
      got.code(status, status, body)
    case Fail{Hairpin.ErrDenied{Retry.DenyOpen{}}}:
      GotOpen{}
    case Fail{e}:
      GotError{}

def upstream(g: Got) -> G.Upstream:
  match g:
    case GotBody{body}:
      G.Fetched{Cache.Found{0n, body}}
    case GotMissing{}:
      G.Fetched{Cache.Missing{}}
    case _:
      G.Failed{}

# An upstream failure is 502. An open breaker is 503: no attempt started.
def got.res(g: Got) -> H.Res:
  match g:
    case GotBody{body}:
      plain(200, "miss", body)
    case GotMissing{}:
      plain(404, "miss", "")
    case GotStatus{s}:
      plain(502, "miss", "")
    case GotOpen{}:
      plain(503, "open", "")
    case GotError{}:
      plain(502, "miss", "")

# Handler
# -------

def finished(out: C.Outcome<String, Reply>, client: Hairpin.Client, g: Got) -> Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>:
  match out:
    case C.Success{RSettled{}}:
      (client, Done{got.res(g)})
    case _:
      (client, Fail{C.ApplicationError{"finish failed"}})

def fetched(+store: C.Context<G.Gate, Unit, Op, String, Reply>, p: G.Pending, r: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, H.Res>) -> IO(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>):
  (client, budget, result) = r
  +g = got(result)
  do IO<Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>>:
    out : C.Outcome<String, Reply> <- call(store, OpFinish{p, upstream(g)})
    return finished(out, client, g)

# The budget starts at the same clock reading as the cache read.
def fetch(client: Hairpin.Client, +store: C.Context<G.Gate, Unit, Op, String, Reply>, p: G.Pending, +attempts: Nat, deadline: Nat, target: String, +now: Nat) -> IO(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>>:
    r : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, H.Res> <- Hairpin.request.in(client, Retry.Budget.new(attempts, now, Some{deadline}), "GET", target, H.empty(), B.new(0))
    fetched(store, p, r)

def began(out: C.Outcome<String, Reply>, client: Hairpin.Client, +store: C.Context<G.Gate, Unit, Op, String, Reply>, +attempts: Nat, deadline: Nat, target: String, +now: Nat) -> IO(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>):
  match out:
    case C.Success{RDenied{}}:
      IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Done{C.empty(403)}))
    case C.Success{RBusy{}}:
      IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Done{plain(503, "busy", "")}))
    case C.Success{RFresh{e}}:
      IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Done{entry.res(e)}))
    case C.Success{RFetch{p}}:
      fetch(client, store, p, attempts, deadline, target, now)
    case C.Exhausted{}:
      IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Done{plain(503, "busy", "")}))
    case C.Stopped{}:
      IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Done{plain(503, "busy", "")}))
    case _:
      IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Fail{C.ApplicationError{"begin failed"}}))

# One clock reading per request, in monotonic ms, for both the cache and the retry budget.
def run(action: Action, client: Hairpin.Client, config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>):
  Config{+store, policy, attempts, deadline} = config
  H.Req{method, +target, +headers, body} = req
  do IO<Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>>:
    +now : Nat <- Time.mono.ms()
    out : C.Outcome<String, Reply> <- call(store, OpBegin{policy, request(method, target, headers), target, now})
    began(out, client, store, attempts, deadline, target, now)

def before(hook: String, client: Hairpin.Client, config: Config, meta: C.Metadata) -> IO(C.Step<Hairpin.Client, String>):
  IO.pure(C.Step<Hairpin.Client, String>, C.Continue{client})

def after(hook: String, client: Hairpin.Client, config: Config, response: H.Res) -> IO(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>):
  IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Done{response}))

def mapper(client: Hairpin.Client, config: Config, error: C.Error<String>) -> IO(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>):
  IO.pure(Hairpin.Client & Result<&2, &1, C.Error<String>, H.Res>, (client, Done{C.default.error(~String, error)}))

def application(config: Config) -> Result<&2, &2, C.RegistrationError, C.Application<Action, Config, C.Policy<String>>>:
  C.application(~Action, ~Config, ~C.Policy<String>,
    [C.Route{"GET", "/items/:id", Read{}, Nil{}, C.policy(~String, 1, Nil{}, Nil{})}],
    Nil{}, config, C.policy(~String, 0, Nil{}, Nil{}))

# One upstream client per request slot. Two transient failures open its breaker for 2 s.
def client(base: String) -> Hairpin.Client:
  Hairpin.circuit(Hairpin.retry(Hairpin.timeout(Hairpin.base(Hairpin.new(), base), 5000), 1), Retry.Circuit{2n, 10000n, 2000n, 1n})
