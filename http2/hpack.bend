# RFC 7541 HPACK header blocks with a bounded dynamic table.
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./huffman.bend as Huff

# mode: 0 permits indexing, 1 is without indexing, 2 is never indexed.
type Field is Data:
  Field{name: String, value: String, mode: U32}

type State is Data:
  State{entries: List<&2, Field>, size: U32, capacity: U32, allowed: U32, pending: Maybe<&2, U32>, minimum: Maybe<&2, U32>}

def new(+max: U32) -> State:
  State{Nil{}, 0, max, max, None{}, None{}}

# RFC 7541 Appendix A, indexed from 1 to 61.
def static(+index: U32) -> Field:
  match index:
    case 1:
      Field{":authority", "", 0}
    case 2:
      Field{":method", "GET", 0}
    case 3:
      Field{":method", "POST", 0}
    case 4:
      Field{":path", "/", 0}
    case 5:
      Field{":path", "/index.html", 0}
    case 6:
      Field{":scheme", "http", 0}
    case 7:
      Field{":scheme", "https", 0}
    case 8:
      Field{":status", "200", 0}
    case 9:
      Field{":status", "204", 0}
    case 10:
      Field{":status", "206", 0}
    case 11:
      Field{":status", "304", 0}
    case 12:
      Field{":status", "400", 0}
    case 13:
      Field{":status", "404", 0}
    case 14:
      Field{":status", "500", 0}
    case 15:
      Field{"accept-charset", "", 0}
    case 16:
      Field{"accept-encoding", "gzip, deflate", 0}
    case 17:
      Field{"accept-language", "", 0}
    case 18:
      Field{"accept-ranges", "", 0}
    case 19:
      Field{"accept", "", 0}
    case 20:
      Field{"access-control-allow-origin", "", 0}
    case 21:
      Field{"age", "", 0}
    case 22:
      Field{"allow", "", 0}
    case 23:
      Field{"authorization", "", 0}
    case 24:
      Field{"cache-control", "", 0}
    case 25:
      Field{"content-disposition", "", 0}
    case 26:
      Field{"content-encoding", "", 0}
    case 27:
      Field{"content-language", "", 0}
    case 28:
      Field{"content-length", "", 0}
    case 29:
      Field{"content-location", "", 0}
    case 30:
      Field{"content-range", "", 0}
    case 31:
      Field{"content-type", "", 0}
    case 32:
      Field{"cookie", "", 0}
    case 33:
      Field{"date", "", 0}
    case 34:
      Field{"etag", "", 0}
    case 35:
      Field{"expect", "", 0}
    case 36:
      Field{"expires", "", 0}
    case 37:
      Field{"from", "", 0}
    case 38:
      Field{"host", "", 0}
    case 39:
      Field{"if-match", "", 0}
    case 40:
      Field{"if-modified-since", "", 0}
    case 41:
      Field{"if-none-match", "", 0}
    case 42:
      Field{"if-range", "", 0}
    case 43:
      Field{"if-unmodified-since", "", 0}
    case 44:
      Field{"last-modified", "", 0}
    case 45:
      Field{"link", "", 0}
    case 46:
      Field{"location", "", 0}
    case 47:
      Field{"max-forwards", "", 0}
    case 48:
      Field{"proxy-authenticate", "", 0}
    case 49:
      Field{"proxy-authorization", "", 0}
    case 50:
      Field{"range", "", 0}
    case 51:
      Field{"referer", "", 0}
    case 52:
      Field{"refresh", "", 0}
    case 53:
      Field{"retry-after", "", 0}
    case 54:
      Field{"server", "", 0}
    case 55:
      Field{"set-cookie", "", 0}
    case 56:
      Field{"strict-transport-security", "", 0}
    case 57:
      Field{"transfer-encoding", "", 0}
    case 58:
      Field{"user-agent", "", 0}
    case 59:
      Field{"vary", "", 0}
    case 60:
      Field{"via", "", 0}
    case 61:
      Field{"www-authenticate", "", 0}
    case _:
      Field{"", "", 0}

