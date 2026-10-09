# files

POSIX paths, directory listing, metadata, and packed file IO.

```bend
import bend-kit-files@0.1.1.1/files.bend as Fs
```

`path.is_absolute`, `path.join`, `path.normalize`, `path.parent`, `path.file_name`, and `path.extension` are pure. They do not touch the disk. `path.join` does not insert a slash that the arguments already imply. Check the result before you pass it to an effect.

Effects return `Result<&1, &1, U32 & String, _>`. The pair is errno and text. A `File` handle comes back beside the result. Pass that handle on.

```bend
def main() -> IO(Unit):
  do IO<Unit>:
    dir : String <- IO.try(String, Fs.temp_dir())
    IO.print(dir)
```

`IO.try` unwraps `Done` and fails the `IO` on `Fail`. Match the `Result` in a helper when you need the errno. `match` takes a parameter, not the bound name from the same def.


`read_bytes(file, max)` and `write_bytes(file, data)` use `Bytes`. This package imports `bend-kit-bytes@0.3.1.0`. `read.words` reads at most 1 MiB per call. A short read is not EOF. `write.words` writes the whole buffer or fails, and it does not roll back bytes already written.

`stat` follows symbolic links. `Info.size` and `Info.mtime` are `U32`. `mtime` is whole seconds since the Unix epoch. Both wrap at 2^32. `mkdir_all` creates each missing component and fails if a component exists and is not a directory. `temp_dir` creates a new private directory under the system temp dir.

The effects are `effs/files.c` and `effs/files.js`. Proofs do not cover them.
