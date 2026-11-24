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
- Text nodes and values remain Unicode strings. Indented partial text still uses the existing text indentation helper. Partials render into separate packed buffers, trim trailing indentation, and append once to their caller. The fixed input has no partials, so these results do not measure partial-heavy workloads.
- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one thread.
