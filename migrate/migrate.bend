# Versioned subscription records: validated JSON decode, proved migrations, and encode. Source: https://github.com/paymog/bend-kit/tree/main/migrate
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-json@0.7.0.0/json.bend as Json

type Period is Data:
  Monthly{}
  Yearly{}

type Status is Data:
  Active{}
  Paused{}
  Cancelled{}

# v1: a monthly price and an on/off flag.
type V1 is Type:
  V1{id: U32, plan: Bytes.Bytes, monthly_cents: U32, active: Bool}

# v2: a price per billing period, a three-state status, and an optional support note.
type V2 is Type:
  V2{id: U32, plan: Bytes.Bytes, cents: U32, period: Period, status: Status, note: Maybe<&1, Bytes.Bytes>}

# v3: v2 without the support note.
type V3 is Type:
  V3{id: U32, plan: Bytes.Bytes, cents: U32, period: Period, status: Status}

# A decoded record and the version it was written in.
type Record is Type:
  R1{r: V1}
  R2{r: V2}
  R3{r: V3}

# What a subscription means to billing: who, which plan, the price per period, and the status.
type Terms is Type:
  Terms{id: U32, plan: Bytes.Bytes, cents: U32, period: Period, status: Status}

# What v2 to v3 discards.
type Dropped is Type:
  Dropped{note: Maybe<&1, Bytes.Bytes>}

# The JSON field names of every version.
type Key is Data:
  KVersion{}
  KId{}
  KPlan{}
  KMonthlyCents{}
  KActive{}
  KCents{}
  KPeriod{}
  KStatus{}
  KNote{}

type Error is Type:
  Malformed{}
  Unsupported{version: U32}
  Unknown{key: Bytes.Bytes}
  Unexpected{key: Key}
  Duplicate{key: Key}
  Missing{key: Key}
  BadField{key: Key}
  Invalid{key: Key}
  NotInV1{key: Key}

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

# The first business rule broken by a plan of len bytes and a price of c: an empty plan or a zero price.
def Terms.problem(+len: U32, +c: U32) -> Maybe<&2, Key>:
  Bool.pick(Maybe<&2, Key>, U32.is_eq(len, 0), Some{KPlan{}}, Bool.pick(Maybe<&2, Key>, U32.is_eq(c, 0), Some{KCents{}}, None{}))

def none(m: Maybe<&2, Key>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{k}:
      False{}

def Terms.valid(t: Terms) -> Bool:
  Terms{i, p, +c, pe, s} = t
  Bytes.Bytes{+len, buf} = p
  none(Terms.problem(len, c))

# The record back, and the first business rule it breaks.
def Record.problem(r: Record) -> Record & Maybe<&2, Key>:
  match r:
    case R1{V1{i, Bytes.Bytes{+len, buf}, +c, a}}:
      (R1{V1{i, Bytes.Bytes{len, buf}, c, a}}, Terms.problem(len, c))
    case R2{V2{i, Bytes.Bytes{+len, buf}, +c, pe, s, n}}:
      (R2{V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}}, Terms.problem(len, c))
    case R3{V3{i, Bytes.Bytes{+len, buf}, +c, pe, s}}:
      (R3{V3{i, Bytes.Bytes{len, buf}, c, pe, s}}, Terms.problem(len, c))

def Record.valid.of(p: Record & Maybe<&2, Key>) -> Bool:
  (r, m) = p
  none(m)

def Record.valid(r: Record) -> Bool:
  Record.valid.of(Record.problem(r))

# Migrations
# ----------

# v1 to v2. Total; V2.down undoes it.
def V1.up(r: V1) -> V2:
  V1{i, p, c, a} = r
  V2{i, p, c, Monthly{}, Status.of_active(a), None{}}

def V2.down.note(n: Maybe<&1, Bytes.Bytes>, i: U32, p: Bytes.Bytes, c: U32, a: Bool) -> Result<&1, &1, Error, V1>:
  match n:
    case None{}:
      Done{V1{i, p, c, a}}
    case Some{b}:
      Fail{NotInV1{KNote{}}}

