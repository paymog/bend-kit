import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ./hash.bend as Hash

def b(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def v32(r: Bytes.Bytes & U32) -> U32:
  (x, h) = r
  h

def v64(r: Bytes.Bytes & Hash.W64) -> Hash.W64:
  (x, h) = r
  h

def iota.go(n: Nat, +i: U32) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{Chr{i}, iota.go(p, (i + 1 : U32))}

# The bytes 0, 1, ..., n - 1.
def iota(n: Nat) -> Bytes.Bytes:
  b(iota.go(n, 0))

def ones.go(n: Nat) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{Chr{255}, ones.go(p)}

# n bytes of 0xff: enough of them push both Adler sums past 65521.
def ones(n: Nat) -> Bytes.Bytes:
  b(ones.go(n))

# SipHash-1-3 with the reference key 00 01 .. 0f.
def sip(n: Nat) -> Hash.W64:
  v64(Hash.siphash13(iota(n), Hash.W64{117835012, 50462976}, Hash.W64{252579084, 185207048}))

# A W64 is {hi, lo}: 0xcbf29ce484222325 is {0xcbf29ce4, 0x84222325}, in decimal.

# FNV-1a: the published vectors of draft-eastlake-fnv §B.
law fnv1a32_empty:
  {v32(Hash.fnv1a32(b(""))) == 2166136261 : U32}

law fnv1a32_a:
  {v32(Hash.fnv1a32(b("a"))) == 3826002220 : U32}

law fnv1a32_foobar:
  {v32(Hash.fnv1a32(b("foobar"))) == 3214735720 : U32}

law fnv1a64_empty:
  {v64(Hash.fnv1a64(b(""))) == Hash.W64{3421674724, 2216829733} : Hash.W64}

law fnv1a64_a:
  {v64(Hash.fnv1a64(b("a"))) == Hash.W64{2942557260, 2248273036} : Hash.W64}

law fnv1a64_foobar:
  {v64(Hash.fnv1a64(b("foobar"))) == Hash.W64{2241085809, 4147734504} : Hash.W64}

# xxHash: the reference implementation's values. Inputs of 16 and 32 bytes or more take the striped path.
law xxh32_empty:
  {v32(Hash.xxh32(b(""), 0)) == 46947589 : U32}

law xxh32_a:
  {v32(Hash.xxh32(b("a"), 0)) == 1426945110 : U32}

law xxh32_abc:
  {v32(Hash.xxh32(b("abc"), 0)) == 852579327 : U32}

law xxh32_16:
  {v32(Hash.xxh32(b("0123456789abcdef"), 0)) == 3267648361 : U32}

law xxh32_spam:
  {v32(Hash.xxh32(b("Nobody inspects the spammish repetition"), 0)) == 3794352943 : U32}

law xxh32_fox:
  {v32(Hash.xxh32(b("The quick brown fox jumps over the lazy dog"), 0)) == 3898516702 : U32}

law xxh32_seed:
  {v32(Hash.xxh32(b("Nobody inspects the spammish repetition"), 1)) == 1396992490 : U32}

law xxh64_empty:
  {v64(Hash.xxh64(b(""), Hash.W64{0, 0})) == Hash.W64{4014398263, 1373170073} : Hash.W64}

law xxh64_a:
  {v64(Hash.xxh64(b("a"), Hash.W64{0, 0})) == Hash.W64{3528377585, 2844552795} : Hash.W64}

law xxh64_foobar:
  {v64(Hash.xxh64(b("foobar"), Hash.W64{0, 0})) == Hash.W64{2729051629, 2424679161} : Hash.W64}

law xxh64_16:
  {v64(Hash.xxh64(b("0123456789abcdef"), Hash.W64{0, 0})) == Hash.W64{1549504707, 1312255243} : Hash.W64}

law xxh64_spam:
  {v64(Hash.xxh64(b("Nobody inspects the spammish repetition"), Hash.W64{0, 0})) == Hash.W64{4224624700, 2318896113} : Hash.W64}

law xxh64_fox:
  {v64(Hash.xxh64(b("The quick brown fox jumps over the lazy dog"), Hash.W64{0, 0})) == Hash.W64{186920246, 534409660} : Hash.W64}

law xxh64_seed:
  {v64(Hash.xxh64(b("The quick brown fox jumps over the lazy dog"), Hash.W64{0, 1})) == Hash.W64{3746599350, 3671246555} : Hash.W64}

# SipHash-1-3: Rust's reference vectors, message 00 01 .. n-1 under key 00 01 .. 0f.
law siphash13_0:
  {sip(0n) == Hash.W64{2880176472, 84919516} : Hash.W64}

law siphash13_1:
  {sip(1n) == Hash.W64{3388251123, 2102905491} : Hash.W64}

law siphash13_7:
  {sip(7n) == Hash.W64{3549592984, 2612072768} : Hash.W64}

law siphash13_8:
  {sip(8n) == Hash.W64{915445009, 2368313998} : Hash.W64}

law siphash13_15:
  {sip(15n) == Hash.W64{3542145133, 709990742} : Hash.W64}

law siphash13_63:
  {sip(63n) == Hash.W64{2635698274, 3082531752} : Hash.W64}

# CRC-32 and Adler-32: the values zlib computes.
law crc32_empty:
  {v32(Hash.crc32(b(""))) == 0 : U32}

law crc32_hello:
  {v32(Hash.crc32(b("hello"))) == 907060870 : U32}

law crc32_fox:
  {v32(Hash.crc32(b("The quick brown fox jumps over the lazy dog"))) == 1095738169 : U32}

law adler32_empty:
  {v32(Hash.adler32(b(""))) == 1 : U32}

law adler32_hello:
  {v32(Hash.adler32(b("hello"))) == 103547413 : U32}

law adler32_fox:
  {v32(Hash.adler32(b("The quick brown fox jumps over the lazy dog"))) == 1541148634 : U32}

law adler32_ff512:
  {v32(Hash.adler32(ones(512n))) == 519175696 : U32}

law crc32_ff512:
  {v32(Hash.crc32(ones(512n))) == 3179004831 : U32}

# The .str forms: a byte string hashes as its Bytes do.
law fnv1a32_str:
  {Hash.fnv1a32.str("foobar") == 3214735720 : U32}

law fnv1a64_str:
  {Hash.fnv1a64.str("foobar") == Hash.W64{2241085809, 4147734504} : Hash.W64}

law xxh32_str:
  {Hash.xxh32.str("Nobody inspects the spammish repetition", 0) == 3794352943 : U32}

law xxh64_str:
  {Hash.xxh64.str("The quick brown fox jumps over the lazy dog", Hash.W64{0, 0}) == Hash.W64{186920246, 534409660} : Hash.W64}

law siphash13_str:
  {Hash.siphash13.str(iota.go(15n, 0), Hash.W64{117835012, 50462976}, Hash.W64{252579084, 185207048}) == Hash.W64{3542145133, 709990742} : Hash.W64}

law crc32_str:
  {Hash.crc32.str("hello") == 907060870 : U32}

law adler32_str:
  {Hash.adler32.str("hello") == 103547413 : U32}
