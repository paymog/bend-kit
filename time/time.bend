# Clocks, Duration and Instant, Gregorian dates, RFC 3339 and HTTP-date text, and TZif time zones. Source: https://github.com/paymog/bend-kit/tree/main/time
import Base
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

import ./pure.bend as Pure

type Duration is Data:
  Duration{secs: Int.I64, nanos: U32}

type Instant is Data:
  Instant{secs: Int.I64, nanos: U32}

type Date is Data:
  Date{year: U32, month: U32, day: U32}

type DateTime is Data:
  DateTime{date: Date, hour: U32, min: U32, sec: U32, nanos: U32}

type P is Data:
  P{vals: List<&2, U32>, rest: String}

type Ttype is Data:
  Ttype{utoff: Int.I64, dst: Bool, abbr: String}

type Trans is Data:
  Trans{at: Int.I64, idx: U32}

type Zone is Data:
  Zone{trans: List<&2, Trans>, types: List<&2, Ttype>, tz: String}

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

type TzEvent is Data:
  TzEvent{when: Int.I64, dst: Bool}

def trans.to.pure(v: Trans) -> Pure.Trans:
  match v:
    case Trans{x0, x1}:
      Pure.Trans{x0, x1}

def trans.list.to.pure(v: List<&2, Trans>) -> List<&2, Pure.Trans>:
  match v:
    case Nil{}:
      Nil{}
    case Con{h, rest}:
      Con{trans.to.pure(h), trans.list.to.pure(rest)}

def ttype.to.pure(v: Ttype) -> Pure.Ttype:
  match v:
    case Ttype{x0, x1, x2}:
      Pure.Ttype{x0, x1, x2}

def ttype.list.to.pure(v: List<&2, Ttype>) -> List<&2, Pure.Ttype>:
  match v:
    case Nil{}:
      Nil{}
    case Con{h, rest}:
      Con{ttype.to.pure(h), ttype.list.to.pure(rest)}

def trans.from.pure(v: Pure.Trans) -> Trans:
  match v:
    case Pure.Trans{x0, x1}:
      Trans{x0, x1}

def trans.list.from.pure(v: List<&2, Pure.Trans>) -> List<&2, Trans>:
  match v:
    case Nil{}:
      Nil{}
    case Con{h, rest}:
      Con{trans.from.pure(h), trans.list.from.pure(rest)}

def ttype.from.pure(v: Pure.Ttype) -> Ttype:
  match v:
    case Pure.Ttype{x0, x1, x2}:
      Ttype{x0, x1, x2}

def ttype.list.from.pure(v: List<&2, Pure.Ttype>) -> List<&2, Ttype>:
  match v:
    case Nil{}:
      Nil{}
    case Con{h, rest}:
      Con{ttype.from.pure(h), ttype.list.from.pure(rest)}

def date.from.pure(v: Pure.Date) -> Date:
  match v:
    case Pure.Date{x0, x1, x2}:
      Date{x0, x1, x2}

def date.maybe.from.pure(v: Maybe<&2, Pure.Date>) -> Maybe<&2, Date>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{date.from.pure(h)}

def date.to.pure(v: Date) -> Pure.Date:
  match v:
    case Date{x0, x1, x2}:
      Pure.Date{x0, x1, x2}

def date.maybe.to.pure(v: Maybe<&2, Date>) -> Maybe<&2, Pure.Date>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{date.to.pure(h)}

def datetime.from.pure(v: Pure.DateTime) -> DateTime:
  match v:
    case Pure.DateTime{x0, x1, x2, x3, x4}:
      DateTime{date.from.pure(x0), x1, x2, x3, x4}

def datetime.maybe.from.pure(v: Maybe<&2, Pure.DateTime>) -> Maybe<&2, DateTime>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{datetime.from.pure(h)}

def datetime.to.pure(v: DateTime) -> Pure.DateTime:
  match v:
    case DateTime{x0, x1, x2, x3, x4}:
      Pure.DateTime{date.to.pure(x0), x1, x2, x3, x4}

def datetime.maybe.to.pure(v: Maybe<&2, DateTime>) -> Maybe<&2, Pure.DateTime>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{datetime.to.pure(h)}

def p.from.pure(v: Pure.P) -> P:
  match v:
    case Pure.P{x0, x1}:
      P{x0, x1}

def p.maybe.from.pure(v: Maybe<&2, Pure.P>) -> Maybe<&2, P>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{p.from.pure(h)}

def instant.from.pure(v: Pure.Instant) -> Instant:
  match v:
    case Pure.Instant{x0, x1}:
      Instant{x0, x1}

def instant.maybe.from.pure(v: Maybe<&2, Pure.Instant>) -> Maybe<&2, Instant>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{instant.from.pure(h)}

def instant.to.pure(v: Instant) -> Pure.Instant:
  match v:
    case Instant{x0, x1}:
      Pure.Instant{x0, x1}

