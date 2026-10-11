# One Camber route guarded by an authz policy: allow, deny overrides, missing context, and restriction.
import Base
import ./authz.bend as Az
import bend-kit-camber@0.7.0.0/camber.bend as C
import bend-kit-http@0.32.0.0/http.bend as H
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B

# The protected effects that ran, oldest first.
type State is Data:
  State{events: List<&2, String>}

type Config is Data:
  Config{policy: Az.Policy}

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

# Owners delete their documents. Admins delete any document. A suspended role always denies.
def documents() -> Az.Policy:
  Az.DenyOverrides{
    Az.DenyOverrides{Az.Permit{Az.AllOf{Az.Action{"DELETE"}, Az.Owner{}}}, Az.Permit{Az.Role{"admin"}}},
    Az.Forbid{Az.Role{"suspended"}}}

# A read-only restriction on top of the document policy.
def read_only() -> Az.Policy:
  Az.Intersect{documents(), Az.Permit{Az.Action{"GET"}}}

# The document table. A missing document has no known owner.
def owner(target: String) -> Maybe<&2, String>:
  match target:
    case "/docs/1":
      Some{"alice"}
    case "/docs/2":
      Some{"bob"}
    case _:
      None{}

def present(value: String) -> Maybe<&2, String>:
  match value:
    case "":
      None{}
    case other:
      Some{other}

def split(s: String, cur: String) -> List<&2, String>:
  match s:
    case SNil{}:
      [cur]
    case SCon{Chr{44}, rest}:
      cur <> split(rest, "")
    case SCon{c, rest}:
      split(rest, cur ++ SCon{c, SNil{}})

def roles(value: String) -> Maybe<&2, List<&2, String>>:
  match value:
    case "":
      None{}
    case other:
      Some{split(other, "")}

# Authentication is outside this check: x-subject and x-roles stand for verified identity.
def request(meta: C.Metadata) -> Az.Request:
  C.Metadata{method, +target, +headers} = meta
  Az.Request{present(H.header(headers, "x-subject")), roles(H.header(headers, "x-roles")), owner(target), method, target}

def gate(allowed: Bool, state: State) -> C.Step<State, String>:
  match allowed:
    case True{}:
      C.Continue{state}
    case False{}:
      C.Early{state, C.empty(403)}

def before(hook: String, state: State, config: Config, meta: C.Metadata) -> IO(C.Step<State, String>):
  Config{policy} = config
  IO.pure(C.Step<State, String>, gate(Az.granted(policy, request(meta)), state))

def after(hook: String, state: State, config: Config, response: H.Res) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Done{response}))

def mapper(state: State, config: Config, error: C.Error<String>) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Done{C.default.error(~String, error)}))

# The protected operation. Its only effect is the event it records.
def run(action: U32, state: State, config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  State{events} = state
  H.Req{method, +target, headers, body} = req
  do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
    IO.print("effect: delete " ++ target)
    return (State{List.append(&2, String, events, ["delete " ++ target])}, Done{C.empty(204)})

def application(policy: Az.Policy) -> Result<&2, &2, C.RegistrationError, C.Application<U32, Config, C.Policy<String>>>:
  C.application(~U32, ~Config, ~C.Policy<String>,
    [C.Route{"DELETE", "/docs/:id", 1, Nil{}, C.policy(~String, 1, ["authz"], Nil{})}],
    Nil{}, Config{policy}, C.policy(~String, 0, Nil{}, Nil{}))

def join(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case x <> rest:
      x ++ ";" ++ join(rest)

def checked(completion: C.Completion<State, String>, +label: String, +status: U32, +events: String) -> IO(Unit):
  C.Completed{State{+seen}, H.Res{+actual, headers, body}, entered, mapped, stopped} = completion
  do IO<Unit>:
    require(U32.is_eq(actual, status), label ++ ": status " ++ U32.show(actual) ++ " expected " ++ U32.show(status))
    require(String.eq(join(seen), events), label ++ ": effects " ++ join(seen) ++ " expected " ++ events)
    IO.print("PASS " ++ label ++ " " ++ U32.show(actual))

def scenario(result: Result<&2, &2, C.RegistrationError, C.Application<U32, Config, C.Policy<String>>>, label: String, target: String, subject: String, roles: String, status: U32, events: String) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit, 1, "registration")
    case Done{app}:
      do IO<Unit>:
        completion : C.Completion<State, String> <- C.dispatch(~U32, ~State, ~Config, ~String, ~String, ~Unit,
          ~before, ~after, ~run, ~mapper, ~C.notice.ignore(~Unit, ~String, ~String), ~C.notice.error.ignore(~Unit, ~String),
          Unit{}, C.access.disabled(~Unit, Unit{}), app, State{Nil{}},
          H.Req{"DELETE", target, H.set(H.set(H.empty(), "x-subject", subject), "x-roles", roles), H.from_string("")})
        checked(completion, label, status, events)

def main() -> IO(Unit):
  do IO<Unit>:
    scenario(application(documents()), "owner allowed", "/docs/1", "alice", "editor", 204, "delete /docs/1;")
    scenario(application(documents()), "admin allowed", "/docs/2", "carol", "admin", 204, "delete /docs/2;")
    scenario(application(documents()), "not owner", "/docs/2", "alice", "editor", 403, "")
    scenario(application(documents()), "deny overrides owner", "/docs/1", "alice", "editor,suspended", 403, "")
    scenario(application(documents()), "deny overrides admin", "/docs/2", "carol", "admin,suspended", 403, "")
    scenario(application(documents()), "missing subject", "/docs/1", "", "editor", 403, "")
    scenario(application(documents()), "missing owner", "/docs/9", "alice", "editor", 403, "")
    scenario(application(documents()), "missing roles", "/docs/1", "alice", "", 403, "")
    scenario(application(read_only()), "restricted admin", "/docs/2", "carol", "admin", 403, "")
    scenario(application(read_only()), "restricted owner", "/docs/1", "alice", "editor", 403, "")