type Cursor is Type:
  Cursor{bytes: Bytes.Bytes, at: U32, length: U32}

def take.of(r: Bytes.Bytes & Maybe<&2, U32>, +at: U32, +length: U32) -> Maybe<&1, Cursor & U32>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{value}:
      Some{(Cursor{b, (at + 1 : U32), length}, value)}

def take(c: Cursor) -> Maybe<&1, Cursor & U32>:
  Cursor{b, +at, +length} = c
  take.of(Bytes.get(b, at), at, length)

def with_pair(-R: Type, r: Cursor & U32, k: Cursor -> U32 -> R) -> R:
  (cursor, value) = r
  k(cursor, value)

def with_taken(-R: Type, m: Maybe<&1, Cursor & U32>, k: Cursor -> U32 -> Maybe<&1, R>) -> Maybe<&1, R>:
  match m:
    case None{}:
      None{}
    case Some{pair}:
      with_pair(Maybe<&1, R>, pair, k)

def within(ok: Bool) -> Maybe<&1, Unit>:
  match ok:
    case True{}:
      Some{Unit{}}
    case False{}:
      None{}

def integer.done(n: Nat, cont: Bool, c: Cursor, +shift: U32, +value: U32) -> Maybe<&1, Cursor & U32>:
  match n cont:
    case 0n False{}:
      Some{(c, value)}
    case 0n True{}:
      None{}
    case 1n+p False{}:
      Some{(c, value)}
    case 1n+p True{}:
      with_taken(Cursor & U32, take(c), cursor => +byte =>
        do Maybe<&1, Cursor & U32>:
          +part: U32 = (byte .&. 127 : U32)
          unused: Unit <- within(U32.is_le(part, ((4294967295 - value : U32) >> U32.to_nat(shift) : U32)))
          integer.done(p, U32.is_ne((byte .&. 128 : U32), 0), cursor, (shift + 7 : U32), (value + (part << U32.to_nat(shift) : U32) : U32)))

def integer.more(full: Bool, c: Cursor, +value: U32) -> Maybe<&1, Cursor & U32>:
  match full:
    case True{}:
      integer.done(5n, True{}, c, 0, value)
    case False{}:
      Some{(c, value)}

def integer.after(+byte: U32, +mask: U32, c: Cursor) -> Maybe<&1, Cursor & U32>:
  +v = (byte .&. mask : U32)
  integer.more(U32.is_eq(v, mask), c, v)

def table.at(xs: List<&2, Field>, n: Nat) -> Maybe<&2, Field>:
  match xs n:
    case Nil{} _:
      None{}
    case Con{+field, tail} 0n:
      Some{field}
    case Con{field, tail} 1n+p:
      table.at(tail, p)


def indexed.static(valid: Bool, +i: U32) -> Maybe<&2, Field>:
  match valid:
    case True{}:
      Some{static(i)}
    case False{}:
      None{}
def indexed.choose(s: Bool, +i: U32, xs: List<&2, Field>) -> Maybe<&2, Field>:
  match s:
    case True{}:
      indexed.static(U32.is_ne(i, 0), i)
    case False{}:
      table.at(xs, U32.to_nat((i - 62 : U32)))
def indexed(+i: U32, st: State) -> Maybe<&2, Field>:
  State{entries, size, capacity, allowed, pending, minimum} = st
  indexed.choose(U32.is_le(i, 61), i, entries)

def literal.decoded(huff: Bool, b: Bytes.Bytes) -> Maybe<&2, String>:
  match huff:
    case True{}:
      Huff.decode(b)
    case False{}:
      Some{Bytes.to_string(b)}

def literal.result(m: Maybe<&2, String>, b: Bytes.Bytes, +at: U32, +count: U32, +length: U32) -> Maybe<&1, Cursor & String>:
  match m:
    case None{}:
      None{}
    case Some{text}:
      Some{(Cursor{b, (at + count : U32), length}, text)}

def literal.slice(r: Bytes.Bytes & Bytes.Bytes, huff: Bool, +at: U32, +count: U32, +length: U32) -> Maybe<&1, Cursor & String>:
  (b, part) = r
  literal.result(literal.decoded(huff, part), b, at, count, length)

