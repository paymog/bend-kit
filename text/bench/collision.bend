import Base
import ../text.bend as T
import ../byte_check.bend as Check
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

def allocations() -> IO(String):
  import "./collision.c"
  import "./collision.js"

def start() -> IO(Time.Duration):
  do IO<Time.Duration>:
    _ : String <- allocations()
    Time.mono()

def stop(+label: String, t0: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    counts : String <- allocations()
    IO.print(label ++ " ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    IO.print(label ++ " allocations\t" ++ counts)

def pad(n: Nat) -> String:
  match n:
    case 0n:
      "\0\u{FF}\u{80}\r\n"
    case 1n+p:
      "xxxxxxxx" ++ pad(p)

def lines(n: Nat, +i: U32, +special: String) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      (Bool.pick(String, U32.is_eq((i % 100 : U32), 7), special, "line " ++ U32.show(i)) ++ pad(16n)) <> lines(p, (i + 1 : U32), special)

def result(r: Array<U32> & Array<U32> & List<&2, T.Edit<T.ByteRange>>, +an: U32, +bn: U32, +old: String, +new: String, expected: U32, t0: Time.Duration) -> IO(Unit):
  (a, b, es1) = r
  +es = {es1 : List<&2, T.Edit<T.ByteRange>>}
  do IO<Unit>:
    stop("fallback", t0)
    IO.print("checksum\t" ++ U32.show(Check.changed(es)))
    t2 : Time.Duration <- start()
    +ok : Bool = Check.result((Bytes.Bytes{an, a}, Bytes.Bytes{bn, b}, es), old, new, expected)
    stop("materialize", t2)
    IO.print("roundtrip\t" ++ Bool.show(ok))
    Bool.pick(IO(Unit), ok, IO.pure(Unit, Unit{}), IO.die(Unit, 1, "collision regression"))

def verified(r: Array<U32> & Array<U32> & Bool, es: List<&2, T.Edit<T.ByteRange>>, +ar: List<&2, T.ByteRange>, +br: List<&2, T.ByteRange>, an: U32, bn: U32, old: String, new: String, expected: U32, t0: Time.Duration) -> IO(Unit):
  (a, b, ok1) = r
  +ok = {ok1 : Bool}
  do IO<Unit>:
    stop("verify", t0)
    IO.print("hash script exact\t" ++ Bool.show(ok))
    t1 : Time.Duration <- start()
    result(T.byte_diff.pick(ok, es, a, b, ar, br), an, bn, old, new, expected, t1)

def hashed(+es: List<&2, T.Edit<T.ByteRange>>, a: Bytes.Bytes, b: Bytes.Bytes, ar: List<&2, T.ByteRange>, br: List<&2, T.ByteRange>, old: String, new: String, expected: U32, t0: Time.Duration) -> IO(Unit):
  Bytes.Bytes{an, aa} = a
  Bytes.Bytes{bn, ba} = b
  do IO<Unit>:
    stop("hash diff", t0)
    t1 : Time.Duration <- start()
    verified(T.byte_paired(es, (aa, ba, True{}), True{}), es, ar, br, an, bn, old, new, expected, t1)

def scanned(x: Bytes.Bytes & List<&2, T.ByteRange>, y: Bytes.Bytes & List<&2, T.ByteRange>, old: String, new: String, expected: U32, t0: Time.Duration) -> IO(Unit):
  (a, ar1) = x
  (b, br1) = y
  +ar = {ar1 : List<&2, T.ByteRange>}
  +br = {br1 : List<&2, T.ByteRange>}
  do IO<Unit>:
    stop("scan", t0)
    t1 : Time.Duration <- start()
    hashed(T.walk(T.ByteRange, T.moves(~U32, ~U32.is_eq, T.keys(~T.ByteRange, ~T.byte_range.key, ar), T.keys(~T.ByteRange, ~T.byte_range.key, br)), ar, br), a, b, ar, br, old, new, expected, t1)

def converted(a: Bytes.Bytes, b: Bytes.Bytes, old: String, new: String, expected: U32, t0: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    stop("convert", t0)
    t1 : Time.Duration <- start()
    scanned(T.byte_lines(a), T.byte_lines(b), old, new, expected, t1)

def run(+old: String, +new: String, +expected: U32) -> IO(Unit):
  do IO<Unit>:
    +ok : Bool = Check.pair(old, new, expected)
    IO.print("public roundtrip\t" ++ Bool.show(ok))
    Bool.pick(IO(Unit), ok, IO.pure(Unit, Unit{}), IO.die(Unit, 1, "public diff regression"))
    clock : Time.Duration <- start()
    stop("clock", clock)
    t0 : Time.Duration <- start()
    converted(Bytes.from_string(old), Bytes.from_string(new), old, new, expected, t0)

def args(as: List<&1, String>) -> IO(Unit):
  match as:
    case _ <> mode <> n <> Nil{}:
      +size = Maybe.default(&2, U32, U32.read(n), 10000)
      +special = Bool.pick(String, String.eq(mode, "collision"), "aa0tfa", "aa0tfb")
      run(String.concat(lines(U32.to_nat(size), 0, "aan1wu")), String.concat(lines(U32.to_nat(size), 0, special)), (2 * ((size + 92 : U32) / 100 : U32) : U32))
    case _:
      IO.die(Unit, 1, "usage: collision collision|control 10000")

def main() -> IO(Unit):
  do IO<Unit>:
    Check.run()
    as : List<&1, String> <- IO.args()
    args(as)
