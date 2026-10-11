# Published direct acceptance consumer: one reusable application/state and one actual Store Owner.
import Base
import ./users.bend as U
import bend-kit-camber@0.7.0.0/camber.bend as C
import bend-kit-camber@0.7.0.0/notices.bend as N
import bend-kit-http@0.32.0.0/http.bend as H
import bend-kit-json@0.5.1.0/json.bend as J
import bend-kit-router@0.2.0.0/router.bend as R
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B

def digit(c: U32) -> U32:
  match c:
    case 48: 0
    case 49: 1
    case 50: 2
    case 51: 3
    case 52: 4
    case 53: 5
    case 54: 6
    case 55: 7
    case 56: 8
    case 57: 9
    case 97: 10
    case 98: 11
    case 99: 12
    case 100: 13
    case 101: 14
    case 102: 15
    case _: 0

def unhex(text: String) -> String:
  match text:
    case SCon{Chr{a}, SCon{Chr{b}, rest}}: SCon{Chr{(digit(a) * 16 + digit(b) : U32)}, unhex(rest)}
    case _: ""

def response.hex(body: H.Body) -> String:
  B.to_hex(body)

def response(res: H.Res) -> IO(Unit):
  H.Res{+status, +headers, body} = res
  IO.print("RESPONSE " ++ H.to_string(J.encode.bytes(J.Obj{
    [(J.utf8("status"), J.Num{J.utf8(U32.show(status))}),
     (J.utf8("allow"), J.Str{J.utf8(H.header(headers, "allow"))}),
     (J.utf8("location"), J.Str{J.utf8(H.header(headers, "location"))}),
     (J.utf8("www-authenticate"), J.Str{J.utf8(H.header(headers, "www-authenticate"))}),
     (J.utf8("content-type"), J.Str{J.utf8(H.header(headers, "content-type"))}),
     (J.utf8("x-plain"), J.Str{J.utf8(H.header(headers, "x-plain"))}),
     (J.utf8("x-root"), J.Str{J.utf8(H.header(headers, "x-root"))}),
     (J.utf8("x-group"), J.Str{J.utf8(H.header(headers, "x-group"))}),
     (J.utf8("x-route"), J.Str{J.utf8(H.header(headers, "x-route"))}),
     (J.utf8("body"), J.Str{J.utf8(response.hex(body))})]})))

def finished(completion: C.Completion<U.State, String>) -> IO(U.State):
  C.Completed{state, res, entered, mapped, stopped} = completion
  do IO<U.State>:
    response(res)
    return state

def dispatch(+app: C.Application<U.Action, U.Config, C.Policy<String>>, state: U.State, req: H.Req) -> IO(U.State):
  C.Application{table, +config, root, groups} = app
  do IO<U.State>:
    completion : C.Completion<U.State, String> <- C.dispatch(~U.Action, ~U.State, ~U.Config, ~String, ~String, ~U.Config,
      ~U.before, ~U.after, ~U.run, ~U.mapper, ~U.notify, ~U.report, config, N.Disabled{}, app, state, req)
    finished(completion)

def requests(values: List<&1, String>, +app: C.Application<U.Action, U.Config, C.Policy<String>>, state: U.State) -> IO(Unit):
  match values:
    case Nil{}: U.destroy(state)
    case +label <> method <> target <> token <> media <> encoding <> fault <> hex <> rest:
      do IO<Unit>:
        IO.print("CASE " ++ label)
        headers : Map<&2, List<&2, String>> = H.set(H.set(H.set(H.set(H.set(H.set(H.empty(), "x-case", label), "authorization", token), "content-type", media), "content-encoding", encoding), "x-invalid", fault), "host", "wrong.test")
        returned : U.State <- dispatch(app, state, H.Req{method, target, headers, H.from_string(unhex(hex))})
        requests(rest, app, returned)
    case _: IO.die(Unit, 1, "incomplete batch request")

def store.closed(result: C.OwnerClose<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  match result:
    case C.OwnerClosed{}: IO.print("STORE JOINED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "store busy after completion")

def registered(result: Result<&2, &2, C.RegistrationError, C.Application<U.Action, U.Config, C.Policy<String>>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, values: List<&1, String>) -> IO(Unit):
  match result:
    case Fail{error}:
      do IO<Unit>:
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        store.closed(closed)
        IO.die(Unit, 1, "registration failed")
    case Done{app}:
      do IO<Unit>:
        requests(values, app, U.fresh())
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        store.closed(closed)

def duplicate.accepted(result: Result<&2, &2, C.RegistrationError, C.Application<U.Action, U.Config, C.Policy<String>>>) -> Bool:
  match result:
    case Fail{C.RouteError{R.Duplicate{method, pattern}}}: True{}
    case _: False{}

def duplicate(result: Result<&2, &2, C.RegistrationError, C.Application<U.Action, U.Config, C.Policy<String>>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  do IO<Unit>:
    accepted : Bool = duplicate.accepted(result)
    closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
    store.closed(closed)
    U.require(accepted, "expected duplicate-registration error")

def ordinary(is_plain: Bool, config: U.Config, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, reverse: Bool, values: List<&1, String>) -> IO(Unit):
  match is_plain:
    case True{}: registered(U.fixture(config), owner, values)
    case False{}: registered(U.application(config, reverse), owner, values)

def selected(is_duplicate: Bool, config: U.Config, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, is_plain: Bool, reverse: Bool, values: List<&1, String>) -> IO(Unit):
  match is_duplicate:
    case True{}: duplicate(C.application(~U.Action, ~U.Config, ~C.Policy<String>,
      [C.Route{"GET", "/users/:id", U.ById{}, Nil{}, C.policy(~String, 2, Nil{}, Nil{})},
       C.Route{"GET", "/users/:name", U.ById{}, Nil{}, C.policy(~String, 2, Nil{}, Nil{})}], Nil{}, config, C.policy(~String, 0, Nil{}, Nil{})), owner)
    case False{}: ordinary(is_plain, config, owner, reverse, values)

def prepared(prepared: C.Owner<U.Store, U32, U.Operation, String, U.User> & C.Context<U.Store, U32, U.Operation, String, U.User>, +fixture: String, reverse: Bool, fault: String, values: List<&1, String>) -> IO(Unit):
  (owner, context) = prepared
  selected(String.eq(fixture, "duplicate"), U.Config{context, U.Disabled{}, fault}, owner, String.eq(fixture, "plain"), reverse, values)

def opened(result: Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>>, fixture: String, reverse: Bool, fault: String, values: List<&1, String>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "store startup failed")
    case Done{owner}: prepared(C.owner.context(U.Store, U32, U.Operation, String, U.User, owner), fixture, reverse, fault, values)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> +fixture <> order <> fault <> journal <> rest:
      do IO<Unit>:
        result : Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>> <- C.start(~U.StoreConfig, ~U.Store, ~U32, ~U.Operation, ~String, ~U.User,
          ~U.store.open, ~U.store.work, ~U.store.close, U.StoreConfig{journal, Bool.not(String.eq(fixture, "default"))}, 1n, 16)
        opened(result, fixture, String.eq(order, "reverse"), fault, rest)
    case _: IO.die(Unit, 1, "expected fixture order fault journal [batch]")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
