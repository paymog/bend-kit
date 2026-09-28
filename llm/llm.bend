# LLM client for the Anthropic Messages and OpenAI Chat Completions APIs, with SSE streaming. Source: https://github.com/paymog/bend-kit/tree/main/llm
import Base
import ./sse.bend as Sse
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
# By hash, as http imports them: bend-kit-json@0.5.0.1, -bytes@0.3.0.0, -encoding@0.3.0.0.
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import 0xcfc8be7b076f41f95c8e118383892d55/encoding.bend as Enc

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

# ErrNet: the request did not complete. ErrApi: the API refused, with its status and error text; an error
# event in a stream has status 200. ErrReply: a reply that is not the API's JSON, with its text.
type Err is Data:
  ErrNet{e: Http.Err}
  ErrApi{status: U32, body: String}
  ErrReply{body: String}

# headers go on every request. ms: the step timeout. retries: extra tries after a retryable failure.
type Client is Type:
  Client{api: Api, base: String, headers: Map<&2, List<&2, String>>, ms: U32, retries: U32, http: Hairpin.Client}

# ---- JSON

def str(s: String) -> Json.Val:
  Json.Str{Json.utf8(s)}

def kv(k: String, v: Json.Val) -> Bytes.Bytes & Json.Val:
  (Json.utf8(k), v)

def num(+n: U32) -> Json.Val:
  Json.Num{Bytes.from_string(U32.show(n))}

def obj(kvs: List<&1, Bytes.Bytes & Json.Val>) -> Json.Val:
  Json.Obj{kvs}

def when(on: Bool, x: Bytes.Bytes & Json.Val, xs: List<&1, Bytes.Bytes & Json.Val>) -> List<&1, Bytes.Bytes & Json.Val>:
  match on:
    case True{}:
      Con{x, xs}
    case False{}:
      xs

def role(r: Role) -> String:
  match r:
    case User{}:
      "user"
    case Assistant{}:
      "assistant"

def msg(+r: String, t: String) -> Json.Val:
  obj([kv("role", str(r)), kv("content", str(t))])

def msgs(xs: List<&2, Msg>) -> List<&1, Json.Val>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Msg{r, t}, rest}:
      Con{msg(role(r), t), msgs(rest)}

def sys(on: Bool, s: String, xs: List<&1, Json.Val>) -> List<&1, Json.Val>:
  match on:
    case True{}:
      Con{msg("system", s), xs}
    case False{}:
      xs

# The request body for api. stream asks for SSE.
def body(api: Api, req: Req, stream: Bool) -> Json.Val:
  match api:
    case Anthropic{}:
      Req{model, +system, ms, max} = req
      obj(Con{kv("model", str(model)), Con{kv("max_tokens", num(max)),
        when(Bool.not(String.is_empty(system)), kv("system", str(system)),
          Con{kv("messages", Json.Arr{msgs(ms)}), when(stream, kv("stream", Json.Flag{True{}}), Nil{})})}})
    case OpenAI{}:
      Req{model, +system, ms, max} = req
      obj(Con{kv("model", str(model)), Con{kv("max_completion_tokens", num(max)),
        Con{kv("messages", Json.Arr{sys(Bool.not(String.is_empty(system)), system, msgs(ms))}),
          when(stream, kv("stream", Json.Flag{True{}}), Nil{})}}})

# A JSON leaf: its path, as "content.0.text", and its text.
type Leaf is Data:
  Leaf{p: String, v: String}

def path(+p: String, +k: String) -> String:
  Bool.pick(String, String.is_empty(p), k, p ++ "." ++ k)

def push.arr(xs: List<&1, Json.Val>, +p: String, +i: U32, t: List<&1, String & Json.Val>) -> List<&1, String & Json.Val>:
  match xs:
    case Nil{}:
      t
    case Con{x, rest}:
      Con{(path(p, U32.show(i)), x), push.arr(rest, p, (i + 1 : U32), t)}

def push.obj(kvs: List<&1, Bytes.Bytes & Json.Val>, +p: String, t: List<&1, String & Json.Val>) -> List<&1, String & Json.Val>:
  match kvs:
    case Nil{}:
      t
    case Con{(k, x), rest}:
      Con{(path(p, Enc.utf8.decode(k)), x), push.obj(rest, p, t)}

