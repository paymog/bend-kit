import Base
import ./process.bend as Proc
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def expect.yes(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def expect.echo(value: U32 & Bytes.Bytes & Bytes.Bytes) -> IO(Unit):
  (code, out, err) = value
  do IO<Unit>:
    expect.yes(U32.is_eq(code, 0), "echo exit code")
    expect.yes(String.eq(Bytes.to_string(out), "hello; not a shell\n"), "echo stdout/argv")
    expect.yes(String.eq(Bytes.to_string(err), ""), "echo stderr")

def expect.failed(value: U32 & Bytes.Bytes & Bytes.Bytes) -> IO(Unit):
  (code, out, err) = value
  do IO<Unit>:
    expect.yes(U32.is_eq(code, 7), "nonzero exit code")
    expect.yes(String.eq(Bytes.to_string(out), ""), "nonzero stdout")
    expect.yes(String.eq(Bytes.to_string(err), "problem"), "nonzero stderr")

def expect.cat(value: U32 & Bytes.Bytes & Bytes.Bytes) -> IO(Unit):
  (code, out, err) = value
  do IO<Unit>:
    expect.yes(U32.is_eq(code, 0), "cat exit code")
    expect.yes(String.eq(Bytes.to_string(out), "a\0b"), "stdin/stdout binary roundtrip")
    expect.yes(String.eq(Bytes.to_string(err), ""), "cat stderr")

def expect.env(value: U32 & Bytes.Bytes & Bytes.Bytes) -> IO(Unit):
  (code, out, err) = value
  do IO<Unit>:
    expect.yes(U32.is_eq(code, 0), "env exit code")
    expect.yes(String.eq(Bytes.to_string(out), "overridden"), "environment overlay")
    expect.yes(String.eq(Bytes.to_string(err), ""), "env stderr")

def expect.missing(value: Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>,
                   message: String) -> IO(Unit):
  match value:
    case Fail{_}:
      IO.pure(Unit, Unit{})
    case Done{_}:
      IO.die(Unit, 1, message)

def expect.child.read(expected: String,
                      pair: File & Result<&1, &1, U32 & String, String>,
                      pid: U32, errors: File) -> IO(Unit):
  (output, received) = pair
  do IO<Unit>:
    text : String <- IO.pass(String, received)
    File.close(output)
    File.close(errors)
    status : U32 <- IO.try(U32, Proc.wait(pid))
    expect.yes(String.eq(text, expected), "spawn output")
    expect.yes(U32.is_eq(status, 0), "spawn status")

def expect.child.written(+expected: String,
                         pair: File & Result<&1, &1, U32 & String, Unit>,
                         pid: U32, output: File, errors: File) -> IO(Unit):
  (input, sent) = pair
  do IO<Unit>:
    IO.pass(Unit, sent)
    File.close(input)
    received : File & Result<&1, &1, U32 & String, String> <-
      File.read(output, U32.from_nat(Nat.add(String.length(expected), 1n)))
    expect.child.read(expected, received, pid, errors)

def expect.child(expected: String, input_text: String,
                 child: U32 & File & File & File) -> IO(Unit):
  (pid, input, output, errors) = child
  do IO<Unit>:
    sent : File & Result<&1, &1, U32 & String, Unit> <- File.write(input, input_text)
    expect.child.written(expected, sent, pid, output, errors)

def expect.command(expected: String, value: U32 & Bytes.Bytes & Bytes.Bytes) -> IO(Unit):
  (code, out, err) = value
  do IO<Unit>:
    expect.yes(U32.is_eq(code, 0), "cwd command exit code")
    expect.yes(String.eq(Bytes.to_string(out), expected), "cwd command stdout")
    expect.yes(String.eq(Bytes.to_string(err), ""), "cwd command stderr")

def expect.cwd() -> IO(Unit):
  do IO<Unit>:
    +parent : String <- IO.try(String, Proc.cwd())
    own : U32 <- Proc.pid()
    +relative : String = ".process-cwd-" ++ U32.show(own)
    +root : String = parent ++ "/" ++ relative
    +first : String = root ++ "/first"
    +second_relative : String = relative ++ "/second directory"
    +second : String = parent ++ "/" ++ second_relative
    setup : U32 & Bytes.Bytes & Bytes.Bytes <- IO.try(U32 & Bytes.Bytes & Bytes.Bytes,
      Proc.run("/bin/sh", ["-c",
        "mkdir \"$1\" \"$2\" \"$3\" && printf first > \"$2/marker\" && printf second > \"$3/marker\"",
        "process-cwd-setup", root, first, second], [], ".", Bytes.from_string("")))
    expect.command("", setup)

    # Both children wait for input before reading a file relative to their cwd.
    first_child : U32 & File & File & File <- IO.try(U32 & File & File & File,
      Proc.spawn("/bin/sh", ["-c", "read ready; exec /bin/cat marker"], [], first))
    second_child : U32 & File & File & File <- IO.try(U32 & File & File & File,
      Proc.spawn("/bin/sh", ["-c", "read ready; exec /bin/cat marker"], [], second_relative))
    after_spawn : String <- IO.try(String, Proc.cwd())
    expect.yes(String.eq(parent, after_spawn), "spawns preserve parent cwd")
    expect.child("first", "\n", first_child)
    expect.child("second", "\n", second_child)

    captured : U32 & Bytes.Bytes & Bytes.Bytes <- IO.try(U32 & Bytes.Bytes & Bytes.Bytes,
      Proc.run("/bin/cat", ["marker"], [], first, Bytes.from_string("")))
    expect.command("first", captured)
    after_run : String <- IO.try(String, Proc.cwd())
    expect.yes(String.eq(parent, after_run), "run preserves parent cwd")
    missing : Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes> <-
      Proc.run("/bin/cat", [], [], root ++ "/missing", Bytes.from_string(""))
    expect.missing(missing, "missing directory must fail to spawn")

    cleanup : U32 & Bytes.Bytes & Bytes.Bytes <- IO.try(U32 & Bytes.Bytes & Bytes.Bytes,
      Proc.run("/bin/sh", ["-c",
        "rm \"$1/marker\" \"$2/marker\" && rmdir \"$1\" \"$2\" \"$3\"",
        "process-cwd-cleanup", first, second, root], [], ".", Bytes.from_string("")))
    expect.command("", cleanup)

def expect.os() -> IO(Unit):
  do IO<Unit>:
    id : U32 <- Proc.pid()
    expect.yes(U32.is_gt(id, 0), "process pid")
    host : String <- IO.try(String, Proc.hostname())
    expect.yes(Bool.not(String.eq(host, "")), "hostname")
    +dir : String <- IO.try(String, Proc.cwd())
    IO.try(Unit, Proc.chdir(dir))
    again : String <- IO.try(String, Proc.cwd())
    expect.yes(String.eq(dir, again), "cwd/chdir")

def signal.send(own: U32) ->
  IO(Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>):
  Proc.run("/bin/kill", ["-TERM", U32.show(own)], [], ".", Bytes.from_string(""))

def expect.signal() -> IO(Unit):
  do IO<Unit>:
    zero : U32 <- Proc.signal.poll()
    expect.yes(U32.is_eq(zero, 0), "initial signal poll")
    own : U32 <- Proc.pid()
    killed : U32 & Bytes.Bytes & Bytes.Bytes <-
      IO.try(U32 & Bytes.Bytes & Bytes.Bytes, signal.send(own))
    IO.sleep(50)
    event : U32 <- Proc.signal.poll()
    expect.yes(U32.is_eq(event, 15), "SIGTERM delivery")

def main() -> IO(Unit):
  do IO<Unit>:
    echo : U32 & Bytes.Bytes & Bytes.Bytes <- IO.try(U32 & Bytes.Bytes & Bytes.Bytes,
      Proc.run("/bin/echo", ["hello; not a shell"], [], ".", Bytes.from_string("")))
    expect.echo(echo)

    failed : U32 & Bytes.Bytes & Bytes.Bytes <- IO.try(U32 & Bytes.Bytes & Bytes.Bytes,
      Proc.run("/bin/sh", ["-c", "printf problem >&2; exit 7"], [], ".", Bytes.from_string("")))
    expect.failed(failed)

    cat : U32 & Bytes.Bytes & Bytes.Bytes <- IO.try(U32 & Bytes.Bytes & Bytes.Bytes,
      Proc.run("/bin/cat", [], [], ".", Bytes.from_string("a\0b")))
    expect.cat(cat)

    environment : U32 & Bytes.Bytes & Bytes.Bytes <- IO.try(U32 & Bytes.Bytes & Bytes.Bytes,
      Proc.run("/bin/sh", ["-c", "printf %s \"$BEND_KIT_PROCESS_SMOKE\""],
        ["BEND_KIT_PROCESS_SMOKE=overridden"], ".", Bytes.from_string("")))
    expect.env(environment)

    missing : Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes> <-
      Proc.run("/definitely-not-a-command", [], [], ".", Bytes.from_string(""))
    expect.missing(missing, "missing executable must fail to spawn")

    child : U32 & File & File & File <- IO.try(U32 & File & File & File,
      Proc.spawn("/bin/cat", [], [], "."))
    expect.child("stream", "stream", child)
    expect.cwd()
    expect.os()
    expect.signal()

    IO.print("process smoke ok")
