import Base
import ./ownership.bend as App
import ../http/http.bend as Http
import ../concurrency/concurrency.bend as Conc

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def request(method: String, path: String, token: String, body: String) -> Http.Req:
  Http.Req{method, path, Http.set(Http.set(Http.empty(), "authorization", token), "content-type", "application/json"), Http.from_string(body)}

def response(res: Http.Res, status: U32, text: String) -> IO(Unit):
  Http.Res{got, headers, body} = res
  do IO<Unit>:
    require(U32.is_eq(got, status), "unexpected HTTP status")
    require(String.eq(Http.to_string(body), text), "unexpected response body or exposed private field")

def checked(result: App.Store & Http.Res, status: U32, text: String) -> IO(App.Store):
  (store, res) = result
  do IO<App.Store>:
    response(res, status, text)
    return store

def exercise(store: App.Store, req: Http.Req, status: U32, text: String) -> IO(App.Store):
  do IO<App.Store>:
    result : App.Store & Http.Res <- App.dispatch(store, req)
    checked(result, status, text)

def created(result: App.Store & Http.Res) -> IO(App.Store):
  (store, res) = result
  Http.Res{status, +headers, body} = res
  do IO<App.Store>:
    require(String.eq(Http.header(headers, "location"), "/users/9"), "creation Location is wrong")
    response(Http.Res{status, headers, body}, 201, "{\"id\":9,\"name\":\"Cara\"}")
    return store

def sequential(path: String) -> IO(Unit):
  do IO<Unit>:
    s0 : App.Store <- App.open(path, "w")
    s1 : App.Store <- exercise(s0, request("GET", "/health", "", ""), 200, "{\"ok\":true}")
    s2 : App.Store <- exercise(s1, request("GET", "/users/7", "Bearer alice", ""), 200, "{\"id\":7,\"name\":\"Alice\"}")
    s3 : App.Store <- exercise(s2, request("GET", "/users/me", "Bearer bob", ""), 200, "{\"id\":8,\"name\":\"Bob\"}")
    s4 : App.Store <- exercise(s3, request("GET", "/users/999", "Bearer alice", ""), 404, "{\"error\":\"not found\"}")
    s5 : App.Store <- exercise(s4, request("GET", "/users/abc", "Bearer alice", ""), 400, "{\"error\":\"invalid input\"}")
    s6 : App.Store <- exercise(s5, request("GET", "/users/4294967296", "Bearer alice", ""), 400, "{\"error\":\"invalid input\"}")
    s7 : App.Store <- exercise(s6, request("POST", "/users", "", "not JSON"), 401, "")
    s8 : App.Store <- exercise(s7, request("POST", "/users", "Bearer alice", "{\"name\":\"\"}"), 400, "{\"error\":\"invalid input\"}")
    s9 : App.Store <- exercise(s8, request("POST", "/users", "Bearer alice", "{\"name\":\"Cara\",\"name\":\"Other\"}"), 400, "{\"error\":\"invalid input\"}")
    s10 : App.Store <- exercise(s9, request("POST", "/users", "Bearer alice", "{\"name\":\"Cara\",\"admin\":true}"), 400, "{\"error\":\"invalid input\"}")
    bad_json : App.Store <- exercise(s10, request("POST", "/users", "Bearer alice", "not JSON"), 400, "{\"error\":\"invalid input\"}")
    missing : App.Store <- exercise(bad_json, request("POST", "/users", "Bearer alice", "{}"), 400, "{\"error\":\"invalid input\"}")
    wrong_type : App.Store <- exercise(missing, request("POST", "/users", "Bearer alice", "{\"name\":42}"), 400, "{\"error\":\"invalid input\"}")
    result : App.Store & Http.Res <- App.dispatch(wrong_type, request("POST", "/users", "Bearer alice", "{\"name\":\"Cara\"}"))
    s11 : App.Store <- created(result)
    s12 : App.Store <- exercise(s11, request("GET", "/users/9", "Bearer alice", ""), 200, "{\"id\":9,\"name\":\"Cara\"}")
    App.close(s12)
    IO.print("four routes: auth, typed decoding, rejection, creation, public output: OK")

