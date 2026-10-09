# RFC 6455 WebSocket client: opening handshake, frames over packed Bytes, and messages over Wire. Source: https://github.com/paymog/bend-kit/tree/main/websocket
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-crypto@0.2.2.1/crypto.bend as Crypto
import bend-kit-wire@0.4.6.1/wire.bend as Wire

# Errors are (code, why). A code of 1000 or more is the RFC 6455 §7.4 close code the
# peer broke (1002 protocol, 1006 closed early, 1007 bad UTF-8, 1009 too big, 1011 budget);
# a smaller code is the errno of a socket or crypto effect.
# Opcodes (§5.2): 0 continuation, 1 text, 2 binary, 8 close, 9 ping, 10 pong.

# Opening handshake (§4.1, §4.2.2).

def guid() -> String:
  "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# The octets SHA-1 hashes for Sec-WebSocket-Accept: the key, then the GUID.
def accept.input(key: String) -> Bytes.Bytes:
  Bytes.from_string(key ++ guid())

# Sec-WebSocket-Accept from the SHA-1 digest of accept.input(key).
def accept.of(digest: Bytes.Bytes) -> String:
  Bytes.to_base64(digest)

def accept.fin(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(len, buf)}:
      Done{accept.of(Bytes.Bytes{len, buf})}

