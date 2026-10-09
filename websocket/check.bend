import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ./websocket.bend as WS

# The effects on the native runtime: SHA-1 and random keys through libcrypto and the
# OS, a 70000-byte frame, and a whole session against a server on 127.0.0.1:39461
# that runs in this program over the same Conn with server true.

def port() -> U32:
  39461

def of(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name)

def die(+what: String, e: U32 & String) -> IO(Unit):
  (+code, why) = e
  IO.die(Unit, 1, what ++ ": " ++ U32.show(code) ++ " " ++ why)

def same(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, v) = r
  v

def text.is(b: Bytes.Bytes, +want: String) -> Bool:
  String.eq(Bytes.to_string(b), want)

def fill(n: Nat, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, i, (i * 7 : U32)), (i + 1 : U32))

def big(+n: U32) -> Bytes.Bytes:
  fill(U32.to_nat(n), Bytes.new(n), 0)

def accepted(r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("accept", e)
    case Done{+a}:
      ok(String.eq(a, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="), "RFC 6455 §1.3 accept through libcrypto SHA-1")

def key.len(m: Maybe<&1, Bytes.Bytes>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{Bytes.Bytes{+n, buf}}:
      U32.is_eq(n, 16)

def keys(a: Result<&1, &1, U32 & String, String>, b: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match a:
    case Fail{e}:
      die("key", e)
    case Done{+x}:
      match b:
        case Fail{e}:
          die("key", e)
        case Done{+y}:
          ok(Bool.and(key.len(Bytes.from_base64(x)), Bool.not(String.eq(x, y))), "keys are 16 fresh random octets in base64")

def round.parsed(+len: U32, +wire: U32, d: WS.Decode<Bytes.Bytes, Bytes.Cursor>) -> Bool:
  match d:
    case WS.Got{WS.Frame{+fin, +op, p}, Bytes.Cursor{b, +pos, start, +end}}:
      Bool.and(Bool.and(fin, U32.is_eq(op, 2)), Bool.and(U32.is_eq(pos, end), same(Bytes.eq(p, big(len)))))
    case _:
      False{}

def round.encoded(+len: U32, +hs: U32, r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{Bytes.Bytes{+n, buf}}:
      Bool.and(U32.is_eq(n, (len + hs : U32)), round.parsed(len, n, WS.parse(True{}, 1048576, Bytes.Cursor.new(Bytes.Bytes{n, buf}))))

# A masked frame of len bytes has an hs-byte header and parses back on a server.
def round(+len: U32, +hs: U32) -> Bool:
  round.encoded(len, hs, WS.encode(WS.Frame{True{}, 2, big(len)}, Some{305419896}))

# Read boundaries. The Bytes decoder runs as recv runs it: parse the buffer, and on Need
# append the next read. Its output must match WS.list.next on the whole input, for reads
# split at every octet and for reads of every fixed size.

def cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

def ramp(n: Nat, +i: U32) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{((i * 7 : U32) .&. 255 : U32), ramp(p, (i + 1 : U32))}

def str.of(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, str.of(t)}

def octs.go(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, t}:
      Con{c, octs.go(t)}

def octs(b: Bytes.Bytes) -> List<&2, U32>:
  octs.go(Bytes.to_string(b))

def show.list(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      "."
    case Con{+h, t}:
      U32.show(h) ++ " " ++ show.list(t)

def show.frame(+fin: Bool, +op: U32, p: List<&2, U32>) -> String:
  "frame " ++ Bool.pick(String, fin, "fin ", "") ++ U32.show(op) ++ ": " ++ show.list(p) ++ "\n"

def show.bad(+code: U32, +why: String) -> String:
  "bad " ++ U32.show(code) ++ " " ++ why

# What the list model decodes from the whole input.
def model(n: Nat, +masked: Bool, +max: U32, d: WS.Decode<List<&2, U32>, List<&2, U32>>) -> String:
  match n:
    case 0n:
      "frame budget"
    case 1n+p:
      match d:
        case WS.Need{b}:
          "need " ++ show.list(b)
        case WS.Bad{+code, +why}:
          show.bad(code, why)
        case WS.Got{WS.Frame{+fin, +op, pl}, +r}:
          show.frame(fin, op, pl) ++ model(p, masked, max, WS.list.next(masked, max, r))

# step is the size of the next read, and later reads take more each.
type Feed is Type:
  FParse{buf: Bytes.Cursor, src: Bytes.Bytes, pos: U32, step: U32, more: U32}
  FStep{d: WS.Decode<Bytes.Bytes, Bytes.Cursor>, src: Bytes.Bytes, pos: U32, step: U32, more: U32}
  FRead{eof: Bool, buf: Bytes.Cursor, src: Bytes.Bytes, pos: U32, step: U32, more: U32}

def feed.read(r: Bytes.Bytes & Bytes.Bytes, buf: Bytes.Cursor, +pos: U32, +step: U32, +more: U32) -> Feed:
  (src, chunk) = r
  FParse{WS.push(buf, chunk), src, (pos + step : U32), more, more}

# The octets of a cursor not decoded yet.
def left(c: Bytes.Cursor) -> Bytes.Bytes:
  Bytes.Cursor{b, +pos, start, +end} = c
  Bytes.snd(Bytes.slice(b, pos, (end - pos : U32)))

def feed.need(b: Bytes.Cursor, src: Bytes.Bytes, +pos: U32, +step: U32, +more: U32) -> Feed:
  Bytes.Bytes{+n, s} = src
  FRead{U32.is_le(n, pos), b, Bytes.Bytes{n, s}, pos, step, more}

# What the Bytes decoder decodes from reads of src. At the end of src a Need is EOF.
def feed(n: Nat, +masked: Bool, +max: U32, st: Feed) -> String:
  match n:
    case 0n:
      "frame budget"
    case 1n+p:
      match st:
        case FParse{buf, src, +pos, +step, +more}:
          feed(p, masked, max, FStep{WS.parse(masked, max, buf), src, pos, step, more})
        case FStep{d, src, +pos, +step, +more}:
          match d:
            case WS.Need{b}:
              feed(p, masked, max, feed.need(b, src, pos, step, more))
            case WS.Bad{+code, +why}:
              show.bad(code, why)
            case WS.Got{WS.Frame{+fin, +op, pl}, r}:
              show.frame(fin, op, octs(pl)) ++ feed(p, masked, max, FParse{r, src, pos, step, more})
        case FRead{eof, buf, src, +pos, +step, +more}:
          match eof:
            case True{}:
              "need " ++ show.list(octs(left(buf)))
            case False{}:
              feed(p, masked, max, feed.read(Bytes.slice(src, pos, step), buf, pos, step, more))

def split.same(eq: Bool, +want: String, +got: String, +what: String) -> Maybe<&2, String>:
  match eq:
    case True{}:
      None{}
    case False{}:
      Some{what ++ " decode\n" ++ got ++ "\nnot\n" ++ want}

def split.diff(+want: String, +got: String, +what: String) -> Maybe<&2, String>:
  split.same(String.eq(want, got), want, got, what)

def either(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Maybe<&2, String>:
  match a:
    case Some{m}:
      Some{m}
    case None{}:
      b

# Reads of first octets, then of more each.
def split.run(+masked: Bool, +max: U32, +xs: List<&2, U32>, +want: String, +first: U32, +more: U32) -> Maybe<&2, String>:
  split.diff(want, feed(1000n, masked, max, FParse{Bytes.Cursor.new(Bytes.new(0)), Bytes.from_string(str.of(xs)), 0, first, more}),
    "reads of " ++ U32.show(first) ++ " then " ++ U32.show(more))

# Two reads split at i, and reads of i + 1 each, for i from i up.
def split.each(n: Nat, +masked: Bool, +max: U32, +xs: List<&2, U32>, +want: String, +i: U32) -> Maybe<&2, String>:
  match n:
    case 0n:
      None{}
    case 1n+p:
      either(either(split.run(masked, max, xs, want, i, 1048576), split.run(masked, max, xs, want, (i + 1 : U32), (i + 1 : U32))),
        split.each(p, masked, max, xs, want, (i + 1 : U32)))

# The list model decodes xs whole as want, and every split of xs decodes the same.
def split(+masked: Bool, +max: U32, +xs: List<&2, U32>, +want: String) -> Maybe<&2, String>:
  either(split.diff(want, model(1000n, masked, max, WS.list.next(masked, max, xs)), "the list model and want"),
    split.each(1n+List.length(&2, U32, xs), masked, max, xs, want, 0))

def says(m: Maybe<&2, String>, +name: String) -> IO(Unit):
  match m:
    case None{}:
      IO.print("ok " ++ name)
    case Some{+why}:
      IO.die(Unit, 1, name ++ ": " ++ why)

# A client gets a text fragment, a ping, the last fragment, a 200-octet binary frame with
# a 16-bit length, and at EOF the first octet of one more frame.
def stream() -> List<&2, U32>:
  cat([1, 3, 72, 101, 108, 137, 1, 112, 128, 2, 108, 111, 130, 126, 0, 200], cat(ramp(200n, 0), [129]))

def stream.want() -> String:
  "frame 1: 72 101 108 .\nframe fin 9: 112 .\nframe fin 0: 108 111 .\nframe fin 2: " ++ show.list(ramp(200n, 0)) ++ "\nneed 129 ."

# A server gets a masked frame with a 64-bit length (key 1 2 3 4), then the RFC 6455 §5.7 masked "Hello".
def masked() -> List<&2, U32>:
  [130, 255, 0, 0, 0, 0, 0, 0, 0, 3, 1, 2, 3, 4, 96, 96, 96, 129, 133, 55, 250, 33, 61, 127, 159, 77, 81, 88]

def splits() -> IO(Unit):
  do IO<Unit>:
    says(split(False{}, 1024, stream(), stream.want()), "concatenated frames and EOF decode the same for every split")
    says(split(True{}, 1024, masked(), "frame fin 2: 97 98 99 .\nframe fin 1: 72 101 108 108 111 .\nneed ."), "masked frames with a split 64-bit length and key")
    says(split(False{}, 1024, [129, 2, 104, 105, 193, 0], "frame fin 1: 104 105 .\nbad 1002 reserved bits set"), "a frame, then malformed input, for every split")
    says(split(False{}, 100, cat([130, 126, 0, 200], ramp(200n, 0)), "bad 1009 frame over the size limit"), "max rejects at the header, before the payload")
    says(split(False{}, 4294967295, [130, 127, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2], "bad 1009 frame over the size limit"), "a 64-bit length of 2^32 is over the largest max")

# Server side.

def srv.closed(r: WS.Conn & Result<&1, &1, U32 & String, WS.Incoming>) -> IO(Unit):
  match r:
    case (c, Done{WS.Closed{+code, reason}}):
      do IO<Unit>:
        ok(Bool.and(U32.is_eq(code, 1000), text.is(reason, "done")), "server reads close 1000 \"done\" and echoes it")
        WS.shutdown(c)
    case (c, Fail{e}):
      die("server close", e)
    case _:
      IO.die(Unit, 1, "server expected close")

def srv.echoed(s: WS.Conn & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match s:
    case (c, Fail{e}):
      die("server echo", e)
    case (c, Done{u}):
      do IO<Unit>:
        r : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(c, 5000)
        srv.closed(r)

def srv.binary(r: WS.Conn & Result<&1, &1, U32 & String, WS.Incoming>) -> IO(Unit):
  match r:
    case (c, Done{WS.Binary{d}}):
      do IO<Unit>:
        s : WS.Conn & Result<&1, &1, U32 & String, Unit> <- WS.send(c, True{}, 2, d)
        srv.echoed(s)
    case (c, Fail{e}):
      die("server binary", e)
    case _:
      IO.die(Unit, 1, "server expected binary")

def srv.pong(r: WS.Conn & Result<&1, &1, U32 & String, WS.Incoming>) -> IO(Unit):
  match r:
    case (c, Done{WS.Pong{d}}):
      do IO<Unit>:
        ok(text.is(d, "p"), "client answers the ping with a masked pong")
        r2 : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(c, 5000)
        srv.binary(r2)
    case (c, Fail{e}):
      die("server pong", e)
    case _:
      IO.die(Unit, 1, "server expected pong")

def srv.sent(s: Socket & Result<&1, &1, U32 & String, Unit>, rest: Bytes.Bytes) -> IO(Unit):
  match s:
    case (sock, Fail{e}):
      die("server reply", e)
    case (sock, Done{u}):
      do IO<Unit>:
        r : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(WS.Conn{sock, False{}, True{}, Bytes.Cursor.new(rest), WS.Idle{}, 1048576, False{}}, 5000)
        srv.pong(r)

# The 101, then in the same write "Hel" as a first fragment, a ping, and "lo".
def srv.reply(a: Result<&1, &1, U32 & String, String>, sock: Socket, rest: Bytes.Bytes) -> IO(Unit):
  match a:
    case Fail{e}:
      die("server accept", e)
    case Done{+acc}:
      do IO<Unit>:
        s : Socket & Result<&1, &1, U32 & String, Unit> <- WS.io.send(sock, False{}, Bytes.append(
          of("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " ++ acc ++ "\r\n\r\n"),
          of("\u{1}\u{3}Hel\u{89}\u{1}p\u{80}\u{2}lo")))
        srv.sent(s, rest)

def srv.key(m: Maybe<&2, String>, sock: Socket, rest: Bytes.Bytes) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "request has no Sec-WebSocket-Key")
    case Some{+k}:
      do IO<Unit>:
        a : Result<&1, &1, U32 & String, String> <- WS.accept(k)
        srv.reply(a, sock, rest)

def srv.head(h: Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>) -> IO(Unit):
  match h:
    case (sock, Fail{e}):
      die("server head", e)
    case (sock, Done{(+head, rest)}):
      do IO<Unit>:
        ok(Bool.and(String.starts_with(head, "GET /chat HTTP/1.1\r\nHost: localhost:39461\r\n"),
          WS.value.is(WS.field(head, "sec-websocket-version"), "13")),
          "request line, Host with port, and version 13")
        srv.key(WS.field(head, "sec-websocket-key"), sock, rest)

def server.accepted(a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match a:
    case (l, Fail{e}):
      do IO<Unit>:
        Listener.close(l)
        die("accept", e)
    case (l, Done{sock}):
      do IO<Unit>:
        Listener.close(l)
        h : Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes> <- WS.head.read(sock, False{}, 5000)
        srv.head(h)

def server(l: Listener) -> IO(Unit):
  do IO<Unit>:
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    server.accepted(a)

# Client side.

def cl.closed(r: WS.Conn & Result<&1, &1, U32 & String, WS.Incoming>) -> IO(Unit):
  match r:
    case (c, Done{WS.Closed{+code, reason}}):
      do IO<Unit>:
        ok(U32.is_eq(code, 1000), "client close handshake completes")
        WS.shutdown(c)
    case (c, Fail{e}):
      die("client close", e)
    case _:
      IO.die(Unit, 1, "client expected close")

def cl.closing(s: WS.Conn & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match s:
    case (c, Fail{e}):
      die("client close send", e)
    case (c, Done{u}):
      do IO<Unit>:
        r : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(c, 5000)
        cl.closed(r)

def cl.binary(r: WS.Conn & Result<&1, &1, U32 & String, WS.Incoming>) -> IO(Unit):
  match r:
    case (c, Done{WS.Binary{d}}):
      do IO<Unit>:
        ok(same(Bytes.eq(d, big(70000))), "70000-byte masked binary message echoes back")
        s : WS.Conn & Result<&1, &1, U32 & String, Unit> <- WS.close(c, 1000, of("done"))
        cl.closing(s)
    case (c, Fail{e}):
      die("client binary", e)
    case _:
      IO.die(Unit, 1, "client expected binary")

def cl.sent(s: WS.Conn & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match s:
    case (c, Fail{e}):
      die("client send", e)
    case (c, Done{u}):
      do IO<Unit>:
        r : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(c, 5000)
        cl.binary(r)

def cl.text(r: WS.Conn & Result<&1, &1, U32 & String, WS.Incoming>) -> IO(Unit):
  match r:
    case (c, Done{WS.Text{d}}):
      do IO<Unit>:
        ok(text.is(d, "Hello"), "fragments join across a ping, from bytes sent with the 101")
        s : WS.Conn & Result<&1, &1, U32 & String, Unit> <- WS.send(c, True{}, 2, big(70000))
        cl.sent(s)
    case (c, Fail{e}):
      die("client text", e)
    case _:
      IO.die(Unit, 1, "client expected text")

def cl.connected(r: Result<&1, &1, U32 & String, WS.Conn>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("connect", e)
    case Done{c}:
      do IO<Unit>:
        IO.print("ok handshake: random key, SHA-1 accept, 101 checked")
        t : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(c, 5000)
        cl.text(t)

def client() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, WS.Conn> <- WS.connect("127.0.0.1", port(), "localhost", "/chat", False{}, 1048576, 5000)
    cl.connected(r)

def session(l: Result<&1, &1, U32 & String, Listener>) -> IO(Unit):
  match l:
    case Fail{e}:
      die("listen", e)
    case Done{lis}:
      do IO<Unit>:
        ch : Chan(Unit) <- IO.fork(Unit, server(lis))
        client()
        IO.join(Unit, ch)

# EOF inside a frame: the server sends its 101 and part of a frame, then closes.

def eof.port() -> U32:
  39462

def eof.sent(s: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match s:
    case (sock, Fail{e}):
      die("eof server reply", e)
    case (sock, Done{u}):
      Socket.close(sock)

def eof.reply(a: Result<&1, &1, U32 & String, String>, sock: Socket) -> IO(Unit):
  match a:
    case Fail{e}:
      die("eof server accept", e)
    case Done{+acc}:
      do IO<Unit>:
        s : Socket & Result<&1, &1, U32 & String, Unit> <- WS.io.send(sock, False{}, Bytes.append(
          of("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " ++ acc ++ "\r\n\r\n"),
          of("\u{81}\u{5}He")))
        eof.sent(s)

def eof.key(m: Maybe<&2, String>, sock: Socket) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "eof request has no Sec-WebSocket-Key")
    case Some{+k}:
      do IO<Unit>:
        a : Result<&1, &1, U32 & String, String> <- WS.accept(k)
        eof.reply(a, sock)

def eof.head(h: Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes>) -> IO(Unit):
  match h:
    case (sock, Fail{e}):
      die("eof server head", e)
    case (sock, Done{(+head, rest)}):
      eof.key(WS.field(head, "sec-websocket-key"), sock)

def eof.accepted(a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match a:
    case (l, Fail{e}):
      do IO<Unit>:
        Listener.close(l)
        die("eof accept", e)
    case (l, Done{sock}):
      do IO<Unit>:
        Listener.close(l)
        h : Socket & Result<&1, &1, U32 & String, String & Bytes.Bytes> <- WS.head.read(sock, False{}, 5000)
        eof.head(h)

def eof.server(l: Listener) -> IO(Unit):
  do IO<Unit>:
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    eof.accepted(a)

def eof.got(r: WS.Conn & Result<&1, &1, U32 & String, WS.Incoming>) -> IO(Unit):
  match r:
    case (c, Fail{(+code, why)}):
      do IO<Unit>:
        ok(U32.is_eq(code, 1006), "EOF inside a frame fails with 1006")
        WS.shutdown(c)
    case (c, Done{x}):
      do IO<Unit>:
        WS.shutdown(c)
        IO.die(Unit, 1, "EOF inside a frame decoded a message")

def eof.connected(r: Result<&1, &1, U32 & String, WS.Conn>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("eof connect", e)
    case Done{c}:
      do IO<Unit>:
        t : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(c, 5000)
        eof.got(t)

def eof.session(l: Result<&1, &1, U32 & String, Listener>) -> IO(Unit):
  match l:
    case Fail{e}:
      die("eof listen", e)
    case Done{lis}:
      do IO<Unit>:
        ch : Chan(Unit) <- IO.fork(Unit, eof.server(lis))
        r : Result<&1, &1, U32 & String, WS.Conn> <- WS.connect("127.0.0.1", eof.port(), "localhost", "/eof", False{}, 1048576, 5000)
        eof.connected(r)
        IO.join(Unit, ch)

def main() -> IO(Unit):
  do IO<Unit>:
    a : Result<&1, &1, U32 & String, String> <- WS.accept("dGhlIHNhbXBsZSBub25jZQ==")
    accepted(a)
    k1 : Result<&1, &1, U32 & String, String> <- WS.key()
    k2 : Result<&1, &1, U32 & String, String> <- WS.key()
    keys(k1, k2)
    ok(round(65535, 8), "65535-byte frame uses the 16-bit length")
    ok(round(70000, 14), "70000-byte frame uses the 64-bit length")
    splits()
    l : Result<&1, &1, U32 & String, Listener> <- TCP.listen("127.0.0.1", port())
    session(l)
    l2 : Result<&1, &1, U32 & String, Listener> <- TCP.listen("127.0.0.1", eof.port())
    eof.session(l2)
