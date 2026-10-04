import Base
import ./json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import 0xcfc8be7b076f41f95c8e118383892d55/encoding.bend as Enc

def show(m: Maybe<&1, Json.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{v}:
      IO.print(Enc.utf8.decode(Json.encode.bytes(v)))

def pb(+s: String) -> Maybe<&1, Json.Val>:
  Json.parse.bytes(Bytes.from_string(s))

def strict(+s: String, cap: U32) -> Maybe<&1, Json.Val>:
  Json.parse.strict.bytes(Bytes.from_string(s), cap)

def encoded(m: Maybe<&1, Json.Val>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      Some{Bytes.to_string(Json.encode.bytes(v))}

def same(m: Maybe<&2, String>, want: Maybe<&2, String>) -> Bool:
  match m want:
    case None{} None{}:
      True{}
    case Some{a} Some{b}:
      String.eq(a, b)
    case _ _:
      False{}

def checked(ok: Bool, +label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ label)

def expect(label: String, s: String, cap: U32, want: Maybe<&2, String>) -> IO(Unit):
  checked(same(encoded(strict(s, cap)), want), label)

def nested(n: Nat, +open: String, +close: String, s: String) -> String:
  match n:
    case 0n:
      s
    case 1n+k:
      nested(k, open, close, open ++ s ++ close)

def main() -> IO(Unit):
  do IO<Unit>:
    show(pb("null"))
    show(pb(" true "))
    show(pb("[]"))
    show(pb("{}"))
    show(pb("-12.5e+3"))
    show(pb("\"hi\\n\\u00e9\""))
    show(pb("null x"))
    show(pb("{\"b\":[1,{\"c\":null}],\"a\":true}"))
    show(pb("[1,]"))
    show(pb("{\"b\":[1,{\"c\":null}],\"a\":\"h\u{c3}\u{a9}\\u00e9\"}"))
    show(pb("\"\u{c0}\u{af}\""))
    expect("lone-high", "\"\\uD800\"", 64, None{})
    expect("lone-low", "\"\\uDC00\"", 64, None{})
    expect("high-before-text", "\"\\uD800x\"", 64, None{})
    expect("high-before-escape", "\"\\uD800\\n\"", 64, None{})
    expect("high-high", "\"\\uD800\\uD800\"", 64, None{})
    expect("low-high", "\"\\uDC00\\uD800\"", 64, None{})
    expect("surrogate-key", "{\"\\uD800\":0}", 64, None{})
    expect("bad-pair-hex", "\"\\uD800\\uZZZZ\"", 64, None{})
    expect("paired-surrogates", "\"\\uD83D\\uDE00\"", 64, Some{"\"\u{f0}\u{9f}\u{98}\u{80}\""})
    expect("paired-key", "{\"\\uD83D\\uDE00\":1}", 64, Some{"{\"\u{f0}\u{9f}\u{98}\u{80}\":1}"})
    expect("depth64", nested(64n, "[", "]", "0"), 64, Some{nested(64n, "[", "]", "0")})
    expect("depth65", nested(65n, "[", "]", "0"), 64, None{})
    expect("empty-depth64", nested(64n, "[", "]", ""), 64, Some{nested(64n, "[", "]", "")})
    expect("empty-depth65", nested(65n, "[", "]", ""), 64, None{})
    expect("object-depth64", nested(64n, "{\"k\":", "}", "0"), 64, Some{nested(64n, "{\"k\":", "}", "0")})
    expect("object-depth65", nested(65n, "{\"k\":", "}", "0"), 64, None{})
    expect("configured65", nested(65n, "[", "]", "0"), 65, Some{nested(65n, "[", "]", "0")})
    expect("zero-scalar", "1e+02", 0, Some{"1e+02"})
    expect("zero-array", "[]", 0, None{})
    expect("zero-object", "{}", 0, None{})
    expect("siblings-reset-depth", "[[0],{},[1]]", 2, Some{"[[0],{},[1]]"})
    expect("mixed-depth", "[{\"k\":[]}]", 2, None{})
    expect("oversized-depth", nested(4096n, "[", "]", "0"), 64, None{})
    expect("empty", "", 64, None{})
    expect("bom", "\u{ef}\u{bb}\u{bf}null", 64, None{})
    expect("invalid-utf8", "\"\u{c0}\u{af}\"", 64, None{})
    expect("raw-surrogate", "\"\u{ed}\u{a0}\u{80}\"", 64, None{})
    expect("truncated-utf8", "\"\u{e2}\u{82}\"", 64, None{})
    expect("exact-numbers", "[-0,1e+02,1E400,9007199254740993,-12.50e-03]", 64, Some{"[-0,1e+02,1E400,9007199254740993,-12.50e-03]"})
    expect("valid-fixture", " { \"a\": [true,false,null,\"x\\n\\u00e9\"] } ", 64, Some{"{\"a\":[true,false,null,\"x\\n\u{c3}\u{a9}\"]}"})
    expect("repeated-keys-preserved", "{\"k\":1,\"k\":2}", 64, Some{"{\"k\":1,\"k\":2}"})
