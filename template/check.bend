import Base
import ./template.bend as T

def put(m: Map<&2, T.Value>, k: String, v: T.Value) -> Map<&2, T.Value>:
  Map.set(&2, T.Value, m, k, v)

def ctx() -> Map<&2, T.Value>:
  m0 = put(Map.new(&2, T.Value), "title", T.VStr{"Tom & Jerry"})
  m1 = put(m0, "items", T.VList{[T.VStr{"<cat>"}, T.VStr{"<mouse>"}]})
  put(m1, "user", T.VMap{put(Map.new(&2, T.Value), "id", T.VStr{"7"})})

def show(r: Result<&2, &2, String, String>) -> String:
  match r:
    case Fail{m}:
      "error: " ++ m
    case Done{s}:
      s

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(show(T.render_text("<h1>{{title}}</h1>\n<ul>\n  {{#items}}\n  <li>{{.}}</li>\n  {{/items}}\n</ul>\n{{^none}}<p>none</p>{{/none}} user {{user.id}}", ctx())))
    IO.print(show(T.render_text("{{#items}}x{{/user}}", ctx())))