def V2.down.status(s: Status, i: U32, p: Bytes.Bytes, c: U32, n: Maybe<&1, Bytes.Bytes>) -> Result<&1, &1, Error, V1>:
  match s:
    case Active{}:
      V2.down.note(n, i, p, c, True{})
    case Paused{}:
      Fail{NotInV1{KStatus{}}}
    case Cancelled{}:
      V2.down.note(n, i, p, c, False{})

def V2.down.period(pe: Period, i: U32, p: Bytes.Bytes, c: U32, s: Status, n: Maybe<&1, Bytes.Bytes>) -> Result<&1, &1, Error, V1>:
  match pe:
    case Monthly{}:
      V2.down.status(s, i, p, c, n)
    case Yearly{}:
      Fail{NotInV1{KPeriod{}}}

# v2 to v1, for a monthly record that is not paused and has no note.
def V2.down(r: V2) -> Result<&1, &1, Error, V1>:
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

# v3 to v2, with no note.
def V3.down(r: V3) -> V2:
  V3.restore(r, Dropped{None{}})

# Any version to v3, with what the chain dropped.
def Record.upgrade(r: Record) -> V3 & Dropped:
  match r:
    case R1{x}:
      V2.up(V1.up(x))
    case R2{x}:
      V2.up(x)
    case R3{x}:
      (x, Dropped{None{}})

# Names as bytes
# --------------

# A name of at most 16 bytes: its length and its first four little-endian words, zero past the end.
type Tag is Data:
  Tag{len: U32, w0: U32, w1: U32, w2: U32, w3: U32}

def Tag.eq(a: Tag, b: Tag) -> Bool:
  Tag{+l, +a0, +a1, +a2, +a3} = a
  Tag{+m, +b0, +b1, +b2, +b3} = b
  U32.is_eq(l, m) && U32.is_eq(a0, b0) && U32.is_eq(a1, b1) && U32.is_eq(a2, b2) && U32.is_eq(a3, b3)

def Tag.word(ok: Bool, a: Array<U32>, +i: U32) -> Array<U32> & U32:
  match ok:
    case True{}:
      Array.get(U32, a, i)
    case False{}:
      (a, 0)

def Tag.of.w3(+len: U32, +w0: U32, +w1: U32, +w2: U32, r: Array<U32> & U32) -> Bytes.Bytes & Tag:
  (a, +w3) = r
  (Bytes.Bytes{len, a}, Tag{len, w0, w1, w2, w3})

def Tag.of.w2(+len: U32, +n: U32, +w0: U32, +w1: U32, r: Array<U32> & U32) -> Bytes.Bytes & Tag:
  (a, +w2) = r
  Tag.of.w3(len, w0, w1, w2, Tag.word(U32.is_lt(3, n), a, 3))

def Tag.of.w1(+len: U32, +n: U32, +w0: U32, r: Array<U32> & U32) -> Bytes.Bytes & Tag:
  (a, +w1) = r
  Tag.of.w2(len, n, w0, w1, Tag.word(U32.is_lt(2, n), a, 2))

def Tag.of.w0(+len: U32, +n: U32, r: Array<U32> & U32) -> Bytes.Bytes & Tag:
  (a, +w0) = r
  Tag.of.w1(len, n, w0, Tag.word(U32.is_lt(1, n), a, 1))

# The bytes back, and their tag. Bytes past 16 are not read, but the length still differs.
def Tag.of(b: Bytes.Bytes) -> Bytes.Bytes & Tag:
  Bytes.Bytes{+len, buf} = b
  +n = Bytes.words(len)
  Tag.of.w0(len, n, Tag.word(U32.is_lt(0, n), buf, 0))

def Tag.set(ok: Bool, a: Array<U32>, +i: U32, +w: U32) -> Array<U32>:
  match ok:
    case True{}:
      Array.set(U32, a, i, w)
    case False{}:
      a

def Tag.bytes(t: Tag) -> Bytes.Bytes:
  Tag{+len, +w0, +w1, +w2, +w3} = t
  +n = Bytes.words(len)
  Bytes.Bytes{len, Tag.set(U32.is_lt(3, n), Tag.set(U32.is_lt(2, n), Tag.set(U32.is_lt(1, n), Tag.set(U32.is_lt(0, n), Bytes.alloc(len), 0, w0), 1, w1), 2, w2), 3, w3)}

