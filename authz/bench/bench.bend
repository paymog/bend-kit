# Authorization benchmark: the Bend side (see README.md).
import Base
import ../authz.bend as Az
import ../../time/time.bend as Time

def action(n: U32) -> String:
  match n:
    case 0:
      "GET"
    case 1:
      "DELETE"
    case _:
      "PUT"

def role.suspended(b: Bool) -> String:
  match b:
    case True{}:
      "suspended"
    case False{}:
      "editor"

def role(b: Bool, i: U32) -> String:
  match b:
    case True{}:
      "admin"
    case False{}:
      role.suspended(U32.is_eq((i % 13 : U32), 0))

def request(+i: U32) -> Az.Request:
  Az.Request{Some{"u" ++ U32.show((i % 7 : U32))}, Some{[role(U32.is_eq((i % 11 : U32), 0), i)]}, Some{"u" ++ U32.show((i % 5 : U32))}, action((i % 3 : U32)), "doc"}

def requests(n: Nat, +i: U32) -> List<&2, Az.Request>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      request(i) <> requests(p, (i + 1 : U32))

def policy() -> Az.Policy:
  Az.DenyOverrides{Az.DenyOverrides{Az.Permit{Az.AllOf{Az.Action{"DELETE"}, Az.Owner{}}}, Az.Permit{Az.Role{"admin"}}}, Az.Forbid{Az.Role{"suspended"}}}

def count(b: Bool, +acc: U32) -> U32:
  match b:
    case True{}:
      (acc + 1 : U32)
    case False{}:
      acc

def evaluate(xs: List<&2, Az.Request>, +p: Az.Policy, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case req <> rest:
      evaluate(rest, p, count(Az.granted(p, req), acc))

def rounds(n: Nat, +xs: List<&2, Az.Request>, +p: Az.Policy, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+rest:
      rounds(rest, xs, p, evaluate(xs, p, acc))

def lg(args: List<&1, String>) -> Nat:
  match args:
    case program <> n <> Nil{}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(n), 8))
    case _:
      8n

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    n : Nat = Nat.pow(2n, lg(args))
    xs : List<&2, Az.Request> = requests(64n, 0)
    p : Az.Policy = policy()
    t0 : Time.Duration <- Time.mono()
    +v : U32 = rounds(n, xs, p, 0)
    t1 : Time.Duration <- Time.mono()
    IO.print("chk\tauthz\t" ++ U32.show(v))
    IO.print("ms\tauthz\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
