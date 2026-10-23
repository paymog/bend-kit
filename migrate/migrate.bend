# Versioned subscription records: validated JSON decode, proved migrations, and encode. Source: https://github.com/paymog/bend-kit/tree/main/migrate
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-encoding@0.4.0.0/encoding.bend as Encoding

type Period is Data:
  Monthly{}
  Yearly{}

type Status is Data:
  Active{}
  Paused{}
  Cancelled{}

# v1: a monthly price and an on/off flag.
type V1 is Data:
  V1{id: U32, plan: String, monthly_cents: U32, active: Bool}

# v2: a price per billing period, a three-state status, and a support note.
type V2 is Data:
  V2{id: U32, plan: String, cents: U32, period: Period, status: Status, note: String}

# v3: v2 without the support note.
type V3 is Data:
  V3{id: U32, plan: String, cents: U32, period: Period, status: Status}

# A decoded record and the version it was written in.
type Record is Data:
  R1{r: V1}
  R2{r: V2}
  R3{r: V3}

# What a subscription means to billing: who, which plan, the price per period, and the status.
type Terms is Data:
  Terms{id: U32, plan: String, cents: U32, period: Period, status: Status}

# What v2 to v3 discards.
type Dropped is Data:
  Dropped{note: String}

type Error is Data:
  Malformed{}
  Unsupported{version: U32}
  Missing{field: String}
  Unknown{field: String}
  Duplicate{field: String}
  BadField{field: String}
  Invalid{field: String}
  NotInV1{field: String}

# Meaning
# -------

# v1 had no pause: an inactive v1 subscription is cancelled.
def Status.of_active(a: Bool) -> Status:
  match a:
    case True{}:
      Active{}
    case False{}:
      Cancelled{}

def V1.terms(r: V1) -> Terms:
  V1{i, p, c, a} = r
  Terms{i, p, c, Monthly{}, Status.of_active(a)}

def V2.terms(r: V2) -> Terms:
  V2{i, p, c, pe, s, n} = r
  Terms{i, p, c, pe, s}

def V3.terms(r: V3) -> Terms:
  V3{i, p, c, pe, s} = r
  Terms{i, p, c, pe, s}

def Record.terms(r: Record) -> Terms:
  match r:
    case R1{x}:
      V1.terms(x)
    case R2{x}:
      V2.terms(x)
    case R3{x}:
      V3.terms(x)

def Terms.cents(+c: U32) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, U32.is_eq(c, 0), Some{"cents"}, None{})

