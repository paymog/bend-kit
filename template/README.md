# template

Mustache templates: variables, sections, inverted sections, and comments. A variable is HTML-escaped unless you ask for raw output.

```bend
import bend-kit-template@0.1.0.0/template.bend as T
```

```bend
def put(m: Map<&2, T.Value>, k: String, v: T.Value) -> Map<&2, T.Value>:
  Map.set(&2, T.Value, m, k, v)

def ctx() -> Map<&2, T.Value>:
  m = put(Map.new(&2, T.Value), "title", T.VStr{"Tom & Jerry"})
  put(m, "items", T.VList{[T.VStr{"<cat>"}, T.VStr{"<mouse>"}]})

def show(r: Result<&2, &2, String, String>) -> String:
  match r:
    case Fail{m}:
      "error: " ++ m
    case Done{s}:
      s

def main() -> IO(Unit):
  # <h1>Tom &amp; Jerry</h1><li>&lt;cat&gt;</li><li>&lt;mouse&gt;</li>
  IO.print(show(T.render_text("<h1>{{title}}</h1>{{#items}}<li>{{.}}</li>{{/items}}", ctx())))
```

The context is a Base `Map<&2, T.Value>`. A `Value` is `VStr`, `VBool`, `VList`, or `VMap`. Write a number as a `VStr`.

| tag | output |
|---|---|
| `{{name}}` | The value, HTML-escaped. `VBool` prints `true` or `false`. A missing name, a list, or a map prints nothing. |
| `{{{name}}}`, `{{& name}}` | The value, not escaped. |
| `{{#name}}…{{/name}}` | The body once per item of a `VList`, once for any other value that is not `VBool{False{}}`, and not at all for a missing name, `VBool{False{}}`, or an empty list. Each item is pushed on the context stack. |
| `{{^name}}…{{/name}}` | The body once when `{{#name}}` would not render it. |
| `{{! text }}` | Nothing. |
| `{{.}}` | The top of the context stack. |

A name is looked up from the innermost section outward. In a dotted name such as `user.id`, only the first part searches the stack. A section, inverted, close, or comment tag alone on its line removes that line.

Escaping replaces `&`, `<`, `>`, `"`, and `'` with `&amp;`, `&lt;`, `&gt;`, `&quot;`, and `&#39;`. That makes a value safe in HTML text and in a quoted attribute. It does not make a value safe in a URL, a script, or a style.

| Def | Result | Use |
|---|---|---|
| `parse(src: String)` | `Result<&2, &2, String, List<&2, Node>>` | Parse once. `Fail` gives the reason: an unclosed tag or section, a close tag that does not match, or an unsupported tag. |
| `render(nodes: List<&2, Node>, ctx: Map<&2, Value>)` | `String` | Render parsed nodes. Rendering cannot fail. |
| `render_text(src: String, ctx: Map<&2, Value>)` | `Result<&2, &2, String, String>` | `parse`, then `render`. |
| `escape(s: String)` | `String` | The HTML escape that `{{name}}` uses. |

Partials (`{{> name}}`), set delimiters (`{{= =}}`), and lambdas are not supported. A template that uses partials or set delimiters fails to parse.

`python3 template/conformance.py` runs the Mustache spec v1.4.2 interpolation, sections, inverted, and comments files in a native build. It skips the tests that use partials or set delimiters, or whose data is not a map. All 104 other tests pass. `LAWS.bend` holds escaping laws and a sample of those cases.

`bench/README.md` compares `render` with Rust, JavaScript, and Python libraries.
