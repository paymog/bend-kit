import Base
import bend-kit-int@0.2.0.0/int.bend as Int
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ./time.bend as Time

def u(x: U32) -> Int.I64:
  Int.I64.from_u32(x)

def neg(x: U32) -> Int.I64:
  Int.I64.neg(Int.I64.from_u32(x))

def at(s: Int.I64) -> Time.Instant:
  Time.Instant{s, 0}

def date(y: U32, m: U32, d: U32) -> Time.Date:
  Time.Date{y, m, d}

def trip(+d: Time.Date) -> Maybe<&2, Time.Date>:
  Time.Date.of_days(Time.Date.to_days(d))

# Leap years: every fourth year, but not centuries, except every fourth century.
law leap_2000:
  {Time.Date.is_leap(2000) == True{} : Bool}

law leap_1900:
  {Time.Date.is_leap(1900) == False{} : Bool}

law leap_2024:
  {Time.Date.is_leap(2024) == True{} : Bool}

law leap_2023:
  {Time.Date.is_leap(2023) == False{} : Bool}

law feb_2000:
  {Time.Date.days_in_month(2000, 2) == 29 : U32}

law feb_1900:
  {Time.Date.days_in_month(1900, 2) == 28 : U32}

law feb_29_1900_invalid:
  {Time.Date.valid(date(1900, 2, 29)) == False{} : Bool}

# Days since 1970-01-01, and back.
law days_epoch:
  {Time.Date.to_days(date(1970, 1, 1)) == u(0) : Int.I64}

law days_2000_03_01:
  {Time.Date.to_days(date(2000, 3, 1)) == u(11017) : Int.I64}

law days_first:
  {Time.Date.to_days(date(0, 1, 1)) == neg(719528) : Int.I64}

law days_last:
  {Time.Date.to_days(date(9999, 12, 31)) == u(2932896) : Int.I64}

law trip_epoch:
  {trip(date(1970, 1, 1)) == Some{date(1970, 1, 1)} : Maybe<&2, Time.Date>}

law trip_before_epoch:
  {trip(date(1969, 12, 31)) == Some{date(1969, 12, 31)} : Maybe<&2, Time.Date>}

law trip_leap_day:
  {trip(date(2000, 2, 29)) == Some{date(2000, 2, 29)} : Maybe<&2, Time.Date>}

law trip_1900_03_01:
  {trip(date(1900, 3, 1)) == Some{date(1900, 3, 1)} : Maybe<&2, Time.Date>}

law trip_first:
  {trip(date(0, 1, 1)) == Some{date(0, 1, 1)} : Maybe<&2, Time.Date>}

law trip_last:
  {trip(date(9999, 12, 31)) == Some{date(9999, 12, 31)} : Maybe<&2, Time.Date>}

law past_last:
  {Time.Date.of_days(u(2932897)) == None{} : Maybe<&2, Time.Date>}

law before_first:
  {Time.Date.of_days(neg(719529)) == None{} : Maybe<&2, Time.Date>}

# 1970-01-01 was a Thursday; 2000-03-01 a Wednesday.
law weekday_epoch:
  {Time.Date.weekday(date(1970, 1, 1)) == 4 : U32}

law weekday_2000_03_01:
  {Time.Date.weekday(date(2000, 3, 1)) == 3 : U32}

# Durations keep nanos in 0..10^9 - 1.
law duration_carry:
  {Time.Duration.add(Time.Duration{u(1), 600000000}, Time.Duration{u(0), 600000000}) ==
    Time.Duration{u(2), 200000000} : Time.Duration}

law duration_neg:
  {Time.Duration.neg(Time.Duration{u(0), 500000000}) == Time.Duration{neg(1), 500000000} : Time.Duration}

law duration_to_ms:
  {Time.Duration.to_ms(Time.Duration{neg(1), 500000000}) == neg(500) : Int.I64}

law instant_since:
  {Time.Instant.since(at(u(10)), Time.Instant{u(12), 250000000}) ==
    Time.Duration{neg(3), 750000000} : Time.Duration}

# RFC 3339 (§5.8 examples).
law rfc3339_utc:
  {Time.rfc3339.parse("1985-04-12T23:20:50.52Z") == Some{Time.Instant{u(482196050), 520000000}} :
    Maybe<&2, Time.Instant>}

law rfc3339_offset:
  {Time.rfc3339.parse("1996-12-19T16:39:57-08:00") == Some{at(u(851042397))} : Maybe<&2, Time.Instant>}

law rfc3339_lowercase:
  {Time.rfc3339.parse("1985-04-12t23:20:50.52z") == Some{Time.Instant{u(482196050), 520000000}} :
    Maybe<&2, Time.Instant>}

law rfc3339_nanos:
  {Time.rfc3339.parse("1970-01-01T00:00:00.1234567891+00:00") == Some{Time.Instant{u(0), 123456789}} :
    Maybe<&2, Time.Instant>}

law rfc3339_leap_second:
  {Time.rfc3339.parse("1990-12-31T23:59:60Z") == None{} : Maybe<&2, Time.Instant>}

