import Base
import ./template.bend as T

def put(m: Map<&2, T.Value>, k: String, v: T.Value) -> Map<&2, T.Value>:
  Map.set(&2, T.Value, m, k, v)

def ctx() -> Map<&2, T.Value>:
  m0 = put(Map.new(&2, T.Value), "name", T.VStr{"<b>Ann & \"Bo\" 'C'</b>"})
  m1 = put(m0, "items", T.VList{[T.VStr{"a"}, T.VStr{"b"}, T.VStr{"c"}]})
  m2 = put(m1, "user", T.VMap{put(Map.new(&2, T.Value), "id", T.VStr{"7"})})
  m3 = put(m2, "none", T.VList{[]})
  put(m3, "off", T.VBool{False{}})

def run(src: String) -> Result<&2, &2, String, String>:
  T.render_text(src, ctx())

def nodes(r: Result<&2, &2, String, List<&2, T.Node>>) -> List<&2, T.Node>:
  match r:
    case Fail{m}:
      Nil{}
    case Done{n}:
      n

def part(m: Map<&2, List<&2, T.Node>>, k: String, src: String) -> Map<&2, List<&2, T.Node>>:
  Map.set(&2, List<&2, T.Node>, m, k, nodes(T.parse(src)))

def parts() -> Map<&2, List<&2, T.Node>>:
  p0 = part(Map.new(&2, List<&2, T.Node>), "row", "<li>{{.}}</li>\n")
  p1 = part(p0, "user", "id={{id}}")
  p2 = part(p1, "box", "<li>\n{{user.id}}\n</li>\n")
  part(p2, "self", "x{{>self}}")

def runp.of(r: Result<&2, &2, String, List<&2, T.Node>>) -> Result<&2, &2, String, String>:
  match r:
    case Fail{m}:
      Fail{m}
    case Done{n}:
      Done{T.render_with(n, ctx(), parts())}

def runp(src: String) -> Result<&2, &2, String, String>:
  runp.of(T.parse(src))

def clean.c(lt: Bool, gt: Bool, quot: Bool, apos: Bool, rest: Bool) -> Bool:
  match lt:
    case True{}:
      False{}
    case False{}:
      match gt:
        case True{}:
          False{}
        case False{}:
          match quot:
            case True{}:
              False{}
            case False{}:
              match apos:
                case True{}:
                  False{}
                case False{}:
                  rest