def Key.tag(k: Key) -> Tag:
  match k:
    case KVersion{}:
      Tag{7, 1936876918, 7237481, 0, 0}
    case KId{}:
      Tag{2, 25705, 0, 0, 0}
    case KPlan{}:
      Tag{4, 1851878512, 0, 0, 0}
    case KMonthlyCents{}:
      Tag{13, 1953394541, 1601793128, 1953391971, 115}
    case KActive{}:
      Tag{6, 1769235297, 25974, 0, 0}
    case KCents{}:
      Tag{5, 1953391971, 115, 0, 0}
    case KPeriod{}:
      Tag{6, 1769104752, 25711, 0, 0}
    case KStatus{}:
      Tag{6, 1952543859, 29557, 0, 0}
    case KNote{}:
      Tag{4, 1702129518, 0, 0, 0}

# The key as UTF-8 JSON text.
def Key.bytes(k: Key) -> Bytes.Bytes:
  Tag.bytes(Key.tag(k))

def Key.is(k: Key, +t: Tag, rest: Maybe<&2, Key>) -> Maybe<&2, Key>:
  +k = k
  Bool.pick(Maybe<&2, Key>, Tag.eq(Key.tag(k), t), Some{k}, rest)

def Key.find(+t: Tag) -> Maybe<&2, Key>:
  Key.is(KVersion{}, t, Key.is(KId{}, t, Key.is(KPlan{}, t, Key.is(KMonthlyCents{}, t, Key.is(KActive{}, t, Key.is(KCents{}, t, Key.is(KPeriod{}, t, Key.is(KStatus{}, t, Key.is(KNote{}, t, None{})))))))))

def Period.tag(p: Period) -> Tag:
  match p:
    case Monthly{}:
      Tag{7, 1953394541, 7957608, 0, 0}
    case Yearly{}:
      Tag{6, 1918985593, 31084, 0, 0}

def Status.tag(s: Status) -> Tag:
  match s:
    case Active{}:
      Tag{6, 1769235297, 25974, 0, 0}
    case Paused{}:
      Tag{6, 1937072496, 25701, 0, 0}
    case Cancelled{}:
      Tag{9, 1668178275, 1701604453, 100, 0}

def Period.find(+t: Tag) -> Maybe<&2, Period>:
  Bool.pick(Maybe<&2, Period>, Tag.eq(Period.tag(Monthly{}), t), Some{Monthly{}}, Bool.pick(Maybe<&2, Period>, Tag.eq(Period.tag(Yearly{}), t), Some{Yearly{}}, None{}))

def Status.find(+t: Tag) -> Maybe<&2, Status>:
  Bool.pick(Maybe<&2, Status>, Tag.eq(Status.tag(Active{}), t), Some{Active{}}, Bool.pick(Maybe<&2, Status>, Tag.eq(Status.tag(Paused{}), t), Some{Paused{}}, Bool.pick(Maybe<&2, Status>, Tag.eq(Status.tag(Cancelled{}), t), Some{Cancelled{}}, None{})))

# Numbers as bytes
# ----------------

def u32.over(+acc: U32, +d: U32) -> Bool:
  Bool.or(U32.is_lt(429496729, acc), Bool.and(U32.is_eq(acc, 429496729), U32.is_lt(5, d)))

def u32.end(ok: Bool, +acc: U32) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{acc}
    case False{}:
      None{}

def u32.go(n: Nat, r: Array<U32> & U32, +i: U32, +acc: U32, ok: Bool) -> Maybe<&2, U32>:
  match n:
    case 0n:
      u32.end(ok, acc)
    case 1n+p:
      (a, +c) = r
      +d = (c - 48 : U32)
      u32.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (acc * 10 + d : U32), ok && U32.is_lt(d, 10) && Bool.not(u32.over(acc, d)))

def u32.first(+len: U32, r: Array<U32> & U32) -> Maybe<&2, U32>:
  (a, +c) = r
  +lead0 = U32.is_eq(c, 48) && U32.is_lt(1, len)
  u32.go(U32.to_nat(len), (a, c), 0, 0, U32.is_lt(0, len) && U32.is_lt(len, 11) && Bool.not(lead0))

