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




def ipv6.port() -> U32:
  38402

def ipv6.serve(+port: U32) -> IO(Unit):
  import "./effs/ipv6_serve.c"
  import "./effs/ipv6_serve.js"

def ipv6.got(+port: U32, mr: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match mr:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "ipv6 recv: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{+data}):
      do IO<Unit>:
        ok(String.eq(data, "ok"), "::1:" ++ U32.show(port), data)
        Socket.close(s)

def ipv6.open(+port: U32, cr: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match cr:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "ipv6 connect: " ++ U32.show(code) ++ " " ++ why)
    case Done{sock}:
      do IO<Unit>:
        mr : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(sock, 8, 5000)
        ipv6.got(port, mr)

def ipv6.client(+port: U32) -> IO(Unit):
  do IO<Unit>:
    cr : Result<&1, &1, U32 & String, Socket> <- Wire.connect("::1", port, 5000)
    ipv6.open(port, cr)

def ipv6.loop(+port: U32) -> IO(Unit):
  do IO<Unit>:
    chan : Chan(Unit) <- IO.fork(Unit, ipv6.serve(port))
    _ : Unit <- IO.sleep(500)
    ipv6.client(port)
    u : Unit <- IO.join(Unit, chan)
    IO.pure(Unit, u)



def mtls.port() -> U32:
  38403

def mtls.serve(+port: U32) -> IO(Unit):
  import "./effs/mtls_serve.c"
  import "./effs/mtls_serve.js"

def mtls.done(+port: U32, tr: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match tr:
    case (s, Fail{(+code, why)}):
      IO.die(Unit, 1, "tls.connect.cert failed: " ++ U32.show(code) ++ " " ++ why)
    case (s, Done{_}):
      do IO<Unit>:
        IO.print("ok mtls:" ++ U32.show(port))
        Wire.tls.close(s)

def mtls.open(+port: U32, cr: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match cr:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "mtls connect: " ++ U32.show(code) ++ " " ++ why)
    case Done{sock}:
      do IO<Unit>:
        tr : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect.cert(
          sock, "localhost", 10000, "test/mtls/client.pem", "test/mtls/client.key")
        mtls.done(port, tr)

def mtls.client(+port: U32) -> IO(Unit):
  do IO<Unit>:
    cr : Result<&1, &1, U32 & String, Socket> <- Wire.connect("127.0.0.1", port, 5000)
    mtls.open(port, cr)

def mtls.loop(+port: U32) -> IO(Unit):
  do IO<Unit>:
    chan : Chan(Unit) <- IO.fork(Unit, mtls.serve(port))
    _ : Unit <- IO.sleep(800)
    mtls.client(port)
    u : Unit <- IO.join(Unit, chan)
    IO.pure(Unit, u)

def main() -> IO(Unit):
  do IO<Unit>:
    ipv6.loop(ipv6.port())
    mtls.loop(mtls.port())
    alpn.host("nghttp2.org")
