# template

Mustache templates: variables, sections, inverted sections, and comments. A variable is HTML-escaped unless you ask for raw output.

```bend
import bend-kit-template@0.3.0.0/template.bend as T
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
| `{{=<% %>=}}` | Nothing. The tags after it use `<%` and `%>`. The new delimiters must be two words with no whitespace between `=` and `=`. |
| `{{> name}}` | The partial `name`, rendered against the current context stack. A missing partial prints nothing. |

A name is looked up from the innermost section outward. In a dotted name such as `user.id`, only the first part searches the stack. A section, inverted, close, comment, set-delimiter, or partial tag alone on its line removes that line. A triple tag with custom delimiters is `<%{name}%>`.

Partials come from a `Map<&2, List<&2, Node>>` of parsed templates, passed to `render_with`. Parse each partial with `parse` and handle its `Fail`. A partial always starts with `{{` and `}}`, whatever delimiters the caller set. A standalone partial tag indents each line of the partial's template text by the whitespace before the tag; text that a value inserts is not indented. Partials nest at most 64 deep, so a partial that includes itself stops; a partial below that depth prints nothing.

Escaping replaces `&`, `<`, `>`, `"`, and `'` with `&amp;`, `&lt;`, `&gt;`, `&quot;`, and `&#39;`. That makes a value safe in HTML text and in a quoted attribute. It does not make a value safe in a URL, a script, or a style.

| Def | Result | Use |
|---|---|---|
| `parse(src: String)` | `Result<&2, &2, String, List<&2, Node>>` | Parse once. `Fail` gives the reason: an unclosed tag or section, a close tag that does not match, or bad set delimiters. |
| `render_with(nodes: List<&2, Node>, ctx: Map<&2, Value>, partials: Map<&2, List<&2, Node>>)` | `String` | Render parsed nodes with partials. Rendering cannot fail. |
| `render(nodes: List<&2, Node>, ctx: Map<&2, Value>)` | `String` | `render_with` and no partials. |
| `render_text(src: String, ctx: Map<&2, Value>)` | `Result<&2, &2, String, String>` | `parse`, then `render`. |
| `escape(s: String)` | `String` | The HTML escape that `{{name}}` uses. |

Lambdas and dynamic partial names (`{{>*name}}`) are not supported.

`python3 template/conformance.py` runs the Mustache spec v1.4.2 interpolation, sections, inverted, comments, delimiters, and partials files in a native build. It skips the tests whose data is not a map. All 130 other tests pass. `LAWS.bend` holds escaping laws and a sample of those cases. Two of its laws hold for every string: `escape` output has no `<`, `>`, `"`, or `'`, and each `&` in it starts `&amp;`, `&lt;`, `&gt;`, `&quot;`, or `&#39;`.

`bench/README.md` compares `render` with Rust, JavaScript, and Python libraries.