def literal.fits(ok: Bool, huff: Bool, b: Bytes.Bytes, +at: U32, +count: U32, +length: U32) -> Maybe<&1, Cursor & String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      literal.slice(Bytes.slice(b, at, count), huff, at, count, length)

def literal.bytes(huff: Bool, c: Cursor, +count: U32) -> Maybe<&1, Cursor & String>:
  Cursor{b, +at, +length} = c
  literal.fits(Bytes.fits(length, at, count), huff, b, at, count, length)

def literal(c: Cursor) -> Maybe<&1, Cursor & String>:
  with_taken(Cursor & String, take(c), cursor => +first =>
    with_taken(Cursor & String, integer.after(first, 127, cursor), cursor => count =>
      literal.bytes(U32.is_ne((first .&. 128 : U32), 0), cursor, count)))

def field.size(f: Field) -> U32:
  Field{+name, +value, mode} = f
  (U32.from_nat(String.length(name)) + U32.from_nat(String.length(value)) + 32 : U32)

def table.trim.go(xs: List<&2, Field>, +room: U32, keep: Bool, +acc: List<&2, Field>, +used: U32) -> List<&2, Field> & U32:
  match xs keep:
    case Nil{} _:
      (List.reverse(&2, Field, acc), used)
    case Con{field, tail} False{}:
      (List.reverse(&2, Field, acc), used)
    case Con{+field, tail} True{}:
      +cost = field.size(field)
      +fits = U32.is_le(cost, room)
      table.trim.go(tail, Bool.pick(U32, fits, (room - cost : U32), 0), fits,
        Bool.pick(List<&2, Field>, fits, Con{field, acc}, acc),
        Bool.pick(U32, fits, (used + cost : U32), used))

def table.trim(xs: List<&2, Field>, +capacity: U32) -> List<&2, Field> & U32:
  table.trim.go(xs, capacity, True{}, Nil{}, 0)

def table.trimmed(r: List<&2, Field> & U32, +capacity: U32, +allowed: U32, pending: Maybe<&2, U32>, minimum: Maybe<&2, U32>) -> State:
  (entries, size) = r
  State{entries, size, capacity, allowed, pending, minimum}

def table.add(room: Bool, +field: Field, xs: List<&2, Field>, +used: U32, +capacity: U32, +allowed: U32, pending: Maybe<&2, U32>, minimum: Maybe<&2, U32>) -> State:
  match room:
    case True{}:
      State{Con{field, xs}, (used + field.size(field) : U32), capacity, allowed, pending, minimum}
    case False{}:
      table.trimmed(table.trim(Con{field, xs}, capacity), capacity, allowed, pending, minimum)

def table.oversize(too_big: Bool, +field: Field, xs: List<&2, Field>, +used: U32, +capacity: U32, +allowed: U32, pending: Maybe<&2, U32>, minimum: Maybe<&2, U32>) -> State:
  match too_big:
    case True{}:
      State{Nil{}, 0, capacity, allowed, pending, minimum}
    case False{}:
      table.add(U32.is_le(used, (capacity - field.size(field) : U32)), field, xs, used, capacity, allowed, pending, minimum)
def table.insert(+field: Field, st: State) -> State:
  State{xs, +used, +capacity, +allowed, pending, minimum} = st
  +cost = field.size(field)
  table.oversize(U32.is_gt(cost, capacity), field, xs, used, capacity, allowed, pending, minimum)

def field.matches(exact: Bool, f: Field, +name: String, +value: String) -> Bool:
  match exact:
    case True{}:
      Field{n, v, mode} = f
      Bool.and(String.eq(n, name), String.eq(v, value))
    case False{}:
      Field{n, v, mode} = f
      String.eq(n, name)

def find.static(+exact: Bool, n: Nat, +i: U32, +name: String, +value: String, found: U32) -> U32:
  match n found:
    case 0n result:
      result
    case 1n+p 0:
      find.static(exact, p, (i + 1 : U32), name, value,
        Bool.pick(U32, field.matches(exact, static(i), name, value), i, 0))
    case 1n+p result:
      result

