# LLM client for the Anthropic Messages and OpenAI Chat Completions APIs, with SSE streaming. Source: https://github.com/paymog/bend-kit/tree/main/llm
import Base
import ./sse.bend as Sse
import bend-kit-hairpin@0.19.0.3/hairpin.bend as Hairpin
import bend-kit-hairpin@0.19.0.3/pure.bend as HairpinPure
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-http@0.45.0.3/http.bend as Http
import bend-kit-http@0.45.0.3/pure.bend as HttpPure
import bend-kit-json@0.7.3.2/json.bend as Json
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-encoding@0.5.0.3/encoding.bend as Enc
import ./pure.bend as Pure

# Anthropic: POST {base}/v1/messages. OpenAI: POST {base}/chat/completions, which many other providers serve too.
type Api is Data:
  Anthropic{}
  OpenAI{}

type Role is Data:
  User{}
  Assistant{}

type Msg is Data:
  Msg{role: Role, text: String}

# system: "" for none. max: the most tokens to write.
type Req is Data:
  Req{model: String, system: String, msgs: List<&2, Msg>, max: U32}

# stop: the API's reason, as "end_turn" or "stop". input and output count tokens.
type Reply is Data:
  Reply{id: String, model: String, text: String, stop: String, input: U32, output: U32}

# ErrNet: the request did not complete, or Hairpin's breaker admitted no attempt. ErrApi: the API refused, with
# its status and error text; an error event in a stream has status 200. ErrReply: a reply that is not the API's JSON, with its text.
type Err is Data:
  ErrNet{e: Hairpin.Err}
  ErrApi{status: U32, body: String}
  ErrReply{body: String}

# headers go on every request. ms: the step timeout. retries: extra tries after a retryable failure.
type Client is Type:
  Client{api: Api, base: String, headers: Map<&2, List<&2, String>>, ms: U32, retries: U32, http: Hairpin.Client}

def api.to.pure(v: Api) -> Pure.Api:
  match v:
    case Anthropic{}:
      Pure.Anthropic{}
    case OpenAI{}:
      Pure.OpenAI{}

def role.to.pure(v: Role) -> Pure.Role:
  match v:
    case User{}:
      Pure.User{}
    case Assistant{}:
      Pure.Assistant{}

def msg.to.pure(v: Msg) -> Pure.Msg:
  Msg{r, t} = v
  Pure.Msg{role.to.pure(r), t}

def msgs.to.pure(xs: List<&2, Msg>) -> List<&2, Pure.Msg>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{msg.to.pure(h), msgs.to.pure(t)}

def req.to.pure(v: Req) -> Pure.Req:
  Req{m, s, xs, n} = v
  Pure.Req{m, s, msgs.to.pure(xs), n}

def reply.from.pure(v: Pure.Reply) -> Reply:
  Pure.Reply{i, m, t, s, n, o} = v
  Reply{i, m, t, s, n, o}

def err.from.pure(v: Pure.Err) -> Err:
  match v:
    case Pure.ErrApi{s, b}:
      ErrApi{s, b}
    case Pure.ErrReply{b}:
      ErrReply{b}

def reply.result.from.pure(v: Result<&1, &1, Pure.Err, Pure.Reply>) -> Result<&1, &1, Err, Reply>:
  match v:
    case Fail{e}:
      Fail{err.from.pure(e)}
    case Done{r}:
      Done{reply.from.pure(r)}


# ---- JSON

def str(s: String) -> Json.Val:
  Pure.str(s)

def kv(k: String, v: Json.Val) -> Bytes.Bytes & Json.Val:
  Pure.kv(k, v)

def num(+n: U32) -> Json.Val:
  Pure.num(n)

def obj(kvs: List<&1, Bytes.Bytes & Json.Val>) -> Json.Val:
  Pure.obj(kvs)

def when(on: Bool, x: Bytes.Bytes & Json.Val, xs: List<&1, Bytes.Bytes & Json.Val>) -> List<&1, Bytes.Bytes & Json.Val>:
  Pure.when(on, x, xs)

