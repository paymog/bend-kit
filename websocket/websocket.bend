# RFC 6455 WebSocket client: opening handshake, frames over packed Bytes, and messages over Wire. Source: https://github.com/paymog/bend-kit/tree/main/websocket
import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-crypto@0.2.2.2/crypto.bend as Crypto
import bend-kit-wire@0.4.9.0/wire.bend as Wire
import ./pure.bend as Pure

type Split is Type:
  Found{head: String, rest: Bytes.Bytes}
  Short{acc: Bytes.Bytes}
  Long{}

type Frame<-P: Type> is Type:
  Frame{fin: Bool, op: U32, payload: P}

type Decode<-P: Type, -S: Type> is Type:
  Need{input: S}
  Got{frame: Frame<P>, rest: S}
  Bad{code: U32, why: String}

type Header is Data:
  HNeed{}
  HBad{code: U32, why: String}
  HOk{fin: Bool, op: U32, m: Bool, key: U32, hs: U32, len: U32}

type Partial is Type:
  Idle{}
  Open{op: U32, data: Bytes.Bytes}

type Msg is Type:
  Message{op: U32, data: Bytes.Bytes}
  Control{op: U32, data: Bytes.Bytes}
  More{}

def frame.to(-P: Type, f: Frame<P>) -> Pure.Frame<P>:
  Frame{fin, op, payload} = f
  Pure.Frame{fin, op, payload}

def decode.from(-P: Type, -S: Type, d: Pure.Decode<P, S>) -> Decode<P, S>:
  match d:
    case Pure.Need{input}:
      Need{input}
    case Pure.Got{Pure.Frame{fin, op, payload}, rest}:
      Got{Frame{fin, op, payload}, rest}
    case Pure.Bad{code, why}:
      Bad{code, why}

def header.to(h: Header) -> Pure.Header:
  match h:
    case HNeed{}:
      Pure.HNeed{}
    case HBad{code, why}:
      Pure.HBad{code, why}
    case HOk{fin, op, m, key, hs, len}:
      Pure.HOk{fin, op, m, key, hs, len}

def header.from(h: Pure.Header) -> Header:
  match h:
    case Pure.HNeed{}:
      HNeed{}
    case Pure.HBad{code, why}:
      HBad{code, why}
    case Pure.HOk{fin, op, m, key, hs, len}:
      HOk{fin, op, m, key, hs, len}

def split.from(s: Pure.Split) -> Split:
  match s:
    case Pure.Found{head, rest}:
      Found{head, rest}
    case Pure.Short{acc}:
      Short{acc}
    case Pure.Long{}:
      Long{}

def partial.to(p: Partial) -> Pure.Partial:
  match p:
    case Idle{}:
      Pure.Idle{}
    case Open{op, data}:
      Pure.Open{op, data}

def partial.from(p: Pure.Partial) -> Partial:
  match p:
    case Pure.Idle{}:
      Idle{}
    case Pure.Open{op, data}:
      Open{op, data}

def msg.from(m: Pure.Msg) -> Msg:
  match m:
    case Pure.Message{op, data}:
      Message{op, data}
    case Pure.Control{op, data}:
      Control{op, data}
    case Pure.More{}:
      More{}

def message.from(r: Result<&1, &1, U32 & String, Pure.Partial & Pure.Msg>) -> Result<&1, &1, U32 & String, Partial & Msg>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(p, m)}:
      Done{(partial.from(p), msg.from(m))}


# Errors are (code, why). A code of 1000 or more is the RFC 6455 §7.4 close code the
# peer broke (1002 protocol, 1006 closed early, 1007 bad UTF-8, 1009 too big, 1011 budget);
# a smaller code is the errno of a socket or crypto effect.
# Opcodes (§5.2): 0 continuation, 1 text, 2 binary, 8 close, 9 ping, 10 pong.

# Opening handshake (§4.1, §4.2.2).

def guid() -> String:
  Pure.guid()

# The octets SHA-1 hashes for Sec-WebSocket-Accept: the key, then the GUID.
def accept.input(key: String) -> Bytes.Bytes:
  Pure.accept.input(key)

