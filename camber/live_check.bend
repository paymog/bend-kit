# Live validation fixture: worker-owned Store/File bundles and bounded admission.
# ponytail: fixed scenarios use 128 owner steps and 256 worker steps; production needs lifecycle-driven shutdown.
import Base
import ./ownership.bend as Users
import ./interface_check.bend as Registry
import ../http/http.bend as Http
import ../http/context_probe.bend as Transport
import ../concurrency/concurrency.bend as Conc

type Counts is Data:
  Counts{busy: U32, mask: U32, completed: U32, rejected: U32}

type Message is Type:
  Submit{request: Http.Req, reply: Chan(Http.Res)}
  Enter{slot: U32}
  Leave{slot: U32}
  Inspect{reply: Chan(Counts)}
  Stop{}

type OwnerStep is Type:
  Waiting{counts: Counts}
  Received{counts: Counts, message: Message}

type Bundle is Type:
  Bundle{slot: U32, store: Users.Store, audit: File, plan: Registry.Plan<Registry.Action, Registry.Config>, owner: Chan(Message), release: Chan(Unit)}

type Context is Data:
  Context{owner: Chan(Message), release: Chan(Unit), limit: U32}

def receive.value(-A: Type, value: Maybe<&1, A>) -> IO(A):
  match value:
    case None{}:
      IO.die(A, 1, "live fixture channel closed early")
    case Some{got}:
      IO.pure(A, got)

def receive(-A: Type, channel: Chan(A)) -> IO(A):
  do IO<A>:
    value : Maybe<&1, A> <- Chan.recv(A, channel)
    receive.value(A, value)

def send(owner: Chan(Message), message: Message) -> IO(Unit):
  do IO<Unit>:
    sent : Bool <- Chan.send(Message, owner, message)
    Registry.require(sent, "owner channel rejected a message")

def audit.result(-A: Type, result: File & Result<&1, &1, U32 & String, A>) -> File & Bool:
  (file, outcome) = result
  match outcome:
    case Fail{error}:
      (file, False{})
    case Done{value}:
      (file, True{})

def audit(method: String, file: File) -> IO(File & Bool):
  match method:
    case "POST":
      do IO<File & Bool>:
        result : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, "attempt\n")
        return audit.result(Unit, result)
    case _:
      do IO<File & Bool>:
        result : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
        return audit.result(U32, result)

def packed(slot: U32, audit: File, plan: Registry.Plan<Registry.Action, Registry.Config>, owner: Chan(Message), release: Chan(Unit), result: Users.Store & Http.Res) -> Bundle & Http.Res:
  (store, response) = result
  (Bundle{slot, store, audit, plan, owner, release}, response)

def before.ready(ok: Bool, slot: U32, store: Users.Store, audit: File, +plan: Registry.Plan<Registry.Action, Registry.Config>, owner: Chan(Message), release: Chan(Unit), request: Http.Req) -> IO(Bundle & Http.Res):
  match ok:
    case False{}:
      IO.pure(Bundle & Http.Res, (Bundle{slot, store, audit, plan, owner, release}, Users.error(Users.StoreFailed{})))
    case True{}:
      do IO<Bundle & Http.Res>:
        result : Users.Store & Http.Res <- Registry.invoke(~Users.Store, ~Registry.Action, ~Registry.Config, ~Registry.run, plan, store, request)
        return packed(slot, audit, plan, owner, release, result)

def before.checked(slot: U32, store: Users.Store, plan: Registry.Plan<Registry.Action, Registry.Config>, owner: Chan(Message), release: Chan(Unit), request: Http.Req, checked: File & Bool) -> IO(Bundle & Http.Res):
  (file, ok) = checked
  before.ready(ok, slot, store, file, plan, owner, release, request)

def before(bundle: Bundle, request: Http.Req) -> IO(Bundle & Http.Res):
  Bundle{slot, store, audit_file, plan, owner, release} = bundle
  Http.Req{+method, path, headers, body} = request
  do IO<Bundle & Http.Res>:
    checked : File & Bool <- audit(method, audit_file)
    before.checked(slot, store, plan, owner, release, Http.Req{method, path, headers, body}, checked)

def after.ready(ok: Bool, bundle: Bundle, response: Http.Res) -> Bundle & Http.Res:
  match ok:
    case False{}:
      (bundle, Users.error(Users.StoreFailed{}))
    case True{}:
      (bundle, response)

