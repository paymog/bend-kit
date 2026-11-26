# Pure journal framing, recovery, and list model.
import Base
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import bend-kit-hash@0.3.2.3/hash.bend as Hash

# A frame is one record and one commit: three u32 little-endian fields, then the payload.
# len, then U32.not(len), then the CRC-32 of the payload, then len payload octets.
# A frame is committed when all 12 + len of its octets are in the file.

# Clean: the input ends on a frame boundary.
# Torn: the input ends inside a frame. A crash cut the last append short.
# Corrupt: a whole header or a whole frame fails its check. Recovery does not go past it.
type Tail is Data:
  Clean{}
  Torn{}
  Corrupt{why: String}

# One decoding step. Short, Bad, and End give the input back untouched, at the frame start.
type Step<-P: Type, -S: Type> is Type:
  End{s: S}
  Short{s: S}
  Bad{why: String, s: S}
  Got{p: P, s: S}

# The committed records in order, how the input ends, and the input from the first frame not taken.
type Recovery<a, -P: Kind(a), -S: Type> is Type:
  Recovery{records: List<a, P>, tail: Tail, rest: S}

# The state after every committed record, how the input ends, and the input from the first frame not taken.
type Replay<-A: Type, -S: Type> is Type:
  Replay{acc: A, tail: Tail, rest: S}

# The decoder is generic over the input S and the payload P. Bytes runs it; a list of octets proves it.
# fits(s, at, n): n octets from at fit in s. u32(s, at): the field at at. cut(s, hs, len): a copy of
# [hs, hs + len). skip(s, hs, len): s from hs + len. sum(p): the checksum of p.

def next.verdict(~P: Type, ~S: Type, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ok: Bool, +len: U32, s: S, p: P) -> Step<P, S>:
  match ok:
    case True{}:
      Got{p, skip(s, 12, len)}
    case False{}:
      Bad{"checksum mismatch", s}

def next.summed(~P: Type, ~S: Type, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, +want: U32, +len: U32, s: S, r: P & U32) -> Step<P, S>:
  (p, +got) = r
  next.verdict(~P, ~S, ~skip, U32.is_eq(got, want), len, s, p)

def next.cut(~P: Type, ~S: Type, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +want: U32, +len: U32, r: S & P) -> Step<P, S>:
  (s, p) = r
  next.summed(~P, ~S, ~skip, want, len, s, sum(p))

def next.want(~P: Type, ~S: Type, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +len: U32, r: S & U32) -> Step<P, S>:
  (s, +want) = r
  next.cut(~P, ~S, ~skip, ~sum, want, len, cut(s, 12, len))

def next.body(~P: Type, ~S: Type, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +len: U32, r: S & Bool) -> Step<P, S>:
  (s, whole) = r
  match whole:
    case True{}:
      next.want(~P, ~S, ~cut, ~skip, ~sum, len, u32(s, 8))
    case False{}:
      Short{s}

def next.size(~P: Type, ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, over: Bool, +len: U32, s: S) -> Step<P, S>:
  match over:
    case True{}:
      Bad{"length over max", s}
    case False{}:
      next.body(~P, ~S, ~u32, ~cut, ~skip, ~sum, len, fits(s, 12, len))

def next.head(~P: Type, ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, ok: Bool, +max: U32, +len: U32, s: S) -> Step<P, S>:
  match ok:
    case True{}:
      next.size(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, U32.is_gt(len, max), len, s)
    case False{}:
      Bad{"length check mismatch", s}

def next.lenx(~P: Type, ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +max: U32, +len: U32, r: S & U32) -> Step<P, S>:
  (s, +lenx) = r
  next.head(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, U32.is_eq(lenx, U32.not(len)), max, len, s)

def next.len(~P: Type, ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +max: U32, r: S & U32) -> Step<P, S>:
  (s, +len) = r
  next.lenx(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, len, u32(s, 4))

# The two length fields are checked before the payload is waited for, so a damaged length is
# Bad and never a Torn tail that hides the frames after it.
def next.start(~P: Type, ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +max: U32, r: S & Bool) -> Step<P, S>:
  (s, both) = r
  match both:
    case True{}:
      next.len(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, u32(s, 0))
    case False{}:
      Short{s}

def next.any(~P: Type, ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +max: U32, r: S & Bool) -> Step<P, S>:
  (s, some) = r
  match some:
    case True{}:
      next.start(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, fits(s, 0, 8))
    case False{}:
      End{s}

# One frame from s. max caps a payload's length.
def next(~P: Type, ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, +max: U32, s: S) -> Step<P, S>:
  next.any(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, fits(s, 0, 1))

