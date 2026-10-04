# Finite fixture acceptance using the production transport and admission owner.
import Base
import ./http.bend as Http
import ./admission.bend as Admission

def accept.closed(~C: Data, server: Http.Server<C>, finished: List<Chan(Unit)>) -> IO(List<Chan(Unit)>):
  do IO<List<Chan(Unit)>>:
    Http.server.close(~C, server)
    IO.print("LISTENER CLOSED")
    return finished

type AcceptStep<-C: Data> is Type:
  AcceptListening{server: Http.Server<C>}
  AcceptReceived{result: Http.Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>}

@unsafe
def accept.go(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), step: AcceptStep<C>,
  fuel: Nat, finished: List<Chan(Unit)>) -> IO(List<Chan(Unit)>):
  match step:
    case AcceptListening{server}:
      match fuel:
        case 0n:
          accept.closed(~C, server, finished)
        case 1n+p:
          do IO<List<Chan(Unit)>>:
            accepted : Http.Server<C> & Result<&1, &1, U32 & String, Chan(Unit)> <- Http.server.accept(~C, ~handler, server)
            accept.go(~C, ~handler, AcceptReceived{accepted}, p, finished)
    case AcceptReceived{accepted}:
      (server, result) = accepted
      match result:
        case Fail{error}:
          accept.go(~C, ~handler, AcceptListening{server}, fuel, finished)
        case Done{done}:
          accept.go(~C, ~handler, AcceptListening{server}, fuel, done <> finished)

def accept(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), count: Nat, context: C, +max: Nat, listener: Listener) -> IO(List<Chan(Unit)>):
  do IO<List<Chan(Unit)>>:
    Http.limits.validate(max)
    inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    accept.go(~C, ~handler, AcceptListening{Http.Server{listener, context,
      Http.ServerConfig{"127.0.0.1", 0, U32.from_nat(max), 65536, 128, 128, 128, 5000, 30000, 30000, 30000}, inbox}}, count, Nil{})

def join(connections: List<Chan(Unit)>) -> IO(Unit):
  match connections:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case finished <> rest:
      do IO<Unit>:
        IO.join(Unit, finished)
        join(rest)
