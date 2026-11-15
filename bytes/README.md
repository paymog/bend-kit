# bytes

Packed byte buffers with affine ownership. Four octets occupy each U32 array word.

```bend
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def show(r: Bytes.Bytes & U32) -> IO(Unit):
  (b, n) = r
  IO.print(U32.show(n) ++ " " ++ Bytes.to_string(b))

def main() -> IO(Unit):
  show(Bytes.length(Bytes.from_string("hi")))
```

`get` returns the buffer beside `None` when the index is at or past `len`. `set` then leaves the buffer unchanged. `from_hex` returns `None` for an odd length or a non-hex character. This package imports `0x4eed9d7ac6ece61523d747a9d804e4f0/int.bend`, identified in the code as `bend-kit-int@0.2.0.0`. U64 reads use its `U64` type.

| def | returns |
|---|---|
| `to_hex(b: Bytes) -> String` | Lowercase hexadecimal text. The call consumes the buffer. |
| `clone(b: Bytes) -> Bytes & Bytes` | Two buffers with the same bytes. |
| `u32.read(b: Bytes) -> Maybe<&2, U32>` | The value of ASCII decimal digits. `None` for an empty buffer, a non-digit, or a value above 4294967295. The call consumes the buffer. |
| `u32.show(n: U32) -> Bytes` | `n` as ASCII decimal digits, with no leading zeros. |


## Positional reads and writes

Import `bend-kit-bytes@0.3.3.0/bytes.bend`. `Cursor.new(bytes)` owns the
existing buffer at position zero. `Cursor.u8`, `Cursor.u16be`, `Cursor.u16le`,
`Cursor.u32be`, `Cursor.u32le`, `Cursor.u64be`, and `Cursor.u64le` return `(cursor, Maybe(value))`.
`None` means incomplete bytes, not an invalid protocol value. A failed read
keeps both position and contents unchanged.

`Cursor.put.u8`, `Cursor.put.u16be`, `Cursor.put.u16le`, `Cursor.put.u32be`,
`Cursor.put.u32le`, `Cursor.put.u64be`, and `Cursor.put.u64le` return `(cursor, Bool)`. Writes mutate the existing
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
