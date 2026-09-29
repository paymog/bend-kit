# POSIX paths plus directory and metadata effects. Source: https://github.com/paymog/bend-kit/tree/main/files
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

# The path.* defs are pure and lexical: they never touch the disk.
# The effects are thin OS calls; each failure is (errno, text).
#   import ./files/files.bend as Fs

def path.is_absolute(p: String) -> Bool:
  String.starts_with(p, "/")

def path.join.rel(bare: Bool, a: String, b: String) -> String:
  match bare:
    case True{}:
      a ++ b
    case False{}:
      a ++ "/" ++ b

def path.join.if(abs: Bool, +a: String, b: String) -> String:
  match abs:
    case True{}:
      b
    case False{}:
      path.join.rel(String.is_empty(a) || String.ends_with(a, "/"), a, b)

# b when b is absolute; otherwise b under a.
def path.join(a: String, +b: String) -> String:
  path.join.if(path.is_absolute(b), a, b)

def path.norm.pop.if(up: Bool, h: String, t: List<&2, String>) ->
  List<&2, String>:
  match up:
    case True{}:
      ".." <> (h <> t)
    case False{}:
      t

# A ".." above the root is dropped; above a relative start it is kept.
def path.norm.pop(stack: List<&2, String>, abs: Bool) -> List<&2, String>:
  match stack:
    case Nil{}:
      Bool.pick(List<&2, String>, abs, Nil{}, [".."])
    case Con{+h, t}:
      path.norm.pop.if(String.eq(h, ".."), h, t)

def path.norm.step(
  skip: Bool, up: Bool, s: String, stack: List<&2, String>, abs: Bool
) -> List<&2, String>:
  match skip:
    case True{}:
      stack
    case False{}:
      match up:
        case True{}:
          path.norm.pop(stack, abs)
        case False{}:
          s <> stack

# The kept segments, last first.
def path.norm.go(segs: List<&2, String>, stack: List<&2, String>, +abs: Bool) ->
  List<&2, String>:
  match segs:
    case Nil{}:
      stack
    case Con{+s, t}:
      path.norm.go(t,
        path.norm.step(String.eq(s, "") || String.eq(s, "."), String.eq(s, ".."),
          s, stack, abs),
        abs)

def path.norm.fin(abs: Bool, body: String) -> String:
  match abs:
    case True{}:
      "/" ++ body
    case False{}:
      match body:
        case SNil{}:
          "."
        case SCon{h, t}:
          SCon{h, t}

# Drops empty and "." segments and resolves "..", as POSIX normpath does
# (RFC 3986 §5.2.4 for paths), but always to one leading "/".
def path.normalize(+p: String) -> String:
  +abs = path.is_absolute(p)
  path.norm.fin(abs,
    String.join(List.reverse(&2, String,
      path.norm.go(String.split(p, '/'), Nil{}, abs)), "/"))

def path.parent(p: String) -> String:
  +n = path.normalize(p)
  path.norm.fin(path.is_absolute(n),
    String.join(List.reverse(&2, String,
      List.tail(&2, String, List.reverse(&2, String, String.split(n, '/')))), "/"))

