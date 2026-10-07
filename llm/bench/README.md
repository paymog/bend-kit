# SSE parse benchmark

This times parsing one fixed recording of Server-Sent Events into each library's events, in Bend and in Rust, JavaScript (Bun and Node), and Python. No server runs. C is left out: it has no standard or widely used SSE parser.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 100,000 events
python3 run.py 5        # 5 runs
python3 run.py 1 1000   # 1 run on 1,000 events (small smoke run)
```

You need `bend` (2.0.35, the version CI pins), `cargo`, `npm`, `bun`, `node`, and `uv`. On the first run, Cargo fetches `eventsource-stream`, `npm` installs `eventsource-parser` into `out/js`, and `uv` fetches `sseclient-py`. Binaries go to `out/`, which git ignores. The full run takes about 15 seconds. It exits non-zero if a build or a run fails, or if a checksum differs from the one `run.py` computes from its own events.

## Input

`run.py` writes `out/stream.sse`: 100,000 events, 12,415,223 bytes, cut from back-to-back Anthropic Messages streams. Each stream is `message_start`, `content_block_start`, `ping`, 20 `content_block_delta` events of 1 to 6 words, `content_block_stop`, `message_delta`, and `message_stop`. Every event has an `event:` line and one `data:` line of compact JSON, and ends with a blank line. Some text is not ASCII (é, ï, an em dash, an emoji), so a 64 KiB piece can end inside a UTF-8 sequence.

Every program reads the file into memory, then feeds it to its parser 64 KiB at a time, as a socket would, and collects every event. Only that is timed. The checksum then walks the events with `h = h*31 + x` (u32, wrapping): 1, the event type's UTF-8 bytes, 2, the data's UTF-8 bytes. The event count is added last. Every checksum must equal `run.py`'s: `117961970` for 100,000 events and `546741534` for 1,000.

## Results

M4 Pro, macOS 26.6.2, 2026-09-28. `python3 run.py 5`, median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| parse | 163.0 (10.5x) | 15.5 (1.0x) | 28.4 (1.8x) | 154.1 (9.9x) | 40.0 (2.6x) |

Versions: Bend 2.0.32, rustc 1.91.0 with eventsource-stream 0.2.3 (futures 0.3.34, bytes 1.12.1), Bun 1.3.14 and Node 24.0.1 with eventsource-parser 4.1.1, Python 3.14.6 with sseclient-py 1.9.0.

Bend's `IO.now` counts whole ms, so Bend times are integers. The Bend binary peaked at about 540 MB RSS (`/usr/bin/time -l out/bend`), most of it the file read as a list of octets before the timer starts.

## The calls

| language | parse |
|---|---|
| Bend | `Sse.feed` then `Sse.next` until `Want`, per 64 KiB piece |
| Rust | `eventsource_stream::Eventsource::eventsource` over a `futures` stream of 64 KiB `Bytes`, collected with `block_on` |
| JavaScript | eventsource-parser `createParser({onEvent}).feed`, per 64 KiB piece decoded with a streaming `TextDecoder` |
| Python | sseclient-py `SSEClient(pieces).events()` over a generator of 64 KiB pieces |

eventsource-parser and sseclient-py take text, so their times include UTF-8 decoding; Bend keeps the data as bytes. eventsource-stream decodes each piece to UTF-8 and parses lines with `nom`.
