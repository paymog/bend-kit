import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-mathlib@0.7.2.0/nat.bend as MNat
import ./websocket.bend as WS

def of(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def octets(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, octets(t)}

def unhex(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case None{}:
      Bytes.new(0)
    case Some{b}:
      b

# RFC 6455 §5.7: "Hello" masked with 37 fa 21 3d.
def masked_hello() -> Bytes.Bytes:
  of(octets([129, 133, 55, 250, 33, 61, 127, 159, 77, 81, 88]))

# The octets of a cursor not decoded yet.
def left(c: Bytes.Cursor) -> Bytes.Bytes:
  Bytes.Cursor{b, +pos, start, +end} = c
  Bytes.snd(Bytes.slice(b, pos, (end - pos : U32)))

# WS.parse on b, with each cursor shown as the octets it has left.
def parse.seen(d: WS.Decode<Bytes.Bytes, Bytes.Cursor>) -> WS.Decode<Bytes.Bytes, Bytes.Bytes>:
  match d:
    case WS.Need{c}:
      WS.Need{left(c)}
    case WS.Got{f, c}:
      WS.Got{f, left(c)}
    case WS.Bad{code, why}:
      WS.Bad{code, why}

def parse(+masked: Bool, +max: U32, b: Bytes.Bytes) -> WS.Decode<Bytes.Bytes, Bytes.Bytes>:
  parse.seen(WS.parse(masked, max, Bytes.Cursor.new(b)))

def reply(+extra: String) -> String:
  "HTTP/1.1 101 Switching Protocols\r\nUpgrade: WebSocket\r\nConnection: keep-alive, Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" ++ extra

# RFC 6455 §1.3 and §4.2.2: the sample key, the octets hashed, and the digest's base64.
law accept_input:
  {Bytes.to_string(WS.accept.input("dGhlIHNhbXBsZSBub25jZQ==")) == "dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11" : String}

law accept_rfc_sample:
  {WS.accept.of(unhex(Bytes.from_hex("b37a4f2cc0624f1690f64606cf385945b2bec4ea"))) == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" : String}

law key_rfc_sample:
  {WS.key.of(of("the sample nonce")) == "dGhlIHNhbXBsZSBub25jZQ==" : String}

law request_rfc:
  {WS.request("server.example.com", "/chat", "dGhlIHNhbXBsZSBub25jZQ==") == Done{of("GET /chat HTTP/1.1\r\nHost: server.example.com\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

# CR or LF in a caller's string would inject headers.
law request_host_crlf:
  {WS.request("a.example\r\nX-Evil: 1", "/chat", "dGhlIHNhbXBsZSBub25jZQ==") == Fail{(22, "host is not visible ASCII")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law request_path_crlf:
  {WS.request("a.example", "/chat\r\nX-Evil: 1", "dGhlIHNhbXBsZSBub25jZQ==") == Fail{(22, "path is not an origin-form target")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law request_path_absolute:
  {WS.request("a.example", "http://a.example/chat", "dGhlIHNhbXBsZSBub25jZQ==") == Fail{(22, "path is not an origin-form target")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law request_key_space:
  {WS.request("a.example", "/chat", "a b") == Fail{(22, "key is not visible ASCII")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law check_accepts:
  {WS.check(reply(""), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Done{Unit{}} : Result<&1, &1, U32 & String, Unit>}

law check_status:
  {WS.check("HTTP/1.1 200 OK\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "status line is not HTTP/1.1 101")} : Result<&1, &1, U32 & String, Unit>}

law check_no_upgrade:
  {WS.check("HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "Upgrade is not one websocket")} : Result<&1, &1, U32 & String, Unit>}

law check_no_connection:
  {WS.check("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: keep-alive\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "Connection lacks Upgrade")} : Result<&1, &1, U32 & String, Unit>}

law check_accept_mismatch:
  {WS.check(reply(""), "x3JJHMbDL1EzLkh9GBhXDw==") == Fail{(1002, "Sec-WebSocket-Accept is not one match for the key")} : Result<&1, &1, U32 & String, Unit>}

law check_duplicate_accept:
  {WS.check(reply("\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "Sec-WebSocket-Accept is not one match for the key")} : Result<&1, &1, U32 & String, Unit>}

law check_duplicate_upgrade:
  {WS.check(reply("\r\nUpgrade: websocket"), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "Upgrade is not one websocket")} : Result<&1, &1, U32 & String, Unit>}

# Connection is a list header, so its tokens may span lines.
law check_connection_lines:
  {WS.check("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: keep-alive\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Done{Unit{}} : Result<&1, &1, U32 & String, Unit>}

law check_leading_line:
  {WS.check("\r\n" ++ reply(""), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "status line is not HTTP/1.1 101")} : Result<&1, &1, U32 & String, Unit>}

law check_http10:
  {WS.check("HTTP/1.0 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "status line is not HTTP/1.1 101")} : Result<&1, &1, U32 & String, Unit>}

law check_folded_line:
  {WS.check(reply("\r\n x-folded: 1"), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "malformed header line")} : Result<&1, &1, U32 & String, Unit>}

law check_bare_line:
  {WS.check(reply("\r\nnot a header"), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "malformed header line")} : Result<&1, &1, U32 & String, Unit>}

law check_extension:
  {WS.check(reply("\r\nSec-WebSocket-Extensions: permessage-deflate"), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "unrequested extension")} : Result<&1, &1, U32 & String, Unit>}

law check_protocol:
  {WS.check(reply("\r\nSec-WebSocket-Protocol: chat"), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == Fail{(1002, "unrequested subprotocol")} : Result<&1, &1, U32 & String, Unit>}

# Frames the server sends right after its head stay as input.
law split_leftover:
  {WS.split(of("HTTP/1.1 101 X\r\nA: b\r\n\r\n\u{81}\u{0}")) == WS.Found{"HTTP/1.1 101 X\r\nA: b", of("\u{81}\u{0}")} : WS.Split}

law split_short:
  {WS.split(of("HTTP/1.1 101 X\r\n")) == WS.Short{of("HTTP/1.1 101 X\r\n")} : WS.Split}

law encode_masked_hello:
  {WS.encode(WS.Frame{True{}, 1, of("Hello")}, Some{1025636919}) == Done{masked_hello()} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law encode_hello:
  {WS.encode(WS.Frame{True{}, 1, of("Hello")}, None{}) == Done{of("\u{81}\u{5}Hello")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law encode_256:
  {WS.encode(WS.Frame{True{}, 2, Bytes.new(256)}, None{}) == Done{Bytes.set.u16be(Bytes.set(Bytes.set(Bytes.new(260), 0, 130), 1, 126), 2, 256)} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law encode_control_long:
  {WS.encode(WS.Frame{True{}, 9, Bytes.new(126)}, None{}) == Fail{(1002, "control frame over 125 bytes")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law encode_control_fragment:
  {WS.encode(WS.Frame{False{}, 10, Bytes.new(0)}, None{}) == Fail{(1002, "fragmented control frame")} : Result<&1, &1, U32 & String, Bytes.Bytes>}

law parse_hello:
  {parse(False{}, 1024, of("\u{81}\u{5}Hello")) == WS.Got{WS.Frame{True{}, 1, of("Hello")}, Bytes.new(0)} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_masked_hello:
  {parse(True{}, 1024, masked_hello()) == WS.Got{WS.Frame{True{}, 1, of("Hello")}, Bytes.new(0)} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_masked_on_client:
  {parse(False{}, 1024, masked_hello()) == WS.Bad{1002, "mask bit does not match the peer's role"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_unmasked_on_server:
  {parse(True{}, 1024, of("\u{81}\u{5}Hello")) == WS.Bad{1002, "mask bit does not match the peer's role"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_need_header:
  {parse(False{}, 1024, of("\u{81}")) == WS.Need{of("\u{81}")} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_need_payload:
  {parse(False{}, 1024, of("\u{81}\u{5}Hel")) == WS.Need{of("\u{81}\u{5}Hel")} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_rest:
  {parse(False{}, 1024, of("\u{1}\u{3}Hel\u{80}\u{2}lo")) == WS.Got{WS.Frame{False{}, 1, of("Hel")}, of("\u{80}\u{2}lo")} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_256:
  {parse(False{}, 1024, Bytes.set.u16be(Bytes.set(Bytes.set(Bytes.new(260), 0, 130), 1, 126), 2, 256)) == WS.Got{WS.Frame{True{}, 2, Bytes.new(256)}, Bytes.new(0)} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_reserved:
  {parse(False{}, 1024, of("\u{c1}\u{0}")) == WS.Bad{1002, "reserved bits set"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_opcode:
  {parse(False{}, 1024, of("\u{83}\u{0}")) == WS.Bad{1002, "unknown opcode"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_fragmented_ping:
  {parse(False{}, 1024, of("\u{9}\u{0}")) == WS.Bad{1002, "fragmented control frame"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

# The header is judged before its payload arrives.
law parse_long_ping:
  {parse(False{}, 1024, of("\u{89}\u{7e}\u{0}\u{7e}")) == WS.Bad{1002, "control frame over 125 bytes"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_too_big:
  {parse(False{}, 4, of("\u{81}\u{5}Hello")) == WS.Bad{1009, "frame over the size limit"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law parse_64bit_high:
  {parse(False{}, 1024, of("\u{82}\u{7f}\u{0}\u{0}\u{0}\u{1}\u{0}\u{0}\u{0}\u{0}")) == WS.Bad{1009, "frame over the size limit"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

# A length of 2^32 or more is over every max, even the largest; its low word is not the length.
law parse_64bit_high_max:
  {parse(False{}, 4294967295, of("\u{82}\u{7f}\u{0}\u{0}\u{0}\u{1}\u{0}\u{0}\u{0}\u{0}")) == WS.Bad{1009, "frame over the size limit"} : WS.Decode<Bytes.Bytes, Bytes.Bytes>}

law mask_involution:
  {WS.mask(1025636919, WS.mask(1025636919, of("Hello"))) == of("Hello") : Bytes.Bytes}

# Bytes past len stay 0, so a masked buffer equals one built from its octets.
law mask_tail_zero:
  {WS.mask(1025636919, of("Hel")) == of(octets([127, 159, 77])) : Bytes.Bytes}

law feed_fragment_start:
  {WS.feed(WS.Idle{}, WS.Frame{False{}, 1, of("Hel")}, 1024) == Done{(WS.Open{1, of("Hel")}, WS.More{})} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_fragment_end:
  {WS.feed(WS.Open{1, of("Hel")}, WS.Frame{True{}, 0, of("lo")}, 1024) == Done{(WS.Idle{}, WS.Message{1, of("Hello")})} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_control_between:
  {WS.feed(WS.Open{1, of("Hel")}, WS.Frame{True{}, 9, of("x")}, 1024) == Done{(WS.Open{1, of("Hel")}, WS.Control{9, of("x")})} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_orphan_continuation:
  {WS.feed(WS.Idle{}, WS.Frame{True{}, 0, of("lo")}, 1024) == Fail{(1002, "continuation frame without a message")} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_data_inside_fragments:
  {WS.feed(WS.Open{1, of("Hel")}, WS.Frame{True{}, 2, of("x")}, 1024) == Fail{(1002, "data frame inside a fragmented message")} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_utf8:
  {WS.feed(WS.Idle{}, WS.Frame{True{}, 1, of(octets([206, 186, 207, 140, 207, 131, 206, 188, 206, 181]))}, 1024) == Done{(WS.Idle{}, WS.Message{1, of(octets([206, 186, 207, 140, 207, 131, 206, 188, 206, 181]))})} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_utf8_four_byte:
  {WS.feed(WS.Idle{}, WS.Frame{True{}, 1, of(octets([240, 159, 152, 128]))}, 1024) == Done{(WS.Idle{}, WS.Message{1, of(octets([240, 159, 152, 128]))})} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_overlong:
  {WS.feed(WS.Idle{}, WS.Frame{True{}, 1, of(octets([192, 128]))}, 1024) == Fail{(1007, "text message is not UTF-8")} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_truncated:
  {WS.feed(WS.Idle{}, WS.Frame{True{}, 1, of(octets([226, 130]))}, 1024) == Fail{(1007, "text message is not UTF-8")} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_surrogate:
  {WS.feed(WS.Idle{}, WS.Frame{True{}, 1, of(octets([237, 160, 128]))}, 1024) == Fail{(1007, "text message is not UTF-8")} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_binary_any_octets:
  {WS.feed(WS.Idle{}, WS.Frame{True{}, 2, of(octets([192, 128]))}, 1024) == Done{(WS.Idle{}, WS.Message{2, of(octets([192, 128]))})} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law feed_message_too_big:
  {WS.feed(WS.Open{2, of("abc")}, WS.Frame{True{}, 0, of("de")}, 4) == Fail{(1009, "message over the size limit")} : Result<&1, &1, U32 & String, WS.Partial & WS.Msg>}

law close_payload:
  {WS.close.payload(1000, of("bye")) == of("\u{3}\u{e8}bye") : Bytes.Bytes}

law close_parse:
  {WS.close.parse(of("\u{3}\u{e8}bye")) == Done{(1000, of("bye"))} : Result<&1, &1, U32 & String, U32 & Bytes.Bytes>}

law close_empty:
  {WS.close.parse(Bytes.new(0)) == Done{(1005, Bytes.new(0))} : Result<&1, &1, U32 & String, U32 & Bytes.Bytes>}

law close_one_byte:
  {WS.close.parse(of("\u{3}")) == Fail{(1002, "close payload of one byte")} : Result<&1, &1, U32 & String, U32 & Bytes.Bytes>}

law close_reserved_code:
  {WS.close.parse(of("\u{3}\u{ed}")) == Fail{(1002, "invalid close code")} : Result<&1, &1, U32 & String, U32 & Bytes.Bytes>}

law close_bad_reason:
  {WS.close.parse(of(octets([3, 232, 192]))) == Fail{(1007, "close reason is not UTF-8")} : Result<&1, &1, U32 & String, U32 & Bytes.Bytes>}

# Incremental decoding. The laws below hold for WS.list.next, the decoder over a list of
# octets (each below 256). WS.parse runs the same WS.next over Bytes, and assumes the
# Bytes operations act as the list ones do; check.bend tests that on split inputs.

def cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

# What the decoder emits from its input in at most n frames, and where it stops: it needs
# more input (with the frames it may still emit), its frame budget ran out with a frame
# ready, or the input is malformed.
type Run is Type:
  RFrame{frame: WS.Frame<List<&2, U32>>, more: Run}
  RNeed{fuel: Nat, rest: List<&2, U32>}
  RFull{frame: WS.Frame<List<&2, U32>>, rest: List<&2, U32>}
  RBad{code: U32, why: String}

# d is WS.list.next of xs.
def drain(n: Nat, +masked: Bool, +max: U32, +xs: List<&2, U32>, d: WS.Decode<List<&2, U32>, List<&2, U32>>) -> Run:
  match n:
    case 0n:
      match d:
        case WS.Need{b}:
          RNeed{0n, xs}
        case WS.Got{f, r}:
          RFull{f, r}
        case WS.Bad{code, why}:
          RBad{code, why}
    case 1n+p:
      match d:
        case WS.Need{b}:
          RNeed{1n+p, xs}
        case WS.Got{f, +r}:
          RFrame{f, drain(p, masked, max, r, WS.list.next(masked, max, r))}
        case WS.Bad{code, why}:
          RBad{code, why}

# The observation of feeding xs to a decoder with an empty buffer.
def frames(n: Nat, +masked: Bool, +max: U32, +xs: List<&2, U32>) -> Run:
  drain(n, masked, max, xs, WS.list.next(masked, max, xs))

# Feeds ys where the run stopped: a stopped decoder keeps its rest and its fault.
def resume(run: Run, +masked: Bool, +max: U32, +ys: List<&2, U32>) -> Run:
  match run:
    case RFrame{f, more}:
      RFrame{f, resume(more, masked, max, ys)}
    case RNeed{k, r}:
      frames(k, masked, max, cat(r, ys))
    case RFull{f, r}:
      RFull{f, cat(r, ys)}
    case RBad{code, why}:
      RBad{code, why}

def emitted(run: Run) -> Nat:
  match run:
    case RFrame{f, more}:
      1n+emitted(more)
    case _:
      0n

# Read boundaries do not change what is decoded: feeding xs then ys is feeding xs ++ ys,
# frame for frame, with the same rest and the same fault.
law feed_split:
  for n: Nat
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {resume(frames(n, masked, max, xs), masked, max, ys) == frames(n, masked, max, cat(xs, ys)) : Run}

law feed_empty:
  for n: Nat
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  {resume(frames(n, masked, max, xs), masked, max, Nil{}) == frames(n, masked, max, xs) : Run}

# Each frame consumes input, so feeding nothing new cannot emit frames without end.
law frames_bound:
  for n: Nat
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  MNat.le(emitted(frames(n, masked, max, xs)), List.length(&2, U32, xs))

# A frame stays decoded when more octets arrive; they join its rest.
law got_more:
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for -f: WS.Frame<List<&2, U32>>
  for +r: List<&2, U32>
  for e: {WS.list.next(masked, max, xs) == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  {WS.list.next(masked, max, cat(xs, ys)) == WS.Got{f, cat(r, ys)} : WS.Decode<List<&2, U32>, List<&2, U32>>}

# Malformed input stays malformed whatever comes next; only Need can change.
law bad_more:
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for +code: U32
  for +why: String
  for e: {WS.list.next(masked, max, xs) == WS.Bad{code, why} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  {WS.list.next(masked, max, cat(xs, ys)) == WS.Bad{code, why} : WS.Decode<List<&2, U32>, List<&2, U32>>}

# A frame consumes a prefix of its input, and the rest is the input after it.
law got_suffix:
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  for -f: WS.Frame<List<&2, U32>>
  for +r: List<&2, U32>
  for e: {WS.list.next(masked, max, xs) == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  exs k: Nat
  {cat(List.take(&2, U32, xs, k), r) == xs : List<&2, U32>}

law got_progress:
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  for -f: WS.Frame<List<&2, U32>>
  for +r: List<&2, U32>
  for e: {WS.list.next(masked, max, xs) == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  MNat.lt(List.length(&2, U32, r), List.length(&2, U32, xs))

# A payload is never longer than max.
law got_limit:
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  for +fin: Bool
  for +op: U32
  for +p: List<&2, U32>
  for +r: List<&2, U32>
  for e: {WS.list.next(masked, max, xs) == WS.Got{WS.Frame{fin, op, p}, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  MNat.le(List.length(&2, U32, p), U32.to_nat(max))

# Input that needs more octets is shorter than a 14-octet header plus max, so the buffer is bounded.
law need_bound:
  for +masked: Bool
  for +max: U32
  for +xs: List<&2, U32>
  for +b: List<&2, U32>
  for e: {WS.list.next(masked, max, xs) == WS.Need{b} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max)))

# The opcodes of §5.2.
type Op is Data:
  OCont{}
  OText{}
  OBin{}
  OClose{}
  OPing{}
  OPong{}

def op.code(o: Op) -> U32:
  match o:
    case OCont{}:
      0
    case OText{}:
      1
    case OBin{}:
      2
    case OClose{}:
      8
    case OPing{}:
      9
    case OPong{}:
      10

# Control frames must not be fragmented (§5.5).
def op.ok(fin: Bool, o: Op) -> Bool:
  match fin:
    case True{}:
      True{}
    case False{}:
      match o:
        case OClose{}:
          False{}
        case OPing{}:
          False{}
        case OPong{}:
          False{}
        case _:
          True{}

# An unmasked frame with a 7-bit length, as a server sends it.
def wire(fin: Bool, o: Op, +p: List<&2, U32>) -> List<&2, U32>:
  Con{(Bool.pick(U32, fin, 128, 0) .|. op.code(o) : U32), Con{U32.from_nat(List.length(&2, U32, p)), p}}

# A client decodes such a frame and leaves what follows it.
law roundtrip:
  for +fin: Bool
  for +o: Op
  for +max: U32
  for +p: List<&2, U32>
  for +ys: List<&2, U32>
  for ok: {op.ok(fin, o) == True{} : Bool}
  for +short: MNat.le(List.length(&2, U32, p), 125n)
  for +fit: MNat.le(List.length(&2, U32, p), U32.to_nat(max))
  {WS.list.next(False{}, max, cat(wire(fin, o, p), ys)) == WS.Got{WS.Frame{fin, op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}

# Every strict prefix of such a frame is incomplete, not malformed.
law prefix_need:
  for +fin: Bool
  for +o: Op
  for +max: U32
  for +p: List<&2, U32>
  for +k: Nat
  for ok: {op.ok(fin, o) == True{} : Bool}
  for +short: MNat.le(List.length(&2, U32, p), 125n)
  for +fit: MNat.le(List.length(&2, U32, p), U32.to_nat(max))
  for +less: MNat.lt(k, List.length(&2, U32, wire(fin, o, p)))
  {WS.list.next(False{}, max, List.take(&2, U32, wire(fin, o, p), k)) == WS.Need{List.take(&2, U32, wire(fin, o, p), k)} : WS.Decode<List<&2, U32>, List<&2, U32>>}

# WS.bytes.cut ends at pos + hs + len, within end, once Bytes.fits holds for the end - pos octets left: nothing wraps.
law cut_exact:
  for +pos: U32
  for +end: U32
  for +hs: U32
  for +len: U32
  for +le: MNat.le(U32.to_nat(pos), U32.to_nat(end))
  for +h: {Bytes.fits((end - pos : U32), hs, len) == True{} : Bool}
  {U32.to_nat(((pos + hs : U32) + len : U32)) == Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))) : Nat}

law cut_within:
  for +pos: U32
  for +end: U32
  for +hs: U32
  for +len: U32
  for +le: MNat.le(U32.to_nat(pos), U32.to_nat(end))
  for +h: {Bytes.fits((end - pos : U32), hs, len) == True{} : Bool}
  MNat.le(U32.to_nat(((pos + hs : U32) + len : U32)), U32.to_nat(end))
