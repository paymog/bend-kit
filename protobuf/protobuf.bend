# Pure bounded protobuf wire codec over Bytes. https://github.com/paymog/bend-kit/tree/main/protobuf
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import bend-kit-f64@0.1.0.0/f64.bend as F

# Signed integers use two's-complement bits, not host numeric conversions.
type Word64 is Data:
  Word64{hi: U32, lo: U32}

type Error is Data:
  Incomplete{}
  Malformed{}
  Limit{}
  InvalidUtf8{}

type Value is Type:
  Varint{value: Word64}
  Fixed32{value: U32}
  Fixed64{value: Word64}
  Blob{value: B.Bytes}
  Group{fields: List<&1, Field>}

type Field is Type:
  Field{number: U32, value: Value}

def valid_number(+n: U32) -> Bool:
  U32.is_ge(n, 1) && U32.is_le(n, 536870911)

def Word64.zero() -> Word64:
  Word64{0, 0}

def Word64.is_zero(w: Word64) -> Bool:
  Word64{h, l} = w
  U32.is_zero(h) && U32.is_zero(l)

def Word64.shr7(w: Word64) -> Word64:
  Word64{+h, l} = w
  Word64{(h >> 7n : U32), ((l >> 7n) .|. (h << 25n) : U32)}

def Word64.zigzag(w: Word64) -> Word64:
  Word64{+h, +l} = w
  +mask = (0 - (h >> 31n) : U32)
  Word64{(((h << 1n) .|. (l >> 31n)) .^. mask : U32), ((l << 1n) .^. mask : U32)}

def Word64.unzigzag(w: Word64) -> Word64:
  Word64{+h, +l} = w
  +mask = (0 - (l .&. 1) : U32)
  Word64{((h >> 1n) .^. mask : U32), (((l >> 1n) .|. (h << 31n)) .^. mask : U32)}

def read32.result(r: B.Cursor & Maybe<&2, U32>) -> Result<&2, &1, Error, B.Cursor & U32>:
  (c, v) = r
  match v:
    case None{}:
      Fail{Incomplete{}}
    case Some{x}:
      Done{(c, x)}

def read32(c: B.Cursor) -> Result<&2, &1, Error, B.Cursor & U32>:
  read32.result(B.Cursor.u32le(c))

def read64.hi(l: U32, r: B.Cursor & U32) -> Result<&2, &1, Error, B.Cursor & Word64>:
  (c, h) = r
  Done{(c, Word64{h, l})}

def read64.lo(r: B.Cursor & U32) -> Result<&2, &1, Error, B.Cursor & Word64>:
  (c, l) = r
  do Result<&2, &1, Error, B.Cursor & Word64>:
    high : B.Cursor & U32 <- read32(c)
    read64.hi(l, high)

def read64(c: B.Cursor) -> Result<&2, &1, Error, B.Cursor & Word64>:
  do Result<&2, &1, Error, B.Cursor & Word64>:
    low : B.Cursor & U32 <- read32(c)
    read64.lo(low)

def varint.add.low(fifth: Bool, +i: U32, +v: U32, h: U32, l: U32) -> Word64:
  match fifth:
    case False{}:
      Word64{h, (l .|. (v << U32.to_nat((i * 7 : U32))) : U32)}
    case True{}:
      Word64{(h .|. (v >> 4n) : U32), (l .|. (v << 28n) : U32)}

def varint.add.pick(low: Bool, +i: U32, +v: U32, w: Word64) -> Word64:
  match low:
    case True{}:
      Word64{h, l} = w
      varint.add.low(U32.is_eq(i, 4), i, v, h, l)
    case False{}:
      Word64{h, l} = w
      Word64{(h .|. (v << U32.to_nat((i * 7 - 32 : U32))) : U32), l}

def varint.add(+i: U32, +v: U32, w: Word64) -> Word64:
  varint.add.pick(U32.is_lt(i, 5), i, v, w)

type VarintByte is Data:
  VarintByte{bad: Bool, done: Bool, value: U32}

def varint.read.result(i: U32, last: U32, max_last: U32, r: B.Cursor & Maybe<&2, U32>) -> B.Cursor & Maybe<&2, VarintByte>:
  (c, m) = r
  match m:
    case None{}:
      (c, None{})
    case Some{+b}:
      (c, Some{VarintByte{U32.is_eq(i, last) && U32.is_gt(b, max_last), U32.is_lt(b, 128), b}})

