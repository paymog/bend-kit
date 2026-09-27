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

# The type index at secs: the last transition at or before it, or type 0 before the first.
# ponytail: linear scan; bisect an Array if lookups get hot.
def Zone.find(ts: List<&2, Trans>, +secs: Int.I64, +cur: U32) -> U32:
  match ts:
    case Nil{}:
      cur
    case Con{Trans{t, k}, rest}:
      Zone.find(rest, secs, Bool.pick(U32, Int.I64.is_le(t, secs), k, cur))

# The local time type at i.
# ponytail: past the last transition the last type holds; evaluate the footer TZ rule for slim files and years past 2037.
def Zone.at(z: Zone, i: Instant) -> Maybe<&2, Ttype>:
  match z i:
    case Zone{ts, types, tz} Instant{s, n}:
      List.get(&2, Ttype, types, U32.to_nat(Zone.find(ts, s, 0)))

def Zone.local.at(m: Maybe<&2, Ttype>, i: Instant) -> Maybe<&2, DateTime>:
  match m:
    case None{}:
      None{}
    case Some{Ttype{off, dst, abbr}}:
      DateTime.of_instant(Instant.add(i, Duration.of_secs(off)))

# The local date and time at i in zone z.
def Zone.local(z: Zone, +i: Instant) -> Maybe<&2, DateTime>:
  Zone.local.at(Zone.at(z, i), i)
