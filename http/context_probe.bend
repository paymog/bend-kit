# Finite validation transport with explicit runtime context; not a published server API.
# ponytail: 512 framing steps per connection; production needs bounded admission and graceful lifecycle controls.
import Base
import ./http.bend as Http

def close(st: Http.Serving) -> IO(Unit):
  Http.Serving{(socket, turn), phase} = st
  Socket.close(socket)

def talk(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), fuel: Nat, +context: C, +max: Nat, st: Http.Serving) -> IO(Unit):
  match fuel:
    case 0n:
      close(st)
    case 1n+p:
      Http.Serving{(socket, turn), phase} = st
      match turn:
        case Http.TurnMore{state, cont}:
          do IO<Unit>:
            received : (Socket & Http.Turn) & Http.Phase <- Http.talk.recv(Http.limits(max), socket, state, cont, phase)
            talk(~C, ~handler, p, context, max, Http.talk.state(received))
        case Http.TurnReq{request, rest, v11}:
          Http.Req{+method, path, +headers, body} = request
          do IO<Unit>:
            response : Http.Res <- handler(context, Http.Req{method, path, headers, body})
            next : Socket & Http.Turn <- Http.talk.send(Http.limits(max), socket, rest, headers, v11, String.eq(method, "HEAD"), response)
            talk(~C, ~handler, p, context, max, Http.Serving{next, None{}})
        case Http.TurnFail{status}:
          Http.reply_fail(socket, status, 30000)
        case Http.TurnClose{}:
          Socket.close(socket)

type AcceptState is Type:
  Listening{listener: Listener}
  Connected{listener: Listener, finished: Chan(Unit)}

def accepted(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), context: C, max: Nat, result: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(AcceptState):
  (listener, got) = result
  do IO<AcceptState>:
    socket : Socket <- IO.pass(Socket, got)
    finished : Chan(Unit) <- IO.fork(Unit, talk(~C, ~handler, 512n, context, max, Http.Serving{(socket, Http.TurnMore{Http.sv.none(), False{}}), None{}}))
    return Connected{listener, finished}

def accept.close(state: AcceptState, finished: List<Chan(Unit)>) -> IO(List<Chan(Unit)>):
  match state:
    case Listening{listener}:
      do IO<List<Chan(Unit)>>:
        Listener.close(listener)
        IO.print("LISTENER CLOSED")
        return finished
    case Connected{listener, done}:
      do IO<List<Chan(Unit)>>:
        Listener.close(listener)
        IO.print("LISTENER CLOSED")
        return done <> finished

def accept.go(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), fuel: Nat, +context: C, +max: Nat, state: AcceptState, finished: List<Chan(Unit)>) -> IO(List<Chan(Unit)>):
  match fuel:
    case 0n:
      accept.close(state, finished)
    case 1n+p:
      match state:
        case Listening{listener}:
          do IO<List<Chan(Unit)>>:
            got : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
            next : AcceptState <- accepted(~C, ~handler, context, max, got)
            accept.go(~C, ~handler, p, context, max, next, finished)
        case Connected{listener, done}:
          accept.go(~C, ~handler, p, context, max, Listening{listener}, done <> finished)

def accept(~C: Data, ~handler: C -> Http.Req -> IO(Http.Res), count: Nat, context: C, max: Nat, listener: Listener) -> IO(List<Chan(Unit)>):
  accept.go(~C, ~handler, (2n * count : Nat), context, max, Listening{listener}, Nil{})

def join(connections: List<Chan(Unit)>) -> IO(Unit):
  match connections:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case finished <> rest:
      do IO<Unit>:
        IO.join(Unit, finished)
        join(rest)
