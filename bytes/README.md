# bytes

Packed byte buffers with affine ownership. Four octets occupy each U32 array word.

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
