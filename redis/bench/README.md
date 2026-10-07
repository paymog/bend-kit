# RESP decode benchmark

This times decoding one fixed recording of Redis replies into each library's reply values, in Bend and in C, Rust, JavaScript (Bun and Node), and Python. No server runs.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 100,000 replies
python3 run.py 5        # 5 runs
python3 run.py 1 1000   # 1 run on 1,000 replies (small smoke run)
```

You need `bend` (2.0.35, the version CI pins), `cc` with Homebrew `hiredis` in `/opt/homebrew`, `cargo`, `npm`, `bun`, `node`, and `uv`. On the first run, Cargo fetches the `redis` crate, `npm` installs `ioredis` into `out/js`, and `uv` fetches `redis-py`. Binaries go to `out/`, which git ignores. The full run takes about 10 seconds. It exits non-zero if a build or a run fails, or if a checksum differs from the one `run.py` computes from its own values.

## Input

`run.py` writes `out/replies.resp`: 100,000 RESP3 replies, 3,377,580 bytes. Reply `i` is kind `i % 8` of what a GET/SET/INCR/LRANGE/HGETALL/SCAN/SISMEMBER workload sees:

- `+OK`
- a bulk string of `i % 100` bytes (`(i*7 + j) & 255`, so CR, LF, and high bytes all occur)
- a null (`_`)
- an integer, `i*1000003 - 2^40` (negative, then positive, past 32 bits)
- an array of `i % 10` bulk strings
- a map of `i % 5` bulk-string pairs
- a SCAN-style array: a cursor, then an array of `i % 7` keys
- a boolean

The recording leaves out doubles, big numbers, sets, verbatim strings, errors, attributes, and pushes. Python and Rust turn doubles into floats, which would make the checksum depend on float formatting; Python sets have no order; and redis-py raises errors and skips attributes.

Every program takes the replies into its library's values; only that is timed. The checksum then walks each reply in pre-order with `h = h*31 + x` (u32, wrapping): 1 for a string, then its length and bytes; 2 for an integer, then its low 32 bits; 3 for a null; 4 and 5 around array items; 6 and 7 around map keys and values; 8 for a boolean, then 0 or 1. The reply count is added last. Every checksum must equal `run.py`'s: `4096574027` for 100,000 replies and `443590310` for 1,000.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27. `python3 run.py 5`, median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| decode | 8.4 (1.0x) | 20.9 (2.5x) | 33.8 (4.0x) | 52.6 (6.3x) | 126.9 (15.1x) | 16.0 (1.9x) |

Versions: Bend 2.0.31, Apple clang 17.0.0 with hiredis 1.4.1, rustc 1.91.0 with redis 1.7.1, Bun 1.3.14 and Node 24.0.1 with ioredis 6.0.0, Python 3.14.6 with redis-py 8.1.0.

Bend's `IO.now` counts whole ms, so Bend times are integers. The Bend binary peaked at about 145 MB RSS (`/usr/bin/time -l out/bend`).

## The calls

| language | decode |
|---|---|
| Bend | `Redis.feed` then `Redis.next` until `Want`, per 64 KiB piece |
| C | hiredis `redisReaderFeed` then `redisReaderGetReply` until no reply, per 64 KiB piece |
| Rust | `redis::Parser::parse_value` on the whole buffer until it fails at the end |
| JavaScript | ioredis `resp/decoder.js` `Decoder.write`, per 64 KiB piece |
| Python | redis-py `_RESP3Parser.read_response(disable_decoding=True)` over a stand-in socket that returns 64 KiB per `recv` |

hiredis moves its unread bytes to the front of its buffer after every 1 KiB it decodes, so one 3 MB feed makes it quadratic; a socket never hands it that much at once. The ioredis decoder is internal (`ioredis/built/resp/decoder.js`, from node-redis). It turns map keys into UTF-8 strings, so the JavaScript checksum converts them back to bytes; every key here is ASCII. Its integers are JavaScript numbers, exact below 2^53, which covers this input.
