import Base
import ../contract.bend as Contract
import ../../../json/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def publish(record: Contract.Record) -> Contract.Record:
  match record:
    case Contract.Record{owner, title, secret, published}:
      Contract.Record{owner, title, secret, published}

def view(record: Contract.Record) -> Contract.Public:
  match record:
    case Contract.Record{owner, title, secret, published}:
      Contract.Public{owner, title, published}

def encode(value: Contract.Public) -> Bytes.Bytes:
  match value:
    case Contract.Public{owner, title, published}:
      Json.encode.bytes(Json.Obj{[
        (Json.utf8("owner"), Json.Num{Json.utf8(U32.show(owner))}),
        (Json.utf8("title"), Json.Str{Json.utf8(title)}),
        (Json.utf8("published"), Json.Flag{published})
      ]})
