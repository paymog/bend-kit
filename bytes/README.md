# bytes

Packed byte buffers with affine ownership. Four octets occupy each U32 array word.

```bend
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

def show(r: Bytes.Bytes & U32) -> IO(Unit):
  (b, n) = r
  IO.print(U32.show(n) ++ " " ++ Bytes.to_string(b))

def main() -> IO(Unit):
  show(Bytes.length(Bytes.from_string("hi")))
```

`get` returns the buffer beside `None` when the index is past `len`. `set` then leaves the buffer unchanged. `from_hex` returns `None` for an odd length or a non-hex character. U64 reads need `bend-kit-int@0.2.0.0`. `http` does not use this version for `Http.Body`. It uses `0x49814d83de8f70993a43e1002be29ecd/bytes.bend`.


## Positional reads and writes

Import `bend-kit-bytes@0.3.2.0/bytes.bend`. `Cursor.new(bytes)` owns the
existing buffer at position zero. `Cursor.u8`, `Cursor.u16be/le`,
`Cursor.u32be/le`, and `Cursor.u64be/le` return `(cursor, Maybe(value))`.
`None` means incomplete bytes, not an invalid protocol value. A failed read
keeps both position and contents unchanged.

`Cursor.put.u8`, `Cursor.put.u16be/le`, `Cursor.put.u32be/le`, and
`Cursor.put.u64be/le` return `(cursor, Bool)`. Writes mutate the existing
packed array. `False` leaves the complete field and position unchanged.
The scalar value keeps its low 8, 16, 32, or 64 bits.

`Cursor.position` and `Cursor.remaining` return the cursor beside the count.
`Cursor.seek` and `Cursor.skip` return a success flag. Position may equal the
region end. Neither operation copies bytes. `Cursor.finish` returns the
backing `Bytes` and final position.

## Bounded regions

`Cursor.region(cursor, length)` returns `(cursor, Maybe(CursorLimit))`.
On success the cursor's start and end bound exactly `length` bytes from its
current position. Reads, writes, and seeks cannot cross either boundary.
On failure the cursor is unchanged. Zero-length regions are valid.

After parsing, `Cursor.leave(cursor, limit)` restores the parent bounds and
resumes after the whole region, including any unread bytes. A limit is affine.
Keep it with its owning cursor and leave nested regions in reverse order. Do not
forge a limit or pair it with another cursor. No region operation slices or
copies the input. The public constructors follow Bend's existing `Bytes`
convention: callers must preserve the packed layout and region invariants.

Run `scripts/check.sh bytes` for concrete laws and native-array checks.
