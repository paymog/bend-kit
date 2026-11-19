# CommonMark render benchmark

This times `to_html` on one document against cmark in C and popular CommonMark libraries in Rust, JavaScript, and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `cmark` (`brew install cmark`), `cargo`, `bun`, `node`, and `uv`. Cargo fetches `pulldown-cmark`, `bun install` fetches `markdown-it`, and `uv` fetches `markdown-it-py` on the first run. Binaries go to `out/`, which git ignores. The run takes about 25 seconds. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The work

The document is 100 copies of one section, numbered 0 to 99: an ATX heading, a paragraph with emphasis, strong emphasis, a code span, an inline link with a title, entity references, and inline HTML, a bullet list with a nested list, an ordered list, a block quote, a fenced code block, and a thematic break. It is 35,550 bytes. Each program builds the document before it starts the clock. Then it renders 10 times and sums the output lengths.

Each program prints FNV-1a over one output and the summed length. The checksum is `1940336995`, and the length is `586500` bytes. The six outputs are the same bytes.

| language | call |
|---|---|
| Bend | `M.to_html` |
| C | cmark 0.31.2: `cmark_markdown_to_html` with `CMARK_OPT_UNSAFE`, so raw HTML passes through as in the others |
| Rust | pulldown-cmark 0.13.6: `html::push_html` over `Parser::new_ext` with no extensions |
| JavaScript | markdown-it 14.1.0 with the `commonmark` preset |
| Python | markdown-it-py 4.0.0 with the `commonmark` preset |

## Results

M4 Pro, macOS 26.7.2, 2026-11-15. Bend 2.0.38, Apple clang 17.0.0, rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Median of five runs. Times are in ms for 10 renders; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| render | 5.7 (2.4x) | 2.3 (1.0x) | 21.3 (9.1x) | 22.0 (9.5x) | 239.1 (102.8x) | 135.2 (58.2x) |

Bend took 311.8 ms on 2026-11-13. `Bool.pick` evaluates both of its branches, so the block parser built every candidate block for each line, and the HTML escape built four escaped tails for each code point. `markdown` 0.3.1.0 takes those branches through `when`, which evaluates only the chosen one. Block parsing fell from 171 ms to 85 ms, and escaping the whole document from 81 ms to 7 ms.

## Paragraph scaling

`scale.bend` times one render of one paragraph of N copies of a line, followed by the definition `[foo]: /url`. The `plain` line has emphasis, strong emphasis, a code span, and an entity reference. The `links` line also has an inline link with a title. The `html` line is `Some <b>bold</b> text here.`, with two raw HTML tags. The `gfm` line is `See https://example.com/a for more.`, rendered with `gfm` on, so it has an extended autolink. The `ref` line is `See [foo] here.`, a shortcut reference link. The `noref` line is `See [plain] here.`, with no definition. The `stray` line is `See plain] here.`, with no open bracket. The `closers` line is `Some a* b_ text here.`, with two emphasis closers that have no opener. The `comment` line is `a <!-- b` and the `decl` line is `a <!x b`; neither is ever closed. Doubling N should about double the time.

```sh
bend scale.bend -o out/scale && ./out/scale
```

M4 Pro, 2026-11-17, Bend 2.0.38, one run. Times are in ms. `before` is `markdown` 0.3.1.0; `after` is 0.3.2.0.

| lines | links before | links after | plain before | plain after |
|---:|---:|---:|---:|---:|
| 100 | 15.3 | 3.4 | 4.9 | 2.4 |
| 200 | 55.7 | 6.2 | 17.0 | 5.5 |
| 400 | 234.2 | 13.1 | 61.2 | 11.0 |
| 800 | 979.1 | 27.0 | 235.8 | 23.0 |
| 1600 | 4023.8 | 62.9 | 923.1 | 46.6 |

Three passes grew with the square of the paragraph length. `find` matched each emphasis closer through `Bool.pick`, so it walked the whole stack below the opener too. Each link deactivated the brackets in every inline before it. Each link also computed its reference label from the lengths of two tails of the paragraph, even when the inline link matched. `find` now takes the chosen branch through `when`. A link leaves an `IMark`, and `deact` stops at it. The reference label waits for the inline link to fail.

Raw inline HTML, M4 Pro, 2026-11-18, Bend 2.0.38, one run. Times are in ms. `before` is `markdown` 0.3.2.0; `after` is 0.3.3.0.

