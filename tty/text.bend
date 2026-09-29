# Pure terminal text: ANSI SGR styling and Unicode 17 display width.
import Base
import 0x6c784a08486e2e02415e89c5249e9e8a/unicode.bend as Unicode
import ./width.bend as W

# Wrap text in one numeric SGR code and a reset when enabled; otherwise return it unchanged.
def style(enabled: Bool, code: U32, text: String) -> String:
  match enabled:
    case True{}:
      String.concat(["\u{1B}[", U32.show(code), "m", text, "\u{1B}[0m"])
    case False{}:
      text

def vs16(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      U32.is_eq(c, 65039) || vs16(t)

# A grapheme cluster takes its first code point's columns (W.w); VS16 makes a narrow base an emoji, 2 wide.
def cluster(g: String) -> U32:
  match g:
    case SNil{}:
      0
    case SCon{Chr{+c}, t}:
      +w = W.w(c)
      Bool.pick(U32, U32.is_eq(w, 1) && vs16(t), 2, w)

def width.go(gs: List<&2, String>, +acc: U32) -> U32:
  match gs:
    case Nil{}:
      acc
    case Con{g, t}:
      width.go(t, (acc + cluster(g) : U32))

# Display columns: East Asian Wide and Fullwidth clusters are 2, marks and controls 0, Ambiguous 1.
# Escape sequences are not stripped: style()'s output is wider than what the terminal shows.
def width(text: String) -> U32:
  width.go(Unicode.graphemes(text), 0)

# Append spaces until text occupies at least cols display columns.
def pad_right(+text: String, +cols: U32) -> String:
  +w = width(text)
  +n = Bool.pick(U32, U32.is_lt(w, cols), (cols - w : U32), 0)
  String.append(text, String.repeat(" ", U32.to_nat(n)))
