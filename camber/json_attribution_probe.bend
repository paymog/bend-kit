# Stage timings without HTTP, routing, hooks, or socket effects.
import Base
import ../json/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-time@0.1.2.1/time.bend as Time
import ./prerequisites.bend as Probe

def end_stage(label: String, started: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    finished : Time.Duration <- Time.mono()
    Probe.elapsed(label, Time.Duration.sub(finished, started))

def erased(value: Maybe<&1, Json.Val>, started: Time.Duration) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "parse failed")
    case Some{document}:
      end_stage("DISPOSE", started)

def retained(value: Maybe<&1, Json.Val>, +output: Chan(Maybe<&1, Json.Val>), started: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    sent : Result<&1, &1, Maybe<&1, Json.Val>, Unit> <- Chan.send(Maybe<&1, Json.Val>, output, value)
    end_stage("PARSE", started)
    disposal : Time.Duration <- Time.mono()
    received : Maybe<&1, Json.Val> <- IO.join(Maybe<&1, Json.Val>, output)
    erased(received, disposal)

def measure(body: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    output0 : Chan(Maybe<&1, Json.Val>) <- Chan.new(Maybe<&1, Json.Val>, 1)
    +output : Chan(Maybe<&1, Json.Val>) = output0
    started : Time.Duration <- Time.mono()
    retained(Json.parse.bytes(body), output, started)

def consume(count: Nat, +bodies: Chan(Bytes.Bytes)) -> IO(Unit):
  match count:
    case 0n:
      IO.print("BATCH_DONE")
    case 1n+rest:
      do IO<Unit>:
        body : Bytes.Bytes <- IO.join(Bytes.Bytes, bodies)
        measure(body)
        consume(rest, bodies)

def queued(result: File & Result<&1, &1, U32 & String, String>, bodies: Chan(Bytes.Bytes)) -> IO(Unit):
  (file, outcome) = result
  do IO<Unit>:
    File.close(file)
    text : String <- IO.pass(String, outcome)
    sent : Result<&1, &1, Bytes.Bytes, Unit> <- Chan.send(Bytes.Bytes, bodies, Bytes.from_string(text))
    return Unit{}

def packed() -> Bytes.Bytes:
  a = Array.new(U32, 18n, 741354544)
  b = Array.set(U32, a, 0, 1868833403)
  c = Array.set(U32, b, 1, 1530536547)
  Bytes.Bytes{1048576, Array.set(U32, c, 262143, 545086768)}

def load_one(path: String, bodies: Chan(Bytes.Bytes)) -> IO(Unit):
  match path:
    case "packed":
      do IO<Unit>:
        sent : Result<&1, &1, Bytes.Bytes, Unit> <- Chan.send(Bytes.Bytes, bodies, packed())
        return Unit{}
    case _:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(path, "r"))
        result : File & Result<&1, &1, U32 & String, String> <- File.read(file, 1048576)
        queued(result, bodies)

def load(count: Nat, +path: String, +bodies: Chan(Bytes.Bytes)) -> IO(Unit):
  match count:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        load_one(path, bodies)
        load(rest, path, bodies)

def start(path: String, +count: U32) -> IO(Unit):
  do IO<Unit>:
    bodies0 : Chan(Bytes.Bytes) <- Chan.new(Bytes.Bytes, count)
    +bodies : Chan(Bytes.Bytes) = bodies0
    load(U32.to_nat(count), path, bodies)
    IO.print("BATCH_BEGIN")
    IO.sleep(100)
    consume(U32.to_nat(count), bodies)

def number(path: String, count: Maybe<&2, U32>) -> IO(Unit):
  match count:
    case None{}:
      IO.die(Unit, 1, "invalid count")
    case Some{n}:
      start(path, n)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> path <> count <> Nil{}:
      number(path, U32.read(count))
    case _:
      IO.die(Unit, 1, "expected path and count")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
