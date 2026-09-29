import Base
import ./tar.bend as Tar
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# A header cannot be read from an empty archive.
law empty_is_truncated:
  {Tar.decode(Bytes.new(0)) == None{} : Maybe<&1, List<&1, Tar.Entry>>}

# A partial header cannot be read as a file.
law partial_header_is_truncated:
  {Tar.decode(Bytes.new(511)) == None{} : Maybe<&1, List<&1, Tar.Entry>>}

# Two zero blocks terminate an empty archive.
law zero_blocks_end_archive:
  {Tar.decode(Bytes.new(1024)) == Some{Nil{}} : Maybe<&1, List<&1, Tar.Entry>>}
