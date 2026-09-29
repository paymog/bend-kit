# Terminal detection, dimensions, ANSI color and Unicode display-width text. Source: https://github.com/paymog/bend-kit/tree/main/tty
import Base
import ./text.bend as Text

# Standard output is a terminal.
def stdout_tty() -> IO(Bool):
  import "./effs/tty.c"
  import "./effs/tty.js"

# Terminal columns and rows; None when stdout is not a terminal or its size is unavailable.
def size() -> IO(Maybe<&1, U32 & U32>):
  import "./effs/tty.c"
  import "./effs/tty.js"

# Automatic styling is enabled only for a terminal without NO_COLOR.
def color_enabled() -> IO(Bool):
  import "./effs/tty.c"
  import "./effs/tty.js"

# Apply one numeric ANSI SGR code and reset it, or leave the text unchanged.
def style(enabled: Bool, code: U32, text: String) -> String:
  Text.style(enabled, code, text)

def auto_style(code: U32, text: String) -> IO(String):
  do IO<String>:
    enabled : Bool <- color_enabled()
    return style(enabled, code, text)

# Display columns for Unicode text. Control characters are not terminal cursor movements.
def width(text: String) -> U32:
  Text.width(text)

# Append spaces until text occupies at least cols display columns.
def pad_right(text: String, cols: U32) -> String:
  Text.pad_right(text, cols)