def instant.maybe.to.pure(v: Maybe<&2, Instant>) -> Maybe<&2, Pure.Instant>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{instant.to.pure(h)}

def zone.from.pure(v: Pure.Zone) -> Zone:
  match v:
    case Pure.Zone{x0, x1, x2}:
      Zone{trans.list.from.pure(x0), ttype.list.from.pure(x1), x2}

def zone.maybe.from.pure(v: Maybe<&2, Pure.Zone>) -> Maybe<&2, Zone>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{zone.from.pure(h)}

def tzfield.from.pure(v: Pure.TzField) -> TzField:
  match v:
    case Pure.TzField{x0, x1}:
      TzField{x0, x1}

def tzfield.maybe.from.pure(v: Maybe<&2, Pure.TzField>) -> Maybe<&2, TzField>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzfield.from.pure(h)}

def tzfield.to.pure(v: TzField) -> Pure.TzField:
  match v:
    case TzField{x0, x1}:
      Pure.TzField{x0, x1}

def tzfield.maybe.to.pure(v: Maybe<&2, TzField>) -> Maybe<&2, Pure.TzField>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzfield.to.pure(h)}

def tztext.from.pure(v: Pure.TzText) -> TzText:
  match v:
    case Pure.TzText{x0, x1}:
      TzText{x0, x1}

def tztext.maybe.from.pure(v: Maybe<&2, Pure.TzText>) -> Maybe<&2, TzText>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tztext.from.pure(h)}

def tztext.to.pure(v: TzText) -> Pure.TzText:
  match v:
    case TzText{x0, x1}:
      Pure.TzText{x0, x1}

def tztext.maybe.to.pure(v: Maybe<&2, TzText>) -> Maybe<&2, Pure.TzText>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tztext.to.pure(h)}

def tzclock.from.pure(v: Pure.TzClock) -> TzClock:
  match v:
    case Pure.TzClock{x0, x1}:
      TzClock{x0, x1}

def tzclock.maybe.from.pure(v: Maybe<&2, Pure.TzClock>) -> Maybe<&2, TzClock>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzclock.from.pure(h)}

def tzday.from.pure(v: Pure.TzDay) -> TzDay:
  match v:
    case Pure.Julian{x0}:
      Julian{x0}
    case Pure.Ordinal{x0}:
      Ordinal{x0}
    case Pure.MonthWeek{x0, x1, x2}:
      MonthWeek{x0, x1, x2}

def tzdaypart.from.pure(v: Pure.TzDayPart) -> TzDayPart:
  match v:
    case Pure.TzDayPart{x0, x1}:
      TzDayPart{tzday.from.pure(x0), x1}

def tzdaypart.maybe.from.pure(v: Maybe<&2, Pure.TzDayPart>) -> Maybe<&2, TzDayPart>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzdaypart.from.pure(h)}

def tzdate.from.pure(v: Pure.TzDate) -> TzDate:
  match v:
    case Pure.TzDate{x0, x1}:
      TzDate{tzday.from.pure(x0), x1}

def tzdatepart.from.pure(v: Pure.TzDatePart) -> TzDatePart:
  match v:
    case Pure.TzDatePart{x0, x1}:
      TzDatePart{tzdate.from.pure(x0), x1}

def tzdatepart.maybe.from.pure(v: Maybe<&2, Pure.TzDatePart>) -> Maybe<&2, TzDatePart>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzdatepart.from.pure(h)}

def tzrule.from.pure(v: Pure.TzRule) -> TzRule:
  match v:
    case Pure.TzRule{x0, x1, x2, x3}:
      TzRule{ttype.from.pure(x0), ttype.from.pure(x1), tzdate.from.pure(x2), tzdate.from.pure(x3)}

def tzrule.maybe.from.pure(v: Maybe<&2, Pure.TzRule>) -> Maybe<&2, TzRule>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzrule.from.pure(h)}

def tzevent.to.pure(v: TzEvent) -> Pure.TzEvent:
  match v:
    case TzEvent{x0, x1}:
      Pure.TzEvent{x0, x1}

def tzevent.maybe.to.pure(v: Maybe<&2, TzEvent>) -> Maybe<&2, Pure.TzEvent>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzevent.to.pure(h)}

def tzevent.from.pure(v: Pure.TzEvent) -> TzEvent:
  match v:
    case Pure.TzEvent{x0, x1}:
      TzEvent{x0, x1}

def tzevent.maybe.from.pure(v: Maybe<&2, Pure.TzEvent>) -> Maybe<&2, TzEvent>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzevent.from.pure(h)}

def ttype.maybe.from.pure(v: Maybe<&2, Pure.Ttype>) -> Maybe<&2, Ttype>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{ttype.from.pure(h)}

