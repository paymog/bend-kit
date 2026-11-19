import Base
import ./text.bend as T

def show(es: List<&2, T.Edit<Char>>) -> String:
  match es:
    case Nil{}:
      ""
    case Con{T.Same{o, n}, t}:
      SCon{n, show(t)}
    case Con{T.Del{o}, t}:
      "-" ++ SCon{o, show(t)}
    case Con{T.Ins{n}, t}:
      "+" ++ SCon{n, show(t)}

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(show(T.diff_chars("ABCABBA", "CBABAC")))
    IO.print(T.unified("old.txt", "new.txt", T.diff_lines("a\nb\nc\nd\n", "a\nB\nc\nd\ne\n"), 3))
    IO.print("distance kitten sitting: " ++ U32.show(T.distance("kitten", "sitting")))
    IO.print(String.join(T.wrap("The quick brown fox jumps over the lazy dog. 日本語の文章も折り返す。", 16), "\n"))
