import Base
import ./stream.bend as Stream
import bend-kit-files@0.1.1.0/files.bend as Files
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def require(ok: Bool, why: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, why)

def fixture(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case Some{b}:
      b
    case None{}:
      Bytes.new(0)

def wrote(p: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match p:
    case (f, r):
      do IO<Unit>:
        IO.pass(Unit, r)
        File.close(f)

def read(p: File & Result<&1, &1, U32 & String, Bytes.Bytes>, want: String) -> IO(Unit):
  match p:
    case (f, r):
      do IO<Unit>:
        b : Bytes.Bytes <- IO.pass(Bytes.Bytes, r)
        require(String.eq(Bytes.to_hex(b), want), "binary bytes or source position differ")
        File.close(f)

def status(o: Stream.Outcome, +kind: U32, n: U32) -> IO(Unit):
  match o:
    case Stream.Complete{count}:
      require(U32.is_eq(kind, 0) && U32.is_eq(count, n), "wrong complete count")
    case Stream.Failed{count, Stream.Limit{}}:
      require(U32.is_eq(kind, 1) && U32.is_eq(count, n), "wrong cap failure")
    case Stream.Failed{count, Stream.BadChunk{}}:
      require(U32.is_eq(kind, 2) && U32.is_eq(count, n), "wrong chunk failure")
    case Stream.Failed{count, Stream.Write{code, why}}:
      require(U32.is_eq(kind, 3) && U32.is_eq(count, n) && Bool.not(U32.is_eq(code, 0)) && Bool.not(String.is_empty(why)), "write error lost errno/count/message")
    case Stream.Failed{count, Stream.Read{code, why}}:
      IO.die(Unit, 1, "unexpected read failure: " ++ why)

def finish(p: File & File & Stream.Outcome, kind: U32, n: U32, rest: String) -> IO(Unit):
  match p:
    case (a, b, o):
      do IO<Unit>:
        status(o, kind, n)
        File.close(b)
        r : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Files.read_bytes(a, 16)
        read(r, rest)

def copy(+src: String, +dest: String, mode: String, chunk: U32, cap: U32, kind: U32, n: U32, rest: String, want: String) -> IO(Unit):
  do IO<Unit>:
    a : File <- IO.try(File, File.open(src, "r"))
    b : File <- IO.try(File, File.open(dest, mode))
    p : File & File & Stream.Outcome <- Stream.file.file(a, b, chunk, cap)
    finish(p, kind, n, rest)
    f : File <- IO.try(File, File.open(dest, "r"))
    r : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Files.read_bytes(f, 16)
    read(r, want)

def main() -> IO(Unit):
  do IO<Unit>:
    +dir : String <- IO.try(String, Files.temp_dir())
    +src : String = Files.path.join(dir, "source")
    +dst : String = Files.path.join(dir, "destination")
    f : File <- IO.try(File, File.open(src, "w"))
    p : File & Result<&1, &1, U32 & String, Unit> <- Files.write_bytes(f, fixture(Bytes.from_hex("00ff010203040506fe")))
    wrote(p)
    copy(src, dst, "w", 3, 9, 0, 9, "", "00ff010203040506fe")
    copy(src, dst, "w", 4, 5, 1, 5, "0506fe", "00ff010203")
    copy(src, dst, "w", 4, 0, 1, 0, "ff010203040506fe", "")
    copy(src, dst, "w", 0, 9, 2, 0, "00ff010203040506fe", "")
    copy(src, dst, "w", 1048577, 9, 2, 0, "00ff010203040506fe", "")
    copy(src, dst, "r", 4, 9, 3, 0, "03040506fe", "")
    copy(src, dst, "w", 1048576, 9, 0, 9, "", "00ff010203040506fe")
    f : File <- IO.try(File, File.open(src, "w"))
    File.close(f)
    copy(src, dst, "w", 1, 0, 0, 0, "", "")
    IO.try(Unit, Files.remove(src))
    IO.try(Unit, Files.remove(dst))
    IO.try(Unit, Files.remove(dir))
    IO.print("stream local binary/cap/validation/write-error checks ok")