def after.checked(slot: U32, store: Users.Store, plan: Registry.Plan<Registry.Action, Registry.Config>, owner: Chan(Message), release: Chan(Unit), response: Http.Res, checked: File & Bool) -> Bundle & Http.Res:
  (file, ok) = checked
  after.ready(ok, Bundle{slot, store, file, plan, owner, release}, response)

def after.invoked(slot: U32, file: File, plan: Registry.Plan<Registry.Action, Registry.Config>, owner: Chan(Message), release: Chan(Unit), result: Users.Store & Http.Res) -> IO(Bundle & Http.Res):
  (store, response) = result
  do IO<Bundle & Http.Res>:
    checked : File & Bool <- audit("GET", file)
    return after.checked(slot, store, plan, owner, release, response, checked)

def after(bundle: Bundle, request: Http.Req) -> IO(Bundle & Http.Res):
  Bundle{slot, store, audit_file, +plan, owner, release} = bundle
  do IO<Bundle & Http.Res>:
    result : Users.Store & Http.Res <- Registry.invoke(~Users.Store, ~Registry.Action, ~Registry.Config, ~Registry.run, plan, store, request)
    after.invoked(slot, audit_file, plan, owner, release, result)

def execute(store_first: Bool, bundle: Bundle, request: Http.Req) -> IO(Bundle & Http.Res):
  match store_first:
    case False{}:
      before(bundle, request)
    case True{}:
      after(bundle, request)

def wait(held: Bool, release: Chan(Unit)) -> IO(Unit):
  match held:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      receive(Unit, release)

def work(bundle: Bundle, request: Http.Req) -> IO(Bundle & Http.Res):
  Bundle{+slot, store, file, plan, +owner, +release} = bundle
  Http.Req{+method, path, +headers, body} = request
  do IO<Bundle & Http.Res>:
    send(owner, Enter{slot})
    wait(String.eq(Http.header(headers, "x-hold"), "yes"), release)
    result : Bundle & Http.Res <- execute(String.eq(method, "GET") && String.eq(Http.header(headers, "x-order"), "store-first"), Bundle{slot, store, file, plan, owner, release}, Http.Req{method, path, headers, body})
    send(owner, Leave{slot})
    return result

def admit(full: Bool, jobs: Chan(Http.Req & Chan(Http.Res)), counts: Counts, request: Http.Req, reply: Chan(Http.Res)) -> IO(Counts):
  match full:
    case True{}:
      Counts{busy, mask, completed, rejected} = counts
      do IO<Counts>:
        sent : Bool <- Chan.send(Http.Res, reply, Http.Res{503, Http.empty(), Http.from_string("")})
        Registry.require(sent, "overload reply channel closed early")
        return Counts{busy, mask, completed, (rejected + 1 : U32)}
    case False{}:
      Counts{busy, mask, completed, rejected} = counts
      do IO<Counts>:
        sent : Bool <- Chan.send(Http.Req & Chan(Http.Res), jobs, (request, reply))
        Registry.require(sent, "job queue closed before admitted work")
        return Counts{(busy + 1 : U32), mask, completed, rejected}

def transition(counts: Counts, message: Message) -> IO(Counts):
  Counts{+busy, +mask, completed, rejected} = counts
  match message:
    case Enter{+slot}:
      +bit = (1 << U32.to_nat(slot) : U32)
      do IO<Counts>:
        Registry.require(U32.is_eq((mask .&. bit : U32), 0), "bundle was used concurrently")
        IO.print("ENTER " ++ U32.show(slot))
        return Counts{busy, (mask .|. bit : U32), completed, rejected}
    case Leave{+slot}:
      +bit = (1 << U32.to_nat(slot) : U32)
      do IO<Counts>:
        Registry.require(U32.is_gt(busy, 0) && U32.is_ne((mask .&. bit : U32), 0), "bundle returned without admission")
        IO.print("LEAVE " ++ U32.show(slot))
        return Counts{(busy - 1 : U32), (mask .^. bit : U32), (completed + 1 : U32), rejected}
    case _:
      IO.die(Counts, 1, "invalid ownership transition")

