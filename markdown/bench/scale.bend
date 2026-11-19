# Paragraph scaling benchmark: to_html time on one paragraph of N lines (see README.md).
import Base
import ../../time/time.bend as Time
import ../markdown.bend as M

def para(n: Nat, +l: String) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      l ++ para(p, l)

def time(+name: String, +l: String, +n: Nat) -> IO(Unit):
  do IO<Unit>:
    +d : String = para(n, l)
    t0 : Time.Duration <- Time.mono()
    len : Nat = String.length(M.to_html(d))
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Nat.show(n) ++ "\t" ++ Nat.show(len) ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def sizes(+name: String, +l: String) -> IO(Unit):
  do IO<Unit>:
    time(name, l, 100n)
    time(name, l, 200n)
    time(name, l, 400n)
    time(name, l, 800n)
    time(name, l, 1600n)

def main() -> IO(Unit):
  do IO<Unit>:
    +plain : String = "Some *emphasis*, **strong**, `code <tag>`, "
    +amp : String = "and &amp; text.\n"
    sizes("links", plain ++ "a [link](https://example.com/?a=1 \"title\"), " ++ amp)
    sizes("plain", plain ++ amp)
    sizes("html", "Some <b>bold</b> text here.\n")
