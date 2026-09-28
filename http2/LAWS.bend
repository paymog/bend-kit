import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./http2.bend as H
import ./huffman.bend as Huff
import ./hpack.bend as Hp

def round.result(r: Result<&1, &1, H.Error, Bytes.Bytes>) -> H.Decode:
  match r:
    case Fail{e}:
      H.Bad{e}
    case Done{b}:
      H.parse(16384, b)

def round(f: H.Frame) -> H.Decode:
  round.result(H.encode(16384, f))

def raw(+len: U32, +kind: U32, +flags: U32, +stream: U32, payload: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.append(Bytes.set.u32be(Bytes.set(Bytes.set(Bytes.put(Bytes.new(9), 0, 3, True{}, len), 3, kind), 4, flags), 5, stream), payload)

law data:
  {round(H.Frame{0, 1, 1, Bytes.from_string("hi")}) == H.Got{H.Frame{0, 1, 1, Bytes.from_string("hi")}, Bytes.new(0)} : H.Decode}

law headers:
  {round(H.Frame{1, 4, 1, Bytes.from_string("h")}) == H.Got{H.Frame{1, 4, 1, Bytes.from_string("h")}, Bytes.new(0)} : H.Decode}

law priority:
  {round(H.Frame{2, 0, 3, Bytes.new(5)}) == H.Got{H.Frame{2, 0, 3, Bytes.new(5)}, Bytes.new(0)} : H.Decode}

law reset:
  {round(H.Frame{3, 0, 1, Bytes.new(4)}) == H.Got{H.Frame{3, 0, 1, Bytes.new(4)}, Bytes.new(0)} : H.Decode}

law settings:
  {round(H.Frame{4, 0, 0, Bytes.new(6)}) == H.Got{H.Frame{4, 0, 0, Bytes.new(6)}, Bytes.new(0)} : H.Decode}

law push:
  {round(H.Frame{5, 4, 1, Bytes.set.u32be(Bytes.new(4), 0, 2)}) == H.Got{H.Frame{5, 4, 1, Bytes.set.u32be(Bytes.new(4), 0, 2)}, Bytes.new(0)} : H.Decode}

law ping:
  {round(H.Frame{6, 1, 0, Bytes.from_string("12345678")}) == H.Got{H.Frame{6, 1, 0, Bytes.from_string("12345678")}, Bytes.new(0)} : H.Decode}

law goaway:
  {round(H.Frame{7, 0, 0, Bytes.new(8)}) == H.Got{H.Frame{7, 0, 0, Bytes.new(8)}, Bytes.new(0)} : H.Decode}

law window:
  {round(H.Frame{8, 0, 0, Bytes.set.u32be(Bytes.new(4), 0, 1)}) == H.Got{H.Frame{8, 0, 0, Bytes.set.u32be(Bytes.new(4), 0, 1)}, Bytes.new(0)} : H.Decode}

law continuation:
  {round(H.Frame{9, 4, 1, Bytes.from_string("h")}) == H.Got{H.Frame{9, 4, 1, Bytes.from_string("h")}, Bytes.new(0)} : H.Decode}

law data_padded:
  {round(H.Frame{0, 9, 1, Bytes.set(Bytes.new(3), 0, 1)}) == H.Got{H.Frame{0, 9, 1, Bytes.set(Bytes.new(3), 0, 1)}, Bytes.new(0)} : H.Decode}

law headers_padded_priority:
  {round(H.Frame{1, 44, 1, Bytes.set(Bytes.new(7), 0, 1)}) == H.Got{H.Frame{1, 44, 1, Bytes.set(Bytes.new(7), 0, 1)}, Bytes.new(0)} : H.Decode}

law push_padded:
  {round(H.Frame{5, 12, 1, Bytes.set(Bytes.set.u32be(Bytes.new(6), 1, 2), 0, 1)}) == H.Got{H.Frame{5, 12, 1, Bytes.set(Bytes.set.u32be(Bytes.new(6), 1, 2), 0, 1)}, Bytes.new(0)} : H.Decode}

law data_stream_zero:
  {H.parse(16384, raw(0, 0, 0, 0, Bytes.new(0))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law data_padding_missing:
  {H.parse(16384, raw(0, 0, 8, 1, Bytes.new(0))) == H.Bad{H.Error{6, False{}, 1}} : H.Decode}

law data_padding_overrun:
  {H.parse(16384, raw(2, 0, 8, 1, Bytes.set(Bytes.new(2), 0, 2))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law headers_stream_zero:
  {H.parse(16384, raw(0, 1, 0, 0, Bytes.new(0))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law headers_priority_short:
  {H.parse(16384, raw(4, 1, 32, 1, Bytes.new(4))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law headers_padding_overrun:
  {H.parse(16384, raw(2, 1, 8, 1, Bytes.set(Bytes.new(2), 0, 2))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law priority_size:
  {H.parse(16384, raw(4, 2, 0, 3, Bytes.new(4))) == H.Bad{H.Error{6, False{}, 3}} : H.Decode}

law priority_stream_zero:
  {H.parse(16384, raw(5, 2, 0, 0, Bytes.new(5))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law reset_size:
  {H.parse(16384, raw(3, 3, 0, 1, Bytes.new(3))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law reset_stream_zero:
  {H.parse(16384, raw(4, 3, 0, 0, Bytes.new(4))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law settings_stream:
  {H.parse(16384, raw(0, 4, 0, 1, Bytes.new(0))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law settings_ack_payload:
  {H.parse(16384, raw(6, 4, 1, 0, Bytes.new(6))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law settings_size:
  {H.parse(16384, raw(5, 4, 0, 0, Bytes.new(5))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law settings_push_value:
  {H.parse(16384, raw(6, 4, 0, 0, Bytes.set.u32be(Bytes.set.u16be(Bytes.new(6), 0, 2), 2, 2))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law settings_window_value:
  {H.parse(16384, raw(6, 4, 0, 0, Bytes.set.u32be(Bytes.set.u16be(Bytes.new(6), 0, 4), 2, 2147483648))) == H.Bad{H.Error{3, True{}, 0}} : H.Decode}

law settings_frame_value:
  {H.parse(16384, raw(6, 4, 0, 0, Bytes.set.u32be(Bytes.set.u16be(Bytes.new(6), 0, 5), 2, 16383))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law push_size:
  {H.parse(16384, raw(3, 5, 0, 1, Bytes.new(3))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law push_stream_zero:
  {H.parse(16384, raw(4, 5, 0, 0, Bytes.set.u32be(Bytes.new(4), 0, 2))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law push_promised_zero:
  {H.parse(16384, raw(4, 5, 0, 1, Bytes.new(4))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law push_padding_overrun:
  {H.parse(16384, raw(6, 5, 8, 1, Bytes.set(Bytes.set.u32be(Bytes.new(6), 1, 2), 0, 2))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law ping_size:
  {H.parse(16384, raw(7, 6, 0, 0, Bytes.new(7))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law ping_stream:
  {H.parse(16384, raw(8, 6, 0, 1, Bytes.new(8))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law goaway_size:
  {H.parse(16384, raw(7, 7, 0, 0, Bytes.new(7))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law goaway_stream:
  {H.parse(16384, raw(8, 7, 0, 1, Bytes.new(8))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law window_size:
  {H.parse(16384, raw(3, 8, 0, 3, Bytes.new(3))) == H.Bad{H.Error{6, False{}, 3}} : H.Decode}

law window_zero:
  {H.parse(16384, raw(4, 8, 0, 3, Bytes.new(4))) == H.Bad{H.Error{1, False{}, 3}} : H.Decode}

law continuation_stream:
  {H.parse(16384, raw(0, 9, 0, 0, Bytes.new(0))) == H.Bad{H.Error{1, True{}, 0}} : H.Decode}

law oversized:
  {H.parse(16384, raw(16385, 0, 0, 1, Bytes.new(0))) == H.Bad{H.Error{6, False{}, 1}} : H.Decode}

law oversized_headers:
  {H.parse(16384, raw(16385, 1, 0, 1, Bytes.new(0))) == H.Bad{H.Error{6, True{}, 0}} : H.Decode}

law partial_payload:
  {H.parse(16384, raw(2, 0, 0, 1, Bytes.from_string("x"))) == H.Need{raw(2, 0, 0, 1, Bytes.from_string("x"))} : H.Decode}

law unknown_type:
  {H.parse(16384, raw(1, 255, 128, 7, Bytes.from_string("x"))) == H.Got{H.Frame{255, 128, 7, Bytes.from_string("x")}, Bytes.new(0)} : H.Decode}

law reserved_stream_bit:
  {H.parse(16384, raw(0, 0, 0, 2147483649, Bytes.new(0))) == H.Got{H.Frame{0, 0, 1, Bytes.new(0)}, Bytes.new(0)} : H.Decode}

law unused_received_flag:
  {H.parse(16384, raw(0, 1, 128, 1, Bytes.new(0))) == H.Got{H.Frame{1, 128, 1, Bytes.new(0)}, Bytes.new(0)} : H.Decode}

law unused_sent_flag:
  {H.encode(16384, H.Frame{1, 128, 1, Bytes.new(0)}) == Fail{H.Error{1, True{}, 0}} : Result<&1, &1, H.Error, Bytes.Bytes>}

def huffman.hex(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Huff.decode(b)

law huffman_encode_www:
  {Huff.encode("www.example.com") == Bytes.from_hex("f1e3c2e5f23a6ba0ab90f4ff") : Maybe<&1, Bytes.Bytes>}

law huffman_decode_www:
  {huffman.hex(Bytes.from_hex("f1e3c2e5f23a6ba0ab90f4ff")) == Some{"www.example.com"} : Maybe<&2, String>}

law huffman_bad_padding:
  {huffman.hex(Bytes.from_hex("f1e3c2e5f23a6ba0ab90f4fe")) == None{} : Maybe<&2, String>}

law huffman_eos:
  {huffman.hex(Bytes.from_hex("ffffffff")) == None{} : Maybe<&2, String>}

def hp.hex(m: Maybe<&1, Hp.State & Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{(state, b)}:
      Some{Bytes.to_hex(b)}

def hp.decode(hex: String, st: Hp.State) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  Maybe.bind(&1, Bytes.Bytes, Hp.State & List<&2, Hp.Field>, Bytes.from_hex(hex), b => Hp.decode(b, st))

def hp.after(hex: String, m: Maybe<&1, Hp.State & List<&2, Hp.Field>>) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  match m:
    case None{}:
      None{}
    case Some{(state, fields)}:
      hp.decode(hex, state)

def hp.result(m: Maybe<&1, Hp.State & List<&2, Hp.Field>>) -> Maybe<&1, U32 & List<&2, Hp.Field>>:
  match m:
    case None{}:
      None{}
    case Some{(Hp.State{entries, size, capacity, allowed, pending, minimum}, fields)}:
      Some{(size, fields)}

law hpack_c2_indexed_encode:
  {hp.hex(Hp.encode([Hp.Field{"custom-key", "custom-header", 0}], False{}, Hp.new(4096))) == Some{"400a637573746f6d2d6b65790d637573746f6d2d686561646572"} : Maybe<&2, String>}

law hpack_c2_indexed_decode:
  {hp.result(hp.decode("400a637573746f6d2d6b65790d637573746f6d2d686561646572", Hp.new(4096))) == Some{(55, [Hp.Field{"custom-key", "custom-header", 0}])} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c2_without_encode:
  {hp.hex(Hp.encode([Hp.Field{":path", "/sample/path", 1}], False{}, Hp.new(4096))) == Some{"040c2f73616d706c652f70617468"} : Maybe<&2, String>}

law hpack_c2_without_decode:
  {hp.result(hp.decode("040c2f73616d706c652f70617468", Hp.new(4096))) == Some{(0, [Hp.Field{":path", "/sample/path", 1}])} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c2_never_encode:
  {hp.hex(Hp.encode([Hp.Field{"password", "secret", 2}], False{}, Hp.new(4096))) == Some{"100870617373776f726406736563726574"} : Maybe<&2, String>}

law hpack_c2_never_decode:
  {hp.result(hp.decode("100870617373776f726406736563726574", Hp.new(4096))) == Some{(0, [Hp.Field{"password", "secret", 2}])} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c2_static_encode:
  {hp.hex(Hp.encode([Hp.Field{":method", "GET", 0}], False{}, Hp.new(4096))) == Some{"82"} : Maybe<&2, String>}

law hpack_c2_static_decode:
  {hp.result(hp.decode("82", Hp.new(4096))) == Some{(0, [Hp.Field{":method", "GET", 0}])} : Maybe<&1, U32 & List<&2, Hp.Field>>}

def hp.next(fields: List<&2, Hp.Field>, huff: Bool, m: Maybe<&1, Hp.State & Bytes.Bytes>) -> Maybe<&1, Hp.State & Bytes.Bytes>:
  match m:
    case None{}:
      None{}
    case Some{(state, previous)}:
      Hp.encode(fields, huff, state)

def req.fields1() -> List<&2, Hp.Field>:
  [Hp.Field{":method", "GET", 0}, Hp.Field{":scheme", "http", 0}, Hp.Field{":path", "/", 0}, Hp.Field{":authority", "www.example.com", 0}]

def req.fields2() -> List<&2, Hp.Field>:
  List.append(&2, Hp.Field, req.fields1(), [Hp.Field{"cache-control", "no-cache", 0}])

def req.fields3() -> List<&2, Hp.Field>:
  [Hp.Field{":method", "GET", 0}, Hp.Field{":scheme", "https", 0}, Hp.Field{":path", "/index.html", 0}, Hp.Field{":authority", "www.example.com", 0}, Hp.Field{"custom-key", "custom-value", 0}]

def req.hex1(huff: Bool) -> String:
  match huff:
    case False{}:
      "828684410f7777772e6578616d706c652e636f6d"
    case True{}:
      "828684418cf1e3c2e5f23a6ba0ab90f4ff"

def req.hex2(huff: Bool) -> String:
  match huff:
    case False{}:
      "828684be58086e6f2d6361636865"
    case True{}:
      "828684be5886a8eb10649cbf"

def req.hex3(huff: Bool) -> String:
  match huff:
    case False{}:
      "828785bf400a637573746f6d2d6b65790c637573746f6d2d76616c7565"
    case True{}:
      "828785bf408825a849e95ba97d7f8925a849e95bb8e8b4bf"

def req.enc1(huff: Bool) -> Maybe<&1, Hp.State & Bytes.Bytes>:
  Hp.encode(req.fields1(), huff, Hp.new(4096))

def req.enc2(+huff: Bool) -> Maybe<&1, Hp.State & Bytes.Bytes>:
  hp.next(req.fields2(), huff, req.enc1(huff))

def req.enc3(+huff: Bool) -> Maybe<&1, Hp.State & Bytes.Bytes>:
  hp.next(req.fields3(), huff, req.enc2(huff))

def req.dec1(+huff: Bool) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  hp.decode(req.hex1(huff), Hp.new(4096))

def req.dec2(+huff: Bool) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  hp.after(req.hex2(huff), req.dec1(huff))

def req.dec3(+huff: Bool) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  hp.after(req.hex3(huff), req.dec2(huff))

def res.fields1() -> List<&2, Hp.Field>:
  [Hp.Field{":status", "302", 0}, Hp.Field{"cache-control", "private", 0}, Hp.Field{"date", "Mon, 21 Oct 2013 20:13:21 GMT", 0}, Hp.Field{"location", "https://www.example.com", 0}]

def res.fields2() -> List<&2, Hp.Field>:
  [Hp.Field{":status", "307", 0}, Hp.Field{"cache-control", "private", 0}, Hp.Field{"date", "Mon, 21 Oct 2013 20:13:21 GMT", 0}, Hp.Field{"location", "https://www.example.com", 0}]

def res.fields3() -> List<&2, Hp.Field>:
  [Hp.Field{":status", "200", 0}, Hp.Field{"cache-control", "private", 0}, Hp.Field{"date", "Mon, 21 Oct 2013 20:13:22 GMT", 0}, Hp.Field{"location", "https://www.example.com", 0}, Hp.Field{"content-encoding", "gzip", 0}, Hp.Field{"set-cookie", "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1", 0}]

def res.hex1(huff: Bool) -> String:
  match huff:
    case False{}:
      "4803333032580770726976617465611d4d6f6e2c203231204f637420323031332032303a31333a323120474d546e1768747470733a2f2f7777772e6578616d706c652e636f6d"
    case True{}:
      "488264025885aec3771a4b6196d07abe941054d444a8200595040b8166e082a62d1bff6e919d29ad171863c78f0b97c8e9ae82ae43d3"

def res.hex2(huff: Bool) -> String:
  match huff:
    case False{}:
      "4803333037c1c0bf"
    case True{}:
      "4883640effc1c0bf"

def res.hex3(huff: Bool) -> String:
  match huff:
    case False{}:
      "88c1611d4d6f6e2c203231204f637420323031332032303a31333a323220474d54c05a04677a69707738666f6f3d4153444a4b48514b425a584f5157454f50495541585157454f49553b206d61782d6167653d333630303b2076657273696f6e3d31"
    case True{}:
      "88c16196d07abe941054d444a8200595040b8166e084a62d1bffc05a839bd9ab77ad94e7821dd7f2e6c7b335dfdfcd5b3960d5af27087f3672c1ab270fb5291f9587316065c003ed4ee5b1063d5007"

def res.enc1(huff: Bool) -> Maybe<&1, Hp.State & Bytes.Bytes>:
  Hp.encode(res.fields1(), huff, Hp.new(256))

def res.enc2(+huff: Bool) -> Maybe<&1, Hp.State & Bytes.Bytes>:
  hp.next(res.fields2(), huff, res.enc1(huff))

def res.enc3(+huff: Bool) -> Maybe<&1, Hp.State & Bytes.Bytes>:
  hp.next(res.fields3(), huff, res.enc2(huff))

def res.dec1(+huff: Bool) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  hp.decode(res.hex1(huff), Hp.new(256))

def res.dec2(+huff: Bool) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  hp.after(res.hex2(huff), res.dec1(huff))

def res.dec3(+huff: Bool) -> Maybe<&1, Hp.State & List<&2, Hp.Field>>:
  hp.after(res.hex3(huff), res.dec2(huff))

law hpack_c3_1_encode:
  {hp.hex(req.enc1(False{})) == Some{req.hex1(False{})} : Maybe<&2, String>}

law hpack_c3_1_decode:
  {hp.result(req.dec1(False{})) == Some{(57, req.fields1())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c3_2_encode:
  {hp.hex(req.enc2(False{})) == Some{req.hex2(False{})} : Maybe<&2, String>}

law hpack_c3_2_decode:
  {hp.result(req.dec2(False{})) == Some{(110, req.fields2())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c3_3_encode:
  {hp.hex(req.enc3(False{})) == Some{req.hex3(False{})} : Maybe<&2, String>}

law hpack_c3_3_decode:
  {hp.result(req.dec3(False{})) == Some{(164, req.fields3())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c4_1_encode:
  {hp.hex(req.enc1(True{})) == Some{req.hex1(True{})} : Maybe<&2, String>}

law hpack_c4_1_decode:
  {hp.result(req.dec1(True{})) == Some{(57, req.fields1())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c4_2_encode:
  {hp.hex(req.enc2(True{})) == Some{req.hex2(True{})} : Maybe<&2, String>}

law hpack_c4_2_decode:
  {hp.result(req.dec2(True{})) == Some{(110, req.fields2())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c4_3_encode:
  {hp.hex(req.enc3(True{})) == Some{req.hex3(True{})} : Maybe<&2, String>}

law hpack_c4_3_decode:
  {hp.result(req.dec3(True{})) == Some{(164, req.fields3())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c5_1_encode:
  {hp.hex(res.enc1(False{})) == Some{res.hex1(False{})} : Maybe<&2, String>}

law hpack_c5_1_decode:
  {hp.result(res.dec1(False{})) == Some{(222, res.fields1())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c5_2_encode:
  {hp.hex(res.enc2(False{})) == Some{res.hex2(False{})} : Maybe<&2, String>}

law hpack_c5_2_decode:
  {hp.result(res.dec2(False{})) == Some{(222, res.fields2())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c5_3_encode:
  {hp.hex(res.enc3(False{})) == Some{res.hex3(False{})} : Maybe<&2, String>}

law hpack_c5_3_decode:
  {hp.result(res.dec3(False{})) == Some{(215, res.fields3())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c6_1_encode:
  {hp.hex(res.enc1(True{})) == Some{res.hex1(True{})} : Maybe<&2, String>}

law hpack_c6_1_decode:
  {hp.result(res.dec1(True{})) == Some{(222, res.fields1())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c6_2_encode:
  {hp.hex(res.enc2(True{})) == Some{res.hex2(True{})} : Maybe<&2, String>}

law hpack_c6_2_decode:
  {hp.result(res.dec2(True{})) == Some{(222, res.fields2())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_c6_3_encode:
  {hp.hex(res.enc3(True{})) == Some{res.hex3(True{})} : Maybe<&2, String>}

law hpack_c6_3_decode:
  {hp.result(res.dec3(True{})) == Some{(215, res.fields3())} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_bad_zero_index:
  {hp.decode("80", Hp.new(4096)) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_bad_dynamic_index:
  {hp.decode("be", Hp.new(4096)) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_short_integer:
  {hp.decode("ff", Hp.new(4096)) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_overflow_integer:
  {hp.decode("ff8080808010", Hp.new(4096)) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_bad_huffman:
  {hp.decode("4081ff00", Hp.new(4096)) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_late_size_update:
  {hp.decode("8220", Hp.new(4096)) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_large_size_update:
  {hp.decode("3fe201", Hp.new(256)) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_missing_size_update:
  {hp.decode("82", Hp.set_limit(128, Hp.new(256))) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_skipped_minimum_size:
  {hp.decode("3f61", Hp.set_limit(128, Hp.set_limit(64, Hp.new(256)))) == None{} : Maybe<&1, Hp.State & List<&2, Hp.Field>>}

law hpack_two_size_updates_encode:
  {hp.hex(Hp.encode(Nil{}, False{}, Hp.set_limit(128, Hp.set_limit(64, Hp.new(256))))) == Some{"3f213f61"} : Maybe<&2, String>}

law hpack_two_size_updates_decode:
  {hp.result(hp.decode("3f213f6182", Hp.set_limit(128, Hp.set_limit(64, Hp.new(256))))) == Some{(0, [Hp.Field{":method", "GET", 0}])} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_oversize_evicts:
  {hp.result(hp.decode("400a637573746f6d2d6b65790d637573746f6d2d686561646572", Hp.new(0))) == Some{(0, [Hp.Field{"custom-key", "custom-header", 0}])} : Maybe<&1, U32 & List<&2, Hp.Field>>}

law hpack_without_index_even_if_static:
  {hp.hex(Hp.encode([Hp.Field{":method", "GET", 1}], False{}, Hp.new(4096))) == Some{"0203474554"} : Maybe<&2, String>}

law hpack_never_index_even_if_static:
  {hp.hex(Hp.encode([Hp.Field{":path", "/", 2}], False{}, Hp.new(4096))) == Some{"14012f"} : Maybe<&2, String>}

law hpack_invalid_octet:
  {hp.hex(Hp.encode([Hp.Field{"x", "€", 0}], False{}, Hp.new(4096))) == None{} : Maybe<&2, String>}

def client.open(r: H.Client & Bytes.Bytes) -> H.Client:
  (c, preface) = r
  c

def client.preface(r: H.Client & Bytes.Bytes) -> String:
  (c, preface) = r
  Bytes.to_hex(preface)

def client.settings.acked(r: H.Reply) -> Bool:
  match r:
    case H.Ready{H.Client{input, streams, encoder, decoder,
        H.Control{next, active, frame_max, initial, max_streams, connection, recv,
          first, ack, continuation, goaway}}, Con{packet, Nil{}}, Nil{}}:
      Bool.and(Bool.not(first), Bool.and(ack,
        String.eq(Bytes.to_hex(packet), "000000040100000000")))
    case _:
      False{}

law client_preface:
  {client.preface(H.client.start()) == "505249202a20485454502f322e300d0a0d0a534d0d0a0d0a000006040000000000000200000000" : String}

law client_settings_ack:
  {client.settings.acked(H.client.receive(client.open(H.client.start()), raw(0, 4, 0, 0, Bytes.new(0)))) == True{} : Bool}

def client.fields() -> List<&2, Hp.Field>:
  [Hp.Field{":method", "GET", 0}, Hp.Field{":scheme", "https", 0},
    Hp.Field{":authority", "www.example.com", 0}, Hp.Field{":path", "/", 0}]

def client.fixture(r: H.Client & Bytes.Bytes) -> H.Reply:
  H.client.request(client.open(r), client.fields(), Bytes.new(0))

def client.feed(r: H.Reply, b: Bytes.Bytes) -> H.Reply:
  match r:
    case H.Failed{error}:
      H.Failed{error}
    case H.Ready{c, writes, events}:
      H.client.receive(c, b)

def client.rejected(r: H.Reply) -> Bool:
  match r:
    case H.Failed{H.Error{7, True{}, 0}}:
      True{}
    case _:
      False{}

def client.goaway.result(r: H.Reply) -> Bool:
  match r:
    case H.Ready{H.Client{input, streams, encoder, decoder,
        H.Control{next, +active, frame_max, initial, max_streams, connection, recv,
          first, ack, continuation, Some{+last}}},
        Con{ack_packet, Nil{}}, Con{H.Shutdown{+stopped, +code}, Con{H.Reset{+id, +reason}, Nil{}}}}:
      Bool.and(U32.is_eq(active, 0), Bool.and(U32.is_eq(last, 0),
        Bool.and(U32.is_eq(stopped, 0), Bool.and(U32.is_eq(code, 0),
          Bool.and(U32.is_eq(id, 1), U32.is_eq(reason, 7))))))
    case _:
      False{}

def client.stall.start(r: H.Client & Bytes.Bytes) -> H.Reply:
  (H.Client{input, streams, encoder, decoder,
    H.Control{next, active, frame_max, initial, max_streams, window, recv,
      first, ack, continuation, goaway}}, preface) = r
  H.client.request(H.Client{input, streams, encoder, decoder,
    H.Control{next, active, frame_max, initial, max_streams, 0, recv,
      first, ack, continuation, goaway}}, client.fields(), Bytes.from_string("abc"))

def client.stall.header(d: H.Decode) -> Bool:
  match d:
    case H.Got{H.Frame{1, 4, 1, payload}, Bytes.Bytes{0, buf}}:
      True{}
    case _:
      False{}

def client.stall.result(r: H.Reply) -> Bool:
  match r:
    case H.Ready{H.Client{input, Con{H.Stream{id, send_window, recv_window, +local_end,
        remote_end, head, headers, partial, body, Bytes.Bytes{+remaining, buf}}, Nil{}},
        encoder, decoder, control}, Con{packet, Nil{}}, Nil{}}:
      Bool.and(U32.is_eq(remaining, 3),
        Bool.and(Bool.not(local_end), client.stall.header(H.parse(16384, packet))))
    case _:
      False{}

def client.stall.data(d: H.Decode) -> Bool:
  match d:
    case H.Got{H.Frame{0, 1, 1, payload}, Bytes.Bytes{0, buf}}:
      String.eq(Bytes.to_hex(payload), "616263")
    case _:
      False{}

def client.stall.resumed(r: H.Reply) -> Bool:
  match r:
    case H.Ready{H.Client{input, Con{H.Stream{id, send_window, recv_window, +local_end,
        remote_end, head, headers, partial, body, Bytes.Bytes{+remaining, buf}}, Nil{}},
        encoder, decoder, control}, Con{ack_packet, Con{data_packet, Nil{}}}, Nil{}}:
      Bool.and(U32.is_eq(remaining, 0),
        Bool.and(local_end, client.stall.data(H.parse(16384, data_packet))))
    case _:
      False{}

law client_goaway:
  {client.goaway.result(client.feed(client.fixture(H.client.start()),
    Bytes.append(raw(0, 4, 0, 0, Bytes.new(0)), raw(8, 7, 0, 0, Bytes.new(8))))) == True{} : Bool}

law client_flow_stall:
  {client.stall.result(client.stall.start(H.client.start())) == True{} : Bool}

law client_flow_resume:
  {client.stall.resumed(client.feed(client.stall.start(H.client.start()),
    Bytes.append(raw(0, 4, 0, 0, Bytes.new(0)),
      raw(4, 8, 0, 0, Bytes.set.u32be(Bytes.new(4), 0, 3))))) == True{} : Bool}

def client.goaway.blocked(r: H.Reply) -> Bool:
  match r:
    case H.Failed{error}:
      False{}
    case H.Ready{c, writes, events}:
      client.rejected(H.client.request(c, client.fields(), Bytes.new(0)))

def client.response.result(r: H.Reply) -> Bool:
  match r:
    case H.Ready{H.Client{input, streams, encoder, decoder,
        H.Control{next, +active, frame_max, initial, max_streams, connection, recv,
          first, ack, continuation, goaway}},
        Con{ack_packet, Nil{}},
        Con{H.Response{1, Con{Hp.Field{":status", "200", 0}, Nil{}}, Bytes.Bytes{0, buf}}, Nil{}}}:
      U32.is_eq(active, 0)
    case _:
      False{}

def client.protocol.error(r: H.Reply) -> Bool:
  match r:
    case H.Failed{H.Error{1, True{}, 0}}:
      True{}
    case _:
      False{}

law client_goaway_blocks_request:
  {client.goaway.blocked(client.feed(client.fixture(H.client.start()),
    Bytes.append(raw(0, 4, 0, 0, Bytes.new(0)), raw(8, 7, 0, 0, Bytes.new(8))))) == True{} : Bool}

law client_header_continuation:
  {client.response.result(client.feed(client.fixture(H.client.start()),
    Bytes.concat([raw(0, 4, 0, 0, Bytes.new(0)),
      raw(0, 1, 1, 1, Bytes.new(0)),
      raw(1, 9, 4, 1, Bytes.set(Bytes.new(1), 0, 136))]))) == True{} : Bool}

law client_continuation_interleaving:
  {client.protocol.error(client.feed(client.fixture(H.client.start()),
    Bytes.concat([raw(0, 4, 0, 0, Bytes.new(0)),
      raw(0, 1, 1, 1, Bytes.new(0)),
      raw(8, 6, 0, 0, Bytes.from_string("12345678"))]))) == True{} : Bool}

def client.response.interim(r: H.Reply) -> Bool:
  match r:
    case H.Ready{H.Client{input, streams, encoder, decoder,
        H.Control{next, +active, frame_max, initial, max_streams, connection, recv,
          first, ack, continuation, goaway}},
        Con{ack_packet, Nil{}},
        Con{H.Response{1, Con{Hp.Field{":status", "100", 0}, Nil{}}, Bytes.Bytes{0, first_body}},
          Con{H.Response{1, Con{Hp.Field{":status", "200", 0}, Nil{}}, Bytes.Bytes{0, final_body}}, Nil{}}}}:
      U32.is_eq(active, 0)
    case _:
      False{}

law client_interim_then_final:
  {client.response.interim(client.feed(client.fixture(H.client.start()),
    Bytes.concat([raw(0, 4, 0, 0, Bytes.new(0)),
      raw(5, 1, 4, 1, Bytes.from_string("H\u{3}100")),
      raw(1, 1, 5, 1, Bytes.set(Bytes.new(1), 0, 136))]))) == True{} : Bool}

law client_window_update_overflow:
  {H.client.window.plus(2147483647, 1) == None{} : Maybe<&1, U32>}

law client_window_update_negative:
  {H.client.window.plus(4294967295, 1) == Some{0} : Maybe<&1, U32>}

law client_settings_window_overflow:
  {H.client.window.adjust(2147483647, 1) == None{} : Maybe<&1, U32>}

law client_settings_window_negative:
  {H.client.window.adjust(0, 4294967295) == Some{4294967295} : Maybe<&1, U32>}

law client_settings_window_underflow:
  {H.client.window.adjust(2147483648, 4294967295) == None{} : Maybe<&1, U32>}

law client_settings_window_recovers:
  {H.client.window.adjust(4294967295, 1) == Some{0} : Maybe<&1, U32>}
