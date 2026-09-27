import Base
import ./bytes.bend as Bytes
import 0x4eed9d7ac6ece61523d747a9d804e4f0/int.bend as Int

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

def of(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def str(b: Bytes.Bytes) -> String:
  Bytes.to_string(b)

def val(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (b, x) = r
  x

def val64(r: Bytes.Bytes & Maybe<&2, Int.U64>) -> Maybe<&2, Int.U64>:
  (b, x) = r
  x

def w64(+hi: U32, +lo: U32) -> Int.U64:
  Int.U64.or(Int.U64.shl(Int.U64.from_u32(hi), 32n), Int.U64.from_u32(lo))

def num(r: Bytes.Bytes & U32) -> U32:
  (b, n) = r
  n

def left(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(a)

def right(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(b)

def rightb(r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes:
  (a, b) = r
  b

def same(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, ok) = r
  ok

# Round trips, inside one word, across words, and at every octet boundary.
law roundtrip_empty:
  {str(of("")) == "" : String}

law roundtrip_word:
  {str(of("abcd")) == "abcd" : String}

law roundtrip_words:
  {str(of("hello, world")) == "hello, world" : String}

law roundtrip_octets:
  {str(of(bytes([0, 128, 255, 13, 10]))) == bytes([0, 128, 255, 13, 10]) : String}

# A Char above 255 keeps its low 8 bits.
law from_masks:
  {str(of(bytes([321]))) == "A" : String}

law new_zeros:
  {str(Bytes.new(5)) == bytes([0, 0, 0, 0, 0]) : String}

law length_of:
  {num(Bytes.length(of("hello"))) == 5 : U32}

law get_first:
  {val(Bytes.get(of("hello"), 0)) == Some{104} : Maybe<&2, U32>}

law get_second_word:
  {val(Bytes.get(of("hello"), 4)) == Some{111} : Maybe<&2, U32>}

# The word has room for 4 bytes, but index 2 is past len.
law get_past_len:
  {val(Bytes.get(of("hi"), 2)) == None{} : Maybe<&2, U32>}

law set_middle:
  {str(Bytes.set(of("abc"), 1, 120)) == "axc" : String}

law set_second_word:
  {str(Bytes.set(of("hello"), 4, 33)) == "hell!" : String}

law set_masks:
  {str(Bytes.set(of("abc"), 0, 376)) == "xbc" : String}

law set_past_len:
  {str(Bytes.set(of("abc"), 3, 120)) == "abc" : String}

law slice_middle:
  {right(Bytes.slice(of("hello"), 1, 3)) == "ell" : String}

law slice_keeps_source:
  {left(Bytes.slice(of("hello"), 1, 3)) == "hello" : String}

law slice_clamps_count:
  {right(Bytes.slice(of("hello"), 3, 10)) == "lo" : String}

law slice_clamps_start:
  {right(Bytes.slice(of("hello"), 9, 2)) == "" : String}

law append_two:
  {str(Bytes.append(of("ab"), of("cde"))) == "abcde" : String}

law append_empty:
  {str(Bytes.append(of(""), of("xyz"))) == "xyz" : String}

# RFC 9112 §2.1: the header section ends at the first empty line.
law find_header_end:
  {val(Bytes.find(of("GET / HTTP/1.1\r\n\r\nbody"), "\r\n\r\n")) == Some{14} : Maybe<&2, U32>}

law find_across_words:
  {val(Bytes.find(of("abc\r\n\r\nx"), "\r\n\r\n")) == Some{3} : Maybe<&2, U32>}

law find_first_of_two:
  {val(Bytes.find(of("xabab"), "ab")) == Some{1} : Maybe<&2, U32>}

law find_at_end:
  {val(Bytes.find(of("xyzab"), "ab")) == Some{3} : Maybe<&2, U32>}

law find_missing:
  {val(Bytes.find(of("hello"), "lx")) == None{} : Maybe<&2, U32>}

law find_needle_too_long:
  {val(Bytes.find(of("ab"), "abc")) == None{} : Maybe<&2, U32>}

law find_empty_needle:
  {val(Bytes.find(of("ab"), "")) == Some{0} : Maybe<&2, U32>}

law eq_same:
  {same(Bytes.eq(of("hello"), of("hello"))) == True{} : Bool}

law eq_last_byte:
  {same(Bytes.eq(of("hello"), of("hellp"))) == False{} : Bool}

law eq_length:
  {same(Bytes.eq(of("hell"), of("hello"))) == False{} : Bool}

law eq_empty:
  {same(Bytes.eq(of(""), of(""))) == True{} : Bool}

# A buffer that was written to equals a fresh one with the same bytes.
law eq_after_set:
  {same(Bytes.eq(Bytes.set(of("abc"), 1, 98), of("abc"))) == True{} : Bool}

law eq_after_append:
  {same(Bytes.eq(Bytes.append(of("ab"), of("cde")), of("abcde"))) == True{} : Bool}

# A partial last word at each length.
law roundtrip_one:
  {str(of("a")) == "a" : String}

law roundtrip_three:
  {str(of("abc")) == "abc" : String}

law roundtrip_seven:
  {str(of("abcdefg")) == "abcdefg" : String}

# slice copies whole words, shifted when the start is not word-aligned, then the tail bytes.
law slice_offset_1:
  {right(Bytes.slice(of("abcdefghijkl"), 1, 9)) == "bcdefghij" : String}

law slice_offset_2:
  {right(Bytes.slice(of("abcdefghijkl"), 2, 8)) == "cdefghij" : String}

law slice_offset_3:
  {right(Bytes.slice(of("abcdefghijkl"), 3, 7)) == "defghij" : String}

law slice_aligned:
  {right(Bytes.slice(of("abcdefghijkl"), 4, 6)) == "efghij" : String}

law slice_to_end:
  {right(Bytes.slice(of("abcdefghijkl"), 5, 100)) == "fghijkl" : String}

law slice_octets:
  {right(Bytes.slice(of(bytes([1, 255, 0, 128, 13, 10, 200])), 1, 5)) == bytes([255, 0, 128, 13, 10]) : String}

law append_aligned:
  {str(Bytes.append(of("abcd"), of("efghij"))) == "abcdefghij" : String}

law append_unaligned:
  {str(Bytes.append(of("abcde"), of("fghij"))) == "abcdefghij" : String}

# Word copies leave the bytes past len at 0, so eq still compares whole words.
law eq_after_slice:
  {same(Bytes.eq(rightb(Bytes.slice(of("xhello, world"), 1, 12)), of("hello, world"))) == True{} : Bool}

law eq_after_aligned_append:
  {same(Bytes.eq(Bytes.append(of("abcd"), of("efg")), of("abcdefg"))) == True{} : Bool}

# Pieces join in order, across word boundaries, and an empty piece adds nothing.
law concat_pieces:
  {str(Bytes.concat([of("ab"), of(""), of("cdefg"), of("h")])) == "abcdefgh" : String}

law concat_none:
  {str(Bytes.concat([])) == "" : String}

# append writes into the left buffer while it has room and copies when it grows.
law append_in_room:
  {str(Bytes.append(Bytes.append(of("ab"), of("c")), of("d"))) == "abcd" : String}

law append_grows:
  {str(Bytes.append(Bytes.append(Bytes.append(of("abc"), of("de")), of("fghi")), of("j"))) == "abcdefghij" : String}

law eq_after_appends:
  {same(Bytes.eq(Bytes.append(Bytes.append(of("a"), of("bc")), of("defgh")), of("abcdefgh"))) == True{} : Bool}

# Integers in both byte orders, inside a word, across words, and past len.
law u16be_at:
  {val(Bytes.get.u16be(of(bytes([1, 2, 3])), 1)) == Some{515} : Maybe<&2, U32>}

law u16le_at:
  {val(Bytes.get.u16le(of(bytes([1, 2, 3])), 1)) == Some{770} : Maybe<&2, U32>}

law u32be_across_words:
  {val(Bytes.get.u32be(of(bytes([0, 1, 2, 3, 4, 5])), 1)) == Some{16909060} : Maybe<&2, U32>}

law u32le_across_words:
  {val(Bytes.get.u32le(of(bytes([0, 1, 2, 3, 4, 5])), 1)) == Some{67305985} : Maybe<&2, U32>}

law u32be_top:
  {val(Bytes.get.u32be(of(bytes([255, 255, 255, 255])), 0)) == Some{4294967295} : Maybe<&2, U32>}

law u32_past_len:
  {val(Bytes.get.u32le(of("abc"), 0)) == None{} : Maybe<&2, U32>}

law u16_past_len:
  {val(Bytes.get.u16be(of("abc"), 2)) == None{} : Maybe<&2, U32>}

law set_u16be_at:
  {str(Bytes.set.u16be(of("xxxx"), 1, 258)) == bytes([120, 1, 2, 120]) : String}

law set_u16le_masks:
  {str(Bytes.set.u16le(of("ab"), 0, 65601)) == bytes([65, 0]) : String}

law set_u32be_across_words:
  {str(Bytes.set.u32be(Bytes.new(6), 2, 16909060)) == bytes([0, 0, 1, 2, 3, 4]) : String}

law set_u32le_across_words:
  {str(Bytes.set.u32le(Bytes.new(6), 1, 16909060)) == bytes([0, 4, 3, 2, 1, 0]) : String}

law set_u16_past_len:
  {str(Bytes.set.u16le(of("abc"), 2, 0)) == "abc" : String}

law u16be_roundtrip:
  {val(Bytes.get.u16be(Bytes.set.u16be(Bytes.new(7), 3, 48879), 3)) == Some{48879} : Maybe<&2, U32>}

law u16le_roundtrip:
  {val(Bytes.get.u16le(Bytes.set.u16le(Bytes.new(7), 3, 48879), 3)) == Some{48879} : Maybe<&2, U32>}

law u32be_roundtrip:
  {val(Bytes.get.u32be(Bytes.set.u32be(Bytes.new(7), 3, 3735928559), 3)) == Some{3735928559} : Maybe<&2, U32>}

law u32le_roundtrip:
  {val(Bytes.get.u32le(Bytes.set.u32le(Bytes.new(7), 3, 3735928559), 3)) == Some{3735928559} : Maybe<&2, U32>}

# 0x0102030405060708 and 0xDEADBEEFCAFEBABE, as high and low words.
law u64be_across_words:
  {val64(Bytes.get.u64be(of(bytes([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])), 1)) == Some{w64(16909060, 84281096)} : Maybe<&2, Int.U64>}

law u64le_across_words:
  {val64(Bytes.get.u64le(of(bytes([0, 8, 7, 6, 5, 4, 3, 2, 1, 9])), 1)) == Some{w64(16909060, 84281096)} : Maybe<&2, Int.U64>}

law u64be_top:
  {val64(Bytes.get.u64be(of(bytes([255, 255, 255, 255, 255, 255, 255, 255])), 0)) == Some{Int.U64.MAX()} : Maybe<&2, Int.U64>}

law u64_past_len:
  {val64(Bytes.get.u64le(of("abcdefg"), 0)) == None{} : Maybe<&2, Int.U64>}

law u64_half_past_len:
  {val64(Bytes.get.u64be(of("abcdefghi"), 2)) == None{} : Maybe<&2, Int.U64>}

law set_u64be_across_words:
  {str(Bytes.set.u64be(Bytes.new(10), 1, w64(16909060, 84281096))) == bytes([0, 1, 2, 3, 4, 5, 6, 7, 8, 0]) : String}

law set_u64le_across_words:
  {str(Bytes.set.u64le(Bytes.new(10), 1, w64(16909060, 84281096))) == bytes([0, 8, 7, 6, 5, 4, 3, 2, 1, 0]) : String}

law set_u64_half_past_len:
  {str(Bytes.set.u64be(of("abcdefghi"), 2, Int.U64.MAX())) == "abcdefghi" : String}

law u64be_roundtrip:
  {val64(Bytes.get.u64be(Bytes.set.u64be(Bytes.new(12), 3, w64(3735928559, 3405691582)), 3)) == Some{w64(3735928559, 3405691582)} : Maybe<&2, Int.U64>}

law u64le_roundtrip:
  {val64(Bytes.get.u64le(Bytes.set.u64le(Bytes.new(12), 3, w64(3735928559, 3405691582)), 3)) == Some{w64(3735928559, 3405691582)} : Maybe<&2, Int.U64>}

law find_from_later:
  {val(Bytes.find.from(of("abcabc"), "bc", 2)) == Some{4} : Maybe<&2, U32>}

law find_from_at_start:
  {val(Bytes.find.from(of("abcabc"), "bc", 1)) == Some{1} : Maybe<&2, U32>}

law find_from_too_late:
  {val(Bytes.find.from(of("abcabc"), "bc", 5)) == None{} : Maybe<&2, U32>}

law find_from_empty_at_len:
  {val(Bytes.find.from(of("ab"), "", 2)) == Some{2} : Maybe<&2, U32>}

law find_from_past_len:
  {val(Bytes.find.from(of("ab"), "", 3)) == None{} : Maybe<&2, U32>}

law rfind_last:
  {val(Bytes.rfind(of("abcabc"), "bc")) == Some{4} : Maybe<&2, U32>}

law rfind_at_end:
  {val(Bytes.rfind(of("abcabc"), "abc")) == Some{3} : Maybe<&2, U32>}

law rfind_at_zero:
  {val(Bytes.rfind(of("abcx"), "ab")) == Some{0} : Maybe<&2, U32>}

law rfind_missing:
  {val(Bytes.rfind(of("hello"), "lx")) == None{} : Maybe<&2, U32>}

law rfind_too_long:
  {val(Bytes.rfind(of("ab"), "abc")) == None{} : Maybe<&2, U32>}

law rfind_empty:
  {val(Bytes.rfind(of("ab"), "")) == Some{2} : Maybe<&2, U32>}

def yes(r: Bytes.Bytes & Bool) -> Bool:
  (b, ok) = r
  ok

law starts_with_method:
  {yes(Bytes.starts_with(of("GET / HTTP/1.1"), "GET ")) == True{} : Bool}

law starts_with_other:
  {yes(Bytes.starts_with(of("GET / HTTP/1.1"), "GEX")) == False{} : Bool}

law starts_with_too_long:
  {yes(Bytes.starts_with(of("GE"), "GET")) == False{} : Bool}

law starts_with_empty:
  {yes(Bytes.starts_with(of(""), "")) == True{} : Bool}

law ends_with_crlf:
  {yes(Bytes.ends_with(of("abcde\r\n"), "\r\n")) == True{} : Bool}

law ends_with_other:
  {yes(Bytes.ends_with(of("abcde\r\n"), "e\n")) == False{} : Bool}

law ends_with_too_long:
  {yes(Bytes.ends_with(of("ab"), "xab")) == False{} : Bool}

def strs(xs: List<&1, Bytes.Bytes>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      Con{str(x), strs(t)}

law split_fields:
  {strs(Bytes.split(of("a,b,,c"), ",")) == ["a", "b", "", "c"] : List<&2, String>}

law split_ends:
  {strs(Bytes.split(of(",a,"), ",")) == ["", "a", ""] : List<&2, String>}

# Matches do not overlap: the second "aa" in "aaa" starts inside the first.
law split_no_overlap:
  {strs(Bytes.split(of("aaa"), "aa")) == ["", "a"] : List<&2, String>}

law split_lines:
  {strs(Bytes.split(of("k: v\r\nx: y"), "\r\n")) == ["k: v", "x: y"] : List<&2, String>}

law split_empty_sep:
  {strs(Bytes.split(of("abc"), "")) == ["abc"] : List<&2, String>}

law split_empty:
  {strs(Bytes.split(of(""), ",")) == [""] : List<&2, String>}

law split_sep_too_long:
  {strs(Bytes.split(of("ab"), "abc")) == ["ab"] : List<&2, String>}

def order(r: Bytes.Bytes & Bytes.Bytes & Cmp) -> Cmp:
  (a, b, c) = r
  c

# Byte order, not word order: the first byte decides, and bytes are unsigned.
law cmp_first_byte:
  {order(Bytes.cmp(of("ba"), of("ab"))) == GT{} : Cmp}

law cmp_last_byte:
  {order(Bytes.cmp(of("abc"), of("abd"))) == LT{} : Cmp}

law cmp_second_word:
  {order(Bytes.cmp(of("abcde"), of("abcdf"))) == LT{} : Cmp}

law cmp_unsigned:
  {order(Bytes.cmp(of(bytes([255])), of(bytes([1])))) == GT{} : Cmp}

law cmp_prefix:
  {order(Bytes.cmp(of("ab"), of("abc"))) == LT{} : Cmp}

# A 0 byte past the shorter one's end still makes the longer one greater.
law cmp_zero_tail:
  {order(Bytes.cmp(of(bytes([97, 98, 0])), of("ab"))) == GT{} : Cmp}

law cmp_equal:
  {order(Bytes.cmp(of("hello"), of("hello"))) == EQ{} : Cmp}

def dec(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Some{str(b)}

law to_hex_octets:
  {Bytes.to_hex(of(bytes([0, 15, 16, 171, 255]))) == "000f10abff" : String}

law to_hex_empty:
  {Bytes.to_hex(of("")) == "" : String}

law from_hex_either_case:
  {dec(Bytes.from_hex("000F10abff")) == Some{bytes([0, 15, 16, 171, 255])} : Maybe<&2, String>}

law from_hex_odd:
  {dec(Bytes.from_hex("abc")) == None{} : Maybe<&2, String>}

law from_hex_bad_char:
  {dec(Bytes.from_hex("0g")) == None{} : Maybe<&2, String>}

law from_hex_empty:
  {dec(Bytes.from_hex("")) == Some{""} : Maybe<&2, String>}

# RFC 4648 §10 test vectors.
law base64_empty:
  {Bytes.to_base64(of("")) == "" : String}

law base64_f:
  {Bytes.to_base64(of("f")) == "Zg==" : String}

law base64_fo:
  {Bytes.to_base64(of("fo")) == "Zm8=" : String}

law base64_foo:
  {Bytes.to_base64(of("foo")) == "Zm9v" : String}

law base64_foob:
  {Bytes.to_base64(of("foob")) == "Zm9vYg==" : String}

law base64_fooba:
  {Bytes.to_base64(of("fooba")) == "Zm9vYmE=" : String}

law base64_foobar:
  {Bytes.to_base64(of("foobar")) == "Zm9vYmFy" : String}

law base64_high_octets:
  {Bytes.to_base64(of(bytes([251, 255]))) == "+/8=" : String}

law from_base64_f:
  {dec(Bytes.from_base64("Zg==")) == Some{"f"} : Maybe<&2, String>}

law from_base64_fo:
  {dec(Bytes.from_base64("Zm8=")) == Some{"fo"} : Maybe<&2, String>}

law from_base64_foobar:
  {dec(Bytes.from_base64("Zm9vYmFy")) == Some{"foobar"} : Maybe<&2, String>}

law from_base64_fooba:
  {dec(Bytes.from_base64("Zm9vYmE=")) == Some{"fooba"} : Maybe<&2, String>}

law from_base64_high_octets:
  {dec(Bytes.from_base64("+/8=")) == Some{bytes([251, 255])} : Maybe<&2, String>}

law from_base64_empty:
  {dec(Bytes.from_base64("")) == Some{""} : Maybe<&2, String>}

law from_base64_length:
  {dec(Bytes.from_base64("Zg=")) == None{} : Maybe<&2, String>}

law from_base64_inner_pad:
  {dec(Bytes.from_base64("Zg=a")) == None{} : Maybe<&2, String>}

law from_base64_three_pads:
  {dec(Bytes.from_base64("Z===")) == None{} : Maybe<&2, String>}

law from_base64_bad_char:
  {dec(Bytes.from_base64("Zm9*")) == None{} : Maybe<&2, String>}

# The last group writes only the bytes before len: 4 bytes fill one word, so a fifth would wrap onto byte 0.
law from_base64_foob:
  {dec(Bytes.from_base64("Zm9vYg==")) == Some{"foob"} : Maybe<&2, String>}

def same.dec(m: Maybe<&1, Bytes.Bytes>, +s: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{b}:
      same(Bytes.eq(b, of(s)))

# Pad bits that are not 0 are dropped (RFC 4648 §3.5 lets a decoder accept them), and stay out of the buffer.
law from_base64_pad_bits:
  {same.dec(Bytes.from_base64("Zh=="), "f") == True{} : Bool}
