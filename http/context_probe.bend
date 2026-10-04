# Finite fixture acceptance using the production transport and admission owner.
import Base
import ./http.bend as Http
import ./admission.bend as Admission
import ./completion.bend as Completion

def accept.reply(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), context: C, request: Http.Req) -> IO(Http.Reply):
  do IO<Http.Reply>:
    response : Http.Res <- handler(context, request)
    return Http.Reply{response, Completion.Unobserved{}}


def join(connections: List<Chan(Unit)>) -> IO(Unit):
  match connections:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case finished <> rest:
      do IO<Unit>:
        IO.join(Unit, finished)
        join(rest)
def accept.closed(~C: Data, server: Http.Server<C>, finished: List<Chan(Unit)>) -> IO(List<Chan(Unit)>):
  do IO<List<Chan(Unit)>>:
    join(finished)
    drained : Http.ServerCounts <- Http.server.close(~C, server)
    IO.print("LISTENER CLOSED")
    return Nil{}

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
            accepted : Http.Server<C> & Result<&1, &1, U32 & String, Chan(Unit)> <- Http.server.accept(~C, ~(context => req => accept.reply(~C, ~handler, context, req)), ~(context => status => outcome => Completion.ignore(status, outcome)), server)
            accept.go(~C, ~handler, AcceptReceived{accepted}, p, finished)
    case AcceptReceived{accepted}:
      (server, result) = accepted
      match result:
        case Fail{error}:
          accept.go(~C, ~handler, AcceptListening{server}, fuel, finished)
        case Done{done}:
          accept.go(~C, ~handler, AcceptListening{server}, fuel, done <> finished)

def accept.opened(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), count: Nat,
  context: C, +max: Nat, listener: Listener,
  opened: Chan(Admission.Command) & Chan(Admission.Counts)) -> IO(List<Chan(Unit)>):
  (inbox, drained) = opened
  accept.go(~C, ~handler, AcceptListening{Http.Server{listener, context,
    Http.ServerConfig{"127.0.0.1", 0, U32.from_nat(max), 65536, 128, 128, 128, 5000, 30000, 30000, 30000}, inbox, drained}}, count, Nil{})

def accept(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), count: Nat, context: C, +max: Nat, listener: Listener) -> IO(List<Chan(Unit)>):
  do IO<List<Chan(Unit)>>:
    Http.limits.validate(max)
    opened : Chan(Admission.Command) & Chan(Admission.Counts) <- Admission.open.owner(Admission.Caps{128, 128, 128})
    accept.opened(~C, ~handler, count, context, max, listener, opened)

