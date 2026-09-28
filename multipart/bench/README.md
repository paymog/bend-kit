# Multipart benchmark

This times `multipart/form-data` encode and decode on one fixed form, in Bend and in Go, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `go`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 10 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

Boundary `bend-kit-0123456789abcdef0123456789abcdef`, three parts:

| part | headers | body |
|---|---|---|
| `title` | `Content-Disposition` | `hello multipart` |
| `blob` | `Content-Disposition` with `filename="blob.bin"`, `Content-Type: application/octet-stream` | 1,048,576 bytes: `x = x * 1103515245 + 12345` (u32) from `x = 1`, each byte `x >> 24` |
| `note` | `Content-Disposition` | `end` |

The encoded body is 1,048,985 bytes. The blob holds every octet, including CR, LF, and `-`.

Each program builds its input before its timer starts and times only the op. `encode` turns the three parts into the body; its checksum is `h = h*31 + byte` over the body, in wrapping u32, plus its length: `142527152`. `decode` turns the body back into parts, whole; its checksum runs the same hash over each part's name and then its body, plus their total length: `3916597363`.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27, `multipart` 0.1.0.0. Median of three runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | Go | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| encode | 0.1 (1.0x) | n/a | n/a | n/a | 4.4 (38.3x) |
| decode | 0.5 (1.2x) | 0.4 (1.0x) | 10.0 (24.0x) | 18.3 (44.0x) | 7.4 (17.8x) |

Versions: Bend 2.0.32, Go 1.27.1, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | encode | decode |
|---|---|---|
| Bend | `Mp.encode` | `Mp.decode`, one `feed` of the whole body |
| Go | `mime/multipart` `Writer` with `SetBoundary` | `mime/multipart` `Reader.NextPart` and `io.ReadAll` |
| JavaScript | left out | `new Response(body).formData()` |
| Python | left out | `email.parser.BytesParser` with `policy.HTTP`, `iter_parts`, `get_payload(decode=True)` |

C and Rust have no multipart codec in their standard libraries, and neither has one popular library that builds with a bare compiler, so they are left out. Python's standard library has no `form-data` encoder (`cgi` is gone, and `email.mime` writes MIME headers `form-data` does not use). `new Response(FormData)` in JavaScript picks its own random boundary, so its bytes cannot match the others' checksum. Those rows are `n/a`.

## Caveats

- Go's `Writer` puts the same header lines in the same order as `Mp.encode`, which is why the encode checksums agree.
- Bend's encode also scans each body for the delimiter, so a caller's boundary cannot break the body; Go's does not.
- Bun's first run pays for warmup, about 5 ms; the median hides it.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.
