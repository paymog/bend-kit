# ZIP archives read over Bytes: stored and DEFLATE entries, checked against their CRC-32 and sizes. Source: https://github.com/paymog/bend-kit/tree/main/archive
import Base
import ../bytes/bytes.bend as Bytes
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as HubBytes
import bend-kit-zlib@0.2.0.1/zlib.bend as Zlib
import bend-kit-hash@0.1.0.0/hash.bend as Hash

# One member: its name and contents as raw bytes, its method (0 stored, 8 DEFLATE), and its CRC-32.
type Entry is Type:
  Entry{name: Bytes.Bytes, data: Bytes.Bytes, method: U32, crc: U32}

# A checked central directory entry. name and data are byte offsets into the input;
# packed is the stored or compressed length, size the length after decoding.
type Header is Data:
  Header{name: U32, name_len: U32, method: U32, crc: U32, packed: U32, size: U32, data: U32}

# The methods read: 0 (stored) and 8 (DEFLATE).
def supported(+method: U32) -> Bool:
  Bool.or(U32.is_eq(method, 0), U32.is_eq(method, 8))

# Hash uses the published Bytes type; transfer the array without copying.
def crc.local(r: HubBytes.Bytes & U32) -> Bytes.Bytes & U32:
  (HubBytes.Bytes{len, buf}, crc) = r
  (Bytes.Bytes{len, buf}, crc)

def crc.bytes(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  Bytes.Bytes{len, buf} = b
  crc.local(Hash.crc32(HubBytes.Bytes{len, buf}))

def crc.value(r: Bytes.Bytes & U32) -> U32:
  (b, crc) = r
  crc

def crc32(b: Bytes.Bytes) -> U32:
  crc.value(crc.bytes(b))

# n bytes from i as a list. Callers keep i + n within the buffer.
def grab.go(k: Nat, r: Array<U32> & U32, +j: U32, acc: List<&2, U32>) -> Array<U32> & List<&2, U32>:
  match k:
    case 0n:
      (a, v) = r
      (a, acc)
    case 1n+p:
      (a, +v) = r
      grab.go(p, Bytes.peek(a, (j - 1 : U32)), (j - 1 : U32), Con{v, acc})

def grab(a: Array<U32>, +i: U32, +n: U32) -> Array<U32> & List<&2, U32>:
  +j = (i + n - 1 : U32)
  grab.go(U32.to_nat(n), Bytes.peek(a, j), j, Nil{})

def at(xs: List<&2, U32>, +i: U32) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{h, t}:
      Bool.pick(U32, U32.is_zero(i), h, at(t, (i - 1 : U32)))

# Little-endian fields of a grabbed record.
def u16(+xs: List<&2, U32>, +o: U32) -> U32:
  (at(xs, o) .|. (at(xs, (o + 1 : U32)) << 8n) : U32)

def u32(+xs: List<&2, U32>, +o: U32) -> U32:
  (u16(xs, o) .|. (u16(xs, (o + 2 : U32)) << 16n) : U32)

# The first failed check's message, outermost first.
def why(+ok: Bool, +msg: String, +rest: Maybe<&2, String>) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, ok, rest, Some{msg})

# General purpose flags: encrypted (bit 0), strong encryption (bit 6), masked headers (bit 13).
def encrypted(+flags: U32) -> Bool:
  Bool.not(U32.is_zero((flags .&. 8257 : U32)))

# Do n bytes at x and at y match? r holds the previous byte's answer.
def same.at3(r: Array<U32> & U32, +u: U32) -> Array<U32> & Bool:
  (a, +v) = r
  (a, U32.is_eq(u, v))

def same.at2(r: Array<U32> & U32, +y: U32) -> Array<U32> & Bool:
  (a, +u) = r
  same.at3(Bytes.peek(a, y), u)

def same.go(n: Nat, r: Array<U32> & Bool, +x: U32, +y: U32) -> Array<U32> & Bool:
  match n:
    case 0n:
      r
    case 1n+q:
      (a, ok) = r
      match ok:
        case False{}:
          (a, False{})
        case True{}:
          same.go(q, same.at2(Bytes.peek(a, x), y), (x + 1 : U32), (y + 1 : U32))

