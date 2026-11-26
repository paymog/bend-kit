import Base
import ./text.bend as T
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def collect.part(r: Bytes.Bytes & Bytes.Bytes, out: List<&2, String>) -> Bytes.Bytes & List<&2, String>:
  (b, part) = r
  (b, Bytes.to_string(part) <> out)

def collect(rs: List<&2, T.ByteRange>, r: Bytes.Bytes & List<&2, String>) -> Bytes.Bytes & String:
  match rs:
    case Nil{}:
      (b, out) = r
      (b, String.concat(List.reverse(&2, String, out)))
    case Con{T.ByteRange{i, n, _}, t}:
      (b, out) = r
      collect(t, collect.part(Bytes.slice(b, i, n), out))

def changed(es: List<&2, T.Edit<T.ByteRange>>) -> U32:
  match es:
    case Nil{}:
      0
    case Con{T.Same{_, _}, t}:
      changed(t)
    case Con{_, t}:
      (1 + changed(t) : U32)

def finish.new(a: Bytes.Bytes, ar: String, r: Bytes.Bytes & String, es: List<&2, T.Edit<T.ByteRange>>, +old: String, +new: String, n: U32) -> Bool:
  (b, br) = r
  Bool.and(String.eq(old, ar), Bool.and(String.eq(new, br), Bool.and(String.eq(old, Bytes.to_string(a)), Bool.and(String.eq(new, Bytes.to_string(b)), U32.is_eq(changed(es), n)))))

def finish.old(r: Bytes.Bytes & String, b: Bytes.Bytes, +es: List<&2, T.Edit<T.ByteRange>>, old: String, new: String, n: U32) -> Bool:
  (a, ar) = r
  finish.new(a, ar, collect(T.after(T.ByteRange, es), (b, Nil{})), es, old, new, n)

def result(r: Bytes.Bytes & Bytes.Bytes & List<&2, T.Edit<T.ByteRange>>, old: String, new: String, n: U32) -> Bool:
  (a, b, es1) = r
  +es = {es1 : List<&2, T.Edit<T.ByteRange>>}
  finish.old(collect(T.before(T.ByteRange, es), (a, Nil{})), b, es, old, new, n)

def pair(+old: String, +new: String, n: U32) -> Bool:
  result(T.diff_bytes(Bytes.from_string(old), Bytes.from_string(new)), old, new, n)

def fallback.new(a: Bytes.Bytes, +ar: List<&2, T.ByteRange>, r: Bytes.Bytes & List<&2, T.ByteRange>) -> Bytes.Bytes & Bytes.Bytes & List<&2, T.Edit<T.ByteRange>>:
  Bytes.Bytes{an, aa} = a
  (Bytes.Bytes{bn, b}, +br) = r
  T.byte_diff.wrap(an, bn, T.byte_diff.pick(False{}, Nil{}, aa, b, ar, br))

def fallback.old(r: Bytes.Bytes & List<&2, T.ByteRange>, b: Bytes.Bytes) -> Bytes.Bytes & Bytes.Bytes & List<&2, T.Edit<T.ByteRange>>:
  (a, ar) = r
  fallback.new(a, ar, T.byte_lines(b))

def fallback(+old: String, +new: String, n: U32) -> Bool:
  result(fallback.old(T.byte_lines(Bytes.from_string(old)), Bytes.from_string(new)), old, new, n)

def packed.tails(n: Nat, +prefix: String, +suffix: String) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      fallback(prefix ++ suffix, prefix ++ suffix, 0) &&
      fallback(prefix ++ suffix, "\n" ++ prefix ++ suffix, 1) &&
      fallback(prefix ++ suffix ++ "\0", prefix ++ suffix ++ "\0\0", 2) &&
      fallback(prefix ++ suffix ++ "\u{FF}", prefix ++ suffix ++ "\u{FE}", 2) &&
      packed.tails(p, prefix, suffix ++ "\u{80}")

def packed.offsets(n: Nat, +prefix: String) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      packed.tails(9n, prefix ++ "\n", "") && packed.offsets(p, prefix ++ "x")

def run() -> IO(Unit):
  do IO<Unit>:
    +ok : Bool = pair("", "", 0) && pair("", "a\n", 1) && pair("a", "", 1) && pair("\n\n", "\n", 1) && pair("a\r\n", "a\n", 2) && pair("a\n", "a", 2) && pair("\u{C3}\u{A9}\n", "\u{E6}\u{97}\u{A5}\n", 2) && pair("\0\u{FF}\n\u{80}", "\0\u{FF}\n\u{81}", 2) && pair("x\naan1wu\ny\n", "x\naa0tfa\ny\n", 2) && pair("a\nb\na\n", "b\na\nb\n", 2)
    IO.print("packed diff boundary and collision round trips: " ++ Bool.show(ok))
    +packed : Bool = packed.offsets(4n, "")
    IO.print("packed fallback offsets, tails, and lengths: " ++ Bool.show(packed))
    Bool.pick(IO(Unit), packed, IO.pure(Unit, Unit{}), IO.die(Unit, 1, "packed fallback regression"))
    Bool.pick(IO(Unit), ok, IO.pure(Unit, Unit{}), IO.die(Unit, 1, "packed diff regression"))
