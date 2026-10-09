# notch

Leveled logging. A logger holds a minimum level, logfmt or JSON-lines format, and contextual fields.

```bend
import bend-kit-notch@0.1.0.1/notch.bend as Notch
```

```bend
def main() -> IO(Unit):
  lg = Notch.with(Notch.text(Notch.Info{}), [Notch.str("svc", "api")])
  Notch.info(lg, "up", [Notch.num("port", 8080)])
```

`text` writes logfmt. `json` writes one JSON object per line. `with` appends fields to every later line. `str`, `num`, and `flag` build fields. `debug`, `info`, `warn`, and `error` write to stderr. `file` writes to a `File` and returns the handle. `line` returns the text, or `None` when the level is below the minimum, so another sink can take it.

A disabled level does not read the clock and does not render the line. Enabled lines stamp an RFC 3339 time from `Time.now`. This package imports `bend-kit-time@0.1.2.1`.

Fields stay in insertion order. Keys are not deduplicated. In JSON output, avoid `time`, `level`, and `msg` as field names. Those are the logger's own keys.
