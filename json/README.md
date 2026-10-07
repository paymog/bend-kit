# json

JSON values as RFC 8259, stored and parsed as UTF-8 `Bytes`. A number stays text in `Num{s}` until you convert it.

```bend
import bend-kit-json@0.5.1.0/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

`json.bend` imports that bytes hash. `http@0.30.0.0` imports an older json hash, `0x584fc27920487ceab242392391418d7f`. Do not pass a `Val` from this version into that `http`.

```bend
def show(m: Maybe<&1, Json.Val>) -> IO(Unit):
  match m:
    case Some{v}:
      IO.print("parsed")
    case None{}:
      IO.print("bad")

def main() -> IO(Unit):
  show(Json.parse.bytes(Bytes.from_string("{\"ok\":true}")))
```

`match` takes a parameter. Pass the `Maybe` into a helper.

## Values

`Val` is `Null{}`, `Flag{on}`, `Num{s}`, `Str{s}`, `Arr{xs}`, or `Obj{kvs}`. Object keys and string values are `Bytes`, not `String`. `Obj` keeps repeated keys and key order. `get` returns the last value for a key. `at` is an array element by `Nat` index.

`parse.bytes` replaces lone surrogates and allows nesting up to the input size. `parse.strict.bytes(b, cap)` rejects lone surrogates and stops at `cap` nested arrays or objects. `encode.bytes` writes compact JSON. `utf8` turns a `String` into the `Bytes` a `Str` holds.

`parse/json.bend` is a separate grammar on the combinators. It is not this package.
