# CBOR (RFC 8949) values encoded and decoded over Bytes. Source: https://github.com/paymog/bend-kit/tree/main/cbor
import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Raw words preserve CBOR integer and floating-point bit patterns.
type W64 is Data:
  W64{hi: U32, lo: U32}

type Float is Data:
  Half{bits: U32}
  Single{bits: U32}
  Double{bits: W64}

type Simple is Data:
  SFalse{}
  STrue{}
  SNull{}
  SUndefined{}
  Other{value: U32}

type Val is Type:
  UInt{value: W64}
  NInt{value: W64}
  BStr{value: Bytes.Bytes}
  TStr{value: Bytes.Bytes}
  Arr{items: List<&1, Val>}
  Obj{items: List<&1, Val & Val>}
  Tag{number: W64, value: Val}
  Sim{value: Simple}
  Flt{value: Float}

type W is Type:
  W{buf: Array<U32>, cap: U32, n: U32, word: U32}
def grow.if(grow: Bool, buf: Array<U32>, +k: U32) -> Array<U32>:
  match grow:
    case True{}:
      Bytes.grow((k * 4 : U32), buf, (k * 8 : U32))
    case False{}:
      buf


def put(full: Bool, buf: Array<U32>, +cap: U32, +n: U32, +word: U32) -> W:
  match full:
    case True{}:
      +k = (n >> 2n : U32)
      +grow = U32.is_eq(k, cap)
      +cap2 = Bool.pick(U32, grow, (cap * 2 : U32), cap)
      W{Array.set(U32, grow.if(grow, buf, k), k, word), cap2, (n + 1 : U32), 0}
    case False{}:
      W{buf, cap, (n + 1 : U32), word}
def finish.buf(full: Bool, cap: U32, buf: Array<U32>, +k: U32, +r: U32, +word: U32) -> Array<U32>:
  match full:
    case True{}:
      +grow = U32.is_eq(k, cap)
      Bytes.flush(True{}, grow.if(grow, buf, k), k, U32.shrn(word, U32.to_nat(((4 - r) * 8 : U32))))
    case False{}:
      buf


def byte(o: W, +b: U32) -> W:
  W{buf, +cap, +n, +word} = o
  +w = ((word >> 8n) .|. (b << 24n) : U32)
  put(U32.is_eq((n .&. 3 : U32), 3), buf, cap, n, w)

def finish(o: W) -> Bytes.Bytes:
  W{buf, cap, +n, +word} = o
  +r = (n .&. 3 : U32)
  +k = (n >> 2n : U32)
  +full = U32.is_ne(r, 0)
  Bytes.Bytes{n, finish.buf(full, cap, buf, k, r, word)}
def empty() -> W:
  W{Bytes.alloc(0), 1, 0, 0}

def head.small(+major: U32, +v: U32, o: W) -> W:
  byte(o, ((major << 5n) .|. v : U32))

def head.u32.sixteen(fits: Bool, +major: U32, +v: U32, o: W) -> W:
  match fits:
    case True{}:
      byte(byte(byte(o, ((major << 5n) .|. 25 : U32)), (v >> 8n : U32)), v)
    case False{}:
      byte(byte(byte(byte(byte(o, ((major << 5n) .|. 26 : U32)), (v >> 24n : U32)), (v >> 16n : U32)), (v >> 8n : U32)), v)

def head.u32.eight(fits: Bool, +major: U32, +v: U32, o: W) -> W:
  match fits:
    case True{}:
      byte(byte(o, ((major << 5n) .|. 24 : U32)), v)
    case False{}:
      head.u32.sixteen(U32.is_le(v, 65535), major, v, o)

def head.u32.small(small: Bool, +major: U32, +v: U32, o: W) -> W:
  match small:
    case True{}:
      head.small(major, v, o)
    case False{}:
      head.u32.eight(U32.is_le(v, 255), major, v, o)
def head.u32(+major: U32, +v: U32, o: W) -> W:
  head.u32.small(U32.is_lt(v, 24), major, v, o)

def raw.u32(o: W, +v: U32) -> W:
  byte(byte(byte(byte(o, (v >> 24n : U32)), (v >> 16n : U32)), (v >> 8n : U32)), v)

def uint.bytes.small(small: Bool, +major: U32, +hi: U32, +lo: U32, o: W) -> W:
  match small:
    case True{}:
      head.u32(major, lo, o)
    case False{}:
      raw.u32(raw.u32(byte(o, ((major << 5n) .|. 27 : U32)), hi), lo)

