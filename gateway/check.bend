# The gateway against a local upstream: deny, miss, hit, negative hit, 503 at capacity, open breaker, and every unit given back.
import Base
import ./gateway.bend as G
import ./app.bend as Gw
import ./upstream.bend as Up
import bend-kit-camber@0.13.0.0/camber.bend as C
import bend-kit-http@0.36.0.0/http.bend as H
import bend-kit-cache@0.2.0.0/cache.bend as Cache
import bend-kit-hairpin@0.10.0.0/hairpin.bend as Hairpin

def PORT() -> U32:
  18461

def BASE() -> String:
  "http://127.0.0.1:18461/"

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ message)

def ask(app: C.Application<Gw.Action, Gw.Config, C.Policy<String>>, client: Hairpin.Client, target: String, roles: String) -> IO(C.Completion<Hairpin.Client, String>):
  C.dispatch(~Gw.Action, ~Hairpin.Client, ~Gw.Config, ~String, ~String, ~Unit,
    ~Gw.before, ~Gw.after, ~Gw.run, ~Gw.mapper, ~C.notice.ignore(~Unit, ~String, ~String), ~C.notice.error.ignore(~Unit, ~String),
    Unit{}, C.access.disabled(~Unit, Unit{}), app, client,
    H.Req{"GET", target, H.set(H.set(H.empty(), "x-subject", "alice"), "x-roles", roles), H.from_string("")})

# Checks the status and the x-cache header, and gives the client back for the next request.
def expect(c: C.Completion<Hairpin.Client, String>, +label: String, +status: U32, +cache: String) -> IO(Hairpin.Client):
  C.Completed{client, H.Res{+actual, +headers, body}, entered, mapped, stopped} = c
  +seen = H.header(headers, "x-cache")
  do IO<Hairpin.Client>:
    require(U32.is_eq(actual, status) && String.eq(seen, cache), label ++ ": got " ++ U32.show(actual) ++ " x-cache=" ++ seen)
    IO.print("PASS " ++ label ++ ": " ++ U32.show(actual) ++ " x-cache=" ++ seen)
    return client

def held.of(out: C.Outcome<String, Gw.Reply>, +n: Nat, +label: String) -> IO(Unit):
  match out:
    case C.Success{Gw.RHeld{+h}}:
      do IO<Unit>:
        require(Nat.is_eq(h, n), label ++ ": " ++ Nat.show(h) ++ " units lent")
        IO.print("PASS " ++ label ++ ": " ++ Nat.show(h) ++ " units lent")
    case _:
      IO.die(Unit, 1, "FAIL " ++ label ++ ": peek failed")

def held(store: C.Context<G.Gate, Unit, Gw.Op, String, Gw.Reply>, +n: Nat, +label: String) -> IO(Unit):
  do IO<Unit>:
    out : C.Outcome<String, Gw.Reply> <- Gw.call(store, Gw.OpPeek{})
    held.of(out, n, label)

# A slow fetch holds the only unit; a request beside it gets 503.
def busy(+app: C.Application<Gw.Action, Gw.Config, C.Policy<String>>, +store: C.Context<G.Gate, Unit, Gw.Op, String, Gw.Reply>, client: Hairpin.Client) -> IO(Hairpin.Client):
  do IO<Hairpin.Client>:
    slow : Chan(C.Completion<Hairpin.Client, String>) <- IO.fork(C.Completion<Hairpin.Client, String>, ask(app, Gw.client(BASE()), "/items/slow-a", "reader"))
    IO.sleep(300)
    held(store, 1n, "a slow fetch holds one unit")
    r : C.Completion<Hairpin.Client, String> <- ask(app, client, "/items/2", "reader")
    c : Hairpin.Client <- expect(r, "503 at capacity", 503, "busy")
    s : C.Completion<Hairpin.Client, String> <- IO.join(C.Completion<Hairpin.Client, String>, slow)
    other : Hairpin.Client <- expect(s, "slow fetch completes", 200, "miss")
    Hairpin.close(other)
    held(store, 0n, "the slow fetch gave its unit back")
    return c

