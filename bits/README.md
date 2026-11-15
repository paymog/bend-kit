# bits

Bit readers and writers over `Bytes`, in either bit order, and canonical Huffman decode tables. DEFLATE (RFC 1951) and GIF send fields LSB-first. JPEG and MP3 send them MSB-first.

```bend
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-bits@0.1.0.1/bits.bend as Bits

# BFINAL, the first bit of a DEFLATE block header.
def head(r: Bits.Reader & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (rd, final) = r
  final

def main() -> Maybe<&2, U32>:
  head(Bits.Reader.lsb(Bits.Reader.new(Bytes.from_string("\u{3}")), 1))
```

`bits.bend` imports `bend-kit-bytes@0.3.3.0`. A `Reader` and a `Writer` own their buffer. Each call returns the handle beside its result, so pass it on.

## Reader

| def | does |
|---|---|
| `Reader.new(b)` | Starts at bit 0 of `b`. |
| `Reader.lsb(r, n)`, `Reader.msb(r, n)` | The next `n` bits (0 to 32) as a number. `None`, with the reader unchanged, when `n > 32` or fewer than `n` bits are left. |
| `Reader.peek.lsb(r, n)`, `Reader.peek.msb(r, n)` | The next `n` bits (cut to 32) without moving. Bits past the end read as 0. |
| `Reader.skip(r, n)` | Moves `n` bits on. `False`, with the reader unchanged, when fewer are left. |
| `Reader.align(r)` | Moves to the next byte boundary. |
| `Reader.left(r)` | The bits left. |
| `Reader.finish(r)` | The buffer back, and the bit position. |

LSB-first, the first bit of a field is its least significant. MSB-first, it is its most significant. JPEG byte stuffing (`0xFF 0x00`) is the caller's job: remove it before the reader sees the bytes.

## Writer

`Writer.new()`, then `Writer.lsb(w, n, v)` or `Writer.msb(w, n, v)` appends the low `n` bits of `v`. `n` is cut to 32. `Writer.align(w)` pads with 0 bits to a byte boundary. `Writer.finish(w)` returns the `Bytes`, with 0 bits in the rest of the last byte. JPEG pads with 1 bits, so write them before `finish`. The buffer doubles when it fills, so writing is O(total).

## Huffman

`Huff.from_lens(msb, lens)` builds a table where symbol `i` has code length `lens[i]`, as DEFLATE sends them. `Huff.from_codes(msb, codes)` takes `Code{sym, len}` values. Codes go shortest first, ties in list order, so JPEG's BITS and HUFFVAL map to it directly. Length 0 means no code. `msb` is the stream's bit order.

Both return `None` when a length exceeds 16 or the lengths over-subscribe the code space. An incomplete set is allowed. `Huff.decode(h, r)` reads one symbol and returns `(h, r, Some{sym})`. It returns `None`, with the reader unchanged, when the next bits start no code or the input ends inside one.

A DEFLATE code goes most significant bit first even in its LSB-first stream. `Huff.from_lens(False{}, lens)` handles that. To write such a code, reverse its bits, then call `Writer.lsb`.

## Limits

- Positions are U32 bit counts, so a stream holds under 512 MiB.
- The table has one level of `2^max` entries, where `max` is the longest code. A 15-bit DEFLATE code builds 32768 entries.
- Symbols must be below 2^27.

## Checks

`LAWS.bend` round-trips fields of widths 0 to 32 in both orders, fixes the bit layout of each order, and decodes the fixed DEFLATE literal/length code (RFC 1951 §3.2.6) for all 288 symbols. `check.bend` round-trips 20,000 random fields per order on the native `Array`. `bench/` times decode against zlib and `bitstream-io`.