def uint.bytes(+major: U32, v: W64, o: W) -> W:
  W64{+hi, +lo} = v
  uint.bytes.small(U32.is_eq(hi, 0), major, hi, lo, o)

def raw.bytes.go(n: Nat, r: Array<U32> & U32, +i: U32, o: W) -> W:
  match n:
    case 0n:
      o
    case 1n+p:
      (a, +b) = r
      raw.bytes.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), byte(o, b))

def raw.bytes(b: Bytes.Bytes, o: W) -> W:
  Bytes.Bytes{+len, buf} = b
  raw.bytes.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, o)

# RFC 3629 §4 validity, as in json: overlong forms, surrogates, and code points past U+10FFFF have width 0.
type Cp is Data:
  Cp{c: U32, w: U32}

def pk.if(ok: Bool, a: Array<U32>, +i: U32) -> Array<U32> & U32:
  match ok:
    case True{}:
      Bytes.peek(a, i)
    case False{}:
      (a, 256)

# Byte i, or 256 at end, which no rule accepts.
def pk(a: Array<U32>, +end: U32, +i: U32) -> Array<U32> & U32:
  pk.if(U32.is_lt(i, end), a, i)

def cont(+b: U32) -> Bool:
  U32.is_eq((b .&. 192 : U32), 128)

def utf8.n(+b0: U32, +b1: U32, +b2: U32, +b3: U32) -> Cp:
  +x1 = (b1 .&. 63 : U32)
  +x2 = (b2 .&. 63 : U32)
  +x3 = (b3 .&. 63 : U32)
  +c2 = (((b0 .&. 31) << 6n) .|. x1 : U32)
  +c3 = ((((b0 .&. 15) << 12n) .|. (x1 << 6n)) .|. x2 : U32)
  +c4 = (((((b0 .&. 7) << 18n) .|. (x1 << 12n)) .|. (x2 << 6n)) .|. x3 : U32)
  +ok2 = U32.is_le(192, b0) && U32.is_lt(b0, 224) && cont(b1) && U32.is_le(128, c2)
  +ok3 = U32.is_le(224, b0) && U32.is_lt(b0, 240) && cont(b1) && cont(b2) && U32.is_le(2048, c3) && (U32.is_lt(c3, 55296) || U32.is_lt(57343, c3))
  +ok4 = U32.is_le(240, b0) && U32.is_lt(b0, 248) && cont(b1) && cont(b2) && cont(b3) && U32.is_le(65536, c4) && U32.is_le(c4, 1114111)
  Bool.pick(Cp, ok2, Cp{c2, 2}, Bool.pick(Cp, ok3, Cp{c3, 3}, Bool.pick(Cp, ok4, Cp{c4, 4}, Cp{0, 0})))

def utf8.b3(+b0: U32, +b1: U32, +b2: U32, r: Array<U32> & U32) -> Array<U32> & Cp:
  (a, +b3) = r
  (a, utf8.n(b0, b1, b2, b3))

def utf8.b2(+end: U32, +i: U32, +b0: U32, +b1: U32, r: Array<U32> & U32) -> Array<U32> & Cp:
  (a, +b2) = r
  utf8.b3(b0, b1, b2, pk(a, end, (i + 3 : U32)))

def utf8.b1(+end: U32, +i: U32, +b0: U32, r: Array<U32> & U32) -> Array<U32> & Cp:
  (a, +b1) = r
  utf8.b2(end, i, b0, b1, pk(a, end, (i + 2 : U32)))

def utf8.cp(+i: U32, r: Array<U32> & Cp) -> Array<U32> & U32 & Bool:
  (a, cp) = r
  Cp{c, +w} = cp
  (a, (i + w : U32), U32.is_ne(w, 0))

def utf8.byte(ascii: Bool, a: Array<U32>, +end: U32, +i: U32, +b: U32) -> Array<U32> & U32 & Bool:
  match ascii:
    case True{}:
      (a, (i + 1 : U32), True{})
    case False{}:
      utf8.cp(i, utf8.b1(end, i, b, pk(a, end, (i + 1 : U32))))

def utf8.lead(+end: U32, +i: U32, r: Array<U32> & U32) -> Array<U32> & U32 & Bool:
  (a, +b) = r
  utf8.byte(U32.is_lt(b, 128), a, end, i, b)

