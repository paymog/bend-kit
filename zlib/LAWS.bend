import Base
import ./zlib.bend as Z

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, bytes(t)}

# Every byte value once, 0 through 255: all four fixed literal code ranges.
def every(k: Nat, +i: U32) -> String:
  match k:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{Chr{i}, every(p, (i + 1 : U32))}

# RFC 1951 §3.2.4: a stored block is copied as is.
law inflate_stored:
  {Z.inflate(bytes([1, 12, 0, 243, 255, 104, 101, 108, 108, 111, 32, 115, 116, 111, 114, 101, 100])) == Some{"hello stored"} : Maybe<&2, String>}

# RFC 1951 §3.2.6: a fixed-Huffman block.
law inflate_fixed:
  {Z.inflate(bytes([203, 72, 205, 201, 201, 7, 0])) == Some{"hello"} : Maybe<&2, String>}

# RFC 1951 §3.2.7: a dynamic-Huffman block.
law inflate_dynamic:
  {Z.inflate(bytes([5, 193, 177, 13, 0, 64, 12, 2, 177, 85, 178, 90, 138, 147, 160, 249, 34, 176, 191, 222, 70, 161, 231, 17, 135, 27, 112, 226, 29, 24, 222, 2, 162, 212, 183, 31])) == Some{"ehsetri hereitseeissia ee enaeeehetetira"} : Maybe<&2, String>}

# A stream cut short is not a stream.
law inflate_truncated:
  {Z.inflate(bytes([203, 72, 205, 201, 201, 87, 40, 207, 47, 202, 73, 81, 200])) == None{} : Maybe<&2, String>}

# RFC 1951 §3.2.3: block type 3 is reserved.
law inflate_bad_type:
  {Z.inflate(bytes([7])) == None{} : Maybe<&2, String>}

# RFC 1952 §2.3: FNAME is skipped up to its zero byte.
law gunzip_fname:
  {Z.gunzip(bytes([31, 139, 8, 8, 0, 0, 0, 0, 2, 255, 97, 46, 116, 120, 116, 0, 203, 75, 204, 77, 77, 81, 72, 202, 79, 169, 204, 27, 210, 44, 0, 219, 138, 47, 170, 200, 0, 0, 0])) == Some{String.repeat("named body", 20n)} : Maybe<&2, String>}

# RFC 1952 §2.3: FEXTRA, FNAME, FCOMMENT and FHCRC together.
law gunzip_all_flags:
  {Z.gunzip(bytes([31, 139, 8, 30, 0, 0, 0, 0, 0, 255, 6, 0, 65, 66, 2, 0, 104, 105, 110, 46, 116, 120, 116, 0, 99, 111, 109, 109, 101, 110, 116, 0, 241, 55, 75, 203, 73, 76, 47, 86, 200, 207, 6, 0, 76, 161, 200, 174, 8, 0, 0, 0])) == Some{"flags ok"} : Maybe<&2, String>}

# RFC 1952 §2.3.1: a CRC-32 mismatch rejects the member.
law gunzip_bad_crc:
  {Z.gunzip(bytes([31, 139, 8, 0, 0, 0, 0, 0, 2, 255, 203, 72, 205, 201, 201, 87, 72, 175, 202, 44, 80, 40, 207, 47, 202, 73, 1, 0, 106, 125, 232, 183, 16, 0, 0, 0])) == None{} : Maybe<&2, String>}

# A member without its trailer is rejected.
law gunzip_truncated:
  {Z.gunzip(bytes([31, 139, 8, 0, 0, 0, 0, 0, 2, 255, 203, 72, 205, 201, 201, 87, 72, 175, 202, 44, 80, 40, 207, 47, 202, 73, 1, 0, 107, 125, 232])) == None{} : Maybe<&2, String>}

# RFC 1950: a zlib stream.
law unzlib_ok:
  {Z.unzlib(bytes([120, 156, 203, 72, 205, 201, 201, 87, 168, 202, 201, 76, 82, 40, 207, 47, 202, 73, 1, 0, 52, 90, 6, 46])) == Some{"hello zlib world"} : Maybe<&2, String>}

# RFC 1950 §2.2: an Adler-32 mismatch rejects the stream.
law unzlib_bad_adler:
  {Z.unzlib(bytes([120, 156, 203, 72, 205, 201, 201, 87, 168, 202, 201, 76, 82, 40, 207, 47, 202, 73, 1, 0, 52, 90, 6, 47])) == None{} : Maybe<&2, String>}

# CRC-32 of "hello", as zlib computes it.
law crc32_hello:
  {Z.crc32("hello") == 907060870 : U32}

# Adler-32 of "hello", as zlib computes it.
law adler32_hello:
  {Z.adler32("hello") == 103547413 : U32}

# RFC 1951 §3.2.5: length/distance pairs copy from earlier output, overlapping included.
law inflate_matches:
  {Z.inflate(bytes([43, 201, 72, 85, 40, 44, 205, 76, 206, 86, 72, 42, 202, 47, 207, 83, 72, 203, 175, 80, 200, 42, 205, 45, 40, 86, 200, 47, 75, 45, 82, 40, 1, 74, 231, 36, 86, 85, 42, 164, 228, 167, 235, 129, 121, 163, 138, 71, 21, 143, 42, 30, 85, 60, 170, 120, 84, 241, 48, 82, 12, 0])) == Some{String.repeat("the quick brown fox jumps over the lazy dog. ", 40n)} : Maybe<&2, String>}

law deflate_empty:
  {Z.inflate(Z.deflate("")) == Some{""} : Maybe<&2, String>}

law deflate_hello:
  {Z.inflate(Z.deflate("hello")) == Some{"hello"} : Maybe<&2, String>}

law deflate_every_byte:
  {Z.inflate(Z.deflate(every(256n, 0))) == Some{every(256n, 0)} : Maybe<&2, String>}

# A run longer than 258 needs several overlapping matches.
law deflate_run:
  {Z.inflate(Z.deflate(String.repeat("a", 600n))) == Some{String.repeat("a", 600n)} : Maybe<&2, String>}

law deflate_repeats:
  {Z.inflate(Z.deflate(String.repeat("the quick brown fox jumps over the lazy dog. ", 40n))) == Some{String.repeat("the quick brown fox jumps over the lazy dog. ", 40n)} : Maybe<&2, String>}

# These bytes decode with system gzip -d.
law gzip_pinned:
  {Z.gzip("hello hello hello hello, world") == bytes([31, 139, 8, 0, 0, 0, 0, 0, 0, 255, 203, 72, 205, 201, 201, 87, 192, 32, 117, 20, 202, 243, 139, 114, 82, 0, 247, 26, 144, 221, 30, 0, 0, 0]) : String}

law gzip_roundtrip:
  {Z.gunzip(Z.gzip("gzip round trip, gzip round trip")) == Some{"gzip round trip, gzip round trip"} : Maybe<&2, String>}

law zlib_roundtrip:
  {Z.unzlib(Z.zlib("zlib round trip, zlib round trip")) == Some{"zlib round trip, zlib round trip"} : Maybe<&2, String>}