def recover.con(~a: Quant, ~P: Kind(a), ~S: Type, p: P, r: Recovery<a, P, S>) -> Recovery<a, P, S>:
  Recovery{rs, t, s} = r
  Recovery{Con{p, rs}, t, s}

# Every frame from st on. Once n frames are taken, the next one is the last: the tail is Corrupt,
# and rest starts after it. Callers give n at least the frame count, so this never happens.
def recover.go(~a: Quant, ~P: Kind(a), ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, n: Nat, +max: U32, st: Step<P, S>) -> Recovery<a, P, S>:
  match n st:
    case 0n End{s}:
      Recovery{Nil{}, Clean{}, s}
    case 0n Short{s}:
      Recovery{Nil{}, Torn{}, s}
    case 0n Bad{why, s}:
      Recovery{Nil{}, Corrupt{why}, s}
    case 0n Got{p, s}:
      Recovery{Con{p, Nil{}}, Corrupt{"frame budget exhausted"}, s}
    case 1n+m End{s}:
      Recovery{Nil{}, Clean{}, s}
    case 1n+m Short{s}:
      Recovery{Nil{}, Torn{}, s}
    case 1n+m Bad{why, s}:
      Recovery{Nil{}, Corrupt{why}, s}
    case 1n+m Got{p, s}:
      recover.con(~a, ~P, ~S, p, recover.go(~a, ~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, m, max, next(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, s)))

# Every committed record of s, in order.
def recover(~a: Quant, ~P: Kind(a), ~S: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, n: Nat, +max: U32, s: S) -> Recovery<a, P, S>:
  recover.go(~a, ~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, n, max, next(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, s))

# step folded over every frame from st on, without a list of the records. n as in recover.go.
def replay.go(~P: Type, ~S: Type, ~A: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, ~step: A -> P -> A, n: Nat, +max: U32, st: Step<P, S>, acc: A) -> Replay<A, S>:
  match n st:
    case 0n End{s}:
      Replay{acc, Clean{}, s}
    case 0n Short{s}:
      Replay{acc, Torn{}, s}
    case 0n Bad{why, s}:
      Replay{acc, Corrupt{why}, s}
    case 0n Got{p, s}:
      Replay{step(acc, p), Corrupt{"frame budget exhausted"}, s}
    case 1n+m End{s}:
      Replay{acc, Clean{}, s}
    case 1n+m Short{s}:
      Replay{acc, Torn{}, s}
    case 1n+m Bad{why, s}:
      Replay{acc, Corrupt{why}, s}
    case 1n+m Got{p, s}:
      replay.go(~P, ~S, ~A, ~fits, ~u32, ~cut, ~skip, ~sum, ~step, m, max, next(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, s), step(acc, p))

def replay(~P: Type, ~S: Type, ~A: Type, ~fits: S -> @+at:U32 -> @+n:U32 -> S & Bool, ~u32: S -> @+at:U32 -> S & U32, ~cut: S -> @+hs:U32 -> @+len:U32 -> S & P, ~skip: S -> @+hs:U32 -> @+len:U32 -> S, ~sum: P -> P & U32, ~step: A -> P -> A, n: Nat, +max: U32, s: S, acc: A) -> Replay<A, S>:
  replay.go(~P, ~S, ~A, ~fits, ~u32, ~cut, ~skip, ~sum, ~step, n, max, next(~P, ~S, ~fits, ~u32, ~cut, ~skip, ~sum, max, s), acc)

# The model: a list of octets. The laws are stated over it.
# A model field holds its value in the first of its four cells and 0 in the others. Bytes holds it
# as four little-endian octets. Both take four cells, so offsets agree; check.bend tests the octets.

def list.fits(xs: List<&2, U32>, +at: U32, +n: U32) -> List<&2, U32> & Bool:
  +ys = xs
  (ys, Nat.is_le(Nat.add(U32.to_nat(at), U32.to_nat(n)), List.length(&2, U32, ys)))

def list.field(xs: List<&2, U32>) -> U32:
  match xs:
    case Con{x, t}:
      x
    case Nil{}:
      0

def list.u32(xs: List<&2, U32>, +at: U32) -> List<&2, U32> & U32:
  +ys = xs
  (ys, list.field(List.drop(&2, U32, ys, U32.to_nat(at))))

def list.cut(xs: List<&2, U32>, +hs: U32, +len: U32) -> List<&2, U32> & List<&2, U32>:
  +ys = xs
  (ys, List.take(&2, U32, List.drop(&2, U32, ys, U32.to_nat(hs)), U32.to_nat(len)))

def list.skip(xs: List<&2, U32>, +hs: U32, +len: U32) -> List<&2, U32>:
  List.drop(&2, U32, xs, Nat.add(U32.to_nat(hs), U32.to_nat(len)))