# The leaves under the stack's values, last first. f: at least the values left.
def flat(f: Nat, stack: List<&1, String & Json.Val>, acc: List<&2, Leaf>) -> List<&2, Leaf>:
  match f:
    case 0n:
      acc
    case 1n+g:
      match stack:
        case Nil{}:
          acc
        case Con{(p, v), t}:
          match v:
            case Json.Null{}:
              flat(g, t, acc)
            case Json.Flag{on}:
              flat(g, t, Con{Leaf{p, Bool.pick(String, on, "true", "false")}, acc})
            case Json.Num{s}:
              flat(g, t, Con{Leaf{p, Bytes.to_string(s)}, acc})
            case Json.Str{s}:
              flat(g, t, Con{Leaf{p, Enc.utf8.decode(s)}, acc})
            case Json.Arr{xs}:
              flat(g, push.arr(xs, p, 0, t), acc)
            case Json.Obj{kvs}:
              flat(g, push.obj(kvs, p, t), acc)

def doc.of(+n: U32, m: Maybe<&1, Json.Val>) -> Maybe<&2, List<&2, Leaf>>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      Some{List.reverse(&2, Leaf, flat(Nat.add(U32.to_nat(n), 1n), [("", v)], Nil{}))}

# Every non-null leaf of a JSON text in document order, keyed by its path, as ("content.0.text", "Hi").
# Strings are decoded; numbers keep their text. None when b is not JSON. Each value takes a byte, so n + 1 steps suffice.
def doc(b: Bytes.Bytes) -> Maybe<&2, List<&2, Leaf>>:
  Bytes.Bytes{+n, buf} = b
  doc.of(n, Json.parse.bytes(Bytes.Bytes{n, buf}))

# The first value at path k, or "".
def look(d: List<&2, Leaf>, +k: String) -> String:
  match d:
    case Nil{}:
      ""
    case Con{Leaf{p, v}, t}:
      Bool.pick(String, String.eq(p, k), v, look(t, k))

def count(s: String) -> U32:
  Maybe.default(&2, U32, Json.u32.num(s), 0)

def dots(s: String, +n: U32) -> U32:
  match s:
    case SNil{}:
      n
    case SCon{Chr{+c}, t}:
      dots(t, Bool.pick(U32, U32.is_eq(c, 46), (n + 1 : U32), n))

# Is p the text of a content block, "content.<i>.text"?
def block(+p: String) -> Bool:
  Bool.and(Bool.and(String.starts_with(p, "content."), String.ends_with(p, ".text")), U32.is_eq(dots(p, 0), 2))

# The text blocks of an Anthropic message, joined.
def blocks(d: List<&2, Leaf>) -> String:
  match d:
    case Nil{}:
      ""
    case Con{Leaf{+p, v}, t}:
      Bool.pick(String, block(p), v, "") ++ blocks(t)

def reply.of(api: Api, +d: List<&2, Leaf>) -> Reply:
  match api:
    case Anthropic{}:
      Reply{look(d, "id"), look(d, "model"), blocks(d), look(d, "stop_reason"),
        count(look(d, "usage.input_tokens")), count(look(d, "usage.output_tokens"))}
    case OpenAI{}:
      Reply{look(d, "id"), look(d, "model"), look(d, "choices.0.message.content"), look(d, "choices.0.finish_reason"),
        count(look(d, "usage.prompt_tokens")), count(look(d, "usage.completion_tokens"))}

def reply.got(api: Api, b: Bytes.Bytes, m: Maybe<&2, List<&2, Leaf>>) -> Result<&1, &1, Err, Reply>:
  match m:
    case None{}:
      Fail{ErrReply{Enc.utf8.decode(b)}}
    case Some{d}:
      Done{reply.of(api, d)}

def reply.copy(api: Api, r: Bytes.Bytes & Bytes.Bytes) -> Result<&1, &1, Err, Reply>:
  (b, c) = r
  reply.got(api, b, doc(c))

# A 2xx response body as a Reply.
def reply(api: Api, b: Bytes.Bytes) -> Result<&1, &1, Err, Reply>:
  reply.copy(api, Bytes.slice(b, 0, 4294967295))