def failed_write(path: String) -> IO(Unit):
  do IO<Unit>:
    s0 : App.Store <- App.open(path, "r")
    s1 : App.Store <- exercise(s0, request("POST", "/users", "Bearer alice", "{\"name\":\"Cara\"}"), 500, "{\"error\":\"internal error\"}")
    s2 : App.Store <- exercise(s1, request("GET", "/users/9", "Bearer alice", ""), 404, "{\"error\":\"not found\"}")
    s3 : App.Store <- exercise(s2, request("GET", "/users/me", "Bearer bob", ""), 200, "{\"id\":8,\"name\":\"Bob\"}")
    App.close(s3)
    IO.print("real File.write failure: handle returned, no user committed, subsequent lookup: OK")

type OwnerEvent is Data:
  Enter{slot: U32}
  Leave{slot: U32}
  Closed{slot: U32}

type Worker is Type:
  Worker{slot: U32, store: App.Store, events: Chan(OwnerEvent), release: Chan(Unit)}

type Counts is Data:
  Counts{mask: U32, busy: U32, closed: U32}

def send(+events: Chan(OwnerEvent), event: OwnerEvent) -> IO(Unit):
  do IO<Unit>:
    ok : Bool <- Chan.send(OwnerEvent, events, event)
    require(ok, "owner event channel closed too early")

def receive.value(-A: Type, got: Maybe<&1, A>) -> IO(A):
  match got:
    case None{}:
      IO.die(A, 1, "persistent channel closed too early")
    case Some{value}:
      IO.pure(A, value)

def receive(-A: Type, channel: Chan(A)) -> IO(A):
  do IO<A>:
    got : Maybe<&1, A> <- Chan.recv(A, channel)
    receive.value(A, got)

def barrier(req: Http.Req) -> Bool & Http.Req:
  Http.Req{method, path, +headers, body} = req
  (String.eq(Http.header(headers, "x-barrier"), "yes"), Http.Req{method, path, headers, body})

def wait(block: Bool, release: Chan(Unit)) -> IO(Unit):
  match block:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      receive(Unit, release)

def work.result(slot: U32, events: Chan(OwnerEvent), release: Chan(Unit), result: App.Store & Http.Res) -> Worker & Http.Res:
  (store, res) = result
  (Worker{slot, store, events, release}, res)

def work.ready(slot: U32, store: App.Store, +events: Chan(OwnerEvent), +release: Chan(Unit), ready: Bool & Http.Req) -> IO(Worker & Http.Res):
  (block, req) = ready
  +slot = slot
  do IO<Worker & Http.Res>:
    send(events, Enter{slot})
    wait(block, release)
    result : App.Store & Http.Res <- App.dispatch(store, req)
    send(events, Leave{slot})
    return work.result(slot, events, release, result)

def work(worker: Worker, req: Http.Req) -> IO(Worker & Http.Res):
  Worker{slot, store, events, release} = worker
  work.ready(slot, store, events, release, barrier(req))

def observe.event(counts: Counts, event: OwnerEvent) -> IO(Counts):
  Counts{+mask, +busy, +closed} = counts
  match event:
    case Enter{+slot}:
      +bit = (1 << U32.to_nat(slot) : U32)
      do IO<Counts>:
        require(U32.is_eq((mask .&. bit : U32), 0), "an affine instance was lent twice")
        return Counts{(mask .|. bit : U32), (busy + 1 : U32), closed}
    case Leave{+slot}:
      +bit = (1 << U32.to_nat(slot) : U32)
      do IO<Counts>:
        require(U32.is_ne((mask .&. bit : U32), 0), "instance returned without checkout")
        return Counts{(mask .^. bit : U32), (busy - 1 : U32), closed}
    case Closed{slot}:
      do IO<Counts>:
        require(U32.is_eq(busy, 0), "closed an instance before admitted requests finished")
        return Counts{mask, busy, (closed + 1 : U32)}

def observe(n: Nat, +events: Chan(OwnerEvent), counts: Counts) -> IO(Counts):
  match n:
    case 0n:
      IO.pure(Counts, counts)
    case 1n+p:
      do IO<Counts>:
        event : OwnerEvent <- receive(OwnerEvent, events)
        next : Counts <- observe.event(counts, event)
        observe(p, events, next)

def count.check(counts: Counts, busy: U32, closed: U32) -> IO(Unit):
  Counts{mask, got_busy, got_closed} = counts
  require(U32.is_eq(got_busy, busy) && U32.is_eq(got_closed, closed), "owner saw wrong in-use or closed count")

def shutdown(workers: List<Worker>) -> IO(Unit):
  match workers:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Worker{+slot, store, events, release} <> rest:
      do IO<Unit>:
        App.close(store)
        send(events, Closed{slot})
        shutdown(rest)

