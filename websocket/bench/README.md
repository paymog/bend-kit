# WebSocket benchmark

This times two hot paths in Bend, Rust, JavaScript (Node), and Python: **frame**, a client masking and encoding a binary frame and a server parsing and unmasking it, and **stream**, a client decoding many frames from fixed-size socket reads.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, `bun`, `node`, and `python3`. `run.py` installs `ws@8.22.0` with `bun install` and `websockets==17.1` with `pip install --target` into `out/`, which git ignores, and builds the Rust and Bend programs there. It exits non-zero if a build fails or if two languages print different checksums.

## Input

**frame**: a 65,536-byte payload, byte `i` = `(7 * i) & 255`, made before the timer starts. Each of **256** rounds masks it with the fixed key `37 fa 21 3d`, encodes one final binary frame (a 14-byte header with the 64-bit length), then parses that frame as a server would and unmasks the payload. 16 MiB go each way.

- **Bend**: `WS.encode(Frame{True, 2, payload}, Some{key})`, then `WS.parse(True, 1 MiB, Bytes.Cursor.new(wire))`. Bytes are affine, so each round slices a fresh copy of the payload.
- **Rust**: `tungstenite` 0.29, `Frame::message` with `header_mut().mask` set, `Frame::format`, then `FrameSocket::read`. `FrameSocket` keeps the mask and the crate's `apply_mask` is private, so the parsed frame is formatted once more, which XORs the mask back off.
- **Node**: `ws` 8.22 `Sender.frame` with a fixed `generateMask`, then a server `Receiver`. Bun replaces `ws` with its own module, which has no `Receiver`, so JavaScript runs on Node only.
- **Python**: `websockets` 17.1 `Frame.serialize(mask=True)` with `secrets.token_bytes` pinned to the key, then `Frame.parse(mask=True)` on a `StreamReader`.
- **C**: left out. libc has no WebSocket framing, and the popular C libraries (libwebsockets, wslay) run frames only through their connection state machines.

Each round adds its wire length, wire octet 20, and decoded payload octet 65535 to a wrapping U32. Expected checksum: **16847360** (256 × (65550 + 11 + 249)).

**stream**: **16,384** unmasked final binary frames, each the first 1,000 octets of that payload with a 4-byte header, built before the timer starts (16,449,536 octets). The client decoder gets them in reads of 65,536 octets, so frames and headers split across reads. Each frame adds its payload length and payload octet 999 to a wrapping U32. Expected checksum: **17711104** (16384 × (1000 + 81)).

- **Bend**: `WS.push` appends each read to the `Bytes.Cursor` input, and `WS.parse(False, 1 MiB, input)` runs until `Need`, as `recv` does.
- **Rust**: `FrameSocket::read` over a `Read` that returns at most 65,536 octets per call.
- **Node**: a client `Receiver`, one `write` per read.
- **Python**: `Frame.parse(mask=False)` on a `StreamReader`; on each yield the next read goes in with `feed_data`.

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-10-08. Median of three runs (`python3 run.py`). MB/s counts payload bytes, one way.

| frame | ms | MB/s | vs fastest |
|---:|---:|---:|---:|
| Rust | 1.8 | 9,158 | 1.0x |
| Node | 26.5 | 633 | 14.5x |
| Python | 2.6 | 6,341 | 1.4x |
| Bend | 35.0 | 480 | 19.1x |

| stream | ms | MB/s | vs fastest |
|---:|---:|---:|---:|
| Rust | 1.1 | 15,398 | 1.0x |
| Node | 8.4 | 1,956 | 7.9x |
| Python | 24.5 | 668 | 23.0x |
| Bend | 10.6 | 1,548 | 9.9x |

Bend masks a U32 word at a time in pure Bend; Rust and Python (`websockets`' C speedup) XOR in native loops. In stream, a decoded frame moves the cursor and copies only its payload; before the cursor, each frame copied the rest of its read and stream took about 89 ms. Bend peak RSS was about 36 MB (`/usr/bin/time -l`), most of it the 16 MB stream input.

Versions: Bend 2.0.36, Rust 1.91.0 (`tungstenite` 0.29.0), Node 24.0.1 (`ws` 8.22.0), Python 3.14.6 (`websockets` 17.1).