def tzday.to.pure(v: TzDay) -> Pure.TzDay:
  match v:
    case Julian{x0}:
      Pure.Julian{x0}
    case Ordinal{x0}:
      Pure.Ordinal{x0}
    case MonthWeek{x0, x1, x2}:
      Pure.MonthWeek{x0, x1, x2}

def tzdate.to.pure(v: TzDate) -> Pure.TzDate:
  match v:
    case TzDate{x0, x1}:
      Pure.TzDate{tzday.to.pure(x0), x1}

def tzrule.to.pure(v: TzRule) -> Pure.TzRule:
  match v:
    case TzRule{x0, x1, x2, x3}:
      Pure.TzRule{ttype.to.pure(x0), ttype.to.pure(x1), tzdate.to.pure(x2), tzdate.to.pure(x3)}

def tzrule.maybe.to.pure(v: Maybe<&2, TzRule>) -> Maybe<&2, Pure.TzRule>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{tzrule.to.pure(h)}

def ttype.maybe.to.pure(v: Maybe<&2, Ttype>) -> Maybe<&2, Pure.Ttype>:
  match v:
    case None{}:
      None{}
    case Some{h}:
      Some{ttype.to.pure(h)}

def duration.to.pure(v: Duration) -> Pure.Duration:
  match v:
    case Duration{x0, x1}:
      Pure.Duration{x0, x1}

def duration.from.pure(v: Pure.Duration) -> Duration:
  match v:
    case Pure.Duration{x0, x1}:
      Duration{x0, x1}

def p.to.pure(v: P) -> Pure.P:
  match v:
    case P{x0, x1}:
      Pure.P{x0, x1}

def zone.to.pure(v: Zone) -> Pure.Zone:
  match v:
    case Zone{x0, x1, x2}:
      Pure.Zone{trans.list.to.pure(x0), ttype.list.to.pure(x1), x2}

def tzclock.to.pure(v: TzClock) -> Pure.TzClock:
  match v:
    case TzClock{x0, x1}:
      Pure.TzClock{x0, x1}

def tzdaypart.to.pure(v: TzDayPart) -> Pure.TzDayPart:
  match v:
    case TzDayPart{x0, x1}:
      Pure.TzDayPart{tzday.to.pure(x0), x1}

def tzdatepart.to.pure(v: TzDatePart) -> Pure.TzDatePart:
  match v:
    case TzDatePart{x0, x1}:
      Pure.TzDatePart{tzdate.to.pure(x0), x1}

def raw.dur(r: U32 & U32 & U32) -> Duration:
  duration.from.pure(Pure.raw.dur(r))

def i64(x: U32) -> Int.I64:
  Pure.i64(x)

def i64s(x: U32) -> Int.I64:
  Pure.i64s(x)

def i64.of(hi: U32, lo: U32) -> Int.I64:
  Pure.i64.of(hi, lo)

def Duration.zero() -> Duration:
  duration.from.pure(Pure.Duration.zero())

def Duration.of_secs(s: Int.I64) -> Duration:
  duration.from.pure(Pure.Duration.of_secs(s))

def Duration.of_ms(+ms: U32) -> Duration:
  duration.from.pure(Pure.Duration.of_ms(ms))

def Duration.to_ms(d: Duration) -> Int.I64:
  Pure.Duration.to_ms(duration.to.pure(d))

def Duration.to_nat.of(m: Maybe<&2, Nat>, +per: Nat, +n: U32) -> Nat:
  Pure.Duration.to_nat.of(m, per, n)

def Duration.to_ms_nat(d: Duration) -> Nat:
  Pure.Duration.to_ms_nat(duration.to.pure(d))

def Duration.to_us_nat(d: Duration) -> Nat:
  Pure.Duration.to_us_nat(duration.to.pure(d))

def Duration.carry(c: Bool, s: Int.I64, +n: U32) -> Duration:
  duration.from.pure(Pure.Duration.carry(c, s, n))

def Duration.add(a: Duration, b: Duration) -> Duration:
  duration.from.pure(Pure.Duration.add(duration.to.pure(a), duration.to.pure(b)))

def Duration.borrow(c: Bool, s: Int.I64, +n: U32) -> Duration:
  duration.from.pure(Pure.Duration.borrow(c, s, n))

def Duration.sub(a: Duration, b: Duration) -> Duration:
  duration.from.pure(Pure.Duration.sub(duration.to.pure(a), duration.to.pure(b)))

def Duration.neg(d: Duration) -> Duration:
  duration.from.pure(Pure.Duration.neg(duration.to.pure(d)))

def Duration.cmp.then(c: Cmp, +na: U32, +nb: U32) -> Cmp:
  Pure.Duration.cmp.then(c, na, nb)

def Duration.cmp(a: Duration, b: Duration) -> Cmp:
  Pure.Duration.cmp(duration.to.pure(a), duration.to.pure(b))

def Instant.epoch() -> Instant:
  instant.from.pure(Pure.Instant.epoch())