# Sec-WebSocket-Accept from the SHA-1 digest of accept.input(key).
def accept.of(digest: Bytes.Bytes) -> String:
  Pure.accept.of(digest)

def accept.fin(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, String>:
  Pure.accept.fin(r)

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
  Pure.key.of(nonce)

def key.fin(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, String>:
  Pure.key.fin(r)

# A fresh key from 16 octets of the OS secure random source.
def key() -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.random.words(16)
    return key.fin(r)

def first(m: Maybe<&1, U32 & String>, n: Maybe<&1, U32 & String>) -> Maybe<&1, U32 & String>:
  Pure.first(m, n)

def reject(bad: Bool, +code: U32, +why: String) -> Maybe<&1, U32 & String>:
  Pure.reject(bad, code, why)

def verdict(-A: Type, m: Maybe<&1, U32 & String>, v: A) -> Result<&1, &1, U32 & String, A>:
  Pure.verdict(A, m, v)

# Every char is visible ASCII (0x21-0x7E): no space, CR, LF, or other control.
def visible(s: String) -> Bool:
  Pure.visible(s)

# The GET that asks to upgrade. host is the Host header (with :port when not the default);
# path is the origin-form target ("/" and on, percent-encoded). A char outside visible
# ASCII could split the head and inject headers, so it fails with EINVAL (22).
def request(+host: String, +path: String, +key: String) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  Pure.request(host, path, key)

def fields.line(parts: List<&2, String>, +name: String, +later: List<&2, String>) -> List<&2, String>:
  Pure.fields.line(parts, name, later)

def fields.go(ls: List<&2, String>, +name: String) -> List<&2, String>:
  Pure.fields.go(ls, name)

def after.first(ls: List<&2, String>) -> List<&2, String>:
  Pure.after.first(ls)

# The header lines of an HTTP head: every line after the start line.
def headers(head: String) -> List<&2, String>:
  Pure.headers(head)

# The trimmed values of every header line named name (lowercase), in order.
def fields(head: String, +name: String) -> List<&2, String>:
  Pure.fields(head, name)

def only(xs: List<&2, String>) -> Maybe<&2, String>:
  Pure.only(xs)

# The value of the header named name when exactly one line has it.
def field(head: String, +name: String) -> Maybe<&2, String>:
  Pure.field(head, name)

# A header line is name ":" value, with a non-empty name that holds no space or tab
# (RFC 9112 §5.1). That rules out obsolete line folding and bare text.
def line.parts(parts: List<&2, String>) -> Bool:
  Pure.line.parts(parts)

def lines.ok(ls: List<&2, String>) -> Bool:
  Pure.lines.ok(ls)

def status.parts(parts: List<&2, String>) -> Bool:
  Pure.status.parts(parts)

# The first line is exactly "HTTP/1.1 101" and a reason, with nothing before it.
def status(ls: List<&2, String>) -> Bool:
  Pure.status(ls)

def token(xs: List<&2, String>, +want: String) -> Bool:
  Pure.token(xs, want)

def value.is(m: Maybe<&2, String>, +want: String) -> Bool:
  Pure.value.is(m, want)

def value.lower(m: Maybe<&2, String>) -> Maybe<&2, String>:
  Pure.value.lower(m)

# Connection is a list header: its lines join into one comma list (RFC 9110 §5.3).
def tokens(xs: List<&2, String>, +want: String) -> Bool:
  Pure.tokens(xs, want)

def none(xs: List<&2, String>) -> Bool:
  Pure.none(xs)

# Does a server's head (up to its blank line) accept the upgrade? want is accept(key).
# Upgrade and Sec-WebSocket-Accept must each come once. No extension or subprotocol
# was asked for, so the server may name none (§4.1).
def check(+head: String, +want: String) -> Result<&1, &1, U32 & String, Unit>:
  Pure.check(head, want)

def with_slice(-R: Type, r: Bytes.Bytes & Bytes.Bytes, k: Bytes.Bytes -> Bytes.Bytes -> R) -> R:
  Pure.with_slice(R, r, k)

# An HTTP head cut at its blank line, with the bytes after it.
def split.long(long: Bool, b: Bytes.Bytes) -> Split:
  split.from(Pure.split.long(long, b))

def split.short(b: Bytes.Bytes) -> Split:
  split.from(Pure.split.short(b))

def split.found(r: Bytes.Bytes & Maybe<&2, U32>) -> Split:
  split.from(Pure.split.found(r))

# Found once b holds "\r\n\r\n"; Long when 16 KiB came without it.
def split(b: Bytes.Bytes) -> Split:
  split.from(Pure.split(b))

# Frames (§5.2).

# The payload P is Bytes at run time and a List of octets in the proofs.
# Need: the input does not hold a whole frame yet, and comes back intact.
# Got: one frame, and the octets after it. Bad: the input breaks §5.2 whatever comes next.
def mask.go(n: Nat, r: Array<U32> & U32, +i: U32, +key: U32) -> Array<U32>:
  Pure.mask.go(n, r, i, key)

def mask.trim.word(+k: U32, +m: U32, r: Array<U32> & U32) -> Array<U32>:
  Pure.mask.trim.word(k, m, r)

def mask.trim.if(whole: Bool, +k: U32, +m: U32, a: Array<U32>) -> Array<U32>:
  Pure.mask.trim.if(whole, k, m, a)

# Bytes at or past len stay 0, as Bytes requires.
def mask.trim(+len: U32, a: Array<U32>) -> Array<U32>:
  Pure.mask.trim(len, a)

# The payload XOR the mask key (§5.3), a word at a time. key's byte k (low first) is mask octet k.
# Masking twice gives the payload back.
def mask(+key: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Pure.mask(key, b)

def known(+op: U32) -> Bool:
  Pure.known(op)

# The §5.2 and §5.5 rules on a frame header. No extension is in use, so RSV must be 0.
# big: the payload is over 125 octets.
def rules.big(+fin: Bool, +rsv: U32, +op: U32, big: Bool) -> Maybe<&1, U32 & String>:
  Pure.rules.big(fin, rsv, op, big)

def rules(+fin: Bool, +rsv: U32, +op: U32, +len: U32) -> Maybe<&1, U32 & String>:
  Pure.rules(fin, rsv, op, len)

def encode.ext(+ext: U32, +len: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Pure.encode.ext(ext, len, b)

def encode.mkey(+keylen: U32, +at: U32, +key: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Pure.encode.mkey(keylen, at, key, b)

def encode.copy(+len: U32, src: Array<U32>, +hs: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Pure.encode.copy(len, src, hs, b)

# Payload lengths use the shortest form (§5.2): 7 bits, then 16, then 64.
def encode.frame(+b0: U32, +mbit: U32, +keylen: U32, +key: U32, p: Bytes.Bytes) -> Bytes.Bytes:
  Pure.encode.frame(b0, mbit, keylen, key, p)

def encode.key(key: Maybe<&2, U32>, +b0: U32, p: Bytes.Bytes) -> Bytes.Bytes:
  Pure.encode.key(key, b0, p)

def encode.checked(err: Maybe<&1, U32 & String>, +fin: Bool, +op: U32, key: Maybe<&2, U32>, p: Bytes.Bytes) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  Pure.encode.checked(err, fin, op, key, p)

# A frame's octets. A client passes Some{mask key} and the payload goes masked;
# None sends it clear, as a server does. Fails on a frame that breaks rules.
def encode(f: Frame<Bytes.Bytes>, key: Maybe<&2, U32>) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  Pure.encode(frame.to(Bytes.Bytes, f), key)

# A frame header, read from a list of the first octets of the input.
# Ok: hs header octets, then len payload octets, masked with key when m.
def header.verdict(err: Maybe<&1, U32 & String>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32) -> Header:
  header.from(Pure.header.verdict(err, fin, op, m, key, hs, len))

# A 64-bit length with a high word is over any U32 max, and is a control frame over 125.
def header.err(+masked: Bool, +b0: U32, +m: Bool, +hi: U32, +len: U32) -> Maybe<&1, U32 & String>:
  Pure.header.err(masked, b0, m, hi, len)

def header.check(+masked: Bool, +b0: U32, +m: Bool, +key: U32, +hs: U32, +hi: U32, +len: U32) -> Header:
  header.from(Pure.header.check(masked, b0, m, key, hs, hi, len))

# Four octets, most significant first. Multiply and add, not shift and or: the proofs reason about them over Nat.
def be32(+a: U32, +b: U32, +c: U32, +d: U32) -> U32:
  Pure.be32(a, b, c, d)

# The mask key (§5.3) follows the length; its first octet is the key's low byte.
def header.key(m: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +hs: U32, +hi: U32, +len: U32) -> Header:
  header.from(Pure.header.key(m, t, masked, b0, hs, hi, len))

def header.ext16(t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) -> Header:
  header.from(Pure.header.ext16(t, masked, b0, m))

def header.ext64(t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) -> Header:
  header.from(Pure.header.ext64(t, masked, b0, m))

# short: no extended length (l7 < 126); mid: 2 octets of it (l7 == 126); else 8.
def header.ext(short: Bool, mid: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool, +l7: U32) -> Header:
  header.from(Pure.header.ext(short, mid, t, masked, b0, m, l7))

def header.b1(m: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +b1: U32) -> Header:
  header.from(Pure.header.b1(m, t, masked, b0, b1))

# The header at the front of p, from octets below 256. It reads at most 14 octets, and is
# HNeed until all of them are in p. It is checked as soon as it is whole, before its payload.
def header(p: List<&2, U32>, +masked: Bool) -> Header:
  header.from(Pure.header(p, masked))

# The decoder, over any input S with four operations, giving payloads P:
# prefix gives at least the first 14 octets as a list; fits tells if hs + len octets are in;
# cut splits into the payload [hs, hs + len) and the input from hs + len on; unmask XORs a mask key.
def unmask.when(~P: Type, ~unmask: @+key:U32 -> P -> P, m: Bool, +key: U32, p: P) -> P:
  Pure.unmask.when(~P, ~unmask, m, key, p)

def next.got(~P: Type, ~S: Type, ~unmask: @+key:U32 -> P -> P, +fin: Bool, +op: U32, +m: Bool, +key: U32, r: P & S) -> Decode<P, S>:
  decode.from(P, S, Pure.next.got(~P, ~S, ~unmask, fin, op, m, key, r))

def next.fits(~P: Type, ~S: Type, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32, r: S & Bool) -> Decode<P, S>:
  decode.from(P, S, Pure.next.fits(~P, ~S, ~cut, ~unmask, fin, op, m, key, hs, len, r))

# over: the payload is longer than max.
def next.size(~P: Type, ~S: Type, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, over: Bool, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32, b: S) -> Decode<P, S>:
  decode.from(P, S, Pure.next.size(~P, ~S, ~fits, ~cut, ~unmask, over, fin, op, m, key, hs, len, b))

def next.head(~P: Type, ~S: Type, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +max: U32, h: Header, b: S) -> Decode<P, S>:
  decode.from(P, S, Pure.next.head(~P, ~S, ~fits, ~cut, ~unmask, max, header.to(h), b))

def next.start(~P: Type, ~S: Type, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +masked: Bool, +max: U32, r: S & List<&2, U32>) -> Decode<P, S>:
  decode.from(P, S, Pure.next.start(~P, ~S, ~fits, ~cut, ~unmask, masked, max, r))

# One frame from the front of b, unmasked. masked: this peer's frames must be masked
# (true on a server, false on a client). max caps the payload length (1009 over it).
def next(~P: Type, ~S: Type, ~prefix: S -> S & List<&2, U32>, ~fits: S -> @+hs:U32 -> @+len:U32 -> S & Bool, ~cut: S -> @+hs:U32 -> @+len:U32 -> P & S, ~unmask: @+key:U32 -> P -> P, +masked: Bool, +max: U32, b: S) -> Decode<P, S>:
  decode.from(P, S, Pure.next(~P, ~S, ~prefix, ~fits, ~cut, ~unmask, masked, max, b))

# The Bytes operations. The input is a cursor: the octets in [pos, end) are not decoded
# yet. A frame moves pos past its octets; the octets stay in place, and only its payload is copied.

def bytes.prefix.con(+v: U32, r: Bytes.Bytes & List<&2, U32>) -> Bytes.Bytes & List<&2, U32>:
  Pure.bytes.prefix.con(v, r)

def bytes.prefix.go(n: Nat, r: Bytes.Bytes & Maybe<&2, U32>, +i: U32) -> Bytes.Bytes & List<&2, U32>:
  Pure.bytes.prefix.go(n, r, i)

def bytes.prefix.back(+pos: U32, +start: U32, +end: U32, r: Bytes.Bytes & List<&2, U32>) -> Bytes.Cursor & List<&2, U32>:
  Pure.bytes.prefix.back(pos, start, end, r)

def bytes.prefix(c: Bytes.Cursor) -> Bytes.Cursor & List<&2, U32>:
  Pure.bytes.prefix(c)

# hs + len octets fit in end - pos exactly when this holds (Bytes law fits_exact); see law cut_exact.
def bytes.fits(c: Bytes.Cursor, +hs: U32, +len: U32) -> Bytes.Cursor & Bool:
  Pure.bytes.fits(c, hs, len)

def bytes.cut.rest(+pos: U32, +start: U32, +end: U32, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & Bytes.Cursor:
  Pure.bytes.cut.rest(pos, start, end, r)

def bytes.cut(c: Bytes.Cursor, +hs: U32, +len: U32) -> Bytes.Bytes & Bytes.Cursor:
  Pure.bytes.cut(c, hs, len)

def bytes.unmask(+key: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  Pure.bytes.unmask(key, b)

# The decoder over Bytes, as recv runs it.
def parse(+masked: Bool, +max: U32, c: Bytes.Cursor) -> Decode<Bytes.Bytes, Bytes.Cursor>:
  decode.from(Bytes.Bytes, Bytes.Cursor, Pure.parse(masked, max, c))

def push.when(whole: Bool, b: Bytes.Bytes, +pos: U32, +end: U32, read: Bytes.Bytes) -> Bytes.Cursor:
  Pure.push.when(whole, b, pos, end, read)

# The input with a read after it. Decoded octets are dropped first, so each octet is
# copied once for the frame it ends up in; when there are none, the read goes into the same buffer.
def push(c: Bytes.Cursor, read: Bytes.Bytes) -> Bytes.Cursor:
  Pure.push(c, read)

# The list operations: the model that PROOF.bend proves the decoder on.

def list.prefix(xs: List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  Pure.list.prefix(xs)

def list.fits(xs: List<&2, U32>, +hs: U32, +len: U32) -> List<&2, U32> & Bool:
  Pure.list.fits(xs, hs, len)

def list.cut(xs: List<&2, U32>, +hs: U32, +len: U32) -> List<&2, U32> & List<&2, U32>:
  Pure.list.cut(xs, hs, len)

# Octet i goes XOR key octet i mod 4 (§5.3): a, b, c, d are the key's octets, low first, and turn one place per octet.
def list.unmask.go(xs: List<&2, U32>, +a: U32, +b: U32, +c: U32, +d: U32) -> List<&2, U32>:
  Pure.list.unmask.go(xs, a, b, c, d)

def list.unmask(+key: U32, xs: List<&2, U32>) -> List<&2, U32>:
  Pure.list.unmask(key, xs)

def list.next(+masked: Bool, +max: U32, xs: List<&2, U32>) -> Decode<List<&2, U32>, List<&2, U32>>:
  decode.from(List<&2, U32>, List<&2, U32>, Pure.list.next(masked, max, xs))

# UTF-8 (RFC 3629) validity. The state packs need | lo << 8 | hi << 16: continuation
# bytes still needed and the range the next one must fall in. need 255 is a failure.
def st(+need: U32, +lo: U32, +hi: U32) -> U32:
  Pure.st(need, lo, hi)

def utf8.lead(+b: U32) -> U32:
  Pure.utf8.lead(b)

def utf8.next(+s: U32, +b: U32) -> U32:
  Pure.utf8.next(s, b)

def utf8.go(n: Nat, r: Array<U32> & U32, +i: U32, +s: U32) -> Array<U32> & Bool:
  Pure.utf8.go(n, r, i, s)

def utf8.fin(+len: U32, r: Array<U32> & Bool) -> Bytes.Bytes & Bool:
  Pure.utf8.fin(len, r)

# b back, and whether it is well-formed UTF-8.
def utf8.valid(b: Bytes.Bytes) -> Bytes.Bytes & Bool:
  Pure.utf8.valid(b)

# Messages (§5.4): fragments join into one message; control frames may come between them.

def done.text(ok: Bytes.Bytes & Bool) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.done.text(ok))

def finish(+op: U32, d: Bytes.Bytes) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.finish(op, d))

def feed.more(fin: Bool, +op: U32, d: Bytes.Bytes) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.feed.more(fin, op, d))

def feed.size(over: Bool, +fin: Bool, +op: U32, d: Bytes.Bytes) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.feed.size(over, fin, op, d))

def feed.join(+fin: Bool, +op: U32, d: Bytes.Bytes, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.feed.join(fin, op, d, max))

def feed.data(p: Partial, +fin: Bool, +op: U32, d: Bytes.Bytes, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.feed.data(partial.to(p), fin, op, d, max))

def feed.kind(ctl: Bool, p: Partial, +fin: Bool, +op: U32, d: Bytes.Bytes, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.feed.kind(ctl, partial.to(p), fin, op, d, max))

# One parsed frame into the message being built. A whole text message must be UTF-8
# (1007); max caps a message's total size (1009). Keep max at or below 2^31.
def feed(p: Partial, f: Frame<Bytes.Bytes>, +max: U32) -> Result<&1, &1, U32 & String, Partial & Msg>:
  message.from(Pure.feed(partial.to(p), frame.to(Bytes.Bytes, f), max))

# Close payloads (§5.5.1, §7.4).

# code (big-endian) then a UTF-8 reason.
def close.payload(+code: U32, reason: Bytes.Bytes) -> Bytes.Bytes:
  Pure.close.payload(code, reason)

# Codes a peer may send: §7.4.1, the IANA registry through 1014, and 3000-4999.
def close.code.ok(+c: U32) -> Bool:
  Pure.close.code.ok(c)

def close.utf8(+c: U32, r: Bytes.Bytes & Bool) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  Pure.close.utf8(c, r)

def close.reason(ok: Bool, +c: U32, b: Bytes.Bytes) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  Pure.close.reason(ok, c, b)

def close.code(r: Bytes.Bytes & Maybe<&2, U32>) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  Pure.close.code(r)

# The code and reason of a close frame. An empty payload is 1005 (no status).
def close.parse(p: Bytes.Bytes) -> Result<&1, &1, U32 & String, U32 & Bytes.Bytes>:
  Pure.close.parse(p)

# Connections over Wire.

# server: this end is the server (peer frames arrive masked, ours go clear), for a socket
# an HTTP server upgraded. input holds octets read past the last frame. closing: we sent close.
type Conn is Type:
  Conn{sock: Socket, tls: Bool, server: Bool, input: Bytes.Cursor, partial: Partial, max: U32, closing: Bool}

# What recv returns. Ping is answered with a pong inside recv and not returned.
type Incoming is Type:
  TextMessage{data: Bytes.Bytes}
  Binary{data: Bytes.Bytes}
  Pong{data: Bytes.Bytes}
  Closed{code: U32, reason: Bytes.Bytes}

def io.send.unwrap(p: Socket & (U32 & Result<&1, &1, U32 & String, Unit>)) -> Socket & Result<&1, &1, U32 & String, Unit>:
  (sock, (_, r)) = p
  (sock, r)

def io.send.if(tls: Bool, bounded: Bool, sock: Socket, +len: U32, buf: Array<U32>, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      match bounded:
        case True{}:
          do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
            p : Socket & (U32 & Result<&1, &1, U32 & String, Unit>) <- Wire.tls.send.words.deadline(sock, len, buf, ms)
            return io.send.unwrap(p)
        case False{}:
          Wire.tls.send.words(sock, len, buf)
    case False{}:
      match bounded:
        case True{}:
          do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
            p : Socket & (U32 & Result<&1, &1, U32 & String, Unit>) <- Wire.send.words.deadline(sock, len, buf, ms)
            return io.send.unwrap(p)
        case False{}:
          Wire.send.words(sock, len, buf)

def io.send(sock: Socket, +tls: Bool, b: Bytes.Bytes, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{+len, buf} = b
  io.send.if(tls, Bool.not(U32.is_zero(ms)), sock, len, buf, ms)

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
        r : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(sock, tls, b, ms)
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

def raw.encoded(e: Result<&1, &1, U32 & String, Bytes.Bytes>, sock: Socket, +tls: Bool, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match e:
    case Fail{err}:
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        return (sock, Fail{err})
    case Done{b}:
      io.send(sock, tls, b, ms)

def raw.key(r: Array<U32> & U32, sock: Socket, +tls: Bool, +fin: Bool, +op: U32, payload: Bytes.Bytes, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  (a, +key) = r
  raw.encoded(encode(Frame{fin, op, payload}, Some{key}), sock, tls, ms)

def raw.keyed(k: Result<&1, &1, U32 & String, U32 & Array<U32>>, sock: Socket, +tls: Bool, +fin: Bool, +op: U32, payload: Bytes.Bytes, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match k:
    case Fail{e}:
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        return (sock, Fail{e})
    case Done{(n, a)}:
      raw.key(Array.get(U32, a, 0), sock, tls, fin, op, payload, ms)

# A client masks every frame with a fresh key from the OS secure random source (§5.3).
def raw(server: Bool, sock: Socket, +tls: Bool, +fin: Bool, +op: U32, payload: Bytes.Bytes, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match server:
    case True{}:
      raw.encoded(encode(Frame{fin, op, payload}, None{}), sock, tls, ms)
    case False{}:
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        k : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.random.words(4)
        raw.keyed(k, sock, tls, fin, op, payload, ms)

def back(r: Socket & Result<&1, &1, U32 & String, Unit>, +tls: Bool, +server: Bool, input: Bytes.Cursor, partial: Partial, +max: U32, +closing: Bool) -> Conn & Result<&1, &1, U32 & String, Unit>:
  (sock, x) = r
  (Conn{sock, tls, server, input, partial, max, closing}, x)

# Sends one frame: fin false starts or continues a fragmented message (later frames use op 0).
# ms bounds the write (0: none, 1..2147483647: deadline in ms). On timeout/write error,
# framing and TLS state may be half-flushed: call shutdown, do not send or close again.
def send(c: Conn, +fin: Bool, +op: U32, payload: Bytes.Bytes, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Unit>):
  Conn{sock, +tls, +server, input, partial, +max, +closing} = c
  do IO<Conn & Result<&1, &1, U32 & String, Unit>>:
    r : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, fin, op, payload, ms)
    return back(r, tls, server, input, partial, max, closing)

# Sends a close frame; recv then runs until the peer's close comes back as Closed.
# ms bounds the write (0: none, 1..2147483647: deadline in ms). On timeout/write error,
# call shutdown and do not send or close again.
def close(c: Conn, +code: U32, reason: Bytes.Bytes, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Unit>):
  Conn{sock, +tls, +server, input, partial, +max, +closing} = c
  do IO<Conn & Result<&1, &1, U32 & String, Unit>>:
    r : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 8, close.payload(code, reason), ms)
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
def recv.fail(sock: Socket, +tls: Bool, +server: Bool, +max: U32, +ms: U32, e: U32 & String) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  (+code, why) = e
  do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
    r : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 8, close.payload(code, Bytes.new(0)), ms)
    recv.failed(r, tls, server, max, (code, why))

def recv.echoed(r: Socket & Result<&1, &1, U32 & String, Unit>, +tls: Bool, +server: Bool, rest: Bytes.Cursor, partial: Partial, +max: U32, +code: U32, reason: Bytes.Bytes) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  (sock, x) = r
  recv.out(sock, tls, server, rest, partial, max, True{}, Done{Closed{code, reason}})

def recv.closed(r: Result<&1, &1, U32 & String, U32 & Bytes.Bytes>, sock: Socket, +tls: Bool, +server: Bool, rest: Bytes.Cursor, partial: Partial, +max: U32, closing: Bool, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  match r:
    case Fail{e}:
      recv.fail(sock, tls, server, max, ms, e)
    case Done{(+code, reason)}:
      match closing:
        case True{}:
          recv.out(sock, tls, server, rest, partial, max, True{}, Done{Closed{code, reason}})
        case False{}:
          echo = Bool.pick(Bytes.Bytes, U32.is_eq(code, 1005), Bytes.new(0), close.payload(code, Bytes.new(0)))
          do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
            s : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 8, echo, ms)
            recv.echoed(s, tls, server, rest, partial, max, code, reason)

def recv.stuck(h: Step, +tls: Bool, +server: Bool, +max: U32, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  match h:
    case Parse{sock, input, partial}:
      recv.fail(sock, tls, server, max, ms, (1011, "frame budget exhausted"))
    case Decoded{sock, partial, d}:
      recv.fail(sock, tls, server, max, ms, (1011, "frame budget exhausted"))
    case Fed{sock, rest, r}:
      recv.fail(sock, tls, server, max, ms, (1011, "frame budget exhausted"))
    case Read{r, input, partial}:
      (sock, x) = r
      recv.fail(sock, tls, server, max, ms, (1011, "frame budget exhausted"))
    case Ponged{r, input, partial}:
      (sock, x) = r
      recv.fail(sock, tls, server, max, ms, (1011, "frame budget exhausted"))

def recv.loop(n: Nat, h: Step, +tls: Bool, +server: Bool, +max: U32, +closing: Bool, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  match n:
    case 0n:
      recv.stuck(h, tls, server, max, ms)
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
              recv.fail(sock, tls, server, max, ms, (code, why))
            case Got{f, rest}:
              recv.loop(p, Fed{sock, rest, feed(partial, f, max)}, tls, server, max, closing, ms)
        case Fed{sock, rest, r}:
          match r:
            case Fail{e}:
              recv.fail(sock, tls, server, max, ms, e)
            case Done{(partial, ev)}:
              match ev:
                case More{}:
                  recv.loop(p, Parse{sock, rest, partial}, tls, server, max, closing, ms)
                case Message{1, d}:
                  recv.out(sock, tls, server, rest, partial, max, closing, Done{TextMessage{d}})
                case Message{op, d}:
                  recv.out(sock, tls, server, rest, partial, max, closing, Done{Binary{d}})
                case Control{9, d}:
                  do IO<Conn & Result<&1, &1, U32 & String, Incoming>>:
                    s : Socket & Result<&1, &1, U32 & String, Unit> <- raw(server, sock, tls, True{}, 10, d, ms)
                    recv.loop(p, Ponged{s, rest, partial}, tls, server, max, closing, ms)
                case Control{10, d}:
                  recv.out(sock, tls, server, rest, partial, max, closing, Done{Pong{d}})
                case Control{op, d}:
                  recv.closed(close.parse(d), sock, tls, server, rest, partial, max, closing, ms)
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
# A protocol fault sends close with its code and fails with it. ms bounds each read and
# internal control-frame write.
def recv(c: Conn, +ms: U32) -> IO(Conn & Result<&1, &1, U32 & String, Incoming>):
  Conn{sock, +tls, +server, input, partial, +max, +closing} = c
  recv.loop(U32.to_nat(16777216), Parse{sock, input, partial}, tls, server, max, closing, ms)
