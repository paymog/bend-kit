import Base
import ../queue.bend as Q
import bend-kit-time@0.3.0.0/time.bend as Time

def fill(n: Nat, s: Q.State<U32>) -> Q.State<U32>:
  match n:
    case 0n:
      s
    case 1n+ +p:
      +i = (1023 - U32.from_nat(p) : U32)
      fill(p, Pair.fst(Q.State<U32>, Nat, Q.enqueue(~U32, U32.to_nat((i * 37 % 64 : U32)), i, s)))

def step(selected: Q.State<U32> & Maybe<&2, Q.Ticket<U32>>, checksum: U32) -> Q.State<U32> & U32:
  (s, ticket) = selected
  match ticket:
    case None{}:
      (s, checksum)
    case Some{Q.Ticket{+id, deadline, payload}}:
      (Pair.fst(Q.State<U32>, Maybe<&2, Q.Ticket<U32>>, Q.complete(U32, id, s)),
        (checksum * 31 + U32.from_nat(id) : U32))

def drain(fuel: Nat, pair: Q.State<U32> & U32) -> U32:
  match fuel:
    case 0n:
      (s, checksum) = pair
      checksum
    case 1n+p:
      (s, checksum) = pair
      drain(p, step(Q.select(~U32, 64n, s), checksum))

def report(+start: Nat, +checksum: U32) -> IO(Unit):
  do IO<Unit>:
    stop : Nat <- Time.mono.us()
    IO.print(Nat.show((stop - start : Nat)) ++ "e-3\t" ++ U32.show(checksum))

def main() -> IO(Unit):
  do IO<Unit>:
    start : Nat <- Time.mono.us()
    report(start, drain(1024n, (fill(1024n, Q.new(U32)), 0)))
