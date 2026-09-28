import Base
import ./cbor.bend as Cbor
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def got(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case Some{b}:
      b
    case None{}:
      Bytes.new(0)

def hexed(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case Some{b}:
      Bytes.to_hex(b)
    case None{}:
      "none (encode)"

def reenc(m: Maybe<&1, Cbor.Val>) -> String:
  match m:
    case Some{v}:
      hexed(Cbor.encode(v))
    case None{}:
      "none"

# Decodes hex, then prints the definite, preferred encoding of the value, or none.
def show(s: String) -> IO(Unit):
  IO.print(reenc(Cbor.decode(got(Bytes.from_hex(s)))))

def main() -> IO(Unit):
  do IO<Unit>:
    show("bf61610161629f0203ffff")
    show("9f018202039f0405ffff")
    show("c29f5f4101ff9fffff")
    show("7f657374726561646d696e67ff")
    show("bf5f4161ff9f9f9f9fffffffffff")
    show("a26161fb3ff199999999999a6162d818f8ff")
    show("1b000000e8d4a51000")
    show("bf01ff")
    show("5f5f4101ffff")
    show("7f61c361bcff")
    show("81ff")
    show("1c")
    show("f818")
    show("0000")
    show("9a0000000201")
    IO.print(hexed(Cbor.encode(Cbor.Sim{Cbor.Other{24}})))
    IO.print(hexed(Cbor.encode(Cbor.TStr{Bytes.from_string("\u{ff}")})))