# Decimal digits with no sign, fraction, exponent, or leading zero, below 2^32.
def u32.read(b: Bytes.Bytes) -> Maybe<&2, U32>:
  Bytes.Bytes{+len, buf} = b
  u32.first(len, Bytes.peek(buf, 0))

def u32.width(+n: U32) -> U32:
  Bool.pick(U32, U32.is_lt(n, 10), 1, Bool.pick(U32, U32.is_lt(n, 100), 2, Bool.pick(U32, U32.is_lt(n, 1000), 3, Bool.pick(U32, U32.is_lt(n, 10000), 4, Bool.pick(U32, U32.is_lt(n, 100000), 5, Bool.pick(U32, U32.is_lt(n, 1000000), 6, Bool.pick(U32, U32.is_lt(n, 10000000), 7, Bool.pick(U32, U32.is_lt(n, 100000000), 8, Bool.pick(U32, U32.is_lt(n, 1000000000), 9, 10)))))))))

def u32.fill(f: Nat, a: Array<U32>, +i: U32, +n: U32) -> Array<U32>:
  match f:
    case 0n:
      a
    case 1n+p:
      +q = (n / 10 : U32)
      u32.fill(p, Bytes.poke(a, i, (48 + n - q * 10 : U32)), (i - 1 : U32), q)

# n in decimal digits.
def u32.text(+n: U32) -> Bytes.Bytes:
  +k = u32.width(n)
  Bytes.Bytes{k, u32.fill(U32.to_nat(k), Bytes.alloc(k), (k - 1 : U32), n)}

# Decode
# ------

# A JSON field value, reduced to what records use. A number keeps its digits until the record is built.
type Scalar is Type:
  SNum{s: Bytes.Bytes}
  SStr{s: Bytes.Bytes}
  SFlag{b: Bool}
  SOther{}

def scalar(v: Json.Val) -> Scalar:
  match v:
    case Json.Num{s}:
      SNum{s}
    case Json.Str{s}:
      SStr{s}
    case Json.Flag{b}:
      SFlag{b}
    case Json.Null{}:
      SOther{}
    case Json.Arr{xs}:
      SOther{}
    case Json.Obj{kvs}:
      SOther{}

# Every field of a record object, by key, before the version picks which ones it allows.
type Slots is Type:
  Slots{version: Maybe<&1, Scalar>, id: Maybe<&1, Scalar>, plan: Maybe<&1, Scalar>, monthly_cents: Maybe<&1, Scalar>, active: Maybe<&1, Scalar>, cents: Maybe<&1, Scalar>, period: Maybe<&1, Scalar>, status: Maybe<&1, Scalar>, note: Maybe<&1, Scalar>}

def Slots.empty() -> Slots:
  Slots{None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}}

def slot.fill(m: Maybe<&1, Scalar>, x: Scalar, k: Key) -> Result<&1, &1, Error, Maybe<&1, Scalar>>:
  match m:
    case None{}:
      Done{Some{x}}
    case Some{y}:
      Fail{Duplicate{k}}

def Slots.set(k: Key, x: Scalar, s: Slots) -> Result<&1, &1, Error, Slots>:
  match k:
    case KVersion{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{m, i, p, mc, a, c, pe, st, n}, slot.fill(ve, x, KVersion{}))
    case KId{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, m, p, mc, a, c, pe, st, n}, slot.fill(i, x, KId{}))
    case KPlan{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, i, m, mc, a, c, pe, st, n}, slot.fill(p, x, KPlan{}))
    case KMonthlyCents{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, i, p, m, a, c, pe, st, n}, slot.fill(mc, x, KMonthlyCents{}))
    case KActive{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, i, p, mc, m, c, pe, st, n}, slot.fill(a, x, KActive{}))
    case KCents{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, i, p, mc, a, m, pe, st, n}, slot.fill(c, x, KCents{}))
    case KPeriod{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, i, p, mc, a, c, m, st, n}, slot.fill(pe, x, KPeriod{}))
    case KStatus{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, i, p, mc, a, c, pe, m, n}, slot.fill(st, x, KStatus{}))
    case KNote{}:
      Slots{ve, i, p, mc, a, c, pe, st, n} = s
      Result.map(&1, &1, Error, Maybe<&1, Scalar>, Slots, m => Slots{ve, i, p, mc, a, c, pe, st, m}, slot.fill(n, x, KNote{}))

