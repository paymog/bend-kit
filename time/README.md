# time

Clocks, `Duration`, `Instant`, Gregorian dates, RFC 3339, HTTP-date, and TZif zones.

```bend
import bend-kit-time@0.3.0.0/time.bend as Time
```

`now` is the wall clock. `mono` is a monotonic duration. Both are effects in `effs/time.c` and `effs/time.js`. Proofs do not cover them. There is no `BEND_LIB` override.

`mono.ms` and `mono.us` read the monotonic clock as a `Nat` of whole milliseconds or microseconds. Pure cores that take a `Nat` `now` take one of them, so every core sees the same clock. `Duration.to_ms_nat` and `Duration.to_us_nat` are the pure conversions; a negative duration gives 0. Native `Nat` stops at `2^48 - 1`, which microseconds reach after about 8.9 years of uptime.

`Instant` and `Duration` use `Int.I64` seconds plus nanoseconds. A day is 86400 seconds. Leap seconds are not inserted. `Duration.add` and `Instant.add` are pure. Gregorian conversion covers years 0 to 9999.

`rfc3339` formats an `Instant` as RFC 3339 text. It returns `None` when the date is outside the supported range. `rfc3339.parse` reads RFC 3339 text. `http_date.parse` reads an IMF-fixdate. The parsers return `None` for text they do not accept.

`tzif.parse` reads a zone from packed bytes. This package imports `bend-kit-bytes@0.3.3.0`, `bend-kit-int@0.2.0.0`, and `bend-kit-fmt@0.1.0.0`. `Zone.local` gives the local date and time for an instant. It uses the POSIX footer after the last explicit transition.

`notch` imports an older time hash, `0x3bfb4ae4d3b87b90f01bfcd298211455`. `http@0.32.0.0` imports `bend-kit-time@0.1.2.1`. Hairpin imports 0.1.2.1 for Http's `Instant`s and 0.1.3.0 for `mono.ms`. Pass an `Instant` only into the version that expects it.