def Instant.of_unix(s: Int.I64) -> Instant:
  instant.from.pure(Pure.Instant.of_unix(s))

def Instant.of(d: Duration) -> Instant:
  instant.from.pure(Pure.Instant.of(duration.to.pure(d)))

def Instant.since_epoch(i: Instant) -> Duration:
  duration.from.pure(Pure.Instant.since_epoch(instant.to.pure(i)))

def Instant.add(i: Instant, d: Duration) -> Instant:
  instant.from.pure(Pure.Instant.add(instant.to.pure(i), duration.to.pure(d)))

def Instant.since(a: Instant, b: Instant) -> Duration:
  duration.from.pure(Pure.Instant.since(instant.to.pure(a), instant.to.pure(b)))

def Instant.cmp(a: Instant, b: Instant) -> Cmp:
  Pure.Instant.cmp(instant.to.pure(a), instant.to.pure(b))

def Date.is_leap(+y: U32) -> Bool:
  Pure.Date.is_leap(y)

def Date.days_in_month(+y: U32, +m: U32) -> U32:
  Pure.Date.days_in_month(y, m)

def Date.valid(d: Date) -> Bool:
  Pure.Date.valid(date.to.pure(d))

def Z.EPOCH() -> U32:
  Pure.Z.EPOCH()

def Date.to_z.at(+y: U32, +mp: U32, +d: U32) -> U32:
  Pure.Date.to_z.at(y, mp, d)

def Date.to_z.go(jf: Bool, +y: U32, +m: U32, +d: U32) -> U32:
  Pure.Date.to_z.go(jf, y, m, d)

def Date.to_z(d: Date) -> U32:
  Pure.Date.to_z(date.to.pure(d))

def Date.of_z.fin(lo: Bool, +y: U32, +mp: U32, +d: U32) -> Date:
  date.from.pure(Pure.Date.of_z.fin(lo, y, mp, d))

def Date.of_z(+z: U32) -> Date:
  date.from.pure(Pure.Date.of_z(z))

def Date.to_days(d: Date) -> Int.I64:
  Pure.Date.to_days(date.to.pure(d))

def Date.of_z.if(ok: Bool, +z: U32) -> Maybe<&2, Date>:
  date.maybe.from.pure(Pure.Date.of_z.if(ok, z))

def Date.of_days(days: Int.I64) -> Maybe<&2, Date>:
  date.maybe.from.pure(Pure.Date.of_days(days))

def Date.weekday(d: Date) -> U32:
  Pure.Date.weekday(date.to.pure(d))

def DateTime.valid(t: DateTime) -> Bool:
  Pure.DateTime.valid(datetime.to.pure(t))

def DateTime.to_instant(t: DateTime) -> Instant:
  instant.from.pure(Pure.DateTime.to_instant(datetime.to.pure(t)))

def DateTime.at(m: Maybe<&2, Date>, +sod: U32, n: U32) -> Maybe<&2, DateTime>:
  datetime.maybe.from.pure(Pure.DateTime.at(date.maybe.to.pure(m), sod, n))

def DateTime.floor(neg: Bool, q: Int.I64, r: Int.I64, n: U32) -> Maybe<&2, DateTime>:
  datetime.maybe.from.pure(Pure.DateTime.floor(neg, q, r, n))

def DateTime.of_instant(i: Instant) -> Maybe<&2, DateTime>:
  datetime.maybe.from.pure(Pure.DateTime.of_instant(instant.to.pure(i)))

def pad(+x: U32, w: Nat) -> String:
  Pure.pad(x, w)

def Duration.show_ms.pos(d: Duration) -> String:
  Pure.Duration.show_ms.pos(duration.to.pure(d))

def Duration.show_ms.sign(neg: Bool, d: Duration) -> String:
  Pure.Duration.show_ms.sign(neg, duration.to.pure(d))

def Duration.show_ms(d: Duration) -> String:
  Pure.Duration.show_ms(duration.to.pure(d))

def frac.go(f: Nat, z: Bool, +n: U32, +w: Nat) -> String:
  Pure.frac.go(f, z, n, w)

def frac(+n: U32) -> String:
  Pure.frac(n)

def DateTime.rfc3339(t: DateTime) -> String:
  Pure.DateTime.rfc3339(datetime.to.pure(t))

def fmt.map(~f: DateTime -> String, m: Maybe<&2, DateTime>) -> Maybe<&2, String>:
  Pure.fmt.map(~(v => f(datetime.from.pure(v))), datetime.maybe.to.pure(m))

def rfc3339(i: Instant) -> Maybe<&2, String>:
  Pure.rfc3339(instant.to.pure(i))

def WEEKDAYS() -> List<&2, String>:
  Pure.WEEKDAYS()

def MONTHS() -> List<&2, String>:
  Pure.MONTHS()

def name(xs: List<&2, String>, +i: U32) -> String:
  Pure.name(xs, i)