def utf8.more(go: Bool, a: Array<U32>, +end: U32, +i: U32) -> Array<U32> & U32 & Bool:
  match go:
    case True{}:
      utf8.lead(end, i, Bytes.peek(a, i))
    case False{}:
      (a, i, True{})

def utf8.step(ok: Bool, a: Array<U32>, +end: U32, +i: U32) -> Array<U32> & U32 & Bool:
  match ok:
    case True{}:
      utf8.more(U32.is_lt(i, end), a, end, i)
    case False{}:
      (a, i, False{})

# Each step eats a whole code point, so end - i steps reach end.
def utf8.go(n: Nat, r: Array<U32> & U32 & Bool, +end: U32) -> Array<U32> & Bool:
  match n:
    case 0n:
      (a, i, ok) = r
      (a, ok)
    case 1n+p:
      (a, +i, ok) = r
      utf8.go(p, utf8.step(ok, a, end, i), end)

# Are bytes i until end well-formed UTF-8?
def utf8.check(a: Array<U32>, +i: U32, +end: U32) -> Array<U32> & Bool:
  utf8.go(U32.to_nat((end - i : U32)), (a, i, True{}), end)

def text.fin(+len: U32, r: Array<U32> & Bool) -> Bytes.Bytes & Bool:
  (a, ok) = r
  (Bytes.Bytes{len, a}, ok)

def text.check(b: Bytes.Bytes) -> Bytes.Bytes & Bool:
  Bytes.Bytes{+len, buf} = b
  text.fin(len, utf8.check(buf, 0, len))

# Simple values 20..23 have their own constructors, 24..31 are reserved (RFC 8949 §3.3).
def simple.ok(+v: U32) -> Bool:
  U32.is_lt(v, 20) || (U32.is_le(32, v) && U32.is_le(v, 255))

# IGuard aborts the encoding when a value has no CBOR form; IText carries a text string and its UTF-8 check.
type Item is Type:
  IVal{value: Val}
  IArr{items: List<&1, Val>}
  IMap{items: List<&1, Val & Val>}
  IArrLen{value: List<&1, Val> & Nat}
  IMapLen{value: List<&1, Val & Val> & Nat}
  IGuard{ok: Bool}
  IText{value: Bytes.Bytes & Bool}
def vals.length.put(h: Val, r: List<&1, Val> & Nat) -> List<&1, Val> & Nat:
  (rest, n) = r
  (Con{h, rest}, (1n + n : Nat))

def pairs.length.put(h: Val & Val, r: List<&1, Val & Val> & Nat) -> List<&1, Val & Val> & Nat:
  (rest, n) = r
  (Con{h, rest}, (1n + n : Nat))

def vals.length(xs: List<&1, Val>) -> List<&1, Val> & Nat:
  match xs:
    case Nil{}:
      (Nil{}, 0n)
    case Con{h, t}:
      vals.length.put(h, vals.length(t))

def pairs.length(xs: List<&1, Val & Val>) -> List<&1, Val & Val> & Nat:
  match xs:
    case Nil{}:
      (Nil{}, 0n)
    case Con{h, t}:
      pairs.length.put(h, pairs.length(t))

def size.arr(h: Val, r: Val & Nat) -> Val & Nat:
  (t, n) = r
  match t:
    case Arr{items}:
      (Arr{Con{h, items}}, n)
    case _:
      (Arr{Nil{}}, n)

def size.obj(k: Val, v: Val, r: Val & Nat) -> Val & Nat:
  (t, n) = r
  match t:
    case Obj{items}:
      (Obj{Con{(k, v), items}}, n)
    case _:
      (Obj{Nil{}}, n)

def size.cons(hr: Val & Nat, r: Val & Nat) -> Val & Nat:
  (h, a) = hr
  (t, b) = r
  size.arr(h, (t, (1n + a + b : Nat)))

def size.pair(kr: Val & Nat, vr: Val & Nat, r: Val & Nat) -> Val & Nat:
  (k, a) = kr
  (v, b) = vr
  (t, c) = r
  size.obj(k, v, (t, (2n + a + b + c : Nat)))

def size.tag(+number: W64, r: Val & Nat) -> Val & Nat:
  (v, n) = r
  (Tag{number, v}, (4n + n : Nat))