def find.dynamic(+exact: Bool, xs: List<&2, Field>, +i: U32, +name: String, +value: String, found: U32) -> U32:
  match xs found:
    case Nil{} result:
      result
    case Con{+field, tail} 0:
      find.dynamic(exact, tail, (i + 1 : U32), name, value,
        Bool.pick(U32, field.matches(exact, field, name, value), i, 0))
    case Con{field, tail} result:
      result

def find.in_dynamic(exact: Bool, st: State, +name: String, +value: String, found: U32) -> U32:
  State{entries, size, capacity, allowed, pending, minimum} = st
  find.dynamic(exact, entries, 62, name, value, found)

def find.index(+exact: Bool, st: State, +name: String, +value: String) -> U32:
  find.in_dynamic(exact, st, name, value, find.static(exact, 61n, 1, name, value, 0))

def limit.min(m: Maybe<&2, U32>, +n: U32) -> U32:
  match m:
    case None{}:
      n
    case Some{+old}:
      Bool.pick(U32, U32.is_lt(n, old), n, old)

def set_limit(+n: U32, st: State) -> State:
  State{entries, size, capacity, allowed, pending, minimum} = st
  State{entries, size, capacity, n, Some{n}, Some{limit.min(minimum, n)}}

def table.resize(+n: U32, st: State) -> State:
  State{entries, size, capacity, allowed, pending, minimum} = st
  table.trimmed(table.trim(entries, n), n, allowed, pending, minimum)

type Step is Type:
  Step{state: State, cursor: Cursor, field: Maybe<&2, Field>}

def with_text.pair(-R: Type, r: Cursor & String, k: Cursor -> String -> R) -> R:
  (cursor, text) = r
  k(cursor, text)

def with_text(-R: Type, m: Maybe<&1, Cursor & String>, k: Cursor -> String -> Maybe<&1, R>) -> Maybe<&1, R>:
  match m:
    case None{}:
      None{}
    case Some{pair}:
      with_text.pair(Maybe<&1, R>, pair, k)

def name.indexed(m: Maybe<&2, Field>, c: Cursor) -> Maybe<&1, Cursor & String>:
  match m:
    case None{}:
      None{}
    case Some{Field{name, value, mode}}:
      Some{(c, name)}

def name.read(+i: U32, st: State, c: Cursor) -> Maybe<&1, Cursor & String>:
  match i:
    case 0:
      literal(c)
    case _:
      name.indexed(indexed(i, st), c)

def decode.indexed.field(m: Maybe<&2, Field>, st: State, c: Cursor) -> Maybe<&1, Step>:
  match m:
    case None{}:
      None{}
    case Some{field}:
      Some{Step{st, c, Some{field}}}

def decode.indexed(+first: U32, +st: State, c: Cursor) -> Maybe<&1, Step>:
  with_taken(Step, integer.after(first, 127, c), cursor => index =>
    decode.indexed.field(indexed(index, st), st, cursor))

def decode.literal.finish(insert: Bool, +field: Field, st: State, c: Cursor) -> Maybe<&1, Step>:
  match insert:
    case True{}:
      Some{Step{table.insert(field, st), c, Some{field}}}
    case False{}:
      Some{Step{st, c, Some{field}}}

def decode.literal(+first: U32, +mask: U32, +mode: U32, +st: State, c: Cursor) -> Maybe<&1, Step>:
  with_taken(Step, integer.after(first, mask, c), cursor => index =>
    with_text(Step, name.read(index, st, cursor), cursor => +name =>
      with_text(Step, literal(cursor), cursor => value =>
        decode.literal.finish(U32.is_eq(mode, 0), Field{name, value, mode}, st, cursor))))

def decode.min(m: Maybe<&2, U32>, +n: U32) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{minimum}:
      U32.is_le(n, minimum)

def decode.updated.from(st: State, c: Cursor) -> Maybe<&1, Step>:
  State{entries, size, capacity, allowed, pending, minimum} = st
  Some{Step{State{entries, size, capacity, allowed, None{}, None{}}, c, None{}}}