def Slots.put(m: Maybe<&2, Key>, k: Bytes.Bytes, x: Scalar, s: Slots) -> Result<&1, &1, Error, Slots>:
  match m:
    case Some{key}:
      Slots.set(key, x, s)
    case None{}:
      Fail{Unknown{k}}

def Slots.key(p: Bytes.Bytes & Tag, x: Scalar, s: Slots) -> Result<&1, &1, Error, Slots>:
  (k, +t) = p
  Slots.put(Key.find(t), k, x, s)

def collect.put(acc: Result<&1, &1, Error, Slots>, k: Bytes.Bytes, v: Json.Val) -> Result<&1, &1, Error, Slots>:
  match acc:
    case Fail{e}:
      Fail{e}
    case Done{s}:
      Slots.key(Tag.of(k), scalar(v), s)

# Files each field under its key. An unknown or repeated key stops the walk.
def collect(kvs: List<&1, Bytes.Bytes & Json.Val>, acc: Result<&1, &1, Error, Slots>) -> Result<&1, &1, Error, Slots>:
  match kvs:
    case Nil{}:
      acc
    case Con{(k, v), t}:
      collect(t, collect.put(acc, k, v))

def need.num(m: Maybe<&1, Scalar>, k: Key) -> Result<&1, &1, Error, Bytes.Bytes>:
  match m:
    case None{}:
      Fail{Missing{k}}
    case Some{SNum{b}}:
      Done{b}
    case Some{s}:
      Fail{BadField{k}}

def need.flag(m: Maybe<&1, Scalar>, k: Key) -> Result<&1, &1, Error, Bool>:
  match m:
    case None{}:
      Fail{Missing{k}}
    case Some{SFlag{b}}:
      Done{b}
    case Some{s}:
      Fail{BadField{k}}

def need.str(m: Maybe<&1, Scalar>, k: Key) -> Result<&1, &1, Error, Bytes.Bytes>:
  match m:
    case None{}:
      Fail{Missing{k}}
    case Some{SStr{b}}:
      Done{b}
    case Some{s}:
      Fail{BadField{k}}

def opt.str(m: Maybe<&1, Scalar>, k: Key) -> Result<&1, &1, Error, Maybe<&1, Bytes.Bytes>>:
  match m:
    case None{}:
      Done{None{}}
    case Some{SStr{b}}:
      Done{Some{b}}
    case Some{s}:
      Fail{BadField{k}}

# A field that this version does not define.
def unexpected(m: Maybe<&1, Scalar>, k: Key) -> Result<&1, &1, Error, Unit>:
  match m:
    case None{}:
      Done{Unit{}}
    case Some{s}:
      Fail{Unexpected{k}}

def found(-A: Data, m: Maybe<&2, A>, k: Key) -> Result<&1, &1, Error, A>:
  match m:
    case Some{x}:
      Done{x}
    case None{}:
      Fail{BadField{k}}

def name.period(p: Bytes.Bytes & Tag) -> Result<&1, &1, Error, Period>:
  (b, +t) = p
  found(Period, Period.find(t), KPeriod{})

def name.status(p: Bytes.Bytes & Tag) -> Result<&1, &1, Error, Status>:
  (b, +t) = p
  found(Status, Status.find(t), KStatus{})

def need.period(m: Maybe<&1, Scalar>) -> Result<&1, &1, Error, Period>:
  match m:
    case None{}:
      Fail{Missing{KPeriod{}}}
    case Some{SStr{b}}:
      name.period(Tag.of(b))
    case Some{s}:
      Fail{BadField{KPeriod{}}}

# An absent v2 period is monthly.
def opt.period(m: Maybe<&1, Scalar>) -> Result<&1, &1, Error, Period>:
  match m:
    case None{}:
      Done{Monthly{}}
    case Some{SStr{b}}:
      name.period(Tag.of(b))
    case Some{s}:
      Fail{BadField{KPeriod{}}}