def role(r: Role) -> String:
  Pure.role(role.to.pure(r))

def msg(+r: String, t: String) -> Json.Val:
  Pure.msg(r, t)

def msgs(xs: List<&2, Msg>) -> List<&1, Json.Val>:
  Pure.msgs(msgs.to.pure(xs))

def sys(on: Bool, s: String, xs: List<&1, Json.Val>) -> List<&1, Json.Val>:
  Pure.sys(on, s, xs)

# The request body for api. stream asks for SSE.
def body(api: Api, req: Req, stream: Bool) -> Json.Val:
  Pure.body(api.to.pure(api), req.to.pure(req), stream)

# A JSON leaf: its path, as "content.0.text", and its text.
type Leaf is Data:
  Leaf{p: String, v: String}

def leaves.to.pure(xs: List<&2, Leaf>) -> List<&2, Pure.Leaf>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Leaf{p, v}, t}:
      Con{Pure.Leaf{p, v}, leaves.to.pure(t)}

def leaves.from.pure(xs: List<&2, Pure.Leaf>) -> List<&2, Leaf>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Pure.Leaf{p, v}, t}:
      Con{Leaf{p, v}, leaves.from.pure(t)}

def doc.to.pure(v: Maybe<&2, List<&2, Leaf>>) -> Maybe<&2, List<&2, Pure.Leaf>>:
  match v:
    case None{}:
      None{}
    case Some{xs}:
      Some{leaves.to.pure(xs)}

def doc.from.pure(v: Maybe<&2, List<&2, Pure.Leaf>>) -> Maybe<&2, List<&2, Leaf>>:
  match v:
    case None{}:
      None{}
    case Some{xs}:
      Some{leaves.from.pure(xs)}

def path(+p: String, +k: String) -> String:
  Pure.path(p, k)

def push.arr(xs: List<&1, Json.Val>, +p: String, +i: U32, t: List<&1, String & Json.Val>) -> List<&1, String & Json.Val>:
  Pure.push.arr(xs, p, i, t)

def push.obj(kvs: List<&1, Bytes.Bytes & Json.Val>, +p: String, t: List<&1, String & Json.Val>) -> List<&1, String & Json.Val>:
  Pure.push.obj(kvs, p, t)

# The leaves under the stack's values, last first. f: at least the values left.
def flat(f: Nat, stack: List<&1, String & Json.Val>, acc: List<&2, Leaf>) -> List<&2, Leaf>:
  leaves.from.pure(Pure.flat(f, stack, leaves.to.pure(acc)))

def doc.of(+n: U32, m: Maybe<&1, Json.Val>) -> Maybe<&2, List<&2, Leaf>>:
  doc.from.pure(Pure.doc.of(n, m))

# Every non-null leaf of a JSON text in document order, keyed by its path, as ("content.0.text", "Hi").
# Strings are decoded; numbers keep their text. None when b is not JSON. Each value takes a byte, so n + 1 steps suffice.
def doc(b: Bytes.Bytes) -> Maybe<&2, List<&2, Leaf>>:
  doc.from.pure(Pure.doc(b))

# The first value at path k, or "".
def look(d: List<&2, Leaf>, +k: String) -> String:
  Pure.look(leaves.to.pure(d), k)

def count(s: String) -> U32:
  Pure.count(s)

def dots(s: String, +n: U32) -> U32:
  Pure.dots(s, n)

# Is p the text of a content block, "content.<i>.text"?
def block(+p: String) -> Bool:
  Pure.block(p)

# The text blocks of an Anthropic message, joined.
def blocks(d: List<&2, Leaf>) -> String:
  Pure.blocks(leaves.to.pure(d))

def reply.of(api: Api, +d: List<&2, Leaf>) -> Reply:
  reply.from.pure(Pure.reply.of(api.to.pure(api), leaves.to.pure(d)))

def reply.got(api: Api, b: Bytes.Bytes, m: Maybe<&2, List<&2, Leaf>>) -> Result<&1, &1, Err, Reply>:
  reply.result.from.pure(Pure.reply.got(api.to.pure(api), b, doc.to.pure(m)))

