# Serves the gateway on loopback in front of an upstream URL. Stop it with Ctrl-C.
import Base
import ./app.bend as Gw
import ./gateway.bend as G
import bend-kit-cache@0.2.0.0/cache.bend as Cache
import bend-kit-camber@0.13.0.0/camber.bend as C
import bend-kit-camber@0.13.0.0/notices.bend as N
import bend-kit-http@0.36.0.0/http.bend as H
import bend-kit-http@0.36.0.0/completion.bend as T
import bend-kit-hairpin@0.10.0.0/hairpin.bend as Hairpin

def done(completion: T.Completion<C.ApplicationReport<String>>) -> IO(Unit):
  IO.pure(Unit, Unit{})

def observed(status: U32, outcome: T.Outcome) -> IO(Unit):
  IO.pure(Unit, Unit{})

def notify(config: Gw.Config, policy: C.Policy<String>, notice: N.Notice) -> IO(Result<&2, &2, String, Unit>):
  IO.pure(Result<&2, &2, String, Unit>, Done{Unit{}})

def report(config: Gw.Config, error: String) -> IO(Unit):
  IO.print("ERROR " ++ error)

def destroy(client: Hairpin.Client) -> IO(Unit):
  Hairpin.close(client)

# Four request slots, each with its own upstream client.
def clients(+base: String) -> List<Hairpin.Client>:
  [Gw.client(base), Gw.client(base), Gw.client(base), Gw.client(base)]

def started(r: Result<&2, &1, C.StartupError, C.Server<Gw.Action, Hairpin.Client, Gw.Config, String>>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "gateway: startup failed")
    case Done{server}:
      do IO<Unit>:
        IO.print("READY gateway")
        exit : C.ServerExit<Gw.Action, Hairpin.Client, Gw.Config, String> <- C.server.run(~Gw.Action, ~Hairpin.Client, ~Gw.Config, ~String, ~String,
          ~done, ~observed, ~notify, ~report, ~C.access.disabled(~Gw.Config), server)
        return Unit{}

def prepared(p: C.Owner<G.Gate, Unit, Gw.Op, String, Gw.Reply> & C.Context<G.Gate, Unit, Gw.Op, String, Gw.Reply>, +port: U32, +base: String) -> IO(Unit):
  (owner, +store) = p
  do IO<Unit>:
    r : Result<&2, &1, C.StartupError, C.Server<Gw.Action, Hairpin.Client, Gw.Config, String>> <- C.server.start(~Gw.Action, ~Hairpin.Client, ~Gw.Config, ~String, ~String,
      ~Gw.before, ~Gw.after, ~Gw.run, ~Gw.mapper, ~destroy, Gw.application(Gw.Config{store, Gw.readers(), 2n, 5000n}), C.server.config(port), clients(base))
    started(r)
    closed : C.OwnerClose<G.Gate, Unit, Gw.Op, String, Gw.Reply> <- C.close(G.Gate, Unit, Gw.Op, String, Gw.Reply, owner)
    return Unit{}

def opened(r: Result<&2, &1, String, C.Owner<G.Gate, Unit, Gw.Op, String, Gw.Reply>>, +port: U32, +base: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "gateway: gate start failed")
    case Done{owner}:
      prepared(C.owner.context(G.Gate, Unit, Gw.Op, String, Gw.Reply, owner), port, base)

# Two requests at once; values stay fresh for 30 s and missing items for 10 s.
def start(port: Maybe<&2, U32>, +base: String) -> IO(Unit):
  match port:
    case Some{+p}:
      do IO<Unit>:
        r : Result<&2, &1, String, C.Owner<G.Gate, Unit, Gw.Op, String, Gw.Reply>> <- Gw.store.start(Gw.Setup{2n, Cache.Policy{30000n, 10000n}})
        opened(r, p, base)
    case None{}:
      IO.die(Unit, 1, "gateway: expected a decimal port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> port <> base <> Nil{}:
      start(U32.read(port), base)
    case _:
      IO.die(Unit, 1, "usage: gateway-demo PORT UPSTREAM-URL")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
