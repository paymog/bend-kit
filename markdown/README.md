# markdown

CommonMark 0.31.2 to HTML in pure Bend, with opt-in GitHub Flavored Markdown extensions. All 652 spec examples pass.

```bend
import bend-kit-markdown@0.3.10.0/markdown.bend as M
```

```bend
def main() -> IO(Unit):
  # <h1>Hi &amp; <em>bye</em></h1>
  # <ul>
  # <li><a href="https://example.com">link</a></li>
  # </ul>
  IO.print(M.to_html("# Hi & *bye*\n\n- [link][x]\n\n[x]: https://example.com\n"))
```

`to_html(s: String) -> String` takes the whole document and returns HTML in the same form as the spec and cmark: `<p>`, `<em>`, `<strong>`, `<code>`, `<pre><code class="language-…">`, `<hr />`, `<br />`, and lists that are tight or loose. It cannot fail. Every input is a valid CommonMark document.

Text is HTML-escaped: `&`, `<`, `>`, and `"` become `&amp;`, `&lt;`, `&gt;`, and `&quot;`. Code spans and code blocks are escaped the same way. A link or image URL is percent-encoded where it is not a safe URL character, and `&` and `'` in it become `&amp;` and `&#x27;`. A title or alt text is escaped as text.

`to_html` does not sanitize. As CommonMark requires, raw HTML blocks and inline HTML pass through, and a `javascript:` URL stays a link.

For untrusted input, use `to_html_safe(s: String) -> String`. It renders as cmark does without `--unsafe`. Each raw HTML block and each inline HTML tag becomes `<!-- raw HTML omitted -->`. A link, image, or autolink URL that starts with `javascript:`, `vbscript:`, `file:`, or `data:`, in any ASCII case, becomes an empty `href` or `src`. A `data:image/png`, `data:image/gif`, `data:image/jpeg`, or `data:image/webp` URL stays. Text, titles, and alt text are escaped in both modes.

The input is a `String` of code points. Decode octets with `encoding`'s `utf8.decode` first. Tabs expand to the next multiple of 4 columns where block structure needs it. A NUL becomes U+FFFD. Link labels match after Unicode case folding, through `bend-kit-unicode`. Named character references use the HTML5 list in `entities.bend`.

`to_html_with(o: Opts, s: String) -> String` takes options. `Opts{safe, gfm}` holds two `Bool`s: `to_html` is `Opts{False{}, False{}}`, and `to_html_safe` is `Opts{True{}, False{}}`. With `gfm` set, it renders the GFM 0.29 extensions:

- Tables. A paragraph line followed by a delimiter row such as `| --- | :-: |` with the same number of cells starts a table. The rows run to the paragraph's end. `:` sets each column's `align`. A row with fewer cells gets empty ones; extra cells drop. `\|` is a pipe inside a cell.
- Task list items. A list item whose text starts with `[ ]`, `[x]`, or `[X]` and a space gets `<input disabled="" type="checkbox">`, with `checked=""` when it is ticked.
- Strikethrough. One or two `~` on each side make `<del>`. The two runs must have the same length; three or more `~` stay text.
- Extended autolinks. `www.` links start at a line start, after a space, or after `*`, `_`, `~`, or `(`. `http://`, `https://`, and `ftp://` links match in any ASCII case and do not start after an ASCII letter. URL autolinks do not start inside brackets. Email links use decoded text and can follow punctuation, as in `x:a@b.co`. Explicit `mailto:` and `xmpp:` prefixes stay inside the link. Trailing punctuation and an unbalanced `)` stay outside a link.
- The tag filter. In raw HTML, `<` becomes `&lt;` before `title`, `textarea`, `style`, `xmp`, `iframe`, `noembed`, `noframes`, `script`, and `plaintext` tags.

With both flags, safe mode still drops all raw HTML and empties unsafe URLs, autolinks included. Extended autolinks become plain text inside an explicit link. GFM output omits a `<strong>` tag whose direct parent is already `<strong>`, as cmark-gfm does. CommonMark output keeps both tags.

## Spec tests

```sh
python3 markdown/conformance.py          # pass count per section, in a native build
python3 markdown/conformance.py Links    # also print the failures in one section
python3 markdown/conformance.py --safe   # to_html_safe against the cmark CLI without --unsafe
python3 markdown/conformance.py --gfm    # the GFM spec's extension examples with gfm on
python3 markdown/conformance.py --gfm-diff # CommonMark, GFM spec, and extension corpus against cmark-gfm
python3 -B markdown/conformance-test.py   # check failure paths with controlled renderer output
python3 markdown/gen.py                  # rewrite entities.bend from Python's html.entities
```

`conformance.py` downloads `spec.json` for 0.31.2 and checks all 652 examples byte for byte. With `--safe`, it compares `to_html_safe` with cmark 0.31.2 on the same 652 inputs; all match. With `--gfm`, it runs the 24 extension examples of the cmark-gfm 0.29.0.gfm.13 spec (tables, task lists, strikethrough, autolinks, and the tag filter); all pass. `LAWS.bend` holds 25 spec examples, 8 escaping laws, 1 alt text law, 7 safe-mode laws, and 8 GFM laws. Two laws hold for every string: the text escape `esc` leaves no `<`, `>`, or `"`, and each `&` it writes starts `&amp;`, `&lt;`, `&gt;`, or `&quot;`.

`--gfm-diff` needs the `cmark-gfm` CLI (`brew install cmark-gfm` on macOS). It enables `table`, `strikethrough`, `autolink`, `tasklist`, and `tagfilter`, with `--unsafe` to match `Opts{False{}, True{}}`. It checks all 652 CommonMark inputs, the 24 official GFM extension inputs, and 224 generated cases for extension boundaries and interactions. An unexplained difference exits with status 1. Missing or extra renderer results also fail.

The comparison normalizes only cmark-gfm's checkbox attribute order and XHTML closing slash to the official GFM spec's spelling. Two exact differences remain because this package follows CommonMark 0.31.2 and cmark-gfm follows 0.29: example 28 rejects an eight-digit decimal character reference; example 354 treats Unicode currency symbols as punctuation for emphasis. Both sides must match their recorded outputs for the check to accept these differences. No other mismatch is ignored. The former list-like table-row and `[www.x.org](/y)` reports do not reproduce with cmark-gfm 0.29.0.gfm.14; both remain in the corpus.

For markdown changes, CI runs `--gfm-diff` with CI's pinned Bend and cmark-gfm 0.29.0.gfm.14 built from its release tag. The log reports the reference version and corpus totals. Other package jobs do not build the reference.

The small checker checks need no downloads, Bend compiler, or reference build. They cover output mismatches, missing and extra results, exact version exceptions, and checkbox normalization.

`bench/README.md` compares `to_html` with cmark and libraries in Rust, JavaScript, and Python.
