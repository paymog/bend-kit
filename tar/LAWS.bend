import Base
import ./tar.bend as Tar
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

# A header cannot be read from an empty archive.
law empty_is_truncated:
  {Tar.decode(Bytes.new(0)) == None{} : Maybe<&1, List<&1, Tar.Entry>>}

# A partial header cannot be read as a file.
law partial_header_is_truncated:
  {Tar.decode(Bytes.new(511)) == None{} : Maybe<&1, List<&1, Tar.Entry>>}

# Two zero blocks terminate an empty archive.
law zero_blocks_end_archive:
  {Tar.decode(Bytes.new(1024)) == Some{Nil{}} : Maybe<&1, List<&1, Tar.Entry>>}
