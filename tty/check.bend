import Base
import ./tty.bend as Tty

def expect(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def flag(b: Bool) -> String:
  Bool.pick(String, b, "yes", "no")
def dimensions(m: Maybe<&1, U32 & U32>) -> String:
  match m:
    case None{}:
      "unavailable"
    case Some{(cols, rows)}:
      U32.show(cols) ++ "x" ++ U32.show(rows)

def main() -> IO(Unit):
  do IO<Unit>:
    expect("wide", U32.is_eq(Tty.width("A界"), 3))
    expect("combining", U32.is_eq(Tty.width("e\u{301}"), 1))
    expect("padding", String.eq(Tty.pad_right("界", 4), "界  "))
    expect("explicit style", String.eq(Tty.style(True{}, 31, "red"), "\u{1B}[31mred\u{1B}[0m"))
    tty : Bool <- Tty.stdout_tty()
    size : Maybe<&1, U32 & U32> <- Tty.size()
    color : Bool <- Tty.color_enabled()
    automatic : String <- Tty.auto_style(31, "red")
    IO.print("terminal=" ++ flag(tty) ++ " size=" ++ dimensions(size) ++ " color=" ++ flag(color))
    IO.print("automatic=" ++ automatic)
