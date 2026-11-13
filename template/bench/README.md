# Mustache render benchmark

This times `render` on one parsed template against popular Mustache libraries in Rust, JavaScript, and Python.

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
| Bend | `T.render` on the nodes from `T.parse` |
| Rust | `mustache` 0.9.0: `Template::render_data` on a `compile_str` template and a `MapBuilder` context |
| JavaScript | `mustache.js` 4.2.0: `Mustache.render`, which reuses the template that `Mustache.parse` cached |
| Python | `chevron` 0.14.0: `chevron.render` |

C is left out. It has no standard or very popular Mustache library.

## Results

M4 Pro, macOS 26.6.2, 2026-11-13. Bend 2.0.38, rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in ms for 100 renders; `Nx` is the multiple of the fastest variant.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| render | 4.2 (1.0x) | 10.9 (2.6x) | 11.0 (2.6x) | 96.7 (23.2x) | 104.9 (25.1x) |

## Caveats

- `chevron.render` tokenizes the template on every call. The other libraries render a parsed template.
- `mustache.js` escapes `/`, `` ` ``, and `=` as well. `bench.ts` sets `Mustache.escape` to the same five characters as the others.
- Bend strings are lists, one cell per character. The output is built by `++` on those lists.
- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one thread.