# CRC-32 (ISO-HDLC, as zlib and Hash.crc32) of a list of octets.
def list.crc(xs: List<&2, U32>) -> U32:
  U32.not(List.foldl(~&2, ~U32, ~U32, ~(h => c => Hash.crc.byte(h, c)), xs, 4294967295))

def list.sum(xs: List<&2, U32>) -> List<&2, U32> & U32:
  +ys = xs
  (ys, list.crc(ys))

def list.next(+max: U32, xs: List<&2, U32>) -> Step<List<&2, U32>, List<&2, U32>>:
  next(~List<&2, U32>, ~List<&2, U32>, ~list.fits, ~list.u32, ~list.cut, ~list.skip, ~list.sum, max, xs)

def list.recover(n: Nat, +max: U32, xs: List<&2, U32>) -> Recovery<&2, List<&2, U32>, List<&2, U32>>:
  recover(~&2, ~List<&2, U32>, ~List<&2, U32>, ~list.fits, ~list.u32, ~list.cut, ~list.skip, ~list.sum, n, max, xs)

def list.replay(~A: Type, ~step: A -> List<&2, U32> -> A, n: Nat, +max: U32, xs: List<&2, U32>, acc: A) -> Replay<A, List<&2, U32>>:
  replay(~List<&2, U32>, ~List<&2, U32>, ~A, ~list.fits, ~list.u32, ~list.cut, ~list.skip, ~list.sum, ~step, n, max, xs, acc)

def list.head(+len: U32, +sum: U32) -> List<&2, U32>:
  [len, 0, 0, 0, U32.not(len), 0, 0, 0, sum, 0, 0, 0]

def list.frame(+p: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, list.head(U32.from_nat(List.length(&2, U32, p)), list.crc(p)), p)

# The frames of rs, one after another: what appending each record writes.
def list.log(rs: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{p, t}:
      List.append(&2, U32, list.frame(p), list.log(t))

# The Bytes instance. A cursor reads b from pos; pos only moves forward, past whole frames.
type Cur is Type:
  Cur{b: Bytes.Bytes, pos: U32}

def cur.fits(c: Cur, +at: U32, +n: U32) -> Cur & Bool:
  Cur{Bytes.Bytes{+len, buf}, +pos} = c
  (Cur{Bytes.Bytes{len, buf}, pos}, Bytes.fits((len - pos : U32), at, n))

def cur.field(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{x}:
      x
    case None{}:
      0

def cur.u32.fin(+pos: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Cur & U32:
  (b, m) = r
  (Cur{b, pos}, cur.field(m))

def cur.u32(c: Cur, +at: U32) -> Cur & U32:
  Cur{b, +pos} = c
  cur.u32.fin(pos, Bytes.get.u32le(b, (pos + at : U32)))

def cur.cut.fin(+pos: U32, r: Bytes.Bytes & Bytes.Bytes) -> Cur & Bytes.Bytes:
  (b, p) = r
  (Cur{b, pos}, p)

def cur.cut(c: Cur, +hs: U32, +len: U32) -> Cur & Bytes.Bytes:
  Cur{b, +pos} = c
  cur.cut.fin(pos, Bytes.slice(b, (pos + hs : U32), len))

def cur.skip(c: Cur, +hs: U32, +len: U32) -> Cur:
  Cur{b, +pos} = c
  Cur{b, (pos + hs + len : U32)}

def cur.sum(p: Bytes.Bytes) -> Bytes.Bytes & U32:
  Hash.crc32(p)

# Every frame of b holds at least 12 octets, so len / 12 + 1 steps reach the end.
def fuel(+len: U32) -> Nat:
  U32.to_nat((len / 12 + 1 : U32))

# step folded over every committed record of b, in order. rest.pos is where the committed prefix ends.
def replay.bytes(~A: Type, ~step: A -> Bytes.Bytes -> A, +max: U32, b: Bytes.Bytes, acc: A) -> Replay<A, Cur>:
  Bytes.Bytes{+len, buf} = b
  replay(~Bytes.Bytes, ~Cur, ~A, ~cur.fits, ~cur.u32, ~cur.cut, ~cur.skip, ~cur.sum, ~step, fuel(len), max, Cur{Bytes.Bytes{len, buf}, 0}, acc)

def frame.of(+len: U32, r: Bytes.Bytes & U32) -> Bytes.Bytes:
  (p, +sum) = r
  Bytes.append(Bytes.set.u32le(Bytes.set.u32le(Bytes.set.u32le(Bytes.new(12), 0, len), 4, U32.not(len)), 8, sum), p)

# The frame that appending p writes.
def frame(p: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = p
  frame.of(len, Hash.crc32(Bytes.Bytes{len, buf}))
