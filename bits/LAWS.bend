import Base
import ./bits.bend as Bits
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

type F is Data:
  F{n: U32, v: U32}

def put(msb: Bool, w: Bits.Writer, +n: U32, +v: U32) -> Bits.Writer:
  match msb:
    case True{}:
      Bits.Writer.msb(w, n, v)
    case False{}:
      Bits.Writer.lsb(w, n, v)

def puts(fs: List<&2, F>, +msb: Bool, w: Bits.Writer) -> Bits.Writer:
  match fs:
    case Nil{}:
      w
    case Con{F{+n, +v}, t}:
      puts(t, msb, put(msb, w, n, v))

def written(+msb: Bool, +fs: List<&2, F>) -> Bytes.Bytes:
  Bits.Writer.finish(puts(fs, msb, Bits.Writer.new()))

def octets(+msb: Bool, +fs: List<&2, F>) -> String:
  Bytes.to_string(written(msb, fs))

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

def reader(+xs: List<&2, U32>) -> Bits.Reader:
  Bits.Reader.new(Bytes.from_string(bytes(xs)))

def get.at(msb: Bool, r: Bits.Reader, +n: U32) -> Bits.Reader & Maybe<&2, U32>:
  match msb:
    case True{}:
      Bits.Reader.msb(r, n)
    case False{}:
      Bits.Reader.lsb(r, n)

def push(acc: List<&2, Maybe<&2, U32>>, r: Bits.Reader & Maybe<&2, U32>) -> Bits.Reader & List<&2, Maybe<&2, U32>>:
  (rd, x) = r
  (rd, Con{x, acc})

def get.step(+msb: Bool, +n: U32, st: Bits.Reader & List<&2, Maybe<&2, U32>>) -> Bits.Reader & List<&2, Maybe<&2, U32>>:
  (rd, acc) = st
  push(acc, get.at(msb, rd, n))