def admission(limit: U32, jobs: Chan(Http.Req & Chan(Http.Res)), counts: Counts, request: Http.Req, reply: Chan(Http.Res)) -> IO(Counts):
  Counts{+busy, mask, completed, rejected} = counts
  admit(U32.is_ge(busy, limit), jobs, Counts{busy, mask, completed, rejected}, request, reply)

def owner.stop(counts: Counts, jobs: Chan(Http.Req & Chan(Http.Res))) -> IO(Counts):
  Counts{+busy, +mask, completed, rejected} = counts
  do IO<Counts>:
    Registry.require(U32.is_eq(busy, 0) && U32.is_eq(mask, 0), "shutdown reached occupied bundles")
    Chan.close(Http.Req & Chan(Http.Res), jobs)
    return Counts{busy, mask, completed, rejected}

def owner(fuel: Nat, +limit: U32, +messages: Chan(Message), +jobs: Chan(Http.Req & Chan(Http.Res)), step: OwnerStep) -> IO(Counts):
  match fuel:
    case 0n:
      IO.die(Counts, 1, "owner fixture ran out of fuel")
    case 1n+p:
      match step:
        case Waiting{counts}:
          do IO<Counts>:
            message : Message <- receive(Message, messages)
            owner(p, limit, messages, jobs, Received{counts, message})
        case Received{+counts, message}:
          match message:
            case Submit{request, reply}:
              do IO<Counts>:
                next : Counts <- admission(limit, jobs, counts, request, reply)
                owner(p, limit, messages, jobs, Waiting{next})
            case Inspect{reply}:
              do IO<Counts>:
                sent : Bool <- Chan.send(Counts, reply, counts)
                Registry.require(sent, "capacity observer closed early")
                owner(p, limit, messages, jobs, Waiting{counts})
            case Enter{slot}:
              do IO<Counts>:
                next : Counts <- transition(counts, Enter{slot})
                owner(p, limit, messages, jobs, Waiting{next})
            case Leave{slot}:
              do IO<Counts>:
                next : Counts <- transition(counts, Leave{slot})
                owner(p, limit, messages, jobs, Waiting{next})
            case Stop{}:
              owner.stop(counts, jobs)

def counts.text(limit: U32, counts: Counts) -> String:
  Counts{busy, mask, completed, rejected} = counts
  "{\"limit\":" ++ U32.show(limit) ++ ",\"busy\":" ++ U32.show(busy) ++ ",\"mask\":" ++ U32.show(mask) ++ ",\"completed\":" ++ U32.show(completed) ++ ",\"rejected\":" ++ U32.show(rejected) ++ "}"

def handle(context: Context, request: Http.Req) -> IO(Http.Res):
  Context{+messages, +release, limit} = context
  Http.Req{method, path, headers, body} = request
  match path:
    case "/_capacity":
      do IO<Http.Res>:
        reply0 : Chan(Counts) <- Chan.new(Counts, 1)
        +reply : Chan(Counts) = reply0
        send(messages, Inspect{reply})
        counts : Counts <- IO.join(Counts, reply)
        return Http.Res{200, Http.empty(), Http.from_string(counts.text(limit, counts))}
    case "/_release":
      do IO<Http.Res>:
        a : Bool <- Chan.send(Unit, release, Unit{})
        b : Bool <- Chan.send(Unit, release, Unit{})
        Registry.require(a && b, "release barrier closed early")
        return Http.Res{204, Http.empty(), Http.from_string("")}
    case _:
      do IO<Http.Res>:
        reply0 : Chan(Http.Res) <- Chan.new(Http.Res, 1)
        +reply : Chan(Http.Res) = reply0
        send(messages, Submit{Http.Req{method, path, headers, body}, reply})
        IO.join(Http.Res, reply)

def bundles(count: Nat, +slot: U32, +path: String, +store_mode: String, +audit_mode: String, +messages: Chan(Message), +release: Chan(Unit)) -> IO(List<Bundle>):
  match count:
    case 0n:
      IO.pure(List<Bundle>, Nil{})
    case 1n+p:
      do IO<List<Bundle>>:
        store : Users.Store <- Users.open(path ++ "-store-" ++ U32.show(slot), store_mode)
        file : File <- IO.try(File, File.open(path ++ "-audit-" ++ U32.show(slot), audit_mode))
        rest : List<Bundle> <- bundles(p, (slot + 1 : U32), path, store_mode, audit_mode, messages, release)
        return Bundle{slot, store, file, Registry.application("live"), messages, release} <> rest