def decode.updated(n: U32, st: State, c: Cursor) -> Maybe<&1, Step>:
  decode.updated.from(table.resize(n, st), c)

def decode.update.valid(valid: Bool, +n: U32, st: State, c: Cursor) -> Maybe<&1, Step>:
  match valid:
    case True{}:
      decode.updated(n, st, c)
    case False{}:
      None{}

def decode.update.value(+n: U32, st: State, c: Cursor) -> Maybe<&1, Step>:
  State{entries, size, capacity, +allowed, pending, +minimum} = st
  decode.update.valid(Bool.and(U32.is_le(n, allowed), decode.min(minimum, n)), n,
    State{entries, size, capacity, allowed, pending, minimum}, c)

def decode.update(+first: U32, st: State, c: Cursor, seen: Bool) -> Maybe<&1, Step>:
  do Maybe<&1, Step>:
    unused: Unit <- within(Bool.not(seen))
    with_taken(Step, integer.after(first, 31, c), cursor => size =>
      decode.update.value(size, st, cursor))

def decode.ready(st: State) -> Bool:
  State{entries, size, capacity, allowed, pending, minimum} = st
  Maybe.is_none(&2, U32, pending)

def decode.kind(+first: U32) -> U32:
  Bool.pick(U32, U32.is_ne((first .&. 128 : U32), 0), 0,
    Bool.pick(U32, U32.is_ne((first .&. 64 : U32), 0), 1,
      Bool.pick(U32, U32.is_ne((first .&. 32 : U32), 0), 2, 3)))

def decode.representation(kind: U32, +first: U32, c: Cursor, +st: State, seen: Bool) -> Maybe<&1, Step>:
  match kind:
    case 0:
      do Maybe<&1, Step>:
        unused: Unit <- within(decode.ready(st))
        decode.indexed(first, st, c)
    case 1:
      do Maybe<&1, Step>:
        unused: Unit <- within(decode.ready(st))
        decode.literal(first, 63, 0, st, c)
    case 2:
      decode.update(first, st, c, seen)
    case _:
      do Maybe<&1, Step>:
        unused: Unit <- within(decode.ready(st))
        decode.literal(first, 15, Bool.pick(U32, U32.is_ne((first .&. 16 : U32), 0), 2, 1), st, c)

def decode.one(c: Cursor, +st: State, seen: Bool) -> Maybe<&1, Step>:
  with_taken(Step, take(c), cursor => +first =>
    decode.representation(decode.kind(first), first, cursor, st, seen))

def decode.add(m: Maybe<&2, Field>, acc: List<&2, Field>, seen: Bool) -> List<&2, Field> & Bool:
  match m:
    case None{}:
      (acc, seen)
    case Some{field}:
      (Con{field, acc}, True{})

def with_step(-R: Type, step: Step, k: State -> Cursor -> Maybe<&2, Field> -> R) -> R:
  Step{state, cursor, field} = step
  k(state, cursor, field)

def with_end(-R: Type, c: Cursor, k: Cursor -> Bool -> R) -> R:
  Cursor{bytes, +at, +length} = c
  k(Cursor{bytes, at, length}, U32.is_eq(at, length))

def with_fields(-R: Type, r: List<&2, Field> & Bool, k: List<&2, Field> -> Bool -> R) -> R:
  (fields, seen) = r
  k(fields, seen)

def decode.go(fuel: Nat, ended: Bool, c: Cursor, st: State, acc: List<&2, Field>, +seen: Bool) -> Maybe<&1, State & List<&2, Field>>:
  match fuel ended:
    case 0n False{}:
      None{}
    case 0n True{}:
      Some{(st, List.reverse(&2, Field, acc))}
    case 1n+p True{}:
      Some{(st, List.reverse(&2, Field, acc))}
    case 1n+p False{}:
      Maybe.bind(&1, Step, State & List<&2, Field>, decode.one(c, st, seen), step =>
        with_step(Maybe<&1, State & List<&2, Field>>, step, state => cursor => field =>
          with_end(Maybe<&1, State & List<&2, Field>>, cursor, cursor => ended =>
            with_fields(Maybe<&1, State & List<&2, Field>>, decode.add(field, acc, seen), fields => was_field =>
              decode.go(p, ended, cursor, state, fields, was_field)))))