def need.status(m: Maybe<&1, Scalar>) -> Result<&1, &1, Error, Status>:
  match m:
    case None{}:
      Fail{Missing{KStatus{}}}
    case Some{SStr{b}}:
      name.status(Tag.of(b))
    case Some{s}:
      Fail{BadField{KStatus{}}}

def V1.finish(mi: Maybe<&2, U32>, p: Bytes.Bytes, mc: Maybe<&2, U32>, a: Bool) -> Result<&1, &1, Error, Record>:
  do Result<&1, &1, Error, Record>:
    id : U32 <- found(U32, mi, KId{})
    cents : U32 <- found(U32, mc, KMonthlyCents{})
    return R1{V1{id, p, cents, a}}

def build.v1(s: Slots) -> Result<&1, &1, Error, Record>:
  Slots{ve, i, p, mc, a, c, pe, st, n} = s
  do Result<&1, &1, Error, Record>:
    u1 : Unit <- unexpected(c, KCents{})
    u2 : Unit <- unexpected(pe, KPeriod{})
    u3 : Unit <- unexpected(st, KStatus{})
    u4 : Unit <- unexpected(n, KNote{})
    id : Bytes.Bytes <- need.num(i, KId{})
    plan : Bytes.Bytes <- need.str(p, KPlan{})
    cents : Bytes.Bytes <- need.num(mc, KMonthlyCents{})
    on : Bool <- need.flag(a, KActive{})
    V1.finish(u32.read(id), plan, u32.read(cents), on)

def V2.finish(mi: Maybe<&2, U32>, p: Bytes.Bytes, mc: Maybe<&2, U32>, pe: Period, s: Status, n: Maybe<&1, Bytes.Bytes>) -> Result<&1, &1, Error, Record>:
  do Result<&1, &1, Error, Record>:
    id : U32 <- found(U32, mi, KId{})
    cents : U32 <- found(U32, mc, KCents{})
    return R2{V2{id, p, cents, pe, s, n}}

def build.v2(s: Slots) -> Result<&1, &1, Error, Record>:
  Slots{ve, i, p, mc, a, c, pe, st, n} = s
  do Result<&1, &1, Error, Record>:
    u1 : Unit <- unexpected(mc, KMonthlyCents{})
    u2 : Unit <- unexpected(a, KActive{})
    id : Bytes.Bytes <- need.num(i, KId{})
    plan : Bytes.Bytes <- need.str(p, KPlan{})
    cents : Bytes.Bytes <- need.num(c, KCents{})
    period : Period <- opt.period(pe)
    status : Status <- need.status(st)
    note : Maybe<&1, Bytes.Bytes> <- opt.str(n, KNote{})
    V2.finish(u32.read(id), plan, u32.read(cents), period, status, note)

def V3.finish(mi: Maybe<&2, U32>, p: Bytes.Bytes, mc: Maybe<&2, U32>, pe: Period, s: Status) -> Result<&1, &1, Error, Record>:
  do Result<&1, &1, Error, Record>:
    id : U32 <- found(U32, mi, KId{})
    cents : U32 <- found(U32, mc, KCents{})
    return R3{V3{id, p, cents, pe, s}}

def build.v3(s: Slots) -> Result<&1, &1, Error, Record>:
  Slots{ve, i, p, mc, a, c, pe, st, n} = s
  do Result<&1, &1, Error, Record>:
    u1 : Unit <- unexpected(mc, KMonthlyCents{})
    u2 : Unit <- unexpected(a, KActive{})
    u3 : Unit <- unexpected(n, KNote{})
    id : Bytes.Bytes <- need.num(i, KId{})
    plan : Bytes.Bytes <- need.str(p, KPlan{})
    cents : Bytes.Bytes <- need.num(c, KCents{})
    period : Period <- need.period(pe)
    status : Status <- need.status(st)
    V3.finish(u32.read(id), plan, u32.read(cents), period, status)

def build.at(+v: U32, s: Slots) -> Result<&1, &1, Error, Record>:
  match v:
    case 1:
      build.v1(s)
    case 2:
      build.v2(s)
    case 3:
      build.v3(s)
    case _:
      Fail{Unsupported{v}}

