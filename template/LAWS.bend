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

law partial_refused:
  {run("{{> part}}") == Fail{"partials are not supported"} : Result<&2, &2, String, String>}
