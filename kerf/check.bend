import Base
import ./kerf.bend as Kerf

def show(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "(dropped)"
    case Some{s}:
      s

def main() -> IO(Unit):
  +lg = Kerf.with(Kerf.text(Kerf.Info{}), [Kerf.str("svc", "api")])
  +js = Kerf.with(Kerf.json(Kerf.Info{}), [Kerf.str("svc", "api")])
  +fs = {[Kerf.str("path", "/a b"), Kerf.num("status", 200), Kerf.flag("ok", True{})] : List<&2, Kerf.Field>}
  do IO<Unit>:
    IO.print(show(Kerf.line(lg, Some{"2026-09-27T12:00:00Z"}, Kerf.Info{}, "request done", fs)))
    IO.print(show(Kerf.line(js, Some{"2026-09-27T12:00:00Z"}, Kerf.Info{}, "tab\there \"q\"", fs)))
    IO.print(show(Kerf.line(lg, None{}, Kerf.Debug{}, "hidden", fs)))
    Kerf.info(lg, "to stderr", fs)
    Kerf.error(js, "to stderr", fs)
    Kerf.debug(lg, "never printed", fs)
