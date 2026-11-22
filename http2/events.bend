import Base
import ./http2.bend as H
import ./hpack.bend as Hp
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

def fields(xs: List<&2, Hp.Field>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{Hp.Field{name, value, mode}, rest}:
      name ++ "=" ++ value ++ ";" ++ fields(rest)

def events(xs: List<&1, H.ClientEvent>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{H.Informational{id, headers}, rest}:
      "I" ++ U32.show(id) ++ ":" ++ fields(headers) ++ events(rest)
    case Con{H.Headers{id, headers}, rest}:
      "H" ++ U32.show(id) ++ ":" ++ fields(headers) ++ events(rest)
    case Con{H.Chunk{id, bytes}, rest}:
      "D" ++ U32.show(id) ++ ":" ++ Bytes.to_hex(bytes) ++ ";" ++ events(rest)
    case Con{H.Trailers{id, headers}, rest}:
      "T" ++ U32.show(id) ++ ":" ++ fields(headers) ++ events(rest)
    case Con{H.Complete{id}, rest}:
      "E" ++ U32.show(id) ++ ";" ++ events(rest)
    case Con{H.Reset{id, code}, rest}:
      "R" ++ U32.show(id) ++ ":" ++ U32.show(code) ++ ";" ++ events(rest)
    case Con{H.Shutdown{last, code}, rest}:
      "G" ++ U32.show(last) ++ ":" ++ U32.show(code) ++ ";" ++ events(rest)
    case Con{H.Pong{bytes}, rest}:
      "P:" ++ Bytes.to_hex(bytes) ++ ";" ++ events(rest)

def expect(r: H.Reply, expected: String, count: Nat, active: U32, k: H.Client -> Bool) -> Bool:
  match r:
    case H.Failed{error}:
      False{}
    case H.Advanced{H.Client{input, streams, encoder, decoder, +control}, writes, got}:
      H.Control{next, remaining, frame_max, initial, max_streams, connection, recv,
        first, ack, continuation, goaway} = control
      Bool.and(String.eq(events(got), expected),
        Bool.and(Nat.is_eq(List.length(&1, Bytes.Bytes, writes), count),
          Bool.and(U32.is_eq(remaining, active), k(H.Client{input, streams, encoder, decoder, control}))))

def frame(kind: U32, flags: U32, id: U32, payload: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = payload
  Bytes.append(Bytes.set.u32be(Bytes.set(Bytes.set(Bytes.put(Bytes.new(9), 0, 3, True{}, len),
    3, kind), 4, flags), 5, id), Bytes.Bytes{len, buf})

def request(c: H.Client) -> H.Reply:
  H.client.request(c, [Hp.Field{":method", "GET", 0}, Hp.Field{":scheme", "https", 0},
    Hp.Field{":authority", "example.com", 0}, Hp.Field{":path", "/", 0}], Bytes.new(0))

def opened(r: H.Client & Bytes.Bytes, k: H.Client -> Bool) -> Bool:
  (c, preface) = r
  expect(request(c), "", 1n, 1, one => expect(request(one), "", 1n, 2, k))

def credit(r: H.Reply, expected: String, expected_events: String, active: U32,
    k: H.Client -> Bool) -> Bool:
  match r:
    case H.Advanced{c, writes, got}:
      Bool.and(String.eq(Bytes.to_hex(Bytes.concat(writes)), expected),
        expect(H.Advanced{c, Nil{}, got}, expected_events, 0n, active, k))
    case _:
      False{}

def incremental.finish(c: H.Client) -> Bool:
  credit(H.client.receive(c, frame(0, 0, 1, Bytes.from_string("three"))),
    "00000408000000000000000005" ++ "00000408000000000100000005", "D1:7468726565;", 2, more =>
    expect(H.client.receive(more, frame(0, 1, 1, Bytes.new(0))), "D1:;E1;", 0n, 1, next =>
      expect(H.client.receive(next, frame(1, 5, 3, Bytes.from_string("\u{0}\u{1}x\u{1}y"))),
        "T3:x=y;E3;", 0n, 0, done => True{})))

def incremental.pieces(c: H.Client) -> Bool:
  expect(H.client.receive(c, Bytes.from_string("\u{0}\u{0}\u{3}\u{0}\u{0}")), "", 0n, 2, next =>
    credit(H.client.receive(next, Bytes.append(Bytes.from_string("\u{0}\u{0}\u{0}\u{1}one"),
      frame(0, 0, 3, Bytes.from_string("two")))),
      "00000408000000000000000003" ++ "00000408000000000100000003" ++
      "00000408000000000000000003" ++ "00000408000000000300000003",
      "D1:6f6e65;D3:74776f;", 2, incremental.finish))

def incremental() -> Bool:
  opened(H.client.start(), c =>
    expect(H.client.receive(c, Bytes.concat([
      frame(4, 0, 0, Bytes.new(0)),
      frame(1, 4, 1, Bytes.from_string("H\u{3}100")),
      frame(1, 4, 1, Bytes.from_string("\u{88}")),
      frame(1, 4, 3, Bytes.from_string("\u{88}"))])),
      "I1::status=100;H1::status=200;H3::status=200;", 1n, 2, incremental.pieces))

def cancellation.closed(r: H.Reply) -> Bool:
  match r:
    case H.Failed{H.Error{5, False{}, 3}}:
      True{}
    case _:
      False{}

def cancellation.finish(c: H.Client) -> Bool:
  credit(H.client.receive(c, Bytes.concat([
    frame(9, 4, 1, Bytes.from_string("\u{1}y")),
    frame(0, 8, 1, Bytes.from_string("\u{1}z\u{0}")),
    frame(3, 0, 1, Bytes.set.u32be(Bytes.new(4), 0, 8)),
    frame(8, 0, 1, Bytes.set.u32be(Bytes.new(4), 0, 1)),
    frame(1, 4, 3, Bytes.from_string("\u{88}\u{be}"))])),
    "00000408000000000000000003", "H3::status=200;x=y;", 1, next =>
      credit(H.client.receive(next, frame(0, 1, 3, Bytes.from_string("ok"))),
        "00000408000000000000000002", "D3:6f6b;E3;", 0, done =>
          expect(request(done), "", 1n, 1, alive => cancellation.closed(H.client.cancel(alive, 3)))))

def cancellation.packet(r: H.Reply) -> Bool:
  match r:
    case H.Advanced{H.Client{input, Con{H.Stream{3, send_window, recv_window,
        local_end, remote_end, head, partial, outgoing}, Nil{}}, encoder, decoder,
        H.Control{next, 1, frame_max, initial, max_streams, connection, recv,
          first, ack, continuation, goaway}}, Con{packet, Nil{}}, Nil{}}:
      Bool.and(String.eq(Bytes.to_hex(packet), "00000403000000000100000008"),
        cancellation.finish(H.Client{input,
          [H.Stream{3, send_window, recv_window, local_end, remote_end, head, partial, outgoing}],
          encoder, decoder, H.Control{next, 1, frame_max, initial, max_streams, connection, recv,
            first, ack, continuation, goaway}}))
    case _:
      False{}

def cancellation.upload.finish(c: H.Client) -> Bool:
  credit(H.client.cancel(c, 1), "00000403000000000100000008", "", 1, next =>
    expect(H.client.receive(next, Bytes.concat([
      frame(8, 0, 1, Bytes.set.u32be(Bytes.new(4), 0, 6)),
      frame(8, 0, 0, Bytes.set.u32be(Bytes.new(4), 0, 6)),
      frame(1, 5, 3, Bytes.from_string("\u{88}"))])),
      "H3::status=200;E3;", 0n, 0, done => True{}))

def cancellation.upload(r: H.Client & Bytes.Bytes) -> Bool:
  (H.Client{input, streams, encoder, decoder,
    H.Control{next, active, frame_max, initial, max_streams, connection, recv,
      first, ack, continuation, goaway}}, preface) = r
  expect(H.client.request(H.Client{input, streams, encoder, decoder,
    H.Control{next, active, frame_max, 0, max_streams, connection, recv,
      first, ack, continuation, goaway}},
    [Hp.Field{":method", "POST", 0}, Hp.Field{":scheme", "https", 0},
      Hp.Field{":authority", "example.com", 0}, Hp.Field{":path", "/", 0}],
    Bytes.from_string("queued")), "", 1n, 1, one =>
      expect(request(one), "", 1n, 2, two =>
        expect(H.client.receive(two, frame(4, 0, 0, Bytes.new(0))), "", 1n, 2, cancellation.upload.finish)))

def cancellation() -> Bool:
  Bool.and(cancellation.upload(H.client.start()), opened(H.client.start(), c =>
    expect(H.client.receive(c, Bytes.concat([
      frame(4, 0, 0, Bytes.new(0)),
      frame(1, 0, 1, Bytes.from_string("@\u{1}x"))])), "", 1n, 2, next =>
        cancellation.packet(H.client.cancel(next, 1)))))
