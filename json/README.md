# json

JSON values follow RFC 8259. The package stores and parses them as UTF-8 `Bytes`. A number stays as text in `Num{s}` until you convert it.

```bend
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
```

`json.bend` imports `bend-kit-bytes@0.3.2.0`. Use this bytes version with `Json.Val`. A caller that imports an older json version can have different types.

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

`Val` is `Null{}`, `Flag{on}`, `Num{s}`, `Str{s}`, `Arr{xs}`, or `Obj{kvs}`. Object keys and string values are `Bytes`, not `String`. `Obj` keeps repeated keys and their order. `get(v, key)` takes a `String` key and returns its last value. `at(v, index)` returns an array element at a `Nat` index.

`parse.bytes` replaces lone surrogates. It allows nesting up to the input size. `parse.strict.bytes(b, cap)` rejects lone surrogates. It stops at `cap` nested arrays or objects. `encode.bytes` writes compact JSON. `utf8` converts a `String` to UTF-8 `Bytes` for `Str`.

`parse/json.bend` is a separate grammar on the combinators. It is not this package.

## Unique object keys

`unique.keys(v)` returns `(v, ok)`. `ok` is true when each object's decoded
UTF-8 keys are unique, including objects nested in arrays. The returned value
keeps field order and exact number text.

`parse.strict.unique.bytes(body, cap)` applies the strict parser and this key
policy. It returns `None` for invalid syntax, invalid UTF-8, lone surrogate
escapes, depth overflow, or a duplicate decoded key. Identical decoded keys in
separate objects are allowed. Key comparison uses exact decoded bytes.

Each object compares every pair of keys. An object with `n` fields performs
`n * (n - 1) / 2` comparisons; comparison cost also depends on key length.
The check returns the original byte buffers and rebuilds container list cells.
