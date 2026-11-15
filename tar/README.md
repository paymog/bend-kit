# Tar

`tar.bend` encodes and decodes regular files and directories over packed `Bytes.Bytes`. Each `File{name, data}` or `Dir{name}` carries a byte-exact path; `decode` returns entries in archive order and does not access the filesystem.

```bend
import Base
import bend-kit-tar@0.3.0.0/tar.bend as Tar
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def example() -> Maybe<&1, Bytes.Bytes>:
  Tar.encode([Tar.Dir{Bytes.from_string("assets/")}, Tar.File{Bytes.from_string("assets/a"), Bytes.from_string("hello")}])
```

`encode` writes ustar headers and local PAX path records when a name exceeds 100 bytes. `decode` accepts ustar and local PAX `path` and `size` records. The payload size is bounded by `Bytes.Bytes`'s U32 length. Unsupported entry types, bad checksums, invalid lengths, and truncated headers or payloads return `None`. The codec does not extract paths or invoke `tar`.

`encode` returns `None` for an empty name, a name with a NUL byte, or an archive that exceeds the U32 length limit.

The decoder advances one `Bytes.Cursor`. Header reads are limited to one 512-byte block. Payload and PAX record regions exclude padding and following records. It copies only decoded names and file data, not the input archive.

## API

| Def | Result |
|---|---|
| `decode(archive: Bytes.Bytes)` | `Maybe<&1, List<&1, Entry>>` |
| `encode(entries: List<&1, Entry>)` | `Maybe<&1, Bytes.Bytes>` |
