# tar archives (POSIX ustar with PAX path and size records) of regular files and directories over Bytes. Source: https://github.com/paymog/bend-kit/tree/main/tar
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

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
  Dec{v: U32, digits: U32, stop: U32, ended: Bool, ok: Bool}

type DByte is Data:
  DByte{byte: U32, digit: Bool}

def dec.byte.of(+len: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, DByte>:
  (a, +b) = r
  (Bytes.Bytes{len, a}, Some{DByte{b, Bytes.in(48, b, 57)}})

def dec.byte(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Maybe<&2, DByte>:
  Bytes.Bytes{+len, a} = b
  dec.byte.of(len, Bytes.peek(a, i))

# Consume decimal digits and, when present, their first non-digit delimiter.
def dec.go(n: Nat, r: Bytes.Cursor & Maybe<&2, DByte>, +acc: U32, +digits: U32, +ok: Bool) -> Bytes.Cursor & Dec:
  match n:
    case 0n:
      (c, m) = r
      (c, Dec{acc, digits, 0, True{}, ok})
    case 1n+p:
      (c, m) = r
      match m:
        case None{}:
          (c, Dec{acc, digits, 0, True{}, False{}})
        case Some{DByte{+b, digit}}:
          match digit:
            case False{}:
              (c, Dec{acc, digits, b, False{}, ok})
            case True{}:
              +v = (b - 48 : U32)
              +fit = U32.is_lt(acc, 429496729) || (U32.is_eq(acc, 429496729) && U32.is_le(v, 5))
              dec.go(p, Bytes.Cursor.read(~DByte, ~dec.byte, c, 1), ((acc * 10) + v : U32), (digits + 1 : U32), ok && fit)

def dec.start(r: Bytes.Cursor & U32) -> Bytes.Cursor & Dec:
  (c, +n) = r
  dec.go(U32.to_nat(n), Bytes.Cursor.read(~DByte, ~dec.byte, c, 1), 0, 0, True{})

def dec(c: Bytes.Cursor) -> Bytes.Cursor & Dec:
  dec.start(Bytes.Cursor.remaining(c))

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
  PGo{pax: Pax}
  PEnd{pax: Pax}
  PBad{}

type PKey is Data:
  PPath{}
  PSize{}
  POther{}

def pr.key.size(hit: Bool, +len: U32, a: Array<U32>) -> Bytes.Bytes & Maybe<&2, PKey>:
  match hit:
    case True{}:
      (Bytes.Bytes{len, a}, Some{PSize{}})
    case False{}:
      (Bytes.Bytes{len, a}, Some{POther{}})

def pr.key.sized(+len: U32, r: Array<U32> & Bool) -> Bytes.Bytes & Maybe<&2, PKey>:
  (a, hit) = r
  pr.key.size(hit, len, a)

def pr.key.path(+i: U32, +len: U32, r: Array<U32> & Bool) -> Bytes.Bytes & Maybe<&2, PKey>:
  (a, hit) = r
  match hit:
    case True{}:
      (Bytes.Bytes{len, a}, Some{PPath{}})
    case False{}:
      pr.key.sized(len, Bytes.at(a, "size=", i))

# The cursor bounds both fixed keyword probes; short or unknown bodies are skipped.
def pr.key(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Maybe<&2, PKey>:
  Bytes.Bytes{+len, a} = b
  pr.key.path(i, len, Bytes.at(a, "path=", i))

def pr.opt(has: Bool, b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  match has:
    case True{}:
      Some{b}
    case False{}:
      None{}

# An empty value unsets the keyword, so the header's own name applies.
def pr.path.done(+start: U32, +end: U32, +n: U32, pax: Pax, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Cursor & Pst:
  Pax{old, size} = pax
  (b, value) = r
  (Bytes.Cursor{b, end, start, end}, PGo{Pax{pr.opt(U32.is_ne(n, 0), value), size}})

def pr.path(c: Bytes.Cursor, pax: Pax) -> Bytes.Cursor & Pst:
  Bytes.Cursor{b, +pos, +start, +end} = c
  pr.path.done(start, end, (end - pos : U32), pax, Bytes.slice(b, pos, (end - pos : U32)))

def pr.size.valid(ok: Bool, c: Bytes.Cursor, +v: U32, path: Maybe<&1, Bytes.Bytes>) -> Bytes.Cursor & Pst:
  match ok:
    case True{}:
      (c, PGo{Pax{path, Some{v}}})
    case False{}:
      (c, PBad{})

def pr.size.done(pax: Pax, r: Bytes.Cursor & Dec) -> Bytes.Cursor & Pst:
  Pax{path, old} = pax
  (c, d) = r
  Dec{+v, +digits, stop, +ended, +ok} = d
  pr.size.valid(ok && ended && U32.is_ne(digits, 0), c, v, path)

def pr.checked(r: Bytes.Cursor & Bool, pax: Pax) -> Bytes.Cursor & Pst:
  (c, ok) = r
  match ok:
    case True{}:
      (c, PGo{pax})
    case False{}:
      (c, PBad{})

def pr.skip(c: Bytes.Cursor, pax: Pax) -> Bytes.Cursor & Pst:
  Bytes.Cursor{b, pos, start, +end} = c
  pr.checked(Bytes.Cursor.seek(Bytes.Cursor{b, pos, start, end}, end), pax)

def pr.value(pax: Pax, r: Bytes.Cursor & Maybe<&2, PKey>) -> Bytes.Cursor & Pst:
  (c, key) = r
  match key:
    case None{}:
      pr.skip(c, pax)
    case Some{k}:
      match k:
        case PPath{}:
          pr.path(c, pax)
        case PSize{}:
          pr.size.done(pax, dec(c))
        case POther{}:
          pr.skip(c, pax)

def pr.nl(pax: Pax, r: Bytes.Cursor & Maybe<&2, U32>) -> Bytes.Cursor & Pst:
  (c, m) = r
  match m:
    case None{}:
      (c, PBad{})
    case Some{+b}:
      pr.checked((c, U32.is_eq(b, 10)), pax)

def pr.close(limit: Bytes.CursorLimit, r: Bytes.Cursor & Pst) -> Bytes.Cursor & Pst:
  (c, st) = r
  match st:
    case PGo{pax}:
      pr.nl(pax, Bytes.Cursor.u8(Bytes.Cursor.leave(c, limit)))
    case PEnd{pax}:
      (Bytes.Cursor.leave(c, limit), PBad{})
    case PBad{}:
      (Bytes.Cursor.leave(c, limit), PBad{})

def pr.body(pax: Pax, r: Bytes.Cursor & Maybe<&1, Bytes.CursorLimit>) -> Bytes.Cursor & Pst:
  (c, m) = r
  match m:
    case None{}:
      (c, PBad{})
    case Some{limit}:
      pr.close(limit, pr.value(pax, Bytes.Cursor.read(~PKey, ~pr.key, c, 5)))

def pr.len.valid(ok: Bool, c: Bytes.Cursor, +body: U32, pax: Pax) -> Bytes.Cursor & Pst:
  match ok:
    case False{}:
      (c, PBad{})
    case True{}:
      pr.body(pax, Bytes.Cursor.region(c, body))

# Length includes its digits, the space, the bounded body and its final newline.
def pr.len(+available: U32, pax: Pax, r: Bytes.Cursor & Dec) -> Bytes.Cursor & Pst:
  (c, d) = r
  Dec{+len, +digits, +stop, +ended, +ok} = d
  pr.len.valid(ok && Bool.not(ended) && U32.is_eq(stop, 32) && U32.is_ne(digits, 0) && U32.is_lt((digits + 1 : U32), len) && U32.is_le(len, available), c, (len - digits - 2 : U32), pax)

def pr.more.if(done: Bool, c: Bytes.Cursor, +n: U32, pax: Pax) -> Bytes.Cursor & Pst:
  match done:
    case True{}:
      (c, PEnd{pax})
    case False{}:
      pr.len(n, pax, dec(c))

def pr.more(pax: Pax, r: Bytes.Cursor & U32) -> Bytes.Cursor & Pst:
  (c, +n) = r
  pr.more.if(U32.is_eq(n, 0), c, n, pax)

# Each record consumes at least three bytes; leave fuel for the end transition.
def pr.run(fuel: Nat, r: Bytes.Cursor & Pst) -> Bytes.Cursor & Maybe<&1, Pax>:
  match fuel:
    case 0n:
      (c, st) = r
      (c, None{})
    case 1n+f:
      (c, st) = r
      match st:
        case PGo{pax}:
          pr.run(f, pr.more(pax, Bytes.Cursor.remaining(c)))
        case PEnd{pax}:
          (c, Some{pax})
        case PBad{}:
          (c, None{})

def pr.start(pax: Pax, r: Bytes.Cursor & U32) -> Bytes.Cursor & Maybe<&1, Pax>:
  (c, +n) = r
  pr.run(U32.to_nat(((n >> 1n) + 2 : U32)), (c, PGo{pax}))

# c is already bounded to exactly the PAX payload, without block padding.
def pr.parse(c: Bytes.Cursor, pax: Pax) -> Bytes.Cursor & Maybe<&1, Pax>:
  pr.start(pax, Bytes.Cursor.remaining(c))

type St is Type:
  SHead{pax: Pax, acc: List<&1, Entry>}
  SOk{entries: List<&1, Entry>}
  SFail{}

# Header metadata is Data so a checked read can advance without copying the header.
type Hdr is Data:
  Hdr{sum: U32, ok: Bool, size: U32, size_ok: Bool, kind: U32}

def hdr.kind(+len: U32, +sum: U32, +ok: Bool, +size: U32, +size_ok: Bool, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, Hdr>:
  (a, t) = r
  (Bytes.Bytes{len, a}, Some{Hdr{sum, ok, size, size_ok, t}})

def hdr.size(+len: U32, +i: U32, +sum: U32, +ok: Bool, r: Array<U32> & U32 & Bool) -> Bytes.Bytes & Maybe<&2, Hdr>:
  (a, size, size_ok) = r
  hdr.kind(len, sum, ok, size, size_ok, Bytes.peek(a, (i + 156 : U32)))

def hdr.valid(ok: Bool, +len: U32, +i: U32, +sum: U32, a: Array<U32>) -> Bytes.Bytes & Maybe<&2, Hdr>:
  match ok:
    case True{}:
      hdr.size(len, i, sum, True{}, oct(a, (i + 124 : U32), 12))
    case False{}:
      (Bytes.Bytes{len, a}, Some{Hdr{sum, False{}, 0, False{}, 0}})

# The checksum's eight bytes count as spaces.
def hdr.ck3(+len: U32, +i: U32, +sum: U32, +ck: U32, +ok: Bool, +x: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, Hdr>:
  (a, +w) = r
  hdr.valid(ok && U32.is_eq(ck, (sum - x - wsum(w) + 256 : U32)), len, i, sum, a)

def hdr.ck2(+len: U32, +i: U32, +sum: U32, +ck: U32, +ok: Bool, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, Hdr>:
  (a, +w) = r
  hdr.ck3(len, i, sum, ck, ok, wsum(w), Array.get(U32, a, ((i >> 2n) + 38 : U32)))

def hdr.check(+len: U32, +i: U32, +sum: U32, r: Array<U32> & U32 & Bool) -> Bytes.Bytes & Maybe<&2, Hdr>:
  (a, ck, ok) = r
  hdr.ck2(len, i, sum, ck, ok, Array.get(U32, a, ((i >> 2n) + 37 : U32)))

def hdr.zero(zero: Bool, +len: U32, +i: U32, +sum: U32, a: Array<U32>) -> Bytes.Bytes & Maybe<&2, Hdr>:
  match zero:
    case True{}:
      (Bytes.Bytes{len, a}, Some{Hdr{0, False{}, 0, True{}, 0}})
    case False{}:
      hdr.check(len, i, sum, oct(a, (i + 148 : U32), 8))

def hdr.sum(+len: U32, +i: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, Hdr>:
  (a, +sum) = r
  hdr.zero(U32.is_eq(sum, 0), len, i, sum, a)

# Cursor.read establishes that all fixed offsets below belong to a complete block.
def hdr.read(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Maybe<&2, Hdr>:
  Bytes.Bytes{+len, a} = b
  hdr.sum(len, i, bsum(a, (i >> 2n : U32)))

def zero.sum(+len: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, U32>:
  (a, sum) = r
  (Bytes.Bytes{len, a}, Some{sum})

def zero.read(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Maybe<&2, U32>:
  Bytes.Bytes{+len, a} = b
  zero.sum(len, bsum(a, (i >> 2n : U32)))

def name.of(path: Maybe<&1, Bytes.Bytes>, a: Array<U32>, +i: U32) -> Array<U32> & Bytes.Bytes:
  match path:
    case Some{b}:
      (a, b)
    case None{}:
      header.name(a, i)

def entry.named(+len: U32, +pos: U32, start: U32, end: U32, r: Array<U32> & Bytes.Bytes) -> Bytes.Cursor & Bytes.Bytes:
  (a, name) = r
  (Bytes.Cursor{Bytes.Bytes{len, a}, pos, start, end}, name)

# The header begins one block before the payload cursor; no separate header index survives.
def entry.name(c: Bytes.Cursor, path: Maybe<&1, Bytes.Bytes>) -> Bytes.Cursor & Bytes.Bytes:
  Bytes.Cursor{Bytes.Bytes{+len, a}, +pos, start, end} = c
  entry.named(len, pos, start, end, name.of(path, a, (pos - 512 : U32)))

def file.data(+len: U32, pos: U32, start: U32, end: U32, +size: U32, name: Bytes.Bytes, acc: List<&1, Entry>, r: Array<U32> & Array<U32>) -> Bytes.Cursor & St:
  (a, o) = r
  (Bytes.Cursor{Bytes.Bytes{len, a}, pos, start, end}, SHead{Pax{None{}, None{}}, Con{File{name, Bytes.Bytes{size, o}}, acc}})

def file.name(+size: U32, acc: List<&1, Entry>, r: Bytes.Cursor & Bytes.Bytes) -> Bytes.Cursor & St:
  (c, name) = r
  Bytes.Cursor{Bytes.Bytes{+len, a}, +pos, start, end} = c
  file.data(len, pos, start, end, size, name, acc, Bytes.copy(size, a, Bytes.alloc(size), pos, 0))

def entry.file(c: Bytes.Cursor, +size: U32, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  Pax{path, s} = pax
  file.name(size, acc, entry.name(c, path))

def dir.name(acc: List<&1, Entry>, r: Bytes.Cursor & Bytes.Bytes) -> Bytes.Cursor & St:
  (c, name) = r
  (c, SHead{Pax{None{}, None{}}, Con{Dir{name}, acc}})

# Leaving the payload region skips a directory's data, as it does global PAX records.
def entry.dir(c: Bytes.Cursor, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  Pax{path, s} = pax
  dir.name(acc, entry.name(c, path))

def step.pax(acc: List<&1, Entry>, r: Bytes.Cursor & Maybe<&1, Pax>) -> Bytes.Cursor & St:
  (c, m) = r
  match m:
    case Some{pax}:
      (c, SHead{pax, acc})
    case None{}:
      (c, SFail{})

# '0'/NUL are files, '5' directories, 'x' local PAX and 'g' ignored global PAX.
# Links, devices, FIFOs, GNU extensions and all other types fail.
def step.type(+t: U32, c: Bytes.Cursor, +size: U32, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  match t:
    case 0:
      entry.file(c, size, pax, acc)
    case 48:
      entry.file(c, size, pax, acc)
    case 53:
      entry.dir(c, pax, acc)
    case 120:
      step.pax(acc, pr.parse(c, pax))
    case 103:
      (c, SHead{pax, acc})
    case _:
      (c, SFail{})

def frame.padded(outer: Bytes.CursorLimit, st: St, r: Bytes.Cursor & Bool) -> Bytes.Cursor & St:
  (c, ok) = r
  match ok:
    case True{}:
      (Bytes.Cursor.leave(c, outer), st)
    case False{}:
      (Bytes.Cursor.leave(c, outer), SFail{})

def frame.body(inner: Bytes.CursorLimit, outer: Bytes.CursorLimit, +padding: U32, r: Bytes.Cursor & St) -> Bytes.Cursor & St:
  (c, st) = r
  frame.padded(outer, st, Bytes.Cursor.skip(Bytes.Cursor.leave(c, inner), padding))

def frame.payload(+t: U32, +size: U32, +padding: U32, outer: Bytes.CursorLimit, pax: Pax, acc: List<&1, Entry>, r: Bytes.Cursor & Maybe<&1, Bytes.CursorLimit>) -> Bytes.Cursor & St:
  (c, m) = r
  match m:
    case Some{inner}:
      frame.body(inner, outer, padding, step.type(t, c, size, pax, acc))
    case None{}:
      (Bytes.Cursor.leave(c, outer), SFail{})

# First bound the complete padded body, then restrict PAX to the exact payload.
# Limits are left in reverse order; neither region slices or copies the backing buffer.
def frame.region(+t: U32, +size: U32, +pd: U32, pax: Pax, acc: List<&1, Entry>, r: Bytes.Cursor & Maybe<&1, Bytes.CursorLimit>) -> Bytes.Cursor & St:
  (c, m) = r
  match m:
    case Some{outer}:
      frame.payload(t, size, (pd - size : U32), outer, pax, acc, Bytes.Cursor.region(c, size))
    case None{}:
      (c, SFail{})

def step.fit(ok: Bool, +t: U32, c: Bytes.Cursor, +size: U32, +pd: U32, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  match ok:
    case True{}:
      frame.region(t, size, pd, pax, acc, Bytes.Cursor.region(c, pd))
    case False{}:
      (c, SFail{})

def step.pad(+t: U32, c: Bytes.Cursor, +size: U32, +ok: Bool, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  +pd = pad(size)
  step.fit(ok && U32.is_le(size, pd), t, c, size, pd, pax, acc)

# A pending PAX size overrides the header field for every type, even when that field is malformed.
def step.size(+t: U32, c: Bytes.Cursor, +v: U32, +ok: Bool, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  Pax{path, +psize} = pax
  step.pad(t, c, Maybe.default(&2, U32, psize, v), Maybe.is_some(&2, U32, psize) || ok, Pax{path, psize}, acc)

def step.hdr(ok: Bool, +t: U32, c: Bytes.Cursor, +size: U32, +size_ok: Bool, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  match ok:
    case True{}:
      step.size(t, c, size, size_ok, pax, acc)
    case False{}:
      (c, SFail{})

# Two zero blocks are required and no local PAX records may remain pending.
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

def end.sum(pax: Pax, acc: List<&1, Entry>, r: Bytes.Cursor & Maybe<&2, U32>) -> Bytes.Cursor & St:
  (c, m) = r
  match m:
    case Some{+sum}:
      (c, end.of(U32.is_eq(sum, 0), pax, acc))
    case None{}:
      (c, SFail{})

def step.zero(zero: Bool, +ok: Bool, +size: U32, +size_ok: Bool, +t: U32, c: Bytes.Cursor, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  match zero:
    case True{}:
      end.sum(pax, acc, Bytes.Cursor.read(~U32, ~zero.read, c, 512))
    case False{}:
      step.hdr(ok, t, c, size, size_ok, pax, acc)

def step.read(pax: Pax, acc: List<&1, Entry>, r: Bytes.Cursor & Maybe<&2, Hdr>) -> Bytes.Cursor & St:
  (c, m) = r
  match m:
    case Some{Hdr{+sum, +ok, +size, +size_ok, +t}}:
      step.zero(U32.is_eq(sum, 0), ok, size, size_ok, t, c, pax, acc)
    case None{}:
      (c, SFail{})

def step(c: Bytes.Cursor, pax: Pax, acc: List<&1, Entry>) -> Bytes.Cursor & St:
  step.read(pax, acc, Bytes.Cursor.read(~Hdr, ~hdr.read, c, 512))

def run(fuel: Nat, r: Bytes.Cursor & St) -> Maybe<&1, List<&1, Entry>>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      (c, st) = r
      match st:
        case SOk{xs}:
          Some{xs}
        case SFail{}:
          None{}
        case SHead{pax, acc}:
          run(f, step(c, pax, acc))

# The entries in archive order. None for a bad header checksum, a malformed size or PAX record,
# an entry or its padding cut short, a missing end (two zero blocks), or any type but file,
# directory, and PAX records. Bytes after the end are ignored.
# fuel: each header step eats a block, so len / 512 + 2 steps are enough.
def decode(archive: Bytes.Bytes) -> Maybe<&1, List<&1, Entry>>:
  Bytes.Bytes{+len, buf} = archive
  run(U32.to_nat(((len >> 9n) + 2 : U32)), (Bytes.Cursor.new(Bytes.Bytes{len, buf}), SHead{Pax{None{}, None{}}, Nil{}}))

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