def none(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{f}:
      False{}

# The first business rule the terms break: an empty plan or a zero price.
def Terms.problem(t: Terms) -> Maybe<&2, String>:
  Terms{i, p, +c, pe, s} = t
  Bool.pick(Maybe<&2, String>, String.is_empty(p), Some{"plan"}, Terms.cents(c))

def Terms.valid(t: Terms) -> Bool:
  none(Terms.problem(t))

def Record.valid(r: Record) -> Bool:
  Terms.valid(Record.terms(r))

# Migrations
# ----------

# v1 to v2. Total; V2.down undoes it.
def V1.up(r: V1) -> V2:
  V1{i, p, c, a} = r
  V2{i, p, c, Monthly{}, Status.of_active(a), ""}

def V2.down.note(n: String, i: U32, p: String, c: U32, a: Bool) -> Result<&2, &2, Error, V1>:
  match n:
    case SNil{}:
      Done{V1{i, p, c, a}}
    case SCon{h, t}:
      Fail{NotInV1{"note"}}

def V2.down.status(s: Status, i: U32, p: String, c: U32, n: String) -> Result<&2, &2, Error, V1>:
  match s:
    case Active{}:
      V2.down.note(n, i, p, c, True{})
    case Paused{}:
      Fail{NotInV1{"status"}}
    case Cancelled{}:
      V2.down.note(n, i, p, c, False{})

def V2.down.period(pe: Period, i: U32, p: String, c: U32, s: Status, n: String) -> Result<&2, &2, Error, V1>:
  match pe:
    case Monthly{}:
      V2.down.status(s, i, p, c, n)
    case Yearly{}:
      Fail{NotInV1{"period"}}

# v2 to v1, for a monthly record that is not paused and has no note.
def V2.down(r: V2) -> Result<&2, &2, Error, V1>:
  V2{i, p, c, pe, s, n} = r
  V2.down.period(pe, i, p, c, s, n)

# v2 to v3. Lossy: it drops the note and returns it.
def V2.up(r: V2) -> V3 & Dropped:
  V2{i, p, c, pe, s, n} = r
  (V3{i, p, c, pe, s}, Dropped{n})

# The v2 record that V2.up turned into r and d.
def V3.restore(r: V3, d: Dropped) -> V2:
  V3{i, p, c, pe, s} = r
  Dropped{n} = d
  V2{i, p, c, pe, s, n}

# v3 to v2, with an empty note.
def V3.down(r: V3) -> V2:
  V3.restore(r, Dropped{""})

# Any version to v3, with what the chain dropped.
def Record.upgrade(r: Record) -> V3 & Dropped:
  match r:
    case R1{x}:
      V2.up(V1.up(x))
    case R2{x}:
      V2.up(x)
    case R3{x}:
      (x, Dropped{""})

# Decode
# ------

# A JSON field value, reduced to what records use.
type Scalar is Data:
  SNum{n: U32}
  SStr{s: String}
  SFlag{b: Bool}
  SOther{}

def scalar.num(m: Maybe<&2, U32>) -> Scalar:
  match m:
    case Some{n}:
      SNum{n}
    case None{}:
      SOther{}

def scalar(v: Json.Val) -> Scalar:
  match v:
    case Json.Num{s}:
      scalar.num(Json.u32(Json.Num{s}))
    case Json.Str{s}:
      SStr{Encoding.utf8.decode(s)}
    case Json.Flag{b}:
      SFlag{b}
    case Json.Null{}:
      SOther{}
    case Json.Arr{xs}:
      SOther{}
    case Json.Obj{kvs}:
      SOther{}

# One object field: its decoded key and its value.
type Field is Data:
  Field{key: String, value: Scalar}

def fields.of(kvs: List<&1, Bytes.Bytes & Json.Val>) -> List<&2, Field>:
  match kvs:
    case Nil{}:
      Nil{}
    case Con{(k, v), t}:
      Con{Field{Encoding.utf8.decode(k), scalar(v)}, fields.of(t)}

def fields.get(fs: List<&2, Field>, +k: String) -> Maybe<&2, Scalar>:
  match fs:
    case Nil{}:
      None{}
    case Con{Field{key, s}, t}:
      Bool.pick(Maybe<&2, Scalar>, String.eq(k, key), Some{s}, fields.get(t, k))

def fields.has(fs: List<&2, Field>, +k: String) -> Bool:
  match fs:
    case Nil{}:
      False{}
    case Con{Field{key, s}, t}:
      Bool.or(String.eq(k, key), fields.has(t, k))

def has(xs: List<&2, String>, +k: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, t}:
      Bool.or(String.eq(k, x), has(t, k))

# The first key that the version does not define, or that repeats.
def fields.bad(fs: List<&2, Field>, +known: List<&2, String>) -> Maybe<&2, Error>:
  match fs:
    case Nil{}:
      None{}
    case Con{Field{+k, s}, +t}:
      Bool.pick(Maybe<&2, Error>, has(known, k), Bool.pick(Maybe<&2, Error>, fields.has(t, k), Some{Duplicate{k}}, fields.bad(t, known)), Some{Unknown{k}})

def only(m: Maybe<&2, Error>) -> Result<&2, &2, Error, Unit>:
  match m:
    case None{}:
      Done{Unit{}}
    case Some{e}:
      Fail{e}

def need.u32(m: Maybe<&2, Scalar>, +f: String) -> Result<&2, &2, Error, U32>:
  match m:
    case None{}:
      Fail{Missing{f}}
    case Some{SNum{n}}:
      Done{n}
    case Some{s}:
      Fail{BadField{f}}

def need.flag(m: Maybe<&2, Scalar>, +f: String) -> Result<&2, &2, Error, Bool>:
  match m:
    case None{}:
      Fail{Missing{f}}
    case Some{SFlag{b}}:
      Done{b}
    case Some{s}:
      Fail{BadField{f}}

def need.str(m: Maybe<&2, Scalar>, +f: String) -> Result<&2, &2, Error, String>:
  match m:
    case None{}:
      Fail{Missing{f}}
    case Some{SStr{s}}:
      Done{s}
    case Some{s}:
      Fail{BadField{f}}

# An optional string field: absent gives d.
def opt.str(m: Maybe<&2, Scalar>, d: String, +f: String) -> Result<&2, &2, Error, String>:
  match m:
    case None{}:
      Done{d}
    case Some{SStr{s}}:
      Done{s}
    case Some{s}:
      Fail{BadField{f}}

def Period.of(+s: String) -> Result<&2, &2, Error, Period>:
  Bool.pick(Result<&2, &2, Error, Period>, String.eq(s, "monthly"), Done{Monthly{}}, Bool.pick(Result<&2, &2, Error, Period>, String.eq(s, "yearly"), Done{Yearly{}}, Fail{BadField{"period"}}))

def Status.of(+s: String) -> Result<&2, &2, Error, Status>:
  Bool.pick(Result<&2, &2, Error, Status>, String.eq(s, "active"), Done{Active{}}, Bool.pick(Result<&2, &2, Error, Status>, String.eq(s, "paused"), Done{Paused{}}, Bool.pick(Result<&2, &2, Error, Status>, String.eq(s, "cancelled"), Done{Cancelled{}}, Fail{BadField{"status"}})))

def decode.v1(+fs: List<&2, Field>) -> Result<&2, &2, Error, Record>:
  do Result<&2, &2, Error, Record>:
    u : Unit <- only(fields.bad(fs, ["version", "id", "plan", "monthly_cents", "active"]))
    i : U32 <- need.u32(fields.get(fs, "id"), "id")
    p : String <- need.str(fields.get(fs, "plan"), "plan")
    c : U32 <- need.u32(fields.get(fs, "monthly_cents"), "monthly_cents")
    a : Bool <- need.flag(fields.get(fs, "active"), "active")
    return R1{V1{i, p, c, a}}

def decode.v2(+fs: List<&2, Field>) -> Result<&2, &2, Error, Record>:
  do Result<&2, &2, Error, Record>:
    u : Unit <- only(fields.bad(fs, ["version", "id", "plan", "cents", "period", "status", "note"]))
    i : U32 <- need.u32(fields.get(fs, "id"), "id")
    p : String <- need.str(fields.get(fs, "plan"), "plan")
    c : U32 <- need.u32(fields.get(fs, "cents"), "cents")
    ps : String <- opt.str(fields.get(fs, "period"), "monthly", "period")
    pe : Period <- Period.of(ps)
    ss : String <- need.str(fields.get(fs, "status"), "status")
    s : Status <- Status.of(ss)
    n : String <- opt.str(fields.get(fs, "note"), "", "note")
    return R2{V2{i, p, c, pe, s, n}}

def decode.v3(+fs: List<&2, Field>) -> Result<&2, &2, Error, Record>:
  do Result<&2, &2, Error, Record>:
    u : Unit <- only(fields.bad(fs, ["version", "id", "plan", "cents", "period", "status"]))
    i : U32 <- need.u32(fields.get(fs, "id"), "id")
    p : String <- need.str(fields.get(fs, "plan"), "plan")
    c : U32 <- need.u32(fields.get(fs, "cents"), "cents")
    ps : String <- need.str(fields.get(fs, "period"), "period")
    pe : Period <- Period.of(ps)
    ss : String <- need.str(fields.get(fs, "status"), "status")
    s : Status <- Status.of(ss)
    return R3{V3{i, p, c, pe, s}}

def decode.at(+n: U32, +fs: List<&2, Field>) -> Result<&2, &2, Error, Record>:
  match n:
    case 1:
      decode.v1(fs)
    case 2:
      decode.v2(fs)
    case 3:
      decode.v3(fs)
    case _:
      Fail{Unsupported{n}}

def decode.version(m: Maybe<&2, Scalar>, +fs: List<&2, Field>) -> Result<&2, &2, Error, Record>:
  match m:
    case None{}:
      Fail{Missing{"version"}}
    case Some{SNum{n}}:
      decode.at(n, fs)
    case Some{s}:
      Fail{BadField{"version"}}

def decode.shape(v: Json.Val) -> Result<&2, &2, Error, Record>:
  match v:
    case Json.Obj{kvs}:
      +fs = fields.of(kvs)
      decode.version(fields.get(fs, "version"), fs)
    case _:
      Fail{Malformed{}}

def Record.check.of(m: Maybe<&2, String>, r: Record) -> Result<&2, &2, Error, Record>:
  match m:
    case None{}:
      Done{r}
    case Some{f}:
      Fail{Invalid{f}}

# r when its terms keep the business rules.
def Record.check(r: Record) -> Result<&2, &2, Error, Record>:
  +s = r
  Record.check.of(Terms.problem(Record.terms(s)), s)

# One record from a parsed JSON value. Only a valid record decodes.
def decode.val(v: Json.Val) -> Result<&2, &2, Error, Record>:
  Result.bind(&2, &2, Error, Record, Record, decode.shape(v), Record.check)

def decode.parsed(m: Maybe<&1, Json.Val>) -> Result<&2, &2, Error, Record>:
  match m:
    case None{}:
      Fail{Malformed{}}
    case Some{v}:
      decode.val(v)

# One record from UTF-8 JSON: an object nested no deeper than one level.
def decode(b: Bytes.Bytes) -> Result<&2, &2, Error, Record>:
  decode.parsed(Json.parse.strict.bytes(b, 1))

# Encode
# ------

def num(+n: U32) -> Json.Val:
  Json.Num{Json.utf8(U32.show(n))}

def str(s: String) -> Json.Val:
  Json.Str{Json.utf8(s)}

def kv(k: String, v: Json.Val) -> Bytes.Bytes & Json.Val:
  (Json.utf8(k), v)

def Period.name(p: Period) -> String:
  match p:
    case Monthly{}:
      "monthly"
    case Yearly{}:
      "yearly"

def Status.name(s: Status) -> String:
  match s:
    case Active{}:
      "active"
    case Paused{}:
      "paused"
    case Cancelled{}:
      "cancelled"

def V1.json(r: V1) -> Json.Val:
  V1{i, p, c, a} = r
  Json.Obj{[kv("version", num(1)), kv("id", num(i)), kv("plan", str(p)), kv("monthly_cents", num(c)), kv("active", Json.Flag{a})]}

def V2.json(r: V2) -> Json.Val:
  V2{i, p, c, pe, s, n} = r
  Json.Obj{[kv("version", num(2)), kv("id", num(i)), kv("plan", str(p)), kv("cents", num(c)), kv("period", str(Period.name(pe))), kv("status", str(Status.name(s))), kv("note", str(n))]}

def V3.json(r: V3) -> Json.Val:
  V3{i, p, c, pe, s} = r
  Json.Obj{[kv("version", num(3)), kv("id", num(i)), kv("plan", str(p)), kv("cents", num(c)), kv("period", str(Period.name(pe))), kv("status", str(Status.name(s)))]}

# The record as a JSON object in its own version.
def Record.json(r: Record) -> Json.Val:
  match r:
    case R1{x}:
      V1.json(x)
    case R2{x}:
      V2.json(x)
    case R3{x}:
      V3.json(x)

def encode(r: Record) -> Bytes.Bytes:
  Json.encode.bytes(Record.json(r))
