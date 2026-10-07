# parse

Parser combinators over text, with a position on every error. Choice backtracks, as in a PEG.

```bend
import bend-kit-parse@0.1.0.1/parse.bend as Parse
```

`start` makes a cursor. `run` applies a parser to a `String` and returns `Res`: the value and the rest of the cursor, or an error at a position. `char`, `lit`, and `satisfy` read one token. `seq`, `alt`, `many`, `sep_by`, and `opt` combine parsers. A template can be called many times. A parser that needs to call itself uses `rec`, because a template cannot recurse through a def below it.

`parse/json.bend` is an RFC 8259 grammar on these combinators. Import it beside `parse.bend`:

```bend
import bend-kit-parse@0.1.0.1/json.bend as J
```

`J.parse` returns `Maybe`. `J.parse.res` returns the positioned `Res`. This `Val` is not `bend-kit-json`'s `Val`. The json package parses `Bytes` and is the one `http` uses.
