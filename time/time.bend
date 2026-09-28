# Clocks, Duration and Instant, Gregorian dates, RFC 3339 and HTTP-date text, and TZif time zones. Source: https://github.com/paymog/bend-kit/tree/main/time
import Base
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-fmt@0.1.0.0/fmt.bend as Fmt
# bend-kit-bytes@0.3.0.0
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# secs + nanos / 10^9 seconds, with nanos below 10^9: -0.5 s is Duration{-1, 500000000}.
type Duration is Data:
  Duration{secs: Int.I64, nanos: U32}

# A Duration since 1970-01-01T00:00:00Z. Days are 86400 s: there are no leap seconds.
type Instant is Data:
  Instant{secs: Int.I64, nanos: U32}

# A proleptic Gregorian date. The conversions and formats cover years 0 to 9999.
type Date is Data:
  Date{year: U32, month: U32, day: U32}

type DateTime is Data:
  DateTime{date: Date, hour: U32, min: U32, sec: U32, nanos: U32}

def i64(x: U32) -> Int.I64:
  Int.I64.from_u32(x)

# The signed 32-bit value of x, widened.
def i64s(x: U32) -> Int.I64:
  match x:
    case U32{w}:
      Int.I64{Int.Int.sext(64n, 32n, w)}

# hi * 2^32 + lo, as the bits of an I64.
def i64.of(hi: U32, lo: U32) -> Int.I64:
  Int.I64.or(Int.I64.shl(i64(hi), 32n), i64(lo))

# Duration
# --------

def Duration.zero() -> Duration:
  Duration{i64(0), 0}

def Duration.of_secs(s: Int.I64) -> Duration:
  Duration{s, 0}

def Duration.of_ms(+ms: U32) -> Duration:
  Duration{i64((ms / 1000 : U32)), ((ms % 1000 : U32) * 1000000 : U32)}

# Whole milliseconds, rounded down.
def Duration.to_ms(d: Duration) -> Int.I64:
  match d:
    case Duration{s, n}:
      Int.I64.add(Int.I64.mul(s, i64(1000)), i64((n / 1000000 : U32)))

def Duration.carry(c: Bool, s: Int.I64, +n: U32) -> Duration:
  match c:
    case True{}:
      Duration{Int.I64.add(s, i64(1)), (n - 1000000000 : U32)}
    case False{}:
      Duration{s, n}

def Duration.add(a: Duration, b: Duration) -> Duration:
  match a b:
    case Duration{sa, na} Duration{sb, nb}:
      +n = (na + nb : U32)
      Duration.carry(U32.is_ge(n, 1000000000), Int.I64.add(sa, sb), n)

# n is na - nb, wrapped when na < nb.
def Duration.borrow(c: Bool, s: Int.I64, +n: U32) -> Duration:
  match c:
    case True{}:
      Duration{Int.I64.sub(s, i64(1)), (n + 1000000000 : U32)}
    case False{}:
      Duration{s, n}

def Duration.sub(a: Duration, b: Duration) -> Duration:
  match a b:
    case Duration{sa, +na} Duration{sb, +nb}:
      Duration.borrow(U32.is_lt(na, nb), Int.I64.sub(sa, sb), (na - nb : U32))

def Duration.neg(d: Duration) -> Duration:
  Duration.sub(Duration.zero(), d)

def Duration.cmp.then(c: Cmp, +na: U32, +nb: U32) -> Cmp:
  match c:
    case EQ{}:
      U32.cmp(na, nb)
    case LT{}:
      LT{}
    case GT{}:
      GT{}

def Duration.cmp(a: Duration, b: Duration) -> Cmp:
  match a b:
    case Duration{sa, na} Duration{sb, nb}:
      Duration.cmp.then(Int.I64.cmp(sa, sb), na, nb)

# Instant
# -------

def Instant.epoch() -> Instant:
  Instant{i64(0), 0}

def Instant.of_unix(s: Int.I64) -> Instant:
  Instant{s, 0}

def Instant.of(d: Duration) -> Instant:
  match d:
    case Duration{s, n}:
      Instant{s, n}

def Instant.since_epoch(i: Instant) -> Duration:
  match i:
    case Instant{s, n}:
      Duration{s, n}

def Instant.add(i: Instant, d: Duration) -> Instant:
  Instant.of(Duration.add(Instant.since_epoch(i), d))

# a - b.
def Instant.since(a: Instant, b: Instant) -> Duration:
  Duration.sub(Instant.since_epoch(a), Instant.since_epoch(b))

def Instant.cmp(a: Instant, b: Instant) -> Cmp:
  Duration.cmp(Instant.since_epoch(a), Instant.since_epoch(b))

# Clocks
# ------

# (secs hi, secs lo, nanos) of CLOCK_MONOTONIC, from an unspecified start.
def mono.raw() -> IO(U32 & U32 & U32):
  import "./effs/time.c"
  import "./effs/time.js"

# (secs hi, secs lo, nanos) of CLOCK_REALTIME, since the Unix epoch.
def wall.raw() -> IO(U32 & U32 & U32):
  import "./effs/time.c"
  import "./effs/time.js"

def raw.dur(r: U32 & U32 & U32) -> Duration:
  (hi, lo, n) = r
  Duration{i64.of(hi, lo), n}

# Time since an unspecified start that never goes back. Use it to measure spans.
def mono() -> IO(Duration):
  do IO<Duration>:
    r : U32 & U32 & U32 <- mono.raw()
    return raw.dur(r)

# The wall clock. It can jump when the system time is set.
def now() -> IO(Instant):
  do IO<Instant>:
    r : U32 & U32 & U32 <- wall.raw()
    return Instant.of(raw.dur(r))

# Dates
# -----

def Date.is_leap(+y: U32) -> Bool:
  Bool.and(U32.is_eq((y % 4 : U32), 0),
    Bool.or(U32.is_ne((y % 100 : U32), 0), U32.is_eq((y % 400 : U32), 0)))

# 0 for a month outside 1 to 12.
def Date.days_in_month(+y: U32, +m: U32) -> U32:
  Bool.pick(U32, U32.is_eq(m, 2), Bool.pick(U32, Date.is_leap(y), 29, 28),
    Bool.pick(U32, Bool.and(U32.is_ge(m, 1), U32.is_le(m, 12)),
      (30 + ((m + (m >> 3n)) .&. 1) : U32), 0))