def varint.read(+i: U32, last: U32, max_last: U32, c: B.Cursor) -> B.Cursor & Maybe<&2, VarintByte>:
  varint.read.result(i, last, max_last, B.Cursor.u8(c))

# The last byte must fit its word; its continuation bit is never allowed.
def varint.go(fuel: Nat, r: B.Cursor & Maybe<&2, VarintByte>, +i: U32, +last: U32, +max_last: U32, w: Word64) -> Result<&2, &1, Error, B.Cursor & Word64>:
  match fuel:
    case 0n:
      Fail{Malformed{}}
    case 1n+p:
      (c, v) = r
      match v:
        case None{}:
          Fail{Incomplete{}}
        case Some{VarintByte{bad, done, b}}:
          match bad:
            case True{}:
              Fail{Malformed{}}
            case False{}:
              match done:
                case True{}:
                  Done{(c, varint.add(i, (b .&. 127 : U32), w))}
                case False{}:
                  varint.go(p, varint.read((i + 1 : U32), last, max_last, c), (i + 1 : U32), last, max_last, varint.add(i, (b .&. 127 : U32), w))

def read_varint(c: B.Cursor) -> Result<&2, &1, Error, B.Cursor & Word64>:
  varint.go(10n, varint.read(0, 9, 1, c), 0, 9, 1, Word64{0, 0})

def read_varint32(c: B.Cursor) -> Result<&2, &1, Error, B.Cursor & Word64>:
  varint.go(5n, varint.read(0, 4, 15, c), 0, 4, 15, Word64{0, 0})

def read_blob.slice(pos: U32, start: U32, end: U32, r: B.Bytes & B.Bytes) -> Result<&2, &1, Error, B.Cursor & B.Bytes>:
  (b, part) = r
  Done{(B.Cursor{b, pos, start, end}, part)}

def read_blob.fits(fits: Bool, c: B.Cursor, +n: U32) -> Result<&2, &1, Error, B.Cursor & B.Bytes>:
  match fits:
    case False{}:
      Fail{Incomplete{}}
    case True{}:
      B.Cursor{b, +pos, start, end} = c
      read_blob.slice((pos + n : U32), start, end, B.slice(b, pos, n))

def read_blob.length(ok: Bool, c: B.Cursor, +n: U32) -> Result<&2, &1, Error, B.Cursor & B.Bytes>:
  match ok:
    case False{}:
      Fail{Malformed{}}
    case True{}:
      B.Cursor{b, +pos, start, +end} = c
      read_blob.fits(B.fits(end, pos, n), B.Cursor{b, pos, start, end}, n)

def read_blob.word(r: B.Cursor & Word64) -> Result<&2, &1, Error, B.Cursor & B.Bytes>:
  (c, Word64{h, +l}) = r
  read_blob.length(U32.is_zero(h) && U32.is_le(l, 2147483647), c, l)

def read_blob(c: B.Cursor) -> Result<&2, &1, Error, B.Cursor & B.Bytes>:
  do Result<&2, &1, Error, B.Cursor & B.Bytes>:
    r : B.Cursor & Word64 <- read_varint32(c)
    read_blob.word(r)

def read_value.varint(r: B.Cursor & Word64) -> Result<&2, &1, Error, B.Cursor & Value>:
  (c, v) = r
  Done{(c, Varint{v})}

def read_value.fixed64(r: B.Cursor & Word64) -> Result<&2, &1, Error, B.Cursor & Value>:
  (c, v) = r
  Done{(c, Fixed64{v})}

def read_value.blob(r: B.Cursor & B.Bytes) -> Result<&2, &1, Error, B.Cursor & Value>:
  (c, v) = r
  Done{(c, Blob{v})}

def read_value.fixed32(r: B.Cursor & U32) -> Result<&2, &1, Error, B.Cursor & Value>:
  (c, v) = r
  Done{(c, Fixed32{v})}

def read_value(kind: U32, c: B.Cursor) -> Result<&2, &1, Error, B.Cursor & Value>:
  match kind:
    case 0:
      do Result<&2, &1, Error, B.Cursor & Value>:
        r : B.Cursor & Word64 <- read_varint(c)
        read_value.varint(r)
    case 1:
      do Result<&2, &1, Error, B.Cursor & Value>:
        r : B.Cursor & Word64 <- read64(c)
        read_value.fixed64(r)
    case 2:
      do Result<&2, &1, Error, B.Cursor & Value>:
        r : B.Cursor & B.Bytes <- read_blob(c)
        read_value.blob(r)
    case 5:
      do Result<&2, &1, Error, B.Cursor & Value>:
        r : B.Cursor & U32 <- read32(c)
        read_value.fixed32(r)
    case _:
      Fail{Malformed{}}