def close(states: List<Bundle>) -> IO(Unit):
  match states:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Bundle{+slot, store, file, plan, owner, release} <> rest:
      do IO<Unit>:
        Users.close(store)
        File.close(file)
        IO.print("CLOSED " ++ U32.show(slot))
        close(rest)

def direct(+path: String) -> IO(Unit):
  +plan = Registry.application("live")
  do IO<Unit>:
    s0 : Users.Store <- Users.open(path ++ "-direct", "w")
    s1 : Users.Store <- Registry.exercise(plan, s0, Registry.req("GET", "/health", ""), 200, "{\"ok\":true}", "live")
    s2 : Users.Store <- Registry.exercise(plan, s1, Registry.req("GET", "/users/7", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "live")
    s3 : Users.Store <- Registry.exercise(plan, s2, Registry.req("GET", "/users/me", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "live")
    s4 : Users.Store <- Registry.exercise(plan, s3, Registry.req("POST", "/users", "{\"name\":\"Cara\"}"), 201, "{\"id\":9,\"name\":\"Cara\"}", "live")
    Users.close(s4)
    IO.print("DIRECT PASS")

def start(+limit: U32, path: String, port: U32, connections: U32, store_mode: String, audit_mode: String) -> IO(Unit):
  +path = path
  do IO<Unit>:
    direct(path)
    messages0 : Chan(Message) <- Chan.new(Message, 8)
    +messages : Chan(Message) = messages0
    release0 : Chan(Unit) <- Chan.new(Unit, 2)
    +release : Chan(Unit) = release0
    jobs0 : Chan(Http.Req & Chan(Http.Res)) <- Chan.new(Http.Req & Chan(Http.Res), limit)
    +jobs : Chan(Http.Req & Chan(Http.Res)) = jobs0
    states : List<Bundle> <- bundles(U32.to_nat(limit), 0, path, store_mode, audit_mode, messages, release)
    workers : List<Chan(Bundle)> <- Conc.pool.start(~Bundle, ~Http.Req, ~Http.Res, ~work, states, 256n, jobs)
    finished : Chan(Counts) <- IO.fork(Counts, owner(128n, limit, messages, jobs, Waiting{Counts{0, 0, 0, 0}}))
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("READY")
    connections_done : List<Chan(Unit)> <- Transport.accept(~Context, ~handle, U32.to_nat(connections), Context{messages, release, limit}, 65536n, listener)
    Transport.join(connections_done)
    send(messages, Stop{})
    final : Counts <- IO.join(Counts, finished)
    returned : List<Bundle> <- Conc.pool.join(Bundle, workers)
    close(returned)
    Chan.close(Message, messages)
    Chan.close(Unit, release)
    IO.print("FINAL " ++ counts.text(limit, final))
    IO.print("live bundled ownership: PASS")

def numbers(port: Maybe<&2, U32>, workers: Maybe<&2, U32>, connections: Maybe<&2, U32>, path: String, +store_mode: String, +audit_mode: String) -> IO(Unit):
  match port workers connections:
    case Some{+p} Some{+w} Some{+n}:
      do IO<Unit>:
        Registry.require(U32.is_gt(p, 0) && U32.is_lt(p, 65536) && U32.is_gt(n, 0) && U32.is_le(n, 4), "invalid fixture port or connection count")
        Registry.require((String.eq(store_mode, "r") || String.eq(store_mode, "w")) && (String.eq(audit_mode, "r") || String.eq(audit_mode, "w")), "invalid fixture file mode")
        Registry.require(U32.is_gt(w, 0) && U32.is_le(w, 2), "fixture requires one or two bundles")
        start(w, path, p, n, store_mode, audit_mode)
    case _ _ _:
      IO.die(Unit, 1, "fixture arguments must be U32")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> path <> port <> workers <> connections <> store_mode <> audit_mode <> Nil{}:
      numbers(U32.read(port), U32.read(workers), U32.read(connections), path, store_mode, audit_mode)
    case _:
      IO.die(Unit, 1, "usage: live_check <journal-prefix> <port> <bundles> <connections> <store-mode> <audit-mode>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
