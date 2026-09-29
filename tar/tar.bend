# tar archives (POSIX ustar with PAX path and size records) of regular files and directories over Bytes. Source: https://github.com/paymog/bend-kit/tree/main/tar
import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# An archive is a list of entries in order. Names are raw bytes (UTF-8 by convention), kept byte for byte;
# a directory keeps whatever trailing '/' its name has. Nothing here touches the filesystem.
#   import ./tar/tar.bend as Tar
type Entry is Type:
  File{name: Bytes.Bytes, data: Bytes.Bytes}
  Dir{name: Bytes.Bytes}


# n rounded up to a whole 512-byte block; 0 when that would pass U32.
def pad(+n: U32) -> U32:
  ((n + 511 : U32) .&. 4294966784 : U32)

# The sum of w's four bytes.
def wsum(+w: U32) -> U32:
  ((w .&. 255) + ((w >> 8n) .&. 255) + ((w >> 16n) .&. 255) + (w >> 24n) : U32)

def bsum.go(n: Nat, r: Array<U32> & U32, +k: U32, +acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (a, w) = r
      (a, acc)
    case 1n+p:
      (a, +w) = r
      bsum.go(p, Array.get(U32, a, (k + 1 : U32)), (k + 1 : U32), (acc + wsum(w) : U32))

# The sum of the 512 bytes from word k: 0 only for a zero block.
def bsum(a: Array<U32>, +k: U32) -> Array<U32> & U32:
  bsum.go(128n, Array.get(U32, a, k), k, 0)

# Octal digits after leading spaces, ended by NUL, space, or the field's end. ph: 0 leading, 1 digits, 2 done.
def oct.go(n: Nat, r: Array<U32> & U32, +j: U32, +ph: U32, +acc: U32, +ok: Bool) -> Array<U32> & U32 & Bool:
  match n:
    case 0n:
      (a, c) = r
      (a, acc, ok)
    case 1n+p:
      (a, +c) = r
      +live = U32.is_ne(ph, 2)
      +dig = live && Bytes.in(48, c, 55)
      +bad = live && Bool.not(Bytes.in(48, c, 55) || (U32.is_eq(c, 32) || U32.is_eq(c, 0)))
      +over = dig && U32.is_lt(536870911, acc)
      +ph2 = Bool.pick(U32, live, Bool.pick(U32, dig, 1, Bool.pick(U32, U32.is_eq(ph, 0) && U32.is_eq(c, 32), 0, 2)), 2)
      +acc2 = Bool.pick(U32, dig, ((acc << 3n) .|. (c - 48) : U32), acc)
      oct.go(p, Bytes.peek(a, (j + 1 : U32)), (j + 1 : U32), ph2, acc2, ok && Bool.not(bad || over))

# The octal field of w bytes at j, and whether it is well formed and fits a U32.
def oct(a: Array<U32>, +j: U32, +w: U32) -> Array<U32> & U32 & Bool:
  oct.go(U32.to_nat(w), Bytes.peek(a, j), j, 0, 0, True{})

def cstr.go(n: Nat, r: Array<U32> & U32, +j: U32, +k: U32, +done: Bool) -> Array<U32> & U32:
  match n:
    case 0n:
      (a, c) = r
      (a, k)
    case 1n+p:
      (a, +c) = r
      match done:
        case True{}:
          (a, k)
        case False{}:
          +stop = U32.is_eq(c, 0)
          cstr.go(p, Bytes.peek(a, (j + 1 : U32)), (j + 1 : U32), Bool.pick(U32, stop, k, (k + 1 : U32)), stop)

# The count of bytes before the first NUL in the w bytes from j.
def cstr(a: Array<U32>, +j: U32, +w: U32) -> Array<U32> & U32:
  cstr.go(U32.to_nat(w), Bytes.peek(a, j), j, 0, False{})

type Dec is Data:
  Dec{v: U32, j: U32, ok: Bool}

def dpk.of(r: Array<U32> & U32) -> Array<U32> & U32 & Bool:
  (a, +c) = r
  (a, c, Bytes.in(48, c, 57))

# Byte j, and whether it is a decimal digit before end.
def dpk(ok: Bool, a: Array<U32>, +j: U32) -> Array<U32> & U32 & Bool:
  match ok:
    case True{}:
      dpk.of(Bytes.peek(a, j))
    case False{}:
      (a, 0, False{})

def dec.go(n: Nat, r: Array<U32> & U32 & Bool, +j: U32, +end: U32, +acc: U32, +ok: Bool) -> Array<U32> & Dec:
  match n:
    case 0n:
      (a, c, d) = r
      (a, Dec{acc, j, ok})
    case 1n+p:
      (a, c, d) = r
      match d:
        case False{}:
          (a, Dec{acc, j, ok})
        case True{}:
          +v = (c - 48 : U32)
          +fit = U32.is_lt(acc, 429496729) || (U32.is_eq(acc, 429496729) && U32.is_le(v, 5))
          dec.go(p, dpk(U32.is_lt((j + 1 : U32), end), a, (j + 1 : U32)), (j + 1 : U32), end, ((acc * 10) + v : U32), ok && fit)

# Decimal digits from j up to end: the value, the index after the last digit, and whether it fits a U32.
def dec(a: Array<U32>, +j: U32, +end: U32) -> Array<U32> & Dec:
  dec.go(U32.to_nat(Bool.pick(U32, U32.is_le(j, end), (end - j : U32), 0)), dpk(U32.is_lt(j, end), a, j), j, end, 0, True{})

# ---- decode ----

# Header i's name: prefix "/" name when the magic is POSIX ustar and the prefix is not empty.
def name.fin(+total: U32, r: Array<U32> & Array<U32>) -> Array<U32> & Bytes.Bytes:
  (a, o) = r
  (a, Bytes.Bytes{total, o})

def name.join(+i: U32, +n: U32, +pl: U32, r: Array<U32> & Array<U32>) -> Array<U32> & Bytes.Bytes:
  (a, o) = r
  +some = U32.is_ne(pl, 0)
  +off = Bool.pick(U32, some, (pl + 1 : U32), 0)
  name.fin((off + n : U32), Bytes.copy(n, a, Bytes.poke.when(some, o, pl, 47), i, off))

def name.pre(+i: U32, +n: U32, r: Array<U32> & U32) -> Array<U32> & Bytes.Bytes:
  (a, +pl) = r
  +off = Bool.pick(U32, U32.is_ne(pl, 0), (pl + 1 : U32), 0)
  name.join(i, n, pl, Bytes.copy(pl, a, Bytes.alloc((off + n : U32)), (i + 345 : U32), 0))

def pfx.len(ustar: Bool, a: Array<U32>, +i: U32) -> Array<U32> & U32:
  match ustar:
    case True{}:
      cstr(a, (i + 345 : U32), 155)
    case False{}:
      (a, 0)

def name.magic(+i: U32, +n: U32, r: Array<U32> & Bool) -> Array<U32> & Bytes.Bytes:
  (a, ustar) = r
  name.pre(i, n, pfx.len(ustar, a, i))

def name.len(+i: U32, r: Array<U32> & U32) -> Array<U32> & Bytes.Bytes:
  (a, +n) = r
  name.magic(i, n, Bytes.at(a, "ustar\u{0}", (i + 257 : U32)))

def header.name(a: Array<U32>, +i: U32) -> Array<U32> & Bytes.Bytes:
  name.len(i, cstr(a, i, 100))

# Records from an 'x' header that apply to the next entry.
type Pax is Type:
  Pax{path: Maybe<&1, Bytes.Bytes>, size: Maybe<&2, U32>}

type Pst is Type:
  PGo{p: U32, pax: Pax}
  PEnd{pax: Pax}
  PBad{}

def pr.opt(has: Bool, b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  match has:
    case True{}:
      Some{b}
    case False{}:
      None{}

# An empty value unsets the keyword (POSIX pax), so the header's own name applies.
def pr.setpath(+next: U32, +m: U32, pax: Pax, r: Array<U32> & Array<U32>) -> Array<U32> & Pst:
  Pax{old, +size} = pax
  (a, o) = r
  (a, PGo{next, Pax{pr.opt(U32.is_ne(m, 0), Bytes.Bytes{m, o}), size}})

def pr.putsize(+next: U32, +v: U32, pax: Pax) -> Pst:
  Pax{path, old} = pax
  PGo{next, Pax{path, Some{v}}}

def pr.sized(ok: Bool, a: Array<U32>, +next: U32, +v: U32, pax: Pax) -> Array<U32> & Pst:
  match ok:
    case True{}:
      (a, pr.putsize(next, v, pax))
    case False{}:
      (a, PBad{})

def pr.setsize(+vs: U32, +e: U32, +next: U32, pax: Pax, r: Array<U32> & Dec) -> Array<U32> & Pst:
  (a, d) = r
  Dec{+v, +j, +ok} = d
  pr.sized(ok && (U32.is_eq(j, e) && U32.is_lt(vs, j)), a, next, v, pax)

def pr.size(hit: Bool, a: Array<U32>, +q: U32, +e: U32, +next: U32, pax: Pax) -> Array<U32> & Pst:
  match hit:
    case True{}:
      pr.setsize((q + 6 : U32), e, next, pax, dec(a, (q + 6 : U32), e))
    case False{}:
      (a, PGo{next, pax})

def pr.ksize(+q: U32, +e: U32, +next: U32, pax: Pax, r: Array<U32> & Bool) -> Array<U32> & Pst:
  (a, hit) = r
  pr.size(hit && U32.is_le((q + 6 : U32), e), a, q, e, next, pax)

def pr.path(hit: Bool, a: Array<U32>, +q: U32, +e: U32, +next: U32, pax: Pax) -> Array<U32> & Pst:
  match hit:
    case True{}:
      +m = (e - q - 6 : U32)
      pr.setpath(next, m, pax, Bytes.copy(m, a, Bytes.alloc(m), (q + 6 : U32), 0))
    case False{}:
      pr.ksize(q, e, next, pax, Bytes.at(a, "size=", (q + 1 : U32)))

def pr.kpath(+q: U32, +e: U32, +next: U32, pax: Pax, r: Array<U32> & Bool) -> Array<U32> & Pst:
  (a, hit) = r
  pr.path(hit && U32.is_le((q + 6 : U32), e), a, q, e, next, pax)

# Unknown keywords (mtime, uid, ...) are skipped.
def pr.rec(ok: Bool, a: Array<U32>, +q: U32, +e: U32, pax: Pax) -> Array<U32> & Pst:
  match ok:
    case True{}:
      pr.kpath(q, e, (e + 1 : U32), pax, Bytes.at(a, "path=", (q + 1 : U32)))
    case False{}:
      (a, PBad{})

def pr.nl(+good: Bool, +q: U32, +e: U32, pax: Pax, r: Array<U32> & Bool) -> Array<U32> & Pst:
  (a, lf) = r
  pr.rec(good && lf, a, q, e, pax)

def pr.sp(+good: Bool, +q: U32, +e: U32, pax: Pax, r: Array<U32> & Bool) -> Array<U32> & Pst:
  (a, sp) = r
  pr.nl(good && sp, q, e, pax, Bytes.at(a, "\n", e))

# A record is "<len> <key>=<value>\n", len counting the whole record; q is the space, e the newline.
def pr.len(+p: U32, +end: U32, pax: Pax, r: Array<U32> & Dec) -> Array<U32> & Pst:
  (a, d) = r
  Dec{+l, +q, +ok} = d
  +e = (p + l - 1 : U32)
  +good = ok && (U32.is_lt(p, q) && (U32.is_lt((q - p + 1 : U32), l) && U32.is_le(l, (end - p : U32))))
  pr.sp(good, q, e, pax, Bytes.at(a, " ", q))

def pr.more(more: Bool, a: Array<U32>, +p: U32, +end: U32, pax: Pax) -> Array<U32> & Pst:
  match more:
    case True{}:
      pr.len(p, end, pax, dec(a, p, end))
    case False{}:
      (a, PEnd{pax})

# Each record takes at least three bytes; allow one step to reach the end and one to return it.
def pr.run(fuel: Nat, r: Array<U32> & Pst, +end: U32) -> Array<U32> & Maybe<&1, Pax>:
  match fuel:
    case 0n:
      (a, st) = r
      (a, None{})
    case 1n+f:
      (a, st) = r
      match st:
        case PGo{+p, pax}:
          pr.run(f, pr.more(U32.is_lt(p, end), a, p, end, pax), end)
        case PEnd{pax}:
          (a, Some{pax})
        case PBad{}:
          (a, None{})

def pr.parse(a: Array<U32>, +s: U32, +size: U32, pax: Pax) -> Array<U32> & Maybe<&1, Pax>:
  pr.run(U32.to_nat(((size >> 1n) + 2 : U32)), (a, PGo{s, pax}), (s + size : U32))

type St is Type:
  SHead{i: U32, pax: Pax, acc: List<&1, Entry>}
  SOk{entries: List<&1, Entry>}
  SFail{}

def name.of(path: Maybe<&1, Bytes.Bytes>, a: Array<U32>, +i: U32) -> Array<U32> & Bytes.Bytes:
  match path:
    case Some{b}:
      (a, b)
    case None{}:
      header.name(a, i)

def file.data(+next: U32, +size: U32, name: Bytes.Bytes, acc: List<&1, Entry>, r: Array<U32> & Array<U32>) -> Array<U32> & St:
  (a, o) = r
  (a, SHead{next, Pax{None{}, None{}}, Con{File{name, Bytes.Bytes{size, o}}, acc}})

def file.name(+i: U32, +size: U32, +next: U32, acc: List<&1, Entry>, r: Array<U32> & Bytes.Bytes) -> Array<U32> & St:
  (a, name) = r
  file.data(next, size, name, acc, Bytes.copy(size, a, Bytes.alloc(size), (i + 512 : U32), 0))

def entry.file(+i: U32, +size: U32, +next: U32, acc: List<&1, Entry>, pax: Pax, a: Array<U32>) -> Array<U32> & St:
  Pax{path, s} = pax
  file.name(i, size, next, acc, name.of(path, a, i))

def dir.name(+next: U32, acc: List<&1, Entry>, r: Array<U32> & Bytes.Bytes) -> Array<U32> & St:
  (a, name) = r
  (a, SHead{next, Pax{None{}, None{}}, Con{Dir{name}, acc}})

# A directory's size field is skipped over like data.
def entry.dir(+i: U32, +next: U32, acc: List<&1, Entry>, pax: Pax, a: Array<U32>) -> Array<U32> & St:
  Pax{path, s} = pax
  dir.name(next, acc, name.of(path, a, i))

def step.pax(+next: U32, acc: List<&1, Entry>, r: Array<U32> & Maybe<&1, Pax>) -> Array<U32> & St:
  (a, m) = r
  match m:
    case Some{pax}:
      (a, SHead{next, pax, acc})
    case None{}:
      (a, SFail{})

# '0' and NUL are regular files, '5' directories, 'x' PAX records for the next entry,
# 'g' global PAX records (skipped). Links, devices, FIFOs, GNU extensions and the rest fail.
def step.type(+t: U32, a: Array<U32>, +i: U32, +size: U32, +next: U32, pax: Pax, acc: List<&1, Entry>) -> Array<U32> & St:
  match t:
    case 0:
      entry.file(i, size, next, acc, pax, a)
    case 48:
      entry.file(i, size, next, acc, pax, a)
    case 53:
      entry.dir(i, next, acc, pax, a)
    case 120:
      step.pax(next, acc, pr.parse(a, (i + 512 : U32), size, pax))
    case 103:
      (a, SHead{next, pax, acc})
    case _:
      (a, SFail{})

def step.kind(fit: Bool, +t: U32, a: Array<U32>, +i: U32, +size: U32, +next: U32, pax: Pax, acc: List<&1, Entry>) -> Array<U32> & St:
  match fit:
    case True{}:
      step.type(t, a, i, size, next, pax, acc)
    case False{}:
      (a, SFail{})

# The data and its padding to a whole block must be in the archive.
def step.fit(+len: U32, +i: U32, +size: U32, +ok: Bool, pax: Pax, acc: List<&1, Entry>, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +t) = r
  +pd = pad(size)
  +fit = ok && (U32.is_le(size, pd) && Bytes.fits(len, (i + 512 : U32), pd))
  step.kind(fit, t, a, i, size, (i + 512 + pd : U32), pax, acc)


# A PAX size overrides the header's field, which then need not parse.
def step.size(+len: U32, +i: U32, pax: Pax, acc: List<&1, Entry>, r: Array<U32> & U32 & Bool) -> Array<U32> & St:
  Pax{path, +psize} = pax
  (a, v, ok) = r
  step.fit(len, i, Maybe.default(&2, U32, psize, v), Maybe.is_some(&2, U32, psize) || ok, Pax{path, psize}, acc, Bytes.peek(a, (i + 156 : U32)))

def step.hdr(ok: Bool, a: Array<U32>, +len: U32, +i: U32, pax: Pax, acc: List<&1, Entry>) -> Array<U32> & St:
  match ok:
    case True{}:
      step.size(len, i, pax, acc, oct(a, (i + 124 : U32), 12))
    case False{}:
      (a, SFail{})

# The checksum counts the 8 checksum bytes (words 37 and 38) as spaces.
def step.ck3(+len: U32, +i: U32, +s: U32, +ck: U32, +ok: Bool, +x: U32, pax: Pax, acc: List<&1, Entry>, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +w) = r
  step.hdr(ok && U32.is_eq(ck, (s - x - wsum(w) + 256 : U32)), a, len, i, pax, acc)

def step.ck2(+len: U32, +i: U32, +s: U32, +ck: U32, +ok: Bool, pax: Pax, acc: List<&1, Entry>, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +w) = r
  step.ck3(len, i, s, ck, ok, wsum(w), pax, acc, Array.get(U32, a, ((i >> 2n) + 38 : U32)))

def step.ck(+len: U32, +i: U32, +s: U32, pax: Pax, acc: List<&1, Entry>, r: Array<U32> & U32 & Bool) -> Array<U32> & St:
  (a, ck, ok) = r
  step.ck2(len, i, s, ck, ok, pax, acc, Array.get(U32, a, ((i >> 2n) + 37 : U32)))

# The end: a second zero block, with no PAX records left waiting for an entry.
def end.pax(pax: Pax, acc: List<&1, Entry>) -> St:
  Pax{p, s} = pax
  match p s:
    case None{} None{}:
      SOk{List.reverse(&1, Entry, acc)}
    case _ _:
      SFail{}

def end.of(ok: Bool, pax: Pax, acc: List<&1, Entry>) -> St:
  match ok:
    case True{}:
      end.pax(pax, acc)
    case False{}:
      SFail{}

def end.sum(pax: Pax, acc: List<&1, Entry>, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +s) = r
  (a, end.of(U32.is_eq(s, 0), pax, acc))

def end.fits(ok: Bool, a: Array<U32>, +i: U32, pax: Pax, acc: List<&1, Entry>) -> Array<U32> & St:
  match ok:
    case True{}:
      end.sum(pax, acc, bsum(a, ((i + 512 : U32) >> 2n : U32)))
    case False{}:
      (a, SFail{})

def step.zero(zero: Bool, a: Array<U32>, +len: U32, +i: U32, +s: U32, pax: Pax, acc: List<&1, Entry>) -> Array<U32> & St:
  match zero:
    case True{}:
      end.fits(Bytes.fits(len, (i + 512 : U32), 512), a, i, pax, acc)
    case False{}:
      step.ck(len, i, s, pax, acc, oct(a, (i + 148 : U32), 8))

def step.sum(+len: U32, +i: U32, pax: Pax, acc: List<&1, Entry>, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +s) = r
  step.zero(U32.is_eq(s, 0), a, len, i, s, pax, acc)

def step.fits(ok: Bool, a: Array<U32>, +len: U32, +i: U32, pax: Pax, acc: List<&1, Entry>) -> Array<U32> & St:
  match ok:
    case True{}:
      step.sum(len, i, pax, acc, bsum(a, (i >> 2n : U32)))
    case False{}:
      (a, SFail{})

def step(a: Array<U32>, +len: U32, +i: U32, pax: Pax, acc: List<&1, Entry>) -> Array<U32> & St:
  step.fits(Bytes.fits(len, i, 512), a, len, i, pax, acc)

def run(fuel: Nat, r: Array<U32> & St, +len: U32) -> Maybe<&1, List<&1, Entry>>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      (a, st) = r
      match st:
        case SOk{xs}:
          Some{xs}
        case SFail{}:
          None{}
        case SHead{+i, pax, acc}:
          run(f, step(a, len, i, pax, acc), len)

# The entries in archive order. None for a bad header checksum, a malformed size or PAX record,
# an entry or its padding cut short, a missing end (two zero blocks), or any type but file,
# directory, and PAX records. Bytes after the end are ignored.
# fuel: each header step eats a block, so len / 512 + 2 steps are enough.
def decode(archive: Bytes.Bytes) -> Maybe<&1, List<&1, Entry>>:
  Bytes.Bytes{+len, buf} = archive
  run(U32.to_nat(((len >> 9n) + 2 : U32)), (buf, SHead{0, Pax{None{}, None{}}, Nil{}}), len)

# ---- encode ----

def put.str(s: String, a: Array<U32>, +j: U32) -> Array<U32>:
  match s:
    case SNil{}:
      a
    case SCon{Chr{+c}, t}:
      put.str(t, Bytes.poke(a, j, c), (j + 1 : U32))

# n octal digits of v ending at j, written back to front.
def oct.put(n: Nat, a: Array<U32>, +j: U32, +v: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      oct.put(p, Bytes.poke(a, j, (48 + (v .&. 7) : U32)), (j - 1 : U32), (v >> 3n : U32))

# n decimal digits of v ending at j, written back to front.
def dec.put(n: Nat, a: Array<U32>, +j: U32, +v: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      dec.put(p, Bytes.poke(a, j, (48 + (v % 10) : U32)), (j - 1 : U32), (v / 10 : U32))

def digits.go(n: Nat, +v: U32, +c: U32) -> U32:
  match n:
    case 0n:
      c
    case 1n+p:
      digits.go(p, (v / 10 : U32), Bool.pick(U32, U32.is_le(10, v), (c + 1 : U32), c))

# The count of decimal digits in v.
def digits(+v: U32) -> U32:
  digits.go(9n, v, 1)

# mode, uid 0, gid 0, size, mtime 0, the checksum as spaces, type, and the POSIX ustar magic.
def hdr.fields(+mode: U32, +size: U32, +t: U32, a: Array<U32>) -> Array<U32>:
  f = oct.put(11n, oct.put(7n, oct.put(7n, oct.put(7n, a, 106, mode), 114, 0), 122, 0), 134, size)
  put.str("ustar\u{0}00", Bytes.poke(put.str("        ", oct.put(11n, f, 146, 0), 148), 156, t), 257)

# Six octal digits, NUL, space: the last space stays from the fields.
def hdr.ck(r: Array<U32> & U32) -> Array<U32>:
  (a, +s) = r
  oct.put(6n, Bytes.poke(a, 154, 0), 153, s)

def hdr.of(+mode: U32, +size: U32, +t: U32, r: Array<U32> & Array<U32>) -> Array<U32> & Bytes.Bytes:
  (src, h) = r
  (src, Bytes.Bytes{512, hdr.ck(bsum(hdr.fields(mode, size, t, h), 0))})

# A header block named by the first n bytes of src, handing src back.
def hdr(src: Array<U32>, +n: U32, +mode: U32, +size: U32, +t: U32) -> Array<U32> & Bytes.Bytes:
  hdr.of(mode, size, t, Bytes.copy(n, src, Bytes.alloc(512), 0, 0))

# b with zero bytes up to the next whole block. Bytes past len are already 0, so only len and room grow.
def blk(b: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = b
  +n = pad(len)
  Bytes.Bytes{n, Bytes.grow(len, buf, n)}

def zeros(b: Bytes.Bytes, +n: U32) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = b
  Bytes.Bytes{(len + n : U32), Bytes.grow(len, buf, (len + n : U32))}

def rec.fin(+l: U32, r: Array<U32> & Array<U32>) -> Array<U32> & Bytes.Bytes:
  (nb, o) = r
  (nb, Bytes.Bytes{l, o})

# A PAX path record's length: nl + 7 plus its own digits, found as in POSIX pax.
def rec.len(+nl: U32) -> U32:
  +base = (nl + 7 : U32)
  (base + digits((base + digits(base) : U32)) : U32)

# "<len> path=<name>\n".
def pr.record(nb: Array<U32>, +nl: U32) -> Array<U32> & Bytes.Bytes:
  +l = rec.len(nl)
  +d = digits(l)
  o = Bytes.poke(put.str(" path=", dec.put(U32.to_nat(d), Bytes.alloc(l), (d - 1 : U32), l), d), (l - 1 : U32), 10)
  rec.fin(l, Bytes.copy(nl, nb, o, 0, (d + 6 : U32)))

def hdr.snd(r: Array<U32> & Bytes.Bytes) -> Bytes.Bytes:
  (a, h) = r
  h

def xhdr.of(+rl: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+n, buf} = b
  hdr.snd(hdr(buf, n, 420, rl, 120))

def enc.paxout(out: Bytes.Bytes, rec: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+rl, rb} = rec
  blk(Bytes.append(Bytes.append(out, xhdr.of(rl, Bytes.from_string("././@PaxHeader"))), Bytes.Bytes{rl, rb}))

def enc.pax(out: Bytes.Bytes, r: Array<U32> & Bytes.Bytes) -> Array<U32> & Bytes.Bytes:
  (nb, rec) = r
  (nb, enc.paxout(out, rec))

def enc.hdr(+dl: U32, db: Array<U32>, out: Bytes.Bytes, r: Array<U32> & Bytes.Bytes) -> Bytes.Bytes:
  (nb, h) = r
  blk(Bytes.append(Bytes.append(out, h), Bytes.Bytes{dl, db}))

# The header keeps the name's first 100 bytes; a longer name rides in the PAX record before it.
def enc.main(+nl: U32, +t: U32, +mode: U32, +dl: U32, db: Array<U32>, r: Array<U32> & Bytes.Bytes) -> Bytes.Bytes:
  (nb, out) = r
  enc.hdr(dl, db, out, hdr(nb, U32.min(nl, 100), mode, dl, t))

def enc.long(long: Bool, nb: Array<U32>, +nl: U32, out: Bytes.Bytes, +t: U32, +mode: U32, +dl: U32, db: Array<U32>) -> Bytes.Bytes:
  match long:
    case True{}:
      enc.main(nl, t, mode, dl, db, enc.pax(out, pr.record(nb, nl)))
    case False{}:
      enc.main(nl, t, mode, dl, db, (nb, out))

def enc.ok(ok: Bool, nb: Array<U32>, +nl: U32, out: Bytes.Bytes, +t: U32, +mode: U32, +dl: U32, db: Array<U32>) -> Maybe<&1, Bytes.Bytes>:
  match ok:
    case True{}:
      Some{enc.long(U32.is_lt(100, nl), nb, nl, out, t, mode, dl, db)}
    case False{}:
      None{}

# Does an entry fit what is left of the U32 length, with room for the end blocks? Every step checks before it subtracts.
def enc.room(+ol: U32, +dl: U32, +nl: U32, +long: Bool) -> Bool:
  +r0 = (4294967295 - ol : U32)
  +pd = pad(dl)
  +l = rec.len(nl)
  +pl = pad(l)
  +okd = U32.is_le(1536, r0) && (U32.is_le(dl, pd) && U32.is_le(pd, (r0 - 1536 : U32)))
  +r1 = (r0 - 1536 - pd : U32)
  +okl = Bool.not(long) || (U32.is_le(nl, 4294967040) && (U32.is_le(l, pl) && (U32.is_le(512, r1) && U32.is_le(pl, (r1 - 512 : U32)))))
  okd && okl

# A name must be non-empty and hold no NUL, which the header's name field could not keep.
def enc.check(+t: U32, +mode: U32, +dl: U32, db: Array<U32>, out: Bytes.Bytes, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Bytes.Bytes>:
  Bytes.Bytes{+ol, ob} = out
  (name, +m) = r
  Bytes.Bytes{+nl, nb} = name
  +fits = enc.room(ol, dl, nl, U32.is_lt(100, nl))
  enc.ok(U32.is_ne(nl, 0) && (Maybe.is_none(&2, U32, m) && fits), nb, nl, Bytes.Bytes{ol, ob}, t, mode, dl, db)

def enc(e: Entry, out: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  match e:
    case File{name, data}:
      Bytes.Bytes{+dl, db} = data
      enc.check(48, 420, dl, db, out, Bytes.find(name, "\u{0}"))
    case Dir{name}:
      enc.check(53, 493, 0, Bytes.alloc(0), out, Bytes.find(name, "\u{0}"))

def enc.end(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case Some{out}:
      Some{zeros(out, 1024)}
    case None{}:
      None{}

def enc.go(xs: List<&1, Entry>, m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      enc.end(m)
    case Con{e, t}:
      match m:
        case Some{out}:
          enc.go(t, enc(e, out))
        case None{}:
          None{}

# A POSIX ustar archive of the entries in order, ended by two zero blocks. Files are mode 0644 and
# directories 0755, with uid, gid, and mtime 0. A name over 100 bytes goes in a PAX path record.
# None when a name is empty or holds a NUL byte, or when the archive would pass 4 GiB (U32 lengths).
# ustar's 8 GiB size field holds any U32 length, so encode never needs a PAX size.
def encode(entries: List<&1, Entry>) -> Maybe<&1, Bytes.Bytes>:
  enc.go(entries, Some{Bytes.new(0)})