# v, and at least the number of encode.go steps it takes.
def size(v: Val) -> Val & Nat:
  match v:
    case Arr{items}:
      match items:
        case Nil{}:
          (Arr{Nil{}}, 3n)
        case Con{h, t}:
          size.cons(size(h), size(Arr{t}))
    case Obj{items}:
      match items:
        case Nil{}:
          (Obj{Nil{}}, 3n)
        case Con{(k, x), t}:
          size.pair(size(k), size(x), size(Obj{t}))
    case Tag{number, value}:
      size.tag(number, size(value))
    case UInt{value}:
      (UInt{value}, 3n)
    case NInt{value}:
      (NInt{value}, 3n)
    case BStr{value}:
      (BStr{value}, 3n)
    case TStr{value}:
      (TStr{value}, 3n)
    case Sim{value}:
      (Sim{value}, 3n)
    case Flt{value}:
      (Flt{value}, 3n)

# fuel bounds the steps; size(v) gives enough, so the 0n arm is never reached.
def encode.go(fuel: Nat, items: List<&1, Item>, o: W) -> Maybe<&1, W>:
  match fuel:
    case 0n:
      None{}
    case 1n+fuel:
      match items:
        case Nil{}:
          Some{o}
        case Con{IGuard{ok}, rest}:
          match ok:
            case True{}:
              encode.go(fuel, rest, o)
            case False{}:
              None{}
        case Con{IText{value}, rest}:
          (b, ok) = value
          Bytes.Bytes{+len, buf} = b
          encode.go(fuel, Con{IGuard{ok}, rest}, raw.bytes(Bytes.Bytes{len, buf}, head.u32(3, len, o)))
        case Con{IArrLen{value}, rest}:
          (xs, n) = value
          encode.go(fuel, Con{IArr{xs}, rest}, head.u32(4, U32.from_nat(n), o))
        case Con{IMapLen{value}, rest}:
          (kvs, n) = value
          encode.go(fuel, Con{IMap{kvs}, rest}, head.u32(5, U32.from_nat(n), o))
        case Con{IArr{xs}, rest}:
          match xs:
            case Nil{}:
              encode.go(fuel, rest, o)
            case Con{h, t}:
              encode.go(fuel, Con{IVal{h}, Con{IArr{t}, rest}}, o)
        case Con{IMap{kvs}, rest}:
          match kvs:
            case Nil{}:
              encode.go(fuel, rest, o)
            case Con{(k, v), t}:
              encode.go(fuel, Con{IVal{k}, Con{IVal{v}, Con{IMap{t}, rest}}}, o)
        case Con{IVal{value}, rest}:
          match value:
            case UInt{value}:
              encode.go(fuel, rest, uint.bytes(0, value, o))
            case NInt{value}:
              encode.go(fuel, rest, uint.bytes(1, value, o))
            case BStr{value}:
              Bytes.Bytes{+len, buf} = value
              encode.go(fuel, rest, raw.bytes.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, head.u32(2, len, o)))
            case TStr{value}:
              encode.go(fuel, Con{IText{text.check(value)}, rest}, o)
            case Arr{items}:
              encode.go(fuel, Con{IArrLen{vals.length(items)}, rest}, o)
            case Obj{items}:
              encode.go(fuel, Con{IMapLen{pairs.length(items)}, rest}, o)
            case Tag{number, value}:
              encode.go(fuel, Con{IVal{value}, rest}, uint.bytes(6, number, o))
            case Sim{value}:
              match value:
                case SFalse{}:
                  encode.go(fuel, rest, byte(o, 244))
                case STrue{}:
                  encode.go(fuel, rest, byte(o, 245))
                case SNull{}:
                  encode.go(fuel, rest, byte(o, 246))
                case SUndefined{}:
                  encode.go(fuel, rest, byte(o, 247))
                case Other{+value}:
                  encode.go(fuel, Con{IGuard{simple.ok(value)}, rest}, head.u32(7, value, o))
            case Flt{value}:
              match value:
                case Half{+bits}:
                  encode.go(fuel, Con{IGuard{U32.is_lt(bits, 65536)}, rest}, byte(byte(byte(o, 249), (bits >> 8n : U32)), bits))
                case Single{+bits}:
                  encode.go(fuel, rest, raw.u32(byte(o, 250), bits))
                case Double{+bits}:
                  W64{+hi, +lo} = bits
                  encode.go(fuel, rest, raw.u32(raw.u32(byte(o, 251), hi), lo))

def encode.done(r: Maybe<&1, W>) -> Maybe<&1, Bytes.Bytes>:
  match r:
    case Some{o}:
      Some{finish(o)}
    case None{}:
      None{}