def DateTime.http_date(t: DateTime) -> String:
  Pure.DateTime.http_date(datetime.to.pure(t))

def http_date(i: Instant) -> Maybe<&2, String>:
  Pure.http_date(instant.to.pure(i))

def is_digit(+c: U32) -> Bool:
  Pure.is_digit(c)

def digits.go(n: Nat, s: String, +acc: U32, ok: Bool) -> Maybe<&1, U32 & String>:
  Pure.digits.go(n, s, acc, ok)

def push(vs: List<&2, U32>, r: Maybe<&1, U32 & String>) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.push(vs, r))

def num(n: Nat, p: P) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.num(n, p.to.pure(p)))

def lit.if(ok: Bool, vs: List<&2, U32>, t: String) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.lit.if(ok, vs, t))

def lit2(+a: U32, +b: U32, p: P) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.lit2(a, b, p.to.pure(p)))

def lit(+c: U32, p: P) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.lit(c, p.to.pure(p)))

def text(+w: String, p: P) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.text(w, p.to.pure(p)))

def at.head(+s: String) -> Bool:
  Pure.at.head(s)

def secfrac.go(s: String, d: Bool, +mul: U32, +acc: U32, +k: U32) -> U32 & U32 & String:
  Pure.secfrac.go(s, d, mul, acc, k)

def secfrac.fin(vs: List<&2, U32>, r: U32 & U32 & String) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.secfrac.fin(vs, r))

def secfrac.if(dot: Bool, vs: List<&2, U32>, +s: String) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.secfrac.if(dot, vs, s))

def secfrac(p: P) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.secfrac(p.to.pure(p)))

def zone.num(+neg: U32, vs: List<&2, U32>, t: String) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.zone.num(neg, vs, t))

def zone.if(z: Bool, plus: Bool, minus: Bool, vs: List<&2, U32>, t: String) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.zone.if(z, plus, minus, vs, t))

def zone(p: P) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.zone(p.to.pure(p)))

def index.go(xs: List<&2, String>, +w: String, +i: U32) -> U32:
  Pure.index.go(xs, w, i)

def word(+names: List<&2, String>, p: P) -> Maybe<&2, P>:
  p.maybe.from.pure(Pure.word(names, p.to.pure(p)))

def mk.if(ok: Bool, t: DateTime) -> Maybe<&2, Instant>:
  instant.maybe.from.pure(Pure.mk.if(ok, datetime.to.pure(t)))

def mk(+t: DateTime) -> Maybe<&2, Instant>:
  instant.maybe.from.pure(Pure.mk(datetime.to.pure(t)))

def rfc3339.shift(m: Maybe<&2, Instant>, +west: U32, +hh: U32, +mm: U32) -> Maybe<&2, Instant>:
  instant.maybe.from.pure(Pure.rfc3339.shift(instant.maybe.to.pure(m), west, hh, mm))

def rfc3339.fin(p: P) -> Maybe<&2, Instant>:
  instant.maybe.from.pure(Pure.rfc3339.fin(p.to.pure(p)))

def rfc3339.parse(s: String) -> Maybe<&2, Instant>:
  instant.maybe.from.pure(Pure.rfc3339.parse(s))

def http_date.fin(p: P) -> Maybe<&2, Instant>:
  instant.maybe.from.pure(Pure.http_date.fin(p.to.pure(p)))

def http_date.parse(s: String) -> Maybe<&2, Instant>:
  instant.maybe.from.pure(Pure.http_date.parse(s))

def be(n: Nat, s: String, +acc: U32) -> U32:
  Pure.be(n, s, acc)

def be32(+s: String, n: Nat) -> U32:
  Pure.be32(s, n)

def u8(+s: String, n: Nat) -> U32:
  Pure.u8(s, n)

def tzif.size(t8: Bool) -> Nat:
  Pure.tzif.size(t8)

def tzif.time(t8: Bool, +s: String) -> Int.I64:
  Pure.tzif.time(t8, s)

def tzif.trans(n: Nat, +t8: Bool, +ts: String, +ks: String) -> List<&2, Trans>:
  trans.list.from.pure(Pure.tzif.trans(n, t8, ts, ks))

def tzif.abbr(chars: String, +i: U32) -> String:
  Pure.tzif.abbr(chars, i)

def tzif.types(n: Nat, +s: String, +chars: String) -> List<&2, Ttype>:
  ttype.list.from.pure(Pure.tzif.types(n, s, chars))

def tzif.if(ok: Bool, z: Zone) -> Maybe<&2, Zone>:
  zone.maybe.from.pure(Pure.tzif.if(ok, zone.to.pure(z)))

def tzif.count(+h: String, i: Nat) -> Nat:
  Pure.tzif.count(h, i)

def tzif.bsize(+t8: Bool, +h: String) -> Nat:
  Pure.tzif.bsize(t8, h)