def decode(block: Bytes.Bytes, st: State) -> Maybe<&1, State & List<&2, Field>>:
  Bytes.Bytes{+length, buf} = block
  decode.go(1n+U32.to_nat(length), U32.is_eq(length, 0),
    Cursor{Bytes.Bytes{length, buf}, 0, length}, st, Nil{}, False{})

def integer.tail(n: Nat, +value: U32, active: Bool) -> String:
  match n active:
    case 0n _:
      SNil{}
    case 1n+p False{}:
      SNil{}
    case 1n+p True{}:
      SCon{Chr{((value .&. 127 : U32) .|. Bool.pick(U32, U32.is_ge(value, 128), 128, 0) : U32)},
        integer.tail(p, (value >> 7n : U32), U32.is_ge(value, 128))}

def integer.encoded(small: Bool, +prefix: U32, +mask: U32, +value: U32) -> Bytes.Bytes:
  match small:
    case True{}:
      Bytes.from_string(SCon{Chr{(prefix .|. value : U32)}, SNil{}})
    case False{}:
      Bytes.from_string(SCon{Chr{(prefix .|. mask : U32)},
        integer.tail(5n, (value - mask : U32), True{})})

def integer.encode(+prefix: U32, +mask: U32, +value: U32) -> Bytes.Bytes:
  integer.encoded(U32.is_lt(value, mask), prefix, mask, value)

def octets.valid(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+octet}, tail}:
      Bool.and(U32.is_le(octet, 255), octets.valid(tail))

def literal.raw(+s: String) -> Maybe<&1, Bytes.Bytes>:
  do Maybe<&1, Bytes.Bytes>:
    unused: Unit <- within(octets.valid(s))
    return Bytes.from_string(s)

def literal.pack(b: Bytes.Bytes, huff: Bool) -> Bytes.Bytes:
  Bytes.Bytes{+length, buf} = b
  Bytes.concat([integer.encode(Bool.pick(U32, huff, 128, 0), 127, length), Bytes.Bytes{length, buf}])

def literal.encode(huff: Bool, s: String) -> Maybe<&1, Bytes.Bytes>:
  match huff:
    case True{}:
      Maybe.map(&1, Bytes.Bytes, Bytes.Bytes, b => literal.pack(b, True{}), Huff.encode(s))
    case False{}:
      Maybe.map(&1, Bytes.Bytes, Bytes.Bytes, b => literal.pack(b, False{}), literal.raw(s))

def name.parts(+index: U32, huff: Bool, name: String) -> Maybe<&1, List<&1, Bytes.Bytes>>:
  match index:
    case 0:
      Maybe.map(&1, Bytes.Bytes, List<&1, Bytes.Bytes>, b => [b], literal.encode(huff, name))
    case _:
      Some{Nil{}}

def encode.literal.bytes(+index: U32, +prefix: U32, +mask: U32, +huff: Bool, name: String, value: String) -> Maybe<&1, Bytes.Bytes>:
  do Maybe<&1, Bytes.Bytes>:
    parts: List<&1, Bytes.Bytes> <- name.parts(index, huff, name)
    encoded: Bytes.Bytes <- literal.encode(huff, value)
    return Bytes.concat(Con{integer.encode(prefix, mask, index),
      List.append(&1, Bytes.Bytes, parts, [encoded])})

def encode.literal.done(insert: Bool, field: Field, st: State, b: Bytes.Bytes) -> Maybe<&1, State & Bytes.Bytes>:
  match insert:
    case True{}:
      Some{(table.insert(field, st), b)}
    case False{}:
      Some{(st, b)}