def accept.words(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{len, buf} = b
  Crypto.sha1.words(len, buf)

# The Sec-WebSocket-Accept a server must answer to key.
def accept(key: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- accept.words(accept.input(key))
    return accept.fin(r)

# Sec-WebSocket-Key from a 16-octet nonce.
def key.of(nonce: Bytes.Bytes) -> String:
  Bytes.to_base64(nonce)

def key.fin(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(len, buf)}:
      Done{key.of(Bytes.Bytes{len, buf})}

# A fresh key from 16 octets of the OS secure random source.
def key() -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.random.words(16)
    return key.fin(r)

def first(m: Maybe<&1, U32 & String>, n: Maybe<&1, U32 & String>) -> Maybe<&1, U32 & String>:
  match m:
    case Some{e}:
      Some{e}
    case None{}:
      n

def reject(bad: Bool, +code: U32, +why: String) -> Maybe<&1, U32 & String>:
  match bad:
    case True{}:
      Some{(code, why)}
    case False{}:
      None{}

def verdict(-A: Type, m: Maybe<&1, U32 & String>, v: A) -> Result<&1, &1, U32 & String, A>:
  match m:
    case Some{e}:
      Fail{e}
    case None{}:
      Done{v}

# Every char is visible ASCII (0x21-0x7E): no space, CR, LF, or other control.
def visible(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(U32.is_ge(c, 33), U32.is_le(c, 126)), visible(t))

# The GET that asks to upgrade. host is the Host header (with :port when not the default);
# path is the origin-form target ("/" and on, percent-encoded). A char outside visible
# ASCII could split the head and inject headers, so it fails with EINVAL (22).
def request(+host: String, +path: String, +key: String) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  verdict(Bytes.Bytes,
    first(reject(Bool.or(String.is_empty(host), Bool.not(visible(host))), 22, "host is not visible ASCII"),
    first(reject(Bool.or(Bool.not(String.starts_with(path, "/")), Bool.not(visible(path))), 22, "path is not an origin-form target"),
      reject(Bool.or(String.is_empty(key), Bool.not(visible(key))), 22, "key is not visible ASCII"))),
    Bytes.from_string("GET " ++ path ++ " HTTP/1.1\r\nHost: " ++ host
      ++ "\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: " ++ key
      ++ "\r\nSec-WebSocket-Version: 13\r\n\r\n"))

def fields.line(parts: List<&2, String>, +name: String, +later: List<&2, String>) -> List<&2, String>:
  match parts:
    case Nil{}:
      later
    case Con{k, v}:
      Bool.pick(List<&2, String>, String.eq(String.to_lower(k), name),
        Con{String.trim(String.join(v, ":")), later}, later)

def fields.go(ls: List<&2, String>, +name: String) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      fields.line(String.split(String.trim_end(h), ':'), name, fields.go(t, name))

def after.first(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      t

# The header lines of an HTTP head: every line after the start line.
def headers(head: String) -> List<&2, String>:
  after.first(String.split(head, '\n'))

# The trimmed values of every header line named name (lowercase), in order.
def fields(head: String, +name: String) -> List<&2, String>:
  fields.go(headers(head), name)

def only(xs: List<&2, String>) -> Maybe<&2, String>:
  match xs:
    case Con{v, Nil{}}:
      Some{v}
    case _:
      None{}

# The value of the header named name when exactly one line has it.
def field(head: String, +name: String) -> Maybe<&2, String>:
  only(fields(head, name))

# A header line is name ":" value, with a non-empty name that holds no space or tab
# (RFC 9112 §5.1). That rules out obsolete line folding and bare text.
def line.parts(parts: List<&2, String>) -> Bool:
  match parts:
    case Con{+k, Con{v, rest}}:
      Bool.and(Bool.not(String.is_empty(k)), Bool.not(Bool.or(String.contains(k, " "), String.contains(k, "\t"))))
    case _:
      False{}

def lines.ok(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(line.parts(String.split(String.trim_end(h), ':')), lines.ok(t))

def status.parts(parts: List<&2, String>) -> Bool:
  match parts:
    case Con{v, Con{code, rest}}:
      Bool.and(String.eq(v, "HTTP/1.1"), String.eq(code, "101"))
    case _:
      False{}

# The first line is exactly "HTTP/1.1 101" and a reason, with nothing before it.
def status(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}:
      False{}
    case Con{l, t}:
      status.parts(String.split(String.trim_end(l), ' '))

def token(xs: List<&2, String>, +want: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(String.eq(String.trim(h), want), token(t, want))

def value.is(m: Maybe<&2, String>, +want: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      String.eq(v, want)

def value.lower(m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      Some{String.to_lower(v)}

# Connection is a list header: its lines join into one comma list (RFC 9110 §5.3).
def tokens(xs: List<&2, String>, +want: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{v, t}:
      Bool.or(token(String.split(String.to_lower(v), ','), want), tokens(t, want))

def none(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      False{}

# Does a server's head (up to its blank line) accept the upgrade? want is accept(key).
# Upgrade and Sec-WebSocket-Accept must each come once. No extension or subprotocol
# was asked for, so the server may name none (§4.1).
def check(+head: String, +want: String) -> Result<&1, &1, U32 & String, Unit>:
  verdict(Unit,
    first(reject(Bool.not(status(String.split(head, '\n'))), 1002, "status line is not HTTP/1.1 101"),
    first(reject(Bool.not(lines.ok(headers(head))), 1002, "malformed header line"),
    first(reject(Bool.not(value.is(value.lower(field(head, "upgrade")), "websocket")), 1002, "Upgrade is not one websocket"),
    first(reject(Bool.not(tokens(fields(head, "connection"), "upgrade")), 1002, "Connection lacks Upgrade"),
    first(reject(Bool.not(value.is(field(head, "sec-websocket-accept"), want)), 1002, "Sec-WebSocket-Accept is not one match for the key"),
    first(reject(Bool.not(none(fields(head, "sec-websocket-extensions"))), 1002, "unrequested extension"),
      reject(Bool.not(none(fields(head, "sec-websocket-protocol"))), 1002, "unrequested subprotocol"))))))),
    Unit{})

def with_slice(-R: Type, r: Bytes.Bytes & Bytes.Bytes, k: Bytes.Bytes -> Bytes.Bytes -> R) -> R:
  (b, part) = r
  k(b, part)

# An HTTP head cut at its blank line, with the bytes after it.
type Split is Type:
  Found{head: String, rest: Bytes.Bytes}
  Short{acc: Bytes.Bytes}
  Long{}

def split.long(long: Bool, b: Bytes.Bytes) -> Split:
  match long:
    case True{}:
      Long{}
    case False{}:
      Short{b}

def split.short(b: Bytes.Bytes) -> Split:
  Bytes.Bytes{+n, buf} = b
  split.long(U32.is_gt(n, 16384), Bytes.Bytes{n, buf})

def split.found(r: Bytes.Bytes & Maybe<&2, U32>) -> Split:
  (b, m) = r
  match m:
    case Some{+i}:
      with_slice(Split, Bytes.slice(b, 0, i), b => head =>
        with_slice(Split, Bytes.slice(b, (i + 4 : U32), 4294967295), unused => rest =>
          Found{Bytes.to_string(head), rest}))
    case None{}:
      split.short(b)

# Found once b holds "\r\n\r\n"; Long when 16 KiB came without it.
def split(b: Bytes.Bytes) -> Split:
  split.found(Bytes.find(b, "\r\n\r\n"))

# Frames (§5.2).

# The payload P is Bytes at run time and a List of octets in the proofs.
type Frame<-P: Type> is Type:
  Frame{fin: Bool, op: U32, payload: P}

# Need: the input does not hold a whole frame yet, and comes back intact.
# Got: one frame, and the octets after it. Bad: the input breaks §5.2 whatever comes next.
type Decode<-P: Type, -S: Type> is Type:
  Need{input: S}
  Got{frame: Frame<P>, rest: S}
  Bad{code: U32, why: String}

def mask.go(n: Nat, r: Array<U32> & U32, +i: U32, +key: U32) -> Array<U32>:
  match n:
    case 0n:
      (a, w) = r
      a
    case 1n+p:
      (a, +w) = r
      +j = (i + 1 : U32)
      mask.go(p, Array.get(U32, Array.set(U32, a, i, (w .^. key : U32)), j), j, key)

def mask.trim.word(+k: U32, +m: U32, r: Array<U32> & U32) -> Array<U32>:
  (a, +w) = r
  Array.set(U32, a, k, (w .&. m : U32))

def mask.trim.if(whole: Bool, +k: U32, +m: U32, a: Array<U32>) -> Array<U32>:
  match whole:
    case True{}:
      a
    case False{}:
      mask.trim.word(k, m, Array.get(U32, a, k))

# Bytes at or past len stay 0, as Bytes requires.
def mask.trim(+len: U32, a: Array<U32>) -> Array<U32>:
  +r = (len .&. 3 : U32)
  mask.trim.if(U32.is_eq(r, 0), (len >> 2n : U32), (U32.shln(1, U32.to_nat((r * 8 : U32))) - 1 : U32), a)

# The payload XOR the mask key (§5.3), a word at a time. key's byte k (low first) is mask octet k.
# Masking twice gives the payload back.
def mask(+key: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = b
  Bytes.Bytes{len, mask.trim(len, mask.go(U32.to_nat(Bytes.words(len)), Array.get(U32, buf, 0), 0, key))}

def known(+op: U32) -> Bool:
  match op:
    case 0:
      True{}
    case 1:
      True{}
    case 2:
      True{}
    case 8:
      True{}
    case 9:
      True{}
    case 10:
      True{}
    case _:
      False{}

# The §5.2 and §5.5 rules on a frame header. No extension is in use, so RSV must be 0.
# big: the payload is over 125 octets.
def rules.big(+fin: Bool, +rsv: U32, +op: U32, big: Bool) -> Maybe<&1, U32 & String>:
  first(reject(U32.is_ne(rsv, 0), 1002, "reserved bits set"),
  first(reject(Bool.not(known(op)), 1002, "unknown opcode"),
  first(reject(Bool.and(U32.is_ge(op, 8), Bool.not(fin)), 1002, "fragmented control frame"),
    reject(Bool.and(U32.is_ge(op, 8), big), 1002, "control frame over 125 bytes"))))

def rules(+fin: Bool, +rsv: U32, +op: U32, +len: U32) -> Maybe<&1, U32 & String>:
  rules.big(fin, rsv, op, U32.is_gt(len, 125))

def encode.ext(+ext: U32, +len: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  match ext:
    case 0:
      b
    case 2:
      Bytes.set.u16be(b, 2, len)
    case _:
      Bytes.set.u32be(b, 6, len)

def encode.mkey(+keylen: U32, +at: U32, +key: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  match keylen:
    case 0:
      b
    case _:
      Bytes.set.u32le(b, at, key)

def encode.copy(+len: U32, src: Array<U32>, +hs: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+n, dst} = b
  Bytes.Bytes{n, Bytes.dst(Bytes.copy(len, src, dst, 0, hs))}

# Payload lengths use the shortest form (§5.2): 7 bits, then 16, then 64.
def encode.frame(+b0: U32, +mbit: U32, +keylen: U32, +key: U32, p: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, src} = p
  +ext = Bool.pick(U32, U32.is_le(len, 125), 0, Bool.pick(U32, U32.is_le(len, 65535), 2, 8))
  +l7 = Bool.pick(U32, U32.is_le(len, 125), len, Bool.pick(U32, U32.is_le(len, 65535), 126, 127))
  +hs = (2 + ext + keylen : U32)
  encode.copy(len, src, hs, encode.mkey(keylen, (2 + ext : U32), key, encode.ext(ext, len,
    Bytes.set(Bytes.set(Bytes.new((hs + len : U32)), 0, b0), 1, (mbit .|. l7 : U32)))))

def encode.key(key: Maybe<&2, U32>, +b0: U32, p: Bytes.Bytes) -> Bytes.Bytes:
  match key:
    case Some{+k}:
      encode.frame(b0, 128, 4, k, mask(k, p))
    case None{}:
      encode.frame(b0, 0, 0, 0, p)

def encode.checked(err: Maybe<&1, U32 & String>, +fin: Bool, +op: U32, key: Maybe<&2, U32>, p: Bytes.Bytes) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match err:
    case Some{e}:
      Fail{e}
    case None{}:
      Done{encode.key(key, (Bool.pick(U32, fin, 128, 0) .|. op : U32), p)}

# A frame's octets. A client passes Some{mask key} and the payload goes masked;
# None sends it clear, as a server does. Fails on a frame that breaks rules.
def encode(f: Frame<Bytes.Bytes>, key: Maybe<&2, U32>) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  Frame{+fin, +op, payload} = f
  Bytes.Bytes{+len, buf} = payload
  encode.checked(rules(fin, 0, op, len), fin, op, key, Bytes.Bytes{len, buf})

# A frame header, read from a list of the first octets of the input.
# Ok: hs header octets, then len payload octets, masked with key when m.
type Header is Data:
  HNeed{}
  HBad{code: U32, why: String}
  HOk{fin: Bool, op: U32, m: Bool, key: U32, hs: U32, len: U32}

def header.verdict(err: Maybe<&1, U32 & String>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32) -> Header:
  match err:
    case Some{(code, why)}:
      HBad{code, why}
    case None{}:
      HOk{fin, op, m, key, hs, len}

# A 64-bit length with a high word is over any U32 max, and is a control frame over 125.
def header.err(+masked: Bool, +b0: U32, +m: Bool, +hi: U32, +len: U32) -> Maybe<&1, U32 & String>:
  first(rules(U32.is_ne((b0 .&. 128 : U32), 0), ((b0 >> 4n) .&. 7 : U32), (b0 .&. 15 : U32), Bool.pick(U32, U32.is_eq(hi, 0), len, 4294967295)),
  first(reject(Bool.xor(m, masked), 1002, "mask bit does not match the peer's role"),
    reject(U32.is_ne(hi, 0), 1009, "frame over the size limit")))

def header.check(+masked: Bool, +b0: U32, +m: Bool, +key: U32, +hs: U32, +hi: U32, +len: U32) -> Header:
  header.verdict(header.err(masked, b0, m, hi, len), U32.is_ne((b0 .&. 128 : U32), 0), (b0 .&. 15 : U32), m, key, hs, len)

# The mask key (§5.3) follows the length; its first octet is the key's low byte.
def header.key(m: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +hs: U32, +hi: U32, +len: U32) -> Header:
  match m:
    case True{}:
      match t:
        case Con{+k0, Con{+k1, Con{+k2, Con{+k3, r}}}}:
          header.check(masked, b0, True{}, (k0 .|. (k1 << 8n) .|. (k2 << 16n) .|. (k3 << 24n) : U32), (hs + 4 : U32), hi, len)
        case _:
          HNeed{}
    case False{}:
      header.check(masked, b0, False{}, 0, hs, hi, len)

def be32(+a: U32, +b: U32, +c: U32, +d: U32) -> U32:
  ((a << 24n) .|. (b << 16n) .|. (c << 8n) .|. d : U32)

def header.ext16(t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) -> Header:
  match t:
    case Con{+x, Con{+y, r}}:
      header.key(m, r, masked, b0, 4, 0, ((x << 8n) .|. y : U32))
    case _:
      HNeed{}

def header.ext64(t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) -> Header:
  match t:
    case Con{+a, Con{+b, Con{+c, Con{+d, Con{+e, Con{+f, Con{+g, Con{+h, r}}}}}}}}:
      header.key(m, r, masked, b0, 10, be32(a, b, c, d), be32(e, f, g, h))
    case _:
      HNeed{}

# short: no extended length (l7 < 126); mid: 2 octets of it (l7 == 126); else 8.
def header.ext(short: Bool, mid: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool, +l7: U32) -> Header:
  match short:
    case True{}:
      header.key(m, t, masked, b0, 2, 0, l7)
    case False{}:
      match mid:
        case True{}:
          header.ext16(t, masked, b0, m)
        case False{}:
          header.ext64(t, masked, b0, m)

def header.b1(m: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +b1: U32) -> Header:
  match m:
    case True{}:
      +l7 = (b1 - 128 : U32)
      header.ext(U32.is_lt(l7, 126), U32.is_eq(l7, 126), t, masked, b0, True{}, l7)
    case False{}:
      header.ext(U32.is_lt(b1, 126), U32.is_eq(b1, 126), t, masked, b0, False{}, b1)

# The header at the front of p, from octets below 256. It reads at most 14 octets, and is
# HNeed until all of them are in p. It is checked as soon as it is whole, before its payload.
def header(p: List<&2, U32>, +masked: Bool) -> Header:
  match p:
    case Con{+b0, Con{+b1, t}}:
      header.b1(U32.is_le(128, b1), t, masked, b0, b1)
    case _:
      HNeed{}

# The decoder, over any input S with four operations, giving payloads P:
# prefix gives at least the first 14 octets as a list; fits tells if hs + len octets are in;
# cut splits into the payload [hs, hs + len) and the input from hs + len on; unmask XORs a mask key.
def unmask.when(~P: Type, ~unmask: @+key:U32 -> P -> P, m: Bool, +key: U32, p: P) -> P:
  match m:
    case True{}:
      unmask(key, p)
    case False{}:
      p

def next.got(~P: Type, ~S: Type, ~unmask: @+key:U32 -> P -> P, +fin: Bool, +op: U32, +m: Bool, +key: U32, r: P & S) -> Decode<P, S>:
  (payload, rest) = r
  Got{Frame{fin, op, unmask.when(~P, ~unmask, m, key, payload)}, rest}

def next.fits(~P: Type, ~S: Type, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32, r: S & Bool) -> Decode<P, S>:
  (b, ok) = r
  match ok:
    case True{}:
      next.got(~P, ~S, ~unmask, fin, op, m, key, cut(b, hs, len))
    case False{}:
      Need{b}

# over: the payload is longer than max.
def next.size(~P: Type, ~S: Type, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, over: Bool, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32, b: S) -> Decode<P, S>:
  match over:
    case True{}:
      Bad{1009, "frame over the size limit"}
    case False{}:
      next.fits(~P, ~S, ~cut, ~unmask, fin, op, m, key, hs, len, fits(b, hs, len))

def next.head(~P: Type, ~S: Type, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +max: U32, h: Header, b: S) -> Decode<P, S>:
  match h:
    case HNeed{}:
      Need{b}
    case HBad{code, why}:
      Bad{code, why}
    case HOk{+fin, +op, +m, +key, +hs, +len}:
      next.size(~P, ~S, ~fits, ~cut, ~unmask, U32.is_lt(max, len), fin, op, m, key, hs, len, b)

def next.start(~P: Type, ~S: Type, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +masked: Bool, +max: U32, r: S & List<&2, U32>) -> Decode<P, S>:
  (b, p) = r
  next.head(~P, ~S, ~fits, ~cut, ~unmask, max, header(p, masked), b)

# One frame from the front of b, unmasked. masked: this peer's frames must be masked
# (true on a server, false on a client). max caps the payload length (1009 over it).
def next(~P: Type, ~S: Type, ~prefix: S -> S & List<&2, U32>, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +masked: Bool, +max: U32, b: S) -> Decode<P, S>:
  next.start(~P, ~S, ~fits, ~cut, ~unmask, masked, max, prefix(b))

# The Bytes operations. The input is a cursor: the octets in [pos, end) are not decoded
# yet. A frame moves pos past its octets; the octets stay in place, and only its payload is copied.

def bytes.prefix.con(+v: U32, r: Bytes.Bytes & List<&2, U32>) -> Bytes.Bytes & List<&2, U32>:
  (b, t) = r
  (b, Con{v, t})

def bytes.prefix.go(n: Nat, r: Bytes.Bytes & Maybe<&2, U32>, +i: U32) -> Bytes.Bytes & List<&2, U32>:
  match n:
    case 0n:
      (b, x) = r
      (b, Nil{})
    case 1n+p:
      (b, x) = r
      match x:
        case None{}:
          (b, Nil{})
        case Some{+v}:
          bytes.prefix.con(v, bytes.prefix.go(p, Bytes.get(b, (i + 1 : U32)), (i + 1 : U32)))

def bytes.prefix.back(+pos: U32, +start: U32, +end: U32, r: Bytes.Bytes & List<&2, U32>) -> Bytes.Cursor & List<&2, U32>:
  (b, t) = r
  (Bytes.Cursor{b, pos, start, end}, t)

def bytes.prefix(c: Bytes.Cursor) -> Bytes.Cursor & List<&2, U32>:
  Bytes.Cursor{b, +pos, +start, +end} = c
  bytes.prefix.back(pos, start, end, bytes.prefix.go(U32.to_nat(U32.min(14, (end - pos : U32))), Bytes.get(b, pos), pos))

# hs + len octets fit in end - pos exactly when this holds (Bytes law fits_exact); see law cut_exact.
def bytes.fits(c: Bytes.Cursor, +hs: U32, +len: U32) -> Bytes.Cursor & Bool:
  Bytes.Cursor{b, +pos, +start, +end} = c
  (Bytes.Cursor{b, pos, start, end}, Bytes.fits((end - pos : U32), hs, len))

def bytes.cut.rest(+pos: U32, +start: U32, +end: U32, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & Bytes.Cursor:
  (b, payload) = r
  (payload, Bytes.Cursor{b, pos, start, end})

def bytes.cut(c: Bytes.Cursor, +hs: U32, +len: U32) -> Bytes.Bytes & Bytes.Cursor:
  Bytes.Cursor{b, +pos, +start, +end} = c
  +at = (pos + hs : U32)
  bytes.cut.rest((at + len : U32), start, end, Bytes.slice(b, at, len))

def bytes.unmask(+key: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  mask(key, b)

# The decoder over Bytes, as recv runs it.
def parse(+masked: Bool, +max: U32, c: Bytes.Cursor) -> Decode<Bytes.Bytes, Bytes.Cursor>:
  next(~Bytes.Bytes, ~Bytes.Cursor, ~bytes.prefix, ~bytes.fits, ~bytes.cut, ~bytes.unmask, masked, max, c)

def push.when(whole: Bool, b: Bytes.Bytes, +pos: U32, +end: U32, read: Bytes.Bytes) -> Bytes.Cursor:
  match whole:
    case True{}:
      Bytes.Cursor.new(Bytes.append(b, read))
    case False{}:
      Bytes.Cursor.new(Bytes.append(Bytes.snd(Bytes.slice(b, pos, (end - pos : U32))), read))

# The input with a read after it. Decoded octets are dropped first, so each octet is
# copied once for the frame it ends up in; when there are none, the read goes into the same buffer.
def push(c: Bytes.Cursor, read: Bytes.Bytes) -> Bytes.Cursor:
  Bytes.Cursor{Bytes.Bytes{+n, buf}, +pos, start, +end} = c
  push.when(Bool.and(U32.is_eq(pos, 0), U32.is_eq(end, n)), Bytes.Bytes{n, buf}, pos, end, read)

# The list operations: the model that PROOF.bend proves the decoder on.

def list.prefix(xs: List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  +ys = xs
  (ys, ys)

def list.fits(xs: List<&2, U32>, +hs: U32, +len: U32) -> List<&2, U32> & Bool:
  +ys = xs
  (ys, Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, ys)))

def list.cut(xs: List<&2, U32>, +hs: U32, +len: U32) -> List<&2, U32> & List<&2, U32>:
  +ys = xs
  (List.take(&2, U32, List.drop(&2, U32, ys, U32.to_nat(hs)), U32.to_nat(len)),
    List.drop(&2, U32, ys, Nat.add(U32.to_nat(hs), U32.to_nat(len))))

# Octet i goes XOR key byte i mod 4; the key turns one byte per octet.
def list.unmask.go(xs: List<&2, U32>, +key: U32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+x, t}:
      Con{(x .^. (key .&. 255 : U32) : U32), list.unmask.go(t, ((key >> 8n) .|. (key << 24n) : U32))}

def list.unmask(+key: U32, xs: List<&2, U32>) -> List<&2, U32>:
  list.unmask.go(xs, key)

def list.next(+masked: Bool, +max: U32, xs: List<&2, U32>) -> Decode<List<&2, U32>, List<&2, U32>>:
  next(~List<&2, U32>, ~List<&2, U32>, ~list.prefix, ~list.fits, ~list.cut, ~list.unmask, masked, max, xs)

# UTF-8 (RFC 3629) validity. The state packs need | lo << 8 | hi << 16: continuation
# bytes still needed and the range the next one must fall in. need 255 is a failure.
def st(+need: U32, +lo: U32, +hi: U32) -> U32:
  (need .|. (lo << 8n) .|. (hi << 16n) : U32)

def utf8.lead(+b: U32) -> U32:
  Bool.pick(U32, U32.is_lt(b, 128), st(0, 128, 191),
  Bool.pick(U32, U32.is_lt(b, 194), 255,
  Bool.pick(U32, U32.is_lt(b, 224), st(1, 128, 191),
  Bool.pick(U32, U32.is_eq(b, 224), st(2, 160, 191),
  Bool.pick(U32, U32.is_eq(b, 237), st(2, 128, 159),
  Bool.pick(U32, U32.is_lt(b, 240), st(2, 128, 191),
  Bool.pick(U32, U32.is_eq(b, 240), st(3, 144, 191),
  Bool.pick(U32, U32.is_lt(b, 244), st(3, 128, 191),
  Bool.pick(U32, U32.is_eq(b, 244), st(3, 128, 143), 255)))))))))

def utf8.next(+s: U32, +b: U32) -> U32:
  +need = (s .&. 255 : U32)
  Bool.pick(U32, U32.is_eq(need, 255), 255,
  Bool.pick(U32, U32.is_eq(need, 0), utf8.lead(b),
    Bool.pick(U32, Bool.and(U32.is_le(((s >> 8n) .&. 255 : U32), b), U32.is_le(b, (s >> 16n : U32))),
      st((need - 1 : U32), 128, 191), 255)))

def utf8.go(n: Nat, r: Array<U32> & U32, +i: U32, +s: U32) -> Array<U32> & Bool:
  match n:
    case 0n:
      (a, v) = r
      (a, U32.is_eq((s .&. 255 : U32), 0))
    case 1n+p:
      (a, +b) = r
      +j = (i + 1 : U32)
      utf8.go(p, Bytes.peek(a, j), j, utf8.next(s, b))

def utf8.fin(+len: U32, r: Array<U32> & Bool) -> Bytes.Bytes & Bool:
  (a, ok) = r
  (Bytes.Bytes{len, a}, ok)

# b back, and whether it is well-formed UTF-8.
def utf8.valid(b: Bytes.Bytes) -> Bytes.Bytes & Bool:
  Bytes.Bytes{+len, buf} = b
  utf8.fin(len, utf8.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, st(0, 128, 191)))

# Messages (§5.4): fragments join into one message; control frames may come between them.

type Partial is Type:
  Idle{}
  Open{op: U32, data: Bytes.Bytes}

type Msg is Type:
  Message{op: U32, data: Bytes.Bytes}
  Control{op: U32, data: Bytes.Bytes}
  More{}

def done.text(ok: Bytes.Bytes & Bool) -> Result<&1, &1, U32 & String, Partial & Msg>:
  (d, v) = ok
  match v:
    case True{}:
      Done{(Idle{}, Message{1, d})}
    case False{}:
      Fail{(1007, "text message is not UTF-8")}

def finish(+op: U32, d: Bytes.Bytes) -> Result<&1, &1, U32 & String, Partial & Msg>:
  match op:
    case 1:
      done.text(utf8.valid(d))
    case +o:
      Done{(Idle{}, Message{o, d})}

def feed.more(fin: Bool, +op: U32, d: Bytes.Bytes) -> Result<&1, &1, U32 & String, Partial & Msg>:
  match fin:
    case True{}:
      finish(op, d)
    case False{}:
      Done{(Open{op, d}, More{})}

def feed.size(over: Bool, +fin: Bool, +op: U32, d: Bytes.Bytes) -> Result<&1, &1, U32 & String, Partial & Msg>:
  match over:
    case True{}:
      Fail{(1009, "message over the size limit")}
    case False{}:
      feed.more(fin, op, d)

def feed.join(+fin: Bool, +op: U32, d: Bytes.Bytes, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  Bytes.Bytes{+n, buf} = d
  feed.size(U32.is_gt(n, max), fin, op, Bytes.Bytes{n, buf})

def feed.data(p: Partial, +fin: Bool, +op: U32, d: Bytes.Bytes, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  match p:
    case Idle{}:
      match op:
        case 0:
          Fail{(1002, "continuation frame without a message")}
        case +o:
          feed.more(fin, o, d)
    case Open{+o, acc}:
      match op:
        case 0:
          feed.join(fin, o, Bytes.append(acc, d), max)
        case _:
          Fail{(1002, "data frame inside a fragmented message")}

def feed.kind(ctl: Bool, p: Partial, +fin: Bool, +op: U32, d: Bytes.Bytes, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  match ctl:
    case True{}:
      Done{(p, Control{op, d})}
    case False{}:
      feed.data(p, fin, op, d, max)

# One parsed frame into the message being built. A whole text message must be UTF-8
# (1007); max caps a message's total size (1009). Keep max at or below 2^31.
def feed(p: Partial, f: Frame<Bytes.Bytes>, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  Frame{+fin, +op, d} = f
  feed.kind(U32.is_ge(op, 8), p, fin, op, d, max)

# Close payloads (§5.5.1, §7.4).

# code (big-endian) then a UTF-8 reason.
def close.payload(+code: U32, reason: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.append(Bytes.set.u16be(Bytes.new(2), 0, code), reason)

# Codes a peer may send: §7.4.1, the IANA registry through 1014, and 3000-4999.
def close.code.ok(+c: U32) -> Bool:
  Bool.or(Bool.and(U32.is_ge(c, 1000), U32.is_le(c, 1003)),
    Bool.or(Bool.and(U32.is_ge(c, 1007), U32.is_le(c, 1014)),
      Bool.and(U32.is_ge(c, 3000), U32.is_le(c, 4999))))

def close.utf8(+c: U32, r: Bytes.Bytes & Bool) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  (b, ok) = r
  match ok:
    case True{}:
      Done{(c, b)}
    case False{}:
      Fail{(1007, "close reason is not UTF-8")}

def close.reason(ok: Bool, +c: U32, b: Bytes.Bytes) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  match ok:
    case False{}:
      Fail{(1002, "invalid close code")}
    case True{}:
      Bytes.Bytes{+n, buf} = b
      with_slice(Result<&1, &1, U32 & String, U32 & Bytes.Bytes>, Bytes.slice(Bytes.Bytes{n, buf}, 2, (n - 2 : U32)),
        unused => r => close.utf8(c, utf8.valid(r)))

def close.code(r: Bytes.Bytes & Maybe<&2, U32>) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  (b, m) = r
  match m:
    case Some{+c}:
      close.reason(close.code.ok(c), c, b)
    case None{}:
      Fail{(1002, "close payload of one byte")}

# The code and reason of a close frame. An empty payload is 1005 (no status).
def close.parse(p: Bytes.Bytes) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  Bytes.Bytes{+n, buf} = p
  match n:
    case 0:
      Done{(1005, Bytes.Bytes{0, buf})}
    case +m:
      close.code(Bytes.get.u16be(Bytes.Bytes{m, buf}, 0))

# Connections over Wire.

# server: this end is the server (peer frames arrive masked, ours go clear), for a socket
# an HTTP server upgraded. input holds octets read past the last frame. closing: we sent close.
type Conn is Type:
  Conn{sock: Socket, tls: Bool, server: Bool, input: Bytes.Cursor, partial: Partial, max: U32, closing: Bool}

# What recv returns. Ping is answered with a pong inside recv and not returned.
type Incoming is Type:
  Text{data: Bytes.Bytes}
  Binary{data: Bytes.Bytes}
  Pong{data: Bytes.Bytes}
  Closed{code: U32, reason: Bytes.Bytes}

def io.send.if(tls: Bool, sock: Socket, +len: U32, buf: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send.words(sock, len, buf)
    case False{}:
      Wire.send.words(sock, len, buf)

def io.send(sock: Socket, +tls: Bool, b: Bytes.Bytes) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{+len, buf} = b
  io.send.if(tls, sock, len, buf)

def io.recv(tls: Bool, sock: Socket, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match tls:
    case True{}:
      Wire.tls.recv.words(sock, 65536, ms)
    case False{}:
      Wire.recv.words(sock, 65536, ms)

def io.close(tls: Bool, sock: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(sock)
    case False{}:
      Socket.close(sock)

type Head is Type:
  HRead{r: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, acc: Bytes.Bytes}
  HSplit{sock: Socket, s: Split}

def head.loop(n: Nat, h: Head, +tls: Bool, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>):
  match n:
    case 0n:
      match h:
        case HRead{r, acc}:
          (sock, x) = r
          do IO<Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
            return (sock, Fail{(1002, "HTTP head took too many reads")})
        case HSplit{sock, s}:
          do IO<Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
            return (sock, Fail{(1002, "HTTP head took too many reads")})
    case 1n+p:
      match h:
        case HRead{r, acc}:
          match r:
            case (sock, Fail{e}):
              do IO<Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
                return (sock, Fail{e})
            case (sock, Done{(0, buf)}):
              do IO<Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
                return (sock, Fail{(1006, "connection closed before the HTTP head ended")})
            case (sock, Done{(+len, buf)}):
              head.loop(p, HSplit{sock, split(Bytes.append(acc, Bytes.Bytes{len, buf}))}, tls, ms)
        case HSplit{sock, s}:
          match s:
            case Found{head, rest}:
              do IO<Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
                return (sock, Done{(head, rest)})
            case Long{}:
              do IO<Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
                return (sock, Fail{(1002, "HTTP head over 16 KiB")})
            case Short{acc}:
              do IO<Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
                r : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv(tls, sock, ms)
                head.loop(p, HRead{r, acc}, tls, ms)

# Reads an HTTP head: the text before its blank line, and the bytes after it.
def head.read(sock: Socket, +tls: Bool, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>):
  head.loop(256n, HSplit{sock, Short{Bytes.new(0)}}, tls, ms)

def hs.fail(sock: Socket, +tls: Bool, e: U32 & String) -> IO(Result<&1, &1, U32 & String, Conn>):
  do IO<Result<&1, &1, U32 & String, Conn>>:
    io.close(tls, sock)
    return Fail{e}

def hs.checked(v: Result<&1, &1, U32 & String, Unit>, sock: Socket, +tls: Bool, +max: U32, rest: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Conn>):
  match v:
    case Fail{e}:
      hs.fail(sock, tls, e)
    case Done{u}:
      do IO<Result<&1, &1, U32 & String, Conn>>:
        return Done{Conn{sock, tls, False{}, Bytes.Cursor.new(rest), Idle{}, max, False{}}}

def hs.head(r: Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>, +tls: Bool, +max: U32, +want: String) -> IO(Result<&1, &1, U32 & String, Conn>):
  match r:
    case (sock, Fail{e}):
      hs.fail(sock, tls, e)
    case (sock, Done{(+head, rest)}):
      hs.checked(check(head, want), sock, tls, max, rest)

def hs.sent(r: Socket & Result<&1, &1, U32 & String, Unit>, +tls: Bool, +max: U32, +ms: U32, +want: String) -> IO(Result<&1, &1, U32 & String, Conn>):
  match r:
    case (sock, Fail{e}):
      hs.fail(sock, tls, e)
    case (sock, Done{u}):
      do IO<Result<&1, &1, U32 & String, Conn>>:
        h : Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes> <- head.read(sock, tls, ms)
        hs.head(h, tls, max, want)

def hs.request(q: Result<&1, &1, U32 & String, Bytes.Bytes>, sock: Socket, +tls: Bool, +max: U32, +ms: U32, +want: String) -> IO(Result<&1, &1, U32 & String, Conn>):
  match q:
    case Fail{e}:
      hs.fail(sock, tls, e)
    case Done{b}:
      do IO<Result<&1, &1, U32 & String, Conn>>:
        r : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(sock, tls, b)
        hs.sent(r, tls, max, ms, want)

def hs.accepted(a: Result<&1, &1, U32 & String, String>, sock: Socket, +tls: Bool, +host: String, +path: String, +max: U32, +ms: U32, +key: String) -> IO(Result<&1, &1, U32 & String, Conn>):
  match a:
    case Fail{e}:
      hs.fail(sock, tls, e)
    case Done{+want}:
      hs.request(request(host, path, key), sock, tls, max, ms, want)

def hs.keyed(k: Result<&1, &1, U32 & String, String>, sock: Socket, +tls: Bool, +host: String, +path: String, +max: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Conn>):
  match k:
    case Fail{e}:
      hs.fail(sock, tls, e)
    case Done{+key}:
      do IO<Result<&1, &1, U32 & String, Conn>>:
        a : Result<&1, &1, U32 & String, String> <- accept(key)
        hs.accepted(a, sock, tls, host, path, max, ms, key)

# The opening handshake on a connected socket (TLS already up when tls). host is the Host
# header and path the request target. max caps frame and message sizes. On failure the
# socket is closed. Bytes the server sent after its head stay in the Conn.
def handshake(sock: Socket, +tls: Bool, +host: String, +path: String, +max: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Conn>):
  do IO<Result<&1, &1, U32 & String, Conn>>:
    k : Result<&1, &1, U32 & String, String> <- key()
    hs.keyed(k, sock, tls, host, path, max, ms)

def connect.tls(r: Socket & Result<&1, &1, U32 & String, Unit>, +authority: String, +path: String, +max: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Conn>):
  match r:
    case (sock, Fail{e}):
      hs.fail(sock, False{}, e)
    case (sock, Done{u}):
      handshake(sock, True{}, authority, path, max, ms)

def connect.tcp(c: Result<&1, &1, U32 & String, Socket>, +tls: Bool, +host: String, +authority: String, +path: String, +max: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Conn>):
  match c:
    case Fail{e}:
      do IO<Result<&1, &1, U32 & String, Conn>>:
        return Fail{e}
    case Done{sock}:
      match tls:
        case True{}:
          do IO<Result<&1, &1, U32 & String, Conn>>:
            t : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(sock, host, ms)
            connect.tls(t, authority, path, max, ms)
        case False{}:
          handshake(sock, False{}, authority, path, max, ms)

# ws:// (tls false) or wss:// to a numeric address (resolve names with dns). host is the
# server name, for Host and TLS verification. ms bounds each socket step.
def connect(+addr: String, +port: U32, +host: String, +path: String, +tls: Bool, +max: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Conn>):
  +std = U32.is_eq(port, Bool.pick(U32, tls, 443, 80))
  +authority = Bool.pick(String, std, host, host ++ ":" ++ U32.show(port))
  do IO<Result<&1, &1, U32 & String, Conn>>:
    c : Result<&1, &1, U32 & String, Socket> <- Wire.connect(addr, port, ms)
    connect.tcp(c, tls, host, authority, path, max, ms)

def raw.encoded(e: Result<&1, &1, U32 & String, Bytes.Bytes>, sock: Socket, +tls: Bool) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match e:
    case Fail{err}:
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        return (sock, Fail{err})
    case Done{b}:
      io.send(sock, tls, b)

def raw.key(r: Array<U32> & U32, sock: Socket, +tls: Bool, +fin: Bool, +op: U32, payload: Bytes.Bytes) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  (a, +key) = r
  raw.encoded(encode(Frame{fin, op, payload}, Some{key}), sock, tls)

def raw.keyed(k: Result<&1, &1, U32 & String, U32 & Array<U32>>, sock: Socket, +tls: Bool, +fin: Bool, +op: U32, payload: Bytes.Bytes) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match k:
    case Fail{e}:
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        return (sock, Fail{e})
    case Done{(n, a)}:
      raw.key(Array.get(U32, a, 0), sock, tls, fin, op, payload)

# A client masks every frame with a fresh key from the OS secure random source (§5.3).
def raw(server: Bool, sock: Socket, +tls: Bool, +fin: Bool, +op: U32, payload: Bytes.Bytes) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match server:
    case True{}:
      raw.encoded(encode(Frame{fin, op, payload}, None{}), sock, tls)
    case False{}:
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        k : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.random.words(4)
        raw.keyed(k, sock, tls, fin, op, payload)

def back(r: Socket & Result<&1, &1, U32 & String, Unit>, +tls: Bool, +server: Bool, input: Bytes.Cursor, partial: Partial, +max: U32, +closing: Bool) -> Conn & Result<&1, &1, U32 & String, Unit>:
  (sock, x) = r
  (Conn{sock, tls, server, input, partial, max, closing}, x)

# Sends one frame: fin false starts or continues a fragmented message (later frames use op 0).
def send(c: Conn, +fin: Bool, +op: U32, payload: Bytes.Bytes) -> IO(Conn & Result<&1, &1, U32 & String, Unit>):
  Conn{sock, +tls, +server, input, partial, +max, +closing} = c
  do IO<Conn & Result<&1, &1, U32 & String, Unit>>:
    r : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, fin, op, payload)
    return back(r, tls, server, input, partial, max, closing)

# Sends a close frame; recv then runs until the peer's close comes back as Closed.
def close(c: Conn, +code: U32, reason: Bytes.Bytes) -> IO(Conn & Result<&1, &1, U32 & String, Unit>):
  Conn{sock, +tls, +server, input, partial, +max, +closing} = c
  do IO<Conn & Result<&1, &1, U32 & String, Unit>>:
    r : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 8, close.payload(code, reason))
    return back(r, tls, server, input, partial, max, True{})

# Closes the socket (and its TLS session).
def shutdown(c: Conn) -> IO(Unit):
  Conn{sock, tls, server, input, partial, max, closing} = c
  io.close(tls, sock)

type Step is Type:
  Parse{sock: Socket, input: Bytes.Cursor, partial: Partial}
  Decoded{sock: Socket, partial: Partial, d: Decode<Bytes.Bytes, Bytes.Cursor>}
  Fed{sock: Socket, rest: Bytes.Cursor, r: Result<&1, &1, U32 & String, Partial & Msg>}
  Read{r: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, input: Bytes.Cursor, partial: Partial}
  Ponged{r: Socket & Result<&1, &1, U32 & String, Unit>, input: Bytes.Cursor, partial: Partial}

def recv.out(sock: Socket, +tls: Bool, +server: Bool, input: Bytes.Cursor, partial: Partial, +max: U32, +closing: Bool, r: Result<&1, &1, U32 & String, Incoming>) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
    return (Conn{sock, tls, server, input, partial, max, closing}, r)

def recv.failed(r: Socket & Result<&1, &1, U32 & String, Unit>, +tls: Bool, +server: Bool, +max: U32, e: U32 & String) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  (sock, x) = r
  recv.out(sock, tls, server, Bytes.Cursor.new(Bytes.new(0)), Idle{}, max, True{}, Fail{e})

# A peer broke the protocol: send close with its code (§7.1.7), then report it.
def recv.fail(sock: Socket, +tls: Bool, +server: Bool, +max: U32, e: U32 & String) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  (+code, why) = e
  do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
    r : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 8, close.payload(code, Bytes.new(0)))
    recv.failed(r, tls, server, max, (code, why))

def recv.echoed(r: Socket & Result<&1, &1, U32 & String, Unit>, +tls: Bool, +server: Bool, rest: Bytes.Cursor, partial: Partial, +max: U32, +code: U32, reason: Bytes.Bytes) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  (sock, x) = r
  recv.out(sock, tls, server, rest, partial, max, True{}, Done{Closed{code, reason}})

def recv.closed(r: Result<&1, &1, U32 & String, U32 & Bytes.Bytes>, sock: Socket, +tls: Bool, +server: Bool, rest: Bytes.Cursor, partial: Partial, +max: U32, closing: Bool) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  match r:
    case Fail{e}:
      recv.fail(sock, tls, server, max, e)
    case Done{(+code, reason)}:
      match closing:
        case True{}:
          recv.out(sock, tls, server, rest, partial, max, True{}, Done{Closed{code, reason}})
        case False{}:
          echo = Bool.pick(Bytes.Bytes, U32.is_eq(code, 1005), Bytes.new(0), close.payload(code, Bytes.new(0)))
          do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
            s : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 8, echo)
            recv.echoed(s, tls, server, rest, partial, max, code, reason)

def recv.stuck(h: Step, +tls: Bool, +server: Bool, +max: U32) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  match h:
    case Parse{sock, input, partial}:
      recv.fail(sock, tls, server, max, (1011, "frame budget exhausted"))
    case Decoded{sock, partial, d}:
      recv.fail(sock, tls, server, max, (1011, "frame budget exhausted"))
    case Fed{sock, rest, r}:
      recv.fail(sock, tls, server, max, (1011, "frame budget exhausted"))
    case Read{r, input, partial}:
      (sock, x) = r
      recv.fail(sock, tls, server, max, (1011, "frame budget exhausted"))
    case Ponged{r, input, partial}:
      (sock, x) = r
      recv.fail(sock, tls, server, max, (1011, "frame budget exhausted"))

def recv.loop(n: Nat, h: Step, +tls: Bool, +server: Bool, +max: U32, +closing: Bool, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  match n:
    case 0n:
      recv.stuck(h, tls, server, max)
    case 1n+p:
      match h:
        case Parse{sock, input, partial}:
          recv.loop(p, Decoded{sock, partial, parse(server, max, input)}, tls, server, max, closing, ms)
        case Decoded{sock, partial, d}:
          match d:
            case Need{input}:
              do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
                r : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv(tls, sock, ms)
                recv.loop(p, Read{r, input, partial}, tls, server, max, closing, ms)
            case Bad{+code, why}:
              recv.fail(sock, tls, server, max, (code, why))
            case Got{f, rest}:
              recv.loop(p, Fed{sock, rest, feed(partial, f, max)}, tls, server, max, closing, ms)
        case Fed{sock, rest, r}:
          match r:
            case Fail{e}:
              recv.fail(sock, tls, server, max, e)
            case Done{(partial, ev)}:
              match ev:
                case More{}:
                  recv.loop(p, Parse{sock, rest, partial}, tls, server, max, closing, ms)
                case Message{1, d}:
                  recv.out(sock, tls, server, rest, partial, max, closing, Done{Text{d}})
                case Message{op, d}:
                  recv.out(sock, tls, server, rest, partial, max, closing, Done{Binary{d}})
                case Control{9, d}:
                  do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
                    s : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 10, d)
                    recv.loop(p, Ponged{s, rest, partial}, tls, server, max, closing, ms)
                case Control{10, d}:
                  recv.out(sock, tls, server, rest, partial, max, closing, Done{Pong{d}})
                case Control{op, d}:
                  recv.closed(close.parse(d), sock, tls, server, rest, partial, max, closing)
        case Read{r, input, partial}:
          match r:
            case (sock, Fail{e}):
              recv.out(sock, tls, server, input, partial, max, closing, Fail{e})
            case (sock, Done{(0, buf)}):
              recv.out(sock, tls, server, input, partial, max, closing, Fail{(1006, "connection closed without a close frame")})
            case (sock, Done{(+len, buf)}):
              recv.loop(p, Parse{sock, push(input, Bytes.Bytes{len, buf}), partial}, tls, server, max, closing, ms)
        case Ponged{r, input, partial}:
          match r:
            case (sock, Fail{e}):
              recv.out(sock, tls, server, input, partial, max, closing, Fail{e})
            case (sock, Done{u}):
              recv.loop(p, Parse{sock, input, partial}, tls, server, max, closing, ms)

# The next message, pong, or close. Fragments are joined and pings answered on the way.
# A protocol fault sends close with its code and fails with it. ms bounds each read.
def recv(c: Conn, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  Conn{sock, +tls, +server, input, partial, +max, +closing} = c
  recv.loop(U32.to_nat(16777216), Parse{sock, input, partial}, tls, server, max, closing, ms)
