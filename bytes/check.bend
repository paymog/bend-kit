import Base
import ./bytes.bend as Bytes
import 0x4eed9d7ac6ece61523d747a9d804e4f0/int.bend as Int

# The laws run in the checker, where Array is a tree of defs. This runs the same
# operations on the runtime's native Array, at sizes the checker would not reach.
# Strings stay at 10 KB: `bend check.bend` overflowed on this file at 20 KB, though a native build passes.

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

def of(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def str(b: Bytes.Bytes) -> String:
  Bytes.to_string(b)

def val(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (b, x) = r
  x

def num(r: Bytes.Bytes & U32) -> U32:
  (b, n) = r
  n

def left(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(a)

def right(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(b)

def rightb(r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes:
  (a, b) = r
  b

def same(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, ok) = r
  ok

def expect(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def has64(r: Bytes.Bytes & Maybe<&2, Int.U64>, +v: String) -> Bool:
  (b, m) = r
  match m:
    case None{}:
      False{}
    case Some{x}:
      String.eq(Int.U64.show(x), v)

def has(m: Maybe<&2, U32>, +v: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      U32.is_eq(x, v)

def none(m: Maybe<&2, U32>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{x}:
      False{}

def rep(n: Nat, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      rep(p, SCon{'a', acc})

def big() -> String:
  rep(10000n, "\r\n\r\n")

# One byte at a time: with a new buffer per append this was O(n²).
def build(n: Nat, acc: Bytes.Bytes) -> Bytes.Bytes:
  match n:
    case 0n:
      acc
    case 1n+p:
      build(p, Bytes.append(acc, Bytes.set(Bytes.new(1), 0, 120)))

def pieces(xs: List<&1, Bytes.Bytes>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{x, t}:
      pieces(t, (n + 1 : U32))

def yes(r: Bytes.Bytes & Bool) -> Bool:
  (b, ok) = r
  ok

def order(r: Bytes.Bytes & Bytes.Bytes & Cmp) -> Cmp:
  (a, b, c) = r
  c

def dec(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "none"
    case Some{b}:
      str(b)

def cursor.sought(r: Bytes.Cursor & Bool) -> Bytes.Cursor:
  (c, ok) = r
  c

def cursor.at(+i: U32, +n: U32) -> Bytes.Cursor:
  cursor.sought(Bytes.Cursor.seek(Bytes.Cursor.new(Bytes.new(n)), i))

def cursor.roundtrip.read(+expected: U32, +ok: Bool, r: Bytes.Cursor & Maybe<&2, U32>) -> Bool:
  (Bytes.Cursor{b, pos, start, end}, value) = r
  ok && U32.is_eq(pos, expected) && has(value, 171)

def cursor.roundtrip.wrote(~read: Bytes.Cursor -> Bytes.Cursor & Maybe<&2, U32>, +width: U32, +at: U32, r: Bytes.Cursor & Bool) -> Bool:
  (Bytes.Cursor{b, pos, start, end}, wrote) = r
  +expected = (at + width : U32)
  cursor.roundtrip.read(expected, wrote && U32.is_eq(pos, expected), read(Bytes.Cursor{b, at, start, end}))

def cursor.roundtrip(~read: Bytes.Cursor -> Bytes.Cursor & Maybe<&2, U32>, ~write: Bytes.Cursor -> U32 -> Bytes.Cursor & Bool, +width: U32, +at: U32) -> Bool:
  cursor.roundtrip.wrote(~read, width, at, write(cursor.at(at, 16), 171))

def cursor.boundary(xs: List<&2, U32>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{+at, rest}:
      do IO<Unit>:
        expect("cursor u8 at " ++ U32.show(at), cursor.roundtrip(~Bytes.Cursor.u8, ~Bytes.Cursor.put.u8, 1, at))
        expect("cursor u16be at " ++ U32.show(at), cursor.roundtrip(~Bytes.Cursor.u16be, ~Bytes.Cursor.put.u16be, 2, at))
        expect("cursor u16le at " ++ U32.show(at), cursor.roundtrip(~Bytes.Cursor.u16le, ~Bytes.Cursor.put.u16le, 2, at))
        expect("cursor u32be at " ++ U32.show(at), cursor.roundtrip(~Bytes.Cursor.u32be, ~Bytes.Cursor.put.u32be, 4, at))
        expect("cursor u32le at " ++ U32.show(at), cursor.roundtrip(~Bytes.Cursor.u32le, ~Bytes.Cursor.put.u32le, 4, at))
        cursor.boundary(rest)

def cursor.failed.wrote(+ok: Bool, +at: U32, +n: U32, r: Bytes.Cursor & Bool) -> Bool:
  (Bytes.Cursor{b, pos, start, end}, wrote) = r
  ok && Bool.not(wrote) && U32.is_eq(pos, at) && String.eq(str(b), rep(U32.to_nat(n), ""))

def cursor.failed.read(+at: U32, r: Bytes.Cursor & Maybe<&2, U32>) -> Bool:
  (Bytes.Cursor{b, +pos, start, end}, m) = r
  +ok = none(m) && U32.is_eq(pos, at)
  cursor.failed.wrote(ok, at, 4, Bytes.Cursor.put.u32le(Bytes.Cursor{b, pos, start, end}, 4294967295))

def cursor.failed() -> Bool:
  cursor.failed.read(1, Bytes.Cursor.u32be(Bytes.Cursor{of("aaaa"), 1, 0, 4}))

def cursor.end() -> Bool:
  cursor.failed.read(4, Bytes.Cursor.u8(Bytes.Cursor{of("aaaa"), 4, 0, 4}))

def cursor.region.left(c: Bytes.Cursor, +ok: Bool) -> Bool:
  Bytes.Cursor{b, pos, start, end} = c
  ok && U32.is_eq(pos, 3) && U32.is_eq(start, 0) && U32.is_eq(end, 8) && String.eq(str(b), bytes([0, 18, 52, 0, 0, 0, 0, 0]))

def cursor.region.wrote(limit: Bytes.CursorLimit, +ok: Bool, r: Bytes.Cursor & Bool) -> Bool:
  (Bytes.Cursor{b, +pos, start, +end}, wrote) = r
  cursor.region.left(Bytes.Cursor.leave(Bytes.Cursor{b, pos, start, end}, limit), ok && wrote && U32.is_eq(pos, end))

def cursor.region.read(limit: Bytes.CursorLimit, r: Bytes.Cursor & Maybe<&2, U32>) -> Bool:
  (c, bad) = r
  cursor.region.wrote(limit, none(bad), Bytes.Cursor.put.u16be(c, 4660))

def cursor.region.result(r: Bytes.Cursor & Maybe<&1, Bytes.CursorLimit>) -> Bool:
  (c, m) = r
  match m:
    case None{}:
      False{}
    case Some{limit}:
      cursor.region.read(limit, Bytes.Cursor.u32be(c))

def cursor.wide.read(+want: String, +expected: U32, +ok: Bool, r: Bytes.Cursor & Maybe<&2, Int.U64>) -> Bool:
  (Bytes.Cursor{b, pos, start, end}, m) = r
  ok && U32.is_eq(pos, expected) && has64((b, m), want)

def cursor.wide.wrote(~read: Bytes.Cursor -> Bytes.Cursor & Maybe<&2, Int.U64>, +want: String, +at: U32, r: Bytes.Cursor & Bool) -> Bool:
  (Bytes.Cursor{b, +pos, start, end}, ok) = r
  cursor.wide.read(want, (at + 8 : U32), ok && U32.is_eq(pos, (at + 8 : U32)), read(Bytes.Cursor{b, at, start, end}))

def cursor.wide() -> Bool:
  cursor.wide.wrote(~Bytes.Cursor.u64be, "18446744073709551615", 3, Bytes.Cursor.put.u64be(cursor.at(3, 11), Int.U64.MAX()))

def cursor.wide.le() -> Bool:
  cursor.wide.wrote(~Bytes.Cursor.u64le, "16909060", 1, Bytes.Cursor.put.u64le(cursor.at(1, 9), Int.U64.from_u32(16909060)))

def cursor.seek.rejected(r: Bytes.Cursor & Bool) -> Bool:
  (Bytes.Cursor{b, pos, start, end}, ok) = r
  Bool.not(ok) && U32.is_eq(pos, 2) && U32.is_eq(start, 1) && U32.is_eq(end, 3) && String.eq(str(b), "aaaa")

def cursor.nested.remaining(r: Bytes.Cursor & U32) -> Bool:
  (Bytes.Cursor{b, pos, start, end}, n) = r
  U32.is_eq(n, 2) && U32.is_eq(pos, 6) && U32.is_eq(start, 0) && U32.is_eq(end, 8) && String.eq(str(b), "abcdefgh")

def cursor.nested.left(c: Bytes.Cursor) -> Bool:
  cursor.nested.remaining(Bytes.Cursor.remaining(c))

def cursor.nested.inner(outer: Bytes.CursorLimit, r: Bytes.Cursor & Maybe<&1, Bytes.CursorLimit>) -> Bool:
  (c, m) = r
  match m:
    case None{}:
      False{}
    case Some{inner}:
      cursor.nested.left(Bytes.Cursor.leave(Bytes.Cursor.leave(c, inner), outer))

def cursor.nested.skipped(outer: Bytes.CursorLimit, r: Bytes.Cursor & Bool) -> Bool:
  (c, ok) = r
  Bool.and(ok, cursor.nested.inner(outer, Bytes.Cursor.region(c, 2)))

def cursor.nested(r: Bytes.Cursor & Maybe<&1, Bytes.CursorLimit>) -> Bool:
  (c, m) = r
  match m:
    case None{}:
      False{}
    case Some{outer}:
      cursor.nested.skipped(outer, Bytes.Cursor.skip(c, 1))

def main() -> IO(Unit):
  do IO<Unit>:
    cursor.boundary([0, 1, 3, 4, 12])
    expect("cursor failed operations are atomic", cursor.failed())
    expect("cursor at end", cursor.end())
    expect("cursor bounded region", cursor.region.result(Bytes.Cursor.region(cursor.at(1, 8), 2)))
    expect("cursor u64be unaligned", cursor.wide())
    expect("cursor u64le unaligned", cursor.wide.le())
    expect("cursor region rejects crossing write", cursor.failed.read(2, Bytes.Cursor.u32be(Bytes.Cursor{of("aaaa"), 2, 1, 3})))
    expect("cursor seek rejects before region", cursor.seek.rejected(Bytes.Cursor.seek(Bytes.Cursor{of("aaaa"), 2, 1, 3}, 0)))
    expect("cursor nested regions restore bounds and skip unread bytes", cursor.nested(Bytes.Cursor.region(Bytes.Cursor{of("abcdefgh"), 1, 0, 8}, 5)))
    expect("roundtrip", String.eq(str(of("hello, world")), "hello, world"))
    expect("roundtrip octets", String.eq(str(of(bytes([0, 128, 255, 13, 10]))), bytes([0, 128, 255, 13, 10])))
    expect("roundtrip 10 KB", String.eq(str(of(big())), big()))
    expect("get past len", none(val(Bytes.get(of("hi"), 2))))
    expect("set", String.eq(str(Bytes.set(of("hello"), 4, 33)), "hell!"))
    expect("set 1 MB", has(val(Bytes.get(Bytes.set(Bytes.new(1000003), 1000002, 7), 1000002)), 7))
    expect("get 1 MB past len", none(val(Bytes.get(Bytes.new(1000003), 1000003))))
    expect("length 1 MB", U32.is_eq(num(Bytes.length(Bytes.new(1000003))), 1000003))
    expect("find header end", has(val(Bytes.find(of("GET / HTTP/1.1\r\n\r\nbody"), "\r\n\r\n")), 14))
    expect("find 10 KB", has(val(Bytes.find(of(big()), "\r\n\r\n")), 10000))
    expect("find missing", none(val(Bytes.find(of(big()), "b"))))
    expect("slice 10 KB", String.eq(right(Bytes.slice(of(big()), 9998, 10)), "aa\r\n\r\n"))
    expect("append", String.eq(str(Bytes.append(of("ab"), of("cde"))), "abcde"))
    expect("append 10 KB", has(val(Bytes.find(Bytes.append(of(big()), of("xyz")), "xyz")), 10004))
    expect("eq 10 KB", same(Bytes.eq(of(big()), of(big()))))
    expect("eq 10 KB differs", Bool.not(same(Bytes.eq(Bytes.set(of(big()), 5, 98), of(big())))))
    expect("eq after set", same(Bytes.eq(Bytes.set(of("abc"), 1, 98), of("abc"))))
    expect("slice 10 KB offset 1", String.eq(right(Bytes.slice(of(big()), 1, 10003)), String.drop(big(), 1n)))
    expect("slice 10 KB offset 3 eq", same(Bytes.eq(rightb(Bytes.slice(of(big()), 3, 10001)), of(String.drop(big(), 3n)))))
    expect("append 10 KB aligned", String.eq(str(Bytes.append(of(big()), of("wxyz"))), big() ++ "wxyz"))
    expect("append 200 K one byte at a time", U32.is_eq(num(Bytes.length(build(200000n, Bytes.new(0)))), 200000))
    expect("u32be 1 MB", has(val(Bytes.get.u32be(Bytes.set.u32be(Bytes.new(1000003), 999999, 3735928559), 999999)), 3735928559))
    expect("u64le 1 MB", has64(Bytes.get.u64le(Bytes.set.u64le(Bytes.new(1000003), 999993, Int.U64.MAX()), 999993), "18446744073709551615"))
    expect("u16le past 1 MB len", none(val(Bytes.get.u16le(Bytes.new(1000003), 1000002))))
    expect("find.from 10 KB", has(val(Bytes.find.from(of(big()), "\r\n\r\n", 1)), 10000))
    expect("rfind 10 KB", has(val(Bytes.rfind(of(big()), "a")), 9999))
    expect("split 10 KB", U32.is_eq(pieces(Bytes.split(of(big()), "a"), 0), 10001))
    expect("ends_with 10 KB", yes(Bytes.ends_with(of(big()), "a\r\n\r\n")))
    expect("cmp 10 KB last byte", Cmp.is_lt(order(Bytes.cmp(of(big()), Bytes.set(of(big()), 10003, 11)))))
    expect("hex 10 KB", String.eq(dec(Bytes.from_hex(Bytes.to_hex(of(big())))), big()))
    expect("base64 10 KB", String.eq(dec(Bytes.from_base64(Bytes.to_base64(of(big())))), big()))
