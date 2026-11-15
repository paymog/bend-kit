# UTF-8 encoding and decoding between text and Bytes. Source: https://github.com/paymog/bend-kit/tree/main/encoding
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

# UTF-8 (RFC 3629). Text is a String of code points; octets are Bytes.
# Hex lives in Bytes: Bytes.to_hex and Bytes.from_hex.

# Octets being written: the buffer, the count so far, and the word being filled.
type Out is Type:
  Out{buf: Array<U32>, n: U32, w: U32}

# Bytes enter at the top of w, as in Bytes.from_string; every fourth byte stores the word.
def put(o: Out, +b: U32) -> Out:
  Out{buf, +n, +w} = o
  +w2 = ((w >> 8n) .|. (b << 24n) : U32)
  +full = U32.is_eq((n .&. 3 : U32), 3)
  Out{Bytes.flush(full, buf, (n >> 2n : U32), w2), (n + 1 : U32), Bool.pick(U32, full, 0, w2)}

def done(o: Out) -> Bytes.Bytes:
  Out{buf, +n, +w} = o
  +r = (n .&. 3 : U32)
  Bytes.Bytes{n, Bytes.flush(U32.is_ne(r, 0), buf, (n >> 2n : U32), U32.shrn(w, U32.to_nat((((4 - r) .&. 3) * 8 : U32))))}

def utf8.width(+c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(c, 128), 1, Bool.pick(U32, U32.is_lt(c, 2048), 2, Bool.pick(U32, U32.is_lt(c, 65536), 3, 4)))

def utf8.size(s: String, +n: U32) -> U32:
  match s:
    case SNil{}:
      n
    case SCon{Chr{+c}, t}:
      utf8.size(t, (n + utf8.width(c) : U32))

def utf8.cont(c: U32, n: Nat) -> U32:
  (128 + U32.and(U32.shrn(c, n), 63) : U32)

def utf8.push4(+c: U32, o: Out) -> Out:
  put(put(put(put(o, (240 + U32.shrn(c, 18n) : U32)), utf8.cont(c, 12n)), utf8.cont(c, 6n)), utf8.cont(c, 0n))

def utf8.push3(+c: U32, o: Out, small: Bool) -> Out:
  match small:
    case True{}:
      put(put(put(o, (224 + U32.shrn(c, 12n) : U32)), utf8.cont(c, 6n)), utf8.cont(c, 0n))
    case False{}:
      utf8.push4(c, o)

def utf8.push2(+c: U32, o: Out, small: Bool) -> Out:
  match small:
    case True{}:
      put(put(o, (192 + U32.shrn(c, 6n) : U32)), utf8.cont(c, 0n))
    case False{}:
      utf8.push3(c, o, U32.is_lt(c, 65536))

def utf8.push(+c: U32, o: Out, ascii: Bool) -> Out:
  match ascii:
    case True{}:
      put(o, c)
    case False{}:
      utf8.push2(c, o, U32.is_lt(c, 2048))

def utf8.encode.go(s: String, o: Out) -> Out:
  match s:
    case SNil{}:
      o
    case SCon{Chr{+c}, t}:
      utf8.encode.go(t, utf8.push(c, o, U32.is_lt(c, 128)))

# Text to octets. One pass sizes the buffer; a second fills it.
def utf8.encode(+s: String) -> Bytes.Bytes:
  done(utf8.encode.go(s, Out{Bytes.alloc(utf8.size(s, 0)), 0, 0}))

# Decoder state: continuation bytes still needed, the allowed range of the
# next one, the code point so far, and the output reversed.
type Utf8 is Data:
  Utf8{need: U32, lo: U32, hi: U32, cp: U32, out: String}

def utf8.bad(out: String) -> String:
  SCon{Chr{65533}, out}

def utf8.lead.multi(+b: U32, out: String) -> Utf8:
  +need = Bool.pick(U32, U32.is_lt(b, 224), 1, Bool.pick(U32, U32.is_lt(b, 240), 2, 3))
  +lo = Bool.pick(U32, U32.is_eq(b, 224), 160, Bool.pick(U32, U32.is_eq(b, 240), 144, 128))
  +hi = Bool.pick(U32, U32.is_eq(b, 237), 159, Bool.pick(U32, U32.is_eq(b, 244), 143, 191))
  Utf8{need, lo, hi, U32.and(b, U32.shrn(63, U32.to_nat(need))), out}

def utf8.lead.high(+b: U32, out: String, bad: Bool) -> Utf8:
  match bad:
    case True{}:
      Utf8{0, 128, 191, 0, utf8.bad(out)}
    case False{}:
      utf8.lead.multi(b, out)

# WHATWG: a byte that cannot start a sequence decodes to U+FFFD.
def utf8.lead(+b: U32, out: String, ascii: Bool) -> Utf8:
  match ascii:
    case True{}:
      Utf8{0, 128, 191, 0, SCon{Chr{b}, out}}
    case False{}:
      utf8.lead.high(b, out, Bool.or(U32.is_lt(b, 194), U32.is_lt(244, b)))

def utf8.more(+need: U32, cp: U32, out: String, done: Bool) -> Utf8:
  match done:
    case True{}:
      Utf8{0, 128, 191, 0, SCon{Chr{cp}, out}}
    case False{}:
      Utf8{need, 128, 191, cp, out}

# WHATWG: a byte that breaks a sequence yields U+FFFD and is read again as a lead.
def utf8.cont.in(+need: U32, cp: U32, +b: U32, out: String, ok: Bool) -> Utf8:
  match ok:
    case True{}:
      utf8.more((need - 1 : U32), (cp * 64 + U32.and(b, 63) : U32), out, U32.is_eq(need, 1))
    case False{}:
      utf8.lead(b, utf8.bad(out), U32.is_lt(b, 128))

def utf8.step.if(+need: U32, +lo: U32, +hi: U32, cp: U32, +b: U32, out: String, idle: Bool) -> Utf8:
  match idle:
    case True{}:
      utf8.lead(b, out, U32.is_lt(b, 128))
    case False{}:
      utf8.cont.in(need, cp, b, out, Bool.and(U32.is_le(lo, b), U32.is_le(b, hi)))

def utf8.step.st(st: Utf8, +b: U32) -> Utf8:
  Utf8{+need, +lo, +hi, cp, out} = st
  utf8.step.if(need, lo, hi, cp, b, out, U32.is_eq(need, 0))

def utf8.finish(st: Utf8) -> String:
  Utf8{+need, lo, hi, cp, +out} = st
  String.reverse(Bool.pick(String, U32.is_eq(need, 0), out, utf8.bad(out)))

def utf8.decode.go(n: Nat, r: Array<U32> & U32, +i: U32, st: Utf8) -> String:
  match n:
    case 0n:
      (a, v) = r
      utf8.finish(st)
    case 1n+p:
      (a, +b) = r
      utf8.decode.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), utf8.step.st(st, b))

# Octets to text, as WHATWG decodes UTF-8: malformed input becomes U+FFFD.
def utf8.decode(b: Bytes.Bytes) -> String:
  Bytes.Bytes{+len, buf} = b
  utf8.decode.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, Utf8{0, 128, 191, 0, SNil{}})
