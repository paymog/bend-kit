import Base
import ./files.bend as Fs
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def names_ok(xs: List<&2, String>) -> Bool:
  match xs:
    case Con{a, Con{b, Nil{}}}:
      String.eq(a, "moved") && String.eq(b, "nested")
    case _:
      False{}

def stat_ok(i: Fs.Info) -> Bool:
  match i:
    case Fs.Info{Fs.Regular{}, size, mtime}:
      U32.is_eq(size, 3)
    case Fs.Info{kind, size, mtime}:
      False{}

def must_fail(r: Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.pure(Unit, Unit{})
    case Done{u}:
      IO.die(Unit, 1, "mkdir_all accepted a regular file")

def finish_write(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match pair:
    case (handle, written):
      do IO<Unit>:
        IO.pass(Unit, written)
        File.close(handle)

def checked_write(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  match pair:
    case (handle, result):
      do IO<File>:
        IO.pass(Unit, result)
        return handle

def invalid_write(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  match pair:
    case (handle, Fail{(code, text)}):
      do IO<File>:
        require(U32.is_eq(code, 22), "invalid packed length did not fail EINVAL")
        return handle
    case (handle, Done{unit}):
      IO.die(File, 1, "invalid packed length succeeded")

def checked_read(pair: File & Result<&1, &1, U32 & String, Bytes.Bytes>, want: String) -> IO(File):
  match pair:
    case (handle, result):
      do IO<File>:
        data : Bytes.Bytes <- IO.pass(Bytes.Bytes, result)
        require(String.eq(Bytes.to_hex(data), want), "packed read has wrong bytes")
        return handle

def read_error(pair: File & Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(File):
  match pair:
    case (handle, result):
      match result:
        case Fail{err}:
          IO.pure(File, handle)
        case Done{data}:
          IO.die(File, 1, "read from write-only file succeeded")

def fixture(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case Some{data}:
      data
    case None{}:
      Bytes.new(0)

def packed(dir: String) -> IO(Unit):
  do IO<Unit>:
    +path : String = Fs.path.join(dir, "packed")
    file : File <- IO.try(File, File.open(path, "w"))
    pair : File & Result<&1, &1, U32 & String, Unit> <-
      Fs.write.words(file, 5, Bytes.alloc(0))
    file : File <- invalid_write(pair)
    pair : File & Result<&1, &1, U32 & String, Unit> <-
      Fs.write_bytes(file, fixture(Bytes.from_hex("00ff010203fe")))
    file : File <- checked_write(pair)
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 2)
    file : File <- read_error(pair)
    File.close(file)
    file : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 1)
    file : File <- checked_read(pair, "00")
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 4)
    file : File <- checked_read(pair, "ff010203")
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 4)
    file : File <- checked_read(pair, "fe")
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 4)
    file : File <- checked_read(pair, "")
    File.close(file)
    file : File <- IO.try(File, File.open(path, "w"))
    pair : File & Result<&1, &1, U32 & String, Unit> <-
      Fs.write_bytes(file, fixture(Bytes.from_hex("00ff010203040506fe")))
    file : File <- checked_write(pair)
    File.close(file)
    file : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 9)
    file : File <- checked_read(pair, "00ff010203040506fe")
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 9)
    file : File <- checked_read(pair, "")
    File.close(file)
    IO.try(Unit, Fs.remove(path))

def main() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(Fs.path.parent("."), ".") &&
      String.eq(Fs.path.parent("../.."), ".."), "relative parent is wrong")
    +dir : String <- IO.try(String, Fs.temp_dir())
    empty : List<&2, String> <- IO.try(List<&2, String>, Fs.list_dir(dir))
    require(List.is_empty(&2, String, empty), "new temp directory is not empty")
    packed(dir)
    +nested : String = Fs.path.join(dir, "nested/child")
    IO.try(Unit, Fs.mkdir_all(nested))
    IO.try(Unit, Fs.mkdir_all(nested))
    +file : String = Fs.path.join(dir, "original")
    handle : File <- IO.try(File, File.open(file, "w"))
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(handle, "abc")
    finish_write(result)
    info : Fs.Info <- IO.try(Fs.Info, Fs.stat(file))
    require(stat_ok(info), "stat should report a three-byte regular file")
    failure : Result<&1, &1, U32 & String, Unit> <- Fs.mkdir_all(file)
    must_fail(failure)
    through_file : Result<&1, &1, U32 & String, Unit> <-
      Fs.mkdir_all(Fs.path.join(file, "../created"))
    must_fail(through_file)
    created : Bool <- Fs.exists(Fs.path.join(dir, "created"))
    require(Bool.not(created), "mkdir_all crossed a regular file")
    +moved : String = Fs.path.join(dir, "moved")
    IO.try(Unit, Fs.rename(file, moved))
    old : Bool <- Fs.exists(file)
    require(Bool.not(old), "renamed source still exists")
    names : List<&2, String> <- IO.try(List<&2, String>, Fs.list_dir(dir))
    require(names_ok(names), "directory listing is not sorted or complete")
    IO.try(Unit, Fs.remove(moved))
    IO.try(Unit, Fs.remove(nested))
    IO.try(Unit, Fs.remove(Fs.path.join(dir, "nested")))
    IO.try(Unit, Fs.remove(dir))
    IO.print("filesystem smoke ok")
