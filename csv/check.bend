import Base
import ./csv.bend as Csv
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def show(r: Result<&1, &1, U32, List<&1, List<&1, Bytes.Bytes>>>) -> IO(Unit):
  match r:
    case Fail{at}:
      IO.print("bad at " ++ U32.show(at))
    case Done{rs}:
      IO.print(Bytes.to_string(Csv.encode(rs)))

def pc(+s: String) -> IO(Unit):
  show(Csv.parse(Bytes.from_string(s)))

def main() -> IO(Unit):
  do IO<Unit>:
    pc("aaa,bbb,ccc\r\nzzz,yyy,xxx\r\n")
    pc("\"aaa\",\"b\r\nbb\",\"b\"\"cc\"\nx,,\n\n")
    pc("\r\n\"\"\r\n")
    pc("id,name\n1,\"Smith, J\"\r2,plain")
    pc("a,b\"c")
    pc("\"open")
