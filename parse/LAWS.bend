import Base
import ./parse.bend as P
import ./json.bend as J
import ../json/json.bend as Json

def cur(s: String, +o: U32, n: Nat) -> P.Cur:
  P.Cur{s, o, n}

def is_a(+c: U32) -> Bool:
  U32.is_eq(c, 97)

def a(c: P.Cur) -> P.Res<U32>:
  P.char(97, c)

def b(c: P.Cur) -> P.Res<U32>:
  P.char(98, c)

def comma(c: P.Cur) -> P.Res<U32>:
  P.char(44, c)

def nothing(c: P.Cur) -> P.Res<Unit>:
  P.pure(Unit, Unit{}, c)

# Primitives
# ----------

law start_len:
  {P.start("ab") == cur("ab", 0, 2n) : P.Cur}

law char_ok:
  {P.char(97, P.start("ab")) == P.Ok{97, cur("b", 1, 1n)} : P.Res<U32>}

law char_err:
  {P.char(98, P.start("ab")) == P.Err{0, "\"b\""} : P.Res<U32>}

law char_eof:
  {P.char(97, P.start("")) == P.Err{0, "\"a\""} : P.Res<U32>}

law satisfy_ok:
  {P.satisfy(~is_a, "a", P.start("ax")) == P.Ok{97, cur("x", 1, 1n)} : P.Res<U32>}

law satisfy_err:
  {P.satisfy(~is_a, "an a", P.start("x")) == P.Err{0, "an a"} : P.Res<U32>}

law lit_ok:
  {P.lit("nu", P.start("null")) == P.Ok{"nu", cur("ll", 2, 2n)} : P.Res<String>}

law lit_err:
  {P.lit("nx", P.start("null")) == P.Err{0, "\"nx\""} : P.Res<String>}

law take_while_run:
  {P.take_while(~is_a, P.start("aab")) == P.Ok{"aa", cur("b", 2, 1n)} : P.Res<String>}

law take_while_all:
  {P.take_while(~is_a, P.start("aa")) == P.Ok{"aa", cur("", 2, 0n)} : P.Res<String>}

law take_while_none:
  {P.take_while(~is_a, P.start("b")) == P.Ok{"", cur("b", 0, 1n)} : P.Res<String>}

law eof_ok:
  {P.eof(P.start("")) == P.Ok{Unit{}, cur("", 0, 0n)} : P.Res<Unit>}

law eof_err:
  {P.eof(P.start("a")) == P.Err{0, "end of input"} : P.Res<Unit>}

# Combinators
# -----------

law pure_ok:
  {P.pure(U32, 7, P.start("a")) == P.Ok{7, cur("a", 0, 1n)} : P.Res<U32>}

law fail_err:
  {P.fail(U32, "x", P.start("a")) == P.Err{0, "x"} : P.Res<U32>}

law map_ok:
  {P.map(~U32, ~U32, ~(x => (x + 1 : U32)), ~a, P.start("a")) == P.Ok{98, cur("", 1, 0n)} : P.Res<U32>}

law map_err:
  {P.map(~U32, ~U32, ~(x => (x + 1 : U32)), ~a, P.start("b")) == P.Err{0, "\"a\""} : P.Res<U32>}

law bind_ok:
  {P.bind(~U32, ~U32, ~a, ~(x => c => P.char((x + 1 : U32), c)), P.start("ab")) == P.Ok{98, cur("", 2, 0n)} : P.Res<U32>}

law bind_err:
  {P.bind(~U32, ~U32, ~a, ~(x => c => P.char((x + 1 : U32), c)), P.start("aa")) == P.Err{1, "\"b\""} : P.Res<U32>}

law seq_ok:
  {P.seq(~U32, ~U32, ~a, ~b, P.start("ab")) == P.Ok{(97, 98), cur("", 2, 0n)} : P.Res<P.Both(U32, U32)>}

law seq_err_second:
  {P.seq(~U32, ~U32, ~a, ~b, P.start("aa")) == P.Err{1, "\"b\""} : P.Res<P.Both(U32, U32)>}

law left_ok:
  {P.left(~U32, ~U32, ~a, ~b, P.start("ab")) == P.Ok{97, cur("", 2, 0n)} : P.Res<U32>}

law right_ok:
  {P.right(~U32, ~U32, ~a, ~b, P.start("ab")) == P.Ok{98, cur("", 2, 0n)} : P.Res<U32>}

law alt_first:
  {P.alt(~U32, ~a, ~b, P.start("a")) == P.Ok{97, cur("", 1, 0n)} : P.Res<U32>}

