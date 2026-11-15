# csv

Parse and encode RFC 4180 records over `Bytes`. Fields are raw bytes. The package does not convert character encodings or remove spaces.

```bend
import bend-kit-csv@0.3.0.0/csv.bend as Csv
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

```bend
def show(got: Result<&1, &1, U32, List<&1, List<&1, Bytes.Bytes>>>) -> IO(Unit):
  match got:
    case Done{rows}:
      IO.print("rows")
    case Fail{at}:
      IO.print(U32.show(at))

def main() -> IO(Unit):
  show(Csv.parse(Bytes.from_string("aaa,bbb,ccc\r\nzzz,yyy,xxx\r\n")))
```

`parse` returns `Fail{at}` at the first RFC 4180 violation. `at` is a byte index. An empty line has no fields. A trailing comma adds an empty field.

`cursor` and `next` read one record at a time. `next` returns `Row{fields, cur}`, `End{}`, or `Bad{at}`. The cursor is affine. Pass the cursor from `Row` into the next call. `encode` writes records with CRLF line endings.
