import Base
import ./markdown.bend as M

def clean.c(lt: Bool, gt: Bool, quot: Bool, rest: Bool) -> Bool:
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
              rest

# s holds no <, >, or ".
def clean(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      clean.c(U32.is_eq(c, 60), U32.is_eq(c, 62), U32.is_eq(c, 34), clean(t))

def ent(+s: String) -> Bool:
  String.starts_with(s, "amp;") || String.starts_with(s, "lt;") || String.starts_with(s, "gt;") || String.starts_with(s, "quot;")

def amp_ok.c(amp: Bool, +t: String, rest: Bool) -> Bool:
  match amp:
    case True{}:
      Bool.and(ent(t), rest)
    case False{}:
      rest

# Every & in s starts &amp;, &lt;, &gt;, or &quot;.
def amp_ok(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{y}, +t}:
      +c = {y : U32}
      amp_ok.c(U32.is_eq(c, 38), t, amp_ok(t))

# For every string, the text escape leaves no <, >, or ".
law esc_clean:
  for s: String
  {clean(M.esc(s)) == True{} : Bool}

# For every string, each & that the text escape writes starts a character reference.
law esc_amp_entity:
  for s: String
  {amp_ok(M.esc(s)) == True{} : Bool}

# HTML escaping: text, code, attributes, and URLs.
law escape_text:
  {M.to_html("a < b & \"c\"\n") == "<p>a &lt; b &amp; &quot;c&quot;</p>\n" : String}

law escape_code_span:
  {M.to_html("`<&>`\n") == "<p><code>&lt;&amp;&gt;</code></p>\n" : String}

law escape_code_block:
  {M.to_html("    <a href=\"x\">&</a>\n") == "<pre><code>&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;\n</code></pre>\n" : String}

law escape_title_quote:
  {M.to_html("[a](/u \"q\\\"x\")\n") == "<p><a href=\"/u\" title=\"q&quot;x\">a</a></p>\n" : String}

law escape_href:
  {M.to_html("[a](<b c?d=1&e=\"f\">)\n") == "<p><a href=\"b%20c?d=1&amp;e=%22f%22\">a</a></p>\n" : String}

law escape_alt:
  {M.to_html("![a & \"b\" <c>](/i)\n") == "<p><img src=\"/i\" alt=\"a &amp; &quot;b&quot; &lt;c&gt;\" /></p>\n" : String}

law alt_line_breaks:
  {M.to_html("![a\nb  \nc\\\nd](/i)\n") == "<p><img src=\"/i\" alt=\"a b c d\" /></p>\n" : String}

law escape_entity_kept:
  {M.to_html("&amp;lt;\n") == "<p>&amp;lt;</p>\n" : String}

law raw_html_kept:
  {M.to_html("<b class=\"x\">&</b>\n") == "<p><b class=\"x\">&amp;</b></p>\n" : String}

def gfm(s: String) -> String:
  M.to_html_with(M.Opts{False{}, True{}}, s)

law gfm_table:
  {gfm("| a | b |\n|:--|--:|\n| 1 < 2 & | `\\|` |\n| y |\n") == "<table>\n<thead>\n<tr>\n<th align=\"left\">a</th>\n<th align=\"right\">b</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td align=\"left\">1 &lt; 2 &amp;</td>\n<td align=\"right\"><code>|</code></td>\n</tr>\n<tr>\n<td align=\"left\">y</td>\n<td align=\"right\"></td>\n</tr>\n</tbody>\n</table>\n" : String}

law gfm_table_off:
  {M.to_html("| a |\n| - |\n") == "<p>| a |\n| - |</p>\n" : String}

law gfm_task_list:
  {gfm("- [ ] a\n- [x] b\n") == "<ul>\n<li><input disabled=\"\" type=\"checkbox\"> a</li>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> b</li>\n</ul>\n" : String}

law gfm_strikethrough:
  {gfm("~~a~~ ~b~ ~~~c~~~\n") == "<p><del>a</del> <del>b</del> ~~~c~~~</p>\n" : String}

law gfm_strikethrough_off:
  {M.to_html("~~a~~\n") == "<p>~~a~~</p>\n" : String}

law gfm_autolink:
  {gfm("see www.x.org/a?b=1&c=2. or a@b.co\n") == "<p>see <a href=\"http://www.x.org/a?b=1&amp;c=2\">www.x.org/a?b=1&amp;c=2</a>. or <a href=\"mailto:a@b.co\">a@b.co</a></p>\n" : String}

law gfm_autolink_safe:
  {M.to_html_with(M.Opts{True{}, True{}}, "https://x.org <b>\n") == "<p><a href=\"https://x.org\">https://x.org</a> <!-- raw HTML omitted --></p>\n" : String}

law gfm_tagfilter:
  {gfm("a <script>x</script> <b>\n") == "<p>a &lt;script>x&lt;/script> <b></p>\n" : String}

law safe_html_block:
  {M.to_html_safe("<div>\nraw\n</div>\n") == "<!-- raw HTML omitted -->\n" : String}

law safe_inline_html:
  {M.to_html_safe("a <b onclick=\"x\">b</b>\n") == "<p>a <!-- raw HTML omitted -->b<!-- raw HTML omitted --></p>\n" : String}

law safe_javascript_link:
  {M.to_html_safe("[a](JavaScript:alert(1))\n") == "<p><a href=\"\">a</a></p>\n" : String}

law safe_autolink:
  {M.to_html_safe("<vbscript:x>\n") == "<p><a href=\"\">vbscript:x</a></p>\n" : String}

law safe_data_png_kept:
  {M.to_html_safe("![i](data:image/png;base64,AA)\n") == "<p><img src=\"data:image/png;base64,AA\" alt=\"i\" /></p>\n" : String}

law safe_data_other:
  {M.to_html_safe("![i](data:text/html,x)\n") == "<p><img src=\"\" alt=\"i\" /></p>\n" : String}

law safe_plain_link_kept:
  {M.to_html_safe("[a](https://x.org/?q=1)\n") == "<p><a href=\"https://x.org/?q=1\">a</a></p>\n" : String}

# A sample of the CommonMark 0.31.2 spec examples; conformance.py runs all of them.
law spec_1:
  {M.to_html("\u{9}foo\u{9}baz\u{9}\u{9}bim\n") == "<pre><code>foo\u{9}baz\u{9}\u{9}bim\n</code></pre>\n" : String}

law spec_12:
  {M.to_html("\\!\\\"\\#\\$\\%\\&\\'\\(\\)\\*\\+\\,\\-\\.\\/\\:\\;\\<\\=\\>\\?\\@\\[\\\\\\]\\^\\_\\`\\{\\|\\}\\~\n") == "<p>!&quot;#$%&amp;'()*+,-./:;&lt;=&gt;?@[\\]^_`{|}~</p>\n" : String}

law spec_25:
  {M.to_html("&nbsp; &amp; &copy; &AElig; &Dcaron;\n&frac34; &HilbertSpace; &DifferentialD;\n&ClockwiseContourIntegral; &ngE;\n") == "<p>\u{A0} &amp; \u{A9} \u{C6} \u{10E}\n\u{BE} \u{210B} \u{2146}\n\u{2232} \u{2267}\u{338}</p>\n" : String}

law spec_43:
  {M.to_html("***\n---\n___\n") == "<hr />\n<hr />\n<hr />\n" : String}

law spec_62:
  {M.to_html("# foo\n## foo\n### foo\n#### foo\n##### foo\n###### foo\n") == "<h1>foo</h1>\n<h2>foo</h2>\n<h3>foo</h3>\n<h4>foo</h4>\n<h5>foo</h5>\n<h6>foo</h6>\n" : String}

law spec_80:
  {M.to_html("Foo *bar*\n=========\n\nFoo *bar*\n---------\n") == "<h1>Foo <em>bar</em></h1>\n<h2>Foo <em>bar</em></h2>\n" : String}

law spec_107:
  {M.to_html("    a simple\n      indented code block\n") == "<pre><code>a simple\n  indented code block\n</code></pre>\n" : String}

law spec_119:
  {M.to_html("```\n<\n >\n```\n") == "<pre><code>&lt;\n &gt;\n</code></pre>\n" : String}

law spec_148:
  {M.to_html("<table><tr><td>\n<pre>\n**Hello**,\n\n_world_.\n</pre>\n</td></tr></table>\n") == "<table><tr><td>\n<pre>\n**Hello**,\n<p><em>world</em>.\n</pre></p>\n</td></tr></table>\n" : String}

law spec_192:
  {M.to_html("[foo]: /url \"title\"\n\n[foo]\n") == "<p><a href=\"/url\" title=\"title\">foo</a></p>\n" : String}

law spec_219:
  {M.to_html("aaa\n\nbbb\n") == "<p>aaa</p>\n<p>bbb</p>\n" : String}

law spec_228:
  {M.to_html("> # Foo\n> bar\n> baz\n") == "<blockquote>\n<h1>Foo</h1>\n<p>bar\nbaz</p>\n</blockquote>\n" : String}

law spec_253:
  {M.to_html("A paragraph\nwith two lines.\n\n    indented code\n\n> A block quote.\n") == "<p>A paragraph\nwith two lines.</p>\n<pre><code>indented code\n</code></pre>\n<blockquote>\n<p>A block quote.</p>\n</blockquote>\n" : String}

law spec_301:
  {M.to_html("- foo\n- bar\n+ baz\n") == "<ul>\n<li>foo</li>\n<li>bar</li>\n</ul>\n<ul>\n<li>baz</li>\n</ul>\n" : String}

law spec_328:
  {M.to_html("`foo`\n") == "<p><code>foo</code></p>\n" : String}

law spec_360:
  {M.to_html("foo_bar_\n") == "<p>foo_bar_</p>\n" : String}

law spec_402:
  {M.to_html("__foo__bar__baz__\n") == "<p><strong>foo__bar__baz</strong></p>\n" : String}

law spec_426:
  {M.to_html("____foo__ bar__\n") == "<p><strong><strong>foo</strong> bar</strong></p>\n" : String}

law spec_482:
  {M.to_html("[link](/uri \"title\")\n") == "<p><a href=\"/uri\" title=\"title\">link</a></p>\n" : String}

law spec_504:
  {M.to_html("[link](\"title\")\n") == "<p><a href=\"%22title%22\">link</a></p>\n" : String}

law spec_526:
  {M.to_html("[foo<https://example.com/?search=](uri)>\n") == "<p>[foo<a href=\"https://example.com/?search=%5D(uri)\">https://example.com/?search=](uri)</a></p>\n" : String}

law spec_572:
  {M.to_html("![foo](/url \"title\")\n") == "<p><img src=\"/url\" alt=\"foo\" title=\"title\" /></p>\n" : String}

law spec_594:
  {M.to_html("<http://foo.bar.baz>\n") == "<p><a href=\"http://foo.bar.baz\">http://foo.bar.baz</a></p>\n" : String}

law spec_613:
  {M.to_html("<a><bab><c2c>\n") == "<p><a><bab><c2c></p>\n" : String}

law spec_633:
  {M.to_html("foo  \nbaz\n") == "<p>foo<br />\nbaz</p>\n" : String}