law alt_second:
  {P.alt(~U32, ~a, ~b, P.start("b")) == P.Ok{98, cur("", 1, 0n)} : P.Res<U32>}

# Both fail at the same offset: both wants.
law alt_err_join:
  {P.alt(~U32, ~a, ~b, P.start("c")) == P.Err{0, "\"a\" or \"b\""} : P.Res<U32>}

# The branch that got further names the error.
law alt_err_further:
  {P.alt(~U32, ~(c => P.right(~U32, ~U32, ~a, ~a, c)), ~b, P.start("ac")) == P.Err{1, "\"a\""} : P.Res<U32>}

law opt_some:
  {P.opt(~U32, ~a, P.start("a")) == P.Ok{Some{97}, cur("", 1, 0n)} : P.Res<Maybe<&2, U32>>}

law opt_none:
  {P.opt(~U32, ~a, P.start("b")) == P.Ok{None{}, cur("b", 0, 1n)} : P.Res<Maybe<&2, U32>>}

law many_run:
  {P.many(~U32, ~a, P.start("aab")) == P.Ok{[97, 97], cur("b", 2, 1n)} : P.Res<List<&2, U32>>}

law many_zero:
  {P.many(~U32, ~a, P.start("b")) == P.Ok{Nil{}, cur("b", 0, 1n)} : P.Res<List<&2, U32>>}

# A parser that takes no input ends the loop.
law many_no_progress:
  {P.many(~Unit, ~nothing, P.start("a")) == P.Ok{Nil{}, cur("a", 0, 1n)} : P.Res<List<&2, Unit>>}

law many1_run:
  {P.many1(~U32, ~a, P.start("aa")) == P.Ok{[97, 97], cur("", 2, 0n)} : P.Res<List<&2, U32>>}

law many1_err:
  {P.many1(~U32, ~a, P.start("b")) == P.Err{0, "\"a\""} : P.Res<List<&2, U32>>}

law text_ok:
  {P.text(~List<&2, U32>, ~(c => P.many(~U32, ~a, c)), P.start("aab")) == P.Ok{"aa", cur("b", 2, 1n)} : P.Res<String>}

law sep_by1_run:
  {P.sep_by1(~U32, ~U32, ~a, ~comma, P.start("a,a")) == P.Ok{[97, 97], cur("", 3, 0n)} : P.Res<List<&2, U32>>}

# A trailing separator is left in the input.
law sep_by1_trailing:
  {P.sep_by1(~U32, ~U32, ~a, ~comma, P.start("a,")) == P.Ok{[97], cur(",", 1, 1n)} : P.Res<List<&2, U32>>}

law sep_by_zero:
  {P.sep_by(~U32, ~U32, ~a, ~comma, P.start("b")) == P.Ok{Nil{}, cur("b", 0, 1n)} : P.Res<List<&2, U32>>}

law run_ok:
  {P.run(~U32, ~a, "a") == P.Ok{97, cur("", 1, 0n)} : P.Res<U32>}

law run_extra:
  {P.run(~U32, ~a, "ab") == P.Err{1, "end of input"} : P.Res<U32>}

# rec: the JSON grammar below nests through it.
law rec_error_offset:
  {J.parse.res("[[1,]]") == P.Err{4, "\"[\" or \"{\" or \"null\" or \"true\" or \"false\" or \"\"\" or \"0\" or digit"} : P.Res<Json.Val>}

law rec_unclosed_offset:
  {J.parse.res("[[1]") == P.Err{4, "\",\" or \"]\""} : P.Res<Json.Val>}

# The JSON laws of json/LAWS.bend, on the grammar in json.bend
# ------------------------------------------------------------

def obj1(k: String, v: Json.Val) -> Json.Val:
  Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), k, v)}

# RFC 8259 §3: literal names.
law parse_null:
  {J.parse("null") == Some{Json.Null{}} : Maybe<&2, Json.Val>}

law parse_true:
  {J.parse("true") == Some{Json.Flag{True{}}} : Maybe<&2, Json.Val>}

law parse_false:
  {J.parse("false") == Some{Json.Flag{False{}}} : Maybe<&2, Json.Val>}

law parse_empty_arr:
  {J.parse("[]") == Some{Json.Arr{Nil{}}} : Maybe<&2, Json.Val>}

law parse_empty_obj:
  {J.parse("{}") == Some{Json.Obj{Map.new(&2, Json.Val)}} : Maybe<&2, Json.Val>}

