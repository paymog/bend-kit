import Base
import ./csv.bend as Csv
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def strs(fs: List<&1, Bytes.Bytes>) -> List<&2, String>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Bytes.to_string(h) <> strs(t)

def recs(rs: List<&1, List<&1, Bytes.Bytes>>) -> List<&2, List<&2, String>>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      strs(h) <> recs(t)

def shown(r: Result<&1, &1, U32, List<&1, List<&1, Bytes.Bytes>>>) -> Result<&2, &2, U32, List<&2, List<&2, String>>>:
  match r:
    case Fail{at}:
      Fail{at}
    case Done{rs}:
      Done{recs(rs)}

# parse of a byte string, one Char per octet, with fields as byte strings.
def ps(+s: String) -> Result<&2, &2, U32, List<&2, List<&2, String>>>:
  shown(Csv.parse(Bytes.from_string(s)))

def bfs(fs: List<&2, String>) -> List<&1, Bytes.Bytes>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Bytes.from_string(h) <> bfs(t)

def brs(rs: List<&2, List<&2, String>>) -> List<&1, List<&1, Bytes.Bytes>>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      bfs(h) <> brs(t)

# encode of records given as byte strings, as a byte string.
def es(rs: List<&2, List<&2, String>>) -> String:
  Bytes.to_string(Csv.encode(brs(rs)))

# Reading back what encode wrote.
def rt(+rs: List<&2, List<&2, String>>) -> Result<&2, &2, U32, List<&2, List<&2, String>>>:
  ps(es(rs))

# The fields of one cursor step and the offset after it; End is (["<end>"], 0).
def step.of(n: Csv.Next) -> Result<&1, &1, U32, List<&2, String> & U32>:
  match n:
    case Csv.Row{fs, Csv.Cur{Bytes.Bytes{+len, buf}, +at}}:
      Done{(strs(fs), at)}
    case Csv.End{}:
      Done{(["<end>"], 0)}
    case Csv.Bad{at}:
      Fail{at}

def after(n: Csv.Next) -> Csv.Next:
  match n:
    case Csv.Row{fs, cur}:
      Csv.next(cur)
    case Csv.End{}:
      Csv.End{}
    case Csv.Bad{at}:
      Csv.Bad{at}

def first(+s: String) -> Result<&1, &1, U32, List<&2, String> & U32>:
  step.of(Csv.next(Csv.cursor(Bytes.from_string(s))))

def second(+s: String) -> Result<&1, &1, U32, List<&2, String> & U32>:
  step.of(after(Csv.next(Csv.cursor(Bytes.from_string(s)))))

def third(+s: String) -> Result<&1, &1, U32, List<&2, String> & U32>:
  step.of(after(after(Csv.next(Csv.cursor(Bytes.from_string(s))))))

# RFC 4180 §2.1: records end with CRLF.
law rfc_crlf_records:
  {ps("aaa,bbb,ccc\r\nzzz,yyy,xxx\r\n") == Done{[["aaa", "bbb", "ccc"], ["zzz", "yyy", "xxx"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

# RFC 4180 §2.2: the last record may have no line end.
law rfc_last_line_end_optional:
  {ps("aaa,bbb,ccc\r\nzzz,yyy,xxx") == Done{[["aaa", "bbb", "ccc"], ["zzz", "yyy", "xxx"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

# RFC 4180 §2.5: fields may be quoted.
law rfc_quoted_fields:
  {ps("\"aaa\",\"bbb\",\"ccc\"\r\nzzz,yyy,xxx") == Done{[["aaa", "bbb", "ccc"], ["zzz", "yyy", "xxx"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

# RFC 4180 §2.6: a quoted field may hold CRLF and commas.
law rfc_quoted_line_break:
  {ps("\"aaa\",\"b\r\nbb\",\"c,cc\"\r\nzzz,yyy,xxx") == Done{[["aaa", "b\r\nbb", "c,cc"], ["zzz", "yyy", "xxx"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

# RFC 4180 §2.7: "" in a quoted field is one quote.
law rfc_doubled_quote:
  {ps("\"aaa\",\"b\"\"bb\",\"ccc\"") == Done{[["aaa", "b\"bb", "ccc"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law only_quotes:
  {ps("\"\"\"\"\"\"") == Done{[["\"\""]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law lf_and_lone_cr_end_records:
  {ps("a\nb\rc\r\nd") == Done{[["a"], ["b"], ["c"], ["d"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law empty_input:
  {ps("") == Done{Nil{}} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law empty_fields:
  {ps(",,") == Done{[["", "", ""]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law trailing_comma:
  {ps("a,\n") == Done{[["a", ""]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law empty_line_has_no_fields:
  {ps("a\n\nb") == Done{[["a"], [], ["b"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law quoted_empty:
  {ps("\"\",x") == Done{[["", "x"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law single_quoted_empty:
  {ps("\"\"\r\n") == Done{[[""]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law octets_kept:
  {ps("\u{ff}\u{0},\u{c3}\u{a9}") == Done{[["\u{ff}\u{0}", "\u{c3}\u{a9}"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

# RFC 4180 §2.5: a quote may not appear in an unquoted field.
law bad_quote_in_unquoted:
  {ps("ab\"c") == Fail{2} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law bad_text_after_closing_quote:
  {ps("\"a\"b") == Fail{3} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law bad_unclosed_quote:
  {ps("\"ab") == Fail{3} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law bad_offset_is_absolute:
  {ps("x,y\n\"a\"b") == Fail{7} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law cursor_first:
  {first("a,b\r\nc") == Done{(["a", "b"], 5)} : Result<&1, &1, U32, List<&2, String> & U32>}

law cursor_second:
  {second("a,b\r\nc") == Done{(["c"], 6)} : Result<&1, &1, U32, List<&2, String> & U32>}

law cursor_end:
  {third("a,b\r\nc") == Done{(["<end>"], 0)} : Result<&1, &1, U32, List<&2, String> & U32>}

law cursor_bad_after_good_row:
  {second("a\n\"b") == Fail{4} : Result<&1, &1, U32, List<&2, String> & U32>}

law encode_plain:
  {es([["a", "b"], ["c"]]) == "a,b\r\nc\r\n" : String}

law encode_none:
  {es(Nil{}) == "" : String}

law encode_one_empty_field:
  {es([[""]]) == "\"\"\r\n" : String}

law encode_zero_fields:
  {es([[]]) == "\r\n" : String}

# RFC 4180 §2.6-2.7: quote only fields that hold a quote, comma, CR, or LF.
law encode_quotes_when_needed:
  {es([["a,b", "q\"q", "l\nf", "c\rr", "plain", ""]]) == "\"a,b\",\"q\"\"q\",\"l\nf\",\"c\rr\",plain,\r\n" : String}

law round_trip_plain:
  {rt([["aaa", "bbb"], ["", "z"]]) == Done{[["aaa", "bbb"], ["", "z"]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law round_trip_special:
  {rt([["\"", "\"\"x\"", ",\r\n,"], ["end\""]]) == Done{[["\"", "\"\"x\"", ",\r\n,"], ["end\""]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}

law round_trip_empty_rows:
  {rt([[], [""], [], [""]]) == Done{[[], [""], [], [""]]} : Result<&2, &2, U32, List<&2, List<&2, String>>>}
