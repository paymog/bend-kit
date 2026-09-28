import Base
import ../dns/dns.bend as Dns
import ../wire/wire.bend as Wire
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./http2.bend as H
import ./hpack.bend as Hp

def fail(+message: String) -> IO(Unit):
  IO.die(Unit, 1, message)

def sent(r: Socket & Result<&1, &1, U32 & String, Unit>, k: Socket -> IO(Socket)) -> IO(Socket):
  match r:
    case (s, Fail{(+code, why)}):
      do IO<Socket>:
        closed: Unit <- Wire.tls.close(s)
        IO.die(Socket, 1, "h2 send: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{unit}):
      k(s)

def send(xs: List<&1, Bytes.Bytes>, s: Socket) -> IO(Socket):
  match xs:
    case Nil{}:
      do IO<Socket>:
        return s
    case Con{Bytes.Bytes{len, buf}, rest}:
      do IO<Socket>:
        r: Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send.words(s, len, buf)
        sent(r, next => send(rest, next))

def status(xs: List<&2, Hp.Field>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{Hp.Field{name, value, mode}, rest}:
      Bool.or(Bool.and(String.eq(name, ":status"), String.eq(value, "200")), status(rest))

def match_status(good: Bool, s: Socket) -> IO(Unit):
  match good:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        fail("public h2 status not 200")

def response(events: List<&1, H.ClientEvent>, s: Socket, c: H.Client,
    k: Socket -> H.Client -> IO(Unit)) -> IO(Unit):
  match events:
    case Nil{}:
      k(s, c)
    case Con{H.Response{id, Con{Hp.Field{":status", SCon{Chr{49}, suffix}, mode}, fields}, body}, rest}:
      response(rest, s, c, k)
    case Con{H.Response{id, headers, body}, rest}:
      do IO<Unit>:
        checked: Unit <- match_status(status(headers), s)
        IO.print("ok public h2 response status 200")
    case Con{H.Reset{id, code}, rest}:
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        IO.die(Unit, 1, "public h2 reset: " ++ U32.show(code))
    case Con{H.Shutdown{last, code}, rest}:
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        IO.die(Unit, 1, "public h2 GOAWAY: " ++ U32.show(code))
    case Con{H.Pong{data}, rest}:
      response(rest, s, c, k)

def replied(r: H.Reply, s: Socket,
    k: Socket -> H.Client -> List<&1, H.ClientEvent> -> IO(Unit)) -> IO(Unit):
  match r:
    case H.Failed{H.Error{code, connection, stream}}:
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        IO.die(Unit, 1, "public h2 protocol: " ++ U32.show(code))
    case H.Ready{c, writes, events}:
      do IO<Unit>:
        next: Socket <- send(writes, s)
        k(next, c, events)

def received(r: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>,
    c: H.Client, k: Socket -> H.Reply -> IO(Unit)) -> IO(Unit):
  match r:
    case (s, Fail{(+code, why)}):
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        IO.die(Unit, 1, "h2 recv: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{(0, buf)}):
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        fail("public h2 closed before response")
    case (s, Done{(+len, buf)}):
      k(s, H.client.receive(c, Bytes.Bytes{len, buf}))

def loop(n: Nat, c: H.Client, s: Socket) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        fail("public h2 response did not finish")
    case 1n+p:
      do IO<Unit>:
        r: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          Wire.tls.recv.words(s, 16384, 15000)
        received(r, c, sock => reply =>
          replied(reply, sock, next => client => events =>
            response(events, next, client, next2 => client2 => loop(p, client2, next2))))

def request(r: H.Reply, s: Socket) -> IO(Unit):
  replied(r, s, next => client => events =>
    response(events, next, client, next2 => client2 => loop(64n, client2, next2)))

def start(r: H.Client & Bytes.Bytes, s: Socket) -> IO(Unit):
  (client, preface) = r
  do IO<Unit>:
    connected: Socket <- send([preface], s)
    request(H.client.request(client,
      [Hp.Field{":method", "GET", 0}, Hp.Field{":scheme", "https", 0},
        Hp.Field{":authority", "nghttp2.org", 0}, Hp.Field{":path", "/", 0}],
      Bytes.new(0)), connected)

def protocol(good: Bool, s: Socket) -> IO(Unit):
  match good:
    case True{}:
      start(H.client.start(), s)
    case False{}:
      do IO<Unit>:
        closed: Unit <- Wire.tls.close(s)
        fail("public TLS did not select h2")

def alpn(r: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case (s, Fail{(+code, why)}):
      do IO<Unit>:
        closed: Unit <- Socket.close(s)
        IO.die(Unit, 1, "h2 ALPN: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{proto}):
      protocol(String.eq(proto, "h2"), s)

def connected(r: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "h2 connect: " ++ U32.show(code) ++ " " ++ why)
    case Done{s}:
      do IO<Unit>:
        tls: Socket & Result<&1, &1, U32 & String, String> <-
          Wire.tls.connect.alpn(s, "nghttp2.org", 15000, "h2")
        alpn(tls)

def address(m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      fail("nghttp2.org DNS failed")
    case Some{ip}:
      do IO<Unit>:
        r: Result<&1, &1, U32 & String, Socket> <- Wire.connect(ip, 443, 15000)
        connected(r)

def run() -> IO(Unit):
  do IO<Unit>:
    ip: Maybe<&2, String> <- Dns.resolve("nghttp2.org")
    address(ip)
