# CommonMark render benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../markdown.bend as M

def N() -> Nat:
  100n

def R() -> Nat:
  10n

def section(+i: U32) -> String:
  +n = U32.show(i)
  "## Section " ++ n ++ "\n\nSome *emphasis*, **strong**, `code <tag>`, and a [link](https://example.com/" ++ n ++ "?a=1&b=2 \"title " ++ n ++ "\").\nText with &amp; entities &lt; and <span class=\"x\">inline html</span>.\n\n- item one\n- item two with `code`\n  - nested *item* " ++ n ++ "\n\n1. first\n2. second\n\n> A quote with **bold** text\n> across lines.\n\n```python\ndef f(x):\n    return x < " ++ n ++ "\n```\n\n---\n\n"

def doc(n: Nat, +i: U32) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      section(i) ++ doc(p, (i + 1 : U32))

# FNV-1a over the octets of s; the output is ASCII.
def fnv(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      fnv(t, (U32.xor(h, c) * 16777619 : U32))

def run(r: Nat, +d: String, acc: Nat) -> Nat:
  match r:
    case 0n:
      acc
    case 1n+p:
      run(p, d, Nat.add(acc, String.length(M.to_html(d))))

def main() -> IO(Unit):
  do IO<Unit>:
    +d : String = doc(N(), 0)
    IO.print("chk\trender\t" ++ U32.show(fnv(M.to_html(d), 2166136261)))
    t0 : Time.Duration <- Time.mono()
    len : Nat = run(R(), d, 0n)
    t1 : Time.Duration <- Time.mono()
    IO.print("len\trender\t" ++ Nat.show(len))
    IO.print("ms\trender\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