def scenarios(+app: C.Application<Gw.Action, Gw.Config, C.Policy<String>>, +store: C.Context<G.Gate, Unit, Gw.Op, String, Gw.Reply>, client: Hairpin.Client) -> IO(Hairpin.Client):
  do IO<Hairpin.Client>:
    a : C.Completion<Hairpin.Client, String> <- ask(app, client, "/items/1", "")
    c1 : Hairpin.Client <- expect(a, "no role is denied", 403, "")
    held(store, 0n, "a denied request reserves nothing")
    b : C.Completion<Hairpin.Client, String> <- ask(app, c1, "/items/1", "reader,suspended")
    c2 : Hairpin.Client <- expect(b, "a suspended reader is denied", 403, "")
    d : C.Completion<Hairpin.Client, String> <- ask(app, c2, "/items/1", "reader")
    c3 : Hairpin.Client <- expect(d, "first read misses", 200, "miss")
    e : C.Completion<Hairpin.Client, String> <- ask(app, c3, "/items/1", "reader")
    c4 : Hairpin.Client <- expect(e, "second read hits", 200, "hit")
    f : C.Completion<Hairpin.Client, String> <- ask(app, c4, "/items/gone", "reader")
    c5 : Hairpin.Client <- expect(f, "a missing item misses", 404, "miss")
    g : C.Completion<Hairpin.Client, String> <- ask(app, c5, "/items/gone", "reader")
    c6 : Hairpin.Client <- expect(g, "a missing item is remembered", 404, "hit")
    c7 : Hairpin.Client <- busy(app, store, c6)
    h : C.Completion<Hairpin.Client, String> <- ask(app, c7, "/items/broken", "reader")
    c8 : Hairpin.Client <- expect(h, "a failing upstream is 502", 502, "miss")
    i : C.Completion<Hairpin.Client, String> <- ask(app, c8, "/items/3", "reader")
    c9 : Hairpin.Client <- expect(i, "an open breaker is 503", 503, "open")
    j : C.Completion<Hairpin.Client, String> <- ask(app, c9, "/items/1", "reader")
    c10 : Hairpin.Client <- expect(j, "a hit is served while the breaker is open", 200, "hit")
    held(store, 0n, "every path gave its unit back")
    return c10

def closed(result: C.OwnerClose<G.Gate, Unit, Gw.Op, String, Gw.Reply>) -> IO(Unit):
  match result:
    case C.OwnerClosed{}:
      IO.pure(Unit, Unit{})
    case C.OwnerBusy{owner, counts}:
      IO.die(Unit, 1, "FAIL the gate is still busy")

def registered(r: Result<&2, &2, C.RegistrationError, C.Application<Gw.Action, Gw.Config, C.Policy<String>>>, +store: C.Context<G.Gate, Unit, Gw.Op, String, Gw.Reply>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "FAIL registration")
    case Done{app}:
      do IO<Unit>:
        client : Hairpin.Client <- scenarios(app, store, Gw.client(BASE()))
        Hairpin.close(client)

def prepared(p: C.Owner<G.Gate, Unit, Gw.Op, String, Gw.Reply> & C.Context<G.Gate, Unit, Gw.Op, String, Gw.Reply>) -> IO(Unit):
  (owner, +store) = p
  do IO<Unit>:
    registered(Gw.application(Gw.Config{store, Gw.readers(), 2n, 5000n}), store)
    r : C.OwnerClose<G.Gate, Unit, Gw.Op, String, Gw.Reply> <- C.close(G.Gate, Unit, Gw.Op, String, Gw.Reply, owner)
    closed(r)

def opened(r: Result<&2, &1, String, C.Owner<G.Gate, Unit, Gw.Op, String, Gw.Reply>>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "FAIL gate start")
    case Done{owner}:
      prepared(C.owner.context(G.Gate, Unit, Gw.Op, String, Gw.Reply, owner))

def serving(p: H.Server<Unit> & H.ServerControl) -> IO(Unit):
  (server, control) = p
  do IO<Unit>:
    exit : Chan(H.ServerExit) <- IO.fork(H.ServerExit, Up.run(server))
    r : Result<&2, &1, String, C.Owner<G.Gate, Unit, Gw.Op, String, Gw.Reply>> <- Gw.store.start(Gw.Setup{1n, Cache.Policy{60000n, 60000n}})
    opened(r)
    stopped : Bool <- H.server.stop(control)
    done : H.ServerExit <- IO.join(H.ServerExit, exit)
    IO.print("ALL GATEWAY CHECKS PASS")

def listening(result: Unit & Result<&2, &1, H.StartupError, H.Server<Unit>>) -> IO(Unit):
  (unit, r) = result
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "FAIL upstream listen")
    case Done{server}:
      serving(H.server.control(~Unit, server))

def main() -> IO(Unit):
  do IO<Unit>:
    result : Unit & Result<&2, &1, H.StartupError, H.Server<Unit>> <- Up.start(PORT())
    listening(result)