def Date.valid(d: Date) -> Bool:
  match d:
    case Date{+y, +m, +dd}:
      Bool.and(U32.is_le(y, 9999),
        Bool.and(U32.is_ge(dd, 1), U32.is_le(dd, Date.days_in_month(y, m))))

# z counts days from -0400-03-01, so every date from year 0 has z > 0 in a U32.
# The civil-days algorithm is Howard Hinnant's, with the year starting in March.
def Z.EPOCH() -> U32:
  865565

def Date.to_z.at(+y: U32, +mp: U32, +d: U32) -> U32:
  +era = (y / 400 : U32)
  +yoe = (y - era * 400 : U32)
  +doy = ((153 * mp + 2) / 5 + d - 1 : U32)
  (era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy : U32)

def Date.to_z.go(jf: Bool, +y: U32, +m: U32, +d: U32) -> U32:
  match jf:
    case True{}:
      Date.to_z.at((y + 399 : U32), (m + 9 : U32), d)
    case False{}:
      Date.to_z.at((y + 400 : U32), (m - 3 : U32), d)

def Date.to_z(d: Date) -> U32:
  match d:
    case Date{+y, +m, +dd}:
      Date.to_z.go(U32.is_le(m, 2), y, m, dd)

def Date.of_z.fin(lo: Bool, +y: U32, +mp: U32, +d: U32) -> Date:
  match lo:
    case True{}:
      Date{(y - 400 : U32), (mp + 3 : U32), d}
    case False{}:
      Date{(y - 399 : U32), (mp - 9 : U32), d}

def Date.of_z(+z: U32) -> Date:
  +era = (z / 146097 : U32)
  +doe = (z - era * 146097 : U32)
  +yoe = ((doe - doe / 1460 + doe / 36524 - doe / 146096) / 365 : U32)
  +doy = (doe - (365 * yoe + yoe / 4 - yoe / 100) : U32)
  +mp = ((5 * doy + 2) / 153 : U32)
  Date.of_z.fin(U32.is_lt(mp, 10), (yoe + era * 400 : U32), mp,
    (doy - (153 * mp + 2) / 5 + 1 : U32))

# Days since 1970-01-01.
def Date.to_days(d: Date) -> Int.I64:
  Int.I64.sub(i64(Date.to_z(d)), i64(Z.EPOCH()))

def Date.of_z.if(ok: Bool, +z: U32) -> Maybe<&2, Date>:
  match ok:
    case True{}:
      Some{Date.of_z(z)}
    case False{}:
      None{}

# The date days after 1970-01-01, or None outside 0000-01-01 to 9999-12-31.
def Date.of_days(days: Int.I64) -> Maybe<&2, Date>:
  +z = Int.I64.add(days, i64(Z.EPOCH()))
  Date.of_z.if(Bool.and(Int.I64.is_ge(z, i64(146037)), Int.I64.is_le(z, i64(3798461))),
    Int.I64.to_u32(z))

# 1 for Monday to 7 for Sunday, as in ISO 8601.
def Date.weekday(d: Date) -> U32:
  ((Date.to_z(d) + 2) % 7 + 1 : U32)

# Date and time
# -------------

def DateTime.valid(t: DateTime) -> Bool:
  match t:
    case DateTime{d, h, mi, s, n}:
      Bool.and(Date.valid(d), Bool.and(U32.is_le(h, 23),
        Bool.and(U32.is_le(mi, 59), Bool.and(U32.is_le(s, 59), U32.is_lt(n, 1000000000)))))

# The instant of a UTC date and time. It does not check t; see DateTime.valid.
def DateTime.to_instant(t: DateTime) -> Instant:
  match t:
    case DateTime{d, h, mi, s, n}:
      Instant{Int.I64.add(Int.I64.mul(Date.to_days(d), i64(86400)),
        i64((h * 3600 + mi * 60 + s : U32))), n}

def DateTime.at(m: Maybe<&2, Date>, +sod: U32, n: U32) -> Maybe<&2, DateTime>:
  match m:
    case None{}:
      None{}
    case Some{d}:
      Some{DateTime{d, (sod / 3600 : U32), (sod / 60 % 60 : U32), (sod % 60 : U32), n}}

# r is secs % 86400, which has the sign of secs.
def DateTime.floor(neg: Bool, q: Int.I64, r: Int.I64, n: U32) -> Maybe<&2, DateTime>:
  match neg:
    case True{}:
      DateTime.at(Date.of_days(Int.I64.sub(q, i64(1))), (Int.I64.to_u32(r) + 86400 : U32), n)
    case False{}:
      DateTime.at(Date.of_days(q), Int.I64.to_u32(r), n)

# The UTC date and time of i, or None outside years 0 to 9999.
def DateTime.of_instant(i: Instant) -> Maybe<&2, DateTime>:
  match i:
    case Instant{+s, n}:
      +r = Int.I64.mod(s, i64(86400))
      DateTime.floor(Int.I64.is_neg(r), Int.I64.div(s, i64(86400)), r, n)

# Text
# ----

def pad(+x: U32, w: Nat) -> String:
  Fmt.Fmt.pad_left(U32.show(x), w, '0')

# Milliseconds with six decimal places.
def Duration.show_ms.pos(d: Duration) -> String:
  match d:
    case Duration{s, +n}:
      Int.I64.show(Duration.to_ms(Duration{s, n})) ++ "." ++ pad((n % 1000000 : U32), 6n)

def Duration.show_ms.sign(neg: Bool, d: Duration) -> String:
  match neg:
    case True{}:
      "-" ++ Duration.show_ms.pos(Duration.neg(d))
    case False{}:
      Duration.show_ms.pos(d)

def Duration.show_ms(d: Duration) -> String:
  match d:
    case Duration{+s, n}:
      Duration.show_ms.sign(Int.I64.is_neg(s), Duration{s, n})

# The digits of n / 10^(9 - w), with trailing zeros cut. n is not 0.
def frac.go(f: Nat, z: Bool, +n: U32, +w: Nat) -> String:
  match f:
    case 0n:
      pad(n, w)
    case 1n+g:
      match z:
        case True{}:
          +m = (n / 10 : U32)
          frac.go(g, U32.is_eq((m % 10 : U32), 0), m, (w - 1n : Nat))
        case False{}:
          pad(n, w)

