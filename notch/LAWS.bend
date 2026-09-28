import Base
import ./notch.bend as Notch

def T() -> Maybe<&2, String>:
  Some{"2026-09-27T12:00:00Z"}

def fs() -> List<&2, Notch.Field>:
  [Notch.str("path", "/a b"), Notch.num("status", 200), Notch.flag("ok", True{})]

def row(+lvl: Notch.Level) -> List<&2, Bool>:
  [Notch.enabled(Notch.text(Notch.Debug{}), lvl), Notch.enabled(Notch.text(Notch.Info{}), lvl),
    Notch.enabled(Notch.text(Notch.Warn{}), lvl), Notch.enabled(Notch.text(Notch.Error{}), lvl)]

# Text is logfmt: time, level, msg, then the with fields and the line's own fields.
law text_line:
  {Notch.render(Notch.with(Notch.text(Notch.Info{}), [Notch.str("svc", "api")]), T(),
    Notch.Info{}, "request done", fs()) ==
    "time=2026-09-27T12:00:00Z level=INFO msg=\"request done\" svc=api path=\"/a b\" status=200 ok=true" : String}

law json_line:
  {Notch.render(Notch.with(Notch.json(Notch.Info{}), [Notch.str("svc", "api")]), T(),
    Notch.Warn{}, "request done", fs()) ==
    "{\"time\":\"2026-09-27T12:00:00Z\",\"level\":\"WARN\",\"msg\":\"request done\",\"svc\":\"api\",\"path\":\"/a b\",\"status\":200,\"ok\":true}" : String}

# Quote, backslash and control chars escape as in JSON; other chars pass as they are.
law json_escape:
  {Notch.render(Notch.json(Notch.Debug{}), None{}, Notch.Error{}, "a\"b\\c\nd\te\u{1}é", []) ==
    "{\"level\":\"ERROR\",\"msg\":\"a\\\"b\\\\c\\nd\\te\\u0001é\"}" : String}

# A logfmt value is quoted when empty or when it has whitespace, control, '=', quote or DEL.
law text_quote:
  {Notch.render(Notch.text(Notch.Debug{}), None{}, Notch.Debug{}, "hi",
    [Notch.str("a", ""), Notch.str("b", "x=y"), Notch.str("c", "é/ok"), Notch.str("d e", "q\""),
     Notch.str("f", "x\u{a0}y"), Notch.str("g", "x\u{2003}y")]) ==
    "level=DEBUG msg=hi a=\"\" b=\"x=y\" c=é/ok \"d e\"=\"q\\\"\" f=\"x\u{a0}y\" g=\"x\u{2003}y\"" : String}

# Each with adds its fields after the ones before it.
law with_order:
  {Notch.render(Notch.with(Notch.with(Notch.text(Notch.Info{}), [Notch.num("a", 1)]), [Notch.num("b", 2)]),
    None{}, Notch.Info{}, "m", [Notch.num("c", 3)]) ==
    "level=INFO msg=m a=1 b=2 c=3" : String}

# Row: the line's level; column: the logger's level, both DEBUG, INFO, WARN, ERROR.
law enabled_table:
  {[row(Notch.Debug{}), row(Notch.Info{}), row(Notch.Warn{}), row(Notch.Error{})] ==
    [[True{}, False{}, False{}, False{}],
     [True{}, True{}, False{}, False{}],
     [True{}, True{}, True{}, False{}],
     [True{}, True{}, True{}, True{}]] : List<&2, List<&2, Bool>>}

# A level filter drops every line below its threshold, whatever the line holds.
law drops_below:
  for f: Notch.Format
  for c: List<&2, Notch.Field>
  for t: Maybe<&2, String>
  for m: String
  for xs: List<&2, Notch.Field>
  {Notch.line(Notch.Logger{Notch.Warn{}, f, c}, t, Notch.Info{}, m, xs) == None{} : Maybe<&2, String>}

law keeps_at:
  for +f: Notch.Format
  for +c: List<&2, Notch.Field>
  for +t: Maybe<&2, String>
  for +m: String
  for +xs: List<&2, Notch.Field>
  {Notch.line(Notch.Logger{Notch.Warn{}, f, c}, t, Notch.Warn{}, m, xs) ==
    Some{Notch.render(Notch.Logger{Notch.Warn{}, f, c}, t, Notch.Warn{}, m, xs)} : Maybe<&2, String>}
