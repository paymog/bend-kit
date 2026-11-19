# Paragraph scaling benchmark: render time on one paragraph of N lines (see README.md).
import Base
import ../../time/time.bend as Time
import ../markdown.bend as M

def para(n: Nat, +l: String) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      l ++ para(p, l)

def time(+gfm: Bool, +name: String, +l: String, +n: Nat) -> IO(Unit):
  do IO<Unit>:
    +d : String = para(n, l) ++ "\n[foo]: /url\n"
    t0 : Time.Duration <- Time.mono()
    len : Nat = String.length(M.to_html_with(M.Opts{False{}, gfm}, d))
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Nat.show(n) ++ "\t" ++ Nat.show(len) ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def sizes(+gfm: Bool, +name: String, +l: String) -> IO(Unit):
  do IO<Unit>:
    time(gfm, name, l, 100n)
    time(gfm, name, l, 200n)
    time(gfm, name, l, 400n)
    time(gfm, name, l, 800n)
    time(gfm, name, l, 1600n)

def main() -> IO(Unit):
  do IO<Unit>:
    +plain : String = "Some *emphasis*, **strong**, `code <tag>`, "
    +amp : String = "and &amp; text.\n"
    sizes(False{}, "links", plain ++ "a [link](https://example.com/?a=1 \"title\"), " ++ amp)
    sizes(False{}, "plain", plain ++ amp)
    sizes(False{}, "html", "Some <b>bold</b> text here.\n")
    sizes(True{}, "gfm", "See https://example.com/a for more.\n")
    sizes(False{}, "ref", "See [foo] here.\n")
    sizes(False{}, "noref", "See [plain] here.\n")
    sizes(False{}, "stray", "See plain] here.\n")
    sizes(False{}, "closers", "Some a* b_ text here.\n")
    sizes(False{}, "comment", "a <!-- b\n")
    sizes(False{}, "decl", "a <!x b\n")
    sizes(False{}, "codelabel", "See [a `]` b] here.\n")
