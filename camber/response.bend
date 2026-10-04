# Final application response safety; transport alone owns framing and suppression.
import Base

def token.extra(c: U32) -> Bool:
  match c:
    case 33: True{}
    case 35: True{}
    case 36: True{}
    case 37: True{}
    case 38: True{}
    case 39: True{}
    case 42: True{}
    case 43: True{}
    case 45: True{}
    case 46: True{}
    case 94: True{}
    case 95: True{}
    case 96: True{}
    case 124: True{}
    case 126: True{}
    case _: False{}

def token(char: Char) -> Bool:
  Chr{+c} = char
  (U32.is_ge(c, 97) && U32.is_le(c, 122)) || (U32.is_ge(c, 48) && U32.is_le(c, 57)) || token.extra(c)

def name.tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{c, rest}:
      token(c) && name.tail(rest)

def name(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{c, rest}:
      token(c) && name.tail(rest)

def value(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      (U32.is_eq(c, 9) || (U32.is_ge(c, 32) && U32.is_le(c, 255) && U32.is_ne(c, 127))) && value(rest)

def values(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case item <> rest:
      value(item) && values(rest)

def connection(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case item <> rest:
      String.eq(item, "close") && connection(rest)

def kind(key: String, items: List<&2, String>) -> Bool:
  match key:
    case "content-length": False{}
    case "transfer-encoding": False{}
    case "keep-alive": False{}
    case "upgrade": False{}
    case "te": False{}
    case "trailer": False{}
    case "proxy-connection": False{}
    case "connection": connection(items)
    case _: True{}

def headers(h: Map<&2, List<&2, String>>) -> Bool:
  match h:
    case MTip{}:
      True{}
    case MLeaf{+key, +items}:
      name(key) && kind(key, items) && values(items)
    case MNode{position, lo, hi}:
      headers(lo) && headers(hi)

def valid(+status: U32, h: Map<&2, List<&2, String>>) -> Bool:
  U32.is_ge(status, 200) && U32.is_le(status, 599) && headers(h)
