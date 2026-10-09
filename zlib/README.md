# zlib

DEFLATE, gzip, and zlib over byte strings, plus native gzip, zstd, and brotli.

```bend
import bend-kit-zlib@0.2.0.1/zlib.bend as Zlib
```

The pure functions take a `String` with one `Char` per octet, 0..255. `deflate`, `gzip`, and `zlib` compress. `inflate`, `gunzip`, and `unzlib` return `None` when the input is truncated or malformed. Laws cover these functions. They do not cover the effects.

The fast path is packed words, four octets per `U32`, and it is `IO`:

```bend
def gz(len: U32, words: Array<U32>) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Zlib.gzip.words(len, words)
```

`inflate.words`, `brotli.words`, and `zstd.words` take a maximum output size and fail with `EFBIG` above it. `gzip.words` compresses. `inflate.new` and `dec.feed.words` stream a raw DEFLATE decode. The `max` on `dec.feed.words` caps that call, not the whole stream.

| Effect | Library | Override |
|---|---|---|
| `inflate.words`, `gzip.words` | `libz` | `BEND_LIBZ` |
| `zstd.words` | `libzstd` | `BEND_LIBZSTD` |
| `brotli.words` | `libbrotlidec` | `BEND_LIBBROTLIDEC` |

A missing library is `ENOENT`. `http` imports this package as `0xaca98ab7f724003ea421c18792cafe52`, which is this version. `archive@0.2.0.0` still imports `bend-kit-zlib@0.1.6.0`.
