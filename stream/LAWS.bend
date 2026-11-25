import Base
import ./pure.bend as Stream

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

law chunk_interval:
  for chunk: U32
  {Stream.chunk.valid(chunk) == (U32.is_ge(chunk, 1) && U32.is_le(chunk, 1048576)) : Bool}

law request_bounds:
  for chunk: U32
  for remaining: U32
  for nonzero: {U32.is_zero(remaining) == False{} : Bool}
  {U32.is_le(Stream.request(chunk, remaining), chunk) == True{} : Bool} &
  {U32.is_le(Stream.request(chunk, remaining), remaining) == True{} : Bool}

law request_probe_general:
  for chunk: U32
  {Stream.request(chunk, 0) == 1 : U32}

law read_eof_general:
  for len: U32
  for remaining: U32
  for zero: {U32.is_zero(len) == True{} : Bool}
  {Stream.read.action(len, remaining) == Stream.End{} : Stream.ReadAction}

law read_probe_general:
  for len: U32
  for remaining: U32
  for nonempty: {U32.is_zero(len) == False{} : Bool}
  for probe: {U32.is_zero(remaining) == True{} : Bool}
  {Stream.read.action(len, remaining) == Stream.Over{} : Stream.ReadAction}

law read_forward_general:
  for len: U32
  for remaining: U32
  for nonempty: {U32.is_zero(len) == False{} : Bool}
  for nonzero: {U32.is_zero(remaining) == False{} : Bool}
  {Stream.read.action(len, remaining) == Stream.Forward{} : Stream.ReadAction}
