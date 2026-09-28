import Base
import ./redis.bend as R
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def b(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def dec.end(ok: Bool, v: R.Val) -> Maybe<&1, R.Val>:
  match ok:
    case True{}:
      Some{v}
    case False{}:
      None{}

def dec.of(r: Bytes.Bytes & R.Step) -> Maybe<&1, R.Val>:
  (buf, s) = r
  Bytes.Bytes{+len, a} = buf
  match s:
    case R.Reply{v, +i}:
      dec.end(U32.is_eq(i, len), v)
    case R.More{}:
      None{}
    case R.Bad{}:
      None{}

# One whole reply that fills the bytes.
def dec(+s: String) -> Maybe<&1, R.Val>:
  dec.of(R.decode(b(s), 0))

def dec.bytes(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, R.Val>:
  match m:
    case Some{x}:
      dec.of(R.decode(x, 0))
    case None{}:
      None{}

def rt(v: R.Val) -> Maybe<&1, R.Val>:
  dec.bytes(R.encode(v))

def hexed(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case Some{x}:
      Some{Bytes.to_string(x)}
    case None{}:
      None{}

def enc(v: R.Val) -> Maybe<&2, String>:
  hexed(R.encode(v))

def step.of(r: Bytes.Bytes & R.Step) -> R.Step:
  (x, s) = r
  s

def step(+s: String, +i: U32) -> R.Step:
  step.of(R.decode(b(s), i))

def int(+hi: U32, +lo: U32) -> R.Val:
  R.Int{hi, lo}

# ---- splits and prefixes

def text(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case Some{x}:
      Bytes.to_string(x)
    case None{}:
      "none"

def split.got(+want: String, r: R.Reader & R.Next) -> Bool:
  (rd, n) = r
  match n:
    case R.Got{v}:
      String.eq(text(R.encode(v)), want)
    case R.Want{}:
      False{}
    case R.Broken{}:
      False{}

# At k = len the first piece already holds the whole reply.
def split.fed(rest: Bytes.Bytes, +want: String, r: R.Reader & R.Next) -> Bool:
  (rd, n) = r
  match n:
    case R.Got{v}:
      String.eq(text(R.encode(v)), want)
    case R.Want{}:
      split.got(want, R.next(R.feed(rd, rest)))
    case R.Broken{}:
      False{}

def split.cut(+k: U32, +want: String, r: Bytes.Bytes & Bytes.Bytes) -> Bool:
  (whole, first) = r
  split.fed(Bytes.snd(Bytes.slice(whole, k, 4294967295)), want, R.next(R.feed(R.reader(), first)))

# The first k bytes, a decode attempt, then the rest: the reply comes out as it does whole.
def split.at(+s: String, +want: String, +k: U32) -> Bool:
  split.cut(k, want, Bytes.slice(b(s), 0, k))

def splits.go(n: Nat, +s: String, +want: String, +k: U32) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Bool.and(split.at(s, want, k), splits.go(p, s, want, (k + 1 : U32)))

def reenc(m: Maybe<&1, R.Val>) -> Maybe<&1, Bytes.Bytes>:
  match m:
    case Some{v}:
      R.encode(v)
    case None{}:
      None{}

# Every split point, 0 through len, against the reply decoded from the whole input.
def splits(+s: String) -> Bool:
  splits.go(U32.to_nat((Bytes.count(s, 0) + 1 : U32)), s, text(reenc(dec(s))), 0)

def more(r: Bytes.Bytes & R.Step) -> Bool:
  (x, s) = r
  match s:
    case R.More{}:
      True{}
    case R.Reply{v, i}:
      False{}
    case R.Bad{}:
      False{}

def prefix.at(r: Bytes.Bytes & Bytes.Bytes) -> Bool:
  (whole, first) = r
  more(R.decode(first, 0))

def prefixes.go(n: Nat, +s: String, +k: U32) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Bool.and(prefix.at(Bytes.slice(b(s), 0, k)), prefixes.go(p, s, (k + 1 : U32)))

# Every proper prefix, empty included.
def prefixes(+s: String) -> Bool:
  prefixes.go(U32.to_nat(Bytes.count(s, 0)), s, 0)

# ---- fixtures

def nested() -> String:
  "|1\r\n+ttl\r\n:3600\r\n%2\r\n$1\r\nk\r\n*4\r\n:-7\r\n_\r\n#t\r\n$4\r\nv\r\n1\r\n+s\r\n~2\r\n,1.5\r\n=8\r\ntxt:a\r\nb\r\n"

def resp2() -> String:
  "*3\r\n$3\r\nGET\r\n$-1\r\n*-1\r\n"

# Attribute, map, a bulk string holding CRLF, and a nested array, in 38 bytes.
def small() -> String:
  "|1\r\n+a\r\n:1\r\n%1\r\n$4\r\nv\r\n1\r\n*2\r\n:-7\r\n_\r\n"

# ---- decode(encode(v)) == v, one fixture per RESP3 type

law rt_simple:
  {rt(R.Simple{b("OK")}) == Some{R.Simple{b("OK")}} : Maybe<&1, R.Val>}

law rt_error:
  {rt(R.Error{b("ERR wrong type")}) == Some{R.Error{b("ERR wrong type")}} : Maybe<&1, R.Val>}

law rt_int_zero:
  {rt(int(0, 0)) == Some{int(0, 0)} : Maybe<&1, R.Val>}

law rt_int_minus_one:
  {rt(int(4294967295, 4294967295)) == Some{int(4294967295, 4294967295)} : Maybe<&1, R.Val>}

law rt_int_max:
  {rt(int(2147483647, 4294967295)) == Some{int(2147483647, 4294967295)} : Maybe<&1, R.Val>}

law rt_int_min:
  {rt(int(2147483648, 0)) == Some{int(2147483648, 0)} : Maybe<&1, R.Val>}

law rt_bulk:
  {rt(R.Bulk{b("a\r\nb")}) == Some{R.Bulk{b("a\r\nb")}} : Maybe<&1, R.Val>}

law rt_bulk_empty:
  {rt(R.Bulk{b("")}) == Some{R.Bulk{b("")}} : Maybe<&1, R.Val>}

law rt_array:
  {rt(R.Arr{[int(0, 1), R.Arr{[R.Bulk{b("x")}, R.Null{}]}, R.Arr{[]}]}) == Some{R.Arr{[int(0, 1), R.Arr{[R.Bulk{b("x")}, R.Null{}]}, R.Arr{[]}]}} : Maybe<&1, R.Val>}

law rt_null:
  {rt(R.Null{}) == Some{R.Null{}} : Maybe<&1, R.Val>}

law rt_true:
  {rt(R.Boolean{True{}}) == Some{R.Boolean{True{}}} : Maybe<&1, R.Val>}

law rt_false:
  {rt(R.Boolean{False{}}) == Some{R.Boolean{False{}}} : Maybe<&1, R.Val>}

law rt_double:
  {rt(R.Double{b("-1.5e-3")}) == Some{R.Double{b("-1.5e-3")}} : Maybe<&1, R.Val>}

law rt_bignum:
  {rt(R.BigNum{b("3492890328409238509324850943850943825024385")}) == Some{R.BigNum{b("3492890328409238509324850943850943825024385")}} : Maybe<&1, R.Val>}

law rt_bulk_error:
  {rt(R.BulkError{b("SYNTAX invalid\r\nsyntax")}) == Some{R.BulkError{b("SYNTAX invalid\r\nsyntax")}} : Maybe<&1, R.Val>}

law rt_verbatim:
  {rt(R.Verbatim{b("txt"), b("Some string")}) == Some{R.Verbatim{b("txt"), b("Some string")}} : Maybe<&1, R.Val>}

law rt_dict:
  {rt(R.Dict{[R.Simple{b("a")}, int(0, 1), R.Bulk{b("b")}, R.Dict{[R.Simple{b("c")}, R.Arr{[R.Null{}]}]}]}) == Some{R.Dict{[R.Simple{b("a")}, int(0, 1), R.Bulk{b("b")}, R.Dict{[R.Simple{b("c")}, R.Arr{[R.Null{}]}]}]}} : Maybe<&1, R.Val>}

law rt_dict_empty:
  {rt(R.Dict{[]}) == Some{R.Dict{[]}} : Maybe<&1, R.Val>}

law rt_set:
  {rt(R.Set{[R.Bulk{b("x")}, int(0, 2)]}) == Some{R.Set{[R.Bulk{b("x")}, int(0, 2)]}} : Maybe<&1, R.Val>}

law rt_attr:
  {rt(R.Attr{[R.Simple{b("key-popularity")}, R.Dict{[R.Bulk{b("a")}, R.Double{b("0.1923")}]}, R.Arr{[int(0, 2039123), int(0, 9543892)]}]}) == Some{R.Attr{[R.Simple{b("key-popularity")}, R.Dict{[R.Bulk{b("a")}, R.Double{b("0.1923")}]}, R.Arr{[int(0, 2039123), int(0, 9543892)]}]}} : Maybe<&1, R.Val>}

law rt_push:
  {rt(R.Push{[R.Bulk{b("message")}, R.Bulk{b("chan")}, R.Bulk{b("hi")}]}) == Some{R.Push{[R.Bulk{b("message")}, R.Bulk{b("chan")}, R.Bulk{b("hi")}]}} : Maybe<&1, R.Val>}

# ---- the wire form

law enc_nested:
  {enc(R.Attr{[R.Simple{b("ttl")}, int(0, 3600), R.Dict{[R.Bulk{b("k")}, R.Arr{[int(4294967295, 4294967289), R.Null{}, R.Boolean{True{}}, R.Bulk{b("v\r\n1")}]}, R.Simple{b("s")}, R.Set{[R.Double{b("1.5")}, R.Verbatim{b("txt"), b("a\r\nb")}]}]}]}) == Some{nested()} : Maybe<&2, String>}

law enc_command:
  {Bytes.to_string(R.encode.command(R.args(["SET", "k", "v"]))) == "*3\r\n$3\r\nSET\r\n$1\r\nk\r\n$1\r\nv\r\n" : String}

law enc_dict_odd:
  {enc(R.Dict{[R.Null{}]}) == None{} : Maybe<&2, String>}

law enc_attr_even:
  {enc(R.Attr{[R.Null{}, R.Null{}]}) == None{} : Maybe<&2, String>}

law enc_line_crlf:
  {enc(R.Simple{b("a\r\nb")}) == None{} : Maybe<&2, String>}

law enc_verbatim_format:
  {enc(R.Verbatim{b("md"), b("x")}) == None{} : Maybe<&2, String>}

# ---- RESP2 replies and malformed input

law dec_resp2_nulls:
  {dec(resp2()) == Some{R.Arr{[R.Bulk{b("GET")}, R.Null{}, R.Null{}]}} : Maybe<&1, R.Val>}

law dec_int_overflow:
  {dec(":9223372036854775808\r\n") == None{} : Maybe<&1, R.Val>}

law dec_int_min:
  {dec(":-9223372036854775808\r\n") == Some{int(2147483648, 0)} : Maybe<&1, R.Val>}

law dec_next:
  {step("+a\r\n:1\r\n", 4) == R.Reply{int(0, 1), 8} : R.Step}

law dec_bad_type:
  {step("?\r\n", 0) == R.Bad{} : R.Step}

law dec_bad_length:
  {step("$3\r\nabcd\r\n", 0) == R.Bad{} : R.Step}

law dec_bad_digit:
  {step("*1x\r\n", 0) == R.Bad{} : R.Step}

# ---- a reply split at any point decodes as it does whole

law split_small:
  {splits(small()) == True{} : Bool}

law split_resp2:
  {splits(resp2()) == True{} : Bool}

# ---- a prefix of a valid reply asks for more, never Bad

law prefix_small:
  {prefixes(small()) == True{} : Bool}

law prefix_resp2:
  {prefixes(resp2()) == True{} : Bool}