def encode.sized(r: Val & Nat) -> Maybe<&1, Bytes.Bytes>:
  (v, n) = r
  encode.done(encode.go((1n + n : Nat), Con{IVal{v}, Nil{}}, empty()))

# Definite lengths and the shortest head for every length, integer, and tag; floats keep their width.
# None when a TStr is not UTF-8, a Half has more than 16 bits, or Other is not a simple value 0..19 or 32..255.
def encode(v: Val) -> Maybe<&1, Bytes.Bytes>:
  encode.sized(size(v))

def decode.other(ok: Bool, +value: U32) -> Maybe<&1, Val>:
  match ok:
    case True{}:
      Some{Sim{Other{value}}}
    case False{}:
      None{}

def decode.simple(+ai: U32) -> Maybe<&1, Val>:
  match ai:
    case 20:
      Some{Sim{SFalse{}}}
    case 21:
      Some{Sim{STrue{}}}
    case 22:
      Some{Sim{SNull{}}}
    case 23:
      Some{Sim{SUndefined{}}}
    case _:
      decode.other(U32.is_lt(ai, 20), ai)

def decode.major7.arg(+ai: U32, +arg: W64) -> Maybe<&1, Val>:
  match ai:
    case 24:
      W64{+hi, +lo} = arg
      decode.other(U32.is_le(32, lo) && U32.is_le(lo, 255), lo)
    case 25:
      W64{hi, lo} = arg
      Some{Flt{Half{lo}}}
    case 26:
      W64{hi, lo} = arg
      Some{Flt{Single{lo}}}
    case 27:
      Some{Flt{Double{arg}}}
    case _:
      None{}

def decode.major7(small: Bool, +ai: U32, +arg: W64) -> Maybe<&1, Val>:
  match small:
    case True{}:
      decode.simple(ai)
    case False{}:
      decode.major7.arg(ai, arg)

# A head: major type, additional info, argument, and the index after it.
type Hd is Data:
  Hd{major: U32, ai: U32, arg: W64, next: U32}

# n argument bytes from j, most significant first.
def hd.words(n: Nat, r: Array<U32> & U32, +j: U32, +hi: U32, +lo: U32, +major: U32, +ai: U32) -> Array<U32> & Maybe<&2, Hd>:
  match n:
    case 0n:
      (a, b) = r
      (a, Some{Hd{major, ai, W64{hi, lo}, j}})
    case 1n+p:
      (a, +b) = r
      hd.words(p, Bytes.peek(a, (j + 1 : U32)), (j + 1 : U32), ((hi << 8n) .|. (lo >> 24n) : U32), ((lo << 8n) .|. b : U32), major, ai)

def hd.wide(ok: Bool, n: Nat, a: Array<U32>, +i: U32, +major: U32, +ai: U32) -> Array<U32> & Maybe<&2, Hd>:
  match ok:
    case True{}:
      hd.words(n, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), 0, 0, major, ai)
    case False{}:
      (a, None{})

# ai 24..27 take 1, 2, 4 or 8 more bytes; 28..30 are reserved; 31 is indefinite or break.
def hd.arg(+ai: U32, a: Array<U32>, +len: U32, +i: U32, +major: U32) -> Array<U32> & Maybe<&2, Hd>:
  match ai:
    case 24:
      hd.wide(Bytes.fits(len, (i + 1 : U32), 1), 1n, a, i, major, 24)
    case 25:
      hd.wide(Bytes.fits(len, (i + 1 : U32), 2), 2n, a, i, major, 25)
    case 26:
      hd.wide(Bytes.fits(len, (i + 1 : U32), 4), 4n, a, i, major, 26)
    case 27:
      hd.wide(Bytes.fits(len, (i + 1 : U32), 8), 8n, a, i, major, 27)
    case 28:
      (a, None{})
    case 29:
      (a, None{})
    case 30:
      (a, None{})
    case _:
      (a, Some{Hd{major, ai, W64{0, ai}, (i + 1 : U32)}})

def hd.of(+len: U32, +i: U32, r: Array<U32> & U32) -> Array<U32> & Maybe<&2, Hd>:
  (a, +b) = r
  hd.arg((b .&. 31 : U32), a, len, i, (b >> 5n : U32))