def path.file_name.fin(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{+s}:
      Bool.pick(String, String.eq(s, "."), "", s)

# The last segment of the normalized path; "" for "/" and ".".
def path.file_name(p: String) -> String:
  path.file_name.fin(List.last(&2, String, String.split(path.normalize(p), '/')))

def path.extension.fin(bare: Bool, ext: String) -> String:
  match bare:
    case True{}:
      ""
    case False{}:
      ext

def path.extension.go(rev: List<&2, String>) -> String:
  match rev:
    case Nil{}:
      ""
    case Con{ext, Nil{}}:
      ""
    case Con{ext, Con{prev, rest}}:
      path.extension.fin(String.is_empty(prev) && List.is_empty(&2, String, rest),
        ext)

# The text after the file name's last ".", without the dot. A leading dot
# does not start one: ".bashrc" has none.
def path.extension(p: String) -> String:
  path.extension.go(List.reverse(&2, String, String.split(path.file_name(p), '.')))

type FileType is Data:
  Regular{}
  Directory{}
  Other{}

# mtime is whole seconds since the Unix epoch. size and mtime wrap at 2^32.
type Info is Data:
  Info{kind: FileType, size: U32, mtime: U32}

# Entry names, NUL-separated, in the order the OS gives them.
def list_dir.raw(path: String) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/files.c"
  import "./effs/files.js"

# (kind, size, mtime); kind 0 is a regular file, 1 a directory, 2 other.
# Symbolic links are followed.
def stat.raw(path: String) ->
  IO(Result<&1, &1, U32 & String, U32 & U32 & U32>):
  import "./effs/files.c"
  import "./effs/files.js"

def mkdir(path: String) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/files.c"
  import "./effs/files.js"

# Removes a file or an empty directory.
def remove(path: String) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/files.c"
  import "./effs/files.js"

def rename(from: String, to: String) ->
  IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/files.c"
  import "./effs/files.js"

# Creates a new, empty, private directory under the system temp dir.
def temp_dir() -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/files.c"
  import "./effs/files.js"

# A successful zero-length read is EOF (or max = 0). Reads at most 1 MiB
# per call; a short read is not necessarily EOF. Errors retain the File.
def read.words(file: File, max: U32) ->
  IO(File & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/files.c"
  import "./effs/files.js"

def read_bytes.wrap(result: Result<&1, &1, U32 & String, U32 & Array<U32>>) ->
  Result<&1, &1, U32 & String, Bytes.Bytes>:
  match result:
    case Fail{err}:
      Fail{err}
    case Done{(len, words)}:
      Done{Bytes.Bytes{len, words}}

def read_bytes.pair(pair: File & Result<&1, &1, U32 & String, U32 & Array<U32>>) ->
  File & Result<&1, &1, U32 & String, Bytes.Bytes>:
  match pair:
    case (handle, result):
      (handle, read_bytes.wrap(result))

# The existing Bytes layout, without an octet List or String.
def read_bytes(file: File, max: U32) ->
  IO(File & Result<&1, &1, U32 & String, Bytes.Bytes>):
  do IO<File & Result<&1, &1, U32 & String, Bytes.Bytes>>:
    pair : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- read.words(file, max)
    return read_bytes.pair(pair)

# Writes the entire buffer or fails. Errors retain the File; writes before
# an error are not rolled back. A len beyond the word array fails EINVAL.
def write.words(file: File, len: U32, words: Array<U32>) ->
  IO(File & Result<&1, &1, U32 & String, Unit>):
  import "./effs/files.c"
  import "./effs/files.js"

def write_bytes(file: File, data: Bytes.Bytes) ->
  IO(File & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{len, buf} = data
  write.words(file, len, buf)

def list_dir.fin(r: Result<&1, &1, U32 & String, String>) ->
  Result<&1, &1, U32 & String, List<&2, String>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{s}:
      Done{List.sort(~String, ~String.is_le,
        List.filter(~String, ~(n => Bool.not(String.is_empty(n))),
          String.split(s, Chr{0})))}

# Entry names, without "." and "..", sorted.
def list_dir(path: String) ->
  IO(Result<&1, &1, U32 & String, List<&2, String>>):
  do IO<Result<&1, &1, U32 & String, List<&2, String>>>:
    r : Result<&1, &1, U32 & String, String> <- list_dir.raw(path)
    return list_dir.fin(r)

def stat.kind(+k: U32) -> FileType:
  Bool.pick(FileType, U32.is_eq(k, 0), Regular{},
    Bool.pick(FileType, U32.is_eq(k, 1), Directory{}, Other{}))

def stat.fin(r: Result<&1, &1, U32 & String, U32 & U32 & U32>) ->
  Result<&1, &1, U32 & String, Info>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(k, size, mtime)}:
      Done{Info{stat.kind(k), size, mtime}}

def stat(path: String) -> IO(Result<&1, &1, U32 & String, Info>):
  do IO<Result<&1, &1, U32 & String, Info>>:
    r : Result<&1, &1, U32 & String, U32 & U32 & U32> <- stat.raw(path)
    return stat.fin(r)

def exists(path: String) -> IO(Bool):
  do IO<Bool>:
    r : Result<&1, &1, U32 & String, U32 & U32 & U32> <- stat.raw(path)
    return Result.is_done(&1, &1, U32 & String, U32 & U32 & U32, r)

def mkdir_all.dir(r: Result<&1, &1, U32 & String, Info>) ->
  Result<&1, &1, U32 & String, Unit>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{Info{Directory{}, size, mtime}}:
      Done{Unit{}}
    case Done{i}:
      Fail{(17, "File exists")}

def mkdir_all.fail(exists: Bool, e: U32 & String,
  k: IO(Result<&1, &1, U32 & String, Unit>)) ->
  IO(Result<&1, &1, U32 & String, Unit>):
  match exists:
    case True{}:
      k
    case False{}:
      IO.pure(Result<&1, &1, U32 & String, Unit>, Fail{e})

def mkdir_all.step(r: Result<&1, &1, U32 & String, Unit>,
  k: IO(Result<&1, &1, U32 & String, Unit>)) ->
  IO(Result<&1, &1, U32 & String, Unit>):
  match r:
    case Fail{(+code, text)}:
      mkdir_all.fail(U32.is_eq(code, 17), (code, text), k)
    case Done{u}:
      k

def mkdir_all.go(segs: List<&2, String>, +at: String) ->
  IO(Result<&1, &1, U32 & String, Unit>):
  match segs:
    case Nil{}:
      do IO<Result<&1, &1, U32 & String, Unit>>:
        r : Result<&1, &1, U32 & String, Info> <- stat(at)
        return mkdir_all.dir(r)
    case Con{s, t}:
      +next = path.join(at, s)
      do IO<Result<&1, &1, U32 & String, Unit>>:
        r : Result<&1, &1, U32 & String, Unit> <- mkdir(next)
        mkdir_all.step(r, mkdir_all.go(t, next))

# Creates the directory and any missing parents. Succeeds when it is
# already a directory; fails if a component is not a directory.
def mkdir_all(+path: String) -> IO(Result<&1, &1, U32 & String, Unit>):
  mkdir_all.go(
    List.filter(~String, ~(n => Bool.not(String.eq(n, ""))),
      String.split(path, '/')),
    Bool.pick(String, path.is_absolute(path), "/", "."))
