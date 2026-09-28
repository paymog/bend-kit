# Wire benchmark: R localhost TCP echo round trips with send.words and recv.words (see README.md).
import Base
import ../../time/time.bend as Time
import ../wire.bend as Wire
import ../../bytes/bytes.bend as Bytes

def port() -> U32:
  38501

def len() -> U32:
  1048576

def rounds() -> Nat:
  64n

def recv.ms() -> U32:
  120000

def b8(+x: U32) -> U32:
  (x .&. 255 : U32)

def packw(+t: U32) -> U32:
  (b8(t) .|. (b8((t + 31 : U32)) << 8n) .|. (b8((t + 62 : U32)) << 16n) .|. (b8((t + 93 : U32)) << 24n) : U32)

def fill(n: Nat, a: Array<U32>, +j: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill(p, Array.set(U32, a, j, packw((j * 124 + 7 : U32))), (j + 1 : U32))

def buf() -> Array<U32>:
  fill(262144n, Array.new(U32, 18n, 0), 0)

def mix(+h: U32, +b: U32) -> U32:
  ((h * 31 : U32) + b : U32)

def hash.str(s: String, +h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{+c}, t}:
      hash.str(t, mix(h, b8(c)))


def recv.fuel() -> Nat:
  65536n

def recv.scratch() -> Array<U32>:
  Array.new(U32, 18n, 0)

@unsafe
def recv.patch.pair(r: Array<U32> & Array<U32>) -> Array<U32>:
  (_, dst) = r
  dst

@unsafe
def recv.patch(+ln: U32, words: Array<U32>, arr: Array<U32>, +off: U32) -> Array<U32>:
  recv.patch.pair(Bytes.copy(ln, words, arr, 0, off))

def recv.full.pack(sock: Socket, arr: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  IO.pure(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, (sock, Done{(len(), arr)}))

@unsafe
def recv.full.step(fuel: Nat, sock: Socket, +off: U32, +ln: U32, arr: Array<U32>, words: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  recv.full.check(fuel, sock, (off + ln : U32), recv.patch(ln, words, arr, off))

@unsafe
def recv.full.got(fuel: Nat, sock: Socket, +off: U32, arr: Array<U32>, pair: U32 & Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  (ln, words) = pair
  recv.full.step(fuel, sock, off, ln, arr, words)

@unsafe
def recv.full.more(fuel: Nat, +off: U32, arr: Array<U32>, mr: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  (sock, r) = mr
  match r:
    case Fail{e}:
      IO.pure(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, (sock, Fail{e}))
    case Done{pair}:
      recv.full.got(fuel, sock, off, arr, pair)

@unsafe
def recv.full.read(fuel: Nat, sock: Socket, +off: U32, arr: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match fuel:
    case 0n:
      do IO<Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>>:
        IO.print("recv incomplete")
        IO.pure(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, (sock, Fail{(110, "incomplete")}))
    case 1n+p:
      do IO<Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>>:
        need : U32 = (len() - off : U32)
        mr : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(sock, need, recv.ms())
        recv.full.more(p, off, arr, mr)

@unsafe
def recv.full.ready(ok: Bool, fuel: Nat, sock: Socket, +off: U32, arr: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match ok:
    case True{}:
      recv.full.pack(sock, arr)
    case False{}:
      recv.full.read(fuel, sock, off, arr)

@unsafe
def recv.full.check(fuel: Nat, sock: Socket, +off: U32, arr: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  recv.full.ready(U32.is_ge(off, len()), fuel, sock, off, arr)

@unsafe
def recv.full(sock: Socket) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  recv.full.check(recv.fuel(), sock, 0, recv.scratch())

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, +cs: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(cs))

def echo.after.send(ms: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Socket):
  (sock, r) = ms
  match r:
    case Fail{e}:
      do IO<Socket>:
        IO.print("server send failed")
        IO.pure(Socket, sock)
    case Done{u}:
      IO.pure(Socket, sock)

def echo.got(sock2: Socket, pair: U32 & Array<U32>) -> IO(Socket):
  (ln, words) = pair
  do IO<Socket>:
    ms : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send.words(sock2, ln, words)
    echo.after.send(ms)

def echo.done(mr: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Socket):
  (sock2, r) = mr
  match r:
    case Fail{e}:
      do IO<Socket>:
        IO.print("server recv failed")
        IO.pure(Socket, sock2)
    case Done{pair}:
      echo.got(sock2, pair)

def echo.one(sock: Socket) -> IO(Socket):
  do IO<Socket>:
    mr : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- recv.full(sock)
    echo.done(mr)

def echo.loop(n: Nat, sock: Socket) -> IO(Unit):
  match n:
    case 0n:
      Socket.close(sock)
    case 1n+p:
      do IO<Unit>:
        sock2 : Socket <- echo.one(sock)
        echo.loop(p, sock2)

def server.accept(mr: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  (_, r) = mr
  match r:
    case Fail{e}:
      IO.print("accept failed")
    case Done{sock}:
      echo.loop(rounds(), sock)

def server.listen(l: Listener) -> IO(Unit):
  do IO<Unit>:
    mr : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    server.accept(mr)

def server.lr(lr: Result<&1, &1, U32 & String, Listener>) -> IO(Unit):
  match lr:
    case Fail{e}:
      IO.print("listen failed")
    case Done{l}:
      server.listen(l)

def server() -> IO(Unit):
  do IO<Unit>:
    lr : Result<&1, &1, U32 & String, Listener> <- TCP.listen(port())
    server.lr(lr)

@unsafe
def client.round.got(t0: Time.Duration, +n: Nat, sock: Socket, pair: U32 & Array<U32>, +h: U32, +send: Array<U32>) -> IO(Unit):
  (ln, words) = pair
  client.round.go(t0, n, sock, send, hash.str(Bytes.to_string(Bytes.Bytes{ln, words}), h))

@unsafe
def client.round.recv(t0: Time.Duration, n: Nat, mr: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, +h: U32, +send: Array<U32>) -> IO(Unit):
  (sock, r) = mr
  match r:
    case Fail{e}:
      IO.print("recv failed")
    case Done{pair}:
      client.round.got(t0, n, sock, pair, h, send)

@unsafe
def client.round.sent(t0: Time.Duration, n: Nat, mr: Socket & Result<&1, &1, U32 & String, Unit>, +h: U32, +send: Array<U32>) -> IO(Unit):
  (sock, r) = mr
  match r:
    case Fail{e}:
      IO.print("send failed")
    case Done{u}:
      do IO<Unit>:
        mr2 : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- recv.full(sock)
        client.round.recv(t0, n, mr2, h, send)

@unsafe
def client.round.go(t0: Time.Duration, n: Nat, sock: Socket, +send: Array<U32>, +h: U32) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        t1 : Time.Duration <- Time.mono()
        lap("echo", t0, t1, h)
    case 1n+p:
      do IO<Unit>:
        mr : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send.words(sock, len(), send)
        client.round.sent(t0, p, mr, h, send)

def client.echo(sock: Socket, words: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    client.round.go(t0, rounds(), sock, words, 0)

def client.connected(sock: Socket) -> IO(Unit):
  do IO<Unit>:
    words : Array<U32> = buf()
    client.echo(sock, words)

def client.cr(cr: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match cr:
    case Fail{e}:
      IO.print("connect failed")
    case Done{sock}:
      client.connected(sock)

def client.go() -> IO(Unit):
  do IO<Unit>:
    cr : Result<&1, &1, U32 & String, Socket> <- Wire.connect("127.0.0.1", port(), 10000)
    client.cr(cr)

def main() -> IO(Unit):
  do IO<Unit>:
    chan : Chan(Unit) <- IO.fork(Unit, server())
    _ : Unit <- IO.sleep(500)
    u : Unit <- client.go()
    IO.join(Unit, chan)
