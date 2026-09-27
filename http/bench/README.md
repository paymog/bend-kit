# HTTP benchmarks

## Codec

`bench.*` and `rs/` time the HTTP/1.1 codec with no socket: parse one fixed request and one fixed response, and encode one of each. Bend runs against C, Rust, JavaScript (Bun and Node), and Python.

### Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `llhttp` (`brew install llhttp`), `cargo`, `bun`, `node`, and `uv`. Cargo fetches `httparse` and `uv` fetches `h11` on the first run. Binaries go to `out/`, which git ignores. The run takes about 30 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

### Input

Each op runs 20,000 times on one message:

| op | message |
|---|---|
| `parse_req` | a 451-byte `POST` with 9 browser-like headers and a 26-byte JSON body |
| `parse_res` | a 252-byte `200` with 6 headers and a 34-byte JSON body |
| `encode_req` | a `POST` with 3 caller headers and the 26-byte body, 222 bytes out |
| `encode_res` | a `200` with 4 caller headers and the 34-byte body, 200 bytes out |

The parse checksum sums, over every message, the method and target lengths (for a request) or the status code (for a response), plus name length + value length + 1 per header, plus the body length. Bend's encoders add `host`, `connection`, and `content-length`, and write headers in sorted order, so the other encoders get the same headers. h11 moves `host` first, so the encode checksum sums a hash per line (`h = h*31 + c`, u32) and does not depend on line order. It adds the total output length. The checksums are `8200000`, `8300000`, `954665139`, and `4171655946`, in table order.

### Results

M4 Pro, macOS 26.6.2, 2026-09-26. Median of five runs. Times are in ms for 20,000 messages; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| parse_req | 4.8 (2.8x) | 1.7 (1.0x) | 17.0 (10.0x) | 19.9 (11.7x) | 440.2 (258.9x) | 453.0 (266.5x) |
| parse_res | 2.9 (2.1x) | 1.4 (1.0x) | 12.2 (8.7x) | 15.0 (10.7x) | 314.5 (224.6x) | 400.0 (285.7x) |
| encode_req | n/a | n/a | n/a | n/a | 313.7 (1.7x) | 181.0 (1.0x) |
| encode_res | n/a | n/a | n/a | n/a | 270.6 (2.1x) | 127.0 (1.0x) |

Versions: Bend 2.0.29, Apple clang 17.0.0 with llhttp 9.4.2, rustc 1.91.0 with httparse 1.10.1, Bun 1.3.14, Node 24.0.1, Python 3.14.6 with h11 0.16.0.

### The calls

| language | parse | encode |
|---|---|---|
| Bend | `Http.parse`, `Http.parse_res` | `Http.encode_req`, `Http.encode` |
| C | `llhttp_execute` with span callbacks | left out |
| Rust | `httparse::Request::parse`, `httparse::Response::parse`, then the `Content-Length` body slice | left out |
| JavaScript | `HTTPParser.execute` from Node's `_http_common` | left out |
| Python | `h11.Connection.receive_data` and `next_event` | `h11.Connection.send` |

C, Rust, and JavaScript have no HTTP/1.1 message encoder short of a client or server bound to a socket, so they have no encode rows. The JavaScript parser is Node's own llhttp binding. Its module is legacy and not documented, but Node and Bun both ship it.

### Caveats

- httparse reads only the head, so the Rust variant finds `Content-Length` and slices the body itself.
- h11 reads a response only on a connection that has sent a request, and writes one only on a connection that has read one. `bench.py` makes those 20,000 connections before the timer starts.
- C, Rust, and JavaScript reuse one parser. Python makes a connection per message. Bend has no parser state.
- Bend strings are lists, one cell per byte. The others read flat buffers.
- Bend's `IO.now` counts in whole ms. The others use sub-ms clocks.
- These are micro-benchmarks on one machine.


### Parse phase breakdown (Bend native)

`parse_phases.bend` times `Http.parse` stages in isolation on the same 20,000×451-byte request as the codec bench (one native run, ms for the whole loop):

```sh
cd http/bench && bend parse_phases.bend -o out/parse_phases && ./out/parse_phases
```

| phase | ms (2026-09-26) | what it measures |
|---|---:|---|
| full | 480 | `Http.parse` |
| split | 64 | `split_at_blank` |
| whole | 68 | split, then `blank_end` on the head |
| lines | 184 | split, then `String.lines` |
| start_line | 194 | lines, then the first line → method/path/version |
| field_ops | 243 | lines, then per header line: `drop_cr`, `split_colon` (lower inline), `trim` |
| map_build | 417 | lines, then `parse.headers` → `Map` |
| head_got | 477 | `parse.got` through head (no body rules) |
| body_len | 453 | `map_build`, then body length / hold |

Each row after `split` includes the rows it builds on. The `Map` build (about 175 ms) and `String.lines` (about 120 ms) are now the largest costs. `String.ends_with`, `String.trim_end`, and the old `drop_cr` each made a reversed copy; the single-pass versions removed most of the time they took.

## Network

`fetch16.bend` and `serve16.bend` time a live download and upload in Bend only. They measure the socket and the runtime along with the codec. See the comment at the top of each file.

```sh
bend fetch16.bend -o out/fetch16 && /usr/bin/time -l out/fetch16 http://127.0.0.1:18094/cl
bend serve16.bend -o out/serve16 && out/serve16 &
curl -s -w ' %{time_total}\n' --data-binary @16m.bin http://127.0.0.1:18093/
```

The download server is a local Python `http.server` that sends 12 MiB (byte `i` is `i % 251`), either with `Content-Length` or as 64 KiB chunks. The upload is 16 MiB of random bytes. Each program prints the body length, which is the checksum: `12582912` and `16777216`.

M4 Pro, macOS 26.6.2, Bend 2.0.29, 2026-09-26. Median of 15 downloads and 7 uploads. The time is in-process for a download and `curl` total for an upload. Peak RSS is from `/usr/bin/time -l`.

| run | http 0.15.0.4 | http 0.15.0.5 |
|---|---:|---:|
| download, Content-Length | 8 ms, 31.6 MB | 7 ms, 19.0 MB |
| download, chunked | 10 ms, 31.9 MB | 12 ms, 33.1 MB |
| upload, Content-Length | 7.8 ms, 35.9 MB | 7.9 ms, 35.9 MB |

0.15.0.5 writes a Content-Length response body into one buffer as it arrives. Chunked downloads and uploads take the same code path in both versions, so their differences are noise.
