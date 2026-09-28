import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
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

def round.parsed(+len: U32, +wire: U32, d: WS.Decode) -> Bool:
  match d:
    case WS.Got{WS.Frame{+fin, +op, p}, Bytes.Bytes{+rest, tail}}:
      Bool.and(Bool.and(fin, U32.is_eq(op, 2)), Bool.and(U32.is_eq(rest, 0), same(Bytes.eq(p, big(len)))))
    case _:
      False{}

def round.encoded(+len: U32, +hs: U32, r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{Bytes.Bytes{+n, buf}}:
      Bool.and(U32.is_eq(n, (len + hs : U32)), round.parsed(len, n, WS.parse(True{}, 1048576, Bytes.Bytes{n, buf})))

# A masked frame of len bytes has an hs-byte header and parses back on a server.
def round(+len: U32, +hs: U32) -> Bool:
  round.encoded(len, hs, WS.encode(WS.Frame{True{}, 2, big(len)}, Some{305419896}))

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
        r : WS.Conn & Result<&1, &1, U32 & String, WS.Incoming> <- WS.recv(WS.Conn{sock, False{}, True{}, rest, WS.Idle{}, 1048576, False{}}, 5000)
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

def main() -> IO(Unit):
  do IO<Unit>:
    a : Result<&1, &1, U32 & String, String> <- WS.accept("dGhlIHNhbXBsZSBub25jZQ==")
    accepted(a)
    k1 : Result<&1, &1, U32 & String, String> <- WS.key()
    k2 : Result<&1, &1, U32 & String, String> <- WS.key()
    keys(k1, k2)
    ok(round(65535, 8), "65535-byte frame uses the 16-bit length")
    ok(round(70000, 14), "70000-byte frame uses the 64-bit length")
    l : Result<&1, &1, U32 & String, Listener> <- TCP.listen("127.0.0.1", port())
    session(l)