def frac(+n: U32) -> String:
  Bool.pick(String, U32.is_eq(n, 0), "", SCon{'.', frac.go(8n, U32.is_eq((n % 10 : U32), 0), n, 9n)})

def DateTime.rfc3339(t: DateTime) -> String:
  match t:
    case DateTime{Date{y, mo, d}, h, mi, s, n}:
      String.concat([pad(y, 4n), "-", pad(mo, 2n), "-", pad(d, 2n), "T", pad(h, 2n), ":",
        pad(mi, 2n), ":", pad(s, 2n), frac(n), "Z"])

def fmt.map(~f: DateTime -> String, m: Maybe<&2, DateTime>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{t}:
      Some{f(t)}

# RFC 3339 in UTC, such as 1985-04-12T23:20:50.52Z. The fraction has no trailing zeros, and is left out when 0.
def rfc3339(i: Instant) -> Maybe<&2, String>:
  fmt.map(~DateTime.rfc3339, DateTime.of_instant(i))

def WEEKDAYS() -> List<&2, String>:
  ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

def MONTHS() -> List<&2, String>:
  ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

def name(xs: List<&2, String>, +i: U32) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, U32.to_nat(i)), "")

def DateTime.http_date(t: DateTime) -> String:
  match t:
    case DateTime{+date, h, mi, s, n}:
      Date{y, mo, d} = date
      String.concat([name(WEEKDAYS(), (Date.weekday(date) - 1 : U32)), ", ", pad(d, 2n), " ",
        name(MONTHS(), (mo - 1 : U32)), " ", pad(y, 4n), " ", pad(h, 2n), ":", pad(mi, 2n), ":",
        pad(s, 2n), " GMT"])

# IMF-fixdate (RFC 9110 §5.6.7), such as Sun, 06 Nov 1994 08:49:37 GMT. It drops the fraction of a second.
def http_date(i: Instant) -> Maybe<&2, String>:
  fmt.map(~DateTime.http_date, DateTime.of_instant(i))

# Parsers
# -------

# A parser state: the numbers read so far, newest first, and the text left.
type P is Data:
  P{vals: List<&2, U32>, rest: String}

def is_digit(+c: U32) -> Bool:
  Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57))

def digits.go(n: Nat, s: String, +acc: U32, ok: Bool) -> Maybe<&1, U32 & String>:
  match n:
    case 0n:
      match ok:
        case True{}:
          Some{(acc, s)}
        case False{}:
          None{}
    case 1n+k:
      match s:
        case SNil{}:
          None{}
        case SCon{Chr{+c}, t}:
          digits.go(k, t, (acc * 10 + c - 48 : U32), Bool.and(ok, is_digit(c)))

def push(vs: List<&2, U32>, r: Maybe<&1, U32 & String>) -> Maybe<&2, P>:
  match r:
    case None{}:
      None{}
    case Some{(v, t)}:
      Some{P{Con{v, vs}, t}}

# Exactly n digits.
def num(n: Nat, p: P) -> Maybe<&2, P>:
  match p:
    case P{vs, s}:
      push(vs, digits.go(n, s, 0, True{}))

def lit.if(ok: Bool, vs: List<&2, U32>, t: String) -> Maybe<&2, P>:
  match ok:
    case True{}:
      Some{P{vs, t}}
    case False{}:
      None{}

# One char that is a or b.
def lit2(+a: U32, +b: U32, p: P) -> Maybe<&2, P>:
  match p:
    case P{vs, s}:
      match s:
        case SNil{}:
          None{}
        case SCon{Chr{+c}, t}:
          lit.if(Bool.or(U32.is_eq(c, a), U32.is_eq(c, b)), vs, t)

def lit(+c: U32, p: P) -> Maybe<&2, P>:
  lit2(c, c, p)

def text(+w: String, p: P) -> Maybe<&2, P>:
  match p:
    case P{vs, +s}:
      +n = String.length(w)
      lit.if(String.eq(String.take(s, n), w), vs, String.drop(s, n))

