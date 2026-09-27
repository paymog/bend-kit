import Base
import ./json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import 0xcfc8be7b076f41f95c8e118383892d55/encoding.bend as Enc

def show(m: Maybe<&1, Json.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{v}:
      IO.print(Enc.utf8.decode(Json.encode.bytes(v)))

def pb(+s: String) -> Maybe<&1, Json.Val>:
  Json.parse.bytes(Bytes.from_string(s))

def main() -> IO(Unit):
  do IO<Unit>:
    show(pb("null"))
    show(pb(" true "))
    show(pb("[]"))
    show(pb("{}"))
    show(pb("-12.5e+3"))
    show(pb("\"hi\\n\\u00e9\""))
    show(pb("null x"))
    show(pb("{\"b\":[1,{\"c\":null}],\"a\":true}"))
    show(pb("[1,]"))
    show(pb("{\"b\":[1,{\"c\":null}],\"a\":\"h\u{c3}\u{a9}\\u00e9\"}"))
    show(pb("\"\u{c0}\u{af}\""))
