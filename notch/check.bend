import Base
import ./notch.bend as Notch

def show(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "(dropped)"
    case Some{s}:
      s

def main() -> IO(Unit):
  +lg = Notch.with(Notch.text(Notch.Info{}), [Notch.str("svc", "api")])
  +js = Notch.with(Notch.json(Notch.Info{}), [Notch.str("svc", "api")])
  +fs = {[Notch.str("path", "/a b"), Notch.num("status", 200), Notch.flag("ok", True{})] : List<&2, Notch.Field>}
  do IO<Unit>:
    IO.print(show(Notch.line(lg, Some{"2026-09-27T12:00:00Z"}, Notch.Info{}, "request done", fs)))
    IO.print(show(Notch.line(js, Some{"2026-09-27T12:00:00Z"}, Notch.Info{}, "tab\there \"q\"", fs)))
    IO.print(show(Notch.line(lg, None{}, Notch.Debug{}, "hidden", fs)))
    Notch.info(lg, "to stderr", fs)
    Notch.error(js, "to stderr", fs)
    Notch.debug(lg, "never printed", fs)
