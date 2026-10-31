# DEFLATE, gzip, and zlib encoding and decoding (RFC 1951, 1952, 1950) over Bytes, plus gzip, zstd, and brotli through the C libraries. Source: https://github.com/paymog/bend-kit/tree/main/zlib
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-bits@0.1.0.1/bits.bend as Bits
import bend-kit-hash@0.3.0.2/hash.bend as Hash

def bits(+n: U32) -> Nat:
  U32.to_nat(n)

# Bit reader. bad: a read ran past the end, so the input was cut short.
type Br is Type:
  Br{r: Bits.Reader, bad: Bool}

def br.got(+bad: Bool, rm: Bits.Reader & Maybe<&2, U32>) -> Br & U32:
  (r, m) = rm
  match m:
    case None{}:
      (Br{r, True{}}, 0)
    case Some{v}:
      (Br{r, bad}, v)

def br.take(b: Br, +n: U32) -> Br & U32:
  Br{r, +bad} = b
  br.got(bad, Bits.Reader.lsb(r, n))

# No code: 9999, never a symbol.
def br.sym.got(+bad: Bool, r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> Bits.Huff & Br & U32:
  (h, rd, m) = r
  match m:
    case None{}:
      (h, Br{rd, True{}}, 9999)
    case Some{v}:
      (h, Br{rd, bad}, v)

def br.sym(h: Bits.Huff, b: Br) -> Bits.Huff & Br & U32:
  Br{r, +bad} = b
  br.sym.got(bad, Bits.Huff.decode(h, r))

# RFC 1951 §3.2.4: a stored block starts on a byte boundary.
def br.align(b: Br) -> Br:
  Br{r, bad} = b
  Br{Bits.Reader.align(r), bad}

def nth(xs: List<&2, U32>, +i: U32) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{h, t}:
      Bool.pick(U32, U32.is_zero(i), h, nth(t, (i - 1 : U32)))

def rep(k: Nat, +v: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+p:
      rep(p, v, Con{v, acc})

def take.n(k: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      Nil{}
    case 1n+p:
      match xs:
        case Nil{}:
          Nil{}
        case Con{h, t}:
          Con{h, take.n(p, t)}

def drop.n(k: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      xs
    case 1n+p:
      match xs:
        case Nil{}:
          Nil{}
        case Con{h, t}:
          drop.n(p, t)

# RFC 1951 §3.2.5
def len.base() -> List<&2, U32>:
  [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]

def len.extra() -> List<&2, U32>:
  [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]

def dist.base() -> List<&2, U32>:
  [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]

def dist.extra() -> List<&2, U32>:
  [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]

# RFC 1951 §3.2.6
def fixed.lit() -> Maybe<&1, Bits.Huff>:
  Bits.Huff.from_lens(False{}, rep(144n, 8, rep(112n, 9, rep(24n, 7, rep(8n, 8, Nil{})))))

def fixed.dist() -> Maybe<&1, Bits.Huff>:
  Bits.Huff.from_lens(False{}, rep(30n, 5, Nil{}))

# Output: 2^dep words of packed bytes, n of them written. Matches copy from the output itself.
type Out is Type:
  Out{buf: Array<U32>, dep: U32, n: U32}

def out.fits(+dep: U32, +want: U32) -> Bool:
  U32.is_le(want, U32.shln(4, bits(dep)))

def out.dep(f: Nat, fits: Bool, +dep: U32, +want: U32) -> U32:
  match f:
    case 0n:
      dep
    case 1n+p:
      match fits:
        case True{}:
          dep
        case False{}:
          +d = (dep + 1 : U32)
          out.dep(p, out.fits(d, want), d, want)

def out.grow(fits: Bool, o: Out, +want: U32) -> Out:
  match fits:
    case True{}:
      o
    case False{}:
      Out{buf, +dep, +n} = o
      +d = out.dep(28n, False{}, dep, want)
      Out{Bytes.dst(Bytes.copy(n, buf, Array.new(U32, bits(d), 0), 0, 0)), d, n}

# The buffer doubles until k more bytes fit, so output is O(total), and it ends as the
# fewest 2^dep words that hold n, as Bytes expects.
def out.room(o: Out, +k: U32) -> Out:
  Out{buf, +dep, +n} = o
  +want = (n + k : U32)
  out.grow(out.fits(dep, want), Out{buf, dep, n}, want)

def out.put(o: Out, +c: U32) -> Out:
  Out{buf, dep, +n} = o
  Out{Bytes.poke(buf, n, c), dep, (n + 1 : U32)}

def out.size(o: Out) -> Out & U32:
  Out{buf, dep, +n} = o
  (Out{buf, dep, n}, n)

def out.bytes(o: Out) -> Bytes.Bytes:
  Out{buf, dep, n} = o
  Bytes.Bytes{n, buf}

type Mo is Type:
  MoHead{}
  MoCodes{lit: Bits.Huff, dist: Bits.Huff}
  MoDone{}
  MoBad{}

type Is is Type:
  Is{br: Br, o: Out, mode: Mo, last: Bool}

def inf.next(last: Bool) -> Mo:
  match last:
    case True{}:
      MoDone{}
    case False{}:
      MoHead{}

def inf.bad(b: Br, o: Out) -> Is:
  Is{b, o, MoBad{}, True{}}

# Stored block (§3.2.4): LEN, then NLEN (its complement), then LEN raw bytes.
def sb.put(bv: Br & U32, o: Out) -> Br & Out:
  (b, +c) = bv
  (b, out.put(o, c))

def sb.go(k: Nat, st: Br & Out) -> Br & Out:
  match k:
    case 0n:
      st
    case 1n+f:
      (b, o) = st
      sb.go(f, sb.put(br.take(b, 8), o))

def sb.done(st: Br & Out, +last: Bool) -> Is:
  (b, o) = st
  Is{b, o, inf.next(last), last}

def sb.ok(ok: Bool, b: Br, +len: U32, o: Out, +last: Bool) -> Is:
  match ok:
    case False{}:
      inf.bad(b, o)
    case True{}:
      sb.done(sb.go(bits(len), (b, out.room(o, len))), last)

def sb.nlen(bv: Br & U32, +len: U32, o: Out, +last: Bool) -> Is:
  (b, +nlen) = bv
  sb.ok(U32.is_eq(U32.xor(len, 65535), nlen), b, len, o, last)

def sb.len(bv: Br & U32, o: Out, +last: Bool) -> Is:
  (b, +len) = bv
  sb.nlen(br.take(b, 16), len, o, last)

def inf.stored(b: Br, o: Out, +last: Bool) -> Is:
  sb.len(br.take(br.align(b), 16), o, last)

# Dynamic block (§3.2.7): code lengths for the code-length code, then the lengths themselves.
# cl.slot[i]: where symbol i's length sits in the order the stream sends them.
def cl.slot() -> List<&2, U32>:
  [3, 17, 15, 13, 11, 9, 7, 5, 4, 6, 8, 10, 12, 14, 16, 18, 0, 1, 2]

def cl.place(xs: List<&2, U32>, +vals: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+i, t}:
      Con{nth(vals, i), cl.place(t, vals)}

def cl.push(bv: Br & U32, acc: List<&2, U32>) -> Br & List<&2, U32>:
  (b, v) = bv
  (b, Con{v, acc})

def cl.one(st: Br & List<&2, U32>) -> Br & List<&2, U32>:
  (b, acc) = st
  cl.push(br.take(b, 3), acc)

def cl.read(k: Nat, st: Br & List<&2, U32>) -> Br & List<&2, U32>:
  match k:
    case 0n:
      st
    case 1n+f:
      cl.read(f, cl.one(st))

# The code-length code, lengths so far (reversed), how many, the last one (for code 16), and whether it went wrong.
type Cd is Type:
  Cd{h: Bits.Huff, br: Br, acc: List<&2, U32>, n: U32, prev: U32, bad: Bool}

def cd.fill(over: Bool, h: Bits.Huff, b: Br, acc: List<&2, U32>, +n: U32, +v: U32, +cnt: U32) -> Cd:
  match over:
    case True{}:
      Cd{h, b, acc, n, v, True{}}
    case False{}:
      Cd{h, b, rep(bits(cnt), v, acc), (n + cnt : U32), v, False{}}

def cd.rep(h: Bits.Huff, bv: Br & U32, +v: U32, +base: U32, acc: List<&2, U32>, +n: U32, +total: U32) -> Cd:
  (b, +e) = bv
  +cnt = (base + e : U32)
  cd.fill(U32.is_lt(total, (n + cnt : U32)), h, b, acc, n, v, cnt)

def cd.prev(ok: Bool, h: Bits.Huff, b: Br, acc: List<&2, U32>, +n: U32, +prev: U32, +total: U32) -> Cd:
  match ok:
    case False{}:
      Cd{h, b, acc, n, prev, True{}}
    case True{}:
      cd.rep(h, br.take(b, 2), prev, 3, acc, n, total)

def cd.z18(ok: Bool, h: Bits.Huff, b: Br, acc: List<&2, U32>, +n: U32, +total: U32) -> Cd:
  match ok:
    case True{}:
      cd.rep(h, br.take(b, 7), 0, 11, acc, n, total)
    case False{}:
      Cd{h, b, acc, n, 0, True{}}

def cd.z17(ok: Bool, h: Bits.Huff, b: Br, acc: List<&2, U32>, +n: U32, +s: U32, +total: U32) -> Cd:
  match ok:
    case True{}:
      cd.rep(h, br.take(b, 3), 0, 3, acc, n, total)
    case False{}:
      cd.z18(U32.is_eq(s, 18), h, b, acc, n, total)

def cd.c16(ok: Bool, h: Bits.Huff, b: Br, acc: List<&2, U32>, +n: U32, +prev: U32, +s: U32, +total: U32) -> Cd:
  match ok:
    case True{}:
      cd.prev(U32.is_lt(0, n), h, b, acc, n, prev, total)
    case False{}:
      cd.z17(U32.is_eq(s, 17), h, b, acc, n, s, total)

def cd.lit(ok: Bool, h: Bits.Huff, b: Br, acc: List<&2, U32>, +n: U32, +prev: U32, +s: U32, +total: U32) -> Cd:
  match ok:
    case True{}:
      Cd{h, b, Con{s, acc}, (n + 1 : U32), s, False{}}
    case False{}:
      cd.c16(U32.is_eq(s, 16), h, b, acc, n, prev, s, total)

# A + binder in a nested tuple does not check (bendlang/bend#1077), so a helper takes it.
def cd.sym.at(h: Bits.Huff, b: Br, +s: U32, acc: List<&2, U32>, +n: U32, +prev: U32, +total: U32) -> Cd:
  cd.lit(U32.is_lt(s, 16), h, b, acc, n, prev, s, total)

def cd.sym(r: Bits.Huff & Br & U32, acc: List<&2, U32>, +n: U32, +prev: U32, +total: U32) -> Cd:
  (h, b, s) = r
  cd.sym.at(h, b, s, acc, n, prev, total)

def cd.step(stop: Bool, h: Bits.Huff, b: Br, acc: List<&2, U32>, +n: U32, +prev: U32, +bad: Bool, +total: U32) -> Cd:
  match stop:
    case True{}:
      Cd{h, b, acc, n, prev, bad}
    case False{}:
      cd.sym(br.sym(h, b), acc, n, prev, total)

# Each step adds at least one length, so total steps suffice.
def cd.go(k: Nat, +total: U32, st: Cd) -> Cd:
  match k:
    case 0n:
      st
    case 1n+f:
      Cd{h, b, acc, +n, +prev, +bad} = st
      cd.go(f, total, cd.step(Bool.or(bad, U32.is_le(total, n)), h, b, acc, n, prev, bad, total))

def dyn.dist(lit: Bits.Huff, m: Maybe<&1, Bits.Huff>) -> Mo:
  match m:
    case None{}:
      MoBad{}
    case Some{dist}:
      MoCodes{lit, dist}

def dyn.mo(l: Maybe<&1, Bits.Huff>, d: Maybe<&1, Bits.Huff>) -> Mo:
  match l:
    case None{}:
      MoBad{}
    case Some{lit}:
      dyn.dist(lit, d)

def dyn.tables(bad: Bool, b: Br, +lens: List<&2, U32>, +hlit: U32) -> Br & Mo:
  match bad:
    case True{}:
      (b, MoBad{})
    case False{}:
      (b, dyn.mo(Bits.Huff.from_lens(False{}, take.n(bits(hlit), lens)), Bits.Huff.from_lens(False{}, drop.n(bits(hlit), lens))))

def dyn.done(st: Cd, +hlit: U32, +total: U32) -> Br & Mo:
  Cd{h, b, acc, +n, prev, +bad} = st
  dyn.tables(Bool.or(bad, Bool.not(U32.is_eq(n, total))), b, List.reverse(&2, U32, acc), hlit)

def dyn.cl(m: Maybe<&1, Bits.Huff>, b: Br, +hlit: U32, +total: U32) -> Br & Mo:
  match m:
    case None{}:
      (b, MoBad{})
    case Some{h}:
      dyn.done(cd.go(bits(total), total, Cd{h, b, Nil{}, 0, 0, False{}}), hlit, total)

def dyn.lens(st: Br & List<&2, U32>, +hlit: U32, +hdist: U32) -> Br & Mo:
  (b, acc) = st
  dyn.cl(Bits.Huff.from_lens(False{}, cl.place(cl.slot(), List.reverse(&2, U32, acc))), b, hlit, (hlit + hdist : U32))

def dyn.clen(bv: Br & U32, +hlit: U32, +hdist: U32) -> Br & Mo:
  (b, +hclen) = bv
  dyn.lens(cl.read(bits((hclen + 4 : U32)), (b, Nil{})), hlit, hdist)

def dyn.hdist(bv: Br & U32, +hlit: U32) -> Br & Mo:
  (b, +hd) = bv
  dyn.clen(br.take(b, 4), hlit, (hd + 1 : U32))

def dyn.hlit(bv: Br & U32) -> Br & Mo:
  (b, +hl) = bv
  dyn.hdist(br.take(b, 5), (hl + 257 : U32))

def dyn.read(b: Br) -> Br & Mo:
  dyn.hlit(br.take(b, 5))

# A match copies len bytes from d back in the output, one at a time, so it may overlap itself.
# ponytail: byte-at-a-time copy; use Bytes.copy when d >= len if long matches dominate.
def cp.of(+dep: U32, +n: U32, r: Array<U32> & U32) -> Out:
  (a, +c) = r
  Out{Bytes.poke(a, n, c), dep, (n + 1 : U32)}

def cp.one(+d: U32, o: Out) -> Out:
  Out{buf, +dep, +n} = o
  cp.of(dep, n, Bytes.peek(buf, (n - d : U32)))

def cp.go(k: Nat, +d: U32, o: Out) -> Out:
  match k:
    case 0n:
      o
    case 1n+f:
      cp.go(f, d, cp.one(d, o))

# RFC 1951 §3.2.5: a distance may not reach before the first byte out.
def inf.far(ok: Bool, lit: Bits.Huff, dist: Bits.Huff, b: Br, +len: U32, +d: U32, o: Out, +last: Bool) -> Is:
  match ok:
    case False{}:
      inf.bad(b, o)
    case True{}:
      Is{b, cp.go(bits(len), d, out.room(o, len)), MoCodes{lit, dist}, last}

def inf.dn(lit: Bits.Huff, dist: Bits.Huff, b: Br, +len: U32, +d: U32, r: Out & U32, +last: Bool) -> Is:
  (o, +n) = r
  inf.far(U32.is_le(d, n), lit, dist, b, len, d, o, last)

def inf.dx(bv: Br & U32, +db: U32, +len: U32, lit: Bits.Huff, dist: Bits.Huff, o: Out, +last: Bool) -> Is:
  (b, +e) = bv
  inf.dn(lit, dist, b, len, (db + e : U32), out.size(o), last)

def inf.ds(ok: Bool, lit: Bits.Huff, dist: Bits.Huff, b: Br, +ds: U32, +len: U32, o: Out, +last: Bool) -> Is:
  match ok:
    case False{}:
      inf.bad(b, o)
    case True{}:
      inf.dx(br.take(b, nth(dist.extra(), ds)), nth(dist.base(), ds), len, lit, dist, o, last)

# A + binder in a nested tuple does not check (bendlang/bend#1077), so a helper takes it.
def inf.d.at(dist: Bits.Huff, b: Br, +ds: U32, +len: U32, lit: Bits.Huff, o: Out, +last: Bool) -> Is:
  inf.ds(U32.is_lt(ds, 30), lit, dist, b, ds, len, o, last)

def inf.d(r: Bits.Huff & Br & U32, +len: U32, lit: Bits.Huff, o: Out, +last: Bool) -> Is:
  (dist, b, ds) = r
  inf.d.at(dist, b, ds, len, lit, o, last)

def inf.lx(bv: Br & U32, +lb: U32, lit: Bits.Huff, dist: Bits.Huff, o: Out, +last: Bool) -> Is:
  (b, +e) = bv
  inf.d(br.sym(dist, b), (lb + e : U32), lit, o, last)

def inf.ls(ok: Bool, lit: Bits.Huff, dist: Bits.Huff, b: Br, +s: U32, o: Out, +last: Bool) -> Is:
  match ok:
    case False{}:
      inf.bad(b, o)
    case True{}:
      +i = (s - 257 : U32)
      inf.lx(br.take(b, nth(len.extra(), i)), nth(len.base(), i), lit, dist, o, last)

def inf.end(eob: Bool, lit: Bits.Huff, dist: Bits.Huff, b: Br, +s: U32, o: Out, +last: Bool) -> Is:
  match eob:
    case True{}:
      Is{b, o, inf.next(last), last}
    case False{}:
      inf.ls(U32.is_le(s, 285), lit, dist, b, s, o, last)

def inf.lit(ok: Bool, lit: Bits.Huff, dist: Bits.Huff, b: Br, +s: U32, o: Out, +last: Bool) -> Is:
  match ok:
    case True{}:
      Is{b, out.put(out.room(o, 1), s), MoCodes{lit, dist}, last}
    case False{}:
      inf.end(U32.is_eq(s, 256), lit, dist, b, s, o, last)

# A + binder in a nested tuple does not check (bendlang/bend#1077), so a helper takes it.
def inf.sym.at(lit: Bits.Huff, b: Br, +s: U32, dist: Bits.Huff, o: Out, +last: Bool) -> Is:
  inf.lit(U32.is_lt(s, 256), lit, dist, b, s, o, last)

def inf.sym(r: Bits.Huff & Br & U32, dist: Bits.Huff, o: Out, +last: Bool) -> Is:
  (lit, b, s) = r
  inf.sym.at(lit, b, s, dist, o, last)

def inf.dyn(bm: Br & Mo, o: Out, +last: Bool) -> Is:
  (b, m) = bm
  Is{b, o, m, last}

def inf.t2(is2: Bool, b: Br, o: Out, +last: Bool) -> Is:
  match is2:
    case True{}:
      inf.dyn(dyn.read(b), o, last)
    case False{}:
      inf.bad(b, o)

def inf.t1(is1: Bool, b: Br, o: Out, +last: Bool, +t: U32) -> Is:
  match is1:
    case True{}:
      Is{b, o, dyn.mo(fixed.lit(), fixed.dist()), last}
    case False{}:
      inf.t2(U32.is_eq(t, 2), b, o, last)

def inf.t0(is0: Bool, b: Br, o: Out, +last: Bool, +t: U32) -> Is:
  match is0:
    case True{}:
      inf.stored(b, o, last)
    case False{}:
      inf.t1(U32.is_eq(t, 1), b, o, last, t)

# §3.2.3: BFINAL, then BTYPE.
def inf.head(bv: Br & U32, o: Out) -> Is:
  (b, +v) = bv
  +t = U32.shr(v)
  inf.t0(U32.is_zero(t), b, o, U32.is_eq(U32.and(v, 1), 1), t)

# Every step reads at least one bit or fails, so 8 steps per input byte always finish a valid stream.
def inf.go(k: Nat, st: Is) -> Is:
  match k:
    case 0n:
      st
    case 1n+f:
      Is{b, o, mode, +last} = st
      match mode:
        case MoHead{}:
          inf.go(f, inf.head(br.take(b, 3), o))
        case MoCodes{lit, dist}:
          inf.go(f, inf.sym(br.sym(lit, b), dist, o, last))
        case MoDone{}:
          Is{b, o, MoDone{}, last}
        case MoBad{}:
          Is{b, o, MoBad{}, last}

# out: the bytes; src: the input back; at: the first byte after the stream.
type Inflated is Type:
  Inflated{out: Bytes.Bytes, src: Bytes.Bytes, at: U32}

def inf.done(r: Bytes.Bytes & U32, o: Out) -> Maybe<&1, Inflated>:
  (src, +pos) = r
  Some{Inflated{out.bytes(o), src, ((pos + 7) >> 3n : U32)}}

def inf.fin(b: Br, o: Out) -> Maybe<&1, Inflated>:
  Br{r, bad} = b
  match bad:
    case True{}:
      None{}
    case False{}:
      inf.done(Bits.Reader.finish(r), o)

def inf.result(st: Is) -> Maybe<&1, Inflated>:
  Is{b, o, mode, last} = st
  match mode:
    case MoDone{}:
      inf.fin(b, o)
    case MoHead{}:
      None{}
    case MoCodes{l, d}:
      None{}
    case MoBad{}:
      None{}

def inf.start(ok: Bool, +len: U32, buf: Array<U32>, +at: U32) -> Maybe<&1, Inflated>:
  match ok:
    case False{}:
      None{}
    case True{}:
      +fuel = Nat.add(Nat.mul(bits((len - at : U32)), 8n), 8n)
      inf.result(inf.go(fuel, Is{Br{Bits.Reader{len, buf, (at << 3n : U32)}, False{}}, Out{Array.new(U32, 0n, 0), 0, 0}, MoHead{}, False{}}))

# A raw DEFLATE stream that starts at byte at.
def inflate.at(b: Bytes.Bytes, +at: U32) -> Maybe<&1, Inflated>:
  Bytes.Bytes{+len, buf} = b
  inf.start(U32.is_le(at, len), len, buf, at)

def inflate.out(m: Maybe<&1, Inflated>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{Inflated{out, src, at}}:
      Some{out}

# Raw DEFLATE. None: malformed or cut short.
def inflate(b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  inflate.out(inflate.at(b, 0))

def holds(m: Maybe<&2, U32>, +v: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+x}:
      U32.is_eq(x, v)

def keep(ok: Bool, b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  match ok:
    case True{}:
      Some{b}
    case False{}:
      None{}

def flag(+f: U32, +bit: U32) -> Bool:
  Bool.not(U32.is_zero(U32.and(f, bit)))

# RFC 1952 §2.3: after the fixed 10 bytes, optional FEXTRA, FNAME, FCOMMENT, FHCRC.
# Each step takes the buffer and the offset so far; None once a field runs past the end.
def gz.xlen(+off: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Maybe<&2, U32>:
  (b, m) = r
  match m:
    case None{}:
      (b, None{})
    case Some{+x}:
      (b, Some{(off + 2 + x : U32)})

def gz.fextra.at(m: Maybe<&2, U32>, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, U32>:
  match m:
    case None{}:
      (b, None{})
    case Some{+off}:
      gz.xlen(off, Bytes.get.u16le(b, off))

def gz.fextra(on: Bool, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Maybe<&2, U32>:
  match on:
    case False{}:
      r
    case True{}:
      (b, m) = r
      gz.fextra.at(m, b)

def gz.zero(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Maybe<&2, U32>:
  (b, m) = r
  match m:
    case None{}:
      (b, None{})
    case Some{+i}:
      (b, Some{(i + 1 : U32)})

def gz.fstr.at(m: Maybe<&2, U32>, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, U32>:
  match m:
    case None{}:
      (b, None{})
    case Some{+off}:
      gz.zero(Bytes.find.from(b, SCon{Chr{0}, SNil{}}, off))

# A zero-terminated FNAME or FCOMMENT.
def gz.fstr(on: Bool, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Maybe<&2, U32>:
  match on:
    case False{}:
      r
    case True{}:
      (b, m) = r
      gz.fstr.at(m, b)

def gz.fhcrc.at(m: Maybe<&2, U32>, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, U32>:
  match m:
    case None{}:
      (b, None{})
    case Some{+off}:
      (b, Some{(off + 2 : U32)})

def gz.fhcrc(on: Bool, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Maybe<&2, U32>:
  match on:
    case False{}:
      r
    case True{}:
      (b, m) = r
      gz.fhcrc.at(m, b)

# One member's output, the input back, and the first byte after its trailer.
type Member is Type:
  Member{out: Bytes.Bytes, src: Bytes.Bytes, next: U32}

def gz.keep(ok: Bool, out: Bytes.Bytes, src: Bytes.Bytes, +next: U32) -> Maybe<&1, Member>:
  match ok:
    case True{}:
      Some{Member{out, src, next}}
    case False{}:
      None{}

def gz.isize(+ok: Bool, +n: U32, +next: U32, out: Bytes.Bytes, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Member>:
  (src, z) = r
  gz.keep(Bool.and(ok, holds(z, n)), out, src, next)

def gz.crc(r: Bytes.Bytes & U32, +n: U32, +at: U32, c: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Member>:
  (out, +crc) = r
  (src, m) = c
  gz.isize(holds(m, crc), n, (at + 8 : U32), out, Bytes.get.u32le(src, (at + 4 : U32)))

def gz.trail(m: Maybe<&1, Inflated>) -> Maybe<&1, Member>:
  match m:
    case None{}:
      None{}
    case Some{Inflated{out, src, +at}}:
      Bytes.Bytes{+n, buf} = out
      gz.crc(Hash.crc32(Bytes.Bytes{n, buf}), n, at, Bytes.get.u32le(src, at))

def gz.body(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Member>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{+off}:
      gz.trail(inflate.at(b, off))

def gz.flags(+f: U32, +p: U32, b: Bytes.Bytes) -> Maybe<&1, Member>:
  gz.body(gz.fhcrc(flag(f, 2), gz.fstr(flag(f, 16), gz.fstr(flag(f, 8), gz.fextra(flag(f, 4), (b, Some{(p + 10 : U32)}))))))

def gz.magic(ok: Bool, +f: U32, +p: U32, b: Bytes.Bytes) -> Maybe<&1, Member>:
  match ok:
    case True{}:
      gz.flags(f, p, b)
    case False{}:
      None{}

# ID1 31, ID2 139, CM 8 (DEFLATE), then FLG.
def gz.head(+p: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Member>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{+w}:
      gz.magic(U32.is_eq(U32.and(w, 16777215), 559903), U32.shrn(w, 24n), p, b)

# The member that starts at byte p.
def gz.member(b: Bytes.Bytes, +p: U32) -> Maybe<&1, Member>:
  gz.head(p, Bytes.get.u32le(b, p))

# RFC 1952 §2.2: members follow each other until the input ends.
type Gz is Type:
  GzMore{acc: Bytes.Bytes, src: Bytes.Bytes, at: U32}
  GzDone{out: Bytes.Bytes}
  GzBad{}

def gz.more(more: Bool, acc: Bytes.Bytes, src: Bytes.Bytes, +at: U32) -> Gz:
  match more:
    case True{}:
      GzMore{acc, src, at}
    case False{}:
      GzDone{acc}

def gz.step(m: Maybe<&1, Member>, acc: Bytes.Bytes) -> Gz:
  match m:
    case None{}:
      GzBad{}
    case Some{Member{out, src, +next}}:
      Bytes.Bytes{+len, buf} = src
      gz.more(U32.is_lt(next, len), Bytes.append(acc, out), Bytes.Bytes{len, buf}, next)

# Each member takes at least 18 bytes, so one step per byte suffices.
def gz.go(k: Nat, st: Gz) -> Maybe<&1, Bytes.Bytes>:
  match k:
    case 0n:
      None{}
    case 1n+f:
      match st:
        case GzMore{acc, src, +at}:
          gz.go(f, gz.step(gz.member(src, at), acc))
        case GzDone{out}:
          Some{out}
        case GzBad{}:
          None{}

# Every gzip member, concatenated; each CRC-32 and ISIZE must match. None: malformed, cut short, corrupt, or junk after a member.
def gunzip(b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  Bytes.Bytes{+len, buf} = b
  gz.go(Nat.add(bits(len), 1n), GzMore{Bytes.Bytes{0, Array.new(U32, 0n, 0)}, Bytes.Bytes{len, buf}, 0})

# RFC 1950: CMF and FLG, then DEFLATE, then Adler-32, big-endian.
def zl.sum(r: Bytes.Bytes & U32, c: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Bytes.Bytes>:
  (out, +a) = r
  (src, m) = c
  keep(holds(m, a), out)

def zl.trail(m: Maybe<&1, Inflated>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{Inflated{out, src, +at}}:
      zl.sum(Hash.adler32(out), Bytes.get.u32be(src, at))

def zl.ok(+cmf: U32, +flg: U32) -> Bool:
  Bool.and(Bool.and(U32.is_eq(U32.and(cmf, 15), 8), U32.is_le(U32.shrn(cmf, 4n), 7)), Bool.and(U32.is_zero(U32.mod((cmf * 256 + flg : U32), 31)), Bool.not(flag(flg, 32))))

def zl.go(ok: Bool, b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  match ok:
    case True{}:
      zl.trail(inflate.at(b, 2))
    case False{}:
      None{}

def zl.head(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Bytes.Bytes>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{+h}:
      zl.go(zl.ok(U32.shrn(h, 8n), U32.and(h, 255)), b)

def unzlib(b: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  zl.head(Bytes.get.u16be(b, 0))

# DEFLATE encoding: LZ77 over hash chains, then one final fixed-Huffman block (RFC 1951 §3.2.6).
# ponytail: fixed Huffman only; dynamic trees would cut text output further.

def bw.code(w: Bits.Writer, cl: U32 & U32) -> Bits.Writer:
  (+c, +l) = cl
  Bits.Writer.lsb(w, l, Bits.rev(bits(l), c, 0))

# RFC 1951 §3.2.6: the fixed code of literal/length symbol s, and its length.
def fx.hi(+s: U32, lo: Bool) -> U32 & U32:
  match lo:
    case True{}:
      ((s - 256 : U32), 7)
    case False{}:
      ((s - 88 : U32), 8)

def fx.mid(+s: U32, lo: Bool) -> U32 & U32:
  match lo:
    case True{}:
      ((s + 256 : U32), 9)
    case False{}:
      fx.hi(s, U32.is_lt(s, 280))

def fx.low(+s: U32, lo: Bool) -> U32 & U32:
  match lo:
    case True{}:
      ((s + 48 : U32), 8)
    case False{}:
      fx.mid(s, U32.is_lt(s, 256))

def fx.lit(+s: U32) -> U32 & U32:
  fx.low(s, U32.is_lt(s, 144))

# The last index whose base is at most v, with that base and its extra-bit count; bases ascend.
type Cx is Data:
  Cx{i: U32, base: U32, extra: U32}

def cx.go(bs: List<&2, U32>, es: List<&2, U32>, +v: U32, +i: U32, +best: Cx) -> Cx:
  match bs:
    case Nil{}:
      best
    case Con{+b, bt}:
      match es:
        case Nil{}:
          best
        case Con{+e, et}:
          cx.go(bt, et, v, (i + 1 : U32), Bool.pick(Cx, U32.is_le(b, v), Cx{i, b, e}, best))


def em.len(w: Bits.Writer, +len: U32, c: Cx) -> Bits.Writer:
  Cx{+i, +b, +e} = c
  Bits.Writer.lsb(bw.code(w, fx.lit((i + 257 : U32))), e, (len - b : U32))

def em.dist(w: Bits.Writer, +d: U32, c: Cx) -> Bits.Writer:
  Cx{+i, +b, +e} = c
  Bits.Writer.lsb(Bits.Writer.lsb(w, 5, Bits.rev(5n, i, 0)), e, (d - b : U32))

def em.match(w: Bits.Writer, +len: U32, +d: U32) -> Bits.Writer:
  em.dist(em.len(w, len, cx.go(len.base(), len.extra(), len, 0, Cx{0, 3, 0})), d, cx.go(dist.base(), dist.extra(), d, 0, Cx{0, 1, 0}))

def em.lit(w: Bits.Writer, +c: U32) -> Bits.Writer:
  bw.code(w, fx.lit(c))

# Match finder: the input bytes, packed, the newest position + 1 per hash, and per position the previous one with its hash (0: none).
type Lz is Type:
  Lz{src: Array<U32>, head: Array<U32>, prev: Array<U32>}

def lz.at.of(r: Array<U32> & U32, head: Array<U32>, prev: Array<U32>) -> Lz & U32:
  (src, v) = r
  (Lz{src, head, prev}, v)

def lz.at(z: Lz, +i: U32) -> Lz & U32:
  Lz{src, head, prev} = z
  lz.at.of(Bytes.peek(src, i), head, prev)

def lz.drop(r: Lz & U32) -> Lz:
  (z, v) = r
  z

def lz.h3(r: Lz & U32, +a: U32, +b: U32) -> Lz & U32:
  (z, +c) = r
  (z, U32.and(U32.xor(U32.xor(U32.shln(a, 10n), U32.shln(b, 5n)), c), 32767))

def lz.h2(r: Lz & U32, +i: U32, +a: U32) -> Lz & U32:
  (z, +b) = r
  lz.h3(lz.at(z, (i + 2 : U32)), a, b)

def lz.h1(r: Lz & U32, +i: U32) -> Lz & U32:
  (z, +a) = r
  lz.h2(lz.at(z, (i + 1 : U32)), i, a)

def lz.hash(z: Lz, +i: U32) -> Lz & U32:
  lz.h1(lz.at(z, i), i)

def lz.link(r: Array<U32> & U32, +i: U32, +h: U32, src: Array<U32>, prev: Array<U32>) -> Lz & U32:
  (head, +old) = r
  (Lz{src, Array.set(U32, head, h, (i + 1 : U32)), Array.set(U32, prev, U32.and(i, 32767), old)}, old)

def lz.ins.of(r: Lz & U32, +i: U32) -> Lz & U32:
  (z, +h) = r
  Lz{src, head, prev} = z
  lz.link(Array.get(U32, head, h), i, h, src, prev)

# Links position i into the chain for its next three bytes; answers the chain's previous head.
def lz.insert(z: Lz, +i: U32) -> Lz & U32:
  lz.ins.of(lz.hash(z, i), i)

# Match length: bytes at a + k and b + k compared so far, and whether the last pair was equal.
type Ml is Type:
  Ml{z: Lz, a: U32, b: U32, k: U32, eq: Bool}

def ml.cmp(r: Lz & U32, +a: U32, +b: U32, +k: U32, +x: U32) -> Ml:
  (z, +y) = r
  Ml{z, a, b, (k + 1 : U32), U32.is_eq(x, y)}

def ml.read(r: Lz & U32, +a: U32, +b: U32, +k: U32) -> Ml:
  (z, +x) = r
  ml.cmp(lz.at(z, (b + k : U32)), a, b, k, x)

def ml.len(+k: U32, eq: Bool) -> U32:
  match eq:
    case True{}:
      k
    case False{}:
      (k - 1 : U32)

# Counts equal bytes from a and from b, up to fuel.
def ml.go(fuel: Nat, st: Ml) -> Lz & U32:
  match fuel:
    case 0n:
      Ml{z, a, b, +k, eq} = st
      (z, ml.len(k, eq))
    case 1n+f:
      Ml{z, +a, +b, +k, eq} = st
      match eq:
        case True{}:
          ml.go(f, ml.read(lz.at(z, (a + k : U32)), a, b, k))
        case False{}:
          (z, (k - 1 : U32))

# Chain walk at i: candidate c (position + 1), the longest match so far, and whether to go on.
type Ch is Type:
  Ch{z: Lz, i: U32, c: U32, max: U32, blen: U32, bdist: U32, go: Bool}

# RFC 1951 §3.2.5: a distance is at most 32768.
def ch.ok(+i: U32, +c: U32, +max: U32, +blen: U32) -> Bool:
  Bool.and(Bool.and(U32.is_lt(0, c), U32.is_lt((i - c : U32), 32768)), U32.is_lt(blen, max))

def ch.next(r: Array<U32> & U32, src: Array<U32>, head: Array<U32>, +i: U32, +max: U32, +blen: U32, +bdist: U32) -> Ch:
  (prev, +c) = r
  Ch{Lz{src, head, prev}, i, c, max, blen, bdist, ch.ok(i, c, max, blen)}

def ch.best(r: Lz & U32, +i: U32, +p: U32, +max: U32, +blen: U32, +bdist: U32) -> Ch:
  (z, +len) = r
  Lz{src, head, prev} = z
  +more = U32.is_lt(blen, len)
  ch.next(Array.get(U32, prev, U32.and(p, 32767)), src, head, i, max, Bool.pick(U32, more, len, blen), Bool.pick(U32, more, (i - p : U32), bdist))

def ch.go(fuel: Nat, st: Ch) -> Ch:
  match fuel:
    case 0n:
      st
    case 1n+f:
      Ch{z, +i, +c, +max, +blen, +bdist, go} = st
      match go:
        case True{}:
          +p = (c - 1 : U32)
          ch.go(f, ch.best(ml.go(bits(max), Ml{z, i, p, 0, True{}}), i, p, max, blen, bdist))
        case False{}:
          Ch{z, i, c, max, blen, bdist, False{}}

# Encoder: match finder, bit writer, position, input length, and whether bytes are left.
type Es is Type:
  Es{z: Lz, w: Bits.Writer, i: U32, n: U32, more: Bool}

def es.lit.of(r: Lz & U32, w: Bits.Writer, +i: U32, +n: U32) -> Es:
  (z, +c) = r
  +j = (i + 1 : U32)
  Es{z, em.lit(w, c), j, n, U32.is_lt(j, n)}

def es.lit(z: Lz, w: Bits.Writer, +i: U32, +n: U32) -> Es:
  es.lit.of(lz.at(z, i), w, i, n)

def ins.one(ok: Bool, z: Lz, +j: U32) -> Lz:
  match ok:
    case True{}:
      lz.drop(lz.insert(z, j))
    case False{}:
      z

# Positions inside a match join their chains too, when three bytes remain.
def ins.go(k: Nat, z: Lz, +j: U32, +n: U32) -> Lz:
  match k:
    case 0n:
      z
    case 1n+f:
      ins.go(f, ins.one(U32.is_le((j + 3 : U32), n), z, j), (j + 1 : U32), n)

def es.emit(hit: Bool, z: Lz, w: Bits.Writer, +i: U32, +n: U32, +blen: U32, +bdist: U32) -> Es:
  match hit:
    case True{}:
      +j = (i + blen : U32)
      Es{ins.go(bits((blen - 1 : U32)), z, (i + 1 : U32), n), em.match(w, blen, bdist), j, n, U32.is_lt(j, n)}
    case False{}:
      es.lit(z, w, i, n)

def es.pick(st: Ch, w: Bits.Writer, +n: U32) -> Es:
  Ch{z, +i, c, max, +blen, +bdist, go} = st
  es.emit(U32.is_le(3, blen), z, w, i, n, blen, bdist)

# ponytail: greedy parse, 32 chain steps; lazy matching would compress text further.
def es.chain(r: Lz & U32, w: Bits.Writer, +i: U32, +n: U32) -> Es:
  (z, +c) = r
  +room = (n - i : U32)
  +max = Bool.pick(U32, U32.is_lt(room, 258), room, 258)
  es.pick(ch.go(32n, Ch{z, i, c, max, 0, 0, ch.ok(i, c, max, 0)}), w, n)

def es.find(short: Bool, z: Lz, w: Bits.Writer, +i: U32, +n: U32) -> Es:
  match short:
    case True{}:
      es.lit(z, w, i, n)
    case False{}:
      es.chain(lz.insert(z, i), w, i, n)

# Each step consumes at least one byte, so n steps finish.
def es.go(fuel: Nat, st: Es) -> Es:
  match fuel:
    case 0n:
      st
    case 1n+f:
      Es{z, w, +i, +n, more} = st
      match more:
        case True{}:
          es.go(f, es.find(U32.is_lt((n - i : U32), 3), z, w, i, n))
        case False{}:
          Es{z, w, i, n, False{}}

def es.out(st: Es) -> Bits.Writer:
  Es{z, w, i, n, more} = st
  Bits.Writer.align(em.lit(w, 256))

# One final fixed-Huffman block (BFINAL = 1, BTYPE = 01) after what w holds, padded to a byte.
def deflate.into(w: Bits.Writer, b: Bytes.Bytes) -> Bits.Writer:
  Bytes.Bytes{+n, src} = b
  es.out(es.go(bits(n), Es{Lz{src, Array.new(U32, 15n, 0), Array.new(U32, 15n, 0)}, Bits.Writer.lsb(w, 3, 3), 0, n, U32.is_lt(0, n)}))

# Raw DEFLATE.
def deflate(b: Bytes.Bytes) -> Bytes.Bytes:
  Bits.Writer.finish(deflate.into(Bits.Writer.new(), b))

def gz.put(r: Bytes.Bytes & U32) -> Bytes.Bytes:
  (b, +crc) = r
  Bytes.Bytes{+n, buf} = b
  head = Bits.Writer.lsb(Bits.Writer.lsb(Bits.Writer.lsb(Bits.Writer.new(), 32, 559903), 32, 0), 16, 65280)
  Bits.Writer.finish(Bits.Writer.lsb(Bits.Writer.lsb(deflate.into(head, Bytes.Bytes{n, buf}), 32, crc), 32, n))

# One gzip member (RFC 1952): no flags, mtime 0, OS unknown.
def gzip(b: Bytes.Bytes) -> Bytes.Bytes:
  gz.put(Hash.crc32(b))

def zl.put(r: Bytes.Bytes & U32) -> Bytes.Bytes:
  (b, +a) = r
  Bits.Writer.finish(Bits.Writer.lsb(deflate.into(Bits.Writer.lsb(Bits.Writer.new(), 16, 376), b), 32, Bytes.bswap(a)))

# RFC 1950: CMF 0x78 (32 KiB window), FLG 0x01 (fastest), then DEFLATE, then Adler-32, big-endian.
def zlib(b: Bytes.Bytes) -> Bytes.Bytes:
  zl.put(Hash.adler32(b))


# The C libraries, through packed words at the effect boundary. Call the Bytes wrappers below.
def zstd.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def inflate.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def inflate.raw.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def gzip.words(len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def brotli.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def words.got(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(+len, buf)}:
      Done{Bytes.Bytes{len, buf}}

def words.run(~eff: U32 -> U32 -> Array<U32> -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>), max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  Bytes.Bytes{+len, buf} = b
  do IO<Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- eff(max, len, buf)
    return words.got(r)

# gzip, zlib, or raw DEFLATE data through libz, selected from the first two bytes. Every gzip member is decoded in turn, as gzip -d does.
# Each decoder fails with EFBIG when the output passes max bytes, and ENOENT without its library.
def libz.inflate(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~inflate.words, max, b)

# One raw DEFLATE stream through libz. Trailing bytes, truncated input and output above max fail.
def libz.inflate.raw(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~inflate.raw.words, max, b)

# One gzip member at level 6 through libz.
def libz.gzip(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  Bytes.Bytes{+len, buf} = b
  do IO<Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- gzip.words(len, buf)
    return words.got(r)

# Zstandard frames (RFC 8878) through libzstd.
def zstd(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~zstd.words, max, b)

# Brotli (RFC 7932) through libbrotlidec.
def brotli(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~brotli.words, max, b)

# A live native decoder. Call dec.finish even after a failed feed to release it.
type Decoder is Type:
  Decoder{id: U32}

def dec.open(kind: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def dec.new.got(r: Result<&1, &1, U32 & String, U32>) -> Result<&1, &1, U32 & String, Decoder>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{+id}:
      Done{Decoder{id}}

def dec.new(+kind: U32) -> IO(Result<&1, &1, U32 & String, Decoder>):
  do IO<Result<&1, &1, U32 & String, Decoder>>:
    r : Result<&1, &1, U32 & String, U32> <- dec.open(kind)
    return dec.new.got(r)

def inflate.new() -> IO(Result<&1, &1, U32 & String, Decoder>):
  dec.new(0)

def brotli.new() -> IO(Result<&1, &1, U32 & String, Decoder>):
  dec.new(1)

def zstd.new() -> IO(Result<&1, &1, U32 & String, Decoder>):
  dec.new(2)

def dec.feed(id: U32, max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

# The output of one chunk of input. max caps this call, not the total output of the stream.
def dec.push(d: Decoder, max: U32, b: Bytes.Bytes) ->
  IO(Decoder & Result<&1, &1, U32 & String, Bytes.Bytes>):
  Decoder{+id} = d
  Bytes.Bytes{+len, buf} = b
  do IO<Decoder & Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- dec.feed(id, max, len, buf)
    return (Decoder{id}, words.got(r))

def dec.finish.id(id: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

# Finish validates the end marker and always releases the decoder.
def dec.finish(d: Decoder) -> IO(Result<&1, &1, U32 & String, Unit>):
  Decoder{+id} = d
  dec.finish.id(id)
