import Base
import ../../time/time.bend as Time
import ../template.bend as T
import bend-kit-bytes@0.3.3.3/bytes.bend as B
import ../../encoding/encoding.bend as Encoding

def nodes(r: Result<&2, &2, String, List<&2, T.Node>>) -> List<&2, T.Node>:
  match r:
    case Fail{m}:
      Nil{}
    case Done{ns}:
      ns

def lines(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      "猫😀 {{v}}\n\n{{{v}}}\n" ++ lines(p)

def items(n: Nat) -> List<&2, T.Value>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      T.VMap{Map.set(&2, T.Value, Map.new(&2, T.Value), "x", T.VBool{True{}})} <> items(p)

def ctx(n: Nat) -> Map<&2, T.Value>:
  Map.set(&2, T.Value, Map.set(&2, T.Value, Map.new(&2, T.Value), "v", T.VStr{"é猫😀 & <"}), "items", T.VList{items(n)})

def parts(p: String) -> Map<&2, List<&2, T.Node>>:
  Map.set(&2, List<&2, T.Node>, Map.set(&2, List<&2, T.Node>, Map.new(&2, List<&2, T.Node>), "p", nodes(T.parse(p))), "q", nodes(T.parse("😀\n\n{{{v}}}\n")))

def packed(ns: List<&2, T.Node>, c: Map<&2, T.Value>, ps: Map<&2, List<&2, T.Node>>) -> B.Bytes:
  T.render_bytes_with(ns, c, ps)

def text(ns: List<&2, T.Node>, c: Map<&2, T.Value>, ps: Map<&2, List<&2, T.Node>>) -> B.Bytes:
  Encoding.utf8.encode(T.render_with(ns, c, ps))

def length(b: B.Bytes) -> Nat:
  B.Bytes{n, buf} = b
  U32.to_nat(n)

def fnv(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      fnv(t, (U32.xor(h, c) * 16777619 : U32))

def run(~render: List<&2, T.Node> -> Map<&2, T.Value> -> Map<&2, List<&2, T.Node>> -> B.Bytes, r: Nat, +ns: List<&2, T.Node>, +c: Map<&2, T.Value>, +ps: Map<&2, List<&2, T.Node>>, acc: Nat) -> Nat:
  match r:
    case 0n:
      acc
    case 1n+p:
      run(~render, p, ns, c, ps, Nat.add(acc, length(render(ns, c, ps))))

def report(~render: List<&2, T.Node> -> Map<&2, T.Value> -> Map<&2, List<&2, T.Node>> -> B.Bytes, +label: String, n: Nat, p: String) -> IO(Unit):
  do IO<Unit>:
    +ns : List<&2, T.Node> = nodes(T.parse("{{#items}}\n  {{>p}}\n{{/items}}"))
    +c : Map<&2, T.Value> = ctx(n)
    +ps : Map<&2, List<&2, T.Node>> = parts(p)
    IO.print("chk\t" ++ label ++ "\t" ++ U32.show(fnv(B.to_string(render(ns, c, ps)), 2166136261)))
    t0 : Time.Duration <- Time.mono()
    total : Nat = run(~render, 100n, ns, c, ps, 0n)
    t1 : Time.Duration <- Time.mono()
    IO.print("len\t" ++ label ++ "\t" ++ Nat.show(total))
    IO.print("ms\t" ++ label ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def main() -> IO(Unit):
  do IO<Unit>:
    report(~packed, "large-packed", 16n, lines(128n))
    report(~text, "large-text", 16n, lines(128n))
    report(~packed, "nested-packed", 200n, "猫\n{{v}}\n\n  {{>q}}\n")
    report(~text, "nested-text", 200n, "猫\n{{v}}\n\n  {{>q}}\n")
