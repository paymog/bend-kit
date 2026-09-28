import Base
import ./llm.bend as Llm
import ./sse.bend as Sse
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def b(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

# ---- SSE

def drain(f: Nat, r: Sse.Reader & Sse.Next, acc: List<&1, Sse.Message>) -> Sse.Reader & List<&1, Sse.Message>:
  match f:
    case 0n:
      (rd, n) = r
      (rd, acc)
    case 1n+g:
      (rd, n) = r
      match n:
        case Sse.Got{e}:
          drain(g, Sse.next(rd), Con{e, acc})
        case Sse.Want{}:
          (rd, acc)

def feed(pieces: List<&2, String>, r: Sse.Reader & List<&1, Sse.Message>) -> Sse.Reader & List<&1, Sse.Message>:
  match pieces:
    case Nil{}:
      r
    case Con{h, t}:
      (rd, acc) = r
      feed(t, drain(64n, Sse.next(Sse.feed(rd, b(h))), acc))

def got(r: Sse.Reader & List<&1, Sse.Message>) -> List<&1, Sse.Message>:
  (rd, acc) = r
  List.reverse(&1, Sse.Message, acc)

# The events the pieces give, fed one at a time.
def events(pieces: List<&2, String>) -> List<&1, Sse.Message>:
  got(feed(pieces, (Sse.reader(), Nil{})))

def show(xs: List<&1, Sse.Message>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Sse.Message{name, data, id}, t}:
      Con{name ++ "|" ++ Bytes.to_string(data) ++ "|" ++ id, show(t)}

def sse(pieces: List<&2, String>) -> List<&2, String>:
  show(events(pieces))

def retried.of(r: Sse.Reader & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (rd, m) = r
  m

def retried(r: Sse.Reader & List<&1, Sse.Message>) -> Maybe<&2, U32>:
  (rd, acc) = r
  retried.of(Sse.retry(rd))

def ones(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      Con{SCon{c, SNil{}}, ones(t)}

def twos(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      match t:
        case SNil{}:
          [SCon{c, SNil{}}]
        case SCon{d, u}:
          Con{SCon{c, SCon{d, SNil{}}}, twos(u)}

def threes(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      match t:
        case SNil{}:
          [SCon{c, SNil{}}]
        case SCon{d, u}:
          match u:
            case SNil{}:
              [SCon{c, SCon{d, SNil{}}}]
            case SCon{e, v}:
              Con{SCon{c, SCon{d, SCon{e, SNil{}}}}, threes(v)}

# CRLF, LF, and CR line ends; a comment; a value with two spaces; a field with no colon; an event
# with no data; an id with no value; and a last event that no blank line ends.
def stream() -> String:
  ": hello\r\nevent: add\r\ndata: first\r\ndata:  second\r\nid: 42\r\n\r\nretry: 1500\ndata\n\nevent: gone\n\ndata: x\rid\r\rdata: tail"

def want() -> List<&2, String>:
  ["add|first\n second|42", "message||42", "message|x|"]

law sse_whole:
  {sse([stream()]) == want() : List<&2, String>}

# However the bytes are cut into pieces, the events are the same.
law sse_ones:
  {sse(ones(stream())) == want() : List<&2, String>}

law sse_twos:
  {sse(twos(stream())) == want() : List<&2, String>}

law sse_threes:
  {sse(threes(stream())) == want() : List<&2, String>}

# A CR that ends one piece and an LF that starts the next make one line end.
law sse_crlf_cut:
  {sse(["data: a\r", "\n", "\r", "\ndata: b\r\n\r\n"]) == ["message|a|", "message|b|"] : List<&2, String>}

law sse_cr_blank:
  {sse(["data: a\r\r"]) == ["message|a|"] : List<&2, String>}

law sse_retry:
  {retried(feed([stream()], (Sse.reader(), Nil{}))) == Some{1500} : Maybe<&2, U32>}

law sse_retry_bad:
  {retried(feed(["retry: 15x\nretry: 7\nretry:\nretry: 1234567890\n"], (Sse.reader(), Nil{}))) == Some{7} : Maybe<&2, U32>}

# Field names are exact; unknown fields are ignored.
law sse_names:
  {sse(["datum: no\nDATA: no\ndata2: no\nfoo: bar\ndata: yes\n\n"]) == ["message|yes|"] : List<&2, String>}

# An id that holds NUL is ignored; an id persists to later events.
law sse_id:
  {sse(["id: 1\ndata: a\n\nid: 2" ++ SCon{Chr{0}, "\ndata: b\n\n"}]) == ["message|a|1", "message|b|1"] : List<&2, String>}

# ---- replies

def anthropic.body() -> String:
  "{\"id\":\"msg_1\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-x\",\"content\":[{\"type\":\"text\",\"text\":\"Hello \"},{\"type\":\"tool_use\",\"id\":\"t\",\"name\":\"f\",\"input\":{\"text\":\"no\"}},{\"type\":\"text\",\"text\":\"there\"}],\"stop_reason\":\"end_turn\",\"stop_sequence\":null,\"usage\":{\"input_tokens\":12,\"output_tokens\":7}}"

# The text blocks join; a tool's input is not text.
law reply_anthropic:
  {Llm.reply(Llm.Anthropic{}, b(anthropic.body())) == Done{Llm.Reply{"msg_1", "claude-x", "Hello there", "end_turn", 12, 7}} : Result<&1, &1, Llm.Err, Llm.Reply>}

def openai.body() -> String:
  "{\"id\":\"chatcmpl-1\",\"object\":\"chat.completion\",\"model\":\"gpt-x\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"Hi there\",\"refusal\":null},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":11,\"completion_tokens\":3,\"total_tokens\":14}}"

law reply_openai:
  {Llm.reply(Llm.OpenAI{}, b(openai.body())) == Done{Llm.Reply{"chatcmpl-1", "gpt-x", "Hi there", "stop", 11, 3}} : Result<&1, &1, Llm.Err, Llm.Reply>}

# Strings are decoded from UTF-8.
law reply_utf8:
  {Llm.reply(Llm.OpenAI{}, b("{\"choices\":[{\"message\":{\"content\":\"" ++ SCon{Chr{195}, SCon{Chr{169}, "\"}}]}"}})) == Done{Llm.Reply{"", "", "é", "", 0, 0}} : Result<&1, &1, Llm.Err, Llm.Reply>}

law reply_bad:
  {Llm.reply(Llm.Anthropic{}, b("<html>")) == Fail{Llm.ErrReply{"<html>"}} : Result<&1, &1, Llm.Err, Llm.Reply>}

# ---- stream events

def ev(api: Llm.Api, +name: String, +data: String) -> Llm.Ev:
  Llm.ev(api, Sse.Message{name, b(data), ""})

law ev_anthropic_text:
  {ev(Llm.Anthropic{}, "content_block_delta", "{\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hi\"}}") == Llm.EText{"Hi"} : Llm.Ev}

law ev_anthropic_tool:
  {ev(Llm.Anthropic{}, "content_block_delta", "{\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\"}}") == Llm.ESkip{} : Llm.Ev}

law ev_anthropic_ping:
  {ev(Llm.Anthropic{}, "ping", "{\"type\":\"ping\"}") == Llm.ESkip{} : Llm.Ev}

law ev_anthropic_stop:
  {ev(Llm.Anthropic{}, "message_stop", "{\"type\":\"message_stop\"}") == Llm.EEnd{} : Llm.Ev}

law ev_anthropic_error:
  {ev(Llm.Anthropic{}, "error", "{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}") == Llm.EFail{Llm.ErrApi{200, "Overloaded"}} : Llm.Ev}

law ev_openai_text:
  {ev(Llm.OpenAI{}, "message", "{\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hi\"}}]}") == Llm.EText{"Hi"} : Llm.Ev}

law ev_openai_role:
  {ev(Llm.OpenAI{}, "message", "{\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\",\"content\":\"\"}}]}") == Llm.ESkip{} : Llm.Ev}

law ev_openai_done:
  {ev(Llm.OpenAI{}, "message", "[DONE]") == Llm.EEnd{} : Llm.Ev}

law ev_openai_error:
  {ev(Llm.OpenAI{}, "message", "{\"error\":{\"message\":\"Rate limit\",\"type\":\"rate_limit_error\"}}") == Llm.EFail{Llm.ErrApi{200, "Rate limit"}} : Llm.Ev}

# ---- request bodies

def s(x: String) -> Json.Val:
  Json.Str{Json.utf8(x)}

def k(x: String, v: Json.Val) -> Bytes.Bytes & Json.Val:
  (Json.utf8(x), v)

def n(+x: String) -> Json.Val:
  Json.Num{b(x)}

def m(+role: String, +text: String) -> Json.Val:
  Json.Obj{[k("role", s(role)), k("content", s(text))]}

def req(+system: String) -> Llm.Req:
  Llm.Req{"m", system, [Llm.Msg{Llm.User{}, "hi"}, Llm.Msg{Llm.Assistant{}, "yo"}], 9}

law body_anthropic:
  {Llm.body(Llm.Anthropic{}, req("be brief"), True{}) == Json.Obj{[k("model", s("m")), k("max_tokens", n("9")), k("system", s("be brief")),
    k("messages", Json.Arr{[m("user", "hi"), m("assistant", "yo")]}), k("stream", Json.Flag{True{}})]} : Json.Val}

law body_anthropic_plain:
  {Llm.body(Llm.Anthropic{}, req(""), False{}) == Json.Obj{[k("model", s("m")), k("max_tokens", n("9")),
    k("messages", Json.Arr{[m("user", "hi"), m("assistant", "yo")]})]} : Json.Val}

# OpenAI takes the system prompt as the first message.
law body_openai:
  {Llm.body(Llm.OpenAI{}, req("be brief"), True{}) == Json.Obj{[k("model", s("m")), k("max_completion_tokens", n("9")),
    k("messages", Json.Arr{[m("system", "be brief"), m("user", "hi"), m("assistant", "yo")]}), k("stream", Json.Flag{True{}})]} : Json.Val}

law body_openai_plain:
  {Llm.body(Llm.OpenAI{}, req(""), False{}) == Json.Obj{[k("model", s("m")), k("max_completion_tokens", n("9")),
    k("messages", Json.Arr{[m("user", "hi"), m("assistant", "yo")]})]} : Json.Val}

# ---- retries

law again_overloaded:
  {Llm.again.status(529) == True{} : Bool}

law again_rate:
  {Llm.again.status(429) == True{} : Bool}

law again_bad_request:
  {Llm.again.status(400) == False{} : Bool}

law again_ok:
  {Llm.again.status(200) == False{} : Bool}
