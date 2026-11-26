# Mustache render benchmark

This times packed UTF-8 rendering on one parsed template against popular Mustache libraries in Rust, JavaScript, and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, `bun`, `node`, and `uv`. Cargo fetches `mustache`, `bun install` fetches `mustache.js`, and `uv` fetches `chevron` on the first run. Binaries go to `out/`, which git ignores. The run takes about 10 seconds. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The work

The template is a list with a nested section:

```mustache
<ul>
{{#items}}
  <li><a href="{{url}}">{{name}}</a>{{#tags}} [{{.}}]{{/tags}}</li>
{{/items}}
</ul>
```

The context has 200 items. Item `i` has the name `Item i & co`, the URL `/items/i?a=1&b="2"`, and the tags `new` and `<hot>` when `i` is even, or no tags when `i` is odd. Each program builds the context and parses the template before it starts the clock. Then it renders 100 times and sums the output lengths.

Each program prints FNV-1a over one output and the summed length. The checksum is `2909106112`, and the length is `1739100` bytes.

| language | call |
|---|---|
| Bend | `T.render_bytes` on the nodes from `T.parse` |
| Rust | `mustache` 0.9.0: `Template::render_data` on a `compile_str` template and a `MapBuilder` context |
| JavaScript | `mustache.js` 4.2.0: `Mustache.render`, which reuses the template that `Mustache.parse` cached |
| Python | `chevron` 0.14.0: `chevron.render` |

C is left out. It has no standard or very popular Mustache library.

## Results

M4 Pro, macOS, 2026-11-24. Bend 2.0.40, rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Each row is a median of five runs from `python3 template/bench/run.py 5`. Times are in ms for 100 renders.

| output | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| Before: linked text | 4.1 | 8.2 | 10.0 | 92.3 | 68.2 |
| After: packed UTF-8 | 4.0 | 8.5 | 10.1 | 93.3 | 40.9 |
| After: repeated | 4.2 | 8.3 | 10.1 | 93.5 | 41.3 |

Packed output takes 40% less time than linked text. The repeat stays within 1% of the first packed result. All runs give checksum `2909106112` and summed length `1739100`. The checksum reads one rendered buffer outside the timer. Each timed render consumes its buffer and adds its byte length.

The renderer writes UTF-8 into a growing buffer and uses the encoding package's word accumulator. Variables escape into that accumulator, rather than append an escaped fragment to a linked output string. The text API remains available and its pure proofs do not change.

## Caveats

- `chevron.render` tokenizes the template on every call. The other libraries render a parsed template.
- `mustache.js` escapes `/`, `` ` ``, and `=` as well. `bench.ts` sets `Mustache.escape` to the same five characters as the others.
- Text nodes and values remain Unicode strings. Parsed line markers tell both renderers where partial indentation belongs. The packed path writes nested partials into the caller's buffer without a separate buffer or trailing-indentation trim. The fixed input has no partials, so these results do not measure partial-heavy workloads.
- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one thread.

## Unicode partial workloads

Run two independent five-run batches from this directory:

```sh
python3 partials.py 5 > out/partials-first.json
python3 partials.py 5 > out/partials-repeat.json
python3 run.py 5
```

Create `out/` first when you redirect there: `mkdir -p out`.
The new runner prints every timing, five-run medians, FNV-1a checksums, and summed UTF-8 lengths as JSON. It rejects missing fields and output that differs from the fixed expected checksums and lengths.

Both workloads render `{{#items}}\n  {{>p}}\n{{/items}}` 100 times. Each item has `x: true`. The outer context has `v: "é猫😀 & <"`.

- **Large:** 16 items. Partial `p` repeats `猫😀 {{v}}\n\n{{{v}}}\n` 128 times.
- **Nested:** 200 items. Partial `p` is `猫\n{{v}}\n\n  {{>q}}\n`. Partial `q` is `😀\n\n{{{v}}}\n`.

These inputs cover blank lines, trailing LF, escaped and raw non-ASCII variables, and composed indentation. Each blank line stays empty. The nested emoji line has four spaces, not six.

| workload | UTF-8 bytes per render | bytes over 100 renders | FNV-1a |
|---|---:|---:|---:|
| Large | 98,304 | 9,830,400 | 3491016133 |
| Nested | 11,600 | 1,160,000 | 715866821 |

M4 Pro, macOS, 2026-11-26. Bend 2.0.40, Bun 1.4.4, Node 24.0.1, Python 3.14.6. JavaScript uses mustache.js 4.2.0. Python uses Pystache 0.6.8. Each cell is a five-run median in ms for 100 renders.

| workload / batch | Bend packed | Bend text + UTF-8 | Bun | Node | Python |
|---|---:|---:|---:|---:|---:|
| Large / first | 156.37 | 234.77 | 54.96 | 72.98 | 759.59 |
| Large / repeat | 155.35 | 234.62 | 55.80 | 72.36 | 748.40 |
| Nested / first | 24.42 | 32.86 | 11.16 | 16.80 | 223.62 |
| Nested / repeat | 24.10 | 32.38 | 11.17 | 16.77 | 224.15 |

All runs match the checksums and UTF-8 lengths above. Packed rendering takes 33–34% less time for large partials and 25–26% less for nested partials than text rendering followed by UTF-8 encoding. This is an API comparison, not evidence of a gain from a new optimization.

The nested-indentation fix already removed linked-text indentation copies, per-partial packed buffers, and trailing-indentation slices. Both renderers now use parsed line markers. No renderer change is made here. The measurements do not justify adding another fused path.

The original 200-item benchmark programs and input remain unchanged. Its new five-run medians are Rust 4.1, Bun 8.7, Node 10.3, Python 94.6, and Bend 42.2 ms. Its checksum remains `2909106112`, with `1739100` summed bytes.

### Partial benchmark limits

- All timed paths produce UTF-8 bytes. Bend text includes `Encoding.utf8.encode`; JavaScript includes `TextEncoder`; Python includes `.encode("utf-8")`. FNV-1a runs outside the timer.
- Bend parses all templates before timing. mustache.js caches the root and indented partial templates after the untimed checksum render. Pystache parses the root once but parses indented partials during rendering.
- Chevron 0.14.0 and Rust mustache 0.9.0 were tried, but disagree on these inputs. On the large workload, Chevron adds spaces to blank lines (102,400 bytes, checksum `3253865925`). Rust gives 90,160 bytes and checksum `3918734789`. They are excluded from this comparison, not normalized to hide the differences. The original benchmark still includes both.
- This measures the corrected renderer on one machine. It does not compare the old incorrect indentation algorithm.
