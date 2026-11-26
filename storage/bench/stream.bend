import Base
import ../http_stream_check.bend as Check
import bend-kit-files@0.4.0.3/files.bend as Files

def main() -> IO(Unit):
  do IO<Unit>:
    dir : String <- IO.try(String, Files.temp_dir())
    Check.one(0, dir)
    IO.print("17 MiB root: 89c9109ce931e20ac63a1729d6f6a9db03dee9401161eb8a3fbd35c4a09a9528")
