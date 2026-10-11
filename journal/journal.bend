# Append-only journal: checksummed frames, fsync'd appends, and crash recovery of the committed prefix. Source: https://github.com/paymog/bend-kit/tree/main/journal
import Base
# bend-kit-bytes@0.3.0.0, the version bend-kit-hash@0.1.0.0 takes, so Hash.crc32 accepts these Bytes.
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-hash@0.1.0.0/hash.bend as Hash

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

def crc.bit(n: Nat, +c: U32) -> U32:
  match n:
    case 0n:
      c
    case 1n+m:
      crc.bit(m, Bool.pick(U32, U32.is_eq((c .&. 1 : U32), 1), ((c >> 1n) .^. 3988292384 : U32), (c >> 1n : U32)))

def crc.go(xs: List<&2, U32>, +c: U32) -> U32:
  match xs:
    case Nil{}:
      c
    case Con{+x, t}:
      crc.go(t, crc.bit(8n, (c .^. (x .&. 255 : U32) : U32)))

# CRC-32 (ISO-HDLC, as zlib and Hash.crc32) of a list of octets, bit by bit.
def list.crc(xs: List<&2, U32>) -> U32:
  U32.not(crc.go(xs, 4294967295))

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

# ponytail: Hash.crc32 builds its 256-entry table per record; share one table if recovery gets hot.
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

# Effects. Each one finishes its write with fsync (F_FULLFSYNC on macOS in C) before it answers.

# Opens path for reading and appending, creating it, and fsyncs its directory. Answers the file and
# its whole contents. Fails with EFBIG when the file holds more than limit octets.
def open.words(path: String, limit: U32) -> IO(Result<&1, &1, U32 & String, File & U32 & Array<U32>>):
  import "./effs/journal.c"
  import "./effs/journal.js"

# Writes len octets of words at the end of file, then fsyncs it.
def append.words(file: File, len: U32, words: Array<U32>) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  import "./effs/journal.c"
  import "./effs/journal.js"

# Cuts file to len octets, then fsyncs it.
def truncate(file: File, len: U32) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  import "./effs/journal.c"
  import "./effs/journal.js"

# An open journal. max caps a record's length. end is the file's length. ok turns False when an
# append fails: what reached the disk is then unknown, so appends stop until the journal is reopened.
type Journal is Type:
  Journal{file: File, max: U32, end: U32, ok: Bool}

def open.cut(r: File & Result<&1, &1, U32 & String, Unit>, +max: U32, +end: U32, -A: Type, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  match r:
    case (file, Fail{e}):
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        File.close(file)
        return Fail{e}
    case (file, Done{u}):
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        return Done{(Journal{file, max, end, True{}}, acc)}

def open.tail(t: Tail, file: File, +max: U32, +pos: U32, -A: Type, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  match t:
    case Clean{}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        return Done{(Journal{file, max, pos, True{}}, acc)}
    case Torn{}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        r : File & Result<&1, &1, U32 & String, Unit> <- truncate(file, pos)
        open.cut(r, max, pos, A, acc)
    case Corrupt{why}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        File.close(file)
        return Fail{(22, "journal: corrupt frame at offset " ++ U32.show(pos) ++ ": " ++ why)}

def open.replayed(file: File, +max: U32, -A: Type, r: Replay<A, Cur>) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  Replay{acc, t, rest} = r
  Cur{b, +pos} = rest
  open.tail(t, file, max, pos, A, acc)

def open.read(~A: Type, ~step: A -> Bytes.Bytes -> A, r: Result<&1, &1, U32 & String, File & U32 & Array<U32>>, +max: U32, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  match r:
    case Fail{e}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        return Fail{e}
    case Done{(file, (len, words))}:
      open.replayed(file, max, A, replay.bytes(~A, ~step, max, Bytes.Bytes{len, words}, acc))

# Opens the journal at path and folds step over its committed records, from acc.
# A torn tail is cut off and fsynced before open answers. A corrupt frame fails with EINVAL and
# its offset; the file is left as it is. max caps a record's length; limit caps the file's size.
def open(~A: Type, ~step: A -> Bytes.Bytes -> A, path: String, +max: U32, limit: U32, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  do IO<Result<&1, &1, U32 & String, Journal & A>>:
    r : Result<&1, &1, U32 & String, File & U32 & Array<U32>> <- open.words(path, limit)
    open.read(~A, ~step, r, max, acc)

def append.back(+max: U32, +end: U32, +len: U32, r: File & Result<&1, &1, U32 & String, Unit>) -> Journal & Result<&1, &1, U32 & String, Unit>:
  match r:
    case (file, Done{u}):
      (Journal{file, max, (end + len : U32), True{}}, Done{u})
    case (file, Fail{e}):
      (Journal{file, max, end, False{}}, Fail{e})

def append.write(file: File, +max: U32, +end: U32, f: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{+len, words} = f
  do IO<Journal & Result<&1, &1, U32 & String, Unit>>:
    r : File & Result<&1, &1, U32 & String, Unit> <- append.words(file, len, words)
    return append.back(max, end, len, r)

def append.refuse(file: File, +max: U32, +end: U32, +ok: Bool, e: U32 & String) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  do IO<Journal & Result<&1, &1, U32 & String, Unit>>:
    return (Journal{file, max, end, ok}, Fail{e})

# The file stays under 4 GiB, so every offset and the next open's read fit a U32.
def append.size(over: Bool, big: Bool, file: File, +max: U32, +end: U32, p: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  match over big:
    case True{} _:
      append.refuse(file, max, end, True{}, (22, "journal: record over max"))
    case False{} True{}:
      append.refuse(file, max, end, True{}, (27, "journal: file would reach 4 GiB"))
    case False{} False{}:
      append.write(file, max, end, frame(p))

def append.ok(ok: Bool, file: File, +max: U32, +end: U32, p: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  match ok:
    case False{}:
      append.refuse(file, max, end, False{}, (5, "journal: an append failed; reopen the journal"))
    case True{}:
      Bytes.Bytes{+len, buf} = p
      append.size(U32.is_gt(len, max), Bool.or(U32.is_gt(end, 4294967283), U32.is_lt((4294967283 - end : U32), len)), file, max, end, Bytes.Bytes{len, buf})

# Appends p as one frame and answers once it is fsynced: Done means durable, under the trust
# assumptions in README.md. After a Fail the record may or may not survive a reopen.
def append(j: Journal, p: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  Journal{file, +max, +end, ok} = j
  append.ok(ok, file, max, end, p)

def close(j: Journal) -> IO(Unit):
  Journal{file, max, end, ok} = j
  File.close(file)
