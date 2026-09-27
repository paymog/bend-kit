import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./http2.bend as H

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