# ---- stream events

# A text piece, the end, an error, or an event with no text.
type Ev is Data:
  EText{s: String}
  EEnd{}
  EFail{e: Err}
  ESkip{}

def ev.text(+s: String) -> Ev:
  Bool.pick(Ev, String.is_empty(s), ESkip{}, EText{s})

def ev.doc(m: Maybe<&2, List<&2, Leaf>>) -> List<&2, Leaf>:
  Maybe.default(&2, List<&2, Leaf>, m, Nil{})

def ev.anthropic(+name: String, data: Bytes.Bytes) -> Ev:
  +d = ev.doc(doc(data))
  Bool.pick(Ev, String.eq(name, "content_block_delta"), ev.text(look(d, "delta.text")),
    Bool.pick(Ev, String.eq(name, "message_stop"), EEnd{},
      Bool.pick(Ev, String.eq(name, "error"), EFail{ErrApi{200, look(d, "error.message")}}, ESkip{})))

def ev.openai(+s: String) -> Ev:
  +d = ev.doc(doc(Bytes.from_string(s)))
  +why = look(d, "error.message")
  Bool.pick(Ev, String.eq(s, "[DONE]"), EEnd{},
    Bool.pick(Ev, String.is_empty(why), ev.text(look(d, "choices.0.delta.content")), EFail{ErrApi{200, why}}))

# What one SSE event of api means.
def ev(api: Api, e: Sse.Message) -> Ev:
  match api:
    case Anthropic{}:
      Sse.Message{name, data, id} = e
      ev.anthropic(name, data)
    case OpenAI{}:
      Sse.Message{name, data, id} = e
      ev.openai(Bytes.to_string(data))

# ---- requests

def ok(+s: U32) -> Bool:
  Bool.and(U32.is_le(200, s), U32.is_lt(s, 300))

# Statuses a later try may clear: 408, 409, 429, and 5xx, which holds Anthropic's 529.
def again.status(+s: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(s, 408), U32.is_eq(s, 409)), Bool.or(U32.is_eq(s, 429), U32.is_le(500, s)))

# A refused connect or a timeout may clear.
def again.err(+e: Http.Err) -> Maybe<&2, String>:
  match e:
    case Http.ErrConnect{code, why}:
      Some{""}
    case Http.ErrTimeout{}:
      Some{""}
    case other:
      None{}

def again.of(+status: U32, +h: Map<&2, List<&2, String>>) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, again.status(status), Some{Http.header(h, "retry-after")}, None{})

