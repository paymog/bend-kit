import Base
import ./stream.bend as Stream

# Pure control decisions only. These claims do not prove host IO behavior.
law chunk_zero:
  {Stream.chunk.valid(0) == False{} : Bool}

law chunk_minimum:
  {Stream.chunk.valid(1) == True{} : Bool}

law chunk_maximum:
  {Stream.chunk.valid(1048576) == True{} : Bool}

law chunk_excess:
  {Stream.chunk.valid(1048577) == False{} : Bool}

law request_chunk_bound:
  {Stream.request(4096, 9000) == 4096 : U32}

law request_cap_bound:
  {Stream.request(4096, 3) == 3 : U32}

law request_probe:
  {Stream.request(4096, 0) == 1 : U32}

law eof_before_cap:
  {Stream.read.action(0, 3) == Stream.End{} : Stream.ReadAction}

law eof_at_cap:
  {Stream.read.action(0, 0) == Stream.End{} : Stream.ReadAction}

law nonempty_probe:
  {Stream.read.action(1, 0) == Stream.Over{} : Stream.ReadAction}

law short_read_continues:
  {Stream.read.action(1, 4096) == Stream.Forward{} : Stream.ReadAction}