def at.head(+s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      is_digit(c)

# Digits after the first nine are read and dropped. d says whether s starts with a digit.
def secfrac.go(s: String, d: Bool, +mul: U32, +acc: U32, +k: U32) -> U32 & U32 & String:
  match s:
    case SNil{}:
      (k, acc, SNil{})
    case SCon{Chr{+c}, +t}:
      match d:
        case True{}:
          secfrac.go(t, at.head(t), (mul / 10 : U32), (acc + (c - 48) * mul : U32), (k + 1 : U32))
        case False{}:
          (k, acc, SCon{Chr{c}, t})

def secfrac.fin(vs: List<&2, U32>, r: U32 & U32 & String) -> Maybe<&2, P>:
  (k, n, t) = r
  lit.if(U32.is_gt(k, 0), Con{n, vs}, t)

def secfrac.if(dot: Bool, vs: List<&2, U32>, +s: String) -> Maybe<&2, P>:
  match dot:
    case True{}:
      +t = String.drop(s, 1n)
      secfrac.fin(vs, secfrac.go(t, at.head(t), 100000000, 0, 0))
    case False{}:
      Some{P{Con{0, vs}, s}}

# An optional '.' and one or more digits, as nanoseconds.
def secfrac(p: P) -> Maybe<&2, P>:
  match p:
    case P{vs, +s}:
      secfrac.if(String.starts_with(s, "."), vs, s)

def zone.num(+neg: U32, vs: List<&2, U32>, t: String) -> Maybe<&2, P>:
  do Maybe<&2, P>:
    a : P <- num(2n, P{Con{neg, vs}, t})
    b : P <- lit(58, a)
    num(2n, b)

def zone.if(z: Bool, plus: Bool, minus: Bool, vs: List<&2, U32>, t: String) -> Maybe<&2, P>:
  match z:
    case True{}:
      Some{P{Con{0, Con{0, Con{0, vs}}}, t}}
    case False{}:
      match plus:
        case True{}:
          zone.num(0, vs, t)
        case False{}:
          match minus:
            case True{}:
              zone.num(1, vs, t)
            case False{}:
              None{}

# Z, or +hh:mm or -hh:mm, as (sign, hh, mm) with sign 1 for west of UTC.
def zone(p: P) -> Maybe<&2, P>:
  match p:
    case P{vs, s}:
      match s:
        case SNil{}:
          None{}
        case SCon{Chr{+c}, t}:
          zone.if(Bool.or(U32.is_eq(c, 90), U32.is_eq(c, 122)), U32.is_eq(c, 43), U32.is_eq(c, 45), vs, t)

def index.go(xs: List<&2, String>, +w: String, +i: U32) -> U32:
  match xs:
    case Nil{}:
      i
    case Con{x, rest}:
      Bool.pick(U32, String.eq(x, w), i, index.go(rest, w, (i + 1 : U32)))

# One of names, as its index.
def word(+names: List<&2, String>, p: P) -> Maybe<&2, P>:
  match p:
    case P{vs, +s}:
      +i = index.go(names, String.take(s, 3n), 0)
      lit.if(U32.is_lt(i, U32.from_nat(List.length(&2, String, names))), Con{i, vs}, String.drop(s, 3n))

def mk.if(ok: Bool, t: DateTime) -> Maybe<&2, Instant>:
  match ok:
    case True{}:
      Some{DateTime.to_instant(t)}
    case False{}:
      None{}

def mk(+t: DateTime) -> Maybe<&2, Instant>:
  mk.if(DateTime.valid(t), t)

def rfc3339.shift(m: Maybe<&2, Instant>, +west: U32, +hh: U32, +mm: U32) -> Maybe<&2, Instant>:
  match m:
    case None{}:
      None{}
    case Some{i}:
      +off = Duration.of_secs(i64((hh * 3600 + mm * 60 : U32)))
      Bool.pick(Maybe<&2, Instant>, Bool.and(U32.is_le(hh, 23), U32.is_le(mm, 59)),
        Some{Instant.add(i, Bool.pick(Duration, U32.is_eq(west, 1), off, Duration.neg(off)))}, None{})

def rfc3339.fin(p: P) -> Maybe<&2, Instant>:
  match p:
    case P{Con{mm, Con{hh, Con{west, Con{n, Con{s, Con{mi, Con{h, Con{d, Con{mo, Con{y, Nil{}}}}}}}}}}}, SNil{}}:
      rfc3339.shift(mk(DateTime{Date{y, mo, d}, h, mi, s, n}), west, hh, mm)
    case _:
      None{}

# An RFC 3339 date-time (§5.6), such as 1985-04-12T23:20:50.52Z or 1996-12-19T16:39:57-08:00.
# T and Z may be lowercase. A leap second (:60) is refused, as Instant has none.
def rfc3339.parse(s: String) -> Maybe<&2, Instant>:
  do Maybe<&2, Instant>:
    a : P <- num(4n, P{Nil{}, s})
    b : P <- lit(45, a)
    c : P <- num(2n, b)
    d : P <- lit(45, c)
    e : P <- num(2n, d)
    f : P <- lit2(84, 116, e)
    g : P <- num(2n, f)
    h : P <- lit(58, g)
    i : P <- num(2n, h)
    j : P <- lit(58, i)
    k : P <- num(2n, j)
    l : P <- secfrac(k)
    m : P <- zone(l)
    rfc3339.fin(m)

def http_date.fin(p: P) -> Maybe<&2, Instant>:
  match p:
    case P{Con{s, Con{mi, Con{h, Con{y, Con{mo, Con{d, Con{wd, Nil{}}}}}}}}, SNil{}}:
      mk(DateTime{Date{y, (mo + 1 : U32), d}, h, mi, s, 0})
    case _:
      None{}

# An IMF-fixdate (RFC 9110 §5.6.7), such as Sun, 06 Nov 1994 08:49:37 GMT.
# The day name must be one of the seven, but it is not checked against the date.
def http_date.parse(s: String) -> Maybe<&2, Instant>:
  do Maybe<&2, Instant>:
    a : P <- word(WEEKDAYS(), P{Nil{}, s})
    b : P <- text(", ", a)
    c : P <- num(2n, b)
    d : P <- lit(32, c)
    e : P <- word(MONTHS(), d)
    f : P <- lit(32, e)
    g : P <- num(4n, f)
    h : P <- lit(32, g)
    i : P <- num(2n, h)
    j : P <- lit(58, i)
    k : P <- num(2n, j)
    l : P <- lit(58, k)
    m : P <- num(2n, l)
    n : P <- text(" GMT", m)
    http_date.fin(n)

# Time zones
# ----------

# A local time type: seconds east of UTC, whether it is daylight time, and its abbreviation.
type Ttype is Data:
  Ttype{utoff: Int.I64, dst: Bool, abbr: String}

# From at on, local time follows types[idx].
type Trans is Data:
  Trans{at: Int.I64, idx: U32}

# A TZif zone (RFC 8536): transitions in time order, local time types, and the footer TZ string ("" in version 1).
type Zone is Data:
  Zone{trans: List<&2, Trans>, types: List<&2, Ttype>, tz: String}

# n bytes of a byte string, big-endian.
def be(n: Nat, s: String, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+k:
      match s:
        case SNil{}:
          acc
        case SCon{Chr{c}, t}:
          be(k, t, ((acc << 8n) .|. c : U32))

def be32(+s: String, n: Nat) -> U32:
  be(4n, String.drop(s, n), 0)

def u8(+s: String, n: Nat) -> U32:
  be(1n, String.drop(s, n), 0)

def tzif.size(t8: Bool) -> Nat:
  match t8:
    case True{}:
      8n
    case False{}:
      4n

def tzif.time(t8: Bool, +s: String) -> Int.I64:
  match t8:
    case True{}:
      i64.of(be32(s, 0n), be32(s, 4n))
    case False{}:
      i64s(be32(s, 0n))

# ts holds the transition times and ks their type indexes.
def tzif.trans(n: Nat, +t8: Bool, +ts: String, +ks: String) -> List<&2, Trans>:
  match n:
    case 0n:
      Nil{}
    case 1n+k:
      Con{Trans{tzif.time(t8, ts), u8(ks, 0n)},
        tzif.trans(k, t8, String.drop(ts, tzif.size(t8)), String.drop(ks, 1n))}

# The NUL-terminated abbreviation at byte i of chars.
def tzif.abbr(chars: String, +i: U32) -> String:
  name(String.split(String.drop(chars, U32.to_nat(i)), Chr{0}), 0)

def tzif.types(n: Nat, +s: String, +chars: String) -> List<&2, Ttype>:
  match n:
    case 0n:
      Nil{}
    case 1n+k:
      Con{Ttype{i64s(be32(s, 0n)), U32.is_ne(u8(s, 4n), 0), tzif.abbr(chars, u8(s, 5n))},
        tzif.types(k, String.drop(s, 6n), chars)}

def tzif.if(ok: Bool, z: Zone) -> Maybe<&2, Zone>:
  match ok:
    case True{}:
      Some{z}
    case False{}:
      None{}

# Header counts, in RFC 8536 order: isut, isstd, leap, time, type, char.
def tzif.count(+h: String, i: Nat) -> Nat:
  U32.to_nat(be32(h, (20n + 4n * i : Nat)))

# The data block's size in bytes, for header h.
def tzif.bsize(+t8: Bool, +h: String) -> Nat:
  +tc = tzif.count(h, 3n)
  (tc * tzif.size(t8) + tc + tzif.count(h, 4n) * 6n + tzif.count(h, 5n) +
    tzif.count(h, 2n) * (tzif.size(t8) + 4n) + tzif.count(h, 1n) + tzif.count(h, 0n) : Nat)

# h starts at a header; its data block follows it. Version 2+ blocks have 8-byte times and a footer.
def tzif.block(+t8: Bool, +h: String) -> Maybe<&2, Zone>:
  +d = String.drop(h, 44n)
  +tc = tzif.count(h, 3n)
  +ty = tzif.count(h, 4n)
  +at = (tc * tzif.size(t8) + tc : Nat)
  +foot = String.drop(d, tzif.bsize(t8, h))
  tzif.if(Bool.and(String.starts_with(h, "TZif"), Bool.and(Nat.is_gt(ty, 0n),
      Nat.is_le((44n + tzif.bsize(t8, h) : Nat), String.length(h)))),
    Zone{tzif.trans(tc, t8, d, String.drop(d, (tc * tzif.size(t8) : Nat))),
      tzif.types(ty, String.drop(d, at), String.take(String.drop(d, (at + ty * 6n : Nat)), tzif.count(h, 5n))),
      Bool.pick(String, t8, name(String.split(foot, '\n'), 1), "")})

def tzif.go(v2: Bool, +s: String) -> Maybe<&2, Zone>:
  match v2:
    case True{}:
      tzif.block(True{}, String.drop(s, (44n + tzif.bsize(False{}, s) : Nat)))
    case False{}:
      tzif.block(False{}, s)

# A TZif file, such as one from /usr/share/zoneinfo. Versions 2 and up use their 64-bit block.
# ponytail: reads the bytes as a byte String; walk Bytes directly if zone files get big.
def tzif.parse(b: Bytes.Bytes) -> Maybe<&2, Zone>:
  +s = Bytes.to_string(b)
  tzif.go(U32.is_ge(u8(s, 4n), 50), s)

# POSIX TZ offsets are seconds west of UTC; transition times are seconds from local midnight.
type TzField is Data:
  TzField{value: U32, rest: String}

type TzText is Data:
  TzText{value: String, rest: String}

type TzClock is Data:
  TzClock{value: Int.I64, rest: String}

type TzDay is Data:
  Julian{day: U32}
  Ordinal{day: U32}
  MonthWeek{month: U32, week: U32, weekday: U32}

type TzDate is Data:
  TzDate{day: TzDay, seconds: Int.I64}

type TzDayPart is Data:
  TzDayPart{day: TzDay, rest: String}

type TzDatePart is Data:
  TzDatePart{date: TzDate, rest: String}

type TzRule is Data:
  TzRule{std: Ttype, daylight: Ttype, start: TzDate, end: TzDate}

def tz.digit(+c: U32) -> Bool:
  Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57))