def hd.read(ok: Bool, a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & Maybe<&2, Hd>:
  match ok:
    case True{}:
      hd.of(len, i, Bytes.peek(a, i))
    case False{}:
      (a, None{})

def bstr.some(+n: U32, r: Array<U32> & Array<U32>) -> Array<U32> & Maybe<&1, Bytes.Bytes>:
  (a, out) = r
  (a, Some{Bytes.Bytes{n, out}})

def bstr.copy(+n: U32, +i: U32, r: Array<U32> & Bool) -> Array<U32> & Maybe<&1, Bytes.Bytes>:
  (a, ok) = r
  match ok:
    case True{}:
      bstr.some(n, Bytes.copy(n, a, Bytes.alloc(n), i, 0))
    case False{}:
      (a, None{})

def bstr.valid(text: Bool, a: Array<U32>, +i: U32, +end: U32) -> Array<U32> & Bool:
  match text:
    case True{}:
      utf8.check(a, i, end)
    case False{}:
      (a, True{})

def bstr.fit(ok: Bool, +text: Bool, a: Array<U32>, +n: U32, +i: U32) -> Array<U32> & Maybe<&1, Bytes.Bytes>:
  match ok:
    case True{}:
      bstr.copy(n, i, bstr.valid(text, a, i, (i + n : U32)))
    case False{}:
      (a, None{})

# A definite string of arg bytes from i. None when it runs past len, or when text is not UTF-8.
def bstr.read(+text: Bool, +arg: W64, a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & Maybe<&1, Bytes.Bytes>:
  W64{+hi, +lo} = arg
  bstr.fit(U32.is_eq(hi, 0) && Bytes.fits(len, i, lo), text, a, lo, i)

def wrap(text: Bool, b: Bytes.Bytes) -> Val:
  match text:
    case True{}:
      TStr{b}
    case False{}:
      BStr{b}

# An open container. Items are reversed; left counts the definite items (or pairs) still due, this one included.
type Frame is Type:
  FArr{left: U32, xs: List<&1, Val>}
  FArrI{xs: List<&1, Val>}
  FMap{left: U32, kvs: List<&1, Val & Val>}
  FKey{left: U32, kvs: List<&1, Val & Val>, key: Val}
  FMapI{kvs: List<&1, Val & Val>}
  FKeyI{kvs: List<&1, Val & Val>, key: Val}
  FTag{number: W64}

# SHead reads an item at i; SChunk reads the next chunk of an indefinite string; SDone hands v to the open frame.
type St is Type:
  SHead{i: U32, stack: List<&1, Frame>}
  SChunk{i: U32, text: Bool, chunks: List<&1, Bytes.Bytes>, stack: List<&1, Frame>}
  SDone{v: Val, i: U32, stack: List<&1, Frame>}
  SOk{v: Val}
  SFail{}

def item.str(+text: Bool, +i: U32, stack: List<&1, Frame>, r: Array<U32> & Maybe<&1, Bytes.Bytes>) -> Array<U32> & St:
  (a, m) = r
  match m:
    case Some{b}:
      Bytes.Bytes{+n, buf} = b
      (a, SDone{wrap(text, Bytes.Bytes{n, buf}), (i + n : U32), stack})
    case None{}:
      (a, SFail{})

def item.empty(map: Bool, +i: U32, stack: List<&1, Frame>) -> St:
  match map:
    case True{}:
      SDone{Obj{Nil{}}, i, stack}
    case False{}:
      SDone{Arr{Nil{}}, i, stack}

def item.push(map: Bool, +n: U32, +i: U32, stack: List<&1, Frame>) -> St:
  match map:
    case True{}:
      SHead{i, Con{FMap{n, Nil{}}, stack}}
    case False{}:
      SHead{i, Con{FArr{n, Nil{}}, stack}}

def item.open(empty: Bool, +map: Bool, +n: U32, +i: U32, stack: List<&1, Frame>) -> St:
  match empty:
    case True{}:
      item.empty(map, i, stack)
    case False{}:
      item.push(map, n, i, stack)

def item.count(ok: Bool, +map: Bool, +n: U32, +i: U32, stack: List<&1, Frame>) -> St:
  match ok:
    case True{}:
      item.open(U32.is_eq(n, 0), map, n, i, stack)
    case False{}:
      SFail{}

# Every item takes a byte, so a count past the bytes left is malformed; this also keeps it in a U32.
def item.len(+map: Bool, +arg: W64, +len: U32, +i: U32, stack: List<&1, Frame>) -> St:
  W64{+hi, +lo} = arg
  item.count(U32.is_eq(hi, 0) && U32.is_le(lo, (len - i : U32)), map, lo, i, stack)

def item.simple(m: Maybe<&1, Val>, +i: U32, stack: List<&1, Frame>) -> St:
  match m:
    case Some{v}:
      SDone{v, i, stack}
    case None{}:
      SFail{}

def item.def(+major: U32, +ai: U32, +arg: W64, +i: U32, a: Array<U32>, +len: U32, stack: List<&1, Frame>) -> Array<U32> & St:
  match major:
    case 0:
      (a, SDone{UInt{arg}, i, stack})
    case 1:
      (a, SDone{NInt{arg}, i, stack})
    case 2:
      item.str(False{}, i, stack, bstr.read(False{}, arg, a, len, i))
    case 3:
      item.str(True{}, i, stack, bstr.read(True{}, arg, a, len, i))
    case 4:
      (a, item.len(False{}, arg, len, i, stack))
    case 5:
      (a, item.len(True{}, arg, len, i, stack))
    case 6:
      (a, SHead{i, Con{FTag{arg}, stack}})
    case _:
      (a, item.simple(decode.major7(U32.is_lt(ai, 24), ai, arg), i, stack))

# A break closes the innermost indefinite array, or map with no key pending; anywhere else it is malformed.
def brk.fr(fr: Frame, +i: U32, rest: List<&1, Frame>) -> St:
  match fr:
    case FArrI{xs}:
      SDone{Arr{List.reverse(&1, Val, xs)}, i, rest}
    case FMapI{kvs}:
      SDone{Obj{List.reverse(&1, Val & Val, kvs)}, i, rest}
    case FArr{left, xs}:
      SFail{}
    case FMap{left, kvs}:
      SFail{}
    case FKey{left, kvs, k}:
      SFail{}
    case FKeyI{kvs, k}:
      SFail{}
    case FTag{number}:
      SFail{}

def brk(stack: List<&1, Frame>, +i: U32) -> St:
  match stack:
    case Nil{}:
      SFail{}
    case Con{fr, rest}:
      brk.fr(fr, i, rest)

# ai 31: indefinite string, array, or map, or (major 7) a break. Majors 0, 1 and 6 have no indefinite form.
def item.indef(+major: U32, +i: U32, stack: List<&1, Frame>) -> St:
  match major:
    case 2:
      SChunk{i, False{}, Nil{}, stack}
    case 3:
      SChunk{i, True{}, Nil{}, stack}
    case 4:
      SHead{i, Con{FArrI{Nil{}}, stack}}
    case 5:
      SHead{i, Con{FMapI{Nil{}}, stack}}
    case 7:
      brk(stack, i)
    case _:
      SFail{}

def item.hd(indef: Bool, +major: U32, +ai: U32, +arg: W64, +i: U32, a: Array<U32>, +len: U32, stack: List<&1, Frame>) -> Array<U32> & St:
  match indef:
    case True{}:
      (a, item.indef(major, i, stack))
    case False{}:
      item.def(major, ai, arg, i, a, len, stack)

def step.head(stack: List<&1, Frame>, +len: U32, r: Array<U32> & Maybe<&2, Hd>) -> Array<U32> & St:
  (a, h) = r
  match h:
    case Some{Hd{+major, +ai, +arg, +i}}:
      item.hd(U32.is_eq(ai, 31), major, ai, arg, i, a, len, stack)
    case None{}:
      (a, SFail{})

def chunk.str(+text: Bool, chunks: List<&1, Bytes.Bytes>, +i: U32, stack: List<&1, Frame>, r: Array<U32> & Maybe<&1, Bytes.Bytes>) -> Array<U32> & St:
  (a, m) = r
  match m:
    case Some{b}:
      Bytes.Bytes{+n, buf} = b
      (a, SChunk{(i + n : U32), text, Con{Bytes.Bytes{n, buf}, chunks}, stack})
    case None{}:
      (a, SFail{})

def chunk.more(ok: Bool, +text: Bool, chunks: List<&1, Bytes.Bytes>, +arg: W64, +i: U32, a: Array<U32>, +len: U32, stack: List<&1, Frame>) -> Array<U32> & St:
  match ok:
    case True{}:
      chunk.str(text, chunks, i, stack, bstr.read(text, arg, a, len, i))
    case False{}:
      (a, SFail{})

# Each chunk is a definite string of the same major type, UTF-8 by itself for text (RFC 8949 §3.2.3).
def chunk.end(stop: Bool, ok: Bool, +text: Bool, chunks: List<&1, Bytes.Bytes>, +arg: W64, +i: U32, a: Array<U32>, +len: U32, stack: List<&1, Frame>) -> Array<U32> & St:
  match stop:
    case True{}:
      (a, SDone{wrap(text, Bytes.concat(List.reverse(&1, Bytes.Bytes, chunks))), i, stack})
    case False{}:
      chunk.more(ok, text, chunks, arg, i, a, len, stack)

def step.chunk(+text: Bool, chunks: List<&1, Bytes.Bytes>, stack: List<&1, Frame>, +len: U32, r: Array<U32> & Maybe<&2, Hd>) -> Array<U32> & St:
  (a, h) = r
  match h:
    case Some{Hd{+major, +ai, +arg, +i}}:
      chunk.end(U32.is_eq(major, 7) && U32.is_eq(ai, 31), U32.is_eq(major, Bool.pick(U32, text, 3, 2)) && U32.is_ne(ai, 31), text, chunks, arg, i, a, len, stack)
    case None{}:
      (a, SFail{})

def done.arr(last: Bool, +left: U32, xs: List<&1, Val>, +i: U32, rest: List<&1, Frame>) -> St:
  match last:
    case True{}:
      SDone{Arr{List.reverse(&1, Val, xs)}, i, rest}
    case False{}:
      SHead{i, Con{FArr{(left - 1 : U32), xs}, rest}}

def done.map(last: Bool, +left: U32, kvs: List<&1, Val & Val>, +i: U32, rest: List<&1, Frame>) -> St:
  match last:
    case True{}:
      SDone{Obj{List.reverse(&1, Val & Val, kvs)}, i, rest}
    case False{}:
      SHead{i, Con{FMap{(left - 1 : U32), kvs}, rest}}

def done.fr(fr: Frame, v: Val, +i: U32, rest: List<&1, Frame>) -> St:
  match fr:
    case FArr{+left, xs}:
      done.arr(U32.is_eq(left, 1), left, Con{v, xs}, i, rest)
    case FArrI{xs}:
      SHead{i, Con{FArrI{Con{v, xs}}, rest}}
    case FMap{+left, kvs}:
      SHead{i, Con{FKey{left, kvs, v}, rest}}
    case FKey{+left, kvs, k}:
      done.map(U32.is_eq(left, 1), left, Con{(k, v), kvs}, i, rest)
    case FMapI{kvs}:
      SHead{i, Con{FKeyI{kvs, v}, rest}}
    case FKeyI{kvs, k}:
      SHead{i, Con{FMapI{Con{(k, v), kvs}}, rest}}
    case FTag{number}:
      SDone{Tag{number, v}, i, rest}

def done.top(end: Bool, v: Val) -> St:
  match end:
    case True{}:
      SOk{v}
    case False{}:
      SFail{}

# A finished top-level item must end the input.
def done(stack: List<&1, Frame>, v: Val, +i: U32, +len: U32) -> St:
  match stack:
    case Nil{}:
      done.top(U32.is_eq(i, len), v)
    case Con{fr, rest}:
      done.fr(fr, v, i, rest)

def run(fuel: Nat, r: Array<U32> & St, +len: U32) -> Maybe<&1, Val>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      (a, st) = r
      match st:
        case SOk{v}:
          Some{v}
        case SFail{}:
          None{}
        case SHead{+i, stack}:
          run(f, step.head(stack, len, hd.read(U32.is_lt(i, len), a, len, i)), len)
        case SChunk{+i, +text, chunks, stack}:
          run(f, step.chunk(text, chunks, stack, len, hd.read(U32.is_lt(i, len), a, len, i)), len)
        case SDone{v, +i, stack}:
          run(f, (a, done(stack, v, i, len)), len)

# One well-formed data item (RFC 8949 §3, Appendix C) filling b. Indefinite strings, arrays and maps come back
# definite, with chunks joined. None for truncation, reserved ai 28..30, a misplaced break or indefinite form,
# a simple value 0..31 in two bytes, text that is not UTF-8, or trailing bytes.
# fuel: a head or chunk eats a byte, and each SDone step follows one, so 2 * len + 2 steps are enough.
def decode(b: Bytes.Bytes) -> Maybe<&1, Val>:
  Bytes.Bytes{+len, buf} = b
  run(Nat.add(Nat.mul(U32.to_nat(len), 2n), 2n), (buf, SHead{0, Nil{}}), len)