def gets.go(ns: List<&2, U32>, +msb: Bool, st: Bits.Reader & List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match ns:
    case Nil{}:
      (rd, acc) = st
      List.reverse(&2, Maybe<&2, U32>, acc)
    case Con{+n, t}:
      gets.go(t, msb, get.step(msb, n, st))

# The fields of widths ns, read in turn.
def gets(+ns: List<&2, U32>, +msb: Bool, r: Bits.Reader) -> List<&2, Maybe<&2, U32>>:
  gets.go(ns, msb, (r, Nil{}))

def widths(fs: List<&2, F>) -> List<&2, U32>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{F{n, v}, t}:
      Con{n, widths(t)}

def values(fs: List<&2, F>) -> List<&2, Maybe<&2, U32>>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{F{n, v}, t}:
      Con{Some{v}, values(t)}

def roundtrip(+msb: Bool, +fs: List<&2, F>) -> List<&2, Maybe<&2, U32>>:
  gets(widths(fs), msb, Bits.Reader.new(written(msb, fs)))

# Widths 0 to 32, inside a byte, across bytes, and across words.
def mixed() -> List<&2, F>:
  [F{3, 5}, F{13, 6844}, F{32, 3735928559}, F{1, 1}, F{0, 0}, F{7, 85}, F{17, 70000}, F{32, 1}, F{9, 300}]

law lsb_roundtrip:
  {roundtrip(False{}, mixed()) == values(mixed()) : List<&2, Maybe<&2, U32>>}

law msb_roundtrip:
  {roundtrip(True{}, mixed()) == values(mixed()) : List<&2, Maybe<&2, U32>>}

# RFC 1951 §3.2.3: BFINAL = 1 then BTYPE = 01 fill the low three bits of the first byte.
law lsb_first_bit_lowest:
  {octets(False{}, [F{1, 1}, F{2, 1}]) == bytes([3]) : String}

law msb_first_bit_highest:
  {octets(True{}, [F{3, 5}, F{5, 1}]) == bytes([161]) : String}

# A field's bits above n are dropped, and the last byte is padded with 0 bits.
law write_masks_and_pads:
  {octets(False{}, [F{4, 255}, F{8, 0}]) == bytes([15, 0]) : String}

law msb_write_masks_and_pads:
  {octets(True{}, [F{4, 255}, F{8, 0}]) == bytes([240, 0]) : String}

# finish keeps the fewest 2^d words that hold the bytes, as Bytes.from_string does.
law finish_is_canonical:
  {written(False{}, [F{32, 67305985}, F{8, 5}]) == Bytes.from_string(bytes([1, 2, 3, 4, 5])) : Bytes.Bytes}

law lsb_read_known:
  {gets([3, 5], False{}, reader([161])) == [Some{1}, Some{20}] : List<&2, Maybe<&2, U32>>}

law msb_read_known:
  {gets([3, 5], True{}, reader([161])) == [Some{5}, Some{1}] : List<&2, Maybe<&2, U32>>}

# A read past the end answers None and leaves the reader where it was.
law read_past_end:
  {gets([17, 8, 1], False{}, reader([171, 205])) == [None{}, Some{171}, Some{1}] : List<&2, Maybe<&2, U32>>}

law read_over_32:
  {gets([33, 4], False{}, reader([1, 2, 3, 4, 5])) == [None{}, Some{1}] : List<&2, Maybe<&2, U32>>}

def peeked(r: Bits.Reader & U32) -> U32:
  (rd, v) = r
  v

# Bits past the end read as 0.
law lsb_peek_past_end:
  {peeked(Bits.Reader.peek.lsb(reader([255]), 12)) == 255 : U32}

law msb_peek_past_end:
  {peeked(Bits.Reader.peek.msb(reader([255]), 12)) == 4080 : U32}

def after.skip(r: Bits.Reader & Bool) -> List<&2, Maybe<&2, U32>>:
  (rd, ok) = r
  gets([8], False{}, rd)

law skip_then_read:
  {after.skip(Bits.Reader.skip(reader([1, 2, 3]), 8)) == [Some{2}] : List<&2, Maybe<&2, U32>>}

law skip_past_end:
  {after.skip(Bits.Reader.skip(reader([1, 2]), 17)) == [Some{1}] : List<&2, Maybe<&2, U32>>}

def after.align(r: Bits.Reader & Maybe<&2, U32>) -> List<&2, Maybe<&2, U32>>:
  (rd, x) = r
  gets([8], False{}, Bits.Reader.align(rd))

law align_to_byte:
  {after.align(Bits.Reader.lsb(reader([1, 2]), 3)) == [Some{2}] : List<&2, Maybe<&2, U32>>}

# Huffman: lengths [2, 1, 3, 3] give the canonical codes 10, 0, 110, 111 (RFC 1951 §3.2.2).
def small() -> List<&2, U32>:
  [2, 1, 3, 3]

def huff(+msb: Bool, +lens: List<&2, U32>) -> Maybe<&1, Bits.Huff>:
  Bits.Huff.from_lens(msb, lens)

def dec.push(acc: List<&2, Maybe<&2, U32>>, r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> Bits.Huff & Bits.Reader & List<&2, Maybe<&2, U32>>:
  (h, rd, x) = r
  (h, rd, Con{x, acc})

def dec.step(st: Bits.Huff & Bits.Reader & List<&2, Maybe<&2, U32>>) -> Bits.Huff & Bits.Reader & List<&2, Maybe<&2, U32>>:
  (h, rd, acc) = st
  dec.push(acc, Bits.Huff.decode(h, rd))

# k symbols decoded in turn.
def dec.go(k: Nat, st: Bits.Huff & Bits.Reader & List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match k:
    case 0n:
      (h, rd, acc) = st
      List.reverse(&2, Maybe<&2, U32>, acc)
    case 1n+p:
      dec.go(p, dec.step(st))

def dec(k: Nat, m: Maybe<&1, Bits.Huff>, b: Bytes.Bytes) -> List<&2, Maybe<&2, U32>>:
  match m:
    case None{}:
      Nil{}
    case Some{h}:
      dec.go(k, (h, Bits.Reader.new(b), Nil{}))

def built(m: Maybe<&1, Bits.Huff>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{h}:
      True{}

# Symbols 0, 1, 2, 3, 1. MSB-first the codes go as they are; LSB-first (DEFLATE) a code
# still goes most significant bit first, so its bits are written reversed: 01, 0, 011, 111.
law huff_msb_decodes_its_codes:
  {dec(5n, huff(True{}, small()), written(True{}, [F{2, 2}, F{1, 0}, F{3, 6}, F{3, 7}, F{1, 0}])) == [Some{0}, Some{1}, Some{2}, Some{3}, Some{1}] : List<&2, Maybe<&2, U32>>}

law huff_lsb_decodes_its_codes:
  {dec(5n, huff(False{}, small()), written(False{}, [F{2, 1}, F{1, 0}, F{3, 3}, F{3, 7}, F{1, 0}])) == [Some{0}, Some{1}, Some{2}, Some{3}, Some{1}] : List<&2, Maybe<&2, U32>>}

# Codes from (symbol, length) pairs go in list order within a length, as JPEG's HUFFVAL does.
law huff_codes_in_list_order:
  {dec(3n, Bits.Huff.from_codes(True{}, [Bits.Code{66, 2}, Bits.Code{9, 1}, Bits.Code{7, 2}]), written(True{}, [F{2, 3}, F{1, 0}, F{2, 2}])) == [Some{7}, Some{9}, Some{66}] : List<&2, Maybe<&2, U32>>}

law huff_over_subscribed:
  {built(huff(False{}, [1, 1, 1])) == False{} : Bool}

law huff_too_long:
  {built(huff(False{}, [17, 1])) == False{} : Bool}

# One code, 0, leaves 1 unused: it decodes to None and does not move the reader.
law huff_incomplete:
  {dec(3n, huff(True{}, [1]), written(True{}, [F{2, 1}])) == [Some{0}, None{}, None{}] : List<&2, Maybe<&2, U32>>}

# Two bits are left, and they start a 3-bit code.
law huff_cut_short:
  {dec(3n, huff(True{}, small()), written(True{}, [F{8, 255}])) == [Some{3}, Some{3}, None{}] : List<&2, Maybe<&2, U32>>}

def rev(k: Nat, +v: U32, +acc: U32) -> U32:
  match k:
    case 0n:
      acc
    case 1n+p:
      rev(p, U32.shrn(v, 1n), ((acc << 1n) .|. (v .&. 1) : U32))

# RFC 1951 §3.2.6: the fixed literal/length code of symbol s, written for an LSB-first stream.
def fixed.code(+s: U32) -> F:
  +c = Bool.pick(U32, U32.is_lt(s, 144), (s + 48 : U32), Bool.pick(U32, U32.is_lt(s, 256), (s + 256 : U32), Bool.pick(U32, U32.is_lt(s, 280), (s - 256 : U32), (s - 88 : U32))))
  +n = Bool.pick(U32, U32.is_lt(s, 144), 8, Bool.pick(U32, U32.is_lt(s, 256), 9, Bool.pick(U32, U32.is_lt(s, 280), 7, 8)))
  F{n, rev(U32.to_nat(n), c, 0)}

def rep(k: Nat, +v: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+p:
      rep(p, v, Con{v, acc})

def fixed.lens() -> List<&2, U32>:
  rep(144n, 8, rep(112n, 9, rep(24n, 7, rep(8n, 8, Nil{}))))

def syms(k: Nat, +s: U32) -> List<&2, U32>:
  match k:
    case 0n:
      Nil{}
    case 1n+p:
      Con{s, syms(p, (s + 1 : U32))}

def fixed.stream(xs: List<&2, U32>) -> List<&2, F>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+s, t}:
      Con{fixed.code(s), fixed.stream(t)}

def somes(xs: List<&2, U32>) -> List<&2, Maybe<&2, U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{s, t}:
      Con{Some{s}, somes(t)}

# Every symbol of the fixed literal/length code, encoded by the RFC's formula, decodes back.
law huff_fixed_deflate_all:
  {dec(288n, huff(False{}, fixed.lens()), written(False{}, fixed.stream(syms(288n, 0)))) == somes(syms(288n, 0)) : List<&2, Maybe<&2, U32>>}
