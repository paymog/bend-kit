import Base
import ./parse.bend as P
import ./json.bend as J
import ../json/json.bend as Json
import 0xcfc8be7b076f41f95c8e118383892d55/encoding.bend as Enc

def show(r: P.Res<J.Val>) -> IO(Unit):
  match r:
    case P.Ok{v, c}:
      IO.print(Enc.utf8.decode(Json.encode.bytes(J.to_json(v))))
    case P.Err{o, w}:
      IO.print("expected " ++ w ++ " at " ++ U32.show(o))

def main() -> IO(Unit):
  do IO<Unit>:
    show(J.parse.res("null"))
    show(J.parse.res(" true "))
    show(J.parse.res("[]"))
    show(J.parse.res("{}"))
    show(J.parse.res("-12.5e+3"))
    show(J.parse.res("\"hi\\n\\u00e9\""))
    show(J.parse.res("null x"))
    show(J.parse.res("{\"b\":[1,{\"c\":null}],\"a\":true}"))
    show(J.parse.res("[1,]"))
    show(J.parse.res("{\"a\" 1}"))