type Frame is Type:
  Frame{number: U32, outer: List<&1, Field>, depth: Nat}


type DecodeState is Type:
  DecodeState{empty: Bool, cursor: B.Cursor, depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>}

def decode.state(cursor: B.Cursor, depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>) -> DecodeState:
  B.Cursor{b, +pos, start, +end} = cursor
  DecodeState{U32.is_ge(pos, end), B.Cursor{b, pos, start, end}, depth, stack, acc}

def decode.step.value(depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>, number: U32, r: B.Cursor & Value) -> Result<&2, &1, Error, DecodeState>:
  (c, v) = r
  Done{decode.state(c, depth, stack, Con{Field{number, v}, acc})}

def decode.step.close(ok: Bool, c: B.Cursor, number: U32, outer: List<&1, Field>, depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>) -> Result<&2, &1, Error, DecodeState>:
  match ok:
    case False{}:
      Fail{Malformed{}}
    case True{}:
      Done{decode.state(c, depth, stack, Con{Field{number, Group{List.reverse(&1, Field, acc)}}, outer})}

def decode.step.kind(kind: U32, c: B.Cursor, +depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>, +number: U32) -> Result<&2, &1, Error, DecodeState>:
  match kind:
    case 3:
      match depth:
        case 0n:
          Fail{Limit{}}
        case 1n+d:
          Done{decode.state(c, d, Con{Frame{number, acc, 1n+d}, stack}, Nil{})}
    case 4:
      match stack:
        case Nil{}:
          Fail{Malformed{}}
        case Con{Frame{expected, outer, parent_depth}, tail}:
          decode.step.close(U32.is_eq(number, expected), c, number, outer, parent_depth, tail, acc)
    case _:
      do Result<&2, &1, Error, DecodeState>:
        r : B.Cursor & Value <- read_value(kind, c)
        decode.step.value(depth, stack, acc, number, r)

def decode.step.valid(ok: Bool, kind: U32, c: B.Cursor, depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>, number: U32) -> Result<&2, &1, Error, DecodeState>:
  match ok:
    case False{}:
      Fail{Malformed{}}
    case True{}:
      decode.step.kind(kind, c, depth, stack, acc, number)

def decode.step.tag(depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>, tag: B.Cursor & Word64) -> Result<&2, &1, Error, DecodeState>:
  (c, Word64{hi, +lo}) = tag
  +number = (lo >> 3n : U32)
  decode.step.valid(U32.is_zero(hi) && valid_number(number), (lo .&. 7 : U32), c, depth, stack, acc, number)

def decode.step(c: B.Cursor, depth: Nat, stack: List<&1, Frame>, acc: List<&1, Field>) -> Result<&2, &1, Error, DecodeState>:
  do Result<&2, &1, Error, DecodeState>:
    tag : B.Cursor & Word64 <- read_varint32(c)
    decode.step.tag(depth, stack, acc, tag)

# Explicit group stack keeps decoding linear and avoids mutually recursive parsers.
def decode.go(fuel: Nat, state: DecodeState) -> Result<&2, &1, Error, List<&1, Field>>:
  match fuel:
    case 0n:
      Fail{Limit{}}
    case 1n+p:
      DecodeState{empty, c, depth, stack, acc} = state
      match empty:
        case True{}:
          match stack:
            case Nil{}:
              Done{List.reverse(&1, Field, acc)}
            case Con{h, t}:
              Fail{Incomplete{}}
        case False{}:
          do Result<&2, &1, Error, List<&1, Field>>:
            next : DecodeState <- decode.step(c, depth, stack, acc)
            decode.go(p, next)

def decode.limit(ok: Bool, b: B.Bytes, +n: U32, depth: Nat) -> Result<&2, &1, Error, List<&1, Field>>:
  match ok:
    case False{}:
      Fail{Limit{}}
    case True{}:
      decode.go(1n+U32.to_nat(n), decode.state(B.Cursor.new(b), depth, Nil{}, Nil{}))

def decode(b: B.Bytes, max_size: U32, depth: Nat) -> Result<&2, &1, Error, List<&1, Field>>:
  B.Bytes{+n, buf} = b
  decode.limit(U32.is_le(n, U32.min(max_size, 2147483647)), B.Bytes{n, buf}, n, depth)