# s holds no <, >, ", or '.
def clean(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      clean.c(U32.is_eq(c, 60), U32.is_eq(c, 62), U32.is_eq(c, 34), U32.is_eq(c, 39), clean(t))

def ent(+s: String) -> Bool:
  String.starts_with(s, "amp;") || String.starts_with(s, "lt;") || String.starts_with(s, "gt;") || String.starts_with(s, "quot;") || String.starts_with(s, "#39;")

def amp_ok.c(amp: Bool, +t: String, rest: Bool) -> Bool:
  match amp:
    case True{}:
      Bool.and(ent(t), rest)
    case False{}:
      rest

# Every & in s starts &amp;, &lt;, &gt;, &quot;, or &#39;.
def amp_ok(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{y}, +t}:
      +c = {y : U32}
      amp_ok.c(U32.is_eq(c, 38), t, amp_ok(t))

# For every string, escape leaves no <, >, ", or '.
law escape_clean:
  for s: String
  {clean(T.escape(s)) == True{} : Bool}

# For every string, each & that escape writes starts a character reference.
law escape_amp_entity:
  for s: String
  {amp_ok(T.escape(s)) == True{} : Bool}

law escape_lt:
  {T.escape("<") == "&lt;" : String}

law escape_gt:
  {T.escape(">") == "&gt;" : String}

law escape_amp:
  {T.escape("&") == "&amp;" : String}

law escape_quot:
  {T.escape("\"") == "&quot;" : String}

law escape_apos:
  {T.escape("'") == "&#39;" : String}

law escape_entity_twice:
  {T.escape("&amp;") == "&amp;amp;" : String}

law escape_plain:
  {T.escape("a b\n") == "a b\n" : String}

# A variable is escaped by default.
law var_escaped:
  {run("{{name}}") == Done{"&lt;b&gt;Ann &amp; &quot;Bo&quot; &#39;C&#39;&lt;/b&gt;"} : Result<&2, &2, String, String>}

law triple_raw:
  {run("{{{name}}}") == Done{"<b>Ann & \"Bo\" 'C'</b>"} : Result<&2, &2, String, String>}

law amp_raw:
  {run("{{& name}}") == Done{"<b>Ann & \"Bo\" 'C'</b>"} : Result<&2, &2, String, String>}

law missing_empty:
  {run("[{{nope}}]") == Done{"[]"} : Result<&2, &2, String, String>}

law dotted:
  {run("{{user.id}}") == Done{"7"} : Result<&2, &2, String, String>}

law dotted_no_fallback:
  {run("{{#user}}{{user.name}}{{/user}}") == Done{""} : Result<&2, &2, String, String>}

law loop:
  {run("{{#items}}<{{.}}>{{/items}}") == Done{"<a><b><c>"} : Result<&2, &2, String, String>}

law section_map:
  {run("{{#user}}id={{id}}{{/user}}") == Done{"id=7"} : Result<&2, &2, String, String>}

law section_outer_lookup:
  {run("{{#user}}{{{name}}}{{/user}}") == Done{"<b>Ann & \"Bo\" 'C'</b>"} : Result<&2, &2, String, String>}

law section_false:
  {run("a{{#off}}b{{/off}}c") == Done{"ac"} : Result<&2, &2, String, String>}

law section_empty_list:
  {run("a{{#none}}b{{/none}}c") == Done{"ac"} : Result<&2, &2, String, String>}

law inverted_empty:
  {run("{{^none}}empty{{/none}}{{^items}}full{{/items}}") == Done{"empty"} : Result<&2, &2, String, String>}

law comment:
  {run("a{{! hidden }}b") == Done{"ab"} : Result<&2, &2, String, String>}

law standalone_lines:
  {run("<ul>\n  {{#items}}\n  <li>{{.}}</li>\n  {{/items}}\n</ul>\n") == Done{"<ul>\n  <li>a</li>\n  <li>b</li>\n  <li>c</li>\n</ul>\n"} : Result<&2, &2, String, String>}

law inline_section_keeps_line:
  {run(" {{#off}}x{{/off}} \n") == Done{"  \n"} : Result<&2, &2, String, String>}

law unclosed_section:
  {run("{{#items}}x") == Fail{"unclosed section: items"} : Result<&2, &2, String, String>}

law mismatched_close:
  {run("{{#items}}x{{/user}}") == Fail{"close tag does not match its section: user"} : Result<&2, &2, String, String>}

law unclosed_tag:
  {run("a {{name") == Fail{"unclosed tag"} : Result<&2, &2, String, String>}

law partial_without_map:
  {run("a{{> part}}b") == Done{"ab"} : Result<&2, &2, String, String>}

law partial_missing:
  {runp("[{{>nope}}]") == Done{"[]"} : Result<&2, &2, String, String>}

law partial_caller_context:
  {runp("{{#user}}<{{>user}}>{{/user}}") == Done{"<id=7>"} : Result<&2, &2, String, String>}

law partial_in_loop:
  {runp("<ul>\n{{#items}}\n{{>row}}\n{{/items}}\n</ul>\n") == Done{"<ul>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ul>\n"} : Result<&2, &2, String, String>}

law partial_standalone_indent:
  {runp("<ul>\n  {{>box}}\n</ul>\n") == Done{"<ul>\n  <li>\n  7\n  </li>\n</ul>\n"} : Result<&2, &2, String, String>}

law partial_recursion_capped:
  {runp("{{>self}}") == Done{String.repeat("x", 64n)} : Result<&2, &2, String, String>}

law partial_default_delims:
  {runp("{{=<% %>=}}<%>user%>") == Done{"id="} : Result<&2, &2, String, String>}

law delims_switch:
  {run("{{=<% %>=}}<%#items%>(<%.%>)<%/items%>{{x}}") == Done{"(a)(b)(c){{x}}"} : Result<&2, &2, String, String>}

law delims_back:
  {run("{{= | | =}}|user.id||={{ }}=|{{user.id}}") == Done{"77"} : Result<&2, &2, String, String>}

law delims_triple:
  {run("{{=<% %>=}}<%{name}%>") == Done{"<b>Ann & \"Bo\" 'C'</b>"} : Result<&2, &2, String, String>}

law delims_standalone:
  {run("a\n  {{=<% %>=}}\nb<%user.id%>\n") == Done{"a\nb7\n"} : Result<&2, &2, String, String>}

law delims_bad:
  {run("{{=<%=}}") == Fail{"bad set delimiters"} : Result<&2, &2, String, String>}
