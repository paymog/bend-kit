import Base
import ./omap.bend as O
import ./hmap.bend as M
import ./vec.bend as V
import ./hmap_check.bend as HCheck

def scmp.fin(r: (String & String) & Cmp) -> Cmp:
  (ab, c) = r
  c

def scmp(a: String, b: String) -> Cmp:
  scmp.fin(String.cmp(a, b))

def quote(s: String) -> String:
  "\"" ++ s ++ "\""

def identity(k: U32) -> U32:
  k

def main() -> IO(Unit):
  +m = O.OMap.put(~String, ~U32, ~scmp,
    O.OMap.put(~String, ~U32, ~scmp, O.OMap.new(String, U32), "b", 2), "a", 1)
  do IO<Unit>:
    IO.print(List.show(~&2, ~String, ~quote, O.OMap.keys(String, U32, m)))
    IO.print(Maybe.show(~&2, ~U32, ~U32.show, O.OMap.get(~String, ~U32, ~scmp, m, "b")))
    IO.print(Maybe.show(~&2, ~U32, ~U32.show,
      M.HMap.get(~U32, ~U32, ~identity, ~U32.is_eq,
        M.HMap.put(~U32, ~U32, ~identity, ~U32.is_eq,
          M.HMap.put(~U32, ~U32, ~identity, ~U32.is_eq, M.HMap.new(U32, U32), 0, 10),
          2147483648, 20), 0)))
    IO.print(List.show(~&2, ~U32, ~U32.show, V.Vec.to_list(~U32, V.Vec.push(~U32, V.Vec.from_list(~U32, [1, 2]), 3))))
    HCheck.run()
