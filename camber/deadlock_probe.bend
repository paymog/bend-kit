# Intentional opposing-acquisition deadlock; native and JS are expected to exit nonzero.
import Base

def value(-A: Type, got: Maybe<&1, A>) -> IO(A):
  match got:
    case Some{x}:
      IO.pure(A, x)
    case None{}:
      IO.die(A, 1, "unexpected closed channel")

def receive(-A: Type, channel: Chan(A)) -> IO(A):
  do IO<A>:
    got : Maybe<&1, A> <- Chan.recv(A, channel)
    value(A, got)

def borrow(first: Chan(File), second: Chan(File), ready: Chan(Unit), go: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    one : File <- receive(File, first)
    announced : Bool <- Chan.send(Unit, ready, Unit{})
    receive(Unit, go)
    two : File <- receive(File, second)
    File.close(one)
    File.close(two)

def main() -> IO(Unit):
  do IO<Unit>:
    one : File <- IO.try(File, File.open("/dev/null", "r"))
    two : File <- IO.try(File, File.open("/dev/null", "r"))
    a0 : Chan(File) <- Chan.new(File, 1)
    +a : Chan(File) = a0
    b0 : Chan(File) <- Chan.new(File, 1)
    +b : Chan(File) = b0
    ready0 : Chan(Unit) <- Chan.new(Unit, 2)
    +ready : Chan(Unit) = ready0
    go0 : Chan(Unit) <- Chan.new(Unit, 2)
    +go : Chan(Unit) = go0
    sent_a : Bool <- Chan.send(File, a, one)
    sent_b : Bool <- Chan.send(File, b, two)
    left : Chan(Unit) <- IO.fork(Unit, borrow(a, b, ready, go))
    right : Chan(Unit) <- IO.fork(Unit, borrow(b, a, ready, go))
    receive(Unit, ready)
    receive(Unit, ready)
    IO.print("both requests hold one affine instance; now each waits for the other set")
    go_a : Bool <- Chan.send(Unit, go, Unit{})
    go_b : Bool <- Chan.send(Unit, go, Unit{})
    IO.join(Unit, left)
    IO.join(Unit, right)