def tzif.block(+t8: Bool, +h: String) -> Maybe<&2, Zone>:
  zone.maybe.from.pure(Pure.tzif.block(t8, h))

def tzif.go(v2: Bool, +s: String) -> Maybe<&2, Zone>:
  zone.maybe.from.pure(Pure.tzif.go(v2, s))

def tzif.parse(b: Bytes.Bytes) -> Maybe<&2, Zone>:
  zone.maybe.from.pure(Pure.tzif.parse(b))

def tz.digit(+c: U32) -> Bool:
  Pure.tz.digit(c)

def tz.alpha(+c: U32) -> Bool:
  Pure.tz.alpha(c)

def tz.quoted(+c: U32) -> Bool:
  Pure.tz.quoted(c)

def tz.number.stop(seen: Bool, acc: U32, s: String) -> Maybe<&2, TzField>:
  tzfield.maybe.from.pure(Pure.tz.number.stop(seen, acc, s))

def tz.number.step(digit: Bool, c: U32, t: String, acc: U32, seen: Bool, next: Unit -> Maybe<&2, TzField>) -> Maybe<&2, TzField>:
  tzfield.maybe.from.pure(Pure.tz.number.step(digit, c, t, acc, seen, (v => tzfield.maybe.to.pure(next(v)))))

def tz.number.go(s: String, +acc: U32, +seen: Bool) -> Maybe<&2, TzField>:
  tzfield.maybe.from.pure(Pure.tz.number.go(s, acc, seen))

def tz.number(s: String) -> Maybe<&2, TzField>:
  tzfield.maybe.from.pure(Pure.tz.number(s))

def tz.name.valid(ok: Bool, name: String, rest: String) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.valid(ok, name, rest))

def tz.name.done(rev: String, rest: String) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.done(rev, rest))

def tz.name.empty(quoted: Bool, rev: String) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.empty(quoted, rev))

def tz.name.branch(continue: Bool, rev: String, c: U32, rest: String, next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.branch(continue, rev, c, rest, (v => tztext.maybe.to.pure(next(v)))))

def tz.name.allowed(ok: Bool, next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.allowed(ok, (v => tztext.maybe.to.pure(next(v)))))

def tz.name.quoted(end: Bool, valid: Bool, rev: String, rest: String, next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.quoted(end, valid, rev, rest, (v => tztext.maybe.to.pure(next(v)))))

def tz.name.char(quoted: Bool, end: Bool, alpha: Bool, valid: Bool, rev: String, c: U32, rest: String,
  next: Unit -> Maybe<&2, TzText>) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.char(quoted, end, alpha, valid, rev, c, rest, (v => tztext.maybe.to.pure(next(v)))))

def tz.name.go(s: String, +rev: String, +quoted: Bool) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name.go(s, rev, quoted))

def tz.name(s: String) -> Maybe<&2, TzText>:
  tztext.maybe.from.pure(Pure.tz.name(s))

def tz.field.valid(ok: Bool, n: U32, rest: String) -> Maybe<&2, TzField>:
  tzfield.maybe.from.pure(Pure.tz.field.valid(ok, n, rest))

def tz.clock.tail(r: TzField, limit: U32) -> Maybe<&2, TzField>:
  tzfield.maybe.from.pure(Pure.tz.clock.tail(tzfield.to.pure(r), limit))

def tz.clock.part(s: String) -> Maybe<&2, TzField>:
  tzfield.maybe.from.pure(Pure.tz.clock.part(s))

def tz.clock.valid(ok: Bool, +value: Int.I64, negative: Bool, rest: String) -> Maybe<&2, TzClock>:
  tzclock.maybe.from.pure(Pure.tz.clock.valid(ok, value, negative, rest))

def tz.clock.seconds(sec: TzField, +hours: U32, +minutes: U32, +max: U32, negative: Bool) -> Maybe<&2, TzClock>:
  tzclock.maybe.from.pure(Pure.tz.clock.seconds(tzfield.to.pure(sec), hours, minutes, max, negative))

def tz.clock.minutes(m: TzField, +hours: U32, +max: U32, +negative: Bool) -> Maybe<&2, TzClock>:
  tzclock.maybe.from.pure(Pure.tz.clock.minutes(tzfield.to.pure(m), hours, max, negative))

def tz.clock.finish(h: TzField, +max: U32, +negative: Bool) -> Maybe<&2, TzClock>:
  tzclock.maybe.from.pure(Pure.tz.clock.finish(tzfield.to.pure(h), max, negative))

def tz.clock.read(s: String, max: U32, negative: Bool) -> Maybe<&2, TzClock>:
  tzclock.maybe.from.pure(Pure.tz.clock.read(s, max, negative))

def tz.clock.sign(s: String, max: U32) -> Maybe<&2, TzClock>:
  tzclock.maybe.from.pure(Pure.tz.clock.sign(s, max))

def tz.day.valid(ok: Bool, d: TzDay, rest: String) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day.valid(ok, tzday.to.pure(d), rest))

