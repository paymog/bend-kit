# time

Clocks, `Duration`, `Instant`, Gregorian dates, RFC 3339, HTTP-date, and TZif zones.

```bend
import bend-kit-time@0.1.2.0/time.bend as Time
```

`now` is the wall clock. `mono` is a monotonic duration. Both are effects in `effs/time.c` and `effs/time.js`. Proofs do not cover them. There is no `BEND_LIB` override.

`Instant` and `Duration` use `Int.I64` seconds plus nanoseconds. A day is 86400 seconds. Leap seconds are not inserted. `Duration.add` and `Instant.add` are pure. Gregorian conversion covers years 0 to 9999.

`rfc3339` and `rfc3339.parse` convert an `Instant` to and from RFC 3339 text. `http_date.parse` reads an IMF-fixdate. Both return `None` on text they do not accept.

`tzif.parse` reads a zone from packed bytes. This package imports bytes as `0x49814d83de8f70993a43e1002be29ecd/bytes.bend`. `Zone.local` applies the zone to an instant, including the POSIX footer for instants after the last explicit transition.

`notch` imports an older time hash, `0x3bfb4ae4d3b87b90f01bfcd298211455`. `http@0.30.0.0` and `hairpin` import `bend-kit-time@0.1.0.0`. Pass an `Instant` only into the version that expects it.