def reply.copy(api: Api, r: Bytes.Bytes & Bytes.Bytes) -> Result<&1, &1, Err, Reply>:
  reply.result.from.pure(Pure.reply.copy(api.to.pure(api), r))

# A 2xx response body as a Reply.
def reply(api: Api, b: Bytes.Bytes) -> Result<&1, &1, Err, Reply>:
  reply.result.from.pure(Pure.reply(api.to.pure(api), b))

# ---- stream events

# A text piece, the end, an error, or an event with no text.
type Ev is Data:
  EText{s: String}
  EEnd{}
  EFail{e: Err}
  ESkip{}

def ev.from.pure(v: Pure.Ev) -> Ev:
  match v:
    case Pure.EText{s}:
      EText{s}
    case Pure.EEnd{}:
      EEnd{}
    case Pure.EFail{e}:
      EFail{err.from.pure(e)}
    case Pure.ESkip{}:
      ESkip{}

def ev.text(+s: String) -> Ev:
  ev.from.pure(Pure.ev.text(s))

def ev.doc(m: Maybe<&2, List<&2, Leaf>>) -> List<&2, Leaf>:
  leaves.from.pure(Pure.ev.doc(doc.to.pure(m)))

def ev.anthropic(+name: String, data: Bytes.Bytes) -> Ev:
  ev.from.pure(Pure.ev.anthropic(name, data))

def ev.openai(+s: String) -> Ev:
  ev.from.pure(Pure.ev.openai(s))

# What one SSE event of api means.
def ev(api: Api, e: Sse.Message) -> Ev:
  ev.from.pure(Pure.ev(api.to.pure(api), e))

# ---- requests

def ok(+s: U32) -> Bool:
  Pure.ok(s)

# Statuses a later try may clear: 408, 409, 429, and 5xx, which holds Anthropic's 529.
def again.status(+s: U32) -> Bool:
  Pure.again.status(s)

# A refused connect or a timeout may clear.
def again.err(+e: HttpPure.Err) -> Maybe<&2, String>:
  match e:
    case HttpPure.ErrConnect{code, why}:
      Some{""}
    case HttpPure.ErrTimeout{}:
      Some{""}
    case other:
      None{}

def again.of(+status: U32, +h: Map<&2, List<&2, String>>) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, again.status(status), Some{HttpPure.header(h, "retry-after")}, None{})

# Again when another try may help; otherwise settled, as HairpinPure.judge would settle it.
def verdict(m: Maybe<&2, String>, settled: HairpinPure.Verdict) -> HairpinPure.Verdict:
  match m:
    case Some{after}:
      HairpinPure.VerdictAgain{after}
    case None{}:
      settled

# Hairpin's judge for every call.
def again(r: Result<&1, &1, HttpPure.Err, HttpPure.Res>) -> Result<&1, &1, HttpPure.Err, HttpPure.Res> & HairpinPure.Verdict:
  match r:
    case Fail{+e}:
      (Fail{e}, verdict(again.err(e), HairpinPure.VerdictTarget{}))
    case Done{res}:
      HttpPure.Res{+status, +h, b} = res
      (Done{HttpPure.Res{status, h, b}}, verdict(again.of(status, h), HairpinPure.judge.status(status)))

def body.ok(good: Bool, +status: U32, b: Bytes.Bytes) -> Result<&1, &1, Err, Bytes.Bytes>:
  match good:
    case True{}:
      Done{b}
    case False{}:
      Fail{ErrApi{status, Enc.utf8.decode(b)}}

# The 2xx body, or why there is none.
def body.of(r: Result<&1, &1, Hairpin.Err, HttpPure.Res>) -> Result<&1, &1, Err, Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{ErrNet{e}}
    case Done{res}:
      HttpPure.Res{+status, h, b} = res
      body.ok(ok(status), status, b)

def url(api: Api, +base: String) -> String:
  match api:
    case Anthropic{}:
      base ++ "/v1/messages"
    case OpenAI{}:
      base ++ "/chat/completions"

# ---- the client

