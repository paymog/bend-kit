import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-collections@0.1.6.0/hmap.bend as M
import bend-kit-scheduler@0.4.4.0/queue.bend as Q
import bend-kit-time@0.3.0.1/time.bend as Time
import ../model.bend as R

def penc(x: U32) -> Bytes.Bytes:
  Bytes.set.u32le(Bytes.new(4), 0, x)

def pdec.of(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (b, x) = r
  x

def pdec(b: Bytes.Bytes) -> Maybe<&2, U32>:
  pdec.of(Bytes.get.u32le(b, 0))

def entries(+n: Nat) -> List<&2, M.Entry<Nat, R.Dead<U32>>>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +id = Nat.mul(p, Nat.mul(65536n, 65536n))
      M.Entry{id, R.Dead{Q.Ticket{id, 0n, 0}, R.WhyFailed{}, 0n}} <> entries(p)

def spread(xs: List<&2, M.Entry<Nat, R.Dead<U32>>>, ds: R.Graves(U32), +id: Nat) -> R.Graves(U32):
  match xs:
    case Nil{}:
      ds
    case Con{M.Entry{k, v}, rest}:
      spread(rest, M.HMap.put(~Nat, ~R.Dead<U32>, ~R.dead.hash, ~Nat.is_eq, ds, id, v), 1n+id)

def snapshot.of(s: R.State<U32>, ds: R.Graves(U32)) -> Bytes.Bytes:
  R.State{q, ts, old, bs} = s
  R.encode.snap(~U32, ~penc, R.State{q, ts, ds, bs})

def snapshot(ds: R.Graves(U32)) -> Bytes.Bytes:
  snapshot.of(R.new(U32), ds)

def count(r: Maybe<&2, R.Rec<U32>>) -> Nat:
  match r:
    case Some{R.Snap{s}}:
      M.HMap.size(Nat, R.Dead<U32>, R.dead(U32, s))
    case _:
      0n

def report(+name: String, n: Nat, start: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    finish : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Nat.show(n) ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(finish, start)))

def timed(collision: Bytes.Bytes, separate: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    report("after-colliding", count(R.decode.rec(~U32, ~pdec, collision)), t0)
    t2 : Time.Duration <- Time.mono()
    report("after-separate", count(R.decode.rec(~U32, ~pdec, separate)), t2)

def run(+xs: List<&2, M.Entry<Nat, R.Dead<U32>>>) -> IO(Unit):
  timed(snapshot(M.HLeaf{0, xs}), snapshot(spread(xs, M.HNil{}, 0n)))

def main() -> IO(Unit):
  run(entries(10000n))
