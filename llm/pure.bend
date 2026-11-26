import Base
import ./sse.bend as Sse
import bend-kit-json@0.7.3.1/json.bend as Json
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import bend-kit-encoding@0.5.0.2/encoding.bend as Enc

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

type Err is Data:
  ErrApi{status: U32, body: String}
  ErrReply{body: String}

# ---- JSON

def str(s: String) -> Json.Val:
  Json.Str{Json.utf8(s)}

def kv(k: String, v: Json.Val) -> Bytes.Bytes & Json.Val:
  (Json.utf8(k), v)

def num(+n: U32) -> Json.Val:
  Json.Num{Bytes.u32.show(n)}

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
