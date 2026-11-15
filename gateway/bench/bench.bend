# Gateway benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import bend-kit-authz@0.1.0.0/authz.bend as Az
import bend-kit-cache@0.3.1.0/cache.bend as C
import ../gateway.bend as G

def keys(n: Nat, +i: U32) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      ("k" ++ U32.show(i)) <> keys(p, (i + 1 : U32))

def readers() -> Az.Policy:
  Az.DenyOverrides{Az.Permit{Az.AllOf{Az.Action{"GET"}, Az.Role{"reader"}}}, Az.Forbid{Az.Role{"suspended"}}}

def alice(+k: String) -> Az.Request:
  Az.Request{Some{"alice"}, Some{["reader"]}, None{}, "GET", k}

def gate.of(f: G.Finish) -> G.Gate:
  match f:
    case G.Settled{g}:
      g
    case G.Unheld{g}:
      g

# Every first read misses: the fetch answers the key itself, and the finish stores it.
def filled(b: G.Begin, +k: String) -> G.Gate:
  match b:
    case G.Fetch{g, p}:
      gate.of(G.finish(g, p, G.Fetched{C.Found{0n, k}}))
    case G.Fresh{g, e}:
      g
    case G.Busy{g}:
      g
    case G.Denied{g}:
      g

def fill(ks: List<&2, String>, +pol: Az.Policy, g: G.Gate) -> G.Gate:
  match ks:
    case Nil{}:
      g
    case Con{+k, t}:
      fill(t, pol, filled(G.begin(pol, alice(k), g, k, 0n), k))

def served(b: G.Begin, acc: U32) -> G.Gate & U32:
  match b:
    case G.Fresh{g, C.Hit{v, x, t}}:
      (g, (acc + U32.from_nat(String.length(x)) : U32))
    case G.Fresh{g, C.Miss{t}}:
      (g, acc)
    case G.Fetch{g, p}:
      (g, acc)
    case G.Busy{g}:
      (g, acc)
    case G.Denied{g}:
      (g, acc)

def reads.key(n: Nat, +pol: Az.Policy, +k: String, r: G.Gate & U32) -> G.Gate & U32:
  match n:
    case 0n:
      r
    case 1n+p:
      (g, acc) = r
      reads.key(p, pol, k, served(G.begin(pol, alice(k), g, k, 0n), acc))

# Reads every key 8 times at clock 0. Each read is one guarded request: authorize, admit, read, release.
def reads(ks: List<&2, String>, +pol: Az.Policy, r: G.Gate & U32) -> G.Gate & U32:
  match ks:
    case Nil{}:
      r
    case Con{+k, t}:
      reads(t, pol, reads.key(8n, pol, k, r))

def rounds(n: Nat, +ks: List<&2, String>, +pol: Az.Policy, r: G.Gate & U32) -> U32:
  match n:
    case 0n:
      (g, acc) = r
      acc
    case 1n+p:
      rounds(p, ks, pol, reads(ks, pol, r))

def lg(args: List<&1, String>) -> Nat:
  match args:
    case program <> n <> Nil{}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(n), 10))
    case _:
      10n

# The rounds come from argv, so the work cannot be computed before the clock starts.
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +n : Nat = Nat.pow(2n, lg(args))
    +ks : List<&2, String> = keys(64n, 0)
    +pol : Az.Policy = readers()
    t0 : Time.Duration <- Time.mono()
    +v : U32 = rounds(n, ks, pol, (fill(ks, pol, G.new(1n, 4n, C.Policy{1000000n, 1000000n})), 0))
    IO.print("chk\tgateway\t" ++ U32.show(v))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tgateway\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
