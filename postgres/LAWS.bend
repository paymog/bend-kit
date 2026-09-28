import Base
import ./codec.bend as C
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def b(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def unhex(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case Some{x}:
      x
    case None{}:
      Bytes.new(0)

# Hex fixtures, as a capture tool prints them.
def x(+h: String) -> Bytes.Bytes:
  unhex(Bytes.from_hex(h))

def hex(m: C.Front) -> String:
  Bytes.to_hex(C.encode(m))

def hex.back(m: C.Back) -> String:
  Bytes.to_hex(C.encode.back(m))

def rt(+mode: U32, m: C.Front) -> Maybe<&1, C.Front>:
  C.decode.front(mode, C.encode(m))

def got.end(m: C.Back, r: C.Reader & U32) -> Maybe<&1, C.Back>:
  (rd, +k) = r
  Bool.pick(Maybe<&1, C.Back>, U32.is_eq(k, 0), Some{m}, None{})

# One message that uses up every byte read.
def got(r: C.Reader & C.Next) -> Maybe<&1, C.Back>:
  (rd, n) = r
  match n:
    case C.Got{m}:
      got.end(m, C.pending(rd))
    case C.Want{}:
      None{}
    case C.Bad{}:
      None{}

def rt.back(m: C.Back) -> Maybe<&1, C.Back>:
  got(C.next(C.feed(C.reader(), C.encode.back(m))))

def step.of(r: C.Reader & C.Next) -> C.Next:
  (rd, n) = r
  n

def step(+h: String) -> C.Next:
  step.of(C.next(C.feed(C.reader(), x(h))))

# ---- splits: every message out, re-encoded, in order; "bad" or "fuel" marks a failure

def drain(f: Nat, r: C.Reader & C.Next, acc: String) -> C.Reader & String:
  match f:
    case 0n:
      (rd, n) = r
      (rd, acc ++ "fuel")
    case 1n+p:
      (rd, n) = r
      match n:
        case C.Got{m}:
          drain(p, C.next(rd), acc ++ hex.back(m))
        case C.Want{}:
          (rd, acc)
        case C.Bad{}:
          (rd, acc ++ "bad")

def split.c(+s: String, r: C.Reader & U32) -> String:
  (rd, +k) = r
  Bool.pick(String, U32.is_eq(k, 0), s, s ++ "left")

def split.b(r: C.Reader & String) -> String:
  (rd, s) = r
  split.c(s, C.pending(rd))

def split.a(rest: Bytes.Bytes, r: C.Reader & String) -> String:
  (rd, s) = r
  split.b(drain(16n, C.next(C.feed(rd, rest)), s))

def split.cut(+k: U32, +h: String, r: Bytes.Bytes & Bytes.Bytes) -> Bool:
  (whole, first) = r
  String.eq(split.a(Bytes.snd(Bytes.slice(whole, k, 4294967295)), drain(16n, C.next(C.feed(C.reader(), first)), "")), h)

# The first k bytes fed and drained, then the rest: the same messages as the whole stream, nothing left over.
def split.at(+h: String, +k: U32) -> Bool:
  split.cut(k, h, Bytes.slice(x(h), 0, k))

def splits.go(n: Nat, +h: String, +k: U32) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      Bool.and(split.at(h, k), splits.go(p, h, (k + 1 : U32)))

# Every split point, 0 through len.
def splits(+h: String) -> Bool:
  splits.go(U32.to_nat(((Bytes.count(h, 0) >> 1n) + 1 : U32)), h, 0)

# ---- fixtures

# AuthenticationOk, ParameterStatus, BackendKeyData, ReadyForQuery.
def session() -> String:
  "52000000080000000053000000187365727665725f76657273696f6e0031362e34004b0000000c000004d20000162e5a0000000549"

# RowDescription, DataRow with a NULL, CommandComplete, ReadyForQuery.
def rows() -> String:
  "540000001b0001696400000040000001000000170004ffffffff000044000000100002000000023432ffffffff430000000d53454c4543542031005a0000000549"

def id.field() -> C.Field:
  C.Field{b("id"), 16384, 1, 23, 4, 4294967295, 0}

def rfc.first() -> Bytes.Bytes:
  b("n,,n=user,r=rOprNGfwEbeRWgbNEkqO")

def missing() -> List<&1, C.Notice>:
  [C.Notice{83, b("ERROR")}, C.Notice{67, b("42P01")}, C.Notice{77, b("relation \"x\" does not exist")}]

# ---- frontend wire bytes

law enc_startup:
  {hex(C.Startup{[C.Param{b("user"), b("alice")}, C.Param{b("database"), b("app")}]}) == "00000021000300007573657200616c696365006461746162617365006170700000" : String}

law enc_ssl_request:
  {hex(C.SSLRequest{}) == "0000000804d2162f" : String}

law enc_password:
  {hex(C.Password{b("secret")}) == "700000000b73656372657400" : String}

law enc_sasl_initial:
  {hex(C.SASLInitial{b("SCRAM-SHA-256"), rfc.first()}) == "7000000036534352414d2d5348412d32353600000000206e2c2c6e3d757365722c723d724f70724e476677456265525767624e456b714f" : String}

law enc_sasl_response:
  {hex(C.SASLResponse{b("c=biws,r=x")}) == "700000000e633d626977732c723d78" : String}

law enc_parse:
  {hex(C.Parse{b(""), b("SELECT $1::int"), [23]}) == "500000001a0053454c4543542024313a3a696e7400000100000017" : String}

law enc_bind:
  {hex(C.Bind{b(""), b(""), [], [Some{b("42")}, None{}], []}) == "4200000016000000000002000000023432ffffffff0000" : String}

law enc_describe:
  {hex(C.Describe{80, b("")}) == "44000000065000" : String}

law enc_execute:
  {hex(C.Execute{b(""), 0}) == "45000000090000000000" : String}

law enc_sync:
  {hex(C.Sync{}) == "5300000004" : String}

law enc_close:
  {hex(C.CloseMsg{83, b("s1")}) == "430000000853733100" : String}

law enc_terminate:
  {hex(C.Terminate{}) == "5800000004" : String}

# ---- frontend decode(encode(m)) == m; mode names the phase the protocol leaves to context

law rt_startup:
  {rt(0, C.Startup{[C.Param{b("user"), b("alice")}, C.Param{b("options"), b("")}]}) == Some{C.Startup{[C.Param{b("user"), b("alice")}, C.Param{b("options"), b("")}]}} : Maybe<&1, C.Front>}

law rt_ssl_request:
  {rt(0, C.SSLRequest{}) == Some{C.SSLRequest{}} : Maybe<&1, C.Front>}

law rt_password:
  {rt(1, C.Password{b("secret")}) == Some{C.Password{b("secret")}} : Maybe<&1, C.Front>}

law rt_sasl_initial:
  {rt(2, C.SASLInitial{b("SCRAM-SHA-256"), rfc.first()}) == Some{C.SASLInitial{b("SCRAM-SHA-256"), rfc.first()}} : Maybe<&1, C.Front>}

law rt_sasl_response:
  {rt(3, C.SASLResponse{b("c=biws,r=x")}) == Some{C.SASLResponse{b("c=biws,r=x")}} : Maybe<&1, C.Front>}

law rt_parse:
  {rt(1, C.Parse{b("s1"), b("SELECT $1, $2"), [23, 25]}) == Some{C.Parse{b("s1"), b("SELECT $1, $2"), [23, 25]}} : Maybe<&1, C.Front>}

law rt_bind:
  {rt(1, C.Bind{b("p"), b("s1"), [0], [Some{b("42")}, None{}, Some{b("")}], [1, 0]}) == Some{C.Bind{b("p"), b("s1"), [0], [Some{b("42")}, None{}, Some{b("")}], [1, 0]}} : Maybe<&1, C.Front>}

law rt_describe:
  {rt(1, C.Describe{83, b("s1")}) == Some{C.Describe{83, b("s1")}} : Maybe<&1, C.Front>}

law rt_execute:
  {rt(1, C.Execute{b("p"), 100}) == Some{C.Execute{b("p"), 100}} : Maybe<&1, C.Front>}

law rt_sync:
  {rt(1, C.Sync{}) == Some{C.Sync{}} : Maybe<&1, C.Front>}

law rt_close:
  {rt(1, C.CloseMsg{80, b("p")}) == Some{C.CloseMsg{80, b("p")}} : Maybe<&1, C.Front>}

law rt_terminate:
  {rt(1, C.Terminate{}) == Some{C.Terminate{}} : Maybe<&1, C.Front>}

law dec_front_trailing:
  {C.decode.front(1, x("530000000400")) == None{} : Maybe<&1, C.Front>}

law dec_front_bad_kind:
  {C.decode.front(1, x("44000000065800")) == None{} : Maybe<&1, C.Front>}

# ---- backend wire bytes

law enc_auth_ok:
  {hex.back(C.AuthOk{}) == "520000000800000000" : String}

law enc_auth_sasl:
  {hex.back(C.AuthSASL{[b("SCRAM-SHA-256")]}) == "52000000170000000a534352414d2d5348412d3235360000" : String}

law enc_row_description:
  {hex.back(C.RowDescription{[id.field()]}) == "540000001b0001696400000040000001000000170004ffffffff0000" : String}

law enc_data_row:
  {hex.back(C.DataRow{[Some{b("42")}, None{}, Some{b("")}]}) == "44000000140003000000023432ffffffff00000000" : String}

law enc_error:
  {hex.back(C.ErrorResponse{missing()}) == "4500000030534552524f5200433432503031004d72656c6174696f6e2022782220646f6573206e6f742065786973740000" : String}

# ---- backend decode(encode(m)) == m

law rt_auth_ok:
  {rt.back(C.AuthOk{}) == Some{C.AuthOk{}} : Maybe<&1, C.Back>}

law rt_auth_cleartext:
  {rt.back(C.AuthCleartext{}) == Some{C.AuthCleartext{}} : Maybe<&1, C.Back>}

law rt_auth_sasl:
  {rt.back(C.AuthSASL{[b("SCRAM-SHA-256-PLUS"), b("SCRAM-SHA-256")]}) == Some{C.AuthSASL{[b("SCRAM-SHA-256-PLUS"), b("SCRAM-SHA-256")]}} : Maybe<&1, C.Back>}

law rt_auth_sasl_continue:
  {rt.back(C.AuthSASLContinue{b("r=abc,s=QSXCR+Q6sek8bf92,i=4096")}) == Some{C.AuthSASLContinue{b("r=abc,s=QSXCR+Q6sek8bf92,i=4096")}} : Maybe<&1, C.Back>}

law rt_auth_sasl_final:
  {rt.back(C.AuthSASLFinal{b("v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=")}) == Some{C.AuthSASLFinal{b("v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=")}} : Maybe<&1, C.Back>}

# MD5 (code 5) is out of scope: it arrives typed, with its salt.
law dec_auth_md5:
  {got(C.next(C.feed(C.reader(), x("520000000c0000000501020304")))) == Some{C.AuthOther{5, x("01020304")}} : Maybe<&1, C.Back>}

law rt_parameter_status:
  {rt.back(C.ParameterStatus{b("server_version"), b("16.4")}) == Some{C.ParameterStatus{b("server_version"), b("16.4")}} : Maybe<&1, C.Back>}

law rt_backend_key_data:
  {rt.back(C.BackendKeyData{1234, 5678}) == Some{C.BackendKeyData{1234, 5678}} : Maybe<&1, C.Back>}

law rt_ready_for_query:
  {rt.back(C.ReadyForQuery{84}) == Some{C.ReadyForQuery{84}} : Maybe<&1, C.Back>}

law rt_row_description:
  {rt.back(C.RowDescription{[id.field(), C.Field{b("name"), 0, 0, 25, 65535, 4294967295, 0}]}) == Some{C.RowDescription{[id.field(), C.Field{b("name"), 0, 0, 25, 65535, 4294967295, 0}]}} : Maybe<&1, C.Back>}

law rt_row_description_empty:
  {rt.back(C.RowDescription{[]}) == Some{C.RowDescription{[]}} : Maybe<&1, C.Back>}

law rt_data_row:
  {rt.back(C.DataRow{[Some{b("42")}, None{}, Some{b("")}]}) == Some{C.DataRow{[Some{b("42")}, None{}, Some{b("")}]}} : Maybe<&1, C.Back>}

law rt_command_complete:
  {rt.back(C.CommandComplete{b("INSERT 0 1")}) == Some{C.CommandComplete{b("INSERT 0 1")}} : Maybe<&1, C.Back>}

law rt_error:
  {rt.back(C.ErrorResponse{missing()}) == Some{C.ErrorResponse{missing()}} : Maybe<&1, C.Back>}

law rt_notice:
  {rt.back(C.NoticeResponse{[C.Notice{83, b("NOTICE")}, C.Notice{77, b("hi")}]}) == Some{C.NoticeResponse{[C.Notice{83, b("NOTICE")}, C.Notice{77, b("hi")}]}} : Maybe<&1, C.Back>}

law rt_parse_complete:
  {rt.back(C.ParseComplete{}) == Some{C.ParseComplete{}} : Maybe<&1, C.Back>}

law rt_bind_complete:
  {rt.back(C.BindComplete{}) == Some{C.BindComplete{}} : Maybe<&1, C.Back>}

law rt_close_complete:
  {rt.back(C.CloseComplete{}) == Some{C.CloseComplete{}} : Maybe<&1, C.Back>}

law rt_no_data:
  {rt.back(C.NoData{}) == Some{C.NoData{}} : Maybe<&1, C.Back>}

law rt_empty_query:
  {rt.back(C.EmptyQuery{}) == Some{C.EmptyQuery{}} : Maybe<&1, C.Back>}

law rt_portal_suspended:
  {rt.back(C.PortalSuspended{}) == Some{C.PortalSuspended{}} : Maybe<&1, C.Back>}

# ParameterDescription is not decoded: it arrives whole as Other.
law rt_other:
  {rt.back(C.Other{116, x("0000")}) == Some{C.Other{116, x("0000")}} : Maybe<&1, C.Back>}

law notice_get:
  {C.notice.get(67, missing()) == Some{b("42P01")} : Maybe<&1, Bytes.Bytes>}

# ---- framing and malformed bodies

law dec_want_header:
  {step("44000000") == C.Want{} : C.Next}

law dec_want_body:
  {step("440000001000") == C.Want{} : C.Next}

law dec_short_length:
  {step("5a00000003") == C.Bad{} : C.Next}

law dec_huge_length:
  {step("447fffffff") == C.Bad{} : C.Next}

law dec_bad_status:
  {step("5a0000000558") == C.Bad{} : C.Next}

law dec_no_nul:
  {step("430000000541") == C.Bad{} : C.Next}

law dec_trailing:
  {step("520000000c0000000000000000") == C.Bad{} : C.Next}

law dec_col_overrun:
  {step("440000000b00010000000541") == C.Bad{} : C.Next}

law dec_col_negative:
  {step("440000000b0001fffffffe41") == C.Bad{} : C.Next}

law dec_notice_unterminated:
  {step("450000000b534552524f5200") == C.Bad{} : C.Next}

# ---- a stream split at any point decodes as it does whole

law split_session:
  {splits(session()) == True{} : Bool}

law split_rows:
  {splits(rows()) == True{} : Bool}