def build.ver(m: Maybe<&2, U32>, s: Slots) -> Result<&1, &1, Error, Record>:
  match m:
    case None{}:
      Fail{BadField{KVersion{}}}
    case Some{v}:
      build.at(v, s)

def build.raw(r: Result<&1, &1, Error, Bytes.Bytes>, s: Slots) -> Result<&1, &1, Error, Record>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      build.ver(u32.read(b), s)

def build(s: Slots) -> Result<&1, &1, Error, Record>:
  Slots{ve, i, p, mc, a, c, pe, st, n} = s
  build.raw(need.num(ve, KVersion{}), Slots{None{}, i, p, mc, a, c, pe, st, n})

# The record an object describes, before the business rules.
def decode.shape(v: Json.Val) -> Result<&1, &1, Error, Record>:
  match v:
    case Json.Obj{kvs}:
      Result.bind(&1, &1, Error, Slots, Record, collect(kvs, Done{Slots.empty()}), build)
    case _:
      Fail{Malformed{}}

def Record.check.if(m: Maybe<&2, Key>, r: Record) -> Result<&1, &1, Error, Record>:
  match m:
    case None{}:
      Done{r}
    case Some{k}:
      Fail{Invalid{k}}

def Record.check.of(p: Record & Maybe<&2, Key>) -> Result<&1, &1, Error, Record>:
  (r, m) = p
  Record.check.if(m, r)

# r when it keeps the business rules.
def Record.check(r: Record) -> Result<&1, &1, Error, Record>:
  Record.check.of(Record.problem(r))

# One record from a parsed JSON value. Only a valid record decodes.
def decode.val(v: Json.Val) -> Result<&1, &1, Error, Record>:
  Result.bind(&1, &1, Error, Record, Record, decode.shape(v), Record.check)

def decode.parsed(m: Maybe<&1, Json.Val>) -> Result<&1, &1, Error, Record>:
  match m:
    case None{}:
      Fail{Malformed{}}
    case Some{v}:
      decode.val(v)

# One record from UTF-8 JSON: an object nested no deeper than one level.
def decode(b: Bytes.Bytes) -> Result<&1, &1, Error, Record>:
  decode.parsed(Json.parse.strict.bytes(b, 1))

# Encode
# ------

def kv(k: Key, v: Json.Val) -> Bytes.Bytes & Json.Val:
  (Key.bytes(k), v)

def num(+n: U32) -> Json.Val:
  Json.Num{u32.text(n)}

def Period.json(p: Period) -> Json.Val:
  Json.Str{Tag.bytes(Period.tag(p))}

def Status.json(s: Status) -> Json.Val:
  Json.Str{Tag.bytes(Status.tag(s))}

def V1.json(r: V1) -> Json.Val:
  V1{+i, p, +c, a} = r
  Json.Obj{[kv(KVersion{}, num(1)), kv(KId{}, num(i)), kv(KPlan{}, Json.Str{p}), kv(KMonthlyCents{}, num(c)), kv(KActive{}, Json.Flag{a})]}

def V2.note(n: Maybe<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes & Json.Val>:
  match n:
    case None{}:
      Nil{}
    case Some{b}:
      [kv(KNote{}, Json.Str{b})]

def V2.json(r: V2) -> Json.Val:
  V2{+i, p, +c, pe, s, n} = r
  Json.Obj{Con{kv(KVersion{}, num(2)), Con{kv(KId{}, num(i)), Con{kv(KPlan{}, Json.Str{p}), Con{kv(KCents{}, num(c)), Con{kv(KPeriod{}, Period.json(pe)), Con{kv(KStatus{}, Status.json(s)), V2.note(n)}}}}}}}

def V3.json(r: V3) -> Json.Val:
  V3{+i, p, +c, pe, s} = r
  Json.Obj{[kv(KVersion{}, num(3)), kv(KId{}, num(i)), kv(KPlan{}, Json.Str{p}), kv(KCents{}, num(c)), kv(KPeriod{}, Period.json(pe)), kv(KStatus{}, Status.json(s))]}

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
