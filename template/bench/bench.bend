# Mustache render benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../template.bend as T

def N() -> Nat:
  200n

def R() -> Nat:
  100n

def SRC() -> String:
  "<ul>\n{{#items}}\n  <li><a href=\"{{url}}\">{{name}}</a>{{#tags}} [{{.}}]{{/tags}}</li>\n{{/items}}\n</ul>\n"

def put(m: Map<&2, T.Value>, k: String, v: T.Value) -> Map<&2, T.Value>:
  Map.set(&2, T.Value, m, k, v)

def tags(+i: U32) -> T.Value:
  Bool.pick(T.Value, U32.is_eq((i % 2 : U32), 0), T.VList{[T.VStr{"new"}, T.VStr{"<hot>"}]}, T.VList{[]})

def item(+i: U32) -> T.Value:
  +n = U32.show(i)
  m0 = put(Map.new(&2, T.Value), "name", T.VStr{"Item " ++ n ++ " & co"})
  m1 = put(m0, "url", T.VStr{"/items/" ++ n ++ "?a=1&b=\"2\""})
  T.VMap{put(m1, "tags", tags(i))}

def items(n: Nat, +i: U32) -> List<&2, T.Value>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      item(i) <> items(p, (i + 1 : U32))

def ctx() -> Map<&2, T.Value>:
  put(Map.new(&2, T.Value), "items", T.VList{items(N(), 0)})

# FNV-1a over the octets of s.
def fnv(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      fnv(t, (U32.xor(h, c) * 16777619 : U32))

# Sums the output lengths, so every render is used.
def run(r: Nat, +nodes: List<&2, T.Node>, +c: Map<&2, T.Value>, acc: Nat) -> Nat:
  match r:
    case 0n:
      acc
    case 1n+p:
      run(p, nodes, c, Nat.add(acc, String.length(T.render(nodes, c))))

def nodes(r: Result<&2, &2, String, List<&2, T.Node>>) -> List<&2, T.Node>:
  match r:
    case Fail{m}:
      Nil{}
    case Done{ns}:
      ns

def main() -> IO(Unit):
  do IO<Unit>:
    +ns : List<&2, T.Node> = nodes(T.parse(SRC()))
    +c : Map<&2, T.Value> = ctx()
    IO.print("chk\trender\t" ++ U32.show(fnv(T.render(ns, c), 2166136261)))
    t0 : Time.Duration <- Time.mono()
    len : Nat = run(R(), ns, c, 0n)
    t1 : Time.Duration <- Time.mono()
    IO.print("len\trender\t" ++ Nat.show(len))
    IO.print("ms\trender\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
