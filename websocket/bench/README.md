# WebSocket benchmark

This times the frame hot path, a client masking and encoding a binary frame and a server parsing and unmasking it, in Bend, Rust, JavaScript (Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, `bun`, `node`, and `python3`. `run.py` installs `ws@8.22.0` with `bun install` and `websockets==17.1` with `pip install --target` into `out/`, which git ignores, and builds the Rust and Bend programs there. It exits non-zero if a build fails or if two languages print different checksums.

## Input

A 65,536-byte payload, byte `i` = `(7 * i) & 255`, made before the timer starts. Each of **256** rounds masks it with the fixed key `37 fa 21 3d`, encodes one final binary frame (a 14-byte header with the 64-bit length), then parses that frame as a server would and unmasks the payload. 16 MiB go each way.

- **Bend**: `WS.encode(Frame{True, 2, payload}, Some{key})`, then `WS.parse(True, 1 MiB, wire)`. Bytes are affine, so each round slices a fresh copy of the payload.
- **Rust**: `tungstenite` 0.29, `Frame::message` with `header_mut().mask` set, `Frame::format`, then `FrameSocket::read`. `FrameSocket` keeps the mask and the crate's `apply_mask` is private, so the parsed frame is formatted once more, which XORs the mask back off.
- **Node**: `ws` 8.22 `Sender.frame` with a fixed `generateMask`, then a server `Receiver`. Bun replaces `ws` with its own module, which has no `Receiver`, so JavaScript runs on Node only.
- **Python**: `websockets` 17.1 `Frame.serialize(mask=True)` with `secrets.token_bytes` pinned to the key, then `Frame.parse(mask=True)` on a `StreamReader`.
- **C**: left out. libc has no WebSocket framing, and the popular C libraries (libwebsockets, wslay) run frames only through their connection state machines.

Each round adds its wire length, wire octet 20, and decoded payload octet 65535 to a wrapping U32. Expected checksum: **16847360** (256 × (65550 + 11 + 249)).

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-09-27. Median of three runs (`python3 run.py`). MB/s counts payload bytes, one way.

| variant | frame ms | MB/s | vs fastest |
|---:|---:|---:|---:|
| Rust | 1.8 | 9,310 | 1.0x |
| Node | 27.0 | 622 | 15.0x |
| Python | 2.8 | 6,076 | 1.5x |
| Bend | 35.3 | 476 | 19.6x |

Bend masks a U32 word at a time in pure Bend; Rust and Python (`websockets`' C speedup) XOR in native loops. Bend peak RSS was about 2 MB (`/usr/bin/time -l`).

Versions: Bend 2.0.32, Rust 1.91.0 (`tungstenite` 0.29.0), Node 24.0.1 (`ws` 8.22.0), Python 3.14.6 (`websockets` 17.1).