def encode.literal(+mode: U32, +name: String, +value: String, huff: Bool, +st: State) -> Maybe<&1, State & Bytes.Bytes>:
  +index = find.index(False{}, st, name, value)
  +prefix = Bool.pick(U32, U32.is_eq(mode, 0), 64, Bool.pick(U32, U32.is_eq(mode, 2), 16, 0))
  +mask = Bool.pick(U32, U32.is_eq(mode, 0), 63, 15)
  Maybe.bind(&1, Bytes.Bytes, State & Bytes.Bytes,
    encode.literal.bytes(index, prefix, mask, huff, name, value), b =>
      encode.literal.done(U32.is_eq(mode, 0), Field{name, value, mode}, st, b))

def encode.exact(found: Bool, +index: U32, +name: String, +value: String, huff: Bool, st: State) -> Maybe<&1, State & Bytes.Bytes>:
  match found:
    case True{}:
      Some{(st, integer.encode(128, 127, index))}
    case False{}:
      encode.literal(0, name, value, huff, st)

def encode.field(f: Field, huff: Bool, +st: State) -> Maybe<&1, State & Bytes.Bytes>:
  Field{+name, +value, mode} = f
  match mode:
    case 0:
      +index = find.index(True{}, st, name, value)
      encode.exact(U32.is_ne(index, 0), index, name, value, huff, st)
    case 1:
      encode.literal(1, name, value, huff, st)
    case 2:
      encode.literal(2, name, value, huff, st)
    case _:
      None{}


def encode.cleared(st: State, pieces: List<&1, Bytes.Bytes>) -> State & List<&1, Bytes.Bytes>:
  State{entries, size, capacity, allowed, pending, minimum} = st
  (State{entries, size, capacity, allowed, None{}, None{}}, pieces)

def encode.emit(smaller: Bool, +minimum: U32, +final: U32, st: State) -> State & List<&1, Bytes.Bytes>:
  match smaller:
    case True{}:
      encode.cleared(table.resize(final, table.resize(minimum, st)),
        [integer.encode(32, 31, minimum), integer.encode(32, 31, final)])
    case False{}:
      encode.cleared(table.resize(final, st), [integer.encode(32, 31, final)])

def encode.pending(m: Maybe<&2, U32>, minimum: Maybe<&2, U32>, st: State) -> State & List<&1, Bytes.Bytes>:
  match m:
    case None{}:
      (st, Nil{})
    case Some{+final}:
      +smallest = limit.min(minimum, final)
      encode.emit(U32.is_lt(smallest, final), smallest, final, st)

def encode.prepare(st: State) -> State & List<&1, Bytes.Bytes>:
  State{entries, size, capacity, allowed, +pending, +minimum} = st
  encode.pending(pending, minimum, State{entries, size, capacity, allowed, pending, minimum})

def with_encoded(-R: Type, r: State & Bytes.Bytes, k: State -> Bytes.Bytes -> R) -> R:
  (st, bytes) = r
  k(st, bytes)

def encode.go(xs: List<&2, Field>, +huff: Bool, st: State, acc: List<&1, Bytes.Bytes>) -> Maybe<&1, State & List<&1, Bytes.Bytes>>:
  match xs:
    case Nil{}:
      Some{(st, acc)}
    case Con{field, tail}:
      Maybe.bind(&1, State & Bytes.Bytes, State & List<&1, Bytes.Bytes>, encode.field(field, huff, st), pair =>
        with_encoded(Maybe<&1, State & List<&1, Bytes.Bytes>>, pair, state => bytes =>
          encode.go(tail, huff, state, Con{bytes, acc})))

def encode.finish(r: State & List<&1, Bytes.Bytes>) -> State & Bytes.Bytes:
  (st, pieces) = r
  (st, Bytes.concat(List.reverse(&1, Bytes.Bytes, pieces)))

def encode.from(r: State & List<&1, Bytes.Bytes>, fields: List<&2, Field>, huff: Bool) -> Maybe<&1, State & Bytes.Bytes>:
  (st, updates) = r
  Maybe.map(&1, State & List<&1, Bytes.Bytes>, State & Bytes.Bytes, encode.finish,
    encode.go(fields, huff, st, List.reverse(&1, Bytes.Bytes, updates)))

def encode(fields: List<&2, Field>, huff: Bool, st: State) -> Maybe<&1, State & Bytes.Bytes>:
  encode.from(encode.prepare(st), fields, huff)

