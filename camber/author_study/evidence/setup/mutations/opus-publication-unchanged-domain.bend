# Pure publishing domain. Imports stay free of IO and @unsafe defs, since the laws depend on this file.
import Base
import ../contract.bend as Contract
import ../../../json/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def publish(record: Contract.Record) -> Contract.Record:
  Contract.Record{owner, title, secret, published} = record
  Contract.Record{owner, title, secret, published}

def view(record: Contract.Record) -> Contract.Public:
  Contract.Record{owner, title, secret, published} = record
  Contract.Public{owner, title, published}

# Bytes.Bytes is Http.Body; importing http.bend here would pull its effects into the proofs.
def encode(value: Contract.Public) -> Bytes.Bytes:
  Contract.Public{owner, title, published} = value
  Json.encode.bytes(Json.Obj{[(Json.utf8("owner"), Json.Num{Json.utf8(U32.show(owner))}), (Json.utf8("title"), Json.Str{Json.utf8(title)}), (Json.utf8("published"), Json.Flag{published})]})