# Append checks subtraction before addition, including U32 size overflow.
def append.limit(ok: Bool, out: B.Bytes, part: B.Bytes) -> Result<&2, &1, Error, B.Bytes>:
  match ok:
    case True{}:
      Done{B.append(out, part)}
    case False{}:
      Fail{Limit{}}

def append(out: B.Bytes, part: B.Bytes, +max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  B.Bytes{+n, a_buf} = out
  B.Bytes{+m, b_buf} = part
  +limit = U32.min(max_size, 2147483647)
  append.limit(U32.is_le(n, limit) && U32.is_le(m, (limit - n : U32)), B.Bytes{n, a_buf}, B.Bytes{m, b_buf})

def byte.limit(ok: Bool, +n: U32, buf: Array<U32>, v: U32) -> Result<&2, &1, Error, B.Bytes>:
  match ok:
    case False{}:
      Fail{Limit{}}
    case True{}:
      Done{B.Bytes{(n + 1 : U32), B.poke(B.grow(n, buf, (n + 1 : U32)), n, v)}}

def byte(out: B.Bytes, v: U32, max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  B.Bytes{+n, buf} = out
  byte.limit(U32.is_lt(n, U32.min(max_size, 2147483647)), n, buf, v)

def write_varint.done(w: Word64) -> Bool:
  Word64{h, l} = w
  U32.is_zero(h) && U32.is_lt(l, 128)

def write_varint.go(fuel: Nat, done: Bool, w: Word64, out: B.Bytes, +max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  match fuel:
    case 0n:
      Fail{Malformed{}}
    case 1n+p:
      match done:
        case True{}:
          Word64{h, l} = w
          byte(out, l, max_size)
        case False{}:
          Word64{+h, +l} = w
          +rest = Word64.shr7(Word64{h, l})
          do Result<&2, &1, Error, B.Bytes>:
            next : B.Bytes <- byte(out, ((l .&. 127) .|. 128 : U32), max_size)
            write_varint.go(p, write_varint.done(rest), rest, next, max_size)

def write_varint(+w: Word64, out: B.Bytes, max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  write_varint.go(10n, write_varint.done(w), w, out, max_size)

def write_tag.valid(valid: Bool, number: U32, kind: U32, out: B.Bytes, max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  match valid:
    case False{}:
      Fail{Malformed{}}
    case True{}:
      write_varint(Word64{0, ((number << 3n) .|. kind : U32)}, out, max_size)

def write_tag(+number: U32, kind: U32, out: B.Bytes, max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  write_tag.valid(valid_number(number), number, kind, out, max_size)

def write_fixed32.limit(ok: Bool, +n: U32, buf: Array<U32>, v: U32) -> Result<&2, &1, Error, B.Bytes>:
  match ok:
    case False{}:
      Fail{Limit{}}
    case True{}:
      Done{B.set.u32le(B.Bytes{(n + 4 : U32), B.grow(n, buf, (n + 4 : U32))}, n, v)}

def write_fixed32(v: U32, out: B.Bytes, max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  B.Bytes{+n, buf} = out
  +limit = U32.min(max_size, 2147483647)
  write_fixed32.limit(U32.is_le(n, limit) && U32.is_le(4, (limit - n : U32)), n, buf, v)

def write_fixed64.limit(ok: Bool, +n: U32, buf: Array<U32>, v: Word64) -> Result<&2, &1, Error, B.Bytes>:
  match ok:
    case False{}:
      Fail{Limit{}}
    case True{}:
      Word64{h, l} = v
      Done{B.set.u32le(B.set.u32le(B.Bytes{(n + 8 : U32), B.grow(n, buf, (n + 8 : U32))}, n, l), (n + 4 : U32), h)}

def write_fixed64(v: Word64, out: B.Bytes, max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  B.Bytes{+n, buf} = out
  +limit = U32.min(max_size, 2147483647)
  write_fixed64.limit(U32.is_le(n, limit) && U32.is_le(8, (limit - n : U32)), n, buf, v)

def write_value(v: Value, out: B.Bytes, +max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  match v:
    case Varint{w}:
      write_varint(w, out, max_size)
    case Fixed32{w}:
      write_fixed32(w, out, max_size)
    case Fixed64{w}:
      write_fixed64(w, out, max_size)
    case Blob{b}:
      B.Bytes{+n, buf} = b
      do Result<&2, &1, Error, B.Bytes>:
        next : B.Bytes <- write_varint(Word64{0, n}, out, max_size)
        append(next, B.Bytes{n, buf}, max_size)
    case Group{fields}:
      Fail{Malformed{}}

def write_field(number: U32, v: Value, out: B.Bytes, +max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  match v:
    case Varint{w}:
      do Result<&2, &1, Error, B.Bytes>:
        next : B.Bytes <- write_tag(number, 0, out, max_size)
        write_value(Varint{w}, next, max_size)
    case Fixed64{w}:
      do Result<&2, &1, Error, B.Bytes>:
        next : B.Bytes <- write_tag(number, 1, out, max_size)
        write_value(Fixed64{w}, next, max_size)
    case Blob{b}:
      do Result<&2, &1, Error, B.Bytes>:
        next : B.Bytes <- write_tag(number, 2, out, max_size)
        write_value(Blob{b}, next, max_size)
    case Fixed32{w}:
      do Result<&2, &1, Error, B.Bytes>:
        next : B.Bytes <- write_tag(number, 5, out, max_size)
        write_value(Fixed32{w}, next, max_size)
    case Group{fields}:
      Fail{Malformed{}}

# Depth is the first decreasing argument for a group; list tails decrease the second.
def encode.go(+depth: Nat, fields: List<&1, Field>, out: B.Bytes, +max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  match depth:
    case 0n:
      match fields:
        case Nil{}:
          Done{out}
        case Con{Field{number, value}, tail}:
          match value:
            case Group{inner}:
              Fail{Limit{}}
            case Varint{w}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Varint{w}, out, max_size)
                encode.go(0n, tail, next, max_size)
            case Fixed32{w}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Fixed32{w}, out, max_size)
                encode.go(0n, tail, next, max_size)
            case Fixed64{w}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Fixed64{w}, out, max_size)
                encode.go(0n, tail, next, max_size)
            case Blob{b}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Blob{b}, out, max_size)
                encode.go(0n, tail, next, max_size)
    case 1n+p:
      match fields:
        case Nil{}:
          Done{out}
        case Con{Field{+number, value}, tail}:
          match value:
            case Group{inner}:
              do Result<&2, &1, Error, B.Bytes>:
                start : B.Bytes <- write_tag(number, 3, out, max_size)
                body : B.Bytes <- encode.go(p, inner, start, max_size)
                end : B.Bytes <- write_tag(number, 4, body, max_size)
                encode.go(1n+p, tail, end, max_size)
            case Varint{w}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Varint{w}, out, max_size)
                encode.go(1n+p, tail, next, max_size)
            case Fixed32{w}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Fixed32{w}, out, max_size)
                encode.go(1n+p, tail, next, max_size)
            case Fixed64{w}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Fixed64{w}, out, max_size)
                encode.go(1n+p, tail, next, max_size)
            case Blob{b}:
              do Result<&2, &1, Error, B.Bytes>:
                next : B.Bytes <- write_field(number, Blob{b}, out, max_size)
                encode.go(1n+p, tail, next, max_size)

def encode(fields: List<&1, Field>, max_size: U32, depth: Nat) -> Result<&2, &1, Error, B.Bytes>:
  encode.go(depth, fields, B.new(0), max_size)

type PackedState is Type:
  PackedState{empty: Bool, cursor: B.Cursor, acc: List<&1, Value>}

def packed_decode.state(cursor: B.Cursor, acc: List<&1, Value>) -> PackedState:
  B.Cursor{b, +pos, start, +end} = cursor
  PackedState{U32.is_ge(pos, end), B.Cursor{b, pos, start, end}, acc}

def packed_decode.step.value(acc: List<&1, Value>, r: B.Cursor & Value) -> Result<&2, &1, Error, PackedState>:
  (c, v) = r
  Done{packed_decode.state(c, Con{v, acc})}

def packed_decode.step(kind: U32, c: B.Cursor, acc: List<&1, Value>) -> Result<&2, &1, Error, PackedState>:
  do Result<&2, &1, Error, PackedState>:
    r : B.Cursor & Value <- read_value(kind, c)
    packed_decode.step.value(acc, r)

def packed_decode.go(fuel: Nat, +kind: U32, state: PackedState) -> Result<&2, &1, Error, List<&1, Value>>:
  match fuel:
    case 0n:
      Fail{Limit{}}
    case 1n+p:
      PackedState{empty, c, acc} = state
      match empty:
        case True{}:
          Done{List.reverse(&1, Value, acc)}
        case False{}:
          do Result<&2, &1, Error, List<&1, Value>>:
            next : PackedState <- packed_decode.step(kind, c, acc)
            packed_decode.go(p, kind, next)

def packed_decode.result(r: Result<&2, &1, Error, List<&1, Value>>) -> Result<&2, &1, Error, List<&1, Value>>:
  match r:
    case Done{values}:
      Done{values}
    case Fail{Incomplete{}}:
      Fail{Malformed{}}
    case Fail{e}:
      Fail{e}

def packed_decode.limit(fits: Bool, kind: U32, bytes: B.Bytes, n: U32) -> Result<&2, &1, Error, List<&1, Value>>:
  match fits:
    case False{}:
      Fail{Limit{}}
    case True{}:
      packed_decode.result(packed_decode.go(1n+U32.to_nat(n), kind, packed_decode.state(B.Cursor.new(bytes), Nil{})))

def packed_decode.valid(valid: Bool, kind: U32, b: B.Bytes, max_size: U32) -> Result<&2, &1, Error, List<&1, Value>>:
  match valid:
    case False{}:
      Fail{Malformed{}}
    case True{}:
      B.Bytes{+n, buf} = b
      packed_decode.limit(U32.is_le(n, U32.min(max_size, 2147483647)), kind, B.Bytes{n, buf}, n)

def packed_decode(+kind: U32, b: B.Bytes, max_size: U32) -> Result<&2, &1, Error, List<&1, Value>>:
  packed_decode.valid(U32.is_eq(kind, 0) || U32.is_eq(kind, 1) || U32.is_eq(kind, 5), kind, b, max_size)

def packed_encode.go(values: List<&1, Value>, out: B.Bytes, +max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  match values:
    case Nil{}:
      Done{out}
    case Con{v, tail}:
      match v:
        case Varint{w}:
          do Result<&2, &1, Error, B.Bytes>:
            next : B.Bytes <- write_value(Varint{w}, out, max_size)
            packed_encode.go(tail, next, max_size)
        case Fixed32{w}:
          do Result<&2, &1, Error, B.Bytes>:
            next : B.Bytes <- write_value(Fixed32{w}, out, max_size)
            packed_encode.go(tail, next, max_size)
        case Fixed64{w}:
          do Result<&2, &1, Error, B.Bytes>:
            next : B.Bytes <- write_value(Fixed64{w}, out, max_size)
            packed_encode.go(tail, next, max_size)
        case Blob{b}:
          Fail{Malformed{}}
        case Group{fields}:
          Fail{Malformed{}}

def packed_encode(values: List<&1, Value>, max_size: U32) -> Result<&2, &1, Error, B.Bytes>:
  packed_encode.go(values, B.new(0), max_size)

def from_uint32(v: U32) -> Value:
  Varint{Word64{0, v}}

def to_uint32(v: Value) -> Result<&2, &2, Error, U32>:
  match v:
    case Varint{Word64{h, l}}:
      Done{l}
    case _:
      Fail{Malformed{}}

def from_int32(+v: U32) -> Value:
  Varint{Word64{(0 - (v >> 31n) : U32), v}}

def to_int32(v: Value) -> Result<&2, &2, Error, U32>:
  to_uint32(v)

def from_sint32(+v: U32) -> Value:
  from_uint32(((v << 1n) .^. (0 - (v >> 31n)) : U32))

def unzigzag32(+bits: U32) -> U32:
  ((bits >> 1n) .^. (0 - (bits .&. 1)) : U32)

def to_sint32(v: Value) -> Result<&2, &2, Error, U32>:
  do Result<&2, &2, Error, U32>:
    bits : U32 <- to_uint32(v)
    return unzigzag32(bits)

def from_fixed32(v: U32) -> Value:
  Fixed32{v}

def to_fixed32(v: Value) -> Result<&2, &2, Error, U32>:
  match v:
    case Fixed32{w}:
      Done{w}
    case _:
      Fail{Malformed{}}

def from_sfixed32(v: U32) -> Value:
  from_fixed32(v)

def to_sfixed32(v: Value) -> Result<&2, &2, Error, U32>:
  to_fixed32(v)

def from_uint64(v: Word64) -> Value:
  Varint{v}

def to_uint64(v: Value) -> Result<&2, &2, Error, Word64>:
  match v:
    case Varint{w}:
      Done{w}
    case _:
      Fail{Malformed{}}

def from_int64(v: Word64) -> Value:
  from_uint64(v)

def to_int64(v: Value) -> Result<&2, &2, Error, Word64>:
  to_uint64(v)

def from_sint64(v: Word64) -> Value:
  from_uint64(Word64.zigzag(v))

def to_sint64(v: Value) -> Result<&2, &2, Error, Word64>:
  do Result<&2, &2, Error, Word64>:
    bits : Word64 <- to_uint64(v)
    return Word64.unzigzag(bits)

def from_fixed64(v: Word64) -> Value:
  Fixed64{v}

def to_fixed64(v: Value) -> Result<&2, &2, Error, Word64>:
  match v:
    case Fixed64{w}:
      Done{w}
    case _:
      Fail{Malformed{}}

def from_sfixed64(v: Word64) -> Value:
  from_fixed64(v)

def to_sfixed64(v: Value) -> Result<&2, &2, Error, Word64>:
  to_fixed64(v)

def from_bool(v: Bool) -> Value:
  from_uint32(Bool.to_u32(v))

def to_bool(v: Value) -> Result<&2, &2, Error, Bool>:
  do Result<&2, &2, Error, Bool>:
    bits : Word64 <- to_uint64(v)
    return Bool.not(Word64.is_zero(bits))

# Numeric F32.to_u32 is not a bit cast. Reuse the native Word(32n) payload.
def float_of_bits(v: U32) -> F32:
  U32{bits} = v
  F32{bits}

def from_float(v: F32) -> Value:
  from_fixed32(F32.bits(v))

def to_float(v: Value) -> Result<&2, &2, Error, F32>:
  do Result<&2, &2, Error, F32>:
    bits : U32 <- to_fixed32(v)
    return float_of_bits(bits)

def from_double(v: F.F64) -> Value:
  F.F64{h, l} = v
  Fixed64{Word64{h, l}}

def double_of_bits(bits: Word64) -> F.F64:
  Word64{h, l} = bits
  F.F64{h, l}

def to_double(v: Value) -> Result<&2, &2, Error, F.F64>:
  do Result<&2, &2, Error, F.F64>:
    bits : Word64 <- to_fixed64(v)
    return double_of_bits(bits)

def from_bytes(v: B.Bytes) -> Value:
  Blob{v}

def to_bytes(v: Value) -> Result<&2, &1, Error, B.Bytes>:
  match v:
    case Blob{b}:
      Done{b}
    case _:
      Fail{Malformed{}}

type Utf8 is Data:
  Utf8{need: U32, lo: U32, hi: U32, cp: U32, out: String}

def utf8.lead.multi(+b: U32, out: String) -> Utf8:
  +need = Bool.pick(U32, U32.is_lt(b, 224), 1, Bool.pick(U32, U32.is_lt(b, 240), 2, 3))
  lo = Bool.pick(U32, U32.is_eq(b, 224), 160, Bool.pick(U32, U32.is_eq(b, 240), 144, 128))
  hi = Bool.pick(U32, U32.is_eq(b, 237), 159, Bool.pick(U32, U32.is_eq(b, 244), 143, 191))
  Utf8{need, lo, hi, (b .&. (63 >> U32.to_nat(need)) : U32), out}

def utf8.lead.high(ok: Bool, b: U32, out: String) -> Result<&2, &2, Error, Utf8>:
  match ok:
    case False{}:
      Fail{InvalidUtf8{}}
    case True{}:
      Done{utf8.lead.multi(b, out)}

def utf8.lead(ascii: Bool, +b: U32, out: String) -> Result<&2, &2, Error, Utf8>:
  match ascii:
    case True{}:
      Done{Utf8{0, 128, 191, 0, SCon{Chr{b}, out}}}
    case False{}:
      utf8.lead.high(U32.is_ge(b, 194) && U32.is_le(b, 244), b, out)

def utf8.more(done: Bool, need: U32, cp: U32, out: String) -> Utf8:
  match done:
    case True{}:
      Utf8{0, 128, 191, 0, SCon{Chr{cp}, out}}
    case False{}:
      Utf8{need, 128, 191, cp, out}

def utf8.cont(ok: Bool, +need: U32, cp: U32, b: U32, out: String) -> Result<&2, &2, Error, Utf8>:
  match ok:
    case False{}:
      Fail{InvalidUtf8{}}
    case True{}:
      Done{utf8.more(U32.is_eq(need, 1), (need - 1 : U32), ((cp << 6n) .|. (b .&. 63) : U32), out)}

def utf8.step.idle(idle: Bool, +need: U32, lo: U32, hi: U32, cp: U32, +b: U32, out: String) -> Result<&2, &2, Error, Utf8>:
  match idle:
    case True{}:
      utf8.lead(U32.is_lt(b, 128), b, out)
    case False{}:
      utf8.cont(U32.is_le(lo, b) && U32.is_le(b, hi), need, cp, b, out)

def utf8.step(st: Utf8, b: U32) -> Result<&2, &2, Error, Utf8>:
  Utf8{+need, lo, hi, cp, out} = st
  utf8.step.idle(U32.is_zero(need), need, lo, hi, cp, b, out)

def utf8.finish(ok: Bool, out: String) -> Result<&2, &2, Error, String>:
  match ok:
    case False{}:
      Fail{InvalidUtf8{}}
    case True{}:
      Done{String.reverse(out)}

def utf8.decode.go(n: Nat, r: B.Cursor & Maybe<&2, U32>, st: Utf8) -> Result<&2, &2, Error, String>:
  match n:
    case 0n:
      Utf8{need, lo, hi, cp, out} = st
      utf8.finish(U32.is_zero(need), out)
    case 1n+p:
      (next, v) = r
      match v:
        case None{}:
          Fail{InvalidUtf8{}}
        case Some{b}:
          do Result<&2, &2, Error, String>:
            state : Utf8 <- utf8.step(st, b)
            utf8.decode.go(p, B.Cursor.u8(next), state)

def utf8.decode(b: B.Bytes) -> Result<&2, &2, Error, String>:
  B.Bytes{+n, buf} = b
  utf8.decode.go(U32.to_nat(n), B.Cursor.u8(B.Cursor.new(B.Bytes{n, buf})), Utf8{0, 128, 191, 0, SNil{}})

def utf8.width(+c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(c, 128), 1, Bool.pick(U32, U32.is_lt(c, 2048), 2, Bool.pick(U32, U32.is_lt(c, 65536), 3, 4)))

def utf8.scalar(+c: U32) -> Bool:
  U32.is_le(c, 1114111) && Bool.not(U32.is_ge(c, 55296) && U32.is_le(c, 57343))

def require(ok: Bool, e: Error) -> Result<&2, &1, Error, Unit>:
  match ok:
    case False{}:
      Fail{e}
    case True{}:
      Done{Unit{}}

def utf8.cont_byte(c: U32, shift: Nat) -> U32:
  (128 .|. ((c >> shift) .&. 63) : U32)

def utf8.push(width: U32, +c: U32, out: B.Bytes) -> Result<&2, &1, Error, B.Bytes>:
  match width:
    case 1:
      byte(out, c, 2147483647)
    case 2:
      do Result<&2, &1, Error, B.Bytes>:
        a : B.Bytes <- byte(out, (192 .|. (c >> 6n) : U32), 2147483647)
        byte(a, utf8.cont_byte(c, 0n), 2147483647)
    case 3:
      do Result<&2, &1, Error, B.Bytes>:
        a : B.Bytes <- byte(out, (224 .|. (c >> 12n) : U32), 2147483647)
        b : B.Bytes <- byte(a, utf8.cont_byte(c, 6n), 2147483647)
        byte(b, utf8.cont_byte(c, 0n), 2147483647)
    case _:
      do Result<&2, &1, Error, B.Bytes>:
        a : B.Bytes <- byte(out, (240 .|. (c >> 18n) : U32), 2147483647)
        b : B.Bytes <- byte(a, utf8.cont_byte(c, 12n), 2147483647)
        d : B.Bytes <- byte(b, utf8.cont_byte(c, 6n), 2147483647)
        byte(d, utf8.cont_byte(c, 0n), 2147483647)

def utf8.encode.go(s: String, out: B.Bytes) -> Result<&2, &1, Error, B.Bytes>:
  match s:
    case SNil{}:
      Done{out}
    case SCon{Chr{+c}, tail}:
      do Result<&2, &1, Error, B.Bytes>:
        ok : Unit <- require(utf8.scalar(c), InvalidUtf8{})
        next : B.Bytes <- utf8.push(utf8.width(c), c, out)
        utf8.encode.go(tail, next)

def utf8.encode(s: String) -> Result<&2, &1, Error, B.Bytes>:
  utf8.encode.go(s, B.new(0))

def from_string(s: String) -> Result<&2, &1, Error, Value>:
  do Result<&2, &1, Error, Value>:
    bytes : B.Bytes <- utf8.encode(s)
    return Blob{bytes}

def to_string(v: Value) -> Result<&2, &2, Error, String>:
  match v:
    case Blob{bytes}:
      utf8.decode(bytes)
    case _:
      Fail{Malformed{}}
