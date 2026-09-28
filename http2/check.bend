import Base
import ./http2.bend as H
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./hpack.bend as Hp
import ./live.bend as Live

def ensure(ok: Bool, +why: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ why)
    case False{}:
      IO.die(Unit, 1, why)

def received(d: H.Decode) -> IO(Unit):
  match d:
    case H.Need{b}:
      IO.die(Unit, 1, "complete frame requested more bytes")
    case H.Bad{H.Error{code, connection, stream}}:
      IO.die(Unit, 1, "valid frame failed: " ++ U32.show(code))
    case H.Got{H.Frame{+kind, +flags, +stream, Bytes.Bytes{+len, buf}}, Bytes.Bytes{+rest, tail}}:
      ensure(Bool.and(U32.is_eq(kind, 0), Bool.and(U32.is_eq(flags, 1), Bool.and(U32.is_eq(stream, 1), Bool.and(U32.is_eq(len, 16384), U32.is_eq(rest, 0))))), "16 KiB DATA payload and frame boundary")

def encoded(r: Result<&1, &1, H.Error, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{H.Error{code, connection, stream}}:
      IO.die(Unit, 1, "valid frame failed to encode: " ++ U32.show(code))
    case Done{b}:
      received(H.parse(16384, b))

def hpack.decoded(m: Maybe<&1, Hp.State & List<&2, Hp.Field>>) -> IO(Unit):
  match m:
    case Some{(Hp.State{entries, +size, capacity, allowed, pending, minimum}, Con{Hp.Field{name, value, mode}, Nil{}})}:
      ensure(Bool.and(U32.is_eq(size, 57), Bool.and(String.eq(name, ":authority"), String.eq(value, "www.example.com"))), "native Huffman block and dynamic table")
    case _:
      IO.die(Unit, 1, "native HPACK decode failed")

def hpack.encoded(m: Maybe<&1, Hp.State & Bytes.Bytes>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "native HPACK encode failed")
    case Some{(state, b)}:
      hpack.decoded(Hp.decode(b, Hp.new(4096)))

def client.fixture.result(r: H.Reply) -> IO(Unit):
  match r:
    case H.Failed{H.Error{code, connection, stream}}:
      IO.die(Unit, 1, "response failed: " ++ U32.show(code))
    case H.Ready{H.Client{input, streams, encoder, decoder,
        H.Control{next, +active, frame_max, initial, max_streams, connection, recv,
          first, ack, continuation, goaway}},
        Con{ack_packet, Nil{}},
        Con{H.Response{+id, Con{Hp.Field{name, value, mode}, Nil{}}, Bytes.Bytes{+len, buf}}, Nil{}}}:
      ensure(Bool.and(U32.is_eq(active, 0), Bool.and(U32.is_eq(id, 1),
        Bool.and(U32.is_eq(len, 0), Bool.and(String.eq(name, ":status"), String.eq(value, "200"))))),
        "request receives decoded response and releases stream")
    case _:
      IO.die(Unit, 1, "response or SETTINGS ACK missing")

def client.fixture.request(r: H.Reply, frames: Bytes.Bytes) -> IO(Unit):
  match r:
    case H.Failed{H.Error{code, connection, stream}}:
      IO.die(Unit, 1, "request failed: " ++ U32.show(code))
    case H.Ready{client, Con{request, Nil{}}, Nil{}}:
      client.fixture.result(H.client.receive(client, frames))
    case _:
      IO.die(Unit, 1, "request did not emit one HEADERS frame")

def client.fixture.start(r: H.Client & Bytes.Bytes, frames: Bytes.Bytes) -> IO(Unit):
  (client, preface) = r
  client.fixture.request(H.client.request(client,
    [Hp.Field{":method", "GET", 0}, Hp.Field{":scheme", "https", 0},
      Hp.Field{":authority", "www.example.com", 0}, Hp.Field{":path", "/", 0}],
    Bytes.new(0)), frames)

def client.fixture.frame(r: Result<&1, &1, H.Error, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{error}:
      IO.die(Unit, 1, "server fixture could not encode")
    case Done{packet}:
      client.fixture.start(H.client.start(), Bytes.append(Bytes.set(Bytes.new(9), 3, 4), packet))

def main() -> IO(Unit):
  do IO<Unit>:
    frame: Unit <- encoded(H.encode(16384, H.Frame{0, 1, 1, Bytes.new(16384)}))
    pack: Unit <- hpack.encoded(Hp.encode([Hp.Field{":authority", "www.example.com", 0}], True{}, Hp.new(4096)))
    fixture: Unit <- client.fixture.frame(H.encode(16384, H.Frame{1, 5, 1, Bytes.set(Bytes.new(1), 0, 136)}))
    Live.run()