def blocked(req: Http.Req) -> Http.Req:
  Http.Req{method, path, headers, body} = req
  Http.Req{method, path, Http.set(headers, "x-barrier", "yes"), body}

def queue(+q: Chan(Http.Req & Chan(Http.Res)), req: Http.Req) -> IO(Chan(Http.Res)):
  do IO<Chan(Http.Res)>:
    reply : Chan(Http.Res) <- Chan.new(Http.Res, 1)
    +reply : Chan(Http.Res) = reply
    sent : Bool <- Chan.send(Http.Req & Chan(Http.Res), q, (req, reply))
    require(sent, "job queue rejected admitted request")
    return reply

def concurrent(+path: String) -> IO(Unit):
  do IO<Unit>:
    left : App.Store <- App.open(path ++ "-left", "w")
    right : App.Store <- App.open(path ++ "-right", "w")
    events0 : Chan(OwnerEvent) <- Chan.new(OwnerEvent, 8)
    +events : Chan(OwnerEvent) = events0
    release0 : Chan(Unit) <- Chan.new(Unit, 2)
    +release : Chan(Unit) = release0
    jobs0 : Chan(Http.Req & Chan(Http.Res)) <- Chan.new(Http.Req & Chan(Http.Res), 2)
    +jobs : Chan(Http.Req & Chan(Http.Res)) = jobs0
    workers : List<Chan(Worker)> <- Conc.pool.start(~Worker, ~Http.Req, ~Http.Res, ~work, [Worker{0, left, events, release}, Worker{1, right, events, release}], 16n, jobs)
    a : Chan(Http.Res) <- queue(jobs, blocked(request("GET", "/users/me", "Bearer alice", "")))
    b : Chan(Http.Res) <- queue(jobs, blocked(request("GET", "/users/me", "Bearer bob", "")))
    active0 : Counts <- observe(2n, events, Counts{0, 0, 0})
    +active : Counts = active0
    count.check(active, 2, 0)
    IO.print("owner observed 2 distinct affine instances in use before either request completed")
    go_a : Bool <- Chan.send(Unit, release, Unit{})
    go_b : Bool <- Chan.send(Unit, release, Unit{})
    require(go_a && go_b, "failed to release concurrent requests")
    res_a : Http.Res <- IO.join(Http.Res, a)
    res_b : Http.Res <- IO.join(Http.Res, b)
    response(res_a, 200, "{\"id\":7,\"name\":\"Alice\"}")
    response(res_b, 200, "{\"id\":8,\"name\":\"Bob\"}")
    idle0 : Counts <- observe(2n, events, active)
    +idle : Counts = idle0
    count.check(idle, 0, 0)
    c : Chan(Http.Res) <- queue(jobs, blocked(request("GET", "/users/999", "Bearer alice", "")))
    d : Chan(Http.Res) <- queue(jobs, blocked(request("GET", "/users/me", "Bearer bob", "")))
    Chan.close(Http.Req & Chan(Http.Res), jobs)
    active_again0 : Counts <- observe(2n, events, idle)
    +active_again : Counts = active_again0
    count.check(active_again, 2, 0)
    go_c : Bool <- Chan.send(Unit, release, Unit{})
    go_d : Bool <- Chan.send(Unit, release, Unit{})
    require(go_c && go_d, "failed to release second concurrent batch")
    res_c : Http.Res <- IO.join(Http.Res, c)
    res_d : Http.Res <- IO.join(Http.Res, d)
    response(res_c, 404, "{\"error\":\"not found\"}")
    response(res_d, 200, "{\"id\":8,\"name\":\"Bob\"}")
    idle_again0 : Counts <- observe(2n, events, active_again)
    +idle_again : Counts = idle_again0
    count.check(idle_again, 0, 0)
    final : List<Worker> <- Conc.pool.join(Worker, workers)
    shutdown(final)
    closed : Counts <- observe(2n, events, idle_again)
    count.check(closed, 0, 2)
    Chan.close(OwnerEvent, events)
    Chan.close(Unit, release)
    IO.print("concurrent principal isolation, expected failure, reuse, orderly close: OK")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> path <> Nil{}:
      +path = path
      do IO<Unit>:
        sequential(path)
        failed_write(path)
        concurrent(path)
        IO.print("ownership experiment: PASS")
    case _:
      IO.die(Unit, 1, "usage: ownership_check <temporary-journal-path>")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