# End of central directory (APPNOTE 4.3.16): the last signature whose comment length reaches the end exactly.
def eocd.of(r: Array<U32> & List<&2, U32>, +len: U32, +p: U32) -> Array<U32> & Bool:
  (a, +x) = r
  (a, Bool.and(U32.is_eq(u32(x, 0), 101010256), U32.is_eq(u16(x, 20), (len - p - 22 : U32))))

def eocd.win(a: Array<U32>, +len: U32, +p: U32) -> Array<U32> & Bool:
  eocd.of(grab(a, p, 22), len, p)

# f counts the positions left below p; a comment is at most 65535 bytes.
def eocd.go(f: Nat, r: Array<U32> & Bool, +len: U32, +p: U32) -> Array<U32> & Maybe<&2, U32>:
  match f:
    case 0n:
      (a, hit) = r
      (a, Bool.pick(Maybe<&2, U32>, hit, Some{p}, None{}))
    case 1n+q:
      (a, hit) = r
      match hit:
        case True{}:
          (a, Some{p})
        case False{}:
          eocd.go(q, eocd.win(a, len, (p - 1 : U32)), len, (p - 1 : U32))

def cd.fin.end(ok: Bool, acc: List<&2, Header>) -> Result<&1, &1, U32 & String, List<&2, Header>>:
  match ok:
    case True{}:
      Done{List.reverse(&2, Header, acc)}
    case False{}:
      Fail{(22, "central directory size does not match its entries")}

def cd.fin(res: Result<&1, &1, U32 & String, U32 & List<&2, Header>>, +end: U32) -> Result<&1, &1, U32 & String, List<&2, Header>>:
  match res:
    case Fail{e}:
      Fail{e}
    case Done{(+p, acc)}:
      cd.fin.end(U32.is_eq(p, end), acc)

