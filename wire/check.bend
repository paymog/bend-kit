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

def main() -> IO(Unit):
  alpn.host("nghttp2.org")