def tz.day.j(r: TzField) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day.j(tzfield.to.pure(r)))

def tz.day.n(r: TzField) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day.n(tzfield.to.pure(r)))

def tz.after(c: Char, s: String) -> String:
  Pure.tz.after(c, s)

def tz.day.weekday(c: TzField, +month: U32, +week: U32) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day.weekday(tzfield.to.pure(c), month, week))

def tz.day.week(b: TzField, month: U32) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day.week(tzfield.to.pure(b), month))

def tz.day.month(a: TzField) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day.month(tzfield.to.pure(a)))

def tz.day.m(s: String) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day.m(s))

def tz.day(s: String) -> Maybe<&2, TzDayPart>:
  tzdaypart.maybe.from.pure(Pure.tz.day(s))

def tz.date.clock(d: TzDay, r: TzClock) -> Maybe<&2, TzDatePart>:
  tzdatepart.maybe.from.pure(Pure.tz.date.clock(tzday.to.pure(d), tzclock.to.pure(r)))

def tz.date.time(d: TzDay, rest: String) -> Maybe<&2, TzDatePart>:
  tzdatepart.maybe.from.pure(Pure.tz.date.time(tzday.to.pure(d), rest))

def tz.date.part(r: TzDayPart) -> Maybe<&2, TzDatePart>:
  tzdatepart.maybe.from.pure(Pure.tz.date.part(tzdaypart.to.pure(r)))

def tz.date(s: String) -> Maybe<&2, TzDatePart>:
  tzdatepart.maybe.from.pure(Pure.tz.date(s))

def tz.rule.end(ok: Bool, standard: Ttype, daylight: Ttype, start: TzDate, end: TzDate) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.end(ok, ttype.to.pure(standard), ttype.to.pure(daylight), tzdate.to.pure(start), tzdate.to.pure(end)))

def tz.rule.finish(b: TzDatePart, standard: Ttype, daylight: Ttype, start: TzDate) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.finish(tzdatepart.to.pure(b), ttype.to.pure(standard), ttype.to.pure(daylight), tzdate.to.pure(start)))

def tz.rule.start(a: TzDatePart, +standard: Ttype, +daylight: Ttype) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.start(tzdatepart.to.pure(a), ttype.to.pure(standard), ttype.to.pure(daylight)))

def tz.rule.dates(+standard: Ttype, +daylight: Ttype, rest: String) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.dates(ttype.to.pure(standard), ttype.to.pure(daylight), rest))

def tz.rule.dstclock(r: TzClock, standard: Ttype, abbr: String) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.dstclock(tzclock.to.pure(r), ttype.to.pure(standard), abbr))

def tz.rule.offset(standard: Ttype, abbr: String, west: Int.I64, rest: String) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.offset(ttype.to.pure(standard), abbr, west, rest))

def tz.rule.named(name: TzText, standard: Ttype, west: Int.I64) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.named(tztext.to.pure(name), ttype.to.pure(standard), west))

def tz.rule.dst(+standard: Ttype, west: Int.I64, rest: String) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.dst(ttype.to.pure(standard), west, rest))

def tz.rule.stdclock(offset: TzClock, abbr: String) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.stdclock(tzclock.to.pure(offset), abbr))

def tz.rule.standard(name: TzText) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule.standard(tztext.to.pure(name)))

def tz.rule(s: String) -> Maybe<&2, TzRule>:
  tzrule.maybe.from.pure(Pure.tz.rule(s))

def tz.day.index(d: TzDay, +y: U32) -> U32:
  Pure.tz.day.index(tzday.to.pure(d), y)

def tz.date.utc(d: TzDate, +y: U32, west: Int.I64) -> Int.I64:
  Pure.tz.date.utc(tzdate.to.pure(d), y, west)

def tz.event.select(newer: Bool, old: Maybe<&2, TzEvent>, when: Int.I64, dst: Bool) -> Maybe<&2, TzEvent>:
  tzevent.maybe.from.pure(Pure.tz.event.select(newer, tzevent.maybe.to.pure(old), when, dst))

def tz.event.new(+now: Int.I64, old: Maybe<&2, TzEvent>, +when: Int.I64, dst: Bool) -> Maybe<&2, TzEvent>:
  tzevent.maybe.from.pure(Pure.tz.event.new(now, tzevent.maybe.to.pure(old), when, dst))

def tz.event.year(+now: Int.I64, old: Maybe<&2, TzEvent>, +r: TzRule, +y: U32) -> Maybe<&2, TzEvent>:
  tzevent.maybe.from.pure(Pure.tz.event.year(now, tzevent.maybe.to.pure(old), tzrule.to.pure(r), y))

def tz.event.prev(+now: Int.I64, old: Maybe<&2, TzEvent>, +r: TzRule, +y: U32) -> Maybe<&2, TzEvent>:
  tzevent.maybe.from.pure(Pure.tz.event.prev(now, tzevent.maybe.to.pure(old), tzrule.to.pure(r), y))

