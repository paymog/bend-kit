# bytes

Packed byte buffers with affine ownership. Four octets occupy each U32 array word.

```bend
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def show(r: Bytes.Bytes & U32) -> IO(Unit):
  (b, n) = r
  IO.print(U32.show(n) ++ " " ++ Bytes.to_string(b))

def main() -> IO(Unit):
  show(Bytes.length(Bytes.from_string("hi")))
```

`get` returns the buffer beside `None` when the index is at or past `len`. `set` then leaves the buffer unchanged. `from_hex` returns `None` for an odd length or a non-hex character. This package imports `bend-kit-int@0.2.0.0/int.bend` by name. U64 reads use its `U64` type.

| def | returns |
|---|---|
| `to_hex(b: Bytes) -> String` | Lowercase hexadecimal text. The call consumes the buffer. |
| `clone(b: Bytes) -> Bytes & Bytes` | Two buffers with the same bytes. |
| `u32.read(b: Bytes) -> Maybe<&2, U32>` | The value of ASCII decimal digits. `None` for an empty buffer, a non-digit, or a value above 4294967295. The call consumes the buffer. |
| `u32.show(n: U32) -> Bytes` | `n` as ASCII decimal digits, with no leading zeros. |

`u32_roundtrip_all` proves that reading `u32.show(n)` gives every U32 `n` back. The law projects the result through `U32.to_nat`. The proof covers packed byte writes, reads, decimal arithmetic, and the digit count. It does not change the runtime codec.

Import `bend-kit-bytes@0.3.3.3/roundtrip-proof.bend` to reuse `raw(n)`, which proves `u32.read(u32.show(n)) == Some{n}` directly. The runtime entry does not import the proof modules.

### Independent decimal proof check

Use Bend 2.0.40, pinned by `scripts/install-bend.sh`, and Lean 4.34.0.
Install [elan](https://github.com/leanprover/elan) and put its `bin` directory
on `PATH`. From the repository root, run:

```sh
elan toolchain install leanprover/lean4:v4.34.0 && \
  lean +leanprover/lean4:v4.34.0 --version && \
  ELAN_TOOLCHAIN=leanprover/lean4:v4.34.0 bend bytes/array-proof.bend --verdict && \
  ELAN_TOOLCHAIN=leanprover/lean4:v4.34.0 bend bytes/roundtrip-proof.bend --verdict && \
  ELAN_TOOLCHAIN=leanprover/lean4:v4.34.0 bend lemmas/lemmas.bend --verdict
```

Run one Bend process at a time. Start with the smaller array proof above.
Stop any proof process that exceeds 20 GB RSS.

All three commands printed `ALL PROOFS CHECK` with exit status zero on
macOS arm64, using Bend 2.0.40 and Lean 4.34.0. With `--verdict`, that result
requires both Bend's checker and the independent BendTT kernel to pass.
The round-trip check includes its imported decimal, array, packed, ASCII,
codec, and shared arithmetic proofs. The separate lemmas command checks the
shared library entry too. The runtime codec and proof claims are unchanged.

CI repeats these three checks in the `bytes-kernel` job when Bend files in
`bytes/` or `lemmas/` change. Changes to its workflow, installer, RSS guard,
or regression check also select the job. CI pins and caches Lean 4.34.0 and
the BendTT kernel. Each check must exit zero and print `ALL PROOFS CHECK`.
The job fails on a proof error, a process-tree RSS above 20 GiB, or its
30-minute timeout. The merge gate requires this job when selected.


## Positional reads and writes

Import `bend-kit-bytes@0.3.3.3/bytes.bend`. `Cursor.new(bytes)` owns the
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

Run `scripts/check.sh bytes` for the universal decimal round-trip law, concrete laws, and native-array checks.
