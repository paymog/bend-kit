import Base
import ../text.bend as T
import ../byte_check.bend as Check
import ./bench.bend as Bench
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def verified(r: Array<U32> & Array<U32> & Bool, t0: Time.Duration) -> IO(Unit):
  (_, _, ok) = r
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("verify ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    IO.print("verified\t" ++ Bool.show(ok))

def script(+es: List<&2, T.Edit<T.ByteRange>>, a: Bytes.Bytes, b: Bytes.Bytes, t0: Time.Duration) -> IO(Unit):
  Bytes.Bytes{_, aa} = a
  Bytes.Bytes{_, ba} = b
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("myers ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    IO.print("checksum\t" ++ U32.show(Check.changed(es)))
    t2 : Time.Duration <- Time.mono()
    verified(T.byte_paired(es, (aa, ba, True{}), True{}), t2)

def prepared(c: T.Ctx<U32>, +n: U32, +m: U32, +off: U32, +old: List<&2, T.ByteRange>, +new: List<&2, T.ByteRange>, a: Bytes.Bytes, b: Bytes.Bytes, t0: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("setup ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    t2 : Time.Duration <- Time.mono()
    script(T.walk(T.ByteRange, T.canon(T.solve(~U32, ~U32.is_eq, U32.to_nat((8 * (n + m) + 8 : U32)), (c, [T.JSolve{0, n, 0, m}]), off, Nil{}), 0n, 0n), old, new), a, b, t2)

def setup(+old: List<&2, T.ByteRange>, +new: List<&2, T.ByteRange>, a: Bytes.Bytes, b: Bytes.Bytes, t0: Time.Duration) -> IO(Unit):
  +n = U32.from_nat(List.length(&2, T.ByteRange, old))
  +m = U32.from_nat(List.length(&2, T.ByteRange, new))
  +off = (n + m + 2 : U32)
  c : T.Ctx<U32> = T.Ctx{T.fill(~U32, T.keys(~T.ByteRange, ~T.byte_range.key, old), T.array(~U32, n, 0), 0), T.fill(~U32, T.keys(~T.ByteRange, ~T.byte_range.key, new), T.array(~U32, m, 0), 0), T.array(~U32, (off + off : U32), 0), T.array(~U32, (off + off : U32), 0)}
  prepared(c, n, m, off, old, new, a, b, t0)

def scanned(ar: Bytes.Bytes & List<&2, T.ByteRange>, br: Bytes.Bytes & List<&2, T.ByteRange>, t0: Time.Duration) -> IO(Unit):
  (a, old1) = ar
  (b, new1) = br
  +old = {old1 : List<&2, T.ByteRange>}
  +new = {new1 : List<&2, T.ByteRange>}
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("scan ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    t2 : Time.Duration <- Time.mono()
    setup(old, new, a, b, t2)

def ready(a: Bytes.Bytes, b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    scanned(T.byte_lines(a), T.byte_lines(b), t0)

def main() -> IO(Unit):
  ready(Bytes.from_string(String.join(Bench.old.go(10000n, 0), "\n") ++ "\n"), Bytes.from_string(String.join(Bench.new.go(10000n, 0), "\n") ++ "\n"))