| lines | html before | html after |
|---:|---:|---:|
| 100 | 7.6 | 1.1 |
| 200 | 39.0 | 2.4 |
| 400 | 177.9 | 5.1 |
| 800 | 779.8 | 10.5 |
| 1600 | 3229.6 | 23.3 |

Each raw HTML tag measured the rest of the paragraph three times: twice to cut out its own text, and once for the fuel of its attribute loop. The tag parsers now return the length of the tag. The attribute loop takes its fuel from the text itself, one code point for each attribute, so it never measures the text.

GFM extended autolinks, M4 Pro, 2026-11-18, Bend 2.0.38, one run. Times are in ms. `before` is `markdown` 0.3.3.0; `after` is 0.3.4.0.

| lines | gfm before | gfm after |
|---:|---:|---:|
| 100 | 9.5 | 3.5 |
| 200 | 35.2 | 7.0 |
| 400 | 124.8 | 14.4 |
| 800 | 466.3 | 28.4 |
| 1600 | 2068.9 | 67.6 |

Two passes grew with the square of the paragraph length. Each scheme autolink measured the rest of the paragraph to find the length of its scheme. The table search ran on every GFM paragraph, even with no `|`, and reversed the lines above each line through `Bool.pick`. The scheme length now comes from the scheme, and the table search takes its branches through `when`.

Brackets, M4 Pro, 2026-11-18, Bend 2.0.38, one run. Times are in ms. `before` is `markdown` 0.3.4.0; `after` is 0.3.5.0.

| lines | ref before | ref after | noref before | noref after | stray before | stray after |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 2.5 | 0.9 | 3.0 | 0.9 | 1.3 | 0.8 |
| 200 | 11.3 | 1.9 | 14.0 | 2.1 | 4.3 | 2.1 |
| 400 | 48.7 | 4.6 | 58.3 | 4.0 | 15.8 | 3.4 |
| 800 | 196.1 | 9.1 | 235.9 | 8.2 | 60.7 | 7.3 |
| 1600 | 785.3 | 18.5 | 943.1 | 19.2 | 237.1 | 13.8 |

Each `]` after a failed inline link measured the rest of the paragraph twice to cut out its raw label, and a `]` with no open bracket walked every inline before it. The raw label is now the text up to the first unescaped bracket after the `[`, which `label` scans. When a code span, raw HTML, or autolink in the brackets holds a `]`, the label may stop early, so that case still measures the rest of the paragraph. The scanner counts open brackets, and a `]` with none open is text at once.

Emphasis closers with no opener, M4 Pro, 2026-11-18, Bend 2.0.38, one run. Times are in ms. `before` is `markdown` 0.3.5.0; `after` is 0.3.6.0.

| lines | closers before | closers after |
|---:|---:|---:|
| 100 | 3.6 | 1.1 |
| 200 | 14.4 | 2.3 |
| 400 | 58.3 | 4.7 |
| 800 | 229.2 | 9.5 |
| 1600 | 843.2 | 19.3 |

Each closer with no opener searched the whole stack. The emphasis pass now keeps the reference implementation's `openers_bottom`: for each closer kind (character, whether the closer can open, and its length mod 3) the height below which no opener fits. A miss raises that height to the top of the stack, and a match lowers every height to the new top.

Unclosed HTML comments and declarations, M4 Pro, 2026-11-18, Bend 2.0.38, one run. Times are in ms. `before` is `markdown` 0.3.6.0; `after` is 0.3.7.0.

| lines | comment before | comment after | decl before | decl after |
|---:|---:|---:|---:|---:|
| 100 | 1.5 | 0.5 | 1.0 | 0.5 |
| 200 | 5.0 | 1.1 | 4.0 | 1.0 |
| 400 | 22.1 | 2.4 | 17.9 | 2.1 |
| 800 | 87.4 | 5.6 | 74.1 | 5.0 |
| 1600 | 355.1 | 10.9 | 285.9 | 9.5 |

Each `<!--`, `<?`, `<![CDATA[`, or `<!` with a letter scanned the rest of the paragraph for its closer. When the closer was missing, every later one scanned again. The scanner now remembers, as cmark does, which closers a failed `<` showed to be missing, and skips those scans for the rest of the paragraph.

## Caveats

- Bend reads and writes `String`, a list with one cell per code point. The others read flat buffers.
- Bend splits the input into lines, then walks each line once per open container and once per block start it tries.
- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one thread.
