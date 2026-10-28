# Durable webhook delivery: a runner job signs a Standard Webhooks POST and sends it through hairpin.
# A receiver on 127.0.0.1 answers 503, then 200: the runner requeues the first delivery and then completes both.
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-webhooks@0.11.0.1/webhooks.bend as W
import bend-kit-hairpin@0.13.0.1/hairpin.bend as Hairpin
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-http@0.38.1.1/http.bend as Http
import bend-kit-http@0.38.1.1/admission.bend as Admission
import bend-kit-http@0.38.1.1/completion.bend as Completion
import bend-kit-time@0.3.0.0/time.bend as Time
import bend-kit-files@0.3.0.0/files.bend as Files
import ./runner.bend as R

# ---- the job

# One webhook: where it goes, its event id (receivers deduplicate on it), and its body.
type Hook is Data:
  Hook{url: String, id: String, body: String}

# The record of a Hook: url, id, and body, split by newlines. A url and an id hold no newline.
def Hook.encode(h: Hook) -> Bytes.Bytes:
  Hook{url, id, body} = h
  Bytes.from_string(url ++ "\n" ++ id ++ "\n" ++ body)

def Hook.parts(xs: List<&2, String>) -> Maybe<&2, Hook>:
  match xs:
    case Con{url, Con{id, body}}:
      Some{Hook{url, id, String.join(body, "\n")}}
    case _:
      None{}

def Hook.decode(b: Bytes.Bytes) -> Maybe<&2, Hook>:
  Hook.parts(String.split(Bytes.to_string(b), '\n'))

# Each receiver URL has its own breaker.
def Hook.target(h: Hook) -> String:
  Hook{url, id, body} = h
  url

def secret() -> String:
  "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"

# A 2xx is delivered. A timeout, a refused connect, 408, 429, or a 5xx may clear on a later attempt.
# Any other 4xx is the sender's fault, so the hook stays dead and the target's breaker does not count it.
# Any other answer will not change either, so the runner keeps the hook dead.
def judge.status(+s: U32) -> Retry.Outcome:
  Bool.pick(Retry.Outcome, Bool.and(U32.is_ge(s, 200), U32.is_lt(s, 300)), Retry.Settled{},
  Bool.pick(Retry.Outcome, Bool.or(Bool.or(U32.is_eq(s, 408), U32.is_eq(s, 429)), U32.is_ge(s, 500)), Retry.Transient{None{}},
  Bool.pick(Retry.Outcome, U32.is_ge(s, 400), Retry.Rejected{}, Retry.Failed{})))

def judge(r: Result<&1, &1, W.SendErr, Http.Res>) -> Retry.Outcome:
  match r:
    case Done{Http.Res{s, h, b}}:
      judge.status(s)
    case Fail{W.SendNet{e}}:
      Retry.Transient{None{}}
    case Fail{W.SendSign{e}}:
      Retry.Failed{}

def sent(x: Hairpin.Client & Result<&1, &1, W.SendErr, Http.Res>) -> IO(Retry.Outcome):
  (c, r) = x
  do IO<Retry.Outcome>:
    Hairpin.close(c)
    return judge(r)

# One attempt: no retry inside hairpin, so the runner owns every retry and its durable record.
def deliver(h: Hook) -> IO(Retry.Outcome):
  Hook{url, id, body} = h
  do IO<Retry.Outcome>:
    x : Hairpin.Client & Result<&1, &1, W.SendErr, Http.Res> <- W.send.with(0, Hairpin.new(), url, id, secret(), Bytes.from_string(body))
    sent(x)

# ---- the receiver: one connection per entry of a script of statuses

def respond(+status: U32, r: Bytes.Bytes & Result<&1, &1, W.Err, String>) -> IO(Http.Reply):
  (body, v) = r
  match v:
    case Fail{e}:
      IO.die(Http.Reply, 1, "bad webhook: the receiver rejected a signature")
    case Done{id}:
      IO.pure(Http.Reply, Http.Reply{Http.Res{status, Http.set(Http.empty(), "connection", "close"), Bytes.new(0)}, Completion.Unobserved{}})

def handle(+status: U32, req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, path, +headers, body} = req
  do IO<Http.Reply>:
    now : Time.Instant <- Time.now()
    r : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify([secret()], now, headers, body)
    respond(status, r)

def serve.one(+busy: Bool, +inbox: Chan(Admission.Command), a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match busy:
    case True{}:
      Http.conn(~(req => handle(503, req)), ~Completion.ignore, Http.limits(1048576n), inbox, a)
    case False{}:
      Http.conn(~(req => handle(200, req)), ~Completion.ignore, Http.limits(1048576n), inbox, a)

def serve.go(ks: List<&2, Bool>, +inbox: Chan(Admission.Command), l: Listener) -> IO(Unit):
  match ks:
    case Nil{}:
      do IO<Unit>:
        Listener.close(l)
        Admission.close(inbox)
    case Con{+k, rest}:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l2 : Listener <- serve.one(k, inbox, a)
        serve.go(rest, inbox, l2)

# True answers 503, False answers 200.
def serve(ks: List<&2, Bool>, l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    serve.go(ks, inbox, l)

# ---- the runner

def config() -> R.Config:
  R.Config{Retry.Policy{4n, 1n, 50, None{}}, Retry.Circuit{5n, 60000n, 1000n, 1n}, 5, 0}

def enq.got(y: R.Runner<Hook> & R.Out(Nat)) -> IO(R.Runner<Hook>):
  match y:
    case (r, Done{i}):
      IO.pure(R.Runner<Hook>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<Hook>, 1, "bad webhook enqueue: " ++ m)

def enq(r: R.Runner<Hook>, x: Hook) -> IO(R.Runner<Hook>):
  do IO<R.Runner<Hook>>:
    y : R.Runner<Hook> & R.Out(Nat) <- R.enqueue(~Hook, ~Hook.encode, r, 0n, x)
    enq.got(y)

def drained(y: R.Ran(Hook)) -> IO(R.Runner<Hook>):
  match y:
    case (r, Done{u}):
      IO.pure(R.Runner<Hook>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<Hook>, 1, "bad webhook drain: " ++ m)

def url() -> String:
  "http://127.0.0.1:47861/hooks"

def finished(m: Maybe<&1, Unit>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "bad webhook: the receiver still waits for an attempt")
    case Some{u}:
      IO.print("ok webhooks: one 503 retried, then both events delivered, three attempts in all")

# Two events to one receiver, one attempt at a time. The first attempt gets 503; the runner requeues it.
def run(+path: String) -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47861))
    ch : Chan(Unit) <- IO.fork(Unit, serve([True{}, False{}, False{}], l))
    r0 : R.Runner<Hook> <- IO.try(R.Runner<Hook>, R.open(~Hook, ~Hook.encode, ~Hook.decode, path, 65536, 1048576, config(), 1n))
    r1 : R.Runner<Hook> <- enq(r0, Hook{url(), "msg_1", "{\"event\": 1}"})
    r2 : R.Runner<Hook> <- enq(r1, Hook{url(), "msg_2", "{\"event\": 2}"})
    y : R.Ran(Hook) <- R.drain(~Hook, ~Hook.encode, ~Hook.target, ~deliver, 200n, r2)
    r3 : R.Runner<Hook> <- drained(y)
    R.close(Hook, r3)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    finished(m)

def main() -> IO(Unit):
  do IO<Unit>:
    dir : String <- IO.try(String, Files.temp_dir())
    run(dir ++ "/hooks.journal")
