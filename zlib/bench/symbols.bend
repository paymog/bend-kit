import Base
import ../zlib.bend as Z
import ../encode.bend as Encode
import ../../time/time.bend as Time

def checksum(t: Encode.Token) -> U32:
  match t:
    case Encode.Lit{s}:
      s
    case Encode.Copy{ls, le, lv, ds, de, dv}:
      (ls + le + lv + ds + de + dv : U32)

def scan(bs: List<&2, U32>, es: List<&2, U32>, +v: U32, +i: U32, +best: Z.Cx) -> Z.Cx:
  match bs:
    case Nil{}:
      best
    case Con{+b, bt}:
      match es:
        case Nil{}:
          best
        case Con{+e, et}:
          scan(bt, et, v, (i + 1 : U32), Bool.pick(Z.Cx, U32.is_le(b, v), Z.Cx{i, b, e}, best))

def legacy(+len: U32, +dist: U32) -> Encode.Token:
  Z.es.copy(len, dist, scan(Z.len.base(), Z.len.extra(), len, 0, Z.Cx{0, 3, 0}), scan(Z.dist.base(), Z.dist.extra(), dist, 0, Z.Cx{0, 1, 0}))

def mapped(+len: U32, +dist: U32) -> Encode.Token:
  Z.es.copy(len, dist, Z.cx.length(len), Z.cx.distance(dist))

def construct(+len: U32, +dist: U32) -> Encode.Token:
  Z.es.copy(len, dist, Z.Cx{0, 3, 0}, Z.Cx{0, 1, 0})

def loop(~f: @+len:U32 -> @+dist:U32 -> Encode.Token, fuel: Nat, +i: U32, acc: U32) -> U32:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      loop(~f, p, (i + 1 : U32), (acc + checksum(f((3 + i % 256 : U32), (1 + i % 32768 : U32))) : U32))

def report(+name: String, t0: Time.Duration, value: U32) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(value))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    report("mapped", t0, loop(~mapped, 1048576n, 0, 0))
    t1 : Time.Duration <- Time.mono()
    report("construct", t1, loop(~construct, 1048576n, 0, 0))
    t2 : Time.Duration <- Time.mono()
    report("legacy", t2, loop(~legacy, 1048576n, 0, 0))
