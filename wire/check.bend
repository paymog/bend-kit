import Base
import ../dns/dns.bend as Dns
import ./wire.bend as Wire

def ok(good: Bool, +name: String, +got: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " gave " ++ got)

def alpn.pair(+host: String, tr: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match tr:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "tls.connect.alpn failed: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{+proto}):
      do IO<Unit>:
        ok(String.eq(proto, "h2"), host ++ " alpn", proto)
        Wire.tls.close(s)

def alpn.run(+host: String, sock: Socket) -> IO(Unit):
  do IO<Unit>:
    tr : Socket & Result<&1, &1, U32 & String, String> <-
      Wire.tls.connect.alpn(sock, host, 30000, "h2,http/1.1")
    alpn.pair(host, tr)

def alpn.connect(+host: String, cr: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match cr:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "connect " ++ host ++ ": " ++ U32.show(code) ++ " " ++ why)
    case Done{sock}:
      alpn.run(host, sock)

def alpn.ip(+host: String, ip: String) -> IO(Unit):
  do IO<Unit>:
    cr : Result<&1, &1, U32 & String, Socket> <- Wire.connect(ip, 443, 30000)
    alpn.connect(host, cr)

def alpn.got(+host: String, m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "resolve " ++ host)
    case Some{ip}:
      alpn.ip(host, ip)

def alpn.host(+host: String) -> IO(Unit):
  do IO<Unit>:
    m : Maybe<&2, String> <- Dns.resolve(host)
    alpn.got(host, m)

def test.listen6(port: U32) -> IO(Result<&1, &1, U32 & String, Listener & U32>):
  import "./effs/ipv6_test.c"
  import "./effs/ipv6_test.js"

def ipv6.got(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "IPv6 recv: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{+data}):
      do IO<Unit>:
        ok(String.eq(data, "ok"), "IPv6 round-trip", data)
        Socket.close(s)

def ipv6.replied(client: Socket, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "IPv6 send: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{u}):
      do IO<Unit>:
        Socket.close(s)
        reply : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(client, 8, 5000)
        ipv6.got(reply)

def ipv6.received(client: Socket, m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "IPv6 recv: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{+data}):
      do IO<Unit>:
        ok(String.eq(data, "ping"), "IPv6 request", data)
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send(s, "ok")
        ipv6.replied(client, sent)

def ipv6.accepted(client: Socket, m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match m:
    case (l, Fail{(+code, why)}):
      IO.die(Unit, 1, "IPv6 accept: " ++ U32.show(code) ++ " " ++ why)
    case (l, Done{server}):
      do IO<Unit>:
        Listener.close(l)
        req : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(server, 8, 5000)
        ipv6.received(client, req)

def ipv6.sent(l: Listener, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "IPv6 send: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{u}):
      do IO<Unit>:
        accepted : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        ipv6.accepted(s, accepted)

def ipv6.connected(l: Listener, r: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "IPv6 connect: " ++ U32.show(code) ++ " " ++ why)
    case Done{s}:
      do IO<Unit>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send(s, "ping")
        ipv6.sent(l, sent)

def ipv6.listener(r: Result<&1, &1, U32 & String, Listener & U32>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "IPv6 listen: " ++ U32.show(code) ++ " " ++ why)
    case Done{(l, +port)}:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, Socket> <- Wire.connect("::1", port, 5000)
        ipv6.connected(l, r)

def ipv6.check() -> IO(Unit):
  do IO<Unit>:
    l : Result<&1, &1, U32 & String, Listener & U32> <- test.listen6(0)
    ipv6.listener(l)

def test.udp6(port: U32) -> IO(Result<&1, &1, U32 & String, Socket & U32>):
  import "./effs/ipv6_test.c"
  import "./effs/ipv6_test.js"

def udp6.payload(+want: U32, s: Socket, r: Result<&1, &1, U32 & String, String & U32 & String>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "IPv6 UDP recv: " ++ U32.show(code) ++ " " ++ why)
    case Done{(host, port, data)}:
      do IO<Unit>:
        ok(String.eq(host, "::1"), "IPv6 UDP host", "wrong host")
        ok(U32.is_eq(port, want), "IPv6 UDP port", "wrong port")
        ok(String.eq(data, "udp"), "IPv6 UDP body", "wrong body")
        Socket.close(s)

def udp6.recv(+want: U32, m: Socket & Result<&1, &1, U32 & String, String & U32 & String>) -> IO(Unit):
  (s, r) = m
  udp6.payload(want, s, r)

def udp6.sent(+want: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "IPv6 UDP send: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{u}):
      do IO<Unit>:
        r : Socket & Result<&1, &1, U32 & String, String & U32 & String> <- Wire.recv_from(s, 8, 5000)
        udp6.recv(want, r)

def udp6.opened(r: Result<&1, &1, U32 & String, Socket & U32>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "IPv6 UDP bind: " ++ U32.show(code) ++ " " ++ why)
    case Done{(s, +port)}:
      do IO<Unit>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send_to(s, "::1", port, "udp")
        udp6.sent(port, sent)

def udp6.check() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Socket & U32> <- test.udp6(0)
    udp6.opened(r)

def main() -> IO(Unit):
  do IO<Unit>:
    ipv6.check()
    udp6.check()
    alpn.host("nghttp2.org")