def tz.alpha(+c: U32) -> Bool:
  Bool.or(Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90)),
    Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)))

def tz.quoted(+c: U32) -> Bool:
  Bool.or(tz.alpha(c), Bool.or(tz.digit(c), Bool.or(U32.is_eq(c, 43), U32.is_eq(c, 45))))

def tz.number.stop(seen: Bool, acc: U32, s: String) -> Maybe<&2, TzField>:
  match seen:
    case True{}:
      Some{TzField{acc, s}}
    case False{}:
      None{}

def tz.number.step(digit: Bool, c: U32, t: String, acc: U32, seen: Bool, next: Unit -> Maybe<&2, TzField>) -> Maybe<&2, TzField>:
  match digit:
    case True{}:
      next(Unit{})
    case False{}:
      tz.number.stop(seen, acc, SCon{Chr{c}, t})

# Three digits suffice for POSIX hour, day, and month fields.
def tz.number.go(s: String, +acc: U32, +seen: Bool) -> Maybe<&2, TzField>:
  match s:
    case SNil{}:
      tz.number.stop(seen, acc, SNil{})
    case SCon{Chr{+c}, +t}:
      tz.number.step(Bool.and(tz.digit(c), U32.is_lt(acc, 100)),
        c, t, acc, seen, _ => tz.number.go(t, ((acc * 10 + c - 48) : U32), True{}))

def tz.number(s: String) -> Maybe<&2, TzField>:
  tz.number.go(s, 0, False{})

def tz.name.valid(ok: Bool, name: String, rest: String) -> Maybe<&2, TzText>:
  match ok:
    case True{}:
      Some{TzText{name, rest}}
    case False{}:
      None{}

def tz.name.done(rev: String, rest: String) -> Maybe<&2, TzText>:
  +name = String.reverse(rev)
  tz.name.valid(Nat.is_ge(String.length(name), 3n), name, rest)

def tz.name.empty(quoted: Bool, rev: String) -> Maybe<&2, TzText>:
  match quoted:
    case True{}:
      None{}
    case False{}:
      tz.name.done(rev, SNil{})

