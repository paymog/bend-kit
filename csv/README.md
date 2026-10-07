# csv

RFC 4180 records over `Bytes`. Fields are raw bytes: no charset conversion and no trimming.

```bend
import bend-kit-csv@0.1.0.0/csv.bend as Csv
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
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

`cursor` and `next` walk one record at a time. `next` returns `Row{fields, cur}`, `End{}`, or `Bad{at}`. The cursor is affine. Pass the cursor from `Row` into the next call. `encode` writes CRLF records.