def tz.event.next.if(valid: Bool, now: Int.I64, old: Maybe<&2, TzEvent>, r: TzRule, y: U32) -> Maybe<&2, TzEvent>:
  tzevent.maybe.from.pure(Pure.tz.event.next.if(valid, now, tzevent.maybe.to.pure(old), tzrule.to.pure(r), y))

def tz.event.next(+now: Int.I64, old: Maybe<&2, TzEvent>, +r: TzRule, +y: U32) -> Maybe<&2, TzEvent>:
  tzevent.maybe.from.pure(Pure.tz.event.next(now, tzevent.maybe.to.pure(old), tzrule.to.pure(r), y))

def tz.event.type(ev: Maybe<&2, TzEvent>, +r: TzRule) -> Ttype:
  ttype.from.pure(Pure.tz.event.type(tzevent.maybe.to.pure(ev), tzrule.to.pure(r)))

def tz.rule.at(+r: TzRule, +secs: Int.I64, +year: U32) -> Ttype:
  ttype.from.pure(Pure.tz.rule.at(tzrule.to.pure(r), secs, year))

def tz.rule.date(d: Maybe<&2, DateTime>, r: TzRule, secs: Int.I64) -> Maybe<&2, Ttype>:
  ttype.maybe.from.pure(Pure.tz.rule.date(datetime.maybe.to.pure(d), tzrule.to.pure(r), secs))

def tz.rule.lookup(rule: Maybe<&2, TzRule>, +secs: Int.I64) -> Maybe<&2, Ttype>:
  ttype.maybe.from.pure(Pure.tz.rule.lookup(tzrule.maybe.to.pure(rule), secs))

def Zone.find(ts: List<&2, Trans>, +secs: Int.I64, +cur: U32) -> U32:
  Pure.Zone.find(trans.list.to.pure(ts), secs, cur)

def Zone.last.go(ts: List<&2, Trans>, +secs: Int.I64, +last: Int.I64) -> Bool:
  Pure.Zone.last.go(trans.list.to.pure(ts), secs, last)

def Zone.last(ts: List<&2, Trans>, secs: Int.I64) -> Bool:
  Pure.Zone.last(trans.list.to.pure(ts), secs)

def Zone.at.fallback(m: Maybe<&2, Ttype>, types: List<&2, Ttype>, ts: List<&2, Trans>, secs: Int.I64) -> Maybe<&2, Ttype>:
  ttype.maybe.from.pure(Pure.Zone.at.fallback(ttype.maybe.to.pure(m), ttype.list.to.pure(types), trans.list.to.pure(ts), secs))

def Zone.at.footer(use: Bool, tz: String, types: List<&2, Ttype>, ts: List<&2, Trans>, +secs: Int.I64) -> Maybe<&2, Ttype>:
  ttype.maybe.from.pure(Pure.Zone.at.footer(use, tz, ttype.list.to.pure(types), trans.list.to.pure(ts), secs))

def Zone.at.tz(empty: Bool, tz: String, types: List<&2, Ttype>, +ts: List<&2, Trans>, +secs: Int.I64) -> Maybe<&2, Ttype>:
  ttype.maybe.from.pure(Pure.Zone.at.tz(empty, tz, ttype.list.to.pure(types), trans.list.to.pure(ts), secs))

def Zone.at(z: Zone, i: Instant) -> Maybe<&2, Ttype>:
  ttype.maybe.from.pure(Pure.Zone.at(zone.to.pure(z), instant.to.pure(i)))

def Zone.local.at(m: Maybe<&2, Ttype>, i: Instant) -> Maybe<&2, DateTime>:
  datetime.maybe.from.pure(Pure.Zone.local.at(ttype.maybe.to.pure(m), instant.to.pure(i)))

def Zone.local(z: Zone, +i: Instant) -> Maybe<&2, DateTime>:
  datetime.maybe.from.pure(Pure.Zone.local(zone.to.pure(z), instant.to.pure(i)))

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

# Time since an unspecified start that never goes back. Use it to measure spans.
def mono() -> IO(Duration):
  do IO<Duration>:
    r : U32 & U32 & U32 <- mono.raw()
    return raw.dur(r)

# Monotonic milliseconds. Pure cores that take a Nat `now` in ms take this.
def mono.ms() -> IO(Nat):
  do IO<Nat>:
    d : Duration <- mono()
    return Duration.to_ms_nat(d)

# Monotonic microseconds.
def mono.us() -> IO(Nat):
  do IO<Nat>:
    d : Duration <- mono()
    return Duration.to_us_nat(d)

# The wall clock. It can jump when the system time is set.
def now() -> IO(Instant):
  do IO<Instant>:
    r : U32 & U32 & U32 <- wall.raw()
    return Instant.of(raw.dur(r))

