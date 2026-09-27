import Base
import ./kerf.bend as Kerf

def T() -> Maybe<&2, String>:
  Some{"2026-09-27T12:00:00Z"}

def fs() -> List<&2, Kerf.Field>:
  [Kerf.str("path", "/a b"), Kerf.num("status", 200), Kerf.flag("ok", True{})]

def row(+lvl: Kerf.Level) -> List<&2, Bool>:
  [Kerf.enabled(Kerf.text(Kerf.Debug{}), lvl), Kerf.enabled(Kerf.text(Kerf.Info{}), lvl),
    Kerf.enabled(Kerf.text(Kerf.Warn{}), lvl), Kerf.enabled(Kerf.text(Kerf.Error{}), lvl)]

# Text is logfmt: time, level, msg, then the with fields and the line's own fields.
law text_line:
  {Kerf.render(Kerf.with(Kerf.text(Kerf.Info{}), [Kerf.str("svc", "api")]), T(),
    Kerf.Info{}, "request done", fs()) ==
    "time=2026-09-27T12:00:00Z level=INFO msg=\"request done\" svc=api path=\"/a b\" status=200 ok=true" : String}

law json_line:
  {Kerf.render(Kerf.with(Kerf.json(Kerf.Info{}), [Kerf.str("svc", "api")]), T(),
    Kerf.Warn{}, "request done", fs()) ==
    "{\"time\":\"2026-09-27T12:00:00Z\",\"level\":\"WARN\",\"msg\":\"request done\",\"svc\":\"api\",\"path\":\"/a b\",\"status\":200,\"ok\":true}" : String}

# Quote, backslash and control chars escape as in JSON; other chars pass as they are.
law json_escape:
  {Kerf.render(Kerf.json(Kerf.Debug{}), None{}, Kerf.Error{}, "a\"b\\c\nd\te\u{1}é", []) ==
    "{\"level\":\"ERROR\",\"msg\":\"a\\\"b\\\\c\\nd\\te\\u0001é\"}" : String}

# A logfmt value is quoted when empty or when it has whitespace, control, '=', quote or DEL.
law text_quote:
  {Kerf.render(Kerf.text(Kerf.Debug{}), None{}, Kerf.Debug{}, "hi",
    [Kerf.str("a", ""), Kerf.str("b", "x=y"), Kerf.str("c", "é/ok"), Kerf.str("d e", "q\""),
     Kerf.str("f", "x\u{a0}y"), Kerf.str("g", "x\u{2003}y")]) ==
    "level=DEBUG msg=hi a=\"\" b=\"x=y\" c=é/ok \"d e\"=\"q\\\"\" f=\"x\u{a0}y\" g=\"x\u{2003}y\"" : String}

# Each with adds its fields after the ones before it.
law with_order:
  {Kerf.render(Kerf.with(Kerf.with(Kerf.text(Kerf.Info{}), [Kerf.num("a", 1)]), [Kerf.num("b", 2)]),
    None{}, Kerf.Info{}, "m", [Kerf.num("c", 3)]) ==
    "level=INFO msg=m a=1 b=2 c=3" : String}

# Row: the line's level; column: the logger's level, both DEBUG, INFO, WARN, ERROR.
law enabled_table:
  {[row(Kerf.Debug{}), row(Kerf.Info{}), row(Kerf.Warn{}), row(Kerf.Error{})] ==
    [[True{}, False{}, False{}, False{}],
     [True{}, True{}, False{}, False{}],
     [True{}, True{}, True{}, False{}],
     [True{}, True{}, True{}, True{}]] : List<&2, List<&2, Bool>>}

# A level filter drops every line below its threshold, whatever the line holds.
law drops_below:
  for f: Kerf.Format
  for c: List<&2, Kerf.Field>
  for t: Maybe<&2, String>
  for m: String
  for xs: List<&2, Kerf.Field>
  {Kerf.line(Kerf.Logger{Kerf.Warn{}, f, c}, t, Kerf.Info{}, m, xs) == None{} : Maybe<&2, String>}

law keeps_at:
  for +f: Kerf.Format
  for +c: List<&2, Kerf.Field>
  for +t: Maybe<&2, String>
  for +m: String
  for +xs: List<&2, Kerf.Field>
  {Kerf.line(Kerf.Logger{Kerf.Warn{}, f, c}, t, Kerf.Warn{}, m, xs) ==
    Some{Kerf.render(Kerf.Logger{Kerf.Warn{}, f, c}, t, Kerf.Warn{}, m, xs)} : Maybe<&2, String>}