def new(+api: Api, base: String, headers: Map<&2, List<&2, String>>) -> Client:
  Client{api, base, headers, 600000, 2, Hairpin.timeout(Hairpin.new(), 600000)}

def json(h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  HttpPure.set(h, "content-type", "application/json")

# base https://api.anthropic.com, 10 min steps, 2 retries.
def anthropic(key: String) -> Client:
  new(Anthropic{}, "https://api.anthropic.com", json(HttpPure.set(HttpPure.set(HttpPure.empty(), "x-api-key", key), "anthropic-version", "2023-06-01")))

# base https://api.openai.com/v1, 10 min steps, 2 retries.
def openai(key: String) -> Client:
  new(OpenAI{}, "https://api.openai.com/v1", json(HttpPure.set(HttpPure.empty(), "authorization", "Bearer " ++ key)))

# Another base URL, as for a provider that serves the same API.
def base(c: Client, url: String) -> Client:
  Client{api, old, h, ms, n, http} = c
  Client{api, url, h, ms, n, http}

# A header on every request, as anthropic-beta. It replaces one of the same name.
def header(c: Client, k: String, v: String) -> Client:
  Client{api, b, h, ms, n, http} = c
  Client{api, b, HttpPure.set(h, String.to_lower(k), v), ms, n, http}

def timeout(c: Client, +ms: U32) -> Client:
  Client{api, b, h, old, n, http} = c
  Client{api, b, h, ms, n, Hairpin.timeout(http, ms)}

def retry(c: Client, n: U32) -> Client:
  Client{api, b, h, ms, old, http} = c
  Client{api, b, h, ms, n, http}

def close(c: Client) -> IO(Unit):
  Client{api, b, h, ms, n, http} = c
  Hairpin.close(http)

def call.done(+api: Api, base: String, headers: Map<&2, List<&2, String>>, +ms: U32, +n: U32,
    x: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res>) -> Client & Result<&1, &1, Err, Bytes.Bytes>:
  (h, b, r) = x
  (Client{api, base, headers, ms, n, h}, body.of(r))

def call.budget(+api: Api, +base: String, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, y: Hairpin.Client & Retry.Budget) ->
    IO(Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res>):
  (h, b) = y
  do IO<Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res>>:
    enc : String <- Http.codings()
    Hairpin.request.as(~again, h, b, True{}, enc, "POST", url(api, base), headers, body)

# POST body to the API with n retries on a budget of n + 1; the 2xx body comes back.
# These POSTs are safe to repeat, so Hairpin retries them as again judges.
def call(c: Client, body: Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, Bytes.Bytes>):
  Client{+api, +base, +headers, +ms, +n, h} = c
  do IO<Client & Result<&1, &1, Err, Bytes.Bytes>>:
    y : Hairpin.Client & Retry.Budget <- Hairpin.budget(Hairpin.retry(h, n))
    x : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res> <- call.budget(api, base, headers, body, y)
    return call.done(api, base, headers, ms, n, x)

def raw.got(b: Bytes.Bytes, m: Maybe<&1, Json.Val>) -> Result<&1, &1, Err, Json.Val>:
  match m:
    case None{}:
      Fail{ErrReply{Enc.utf8.decode(b)}}
    case Some{v}:
      Done{v}

def raw.copy(r: Bytes.Bytes & Bytes.Bytes) -> Result<&1, &1, Err, Json.Val>:
  (b, c) = r
  raw.got(b, Json.parse.bytes(c))

def raw.of(r: Result<&1, &1, Err, Bytes.Bytes>) -> Result<&1, &1, Err, Json.Val>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      raw.copy(Bytes.slice(b, 0, 4294967295))

def raw.done(x: Client & Result<&1, &1, Err, Bytes.Bytes>) -> Client & Result<&1, &1, Err, Json.Val>:
  (c, r) = x
  (c, raw.of(r))

# Any request body, as for tools or images, and the reply as JSON.
def send.raw(c: Client, v: Json.Val) -> IO(Client & Result<&1, &1, Err, Json.Val>):
  do IO<Client & Result<&1, &1, Err, Json.Val>>:
    x : Client & Result<&1, &1, Err, Bytes.Bytes> <- call(c, Json.encode.bytes(v))
    return raw.done(x)

def send.of(r: Result<&1, &1, Err, Bytes.Bytes>, +api: Api) -> Result<&1, &1, Err, Reply>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      reply(api, b)

def send.done(+api: Api, x: Client & Result<&1, &1, Err, Bytes.Bytes>) -> Client & Result<&1, &1, Err, Reply>:
  (c, r) = x
  (c, send.of(r, api))

# One whole reply.
def send(c: Client, req: Req) -> IO(Client & Result<&1, &1, Err, Reply>):
  Client{+api, b, h, ms, n, http} = c
  do IO<Client & Result<&1, &1, Err, Reply>>:
    x : Client & Result<&1, &1, Err, Bytes.Bytes> <- call(Client{api, b, h, ms, n, http}, Json.encode.bytes(body(api, req, False{})))
    return send.done(api, x)

# ---- streams

type Stream is Type:
  Stream{api: Api, h: Http.Stream, rd: Sse.Reader}

def open.res(x: Http.Stream & HttpPure.Res) -> Result<&1, &1, HttpPure.Err, Http.Stream> & HairpinPure.Verdict:
  (st, res) = x
  HttpPure.Res{+status, +h, b} = res
  (Done{st}, verdict(again.of(status, h), HairpinPure.judge.status(status)))

def open.judge(r: Result<&1, &1, HttpPure.Err, Http.Stream>) -> Result<&1, &1, HttpPure.Err, Http.Stream> & HairpinPure.Verdict:
  match r:
    case Fail{+e}:
      (Fail{e}, verdict(again.err(e), HairpinPure.VerdictTarget{}))
    case Done{st}:
      open.res(Http.stream.res(st))

# A refused stream's error body, at most f more pieces; only a complete body returns its connection.
def drain(f: Nat, c: Hairpin.Client, x: Http.Stream & Result<&1, &1, HttpPure.Err, Maybe<&1, Bytes.Bytes>>, acc: Bytes.Bytes) -> IO(Hairpin.Client & Bytes.Bytes):
  match f:
    case 0n:
      (h, r) = x
      do IO<Hairpin.Client & Bytes.Bytes>:
        Http.stream.close(h)
        return (c, acc)
    case 1n+g:
      (h, r) = x
      match r:
        case Fail{e}:
          do IO<Hairpin.Client & Bytes.Bytes>:
            Http.stream.close(h)
            return (c, acc)
        case Done{m}:
          match m:
            case None{}:
              do IO<Hairpin.Client & Bytes.Bytes>:
                p : Hairpin.Client <- Hairpin.stream.close(c, h)
                return (p, acc)
            case Some{b}:
              do IO<Hairpin.Client & Bytes.Bytes>:
                merged : Bytes.Bytes = Bytes.append(acc, b)
                y : Http.Stream & Result<&1, &1, HttpPure.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(h)
                drain(g, c, y, merged)

def start.error(+status: U32, x: Hairpin.Client & Bytes.Bytes) -> Hairpin.Client & Result<&1, &1, Err, Http.Stream>:
  (c, b) = x
  (c, Fail{ErrApi{status, Enc.utf8.decode(b)}})

def start.refused(+status: U32, c: Hairpin.Client, h: Http.Stream) -> IO(Hairpin.Client & Result<&1, &1, Err, Http.Stream>):
  do IO<Hairpin.Client & Result<&1, &1, Err, Http.Stream>>:
    y : Http.Stream & Result<&1, &1, HttpPure.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(h)
    x : Hairpin.Client & Bytes.Bytes <- drain(64n, c, y, Bytes.new(0))
    return start.error(status, x)

def start.ok(good: Bool, +status: U32, c: Hairpin.Client, h: Http.Stream) -> IO(Hairpin.Client & Result<&1, &1, Err, Http.Stream>):
  match good:
    case True{}:
      IO.pure(Hairpin.Client & Result<&1, &1, Err, Http.Stream>, (c, Done{h}))
    case False{}:
      start.refused(status, c, h)

def start.res(c: Hairpin.Client, x: Http.Stream & HttpPure.Res) -> IO(Hairpin.Client & Result<&1, &1, Err, Http.Stream>):
  (h, res) = x
  HttpPure.Res{+status, hd, b} = res
  start.ok(ok(status), status, c, h)

def start(c: Hairpin.Client, r: Result<&1, &1, Hairpin.Err, Http.Stream>) -> IO(Hairpin.Client & Result<&1, &1, Err, Http.Stream>):
  match r:
    case Fail{e}:
      IO.pure(Hairpin.Client & Result<&1, &1, Err, Http.Stream>, (c, Fail{ErrNet{e}}))
    case Done{h}:
      start.res(c, Http.stream.res(h))

def stream.of(r: Result<&1, &1, Err, Http.Stream>, +api: Api) -> Result<&1, &1, Err, Stream>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{h}:
      Done{Stream{api, h, Sse.reader()}}

def stream.result(+api: Api, base: String, headers: Map<&2, List<&2, String>>, +ms: U32, +n: U32,
    x: Hairpin.Client & Result<&1, &1, Err, Http.Stream>) -> Client & Result<&1, &1, Err, Stream>:
  (h, s) = x
  (Client{api, base, headers, ms, n, h}, stream.of(s, api))

def stream.done(+api: Api, base: String, headers: Map<&2, List<&2, String>>, +ms: U32, +n: U32,
    x: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream>) -> IO(Client & Result<&1, &1, Err, Stream>):
  (h, b, r) = x
  do IO<Client & Result<&1, &1, Err, Stream>>:
    y : Hairpin.Client & Result<&1, &1, Err, Http.Stream> <- start(h, r)
    return stream.result(api, base, headers, ms, n, y)

def open.budget(+api: Api, +base: String, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, y: Hairpin.Client & Retry.Budget) ->
    IO(Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream>):
  (h, b) = y
  do IO<Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream>>:
    enc : String <- Http.codings()
    Hairpin.open.as(~open.judge, h, b, True{}, enc, "POST", url(api, base), headers, body)

# Any request body that asks for SSE, as for tools. The open retries as call does, on a budget of n + 1.
# A stream opens on the client's pool. Close it with stream.close to give its connection back.
def stream.raw(c: Client, v: Json.Val) -> IO(Client & Result<&1, &1, Err, Stream>):
  Client{+api, +base, +headers, +ms, +n, h} = c
  do IO<Client & Result<&1, &1, Err, Stream>>:
    y : Hairpin.Client & Retry.Budget <- Hairpin.budget(Hairpin.retry(h, n))
    x : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream> <- open.budget(api, base, headers, Json.encode.bytes(v), y)
    stream.done(api, base, headers, ms, n, x)

# The reply as it is written: read it with next.
def stream(c: Client, req: Req) -> IO(Client & Result<&1, &1, Err, Stream>):
  Client{+api, b, h, ms, n, http} = c
  stream.raw(Client{api, b, h, ms, n, http}, body(api, req, True{}))

# Close a stream. A stream read to its end gives its connection to the client's pool.
def stream.close(c: Client, s: Stream) -> IO(Client):
  Client{api, base, headers, ms, n, h} = c
  Stream{sa, st, rd} = s
  do IO<Client>:
    p : Hairpin.Client <- Hairpin.stream.close(h, st)
    return Client{api, base, headers, ms, n, p}

# The reader after the next event, or the stream's result.
type Rn is Type:
  RnNext{h: Http.Stream, r: Sse.Reader & Sse.Next}
  RnOut{h: Http.Stream, rd: Sse.Reader, r: Result<&1, &1, Err, Maybe<&1, Sse.Message>>}

def event.read(rd: Sse.Reader, x: Http.Stream & Result<&1, &1, HttpPure.Err, Maybe<&1, Bytes.Bytes>>) -> Rn:
  (h, r) = x
  match r:
    case Fail{e}:
      RnOut{h, rd, Fail{ErrNet{Hairpin.ErrHttp{e}}}}
    case Done{m}:
      match m:
        case None{}:
          RnOut{h, rd, Done{None{}}}
        case Some{b}:
          RnNext{h, Sse.next(Sse.feed(rd, b))}

# f: pieces left to read before the stream counts as stalled.
def event.loop(f: Nat, st: Rn) -> IO(Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>>):
  match f:
    case 0n:
      match st:
        case RnNext{h, r}:
          (rd, n) = r
          IO.pure(Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>>, (h, rd, Fail{ErrReply{"too many pieces without an event"}}))
        case RnOut{h, rd, r}:
          IO.pure(Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>>, (h, rd, r))
    case 1n+g:
      match st:
        case RnNext{h, r}:
          (rd, n) = r
          match n:
            case Sse.Got{e}:
              IO.pure(Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>>, (h, rd, Done{Some{e}}))
            case Sse.Want{}:
              do IO<Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>>>:
                x : Http.Stream & Result<&1, &1, HttpPure.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(h)
                event.loop(g, event.read(rd, x))
        case RnOut{h, rd, r}:
          IO.pure(Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>>, (h, rd, r))

def event.done(+api: Api, x: Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>>) -> Stream & Result<&1, &1, Err, Maybe<&1, Sse.Message>>:
  (h, rd, r) = x
  (Stream{api, h, rd}, r)

# The next SSE event, or None when the stream ends. An event the end cuts off is dropped.
def event(s: Stream) -> IO(Stream & Result<&1, &1, Err, Maybe<&1, Sse.Message>>):
  Stream{+api, h, rd} = s
  do IO<Stream & Result<&1, &1, Err, Maybe<&1, Sse.Message>>>:
    x : Http.Stream & Sse.Reader & Result<&1, &1, Err, Maybe<&1, Sse.Message>> <- event.loop(Nat.mul(65536n, 256n), RnNext{h, Sse.next(rd)})
    return event.done(api, x)

def next.ev(r: Result<&1, &1, Err, Maybe<&1, Sse.Message>>, +api: Api) -> Ev:
  match r:
    case Fail{e}:
      EFail{e}
    case Done{m}:
      match m:
        case None{}:
          EEnd{}
        case Some{e}:
          ev(api, e)

def next.of(x: Stream & Result<&1, &1, Err, Maybe<&1, Sse.Message>>) -> Stream & Ev:
  (s, r) = x
  Stream{+api, h, rd} = s
  (Stream{api, h, rd}, next.ev(r, api))

# f: events left to skip.
def next.loop(f: Nat, x: Stream & Ev) -> IO(Stream & Result<&1, &1, Err, Maybe<&2, String>>):
  match f:
    case 0n:
      (s, e) = x
      IO.pure(Stream & Result<&1, &1, Err, Maybe<&2, String>>, (s, Fail{ErrReply{"too many events without text"}}))
    case 1n+g:
      (s, e) = x
      match e:
        case EText{t}:
          IO.pure(Stream & Result<&1, &1, Err, Maybe<&2, String>>, (s, Done{Some{t}}))
        case EEnd{}:
          IO.pure(Stream & Result<&1, &1, Err, Maybe<&2, String>>, (s, Done{None{}}))
        case EFail{err}:
          IO.pure(Stream & Result<&1, &1, Err, Maybe<&2, String>>, (s, Fail{err}))
        case ESkip{}:
          do IO<Stream & Result<&1, &1, Err, Maybe<&2, String>>>:
            y : Stream & Result<&1, &1, Err, Maybe<&1, Sse.Message>> <- event(s)
            next.loop(g, next.of(y))

# The next piece of reply text, or None at the end.
def next(s: Stream) -> IO(Stream & Result<&1, &1, Err, Maybe<&2, String>>):
  do IO<Stream & Result<&1, &1, Err, Maybe<&2, String>>>:
    y : Stream & Result<&1, &1, Err, Maybe<&1, Sse.Message>> <- event(s)
    next.loop(Nat.mul(65536n, 256n), next.of(y))