# The result, with Some{Retry-After} when another try may help.
def again(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  match r:
    case Fail{+e}:
      (Fail{e}, again.err(e))
    case Done{res}:
      Http.Res{+status, +h, b} = res
      (Done{Http.Res{status, h, b}}, again.of(status, h))

def post.judged(h: Hairpin.Client, body: Bytes.Bytes, j: Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) ->
    Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  (r, m) = j
  (h, body, r, m)

def post.kept(body: Bytes.Bytes, x: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) ->
    Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  (h, r) = x
  post.judged(h, body, again(r))

def post.once(+url: String, +headers: Map<&2, List<&2, String>>, h: Hairpin.Client, r: Bytes.Bytes & Bytes.Bytes) ->
    IO(Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>):
  (body, spare) = r
  do IO<Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>>:
    x : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- Hairpin.request(h, "POST", url, headers, spare)
    return post.kept(body, x)

# left: retries still allowed. n: the retry to wait for next, 0 first. The wait is Retry-After, else Http's backoff.
def post.go(left: Nat, +n: Nat, +url: String, +headers: Map<&2, List<&2, String>>,
    t: Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) ->
    IO(Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>):
  match left:
    case 0n:
      (h, body, r, m) = t
      IO.pure(Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>, (h, r))
    case 1n+rest:
      (h, body, r, m) = t
      match m:
        case None{}:
          IO.pure(Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>, (h, r))
        case Some{v}:
          do IO<Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>>:
            Http.retry.sleep(v, n)
            tried : Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String> <-
              post.once(url, headers, h, Bytes.slice(body, 0, 4294967295))
            post.go(rest, 1n+n, url, headers, tried)

# POST body, then retry. Hairpin retries only idempotent methods, and these POSTs are safe to repeat.
def post(+retries: U32, +url: String, +headers: Map<&2, List<&2, String>>, h: Hairpin.Client, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>):
  do IO<Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>>:
    first : Hairpin.Client & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String> <-
      post.once(url, headers, h, Bytes.slice(body, 0, 4294967295))
    post.go(U32.to_nat(retries), 0n, url, headers, first)

def body.ok(good: Bool, +status: U32, b: Bytes.Bytes) -> Result<&1, &1, Err, Bytes.Bytes>:
  match good:
    case True{}:
      Done{b}
    case False{}:
      Fail{ErrApi{status, Enc.utf8.decode(b)}}

# The 2xx body, or why there is none.
def body.of(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Err, Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{ErrNet{e}}
    case Done{res}:
      Http.Res{+status, h, b} = res
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
  Http.set(h, "content-type", "application/json")

# base https://api.anthropic.com, 10 min steps, 2 retries.
def anthropic(key: String) -> Client:
  new(Anthropic{}, "https://api.anthropic.com", json(Http.set(Http.set(Http.empty(), "x-api-key", key), "anthropic-version", "2023-06-01")))

# base https://api.openai.com/v1, 10 min steps, 2 retries.
def openai(key: String) -> Client:
  new(OpenAI{}, "https://api.openai.com/v1", json(Http.set(Http.empty(), "authorization", "Bearer " ++ key)))

# Another base URL, as for a provider that serves the same API.
def base(c: Client, url: String) -> Client:
  Client{api, old, h, ms, n, http} = c
  Client{api, url, h, ms, n, http}

# A header on every request, as anthropic-beta. It replaces one of the same name.
def header(c: Client, k: String, v: String) -> Client:
  Client{api, b, h, ms, n, http} = c
  Client{api, b, Http.set(h, String.to_lower(k), v), ms, n, http}

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
    x: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) -> Client & Result<&1, &1, Err, Bytes.Bytes>:
  (h, r) = x
  (Client{api, base, headers, ms, n, h}, body.of(r))

# POST body to the API, with retries; the 2xx body comes back.
def call(c: Client, body: Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, Bytes.Bytes>):
  Client{+api, +base, +headers, +ms, +n, h} = c
  do IO<Client & Result<&1, &1, Err, Bytes.Bytes>>:
    x : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- post(n, url(api, base), headers, h, body)
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

def open.res(x: Http.Stream & Http.Res) -> Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>:
  (st, res) = x
  Http.Res{+status, +h, b} = res
  (Done{st}, again.of(status, h))

def open.judge(r: Result<&1, &1, Http.Err, Http.Stream>) -> Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>:
  match r:
    case Fail{+e}:
      (Fail{e}, again.err(e))
    case Done{st}:
      open.res(Http.stream.res(st))

def open.kept(body: Bytes.Bytes, j: Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>) -> Bytes.Bytes & Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>:
  (r, m) = j
  (body, r, m)

def open.once(+url: String, +headers: Map<&2, List<&2, String>>, +ms: U32, r: Bytes.Bytes & Bytes.Bytes) ->
    IO(Bytes.Bytes & Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>):
  (body, spare) = r
  do IO<Bytes.Bytes & Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>>:
    s : Result<&1, &1, Http.Err, Http.Stream> <- Http.open.with("POST", url, headers, spare, ms)
    return open.kept(body, open.judge(s))

def open.drop(r: Result<&1, &1, Http.Err, Http.Stream>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.pure(Unit, Unit{})
    case Done{st}:
      Http.stream.close(st)

# As post.go, but a refused stream closes before the next try.
def open.go(left: Nat, +n: Nat, +url: String, +headers: Map<&2, List<&2, String>>, +ms: U32,
    t: Bytes.Bytes & Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>) -> IO(Result<&1, &1, Http.Err, Http.Stream>):
  match left:
    case 0n:
      (body, r, m) = t
      IO.pure(Result<&1, &1, Http.Err, Http.Stream>, r)
    case 1n+rest:
      (body, r, m) = t
      match m:
        case None{}:
          IO.pure(Result<&1, &1, Http.Err, Http.Stream>, r)
        case Some{v}:
          do IO<Result<&1, &1, Http.Err, Http.Stream>>:
            open.drop(r)
            Http.retry.sleep(v, n)
            tried : Bytes.Bytes & Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String> <- open.once(url, headers, ms, Bytes.slice(body, 0, 4294967295))
            open.go(rest, 1n+n, url, headers, ms, tried)

# A refused stream's error body, at most f more pieces, then the stream closed.
def drain(f: Nat, x: Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>>, acc: Bytes.Bytes) -> IO(Bytes.Bytes):
  match f:
    case 0n:
      (h, r) = x
      do IO<Bytes.Bytes>:
        Http.stream.close(h)
        return acc
    case 1n+g:
      (h, r) = x
      match r:
        case Fail{e}:
          do IO<Bytes.Bytes>:
            Http.stream.close(h)
            return acc
        case Done{m}:
          match m:
            case None{}:
              do IO<Bytes.Bytes>:
                Http.stream.close(h)
                return acc
            case Some{b}:
              do IO<Bytes.Bytes>:
                y : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(h)
                drain(g, y, Bytes.append(acc, b))

def start.refused(+status: U32, h: Http.Stream) -> IO(Result<&1, &1, Err, Http.Stream>):
  do IO<Result<&1, &1, Err, Http.Stream>>:
    y : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(h)
    b : Bytes.Bytes <- drain(64n, y, Bytes.new(0))
    return Fail{ErrApi{status, Enc.utf8.decode(b)}}

def start.ok(good: Bool, +status: U32, h: Http.Stream) -> IO(Result<&1, &1, Err, Http.Stream>):
  match good:
    case True{}:
      IO.pure(Result<&1, &1, Err, Http.Stream>, Done{h})
    case False{}:
      start.refused(status, h)

def start.res(x: Http.Stream & Http.Res) -> IO(Result<&1, &1, Err, Http.Stream>):
  (h, res) = x
  Http.Res{+status, hd, b} = res
  start.ok(ok(status), status, h)

def start(r: Result<&1, &1, Http.Err, Http.Stream>) -> IO(Result<&1, &1, Err, Http.Stream>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Http.Stream>, Fail{ErrNet{e}})
    case Done{h}:
      start.res(Http.stream.res(h))

def stream.of(r: Result<&1, &1, Err, Http.Stream>, +api: Api) -> Result<&1, &1, Err, Stream>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{h}:
      Done{Stream{api, h, Sse.reader()}}

# Any request body that asks for SSE, as for tools. A stream opens its own connection, outside the pool.
def stream.raw(c: Client, v: Json.Val) -> IO(Client & Result<&1, &1, Err, Stream>):
  Client{+api, +base, +headers, +ms, +n, h} = c
  do IO<Client & Result<&1, &1, Err, Stream>>:
    first : Bytes.Bytes & Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String> <- open.once(url(api, base), headers, ms, Bytes.slice(Json.encode.bytes(v), 0, 4294967295))
    r : Result<&1, &1, Http.Err, Http.Stream> <- open.go(U32.to_nat(n), 0n, url(api, base), headers, ms, first)
    s : Result<&1, &1, Err, Http.Stream> <- start(r)
    return (Client{api, base, headers, ms, n, h}, stream.of(s, api))

# The reply as it is written: read it with next.
def stream(c: Client, req: Req) -> IO(Client & Result<&1, &1, Err, Stream>):
  Client{+api, b, h, ms, n, http} = c
  stream.raw(Client{api, b, h, ms, n, http}, body(api, req, True{}))

def stream.close(s: Stream) -> IO(Unit):
  Stream{api, h, rd} = s
  Http.stream.close(h)

# The reader after the next event, or the stream's result.
type Rn is Type:
  RnNext{h: Http.Stream, r: Sse.Reader & Sse.Next}
  RnOut{h: Http.Stream, rd: Sse.Reader, r: Result<&1, &1, Err, Maybe<&1, Sse.Message>>}

def event.read(rd: Sse.Reader, x: Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>>) -> Rn:
  (h, r) = x
  match r:
    case Fail{e}:
      RnOut{h, rd, Fail{ErrNet{e}}}
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
                x : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(h)
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