# §2: one value per text.
law trailing_junk:
  {J.parse("null x") == None{} : Maybe<&2, Json.Val>}

law parse_nested:
  {J.parse("{\"a\":[1,{\"b\":null}],\"c\":\"x\"}") == Some{Json.Obj{Map.set(&2, Json.Val, Map.set(&2, Json.Val, Map.new(&2, Json.Val), "a", Json.Arr{[Json.Num{"1"}, obj1("b", Json.Null{})]}), "c", Json.Str{"x"})}} : Maybe<&2, Json.Val>}

# §2: insignificant whitespace around structural characters.
law parse_ws:
  {J.parse(" \t{ \"a\" :\n[ 1 , 2 ]\r\n} ") == Some{obj1("a", Json.Arr{[Json.Num{"1"}, Json.Num{"2"}]})} : Maybe<&2, Json.Val>}

law parse_deep:
  {J.parse("[[[[[]]]]]") == Some{Json.Arr{[Json.Arr{[Json.Arr{[Json.Arr{[Json.Arr{Nil{}}]}]}]}]}} : Maybe<&2, Json.Val>}

# §4: names SHOULD be unique; like most parsers, the last one wins.
law dup_key_last:
  {J.parse("{\"a\":1,\"a\":2}") == Some{obj1("a", Json.Num{"2"})} : Maybe<&2, Json.Val>}

# §6: number grammar; the text is kept exactly.
law num_neg_frac_exp:
  {J.parse("-12.5e+3") == Some{Json.Num{"-12.5e+3"}} : Maybe<&2, Json.Val>}

law num_neg_zero:
  {J.parse("-0") == Some{Json.Num{"-0"}} : Maybe<&2, Json.Val>}

law num_big_exp:
  {J.parse("1E400") == Some{Json.Num{"1E400"}} : Maybe<&2, Json.Val>}

law num_leading_zero_rejects:
  {J.parse("01") == None{} : Maybe<&2, Json.Val>}

law num_bare_minus_rejects:
  {J.parse("-") == None{} : Maybe<&2, Json.Val>}

law num_dot_end_rejects:
  {J.parse("1.") == None{} : Maybe<&2, Json.Val>}

law num_dot_start_rejects:
  {J.parse(".5") == None{} : Maybe<&2, Json.Val>}

law num_exp_end_rejects:
  {J.parse("1e") == None{} : Maybe<&2, Json.Val>}

law num_plus_rejects:
  {J.parse("+1") == None{} : Maybe<&2, Json.Val>}

# §7: escapes.
law str_escapes:
  {J.parse("\"a\\\"b\\\\c\\/d\\n\\t\"") == Some{Json.Str{"a\"b\\c/d\n\t"}} : Maybe<&2, Json.Val>}

law str_unicode_pair:
  {J.parse("\"\\u00e9\\ud83d\\ude00\"") == Some{Json.Str{"é😀"}} : Maybe<&2, Json.Val>}

# §8.2: an unpaired surrogate becomes U+FFFD.
law str_lone_surrogate:
  {J.parse("\"\\ud83dx\"") == Some{Json.Str{"\u{FFFD}x"}} : Maybe<&2, Json.Val>}

law str_raw_control_rejects:
  {J.parse("\"a\nb\"") == None{} : Maybe<&2, Json.Val>}

law str_bad_escape_rejects:
  {J.parse("\"\\x\"") == None{} : Maybe<&2, Json.Val>}

law str_unterminated_rejects:
  {J.parse("\"abc") == None{} : Maybe<&2, Json.Val>}

# §5, §4: structure.
law arr_trailing_comma_rejects:
  {J.parse("[1,]") == None{} : Maybe<&2, Json.Val>}

law arr_missing_comma_rejects:
  {J.parse("[1 2]") == None{} : Maybe<&2, Json.Val>}

law obj_missing_colon_rejects:
  {J.parse("{\"a\" 1}") == None{} : Maybe<&2, Json.Val>}

law obj_trailing_comma_rejects:
  {J.parse("{\"a\":1,}") == None{} : Maybe<&2, Json.Val>}

law obj_number_key_rejects:
  {J.parse("{1:2}") == None{} : Maybe<&2, Json.Val>}

law unclosed_rejects:
  {J.parse("[{\"a\":[1]") == None{} : Maybe<&2, Json.Val>}

law empty_rejects:
  {J.parse("  ") == None{} : Maybe<&2, Json.Val>}

law roundtrip:
  {J.parse(Json.encode(Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})})) == Some{Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})}} : Maybe<&2, Json.Val>}

