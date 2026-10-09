# Live smoke: one reply and one stream per API whose key is set; the others are skipped.
# ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN (bearer), ANTHROPIC_BASE_URL, ANTHROPIC_MODEL; OPENAI_API_KEY, OPENAI_BASE_URL, OPENAI_MODEL.
import Base
import ./llm.bend as Llm
import ../hairpin/hairpin.bend as Hairpin
import ../http/http.bend as Http

def env(r: Result<&1, &1, U32 & String, String>) -> Maybe<&2, String>:
  match r:
    case Fail{e}:
      None{}
    case Done{+s}:
      Bool.pick(Maybe<&2, String>, String.is_empty(s), None{}, Some{s})

def env.or(r: Result<&1, &1, U32 & String, String>, d: String) -> String:
  Maybe.default(&2, String, env(r), d)

def net(e: Http.Err) -> String:
  match e:
    case Http.ErrUrl{}:
      "bad url"
    case Http.ErrDns{}:
      "dns"
    case Http.ErrConnect{code, why}:
      "connect: " ++ why
    case Http.ErrTls{code, why}:
      "tls: " ++ why
    case Http.ErrRead{code, why}:
      "read: " ++ why
    case Http.ErrWrite{code, why}:
      "write: " ++ why
    case Http.ErrTimeout{}:
      "timeout"
    case Http.ErrRedirect{}:
      "redirect"
    case Http.ErrBad{}:
      "bad response"

def err(e: Llm.Err) -> String:
  match e:
    case Llm.ErrNet{Hairpin.ErrHttp{x}}:
      net(x)
    case Llm.ErrNet{Hairpin.ErrDenied{why}}:
      "denied: no attempt started"
    case Llm.ErrApi{+s, b}:
      "status " ++ U32.show(s) ++ ": " ++ b
    case Llm.ErrReply{b}:
      "bad reply: " ++ b

def req(model: String) -> Llm.Req:
  Llm.Req{model, "Answer in one short sentence.", [Llm.Msg{Llm.User{}, "Say hello to Bend."}], 64}

def sent(+name: String, x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Reply>) -> IO(Llm.Client):
  (c, r) = x
  match r:
    case Fail{e}:
      do IO<Llm.Client>:
        IO.print("fail " ++ name ++ " send: " ++ err(e))
        return c
    case Done{Llm.Reply{id, model, text, stop, +i, +o}}:
      do IO<Llm.Client>:
        IO.print("ok " ++ name ++ " send: " ++ text ++ " [" ++ stop ++ ", " ++ U32.show(i) ++ " in, " ++ U32.show(o) ++ " out]")
        return c

def pieces(f: Nat, +name: String, x: Llm.Stream & Result<&1, &1, Llm.Err, Maybe<&2, String>>, acc: String) -> IO(Unit):
  match f:
    case 0n:
      (s, r) = x
      do IO<Unit>:
        Llm.stream.close(s)
        IO.print("fail " ++ name ++ " stream: too many pieces")
    case 1n+g:
      (s, r) = x
      match r:
        case Fail{e}:
          do IO<Unit>:
            Llm.stream.close(s)
            IO.print("fail " ++ name ++ " stream: " ++ err(e))
        case Done{m}:
          match m:
            case None{}:
              do IO<Unit>:
                Llm.stream.close(s)
                IO.print("ok " ++ name ++ " stream: " ++ acc)
            case Some{t}:
              do IO<Unit>:
                y : Llm.Stream & Result<&1, &1, Llm.Err, Maybe<&2, String>> <- Llm.next(s)
                pieces(g, name, y, acc ++ t)

def streamed(+name: String, x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Llm.Client):
  (c, r) = x
  match r:
    case Fail{e}:
      do IO<Llm.Client>:
        IO.print("fail " ++ name ++ " stream: " ++ err(e))
        return c
    case Done{s}:
      do IO<Llm.Client>:
        y : Llm.Stream & Result<&1, &1, Llm.Err, Maybe<&2, String>> <- Llm.next(s)
        pieces(4096n, name, y, "")
        return c

def run(+name: String, c: Llm.Client, +model: String) -> IO(Unit):
  do IO<Unit>:
    x : Llm.Client & Result<&1, &1, Llm.Err, Llm.Reply> <- Llm.send(c, req(model))
    c1 : Llm.Client <- sent(name, x)
    y : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream(c1, req(model))
    c2 : Llm.Client <- streamed(name, y)
    Llm.close(c2)

def anthropic(t: Maybe<&2, String>, k: Maybe<&2, String>, base: String, +model: String) -> IO(Unit):
  match t:
    case Some{tok}:
      run("anthropic", Llm.header(Llm.base(Llm.anthropic(""), base), "authorization", "Bearer " ++ tok), model)
    case None{}:
      match k:
        case None{}:
          IO.print("skip anthropic: ANTHROPIC_API_KEY is not set")
        case Some{key}:
          run("anthropic", Llm.base(Llm.anthropic(key), base), model)

def openai(k: Maybe<&2, String>, base: String, +model: String) -> IO(Unit):
  match k:
    case None{}:
      IO.print("skip openai: OPENAI_API_KEY is not set")
    case Some{key}:
      run("openai", Llm.base(Llm.openai(key), base), model)

def main() -> IO(Unit):
  do IO<Unit>:
    at : Result<&1, &1, U32 & String, String> <- IO.get_env("ANTHROPIC_AUTH_TOKEN")
    ak : Result<&1, &1, U32 & String, String> <- IO.get_env("ANTHROPIC_API_KEY")
    ab : Result<&1, &1, U32 & String, String> <- IO.get_env("ANTHROPIC_BASE_URL")
    am : Result<&1, &1, U32 & String, String> <- IO.get_env("ANTHROPIC_MODEL")
    anthropic(env(at), env(ak), env.or(ab, "https://api.anthropic.com"), env.or(am, "claude-haiku-4-5"))
    ok : Result<&1, &1, U32 & String, String> <- IO.get_env("OPENAI_API_KEY")
    ob : Result<&1, &1, U32 & String, String> <- IO.get_env("OPENAI_BASE_URL")
    om : Result<&1, &1, U32 & String, String> <- IO.get_env("OPENAI_MODEL")
    openai(env(ok), env.or(ob, "https://api.openai.com/v1"), env.or(om, "gpt-4.1-mini"))
