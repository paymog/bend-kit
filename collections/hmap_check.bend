import Base
import ./hmap.bend as H

def hkey(k: U32) -> U32:
  (k .&. 1 : U32)

def same(a: Maybe<&2, U32>, b: Maybe<&2, U32>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      U32.is_eq(x, y)
    case _ _:
      False{}

def ok(label: String, cond: Bool) -> IO(Unit):
  match cond:
    case True{}:
      IO.print("ok " ++ label)
    case False{}:
      IO.die(Unit, 1, "failed " ++ label)

def run() -> IO(Unit):
  +m0 = H.HMap.new(U32, U32)
  +m1 = H.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, m0, 2, 20)
  +m2 = H.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, m1, 4, 40)
  +m3 = H.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, m2, 3, 30)
  +m4 = H.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, m3, 2, 22)
  +m5 = H.HMap.del(~U32, ~U32, ~hkey, ~U32.is_eq, m4, 4)
  +m6 = H.HMap.del(~U32, ~U32, ~hkey, ~U32.is_eq, m5, 2)
  +m7 = H.HMap.del(~U32, ~U32, ~hkey, ~U32.is_eq, m6, 3)
  +absent = H.HMap.del(~U32, ~U32, ~hkey, ~U32.is_eq, m3, 6)
  do IO<Unit>:
    ok("collision insertion size", Nat.is_eq(H.HMap.size(U32, U32, m3), 3n))
    ok("collision replacement size", Nat.is_eq(H.HMap.size(U32, U32, m4), 3n))
    ok("replacement lookup", same(H.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq, m4, 2), Some{22}))
    ok("missing deletion preserves size", Nat.is_eq(H.HMap.size(U32, U32, absent), 3n))
    ok("collision deletion size", Nat.is_eq(H.HMap.size(U32, U32, m5), 2n))
    ok("deleted key absent", same(H.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq, m5, 4), None{}))
    ok("other colliding key intact", same(H.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq, m5, 2), Some{22}))
    ok("other branch intact", same(H.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq, m5, 3), Some{30}))
    ok("last bucket entry deleted", Nat.is_eq(H.HMap.size(U32, U32, m6), 1n))
    ok("final key deleted", Nat.is_eq(H.HMap.size(U32, U32, m7), 0n))

def main() -> IO(Unit):
  run()
