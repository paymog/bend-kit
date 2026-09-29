# Tar

`tar.bend` encodes and decodes regular files and directories over packed `Bytes.Bytes`. Each `File{name, data}` or `Dir{name}` carries a byte-exact path; `decode` returns entries in archive order and does not access the filesystem.

```bend
import Base
import ./tar/tar.bend as Tar
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def example() -> Maybe<&1, Bytes.Bytes>:
  Tar.encode([Tar.Dir{Bytes.from_string("assets/")}, Tar.File{Bytes.from_string("assets/a"), Bytes.from_string("hello")}])
```

`encode` writes ustar headers and local PAX path records when a name exceeds 100 bytes. `decode` accepts ustar and local PAX `path` and `size` records. The payload size is bounded by `Bytes.Bytes`'s U32 length. Unsupported entry types, bad checksums, invalid lengths, and truncated headers or payloads return `None`. The codec does not extract paths or invoke `tar`.