law rfc3339_bad_day:
  {Time.rfc3339.parse("2023-02-29T00:00:00Z") == None{} : Maybe<&2, Time.Instant>}

law rfc3339_no_zone:
  {Time.rfc3339.parse("2023-02-28T00:00:00") == None{} : Maybe<&2, Time.Instant>}

law rfc3339_empty_fraction:
  {Time.rfc3339.parse("2023-02-28T00:00:00.Z") == None{} : Maybe<&2, Time.Instant>}

law rfc3339_format:
  {Time.rfc3339(Time.Instant{u(482196050), 520000000}) == Some{"1985-04-12T23:20:50.52Z"} :
    Maybe<&2, String>}

law rfc3339_format_whole:
  {Time.rfc3339(at(u(851042397))) == Some{"1996-12-20T00:39:57Z"} : Maybe<&2, String>}

law rfc3339_format_before_epoch:
  {Time.rfc3339(at(neg(1))) == Some{"1969-12-31T23:59:59Z"} : Maybe<&2, String>}

law rfc3339_format_nanos:
  {Time.rfc3339(Time.Instant{neg(1), 1}) == Some{"1969-12-31T23:59:59.000000001Z"} : Maybe<&2, String>}

# HTTP-date (RFC 9110 §5.6.7 example).
law http_date_parse:
  {Time.http_date.parse("Sun, 06 Nov 1994 08:49:37 GMT") == Some{at(u(784111777))} :
    Maybe<&2, Time.Instant>}

law http_date_format:
  {Time.http_date(at(u(784111777))) == Some{"Sun, 06 Nov 1994 08:49:37 GMT"} : Maybe<&2, String>}

law http_date_not_gmt:
  {Time.http_date.parse("Sun, 06 Nov 1994 08:49:37 UTC") == None{} : Maybe<&2, Time.Instant>}

law http_date_bad_month:
  {Time.http_date.parse("Sun, 06 Now 1994 08:49:37 GMT") == None{} : Maybe<&2, Time.Instant>}

law http_date_asctime:
  {Time.http_date.parse("Sun Nov  6 08:49:37 1994") == None{} : Maybe<&2, Time.Instant>}

# A TZif version 2 fixture for America/New_York around 2024: transitions at
# 2023-11-05T06:00Z (EST), 2024-03-10T07:00Z (EDT), and 2024-11-03T06:00Z (EST).
def ny.of(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, Time.Zone>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Time.tzif.parse(b)

def ny() -> Maybe<&2, Time.Zone>:
  ny.of(Bytes.from_hex("545a696632000000000000000000000000000000000000000000000000000000000000000000000100000004ffffb9b0000045535400545a6966320000000000000000000000000000000000000000000000000000000000000300000002000000080000000065472f600000000065ed5a700000000067271160000100ffffb9b00000ffffc7c0010445535400454454000a455354354544542c4d332e322e302c4d31312e312e300a"))

def ny.type(m: Maybe<&2, Time.Zone>, s: Int.I64) -> Maybe<&2, Time.Ttype>:
  match m:
    case None{}:
      None{}
    case Some{z}:
      Time.Zone.at(z, at(s))

def ny.local(m: Maybe<&2, Time.Zone>, s: Int.I64) -> Maybe<&2, Time.DateTime>:
  match m:
    case None{}:
      None{}
    case Some{z}:
      Time.Zone.local(z, at(s))

def ny.tz(m: Maybe<&2, Time.Zone>) -> String:
  match m:
    case None{}:
      ""
    case Some{Time.Zone{ts, types, tz}}:
      tz

def local(y: U32, mo: U32, d: U32, h: U32, mi: U32, s: U32) -> Maybe<&2, Time.DateTime>:
  Some{Time.DateTime{date(y, mo, d), h, mi, s, 0}}

# The last second of EST, and the first of EDT: clocks go from 01:59:59 to 03:00:00.
law dst_before:
  {ny.type(ny(), u(1710053999)) == Some{Time.Ttype{neg(18000), False{}, "EST"}} : Maybe<&2, Time.Ttype>}

law dst_after:
  {ny.type(ny(), u(1710054000)) == Some{Time.Ttype{neg(14400), True{}, "EDT"}} : Maybe<&2, Time.Ttype>}

law dst_local_before:
  {ny.local(ny(), u(1710053999)) == local(2024, 3, 10, 1, 59, 59) : Maybe<&2, Time.DateTime>}

law dst_local_after:
  {ny.local(ny(), u(1710054000)) == local(2024, 3, 10, 3, 0, 0) : Maybe<&2, Time.DateTime>}

# Before the first transition, type 0 holds.
law before_first_transition:
  {ny.type(ny(), u(0)) == Some{Time.Ttype{neg(18000), False{}, "EST"}} : Maybe<&2, Time.Ttype>}

law tzif_footer:
  {ny.tz(ny()) == "EST5EDT,M3.2.0,M11.1.0" : String}

law tzif_bad_magic:
  {ny.of(Bytes.from_hex("545a6967")) == None{} : Maybe<&2, Time.Zone>}
