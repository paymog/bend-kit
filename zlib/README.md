# zlib

DEFLATE, gzip, and zlib over `Bytes`, plus native gzip, zstd, and brotli.

```bend
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-zlib@0.6.1.0/zlib.bend as Zlib
import bend-kit-zlib@0.6.1.0/native.bend as Native
```

The codec takes and gives `Bytes.Bytes`. `zlib.bend` imports `bytes` 0.3.3.1, `bits` 0.3.0.1, and `hash` 0.3.2.2 from the hub. It imports no foreign effects. `LAWS.bend` and `PROOF.bend` use only this pure graph. `publish.bend` bundles both modules for the hub.

## Pure

`deflate`, `gzip`, and `zlib` compress. `inflate`, `gunzip`, and `unzlib` return `None` when the input is truncated or malformed, and `gunzip` and `unzlib` also check the CRC-32 or Adler-32. The decoder reads through a `Bits.Reader` and decodes symbols with `Bits.Huff` tables. Laws cover these functions. They do not cover the effects.

The encoder uses lazy matching with a 32 KiB window and up to 32 hash-chain candidates. It splits the input into 32 KiB blocks and picks fixed or dynamic Huffman codes by their encoded bit cost. Trees have at most 15 bits per code. `gunzip` decodes every gzip member and joins the outputs, as `gzip -d` does. It rejects bytes after a member that do not start another member.

Dynamic headers trim unused trailing lengths and encode repeated lengths with RFC 1951 symbols 16–18. Their code-length alphabet uses at most seven bits per code. Block selection includes every header bit.

## Native

Import `native.bend` for native calls. They return `IO` and fail with `(errno, message)`:

```bend
def gz(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  Native.libz.gzip(b)
```

| def | does | library | override |
|---|---|---|---|
| `libz.inflate(max, b)` | gzip (every member), zlib, or raw DEFLATE, picked from the first two bytes | `libz` | `BEND_LIBZ` |
| `libz.inflate.raw(max, b)` | one raw DEFLATE stream; trailing or cut input fails | `libz` | `BEND_LIBZ` |
| `libz.gzip(b)` | one gzip member at level 6 | `libz` | `BEND_LIBZ` |
| `zstd(max, b)` | Zstandard frames (RFC 8878) | `libzstd` | `BEND_LIBZSTD` |
| `brotli(max, b)` | Brotli (RFC 7932) | `libbrotlidec` | `BEND_LIBBROTLIDEC` |

A decoder fails with `EFBIG` when its output passes `max` bytes. A missing library is `ENOENT`.

`inflate.new`, `brotli.new`, and `zstd.new` open a streaming `Decoder`. `dec.push(d, max, b)` feeds it one chunk and returns that chunk's output; `max` caps that call, not the whole stream. `dec.finish(d)` checks the end marker and releases the decoder, so call it even after a failed push.

The `.words` defs are the effect boundary: packed `(len, Array<U32>)`. Call the `Bytes` defs above instead.
