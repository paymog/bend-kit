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

`scale.bend` times one `to_html` call on one paragraph of N copies of a line. The `plain` line has emphasis, strong emphasis, a code span, and an entity reference. The `links` line also has an inline link with a title. The `html` line is `Some <b>bold</b> text here.`, with two raw HTML tags. Doubling N should about double the time.

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

## Caveats

- Bend reads and writes `String`, a list with one cell per code point. The others read flat buffers.
- Bend splits the input into lines, then walks each line once per open container and once per block start it tries.
- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one thread.