def lh.push(ok: Bool, a: Array<U32>, +hd: Header, +next: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  match ok:
    case False{}:
      (a, Fail{(22, "local header name differs from the central directory")})
    case True{}:
      (a, Done{(next, Con{hd, acc})})

def lh.same(r: Array<U32> & Bool, +hd: Header, +next: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  (a, ok) = r
  lh.push(ok, a, hd, next, acc)

def lh.name(err: Maybe<&2, String>, a: Array<U32>, +lname: U32, +hd: Header, +next: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  match err:
    case Some{m}:
      (a, Fail{(22, m)})
    case None{}:
      Header{+name, +nlen, method, crc, packed, size, data} = hd
      lh.same(same.go(U32.to_nat(nlen), (a, True{}), name, lname), hd, next, acc)

# Local file header (APPNOTE 4.3.7): it must agree with the central directory, and its data must end before the directory.
def lh.err(+l: List<&2, U32>, +method: U32, +nlen: U32, +packed: U32, +cdoff: U32, +lname: U32, +extra: U32) -> Maybe<&2, String>:
  +data = (lname + extra : U32)
  why(U32.is_eq(u32(l, 0), 67324752), "bad local header signature",
    why(Bool.not(encrypted(u16(l, 6))), "encrypted entries are unsupported",
      why(U32.is_eq(u16(l, 8), method), "local header method differs from the central directory",
        why(U32.is_eq(u16(l, 26), nlen), "local header name differs from the central directory",
          why(Bytes.fits(cdoff, lname, extra), "local header runs past the central directory",
            why(Bytes.fits(cdoff, data, packed), "entry data runs past the central directory", None{}))))))

def lh.head(r: Array<U32> & List<&2, U32>, +h: List<&2, U32>, +p: U32, +next: U32, +cdoff: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  (a, +l) = r
  +nlen = u16(h, 28)
  +method = u16(h, 10)
  +packed = u32(h, 20)
  +lname = (u32(h, 42) + 30 : U32)
  +extra = (u16(l, 26) + u16(l, 28) : U32)
  lh.name(lh.err(l, method, nlen, packed, cdoff, lname, extra), a, lname, Header{(p + 46 : U32), nlen, method, u32(h, 16), packed, u32(h, 24), (lname + extra : U32)}, next, acc)

def lh.at(ok: Bool, a: Array<U32>, +h: List<&2, U32>, +p: U32, +next: U32, +cdoff: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  match ok:
    case False{}:
      (a, Fail{(22, "local header is out of bounds")})
    case True{}:
      lh.head(grab(a, u32(h, 42), 30), h, p, next, cdoff, acc)

# Central directory file header (APPNOTE 4.3.12) at p, with the directory ending at end.
def cd.err(+h: List<&2, U32>, +p: U32, +end: U32) -> Maybe<&2, String>:
  +method = u16(h, 10)
  +packed = u32(h, 20)
  +size = u32(h, 24)
  +rest = (u16(h, 28) + u16(h, 30) + u16(h, 32) : U32)
  +zip64 = Bool.or(Bool.or(U32.is_eq(packed, 4294967295), U32.is_eq(size, 4294967295)), U32.is_eq(u32(h, 42), 4294967295))
  why(U32.is_eq(u32(h, 0), 33639248), "bad central directory header signature",
    why(Bool.not(encrypted(u16(h, 8))), "encrypted entries are unsupported",
      why(supported(method), "unsupported compression method " ++ U32.show(method),
        why(Bool.not(zip64), "ZIP64 is unsupported",
          why(U32.is_eq(u16(h, 34), 0), "multi-disk ZIP is unsupported",
            why(Bytes.fits(end, (p + 46 : U32), rest), "central directory header runs past the directory",
              why(Bool.or(U32.is_eq(method, 8), U32.is_eq(packed, size)), "stored entry sizes differ", None{})))))))

def cd.head.of(err: Maybe<&2, String>, a: Array<U32>, +h: List<&2, U32>, +p: U32, +cdoff: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  match err:
    case Some{m}:
      (a, Fail{(22, m)})
    case None{}:
      +next = (p + 46 + u16(h, 28) + u16(h, 30) + u16(h, 32) : U32)
      lh.at(Bytes.fits(cdoff, u32(h, 42), 30), a, h, p, next, cdoff, acc)

def cd.head(r: Array<U32> & List<&2, U32>, +p: U32, +end: U32, +cdoff: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  (a, +h) = r
  cd.head.of(cd.err(h, p, end), a, h, p, cdoff, acc)

def cd.entry(ok: Bool, a: Array<U32>, +p: U32, +end: U32, +cdoff: U32, acc: List<&2, Header>) -> Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>:
  match ok:
    case False{}:
      (a, Fail{(22, "central directory is truncated")})
    case True{}:
      cd.head(grab(a, p, 46), p, end, cdoff, acc)

# k entries left; r holds the next header's offset and the headers so far, reversed.
def cd.go(k: Nat, r: Array<U32> & Result<&1, &1, U32 & String, U32 & List<&2, Header>>, +end: U32, +cdoff: U32) -> Array<U32> & Result<&1, &1, U32 & String, List<&2, Header>>:
  match k:
    case 0n:
      (a, res) = r
      (a, cd.fin(res, end))
    case 1n+q:
      (a, res) = r
      match res:
        case Fail{e}:
          (a, Fail{e})
        case Done{(+p, acc)}:
          cd.go(q, cd.entry(Bytes.fits(end, p, 46), a, p, end, cdoff, acc), end, cdoff)

def eocd.err(+x: List<&2, U32>, +e: U32) -> Maybe<&2, String>:
  +zip64 = Bool.or(Bool.or(U32.is_eq(u16(x, 10), 65535), U32.is_eq(u32(x, 12), 4294967295)), U32.is_eq(u32(x, 16), 4294967295))
  why(Bool.and(Bool.and(U32.is_eq(u16(x, 4), 0), U32.is_eq(u16(x, 6), 0)), U32.is_eq(u16(x, 8), u16(x, 10))), "multi-disk ZIP is unsupported",
    why(Bool.not(zip64), "ZIP64 is unsupported",
      why(Bytes.fits(e, u32(x, 16), u32(x, 12)), "central directory is out of bounds", None{})))

def eocd.checked(err: Maybe<&2, String>, a: Array<U32>, +x: List<&2, U32>) -> Array<U32> & Result<&1, &1, U32 & String, List<&2, Header>>:
  match err:
    case Some{m}:
      (a, Fail{(22, m)})
    case None{}:
      +off = u32(x, 16)
      cd.go(U32.to_nat(u16(x, 10)), (a, Done{(off, Nil{})}), (off + u32(x, 12) : U32), off)

def eocd.parse(r: Array<U32> & List<&2, U32>, +e: U32) -> Array<U32> & Result<&1, &1, U32 & String, List<&2, Header>>:
  (a, +x) = r
  eocd.checked(eocd.err(x, e), a, x)

def eocd.found(r: Array<U32> & Maybe<&2, U32>) -> Array<U32> & Result<&1, &1, U32 & String, List<&2, Header>>:
  (a, m) = r
  match m:
    case None{}:
      (a, Fail{(22, "no end of central directory record")})
    case Some{+e}:
      eocd.parse(grab(a, e, 22), e)

def headers.at(short: Bool, a: Array<U32>, +len: U32) -> Array<U32> & Result<&1, &1, U32 & String, List<&2, Header>>:
  match short:
    case True{}:
      (a, Fail{(22, "input is shorter than an end of central directory record")})
    case False{}:
      +p = (len - 22 : U32)
      eocd.found(eocd.go(U32.to_nat(U32.min(p, 65535)), eocd.win(a, len, p), len, p))

def headers.fin(+len: U32, r: Array<U32> & Result<&1, &1, U32 & String, List<&2, Header>>) -> Bytes.Bytes & Result<&1, &1, U32 & String, List<&2, Header>>:
  (a, res) = r
  (Bytes.Bytes{len, a}, res)

# The input back, and its central directory with every bound, local header, and method checked. Pure: no data is decoded.
def headers(input: Bytes.Bytes) -> Bytes.Bytes & Result<&1, &1, U32 & String, List<&2, Header>>:
  Bytes.Bytes{+len, buf} = input
  headers.fin(len, headers.at(U32.is_lt(len, 22), buf, len))

def inflated(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match r:
    case Fail{e}:
      (+code, msg) = e
      Fail{Bool.pick(U32 & String, U32.is_eq(code, 27), (22, "entry size differs from the central directory"), (code, "DEFLATE entry: " ++ msg))}
    case Done{(+n, w)}:
      Done{Bytes.Bytes{n, w}}

# Output past size is refused inside libz, so a bomb never grows beyond its declared size.
def inflate.of(+size: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  Bytes.Bytes{+n, buf} = b
  do IO<Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Zlib.inflate.raw.words(size, n, buf)
    return inflated(r)

def decode(stored: Bool, +size: U32, raw: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  match stored:
    case True{}:
      IO.pure(Result<&1, &1, U32 & String, Bytes.Bytes>, Done{raw})
    case False{}:
      inflate.of(size, raw)

def check.crc.of(ok: Bool, b: Bytes.Bytes) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match ok:
    case True{}:
      Done{b}
    case False{}:
      Fail{(22, "entry CRC-32 does not match")}

def check.crc(r: Bytes.Bytes & U32, +crc: U32) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  (b, +c) = r
  check.crc.of(U32.is_eq(c, crc), b)

def check.len.of(ok: Bool, b: Bytes.Bytes, +crc: U32) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match ok:
    case False{}:
      Fail{(22, "entry size differs from the central directory")}
    case True{}:
      check.crc(crc.bytes(b), crc)

def check.len(r: Bytes.Bytes & U32, +size: U32, +crc: U32) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  (b, +n) = r
  check.len.of(U32.is_eq(n, size), b, crc)

def check(+size: U32, +crc: U32, r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      check.len(Bytes.length(b), size, crc)

def one.put(r: Result<&1, &1, U32 & String, Bytes.Bytes>, nm: Bytes.Bytes, +method: U32, +crc: U32, +left: U32, +size: U32, acc: List<&1, Entry>) -> Result<&1, &1, U32 & String, U32 & List<&1, Entry>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      Done{((left - size : U32), Con{Entry{nm, b, method, crc}, acc})}

def one.data(r: Bytes.Bytes & Bytes.Bytes, nm: Bytes.Bytes, +method: U32, +crc: U32, +size: U32, +left: U32, acc: List<&1, Entry>) -> IO(Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>>):
  (input, raw) = r
  do IO<Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>>>:
    out : Result<&1, &1, U32 & String, Bytes.Bytes> <- decode(U32.is_eq(method, 0), size, raw)
    return (input, one.put(check(size, crc, out), nm, method, crc, left, size, acc))

def one.name(r: Bytes.Bytes & Bytes.Bytes, +method: U32, +crc: U32, +packed: U32, +size: U32, +data: U32, +left: U32, acc: List<&1, Entry>) -> IO(Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>>):
  (input, nm) = r
  one.data(Bytes.slice(input, data, packed), nm, method, crc, size, left, acc)

# left: the output still allowed under the caller's max.
def one.cap(over: Bool, input: Bytes.Bytes, +hd: Header, +left: U32, acc: List<&1, Entry>) -> IO(Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>>):
  match over:
    case True{}:
      IO.pure(Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>>, (input, Fail{(27, "archive output is larger than max")}))
    case False{}:
      Header{+name, +nlen, +method, +crc, +packed, +size, +data} = hd
      one.name(Bytes.slice(input, name, nlen), method, crc, packed, size, data, left, acc)

def one(+hd: Header, input: Bytes.Bytes, +left: U32, acc: List<&1, Entry>) -> IO(Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>>):
  Header{name, nlen, method, crc, packed, +size, data} = hd
  one.cap(U32.is_lt(left, size), input, hd, left, acc)

def run.fin(res: Result<&1, &1, U32 & String, U32 & List<&1, Entry>>) -> Result<&1, &1, U32 & String, List<&1, Entry>>:
  match res:
    case Fail{e}:
      Fail{e}
    case Done{(left, acc)}:
      Done{List.reverse(&1, Entry, acc)}

def run(xs: List<&2, Header>, st: Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>>) -> IO(Result<&1, &1, U32 & String, List<&1, Entry>>):
  match xs:
    case Nil{}:
      (input, res) = st
      IO.pure(Result<&1, &1, U32 & String, List<&1, Entry>>, run.fin(res))
    case Con{hd, t}:
      (input, res) = st
      match res:
        case Fail{e}:
          IO.pure(Result<&1, &1, U32 & String, List<&1, Entry>>, Fail{e})
        case Done{(+left, acc)}:
          do IO<Result<&1, &1, U32 & String, List<&1, Entry>>>:
            next : Bytes.Bytes & Result<&1, &1, U32 & String, U32 & List<&1, Entry>> <- one(hd, input, left, acc)
            run(t, next)

def read.of(r: Bytes.Bytes & Result<&1, &1, U32 & String, List<&2, Header>>, +max: U32) -> IO(Result<&1, &1, U32 & String, List<&1, Entry>>):
  (input, res) = r
  match res:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, List<&1, Entry>>, Fail{e})
    case Done{xs}:
      run(xs, (input, Done{(max, Nil{})}))

# Every entry of a ZIP archive, in central directory order, or the first problem found.
# Stored (0) and DEFLATE (8) entries only; no ZIP64, encryption, or multi-disk archives.
# Output past max bytes in total fails with 27 (EFBIG). Malformed ZIP fails with 22 (EINVAL); libz load and allocation errors keep their host codes.
def read(max: U32, input: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, List<&1, Entry>>):
  read.of(headers(input), max)