def tz.name.branch(continue: Bool, rev: String, c: U32, rest: String, next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  match continue:
    case True{}:
      next(Unit{})
    case False{}:
      tz.name.done(rev, SCon{Chr{c}, rest})

def tz.name.allowed(ok: Bool, next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  match ok:
    case True{}:
      next(Unit{})
    case False{}:
      None{}

def tz.name.quoted(end: Bool, valid: Bool, rev: String, rest: String, next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  match end:
    case True{}:
      tz.name.done(rev, rest)
    case False{}:
      tz.name.allowed(valid, next)

def tz.name.char(quoted: Bool, end: Bool, alpha: Bool, valid: Bool, rev: String, c: U32, rest: String,
  next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  match quoted:
    case True{}:
      tz.name.quoted(end, valid, rev, rest, next)
    case False{}:
      tz.name.branch(alpha, rev, c, rest, next)

def tz.name.go(s: String, +rev: String, +quoted: Bool) -> Maybe<&2, TzText>:
  match s:
    case SNil{}:
      tz.name.empty(quoted, rev)
    case SCon{Chr{+c}, +t}:
      tz.name.char(quoted, U32.is_eq(c, 62), tz.alpha(c), tz.quoted(c), rev, c, t,
        _ => tz.name.go(t, SCon{Chr{c}, rev}, quoted))

def tz.name(s: String) -> Maybe<&2, TzText>:
  match s:
    case SCon{Chr{60}, t}:
      tz.name.go(t, SNil{}, True{})
    case _:
      tz.name.go(s, SNil{}, False{})

def tz.field.valid(ok: Bool, n: U32, rest: String) -> Maybe<&2, TzField>:
  match ok:
    case True{}:
      Some{TzField{n, rest}}
    case False{}:
      None{}

def tz.clock.tail(r: TzField, limit: U32) -> Maybe<&2, TzField>:
  match r:
    case TzField{+n, rest}:
      tz.field.valid(U32.is_le(n, limit), n, rest)

def tz.clock.part(s: String) -> Maybe<&2, TzField>:
  match s:
    case SCon{Chr{58}, t}:
      do Maybe<&2, TzField>:
        n : TzField <- tz.number(t)
        tz.clock.tail(n, 59)
    case _:
      Some{TzField{0, s}}

def tz.clock.valid(ok: Bool, +value: Int.I64, negative: Bool, rest: String) -> Maybe<&2, TzClock>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{TzClock{Bool.pick(Int.I64, negative, Int.I64.neg(value), value), rest}}

def tz.clock.seconds(sec: TzField, +hours: U32, +minutes: U32, +max: U32, negative: Bool) -> Maybe<&2, TzClock>:
  match sec:
    case TzField{+seconds, rest}:
      tz.clock.valid(U32.is_le(hours, max),
        i64((hours * 3600 + minutes * 60 + seconds : U32)), negative, rest)

def tz.clock.minutes(m: TzField, +hours: U32, +max: U32, +negative: Bool) -> Maybe<&2, TzClock>:
  match m:
    case TzField{+minutes, rest}:
      do Maybe<&2, TzClock>:
        sec : TzField <- tz.clock.part(rest)
        tz.clock.seconds(sec, hours, minutes, max, negative)
def tz.clock.finish(h: TzField, +max: U32, +negative: Bool) -> Maybe<&2, TzClock>:
  match h:
    case TzField{+hours, rest}:
      do Maybe<&2, TzClock>:
        m : TzField <- tz.clock.part(rest)
        tz.clock.minutes(m, hours, max, negative)


def tz.clock.read(s: String, max: U32, negative: Bool) -> Maybe<&2, TzClock>:
  do Maybe<&2, TzClock>:
    h : TzField <- tz.number(s)
    tz.clock.finish(h, max, negative)
def tz.clock.sign(s: String, max: U32) -> Maybe<&2, TzClock>:
  match s:
    case SCon{Chr{45}, t}:
      tz.clock.read(t, max, True{})
    case SCon{Chr{43}, t}:
      tz.clock.read(t, max, False{})
    case _:
      tz.clock.read(s, max, False{})


def tz.day.valid(ok: Bool, d: TzDay, rest: String) -> Maybe<&2, TzDayPart>:
  match ok:
    case True{}:
      Some{TzDayPart{d, rest}}
    case False{}:
      None{}

def tz.day.j(r: TzField) -> Maybe<&2, TzDayPart>:
  match r:
    case TzField{+n, rest}:
      tz.day.valid(Bool.and(U32.is_ge(n, 1), U32.is_le(n, 365)), Julian{n}, rest)

def tz.day.n(r: TzField) -> Maybe<&2, TzDayPart>:
  match r:
    case TzField{+n, rest}:
      tz.day.valid(U32.is_le(n, 365), Ordinal{n}, rest)

def tz.after(c: Char, s: String) -> String:
  match s:
    case SCon{h, t}:
      Bool.pick(String, Char.is_eq(h, c), t, SNil{})
    case SNil{}:
      SNil{}

def tz.day.weekday(c: TzField, +month: U32, +week: U32) -> Maybe<&2, TzDayPart>:
  match c:
    case TzField{+weekday, rest}:
      tz.day.valid(Bool.and(U32.is_ge(month, 1), Bool.and(U32.is_le(month, 12),
        Bool.and(U32.is_ge(week, 1), Bool.and(U32.is_le(week, 5), U32.is_le(weekday, 6))))),
        MonthWeek{month, week, weekday}, rest)

def tz.day.week(b: TzField, month: U32) -> Maybe<&2, TzDayPart>:
  match b:
    case TzField{week, rest}:
      do Maybe<&2, TzDayPart>:
        c : TzField <- tz.number(tz.after('.', rest))
        tz.day.weekday(c, month, week)

def tz.day.month(a: TzField) -> Maybe<&2, TzDayPart>:
  match a:
    case TzField{month, rest}:
      do Maybe<&2, TzDayPart>:
        b : TzField <- tz.number(tz.after('.', rest))
        tz.day.week(b, month)

def tz.day.m(s: String) -> Maybe<&2, TzDayPart>:
  do Maybe<&2, TzDayPart>:
    a : TzField <- tz.number(s)
    tz.day.month(a)

def tz.day(s: String) -> Maybe<&2, TzDayPart>:
  match s:
    case SCon{Chr{74}, t}:
      do Maybe<&2, TzDayPart>:
        n : TzField <- tz.number(t)
        tz.day.j(n)
    case SCon{Chr{77}, t}:
      tz.day.m(t)
    case _:
      do Maybe<&2, TzDayPart>:
        n : TzField <- tz.number(s)
        tz.day.n(n)

def tz.date.clock(d: TzDay, r: TzClock) -> Maybe<&2, TzDatePart>:
  match r:
    case TzClock{secs, end}:
      Some{TzDatePart{TzDate{d, secs}, end}}

def tz.date.time(d: TzDay, rest: String) -> Maybe<&2, TzDatePart>:
  match rest:
    case SCon{Chr{47}, t}:
      do Maybe<&2, TzDatePart>:
        r : TzClock <- tz.clock.sign(t, 167)
        tz.date.clock(d, r)
    case _:
      Some{TzDatePart{TzDate{d, i64(7200)}, rest}}

def tz.date.part(r: TzDayPart) -> Maybe<&2, TzDatePart>:
  match r:
    case TzDayPart{d, rest}:
      tz.date.time(d, rest)

def tz.date(s: String) -> Maybe<&2, TzDatePart>:
  do Maybe<&2, TzDatePart>:
    r : TzDayPart <- tz.day(s)
    tz.date.part(r)

def tz.rule.end(ok: Bool, standard: Ttype, daylight: Ttype, start: TzDate, end: TzDate) -> Maybe<&2, TzRule>:
  match ok:
    case True{}:
      Some{TzRule{standard, daylight, start, end}}
    case False{}:
      None{}

def tz.rule.finish(b: TzDatePart, standard: Ttype, daylight: Ttype, start: TzDate) -> Maybe<&2, TzRule>:
  match b:
    case TzDatePart{end, rest}:
      tz.rule.end(String.is_empty(rest), standard, daylight, start, end)

def tz.rule.start(a: TzDatePart, +standard: Ttype, +daylight: Ttype) -> Maybe<&2, TzRule>:
  match a:
    case TzDatePart{start, rest}:
      do Maybe<&2, TzRule>:
        b : TzDatePart <- tz.date(tz.after(',', rest))
        tz.rule.finish(b, standard, daylight, start)

def tz.rule.dates(+standard: Ttype, +daylight: Ttype, rest: String) -> Maybe<&2, TzRule>:
  do Maybe<&2, TzRule>:
    a : TzDatePart <- tz.date(tz.after(',', rest))
    tz.rule.start(a, standard, daylight)

def tz.rule.dstclock(r: TzClock, standard: Ttype, abbr: String) -> Maybe<&2, TzRule>:
  match r:
    case TzClock{west, rest}:
      tz.rule.dates(standard, Ttype{Int.I64.neg(west), True{}, abbr}, rest)

def tz.rule.offset(standard: Ttype, abbr: String, west: Int.I64, rest: String) -> Maybe<&2, TzRule>:
  match rest:
    case SCon{Chr{44}, t}:
      tz.rule.dates(standard, Ttype{Int.I64.sub(i64(3600), west), True{}, abbr}, rest)
    # POSIX leaves absent DST dates to the implementation; use the common US rules.
    case SNil{}:
      tz.rule.end(True{}, standard, Ttype{Int.I64.sub(i64(3600), west), True{}, abbr},
        TzDate{MonthWeek{3, 2, 0}, i64(7200)}, TzDate{MonthWeek{11, 1, 0}, i64(7200)})
    case _:
      do Maybe<&2, TzRule>:
        r : TzClock <- tz.clock.sign(rest, 24)
        tz.rule.dstclock(r, standard, abbr)

def tz.rule.named(name: TzText, standard: Ttype, west: Int.I64) -> Maybe<&2, TzRule>:
  match name:
    case TzText{abbr, rest}:
      tz.rule.offset(standard, abbr, west, rest)

def tz.rule.dst(+standard: Ttype, west: Int.I64, rest: String) -> Maybe<&2, TzRule>:
  match rest:
    case SNil{}:
      Some{TzRule{standard, standard, TzDate{Ordinal{0}, i64(0)}, TzDate{Ordinal{0}, i64(0)}}}
    case _:
      do Maybe<&2, TzRule>:
        name : TzText <- tz.name(rest)
        tz.rule.named(name, standard, west)

def tz.rule.stdclock(offset: TzClock, abbr: String) -> Maybe<&2, TzRule>:
  match offset:
    case TzClock{+west, rest}:
      tz.rule.dst(Ttype{Int.I64.neg(west), False{}, abbr}, west, rest)

def tz.rule.standard(name: TzText) -> Maybe<&2, TzRule>:
  match name:
    case TzText{abbr, rest}:
      do Maybe<&2, TzRule>:
        offset : TzClock <- tz.clock.sign(rest, 24)
        tz.rule.stdclock(offset, abbr)

def tz.rule(s: String) -> Maybe<&2, TzRule>:
  do Maybe<&2, TzRule>:
    name : TzText <- tz.name(s)
    tz.rule.standard(name)

# The day number of a rule in year y, relative to January 1.
def tz.day.index(d: TzDay, +y: U32) -> U32:
  match d:
    case Julian{+n}:
      (n - 1 + Bool.pick(U32, Bool.and(Date.is_leap(y), U32.is_ge(n, 60)), 1, 0) : U32)
    case Ordinal{n}:
      n
    case MonthWeek{+month, +week, +weekday}:
      +first_day = (Date.weekday(Date{y, month, 1}) % 7 : U32)
      +day = (1 + ((weekday + 7 - first_day) % 7) + (week - 1) * 7 : U32)
      +last = Date.days_in_month(y, month)
      +actual = Bool.pick(U32, U32.is_gt(day, last), (day - 7 : U32), day)
      Int.I64.to_u32(Int.I64.sub(Date.to_days(Date{y, month, actual}), Date.to_days(Date{y, 1, 1})))

def tz.date.utc(d: TzDate, +y: U32, west: Int.I64) -> Int.I64:
  match d:
    case TzDate{day, sec}:
      Int.I64.add(Int.I64.mul(Int.I64.add(Date.to_days(Date{y, 1, 1}), i64(tz.day.index(day, y))), i64(86400)),
        Int.I64.add(sec, west))

# Apply the two transitions for the UTC year and its neighbors. A /time may cross a year boundary.
type TzEvent is Data:
  TzEvent{when: Int.I64, dst: Bool}

def tz.event.select(newer: Bool, old: Maybe<&2, TzEvent>, when: Int.I64, dst: Bool) -> Maybe<&2, TzEvent>:
  match newer:
    case True{}:
      Some{TzEvent{when, dst}}
    case False{}:
      old

def tz.event.new(+now: Int.I64, old: Maybe<&2, TzEvent>, +when: Int.I64, dst: Bool) -> Maybe<&2, TzEvent>:
  match old:
    case None{}:
      tz.event.select(Int.I64.is_le(when, now), None{}, when, dst)
    case Some{TzEvent{+prev, flag}}:
      tz.event.select(Bool.and(Int.I64.is_le(when, now), Int.I64.is_gt(when, prev)),
        Some{TzEvent{prev, flag}}, when, dst)

def tz.event.year(+now: Int.I64, old: Maybe<&2, TzEvent>, +r: TzRule, +y: U32) -> Maybe<&2, TzEvent>:
  match r:
    case TzRule{Ttype{+off, _, _}, Ttype{+dstoff, _, _}, +start, +end}:
      +first = tz.event.new(now, old, tz.date.utc(start, y, Int.I64.neg(off)), True{})
      tz.event.new(now, first, tz.date.utc(end, y, Int.I64.neg(dstoff)), False{})

def tz.event.prev(+now: Int.I64, old: Maybe<&2, TzEvent>, +r: TzRule, +y: U32) -> Maybe<&2, TzEvent>:
  match y:
    case 0:
      old
    case _:
      tz.event.year(now, old, r, (y - 1 : U32))

def tz.event.next.if(valid: Bool, now: Int.I64, old: Maybe<&2, TzEvent>, r: TzRule, y: U32) -> Maybe<&2, TzEvent>:
  match valid:
    case True{}:
      tz.event.year(now, old, r, (y + 1 : U32))
    case False{}:
      old
def tz.event.next(+now: Int.I64, old: Maybe<&2, TzEvent>, +r: TzRule, +y: U32) -> Maybe<&2, TzEvent>:
  tz.event.next.if(U32.is_lt(y, 9999), now, old, r, y)


def tz.event.type(ev: Maybe<&2, TzEvent>, +r: TzRule) -> Ttype:
  match ev:
    case Some{TzEvent{when, dst}}:
      match r:
        case TzRule{standard, daylight, start, end}:
          Bool.pick(Ttype, dst, daylight, standard)
    case None{}:
      match r:
        case TzRule{standard, daylight, start, end}:
          standard

def tz.rule.at(+r: TzRule, +secs: Int.I64, +year: U32) -> Ttype:
  +a = tz.event.prev(secs, None{}, r, year)
  +b = tz.event.year(secs, a, r, year)
  tz.event.type(tz.event.next(secs, b, r, year), r)

def tz.rule.date(d: Maybe<&2, DateTime>, r: TzRule, secs: Int.I64) -> Maybe<&2, Ttype>:
  match d:
    case None{}:
      None{}
    case Some{DateTime{Date{y, m, day}, h, mi, second, nanos}}:
      Some{tz.rule.at(r, secs, y)}

def tz.rule.lookup(rule: Maybe<&2, TzRule>, +secs: Int.I64) -> Maybe<&2, Ttype>:
  match rule:
    case None{}:
      None{}
    case Some{r}:
      tz.rule.date(DateTime.of_instant(Instant.of_unix(secs)), r, secs)

# The type index at secs: the last transition at or before it, or type 0 before the first.
# ponytail: linear scan; bisect an Array if lookups get hot.
def Zone.find(ts: List<&2, Trans>, +secs: Int.I64, +cur: U32) -> U32:
  match ts:
    case Nil{}:
      cur
    case Con{Trans{t, k}, rest}:
      Zone.find(rest, secs, Bool.pick(U32, Int.I64.is_le(t, secs), k, cur))
def Zone.last.go(ts: List<&2, Trans>, +secs: Int.I64, +last: Int.I64) -> Bool:
  match ts:
    case Nil{}:
      Int.I64.is_gt(secs, last)
    case Con{Trans{t, k}, rest}:
      Zone.last.go(rest, secs, t)
def Zone.last(ts: List<&2, Trans>, secs: Int.I64) -> Bool:
  match ts:
    case Nil{}:
      True{}
    case Con{Trans{t, k}, rest}:
      Zone.last.go(rest, secs, t)


def Zone.at.fallback(m: Maybe<&2, Ttype>, types: List<&2, Ttype>, ts: List<&2, Trans>, secs: Int.I64) -> Maybe<&2, Ttype>:
  match m:
    case Some{t}:
      Some{t}
    case None{}:
      List.get(&2, Ttype, types, U32.to_nat(Zone.find(ts, secs, 0)))
def Zone.at.footer(use: Bool, tz: String, types: List<&2, Ttype>, ts: List<&2, Trans>, +secs: Int.I64) -> Maybe<&2, Ttype>:
  match use:
    case False{}:
      List.get(&2, Ttype, types, U32.to_nat(Zone.find(ts, secs, 0)))
    case True{}:
      Zone.at.fallback(tz.rule.lookup(tz.rule(tz), secs), types, ts, secs)

def Zone.at.tz(empty: Bool, tz: String, types: List<&2, Ttype>, +ts: List<&2, Trans>, +secs: Int.I64) -> Maybe<&2, Ttype>:
  match empty:
    case True{}:
      List.get(&2, Ttype, types, U32.to_nat(Zone.find(ts, secs, 0)))
    case False{}:
      Zone.at.footer(Zone.last(ts, secs), tz, types, ts, secs)



# The local time type at i. The footer applies strictly after the final explicit transition.
def Zone.at(z: Zone, i: Instant) -> Maybe<&2, Ttype>:
  match z i:
    case Zone{ts, types, +tz} Instant{s, n}:
      Zone.at.tz(String.eq(tz, ""), tz, types, ts, s)

def Zone.local.at(m: Maybe<&2, Ttype>, i: Instant) -> Maybe<&2, DateTime>:
  match m:
    case None{}:
      None{}
    case Some{Ttype{off, dst, abbr}}:
      DateTime.of_instant(Instant.add(i, Duration.of_secs(off)))

# The local date and time at i in zone z.
def Zone.local(z: Zone, +i: Instant) -> Maybe<&2, DateTime>:
  Zone.local.at(Zone.at(z, i), i)
