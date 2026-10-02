# Observe prerequisite contract gaps; this is not a conformance gate.
import Base
import ./interface_check.bend as Registry
import ../router/router.bend as Router
import ../json/json.bend as Json
import ../concurrency/concurrency.bend as Conc
import bend-kit-time@0.1.0.0/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

def truth(flag: Bool) -> String:
  match flag:
    case True{}: "true"
    case False{}: "false"

def absent(result: Maybe<&2, Map<&2, String>>) -> Bool:
  match result:
    case None{}: True{}
    case Some{fields}: False{}

def rejected(result: Maybe<&1, Json.Val>) -> Bool:
  match result:
    case None{}: True{}
    case Some{value}: False{}

def static(result: Maybe<&2, U32>) -> Bool:
  match result:
    case None{}: False{}
    case Some{value}: U32.is_eq(value, 2)

def nest(depth: Nat) -> String:
  match depth:
    case 0n: "0"
    case 1n+remaining: "[" ++ nest(remaining) ++ "]"

def observed(label: String, flag: Bool) -> IO(Unit):
  IO.print(label ++ "=" ++ truth(flag))

def elapsed(label: String, duration: Time.Duration) -> IO(Unit):
  Time.Duration{seconds, nanos} = duration
  IO.print(label ++ "\t" ++ Int.I64.show(seconds) ++ "\t" ++ U32.show(nanos))

def written(result: File & Result<&1, &1, U32 & String, Unit>, start: Time.Duration) -> IO(Unit):
  (journal, status) = result
  do IO<Unit>:
    IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, status))
    File.close(journal)
    finish : Time.Duration <- Time.mono()
    elapsed("late-side-effect", Time.Duration.sub(finish, start))

def late(journal: File, start: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(250)
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(journal, "late\n")
    written(result, start)

def deadline(result: Maybe<&1, Unit>) -> IO(Unit):
  match result:
    case None{}: IO.print("deadline-returned")
    case Some{unit}: IO.die(Unit, 1, "delayed action won deadline unexpectedly")

def run(path: String) -> IO(Unit):
  do IO<Unit>:
    observed("double-slash-distinct", absent(Router.route("GET", "GET", "/users/:id", "/users//7")))
    observed("trailing-slash-distinct", absent(Router.route("GET", "GET", "/users/7", "/users/7/")))
    observed("static-first-in-parameter-first-registry", static(Registry.choose(~U32, [Registry.Entry{"GET", "/users/:id", 1}, Registry.Entry{"GET", "/users/new", 2}], "GET", "/users/new")))
    observed("static-first-in-static-first-registry", static(Registry.choose(~U32, [Registry.Entry{"GET", "/users/new", 2}, Registry.Entry{"GET", "/users/:id", 1}], "GET", "/users/new")))
    observed("unpaired-surrogate-rejected", rejected(Json.parse.bytes(Json.utf8("\"\\uD800\""))))
    observed("nested-duplicate-rejected", rejected(Json.parse.bytes(Json.utf8("{\"outer\":{\"id\":1,\"id\":2}}"))))
    observed("depth-65-rejected", rejected(Json.parse.bytes(Json.utf8(nest(65n)))))
    journal : File <- IO.try(File, File.open(path, "w"))
    +start : Time.Duration <- Time.mono()
    result : Maybe<&1, Unit> <- Conc.timeout(Unit, 10, late(journal, start))
    deadline(result)
    finish : Time.Duration <- Time.mono()
    elapsed("deadline", Time.Duration.sub(finish, start))

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> path <> Nil{}: run(path)
    case _: IO.die(Unit, 1, "usage: prerequisites <owned-journal>")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
