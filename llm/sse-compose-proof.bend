import Base
import ./LAWS.bend as Laws
import ./sse.bend as Sse
import ./sse-next-proof.bend as Next
import ./sse-budget-proof.bend as Budget
import ./sse-drain-proof.bend as Drain
import ./sse-offset-proof.bend as Offset
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../lemmas/array.bend as Tree
import ./sse-boundary-proof.bend as Boundary
import ./sse-reader-proof.bend as Reader
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./sse-feed-proof.bend as Feed
import ./sse-packed-proof.bend as Packed
import ../bytes/append-proof.bend as Model
import ./sse-buffer-proof.bend as Buffer
import ./sse-refinement-proof.bend as Refinement
import ./sse-scan-proof.bend as Scan
import ./sse-field-proof.bend as Field
import ../bits/array-proof.bend as Bound
import ../bytes/bytes.bend as Local

def reader_length(rd: Sse.Reader) -> U32:
  Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st} = rd
  len

def result_length(result: Sse.Reader & Sse.Next) -> U32:
  (rd, next) = result
  reader_length(rd)

def stop_length(line: Sse.Line, +len: U32) -> {result_length(Sse.stop(line, len)) == len : U32}:
  match line:
    case Sse.LMore{a, pos, cr, st}: {==}
    case Sse.LWant{a, pos, cr, st}: {==}
    case Sse.LGot{a, pos, cr, st, message}: {==}

def loop_length(fuel: Nat, line: Sse.Line, +len: U32) -> {result_length(Sse.loop(fuel, line, len)) == len : U32}:
  match fuel:
    case 0n: stop_length(line, len)
    case 1n+p:
      match line:
        case Sse.LMore{a, +pos, cr, st}: loop_length(p, Sse.line(a, len, pos, pos, cr, st), len)
        case Sse.LWant{a, pos, cr, st}: {==}
        case Sse.LGot{a, pos, cr, st, message}: {==}

def next_at_length(+len: U32, +seen: U32, st: Sse.St, skipped: Array<U32> & U32 & Bool) ->
  {result_length(Sse.next.at(len, seen, st, skipped)) == len : U32}:
  (a, +pos, cr) = skipped
  loop_length(Nat.add(U32.to_nat((len - pos : U32)), 2n), Sse.line(a, len, pos, seen, cr, st), len)

def next_length(rd: Sse.Reader) -> {result_length(Sse.next(rd)) == reader_length(rd) : U32}:
  Sse.Reader{Bytes.Bytes{+len, a}, +pos, +seen, cr, st} = rd
  next_at_length(len, seen, st, Sse.skip(cr, a, len, pos))

def reader_line(rd: Sse.Reader) -> Sse.Line:
  Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st} = rd
  Sse.LMore{a, pos, cr, st}

def reader_valid(rd: Sse.Reader, +limit: Nat) -> Type:
  Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st} = rd
  Drain.buffer_valid(len, a, pos, seen, limit) & Drain.state_valid(st, limit)

def stripped(view: Budget.view_type()) -> Budget.view_type():
  (tag, tail, cr, state, message) = view
  (0, tail, cr, state, None{})

def reader_view(rd: Sse.Reader) -> Budget.view_type():
  Sse.Reader{Bytes.Bytes{+len, a}, +pos, seen, cr, st} = rd
  Drain.line_view(len, Sse.LMore{a, pos, cr, st})

def result_reader(result: Sse.Reader & Sse.Next) -> Sse.Reader:
  (rd, next) = result
  rd

def result_valid(n: Sse.Next, +len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  canonical: Budget.canonical_seen((Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, n)),
  valid: Drain.line_valid(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, n)), limit)) ->
  reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit):
  match n:
    case Sse.Want{}:
      %Equal.sym(U32, seen, len, canonical) : reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, _, cr, st}, limit)
      valid
    case Sse.Got{message}:
      (buffer, state, event) = valid
      %Equal.sym(U32, seen, pos, canonical) : reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, _, cr, st}, limit)
      (buffer, state)

def reader_relation(+len: U32, +other: U32, -left: Sse.Reader, -right: Sse.Reader, +limit: Nat) -> Type:
  {reader_length(left) == len : U32} & {reader_length(right) == other : U32} &
    {reader_view(left) == reader_view(right) : Budget.view_type()} &
    reader_valid(left, limit) & reader_valid(right, limit) &
    Budget.line_reserved(len, reader_line(left), limit)

def drain_relation(+len: U32, +other: U32, left: Sse.Reader & List<&1, Sse.Message>, right: Sse.Reader & List<&1, Sse.Message>, +limit: Nat) -> Type:
  (rd, acc) = left
  (other_rd, other_acc) = right
  reader_relation(len, other, rd, other_rd, limit) & {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}

def result_facts(n: Sse.Next, +len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  canonical: Budget.canonical_seen((Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, n)),
  valid: Drain.line_valid(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, n)), limit)) ->
  reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit) &
    {stripped(Drain.line_view(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, n)))) ==
      reader_view(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}) : Budget.view_type()} &
    {Budget.line_mass(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, n))) ==
      Budget.line_mass(len, Sse.LMore{a, pos, cr, st}) : Nat}:
  match n:
    case Sse.Want{}:
      (result_valid(Sse.Want{}, len, a, pos, seen, cr, st, limit, canonical, valid), {==}, {==})
    case Sse.Got{message}:
      (result_valid(Sse.Got{message}, len, a, pos, seen, cr, st, limit, canonical, valid), {==}, {==})

def result_readers_facts(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St,
  -n: Sse.Next, -m: Sse.Next, +limit: Nat,
  views: {Drain.line_view(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n))) ==
    Drain.line_view(other, Budget.result_line((Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, m))) : Budget.view_type()},
  reserve: Budget.line_reserved(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n)), limit),
  left: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, limit) &
    {stripped(Drain.line_view(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n)))) ==
      reader_view(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}) : Budget.view_type()} &
    {Budget.line_mass(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n))) == Budget.line_mass(len, Sse.LMore{a, s, cr, st}) : Nat},
  right: reader_valid(Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit) &
    {stripped(Drain.line_view(other, Budget.result_line((Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, m)))) ==
      reader_view(Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}) : Budget.view_type()} &
    {Budget.line_mass(other, Budget.result_line((Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, m))) == Budget.line_mass(other, Sse.LMore{b, t, other_cr, next}) : Nat}) ->
  reader_relation(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit):
  (left_valid, left_view, mass) = left
  (right_valid, right_view, other_mass) = right
  ({==}, {==},
    Equal.trans(Budget.view_type(), reader_view(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}),
      stripped(Drain.line_view(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n)))),
      reader_view(Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}),
      Equal.sym(Budget.view_type(), stripped(Drain.line_view(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n)))),
        reader_view(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}), left_view),
      Equal.trans(Budget.view_type(),
        stripped(Drain.line_view(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n)))),
        stripped(Drain.line_view(other, Budget.result_line((Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, m)))),
        reader_view(Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}),
        Equal.cong(Budget.view_type(), Budget.view_type(), stripped,
          Drain.line_view(len, Budget.result_line((Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n))),
          Drain.line_view(other, Budget.result_line((Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, m))), views), right_view)),
    left_valid, right_valid,
    (%mass : MNat.lt(Nat.add(Nat.add(_, 1n), 3n), limit); reserve))

def result_readers(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St,
  n: Sse.Next, m: Sse.Next, +limit: Nat,
  certificate: Budget.next_certificate(len, other, (Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, n),
    (Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, m), limit)) ->
  reader_relation(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit):
  (((views, left_valid, right_valid), reserve), left_seen, right_seen) = certificate
  result_readers_facts(len, other, a, b, s, t, seen, other_seen, cr, other_cr, st, next, n, m, limit,
    views, reserve, result_facts(n, len, a, s, seen, cr, st, limit, left_seen, left_valid),
    result_facts(m, other, b, t, other_seen, other_cr, next, limit, right_seen, right_valid))

def next_reader_relation(+len: U32, +other: U32, left: Sse.Reader & Sse.Next, right: Sse.Reader & Sse.Next, +limit: Nat,
  +left_length: {result_length(left) == len : U32}, +right_length: {result_length(right) == other : U32},
  certificate: Budget.next_certificate(len, other, left, right, limit)) ->
  reader_relation(len, other, result_reader(left), result_reader(right), limit):
  (Sse.Reader{Bytes.Bytes{+la, a}, +s, +seen, +cr, st}, n) = left
  (Sse.Reader{Bytes.Bytes{+lb, b}, +t, +other_seen, +other_cr, next}, m) = right
  %left_length : reader_relation(_, other, Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, limit)
  %right_length : reader_relation(la, _, Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, limit)
  result_readers(la, lb, a, b, s, t, seen, other_seen, cr, other_cr, st, next, n, m, limit,
    (%Equal.sym(U32, la, len, left_length) : Budget.next_certificate(_, lb,
      (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, n),
      (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, m), limit)
     %Equal.sym(U32, lb, other, right_length) : Budget.next_certificate(len, _,
      (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, n),
      (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, m), limit)
     certificate))

def next_length_keep(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  {result_length(Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st})) == len : U32} &
    reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit):
  ((+src, prefix, tail, +ea, buffer), (+name, +old, +id, +retry, (+data_len, +data, +eq, shape, length, bound, reads))) = valid
  ((%Equal.sym(Array<U32>, a, Tree.reify(U32, src), ea) :
      {result_length(Sse.next(Sse.Reader{Bytes.Bytes{len, _}, pos, seen, cr, st})) == len : U32}
    %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
      {result_length(Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, _})) == len : U32}
    next_length(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr,
      Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}})),
    ((src, prefix, tail, ea, buffer), (name, old, id, retry, (data_len, data, eq, shape, length, bound, reads))))

def got_next_lengths(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  views: {Drain.line_view(len, Sse.LMore{a, s, cr, st}) == Drain.line_view(other, Sse.LMore{b, t, other_cr, next}) : Budget.view_type()},
  reserve: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  left: {result_length(Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st})) == len : U32} &
    reader_valid(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}, limit),
  right: {result_length(Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next})) == other : U32} &
    reader_valid(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}, limit)) ->
  {result_length(Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st})) == len : U32} &
    {result_length(Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next})) == other : U32} &
    Budget.next_certificate(len, other,
      Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}),
      Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}), limit):
  (left_length, left_valid) = left
  (right_length, right_valid) = right
  (left_length, right_length, Next.next_ready(len, other, a, b, s, t, cr, other_cr, st, next, delta, limit,
    hu, ends, reserve, (views, left_valid, right_valid)))

def after_next(+len: U32, +other: U32, -left: Sse.Reader, -right: Sse.Reader, +limit: Nat) -> Type:
  {result_length(Sse.next(left)) == len : U32} & {result_length(Sse.next(right)) == other : U32} &
    Budget.next_certificate(len, other, Sse.next(left), Sse.next(right), limit)

def got_next_restarted(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St,
  -event: Sse.Message, -other_event: Sse.Message, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  certificate: Budget.next_certificate(len, other,
    (Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}, Sse.Got{event}),
    (Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}, Sse.Got{other_event}), limit)) ->
  after_next(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}, limit):
  (((views, (left_buffer, left_state, left_message), (right_buffer, right_state, right_message)), reserve), left_seen, right_seen) = certificate
  got_next_lengths(len, other, a, b, s, t, cr, other_cr, st, next, delta, limit, hu, ends,
    Equal.cong(Budget.view_type(), Budget.view_type(), stripped,
      Drain.line_view(len, Sse.LGot{a, s, cr, st, event}), Drain.line_view(other, Sse.LGot{b, t, other_cr, next, other_event}), views),
    reserve,
    next_length_keep(len, a, s, s, cr, st, limit, (left_buffer, left_state)),
    next_length_keep(other, b, t, t, other_cr, next, limit, (right_buffer, right_state)))

# Transport readers before next: https://github.com/bendlang/bend/issues/1071.
def after_next_transport(+len: U32, +other: U32, -left: Sse.Reader, -right: Sse.Reader,
  -normalized_left: Sse.Reader, -normalized_right: Sse.Reader, +limit: Nat,
  ea: {left == normalized_left : Sse.Reader}, eb: {right == normalized_right : Sse.Reader},
  certificate: after_next(len, other, normalized_left, normalized_right, limit)) ->
  after_next(len, other, left, right, limit):
  %Equal.sym(Sse.Reader, left, normalized_left, ea) : after_next(len, other, _, right, limit)
  %Equal.sym(Sse.Reader, right, normalized_right, eb) : after_next(len, other, normalized_left, _, limit)
  certificate

def got_next(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St,
  -event: Sse.Message, -other_event: Sse.Message, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  certificate: Budget.next_certificate(len, other,
    (Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, Sse.Got{event}),
    (Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, Sse.Got{other_event}), limit)) ->
  after_next(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit):
  (((views, left_valid, right_valid), reserve), left_seen, right_seen) = certificate
  after_next_transport(len, other,
    Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next},
    Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}, Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}, limit,
    Equal.cong(U32, Sse.Reader, x => Sse.Reader{Bytes.Bytes{len, a}, s, x, cr, st}, seen, s, left_seen),
    Equal.cong(U32, Sse.Reader, x => Sse.Reader{Bytes.Bytes{other, b}, t, x, other_cr, next}, other_seen, t, right_seen),
    got_next_restarted(len, other, a, b, s, t, cr, other_cr, st, next, event, other_event, delta, limit,
      hu, ends, (((views, left_valid, right_valid), reserve), {==}, {==})))

def certificate_retarget(+len: U32, +other: U32, +la: U32, +lb: U32,
  -left: Sse.Reader & Sse.Next, -right: Sse.Reader & Sse.Next, +limit: Nat,
  ea: {la == len : U32}, eb: {lb == other : U32},
  certificate: Budget.next_certificate(len, other, left, right, limit)) ->
  Budget.next_certificate(la, lb, left, right, limit):
  %Equal.sym(U32, la, len, ea) : Budget.next_certificate(_, lb, left, right, limit)
  %Equal.sym(U32, lb, other, eb) : Budget.next_certificate(len, _, left, right, limit)
  certificate

def after_next_retarget(+len: U32, +other: U32, +la: U32, +lb: U32,
  -left: Sse.Reader, -right: Sse.Reader, +limit: Nat,
  ea: {la == len : U32}, eb: {lb == other : U32},
  certificate: after_next(la, lb, left, right, limit)) -> after_next(len, other, left, right, limit):
  %ea : after_next(_, other, left, right, limit)
  %eb : after_next(la, _, left, right, limit)
  certificate

def got_next_fixed(+len: U32, +other: U32, +la: U32, +lb: U32,
  -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St,
  -event: Sse.Message, -other_event: Sse.Message, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  +ea: {la == len : U32}, +eb: {lb == other : U32},
  certificate: Budget.next_certificate(len, other,
    (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Got{event}),
    (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Got{other_event}), limit)) ->
  after_next(len, other, Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, limit):
  after_next_retarget(len, other, la, lb,
    Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, limit, ea, eb,
    got_next(la, lb, a, b, s, t, seen, other_seen, cr, other_cr, st, next, event, other_event, delta, limit,
      hu, (%Equal.sym(U32, la, len, ea) : Offset.offset(delta, _, lb);
        %Equal.sym(U32, lb, other, eb) : Offset.offset(delta, len, _); ends),
      certificate_retarget(len, other, la, lb,
        (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Got{event}),
        (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Got{other_event}), limit, ea, eb, certificate)))

def render_maybe(message: Maybe<&1, String & String & String>) -> String:
  match message:
    case None{}: ""
    case Some{(name, data, id)}: name ++ "|" ++ data ++ "|" ++ id

def render_view(view: Budget.view_type()) -> String:
  (tag, tail, cr, state, message) = view
  render_maybe(message)

def prepend_equal(+name: String, -data: Bytes.Bytes, +id: String,
  +other_name: String, -other_data: Bytes.Bytes, +other_id: String,
  -acc: List<&1, Sse.Message>, -other_acc: List<&1, Sse.Message>,
  event: {name ++ "|" ++ Bytes.to_string(data) ++ "|" ++ id ==
    other_name ++ "|" ++ Bytes.to_string(other_data) ++ "|" ++ other_id : String},
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  {Laws.show(Con{Sse.Message{name, data, id}, acc}) ==
    Laws.show(Con{Sse.Message{other_name, other_data, other_id}, other_acc}) : List<&2, String>}:
  Equal.trans(List<&2, String>,
    Con{name ++ "|" ++ Bytes.to_string(data) ++ "|" ++ id, Laws.show(acc)},
    Con{other_name ++ "|" ++ Bytes.to_string(other_data) ++ "|" ++ other_id, Laws.show(acc)},
    Con{other_name ++ "|" ++ Bytes.to_string(other_data) ++ "|" ++ other_id, Laws.show(other_acc)},
    Equal.cong(String, List<&2, String>, x => Con{x, Laws.show(acc)},
      name ++ "|" ++ Bytes.to_string(data) ++ "|" ++ id,
      other_name ++ "|" ++ Bytes.to_string(other_data) ++ "|" ++ other_id, event),
    Equal.cong(List<&2, String>, List<&2, String>,
      xs => Con{other_name ++ "|" ++ Bytes.to_string(other_data) ++ "|" ++ other_id, xs},
      Laws.show(acc), Laws.show(other_acc), same))

def drain_goal(+fuel: Nat, +len: U32, +other: U32, -left: Sse.Reader & Sse.Next, -right: Sse.Reader & Sse.Next, +limit: Nat) -> Type:
  @acc: List<&1, Sse.Message> -> @other_acc: List<&1, Sse.Message> ->
    {result_length(left) == len : U32} -> {result_length(right) == other : U32} ->
    Budget.next_certificate(len, other, left, right, limit) ->
    {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>} ->
    drain_relation(len, other, Laws.drain(fuel, left, acc), Laws.drain(fuel, right, other_acc), limit)

def drain_continue(+fuel: Nat, +len: U32, +other: U32, -left: Sse.Reader, -right: Sse.Reader, +limit: Nat,
  continue: drain_goal(fuel, len, other, Sse.next(left), Sse.next(right), limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  facts: after_next(len, other, left, right, limit),
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(len, other, Laws.drain(fuel, Sse.next(left), acc), Laws.drain(fuel, Sse.next(right), other_acc), limit):
  (left_length, right_length, certificate) = facts
  continue(acc, other_acc, left_length, right_length, certificate, same)

def drain_got_step(-P: Type, +len: U32, +other: U32, +la: U32, +lb: U32,
  -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32, +seen: U32, +other_seen: U32,
  +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St,
  +name: String, -data: Bytes.Bytes, +id: String, +other_name: String, -other_data: Bytes.Bytes, +other_id: String,
  -acc: List<&1, Sse.Message>, -other_acc: List<&1, Sse.Message>, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  ea: {la == len : U32}, eb: {lb == other : U32},
  continue: after_next(len, other, Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st},
      Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, limit) ->
    {Laws.show(Con{Sse.Message{name, data, id}, acc}) ==
      Laws.show(Con{Sse.Message{other_name, other_data, other_id}, other_acc}) : List<&2, String>} -> P,
  certificate: Budget.next_certificate(len, other,
    (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Got{Sse.Message{name, data, id}}),
    (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Got{Sse.Message{other_name, other_data, other_id}}), limit),
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) -> P:
  (((+views, left_valid, right_valid), reserve), left_seen, right_seen) = certificate
  continue(
    got_next_fixed(len, other, la, lb, a, b, s, t, seen, other_seen, cr, other_cr, st, next,
      Sse.Message{name, data, id}, Sse.Message{other_name, other_data, other_id}, delta, limit, hu, ends, ea, eb,
      (((views, left_valid, right_valid), reserve), left_seen, right_seen)),
    prepend_equal(name, data, id, other_name, other_data, other_id, acc, other_acc,
      Equal.cong(Budget.view_type(), String, render_view,
        Drain.line_view(len, Sse.LGot{a, s, cr, st, Sse.Message{name, data, id}}),
        Drain.line_view(other, Sse.LGot{b, t, other_cr, next, Sse.Message{other_name, other_data, other_id}}), views), same))

def drain_mismatch(-P: Type, +len: U32, +other: U32, -left: Sse.Reader & Sse.Next, -right: Sse.Reader & Sse.Next,
  +limit: Nat, +i: U32, +j: U32,
  left_tag: {Budget.view_tag(Drain.line_view(len, Budget.result_line(left))) == i : U32},
  right_tag: {Budget.view_tag(Drain.line_view(other, Budget.result_line(right))) == j : U32},
  different: {Nat.is_eq(U32.to_nat(i), U32.to_nat(j)) == False{} : Bool},
  certificate: Budget.next_certificate(len, other, left, right, limit)) -> P:
  (((views, left_valid, right_valid), reserve), left_seen, right_seen) = certificate
  Empty.absurd(P, Budget.unequal_tags(i, j, different,
    Equal.trans(U32, i, Budget.view_tag(Drain.line_view(len, Budget.result_line(left))), j,
      Equal.sym(U32, Budget.view_tag(Drain.line_view(len, Budget.result_line(left))), i, left_tag),
      Equal.trans(U32, Budget.view_tag(Drain.line_view(len, Budget.result_line(left))),
        Budget.view_tag(Drain.line_view(other, Budget.result_line(right))), j,
        Equal.cong(Budget.view_type(), U32, Budget.view_tag,
          Drain.line_view(len, Budget.result_line(left)), Drain.line_view(other, Budget.result_line(right)), views), right_tag))))

def drain_zero(+len: U32, +other: U32, left: Sse.Reader & Sse.Next, right: Sse.Reader & Sse.Next, +limit: Nat) ->
  drain_goal(0n, len, other, left, right, limit):
  (rd, n) = left
  (other_rd, m) = right
  acc => other_acc => left_length => right_length => certificate => same =>
    (next_reader_relation(len, other, (rd, n), (other_rd, m), limit, left_length, right_length, certificate), same)

def drain_pair_succ(+fuel: Nat, +len: U32, +other: U32, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other),
  ih: @left: Sse.Reader & Sse.Next -> @right: Sse.Reader & Sse.Next -> drain_goal(fuel, len, other, left, right, limit),
  left: Sse.Reader & Sse.Next, right: Sse.Reader & Sse.Next) -> drain_goal(1n+fuel, len, other, left, right, limit):
  match left right:
    case Tuple{Sse.Reader{Bytes.Bytes{+la, a}, +s, +seen, +cr, st}, Sse.Want{}} Tuple{Sse.Reader{Bytes.Bytes{+lb, b}, +t, +other_seen, +other_cr, next}, Sse.Want{}}:
      acc => other_acc => ea => eb => certificate => same =>
        (next_reader_relation(len, other,
          (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Want{}),
          (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Want{}), limit, ea, eb, certificate), same)
    case Tuple{Sse.Reader{Bytes.Bytes{+la, a}, +s, +seen, +cr, st}, Sse.Want{}} Tuple{Sse.Reader{Bytes.Bytes{+lb, b}, +t, +other_seen, +other_cr, next}, Sse.Got{message}}:
      acc => other_acc => ea => eb => certificate => same =>
        drain_mismatch(drain_relation(len, other,
          Laws.drain(1n+fuel, (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Want{}), acc),
          Laws.drain(1n+fuel, (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Got{message}), other_acc), limit),
          len, other, (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Want{}),
          (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Got{message}), limit, 1, 2, {==}, {==}, {==}, certificate)
    case Tuple{Sse.Reader{Bytes.Bytes{+la, a}, +s, +seen, +cr, st}, Sse.Got{message}} Tuple{Sse.Reader{Bytes.Bytes{+lb, b}, +t, +other_seen, +other_cr, next}, Sse.Want{}}:
      acc => other_acc => ea => eb => certificate => same =>
        drain_mismatch(drain_relation(len, other,
          Laws.drain(1n+fuel, (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Got{message}), acc),
          Laws.drain(1n+fuel, (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Want{}), other_acc), limit),
          len, other, (Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Got{message}),
          (Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, Sse.Want{}), limit, 2, 1, {==}, {==}, {==}, certificate)
    case Tuple{Sse.Reader{Bytes.Bytes{+la, a}, +s, +seen, +cr, st}, Sse.Got{Sse.Message{+name, data, +id}}} Tuple{Sse.Reader{Bytes.Bytes{+lb, b}, +t, +other_seen, +other_cr, next}, Sse.Got{Sse.Message{+other_name, other_data, +other_id}}}:
      acc => other_acc => ea => eb => certificate => same =>
        drain_got_step(drain_relation(len, other,
          Laws.drain(fuel, Sse.next(Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}), Con{Sse.Message{name, data, id}, acc}),
          Laws.drain(fuel, Sse.next(Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}), Con{Sse.Message{other_name, other_data, other_id}, other_acc}), limit),
          len, other, la, lb, a, b, s, t, seen, other_seen, cr, other_cr, st, next,
          name, data, id, other_name, other_data, other_id, acc, other_acc, delta, limit, hu, ends, ea, eb,
          facts => messages => drain_continue(fuel, len, other,
            Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, limit,
            ih(Sse.next(Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}), Sse.next(Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next})),
            Con{Sse.Message{name, data, id}, acc}, Con{Sse.Message{other_name, other_data, other_id}, other_acc}, facts, messages),
          certificate, same)

def drain_refines(fuel: Nat, +len: U32, +other: U32, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other)) ->
  @left: Sse.Reader & Sse.Next -> @right: Sse.Reader & Sse.Next -> drain_goal(fuel, len, other, left, right, limit):
  match fuel:
    case 0n: left => right => drain_zero(len, other, left, right, limit)
    case 1n+ +p:
      left => right => drain_pair_succ(p, len, other, delta, limit, hu, ends,
        drain_refines(p, len, other, delta, limit, hu, ends), left, right)

def started_next(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  reserve: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  relation: Drain.line_relation(len, other, Sse.LMore{a, s, cr, st}, Sse.LMore{b, t, other_cr, next}, limit)) ->
  after_next(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}, limit):
  (views, left_valid, right_valid) = relation
  got_next_lengths(len, other, a, b, s, t, cr, other_cr, st, next, delta, limit, hu, ends, views, reserve,
    next_length_keep(len, a, s, s, cr, st, limit, left_valid),
    next_length_keep(other, b, t, t, other_cr, next, limit, right_valid))

def drain_started_refines(+fuel: Nat, +len: U32, +other: U32, a: Array<U32>, b: Array<U32>, +s: U32, +t: U32,
  +cr: Bool, +other_cr: Bool, st: Sse.St, next: Sse.St, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other),
  reserve: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  relation: Drain.line_relation(len, other, Sse.LMore{a, s, cr, st}, Sse.LMore{b, t, other_cr, next}, limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(len, other,
    Laws.drain(fuel, Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}), acc),
    Laws.drain(fuel, Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}), other_acc), limit):
  drain_continue(fuel, len, other,
    Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}, Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}, limit,
    drain_refines(fuel, len, other, delta, limit, hu, ends)(
      Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}),
      Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next})),
    acc, other_acc,
    started_next(len, other, a, b, s, t, cr, other_cr, st, next, delta, limit, hu, ends, reserve, relation), same)

def normalize_tree_copies(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  +cr: Bool, -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  copies: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit) &
    Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, cr, st}) : Sse.Reader & Sse.Next} &
    Reader.valid_buffer("", Drain.restarted_tail(len, src, pos), len, src, pos, pos, limit):
  (for_restart, (shape, hl, lower, upper, width, length, reads, clean)) = copies
  (Next.next_restart(cr, prefix, tail, len, src, pos, seen, st, limit, hu, for_restart),
    Drain.restarted_buffer(len, src, pos, limit, shape, hl,
      MNat.le_trans(U32.to_nat(pos), U32.to_nat(seen), U32.to_nat(len), lower, upper)))

def normalize_tree(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  +cr: Bool, -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  valid: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, cr, st}) : Sse.Reader & Sse.Next} &
    Reader.valid_buffer("", Drain.restarted_tail(len, src, pos), len, src, pos, pos, limit):
  normalize_tree_copies(prefix, tail, len, src, pos, seen, cr, st, limit, hu,
    Boundary.duplicate_valid(prefix, tail, len, src, pos, seen, limit, valid))

def normalize_reader_parts(+len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  +cr: Bool, -st: Sse.St, +limit: Nat, -a: Array<U32>, +ea: {a == Tree.reify(U32, src) : Array<U32>},
  state: Drain.state_valid(st, limit),
  normalized: {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, cr, st}) : Sse.Reader & Sse.Next} &
    Reader.valid_buffer("", Drain.restarted_tail(len, src, pos), len, src, pos, pos, limit)) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, pos, cr, st}) : Sse.Reader & Sse.Next} &
    Drain.line_valid(len, Sse.LMore{a, pos, cr, st}, limit):
  (eq, buffer) = normalized
  ((%Equal.sym(Array<U32>, a, Tree.reify(U32, src), ea) :
    {Sse.next(Sse.Reader{Bytes.Bytes{len, _}, pos, seen, cr, st}) ==
      Sse.next(Sse.Reader{Bytes.Bytes{len, _}, pos, pos, cr, st}) : Sse.Reader & Sse.Next}; eq),
    ((src, "", Drain.restarted_tail(len, src, pos), ea, buffer), state))

def normalize_reader(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32,
  +cr: Bool, -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, pos, cr, st}) : Sse.Reader & Sse.Next} &
    Drain.line_valid(len, Sse.LMore{a, pos, cr, st}, limit):
  ((+src, +prefix, +tail, ea, buffer), state) = valid
  normalize_reader_parts(len, src, pos, seen, cr, st, limit, a, ea, state,
    normalize_tree(prefix, tail, len, src, pos, seen, cr, st, limit, hu, buffer))

def after_next_results(+len: U32, +other: U32, -left: Sse.Reader, -right: Sse.Reader,
  -normalized_left: Sse.Reader, -normalized_right: Sse.Reader, +limit: Nat,
  +ea: {Sse.next(left) == Sse.next(normalized_left) : Sse.Reader & Sse.Next},
  +eb: {Sse.next(right) == Sse.next(normalized_right) : Sse.Reader & Sse.Next},
  certificate: after_next(len, other, normalized_left, normalized_right, limit)) ->
  after_next(len, other, left, right, limit):
  (left_length, right_length, paired) = certificate
  (Equal.trans(U32, result_length(Sse.next(left)), result_length(Sse.next(normalized_left)), len,
      Equal.cong(Sse.Reader & Sse.Next, U32, result_length, Sse.next(left), Sse.next(normalized_left), ea), left_length),
    Equal.trans(U32, result_length(Sse.next(right)), result_length(Sse.next(normalized_right)), other,
      Equal.cong(Sse.Reader & Sse.Next, U32, result_length, Sse.next(right), Sse.next(normalized_right), eb), right_length),
    Budget.next_transport(len, other, Sse.next(left), Sse.next(right), Sse.next(normalized_left), Sse.next(normalized_right), limit, ea, eb, paired))

def started_seen_parts(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  views: {Drain.line_view(len, Sse.LMore{a, s, cr, st}) == Drain.line_view(other, Sse.LMore{b, t, other_cr, next}) : Budget.view_type()},
  reserve: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  left: {Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}) : Sse.Reader & Sse.Next} & Drain.line_valid(len, Sse.LMore{a, s, cr, st}, limit),
  right: {Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}) : Sse.Reader & Sse.Next} & Drain.line_valid(other, Sse.LMore{b, t, other_cr, next}, limit)) ->
  after_next(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit):
  (ea, left_valid) = left
  (eb, right_valid) = right
  after_next_results(len, other,
    Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next},
    Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}, Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}, limit, ea, eb,
    started_next(len, other, a, b, s, t, cr, other_cr, st, next, delta, limit, hu, ends, reserve, (views, left_valid, right_valid)))

def started_seen(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  relation: reader_relation(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit)) ->
  after_next(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit):
  (left_length, right_length, views, left_valid, right_valid, reserve) = relation
  started_seen_parts(len, other, a, b, s, t, seen, other_seen, cr, other_cr, st, next, delta, limit, hu, ends,
    views, reserve, normalize_reader(len, a, s, seen, cr, st, limit, hu, left_valid),
    normalize_reader(other, b, t, other_seen, other_cr, next, limit, hu, right_valid))

def feed_drain_refines(+len: U32, a: Array<U32>, b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, st: Sse.St, next: Sse.St, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  relation: reader_relation(len, len, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{len, b}, t, other_seen, other_cr, next}, limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(len, len,
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, acc),
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, b}, t, other_seen, other_cr, next}, other_acc), limit):
  drain_continue(Nat.add(U32.to_nat(len), 1n), len, len,
    Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{len, b}, t, other_seen, other_cr, next}, limit,
    drain_refines(Nat.add(U32.to_nat(len), 1n), len, len, 0n, limit, hu, {==})(
      Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}),
      Sse.next(Sse.Reader{Bytes.Bytes{len, b}, t, other_seen, other_cr, next})),
    acc, other_acc,
    started_seen(len, len, a, b, s, t, seen, other_seen, cr, other_cr, st, next, 0n, limit, hu, {==}, relation), same)

def zero_width(+len: U32) -> {U32.to_nat((len - 0 : U32)) == U32.to_nat(len) : Nat}:
  Equal.trans(Nat, U32.to_nat((len - 0 : U32)), Nat.sub(U32.to_nat(len), 0n), U32.to_nat(len),
    Lemmas.u32_sub_nat(len, 0, MNat.zero_le(U32.to_nat(len))), MNat.sub_zero(U32.to_nat(len)))

def zero_reader_view(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>,
  +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  valid: Reader.valid_buffer(prefix, tail, len, src, 0, seen, limit)) ->
  {reader_view(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}) ==
    (0, prefix ++ tail, cr, Drain.state_view(st), None{}) : Budget.view_type()}:
  (shape, hl, hp, hs, ep, +length, reads, clean) = valid
  Equal.cong(String, Budget.view_type(), text => (0, text, cr, Drain.state_view(st), None{}),
    Buffer.observed(U32.to_nat((len - 0 : U32)), Bytes.peek(Tree.reify(U32, src), 0), 0), prefix ++ tail,
    (%Equal.sym(Nat, U32.to_nat((len - 0 : U32)), U32.to_nat(len), zero_width(len)) :
      {Buffer.observed(_, Bytes.peek(Tree.reify(U32, src), 0), 0) == prefix ++ tail : String}
     %Equal.sym(Nat, U32.to_nat(len), String.length(prefix ++ tail), length) :
      {Buffer.observed(_, Bytes.peek(Tree.reify(U32, src), 0), 0) == prefix ++ tail : String}
     Packed.reads_observed(prefix ++ tail, src, 0, reads)))

def zero_reader_certificate(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>,
  +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(prefix ++ tail)), 1n), 3n), limit),
  state: Drain.state_valid(st, limit),
  buffers: Reader.valid_buffer(prefix, tail, len, src, 0, seen, limit) &
    Reader.valid_buffer(prefix, tail, len, src, 0, seen, limit)) ->
  {reader_view(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}) ==
    (0, prefix ++ tail, cr, Drain.state_view(st), None{}) : Budget.view_type()} &
    reader_valid(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}, limit) &
    Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, src), 0, cr, st}, limit):
  (observe, (shape, +hl, +hp, +hs, +ep, +length, reads, clean)) = buffers
  (zero_reader_view(prefix, tail, len, src, seen, cr, st, limit, observe),
    ((src, prefix, tail, {==}, shape, hl, hp, hs, ep, length, reads, clean), state),
    (%Equal.sym(Nat, U32.to_nat((len - 0 : U32)), U32.to_nat(len), zero_width(len)) :
      MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), _), 1n), 3n), limit)
     %Equal.sym(Nat, U32.to_nat(len), String.length(prefix ++ tail), length) :
      MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), _), 1n), 3n), limit)
     reserve))

def feed_room(+size: Nat, +width: Nat, +limit: Nat,
  reserve: MNat.lt(Nat.add(Nat.add(Nat.add(size, width), 1n), 3n), limit)) ->
  MNat.lt(Nat.add(width, 3n), limit):
  MNat.lt_of_le_of_lt(Nat.add(width, 3n), Nat.add(Nat.add(Nat.add(size, width), 1n), 3n), limit,
    MNat.add_le_add_right(width, Nat.add(Nat.add(size, width), 1n), 3n,
      MNat.le_trans(width, Nat.add(size, width), Nat.add(Nat.add(size, width), 1n),
        MNat.le_add_left(width, size), MNat.le_add_right(Nat.add(size, width), 1n))), reserve)

def feed_certificate(+len: U32, +text: String, +cr: Bool, -st: Sse.St, -rd: Sse.Reader, +limit: Nat) -> Type:
  {reader_length(rd) == len : U32} &
    {U32.to_nat(len) == String.length(text) : Nat} &
    {reader_view(rd) == (0, text, cr, Drain.state_view(st), None{}) : Budget.view_type()} &
    reader_valid(rd, limit) & Budget.line_reserved(len, reader_line(rd), limit)

def feed_certificate_transport(+len: U32, +text: String, +cr: Bool, -st: Sse.St,
  -actual: Sse.Reader, -normalized: Sse.Reader, +limit: Nat,
  eq: {actual == normalized : Sse.Reader},
  certificate: feed_certificate(len, text, cr, st, normalized, limit)) ->
  feed_certificate(len, text, cr, st, actual, limit):
  %Equal.sym(Sse.Reader, actual, normalized, eq) : feed_certificate(len, text, cr, st, _, limit)
  certificate

def feed_output_certificate(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>,
  +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(prefix ++ tail)), 1n), 3n), limit),
  state: Drain.state_valid(st, limit),
  buffers: Reader.valid_buffer(prefix, tail, len, src, 0, seen, limit) &
    Reader.valid_buffer(prefix, tail, len, src, 0, seen, limit)) ->
  feed_certificate(len, prefix ++ tail, cr, st, Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}, limit):
  (observe, (shape, +hl, +hp, +hs, +ep, +length, reads, clean)) = buffers
  ({==}, length, zero_reader_certificate(prefix, tail, len, src, seen, cr, st, limit, reserve, state,
    (observe, (shape, hl, hp, hs, ep, length, reads, clean))))

def feed_snapshot_certificate(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(prefix ++ (tail ++ chunk))), 1n), 3n), limit),
  state: Drain.state_valid(st, limit),
  snapshot: Reader.valid_feed_type(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit)) ->
  feed_certificate((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), prefix ++ (tail ++ chunk), cr, st,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit):
  (+out, (eq, valid)) = snapshot
  +n = (Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32)
  +output_seen = Feed.output_seen(U32.is_zero(pos), seen, pos)
  feed_certificate_transport(n, prefix ++ (tail ++ chunk), cr, st,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.Reader{Bytes.Bytes{n, Tree.reify(U32, out)}, 0, output_seen, cr, st}, limit, eq,
    feed_output_certificate(prefix, tail ++ chunk, n, out, output_seen, cr, st, limit, reserve, state,
      Boundary.duplicate_valid(prefix, tail ++ chunk, n, out, 0, output_seen, limit, valid)))

def feed_valid_certificate_parts(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(prefix ++ (tail ++ chunk))), 1n), 3n), limit),
  state: Drain.state_valid(st, limit), chunk_reads: Model.Reads(chunk, right, 0),
  buffers: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit) &
    Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  feed_certificate((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), prefix ++ (tail ++ chunk), cr, st,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit):
  ((shape, hl, hp, hs, ep, +length, reads, clean), keep) = buffers
  feed_snapshot_certificate(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, reserve, state,
    Reader.feed_valid(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, hu, eb,
      (%Equal.sym(Nat, U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), String.length(prefix ++ tail), length) :
        MNat.lt(Nat.add(Nat.add(_, U32.to_nat(lb)), 3n), limit)
       %Equal.sym(Nat, U32.to_nat(lb), String.length(chunk), eb) :
        MNat.lt(Nat.add(Nat.add(String.length(prefix ++ tail), _), 3n), limit)
       %Equal.sym(Nat, Nat.add(String.length(prefix ++ tail), String.length(chunk)), String.length((prefix ++ tail) ++ chunk),
         Equal.sym(Nat, String.length((prefix ++ tail) ++ chunk), Nat.add(String.length(prefix ++ tail), String.length(chunk)), Model.length_append(prefix ++ tail, chunk))) :
        MNat.lt(Nat.add(_, 3n), limit)
       %Equal.sym(String, (prefix ++ tail) ++ chunk, prefix ++ (tail ++ chunk), Model.append_assoc(prefix, tail, chunk)) :
        MNat.lt(Nat.add(String.length(_), 3n), limit)
       feed_room(Budget.state_size(st), String.length(prefix ++ (tail ++ chunk)), limit, reserve)),
      chunk_reads, keep))

def feed_valid_certificate(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(prefix ++ (tail ++ chunk))), 1n), 3n), limit),
  state: Drain.state_valid(st, limit), chunk_reads: Model.Reads(chunk, right, 0),
  buffer: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  feed_certificate((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), prefix ++ (tail ++ chunk), cr, st,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit):
  feed_valid_certificate_parts(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, hu, eb, reserve, state,
    chunk_reads, Boundary.duplicate_valid(prefix, tail, len, src, pos, seen, limit, buffer))

def feed_certificates_related(+len: U32, +other: U32, +text: String, +cr: Bool,
  -st: Sse.St, -next: Sse.St, -left: Sse.Reader, -right: Sse.Reader, +limit: Nat,
  states: {Drain.state_view(st) == Drain.state_view(next) : String & String & String & Maybe<&2, U32>},
  a: feed_certificate(len, text, cr, st, left, limit),
  b: feed_certificate(other, text, cr, next, right, limit)) ->
  reader_relation(len, len, left, right, limit):
  (left_length, +left_width, left_view, left_valid, reserve) = a
  (right_length, +right_width, right_view, right_valid, other_reserve) = b
  +ends = Lemmas.u32_to_nat_inj(other, len,
    Equal.trans(Nat, U32.to_nat(other), String.length(text), U32.to_nat(len),
      right_width, Equal.sym(Nat, U32.to_nat(len), String.length(text), left_width)))
  (left_length, Equal.trans(U32, reader_length(right), other, len, right_length, ends),
    Equal.trans(Budget.view_type(), reader_view(left), (0, text, cr, Drain.state_view(st), None{}), reader_view(right),
      left_view, Equal.trans(Budget.view_type(), (0, text, cr, Drain.state_view(st), None{}),
        (0, text, cr, Drain.state_view(next), None{}), reader_view(right),
        Equal.cong(String & String & String & Maybe<&2, U32>, Budget.view_type(),
          value => (0, text, cr, value, None{}), Drain.state_view(st), Drain.state_view(next), states),
        Equal.sym(Budget.view_type(), reader_view(right), (0, text, cr, Drain.state_view(next), None{}), right_view))),
    left_valid, right_valid, reserve)

def feed_drain_related(+len: U32, left: Sse.Reader, right: Sse.Reader, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), relation: reader_relation(len, len, left, right, limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(len, len, Laws.feed_drain(left, acc), Laws.feed_drain(right, other_acc), limit):
  Sse.Reader{Bytes.Bytes{+la, a}, +s, +seen, +cr, st} = left
  Sse.Reader{Bytes.Bytes{+lb, b}, +t, +other_seen, +other_cr, next} = right
  (+ea, +eb, views, left_valid, right_valid, reserve) = relation
  %Equal.sym(U32, la, len, ea) : drain_relation(len, len,
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{_, a}, s, seen, cr, st}, acc),
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{lb, b}, t, other_seen, other_cr, next}, other_acc), limit)
  %Equal.sym(U32, lb, len, eb) : drain_relation(len, len,
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, acc),
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{_, b}, t, other_seen, other_cr, next}, other_acc), limit)
  feed_drain_refines(len, a, b, s, t, seen, other_seen, cr, other_cr, st, next, limit, hu,
    (%ea : reader_relation(len, len,
      Sse.Reader{Bytes.Bytes{_, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{len, b}, t, other_seen, other_cr, next}, limit)
     %eb : reader_relation(len, len,
      Sse.Reader{Bytes.Bytes{la, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{_, b}, t, other_seen, other_cr, next}, limit)
     (ea, eb, views, left_valid, right_valid, reserve)), acc, other_acc, same)

def feed_valid_certificate_erased(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(prefix ++ (tail ++ chunk))), 1n), 3n), limit),
  state: Drain.state_valid(st, limit), chunk_reads: Model.Reads(chunk, right, 0),
  buffer: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  feed_certificate((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), prefix ++ (tail ++ chunk), cr, st,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit):
  (+name, +old, +id, +retry, (+data_len, +data, +eq, shape, length, bound, reads)) = state
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    feed_certificate((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), prefix ++ (tail ++ chunk), cr, _,
      Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, _}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit)
  feed_valid_certificate(prefix, tail, chunk, len, src, pos, seen, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, lb, right, limit, hu, eb,
    (%eq : MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(_), String.length(prefix ++ (tail ++ chunk))), 1n), 3n), limit); reserve),
    (name, old, id, retry, data_len, data, {==}, shape, length, bound, reads), chunk_reads, buffer)

def appended_text(+prefix: String, +tail: String, +text: String, +chunk: String,
  same: {prefix ++ tail == text : String}) ->
  {prefix ++ (tail ++ chunk) == text ++ chunk : String}:
  Equal.trans(String, prefix ++ (tail ++ chunk), (prefix ++ tail) ++ chunk, text ++ chunk,
    Equal.sym(String, (prefix ++ tail) ++ chunk, prefix ++ (tail ++ chunk), Model.append_assoc(prefix, tail, chunk)),
    Equal.cong(String, String, value => value ++ chunk, prefix ++ tail, text, same))

def feed_observed_certificate(+prefix: String, +tail: String, +text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +same: {prefix ++ tail == text : String},
  reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(text ++ chunk)), 1n), 3n), limit),
  state: Drain.state_valid(st, limit), chunk_reads: Model.Reads(chunk, right, 0),
  buffer: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  feed_certificate((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), text ++ chunk, cr, st,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit):
  +eq = appended_text(prefix, tail, text, chunk, same)
  %eq : feed_certificate((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), _, cr, st,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit)
  feed_valid_certificate_erased(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, hu, eb,
    (%Equal.sym(String, prefix ++ (tail ++ chunk), text ++ chunk, eq) :
      MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(_)), 1n), 3n), limit); reserve),
    state, chunk_reads, buffer)

def feed_pair_refines_reads(+prefix: String, +tail: String, +other_prefix: String, +other_tail: String, +text: String, +chunk: String,
  +len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +s: U32, +t: U32, +seen: U32, +other_seen: U32, +cr: Bool, -st: Sse.St, -next: Sse.St,
  +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  left_text: {prefix ++ tail == text : String}, right_text: {other_prefix ++ other_tail == text : String},
  states: {Drain.state_view(st) == Drain.state_view(next) : String & String & String & Maybe<&2, U32>},
  left_reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(text ++ chunk)), 1n), 3n), limit),
  right_reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(next), String.length(text ++ chunk)), 1n), 3n), limit),
  left_state: Drain.state_valid(st, limit), right_state: Drain.state_valid(next, limit),
  left_buffer: Reader.valid_buffer(prefix, tail, len, a, s, seen, limit),
  right_buffer: Reader.valid_buffer(other_prefix, other_tail, other, b, t, other_seen, limit),
  reads: Model.Reads(chunk, right, 0) & Model.Reads(chunk, right, 0)) ->
  reader_relation((Feed.input_length(U32.is_zero(s), len, s) + lb : U32), (Feed.input_length(U32.is_zero(s), len, s) + lb : U32),
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.feed(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, cr, next}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit):
  (ra, rb) = reads
  feed_certificates_related((Feed.input_length(U32.is_zero(s), len, s) + lb : U32),
    (Feed.input_length(U32.is_zero(t), other, t) + lb : U32), text ++ chunk, cr, st, next,
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.feed(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, cr, next}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit, states,
    feed_observed_certificate(prefix, tail, text, chunk, len, a, s, seen, cr, st, lb, right, limit, hu, eb, left_text,
      left_reserve, left_state, ra, left_buffer),
    feed_observed_certificate(other_prefix, other_tail, text, chunk, other, b, t, other_seen, cr, next, lb, right, limit, hu, eb, right_text,
      right_reserve, right_state, rb, right_buffer))

def feed_pair_refines(+prefix: String, +tail: String, +other_prefix: String, +other_tail: String, +text: String, +chunk: String,
  +len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +s: U32, +t: U32, +seen: U32, +other_seen: U32, +cr: Bool, -st: Sse.St, -next: Sse.St,
  +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  left_text: {prefix ++ tail == text : String}, right_text: {other_prefix ++ other_tail == text : String},
  states: {Drain.state_view(st) == Drain.state_view(next) : String & String & String & Maybe<&2, U32>},
  left_reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(text ++ chunk)), 1n), 3n), limit),
  right_reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(next), String.length(text ++ chunk)), 1n), 3n), limit),
  left_state: Drain.state_valid(st, limit), right_state: Drain.state_valid(next, limit),
  left_buffer: Reader.valid_buffer(prefix, tail, len, a, s, seen, limit),
  right_buffer: Reader.valid_buffer(other_prefix, other_tail, other, b, t, other_seen, limit),
  reads: Model.Reads(chunk, right, 0)) ->
  reader_relation((Feed.input_length(U32.is_zero(s), len, s) + lb : U32), (Feed.input_length(U32.is_zero(s), len, s) + lb : U32),
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.feed(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, cr, next}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit):
  feed_pair_refines_reads(prefix, tail, other_prefix, other_tail, text, chunk, len, other, a, b, s, t, seen, other_seen,
    cr, st, next, lb, right, limit, hu, eb, left_text, right_text, states, left_reserve, right_reserve,
    left_state, right_state, left_buffer, right_buffer, Offset.reads_duplicate(chunk, right, 0, reads))

def feed_pair_drain_refines(+prefix: String, +tail: String, +other_prefix: String, +other_tail: String, +text: String, +chunk: String,
  +len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +s: U32, +t: U32, +seen: U32, +other_seen: U32, +cr: Bool, st: Sse.St, next: Sse.St,
  +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  left_text: {prefix ++ tail == text : String}, right_text: {other_prefix ++ other_tail == text : String},
  states: {Drain.state_view(st) == Drain.state_view(next) : String & String & String & Maybe<&2, U32>},
  left_reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(st), String.length(text ++ chunk)), 1n), 3n), limit),
  right_reserve: MNat.lt(Nat.add(Nat.add(Nat.add(Budget.state_size(next), String.length(text ++ chunk)), 1n), 3n), limit),
  left_state: Drain.state_valid(st, limit), right_state: Drain.state_valid(next, limit),
  left_buffer: Reader.valid_buffer(prefix, tail, len, a, s, seen, limit),
  right_buffer: Reader.valid_buffer(other_prefix, other_tail, other, b, t, other_seen, limit),
  reads: Model.Reads(chunk, right, 0),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation((Feed.input_length(U32.is_zero(s), len, s) + lb : U32), (Feed.input_length(U32.is_zero(s), len, s) + lb : U32),
    Laws.feed_drain(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}), acc),
    Laws.feed_drain(Sse.feed(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, cr, next}, Bytes.Bytes{lb, Tree.reify(U32, right)}), other_acc), limit):
  feed_drain_related((Feed.input_length(U32.is_zero(s), len, s) + lb : U32),
    Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.feed(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, cr, next}, Bytes.Bytes{lb, Tree.reify(U32, right)}), limit, hu,
    feed_pair_refines(prefix, tail, other_prefix, other_tail, text, chunk, len, other, a, b, s, t, seen, other_seen, cr, st, next,
      lb, right, limit, hu, eb, left_text, right_text, states, left_reserve, right_reserve, left_state, right_state, left_buffer, right_buffer, reads),
    acc, other_acc, same)

def reserve_cursor(+size: Nat, +len: U32, +s: U32, +pos: U32, +limit: Nat,
  lower: MNat.le(U32.to_nat(s), U32.to_nat(pos)), upper: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  reserve: MNat.lt(Nat.add(Nat.add(Nat.add(size, U32.to_nat((len - s : U32))), 1n), 3n), limit)) ->
  MNat.lt(Nat.add(Nat.add(Nat.add(size, U32.to_nat((len - pos : U32))), 1n), 3n), limit):
  MNat.lt_of_le_of_lt(Nat.add(Nat.add(Nat.add(size, U32.to_nat((len - pos : U32))), 1n), 3n),
    Nat.add(Nat.add(Nat.add(size, U32.to_nat((len - s : U32))), 1n), 3n), limit,
    MNat.add_le_add_right(Nat.add(Nat.add(size, U32.to_nat((len - pos : U32))), 1n),
      Nat.add(Nat.add(size, U32.to_nat((len - s : U32))), 1n), 3n,
      MNat.add_le_add_right(Nat.add(size, U32.to_nat((len - pos : U32))),
        Nat.add(size, U32.to_nat((len - s : U32))), 1n,
        MNat.add_le_add_left(U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32)), size,
          Refinement.suffix_length_le(s, pos, len, lower, upper)))), reserve)

def pending_progress_lf_bounds(+len: U32, +src: Tree.Tree<U32>, +s: U32, -st: Sse.St, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +available: {U32.is_lt(s, len) == True{} : Bool},
  lf: {Model.peek(src, s) == 10 : U32},
  reserve: Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, src), s, True{}, st}, limit),
  state: Drain.state_valid(st, limit),
  buffer: Drain.buffer_valid(len, Tree.reify(U32, src), (s + 1 : U32), (s + 1 : U32), limit),
  bounds: MNat.le(U32.to_nat(s), U32.to_nat((s + 1 : U32))) & MNat.le(U32.to_nat((s + 1 : U32)), U32.to_nat(len))) ->
  Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, True{}, st})):
  (+name, +old, +id, +retry, +data_len, +data, +eq, shape, length, bound, reads) = state
  (+lower, +upper) = bounds
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, True{}, _}))
  Budget.result_progress_transport(s, len,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, True{},
      Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}}),
    Sse.next.at(len, (s + 1 : U32), Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry},
      (Tree.reify(U32, src), (s + 1 : U32), False{})),
    Drain.next_pending_restart(len, s, src, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, available, lf, lower),
    Budget.result_progress_trans(s, (s + 1 : U32), len,
      Sse.next.at(len, (s + 1 : U32), Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry},
        (Tree.reify(U32, src), (s + 1 : U32), False{})), lower,
      Budget.next_at_progress_valid(len, Tree.reify(U32, src), (s + 1 : U32), False{},
        Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit, hu,
        reserve_cursor(U32.to_nat(data_len), len, s, (s + 1 : U32), limit, lower, upper,
          (%eq : Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, src), s, True{}, _}, limit); reserve)),
        (buffer, name, old, id, retry, data_len, data, {==}, shape, length, bound, reads))))

def pending_progress_lf(+len: U32, +src: Tree.Tree<U32>, +s: U32, -st: Sse.St, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +available: {U32.is_lt(s, len) == True{} : Bool},
  lf: {Model.peek(src, s) == 10 : U32},
  reserve: Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, src), s, True{}, st}, limit),
  valid: Drain.line_valid(len, Sse.LMore{Tree.reify(U32, src), s, True{}, st}, limit)) ->
  Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, True{}, st})):
  ((+tree, prefix, tail, +ea, (shape, +hl, lower, upper, width, length, reads, clean)), state) = valid
  pending_progress_lf_bounds(len, src, s, st, limit, hu, available, lf, reserve, state,
    (tree, "", Drain.restarted_tail(len, tree, (s + 1 : U32)), ea,
      Drain.restarted_buffer(len, tree, (s + 1 : U32), limit, shape, hl,
        Pair.snd(MNat.le(U32.to_nat(s), U32.to_nat((s + 1 : U32))), MNat.le(U32.to_nat((s + 1 : U32)), U32.to_nat(len)),
          Drain.cursor_step(s, len, limit,
            Equal.trans(Bool, Nat.is_lt(U32.to_nat(s), U32.to_nat(len)), U32.is_lt(s, len), True{},
              Equal.sym(Bool, U32.is_lt(s, len), Nat.is_lt(U32.to_nat(s), U32.to_nat(len)), Lemmas.u32_is_lt_nat(s, len)), available),
            MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu)))),
    Drain.cursor_step(s, len, limit,
      Equal.trans(Bool, Nat.is_lt(U32.to_nat(s), U32.to_nat(len)), U32.is_lt(s, len), True{},
        Equal.sym(Bool, U32.is_lt(s, len), Nat.is_lt(U32.to_nat(s), U32.to_nat(len)), Lemmas.u32_is_lt_nat(s, len)), available),
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu))

def pending_progress_byte(lf: Bool, +len: U32, +src: Tree.Tree<U32>, +s: U32, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), +available: {U32.is_lt(s, len) == True{} : Bool},
  selected: {U32.is_eq(Model.peek(src, s), 10) == lf : Bool},
  reserve: Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, src), s, True{}, st}, limit),
  valid: Drain.line_valid(len, Sse.LMore{Tree.reify(U32, src), s, True{}, st}, limit)) ->
  Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, True{}, st})):
  match lf:
    case True{}:
      pending_progress_lf(len, src, s, st, limit, hu, available, Next.byte_eq(Model.peek(src, s), 10, selected), reserve, valid)
    case False{}:
      Budget.result_progress_transport(s, len,
        Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, True{}, st}),
        Sse.next.at(len, s, st, (Tree.reify(U32, src), s, False{})),
        Drain.next_pending_non_lf(len, s, s, src, st, available, selected),
        Budget.next_at_progress_valid(len, Tree.reify(U32, src), s, False{}, st, limit, hu, reserve, valid))

def pending_progress_available(available: Bool, +len: U32, +src: Tree.Tree<U32>, +s: U32, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), selected: {U32.is_lt(s, len) == available : Bool},
  reserve: Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, src), s, True{}, st}, limit),
  valid: Drain.line_valid(len, Sse.LMore{Tree.reify(U32, src), s, True{}, st}, limit)) ->
  Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, True{}, st})):
  match available:
    case True{}:
      pending_progress_byte(U32.is_eq(Model.peek(src, s), 10), len, src, s, st, limit, hu, selected, {==}, reserve, valid)
    case False{}:
      %Equal.sym(Bool, U32.is_lt(s, len), False{}, selected) :
        Budget.result_progress(s, len, Sse.next.at(len, s, st, Sse.skip.at(_, Tree.reify(U32, src), s)))
      Budget.next_at_progress_valid(len, Tree.reify(U32, src), s, True{}, st, limit, hu, reserve, valid)

def restarted_next_progress(cr: Bool, +len: U32, -a: Array<U32>, +s: U32, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  valid: Drain.line_valid(len, Sse.LMore{a, s, cr, st}, limit)) ->
  Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st})):
  match cr:
    case False{}: Budget.next_at_progress_valid(len, a, s, False{}, st, limit, hu, reserve, valid)
    case True{}:
      ((+src, +prefix, +tail, +eq, buffer), state) = valid
      %Equal.sym(Array<U32>, a, Tree.reify(U32, src), eq) :
        Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, _}, s, s, True{}, st}))
      pending_progress_available(U32.is_lt(s, len), len, src, s, st, limit, hu, {==},
        (%eq : Budget.line_reserved(len, Sse.LMore{_, s, True{}, st}, limit); reserve),
        ((src, prefix, tail, {==}, buffer), state))

def next_progress_normalized(+len: U32, -a: Array<U32>, +s: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  normalized: {Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}) : Sse.Reader & Sse.Next} &
    Drain.line_valid(len, Sse.LMore{a, s, cr, st}, limit)) ->
  Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st})):
  (eq, valid) = normalized
  Budget.result_progress_transport(s, len,
    Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}), eq,
    restarted_next_progress(cr, len, a, s, st, limit, hu, reserve, valid))

def next_progress(+len: U32, -a: Array<U32>, +s: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, limit)) ->
  Budget.result_progress(s, len, Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st})):
  next_progress_normalized(len, a, s, seen, cr, st, limit, hu, reserve,
    normalize_reader(len, a, s, seen, cr, st, limit, hu, valid))

def reader_valid_copies(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St,
  +src: Tree.Tree<U32>, +prefix: String, +tail: String, +limit: Nat,
  +eq: {a == Tree.reify(U32, src) : Array<U32>},
  buffers: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit) &
    Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit),
  +name: String, +old: String, +id: String, +retry: Maybe<&2, U32>,
  states: Budget.snapshot_for_view((name, old, id, retry), st, limit) &
    Budget.snapshot_for_view((name, old, id, retry), st, limit)) ->
  reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit) &
    reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit):
  (left_buffer, right_buffer) = buffers
  (left_state, right_state) = states
  (((src, prefix, tail, eq, left_buffer), name, old, id, retry, left_state),
    ((src, prefix, tail, eq, right_buffer), name, old, id, retry, right_state))

def reader_valid_copy(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit) &
    reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit):
  ((+src, +prefix, +tail, eq, buffer), +name, +old, +id, +retry, state) = valid
  reader_valid_copies(len, a, pos, seen, cr, st, src, prefix, tail, limit, eq,
    Boundary.duplicate_valid(prefix, tail, len, src, pos, seen, limit, buffer), name, old, id, retry,
    Budget.snapshot_copy(old, name, id, retry, st, limit, state))

def self_next_copies(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  copies: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit) &
    reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  after_next(len, len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit):
  (left, right) = copies
  started_seen(len, len, a, a, pos, pos, seen, seen, cr, cr, st, st, 0n, limit, hu, {==},
    ({==}, {==}, {==}, left, right, reserve))

def self_next(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  after_next(len, len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit):
  self_next_copies(len, a, pos, seen, cr, st, limit, hu, reserve, reader_valid_copy(len, a, pos, seen, cr, st, limit, valid))

def drain_room(+fuel: Nat, +len: U32, -result: Sse.Reader & Sse.Next) -> Type:
  {Budget.is_got(Budget.result_line(result)) == True{} : Bool} ->
    MNat.lt(U32.to_nat((len - Budget.line_position(Budget.result_line(result)) : U32)), fuel)

def drain_room_after(+fuel: Nat, +len: U32, +s: U32, -result: Sse.Reader & Sse.Next,
  before: MNat.lt(U32.to_nat((len - s : U32)), 1n+fuel),
  progress: Budget.result_progress(s, len, result)) -> drain_room(fuel, len, result):
  match progress:
    case Inl{no_event}:
      event => Empty.absurd(MNat.lt(U32.to_nat((len - Budget.line_position(Budget.result_line(result)) : U32)), fuel),
        MNat.internal_false_ne_true(Equal.trans(Bool, False{}, Budget.is_got(Budget.result_line(result)), True{},
          Equal.sym(Bool, Budget.is_got(Budget.result_line(result)), False{}, no_event), event)))
    case Inr{(+pos, eq, strict, upper)}:
      event => (
        %Equal.sym(U32, Budget.line_position(Budget.result_line(result)), pos, eq) :
          MNat.lt(U32.to_nat((len - _ : U32)), fuel)
        MNat.lt_of_lt_of_le(U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32)), fuel,
          Budget.remaining_strict(len, s, pos, strict, upper),
          MNat.le_of_lt_succ(U32.to_nat((len - s : U32)), fuel, before)))

def event_advance(fuel: Nat, result: Sse.Reader & Sse.Next) -> Sse.Reader & Sse.Next:
  match fuel:
    case 0n: result
    case 1n+p:
      (rd, next) = result
      match next:
        case Sse.Want{}: (rd, Sse.Want{})
        case Sse.Got{message}: event_advance(p, Sse.next(rd))

# Keep the terminal equation folded: https://github.com/bendlang/bend/issues/1071.
type EventHalted<-fuel: Nat, -result: Sse.Reader & Sse.Next> is Type:
  EventHalted{proof: {Budget.is_got(Budget.result_line(event_advance(fuel, result))) == False{} : Bool}}

def event_halted(+fuel: Nat, -result: Sse.Reader & Sse.Next) -> Type:
  EventHalted<fuel, result>

def event_valid(+len: U32, -result: Sse.Reader & Sse.Next, +limit: Nat) -> Type:
  {reader_length(result_reader(result)) == len : U32} &
    reader_valid(result_reader(result), limit) &
    Budget.line_reserved(len, reader_line(result_reader(result)), limit)

def event_result_facts(+len: U32, -result: Sse.Reader & Sse.Next, +limit: Nat,
  length: {reader_length(result_reader(result)) == len : U32},
  reserve: Budget.line_reserved(len, Budget.result_line(result), limit),
  facts: reader_valid(result_reader(result), limit) &
    {stripped(Drain.line_view(len, Budget.result_line(result))) == reader_view(result_reader(result)) : Budget.view_type()} &
    {Budget.line_mass(len, Budget.result_line(result)) == Budget.line_mass(len, reader_line(result_reader(result))) : Nat}) ->
  event_valid(len, result, limit):
  (valid, view, mass) = facts
  (length, valid,
    (%mass : MNat.lt(Nat.add(Nat.add(_, 1n), 3n), limit); reserve))

def event_from_certificate_actual(result: Sse.Reader & Sse.Next, +limit: Nat,
  certificate: Budget.next_certificate(result_length(result), result_length(result), result, result, limit)) ->
  event_valid(result_length(result), result, limit):
  (Sse.Reader{Bytes.Bytes{+la, a}, +pos, +seen, +cr, st}, n) = result
  (((views, valid, other_valid), reserve), canonical, other_canonical) = certificate
  event_result_facts(la, (Sse.Reader{Bytes.Bytes{la, a}, pos, seen, cr, st}, n), limit, {==}, reserve,
    result_facts(n, la, a, pos, seen, cr, st, limit, canonical, valid))

def event_from_certificate(+len: U32, result: Sse.Reader & Sse.Next, +limit: Nat,
  +length: {result_length(result) == len : U32},
  certificate: Budget.next_certificate(len, len, result, result, limit)) -> event_valid(len, result, limit):
  %length : event_valid(_, result, limit)
  event_from_certificate_actual(result, limit,
    (%Equal.sym(U32, result_length(result), len, length) :
      Budget.next_certificate(_, _, result, result, limit); certificate))

def next_event_valid(+len: U32, rd: Sse.Reader, +limit: Nat,
  facts: after_next(len, len, rd, rd, limit)) -> event_valid(len, Sse.next(rd), limit):
  (left_length, right_length, certificate) = facts
  event_from_certificate(len, Sse.next(rd), limit, left_length, certificate)

type ReaderSeed is Data:
  ReaderSeed{len: U32, src: Tree.Tree<U32>, pos: U32, seen: U32, cr: Bool,
    name: String, data_len: U32, data: Tree.Tree<U32>, id: String, retry: Maybe<&2, U32>}

def seed_length(seed: ReaderSeed) -> U32:
  ReaderSeed{len, src, pos, seen, cr, name, data_len, data, id, retry} = seed
  len

def seed_reader(seed: ReaderSeed) -> Sse.Reader:
  ReaderSeed{len, src, pos, seen, cr, name, data_len, data, id, retry} = seed
  Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}}

def seed_self(+seed: ReaderSeed, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit),
  valid: reader_valid(seed_reader(seed), limit)) ->
  after_next(seed_length(seed), seed_length(seed), seed_reader(seed), seed_reader(seed), limit):
  ReaderSeed{+len, +src, +pos, +seen, +cr, +name, +data_len, +data, +id, +retry} = seed
  self_next(len, Tree.reify(U32, src), pos, seen, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit, hu, reserve, valid)

def seed_event_valid(+seed: ReaderSeed, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit),
  valid: reader_valid(seed_reader(seed), limit)) ->
  event_valid(seed_length(seed), Sse.next(seed_reader(seed)), limit):
  next_event_valid(seed_length(seed), seed_reader(seed), limit, seed_self(seed, limit, hu, reserve, valid))
def reader_rebuild(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St,
  +src: Tree.Tree<U32>, +name: String, +data_len: U32, +data: Tree.Tree<U32>, +id: String, +retry: Maybe<&2, U32>,
  ea: {a == Tree.reify(U32, src) : Array<U32>},
  eq: {st == Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry} : Sse.St}) ->
  {Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st} ==
    seed_reader(ReaderSeed{len, src, pos, seen, cr, name, data_len, data, id, retry}) : Sse.Reader}:
  Equal.trans(Sse.Reader, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st},
    Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st},
    Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr,
      Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}},
    Equal.cong(Array<U32>, Sse.Reader, x => Sse.Reader{Bytes.Bytes{len, x}, pos, seen, cr, st},
      a, Tree.reify(U32, src), ea),
    Equal.cong(Sse.St, Sse.Reader, x => Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, x},
      st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq))

def seed_inputs(+len: U32, -rd: Sse.Reader, +limit: Nat) -> Type:
  &seed: ReaderSeed ->
    {len == seed_length(seed) : U32} & {rd == seed_reader(seed) : Sse.Reader} &
    reader_valid(seed_reader(seed), limit) &
    Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit)

def seed_inputs_reserved(+len: U32, -rd: Sse.Reader, +seed: ReaderSeed, +limit: Nat,
  +length: {len == seed_length(seed) : U32}, +eq: {rd == seed_reader(seed) : Sse.Reader},
  reserve: Budget.line_reserved(len, reader_line(rd), limit), valid: reader_valid(seed_reader(seed), limit)) ->
  seed_inputs(len, rd, limit):
  (seed, length, eq, valid,
    (%length : Budget.line_reserved(_, reader_line(seed_reader(seed)), limit);
     %eq : Budget.line_reserved(len, reader_line(_), limit); reserve))

def reader_seed(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  seed_inputs(len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit):
  ((+src, +prefix, +tail, +ea, buffer), +name, +old, +id, +retry, +data_len, +data, +eq, shape, length, bound, reads) = valid
  seed_inputs_reserved(len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st},
    ReaderSeed{len, src, pos, seen, cr, name, data_len, data, id, retry}, limit, {==},
    reader_rebuild(len, a, pos, seen, cr, st, src, name, data_len, data, id, retry, ea, eq), reserve,
    ((src, prefix, tail, {==}, buffer), name, old, id, retry, data_len, data, {==}, shape, length, bound, reads))

def event_from_seed(+len: U32, -rd: Sse.Reader, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), inputs: seed_inputs(len, rd, limit)) ->
  event_valid(len, Sse.next(rd), limit):
  (+seed, length, eq, valid, reserve) = inputs
  %Equal.sym(U32, len, seed_length(seed), length) : event_valid(_, Sse.next(rd), limit)
  %Equal.sym(Sse.Reader, rd, seed_reader(seed), eq) : event_valid(seed_length(seed), Sse.next(_), limit)
  seed_event_valid(seed, limit, hu, reserve, valid)

def event_next_valid(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  event_valid(len, Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}), limit):
  event_from_seed(len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit, hu,
    reader_seed(len, a, pos, seen, cr, st, limit, reserve, valid))
def seed_next_progress(+seed: ReaderSeed, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit),
  valid: reader_valid(seed_reader(seed), limit)) ->
  Budget.result_progress(Budget.line_position(reader_line(seed_reader(seed))), seed_length(seed), Sse.next(seed_reader(seed))):
  ReaderSeed{+len, +src, +pos, +seen, +cr, +name, +data_len, +data, +id, +retry} = seed
  next_progress(len, Tree.reify(U32, src), pos, seen, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit, hu, reserve, valid)

def seed_valid_copy(+seed: ReaderSeed, +limit: Nat, valid: reader_valid(seed_reader(seed), limit)) ->
  reader_valid(seed_reader(seed), limit) & reader_valid(seed_reader(seed), limit):
  ReaderSeed{+len, +src, +pos, +seen, +cr, +name, +data_len, +data, +id, +retry} = seed
  reader_valid_copy(len, Tree.reify(U32, src), pos, seen, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit, valid)

def progress_room_scalars(+fuel: Nat, +len: U32, +s: U32, +got: Bool, +at: U32,
  before: MNat.lt(U32.to_nat((len - s : U32)), 1n+fuel),
  progress: {got == False{} : Bool} |
    (&pos: U32 -> {at == pos : U32} & MNat.lt(U32.to_nat(s), U32.to_nat(pos)) &
      MNat.le(U32.to_nat(pos), U32.to_nat(len)))) ->
  {got == True{} : Bool} -> MNat.lt(U32.to_nat((len - at : U32)), fuel):
  match progress:
    case Inl{no_event}:
      event => Empty.absurd(MNat.lt(U32.to_nat((len - at : U32)), fuel),
        MNat.internal_false_ne_true(Equal.trans(Bool, False{}, got, True{},
          Equal.sym(Bool, got, False{}, no_event), event)))
    case Inr{(+pos, eq, strict, upper)}:
      event => (
        %Equal.sym(U32, at, pos, eq) : MNat.lt(U32.to_nat((len - _ : U32)), fuel)
        MNat.lt_of_lt_of_le(U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32)), fuel,
          Budget.remaining_strict(len, s, pos, strict, upper),
          MNat.le_of_lt_succ(U32.to_nat((len - s : U32)), fuel, before)))

def seed_room(+fuel: Nat, +seed: ReaderSeed, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  before: MNat.lt(U32.to_nat((seed_length(seed) - Budget.line_position(reader_line(seed_reader(seed))) : U32)), 1n+fuel),
  reserve: Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit),
  valid: reader_valid(seed_reader(seed), limit)) ->
  drain_room(fuel, seed_length(seed), Sse.next(seed_reader(seed))):
  progress_room_scalars(fuel, seed_length(seed), Budget.line_position(reader_line(seed_reader(seed))),
    Budget.is_got(Budget.result_line(Sse.next(seed_reader(seed)))),
    Budget.line_position(Budget.result_line(Sse.next(seed_reader(seed)))), before,
    seed_next_progress(seed, limit, hu, reserve, valid))
def seed_halts_goal(+fuel: Nat, +seed: ReaderSeed, +limit: Nat) -> Type:
  MNat.lt(U32.to_nat((seed_length(seed) - Budget.line_position(reader_line(seed_reader(seed))) : U32)), fuel) ->
    Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit) ->
    reader_valid(seed_reader(seed), limit) -> event_halted(fuel, Sse.next(seed_reader(seed)))

def event_halts_from_seed(+fuel: Nat, +len: U32, -rd: Sse.Reader, +limit: Nat,
  ih: @seed: ReaderSeed -> seed_halts_goal(fuel, seed, limit),
  before: MNat.lt(U32.to_nat((len - Budget.line_position(reader_line(rd)) : U32)), fuel),
  inputs: seed_inputs(len, rd, limit)) -> event_halted(fuel, Sse.next(rd)):
  (+seed, +length, +eq, valid, reserve) = inputs
  %Equal.sym(Sse.Reader, rd, seed_reader(seed), eq) : event_halted(fuel, Sse.next(_))
  ih(seed,
    (%length : MNat.lt(U32.to_nat((_ - Budget.line_position(reader_line(seed_reader(seed))) : U32)), fuel);
     %eq : MNat.lt(U32.to_nat((len - Budget.line_position(reader_line(_)) : U32)), fuel); before),
    reserve, valid)

def reader_seed_any(+len: U32, rd: Sse.Reader, +limit: Nat,
  +length: {reader_length(rd) == len : U32},
  reserve: Budget.line_reserved(len, reader_line(rd), limit), valid: reader_valid(rd, limit)) ->
  seed_inputs(len, rd, limit):
  Sse.Reader{Bytes.Bytes{+la, a}, +pos, +seen, +cr, st} = rd
  %length : seed_inputs(_, Sse.Reader{Bytes.Bytes{la, a}, pos, seen, cr, st}, limit)
  reader_seed(la, a, pos, seen, cr, st, limit,
    (%Equal.sym(U32, la, len, length) : Budget.line_reserved(_, Sse.LMore{a, pos, cr, st}, limit); reserve), valid)

def event_halts_reader(+fuel: Nat, +len: U32, rd: Sse.Reader, +limit: Nat,
  ih: @seed: ReaderSeed -> seed_halts_goal(fuel, seed, limit),
  before: MNat.lt(U32.to_nat((len - Budget.line_position(reader_line(rd)) : U32)), fuel),
  facts: {reader_length(rd) == len : U32} & reader_valid(rd, limit) &
    Budget.line_reserved(len, reader_line(rd), limit)) -> event_halted(fuel, Sse.next(rd)):
  (length, valid, reserve) = facts
  event_halts_from_seed(fuel, len, rd, limit, ih, before, reader_seed_any(len, rd, limit, length, reserve, valid))

def event_got_box(+fuel: Nat, -rd: Sse.Reader, -message: Sse.Message,
  proof: event_halted(fuel, Sse.next(rd))) -> event_halted(1n+fuel, (rd, Sse.Got{message})):
  EventHalted{eq} = proof
  EventHalted{eq}

def event_halts_result(+fuel: Nat, +len: U32, result: Sse.Reader & Sse.Next, +limit: Nat,
  ih: @seed: ReaderSeed -> seed_halts_goal(fuel, seed, limit),
  facts: drain_room(fuel, len, result) & event_valid(len, result, limit)) -> event_halted(1n+fuel, result):
  (Sse.Reader{Bytes.Bytes{+la, a}, +pos, +seen, +cr, st}, next) = result
  match next:
    case Sse.Want{}:
      EventHalted{{==}}
    case Sse.Got{message}:
      (room, valid) = facts
      event_got_box(fuel, Sse.Reader{Bytes.Bytes{la, a}, pos, seen, cr, st}, message,
        event_halts_reader(fuel, len, Sse.Reader{Bytes.Bytes{la, a}, pos, seen, cr, st}, limit, ih, room({==}), valid))

def event_halted_transport(+fuel: Nat, -left: Sse.Reader & Sse.Next, -right: Sse.Reader & Sse.Next,
  eq: {left == right : Sse.Reader & Sse.Next}, proof: event_halted(fuel, right)) -> event_halted(fuel, left):
  %Equal.sym(Sse.Reader & Sse.Next, left, right, eq) : event_halted(fuel, _)
  proof

def seed_halts_succ_abstract(+fuel: Nat, +seed: ReaderSeed, result: Sse.Reader & Sse.Next, +limit: Nat,
  +eq: {Sse.next(seed_reader(seed)) == result : Sse.Reader & Sse.Next},
  ih: @next: ReaderSeed -> seed_halts_goal(fuel, next, limit),
  facts: drain_room(fuel, seed_length(seed), Sse.next(seed_reader(seed))) &
    event_valid(seed_length(seed), Sse.next(seed_reader(seed)), limit)) ->
  event_halted(1n+fuel, Sse.next(seed_reader(seed))):
  event_halted_transport(1n+fuel, Sse.next(seed_reader(seed)), result, eq,
    event_halts_result(fuel, seed_length(seed), result, limit, ih,
      (%eq : drain_room(fuel, seed_length(seed), _) & event_valid(seed_length(seed), _, limit); facts)))

def seed_halts_with_facts(+fuel: Nat, +seed: ReaderSeed, +limit: Nat,
  ih: @next: ReaderSeed -> seed_halts_goal(fuel, next, limit),
  room: drain_room(fuel, seed_length(seed), Sse.next(seed_reader(seed))),
  valid: event_valid(seed_length(seed), Sse.next(seed_reader(seed)), limit)) ->
  event_halted(1n+fuel, Sse.next(seed_reader(seed))):
  seed_halts_succ_abstract(fuel, seed, Sse.next(seed_reader(seed)), limit, {==}, ih, (room, valid))

def seed_halts_succ_copies(+fuel: Nat, +seed: ReaderSeed, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ih: @next: ReaderSeed -> seed_halts_goal(fuel, next, limit),
  before: MNat.lt(U32.to_nat((seed_length(seed) - Budget.line_position(reader_line(seed_reader(seed))) : U32)), 1n+fuel),
  reserves: Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit) &
    Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit),
  copies: reader_valid(seed_reader(seed), limit) & reader_valid(seed_reader(seed), limit)) ->
  event_halted(1n+fuel, Sse.next(seed_reader(seed))):
  (left_reserve, right_reserve) = reserves
  (left, right) = copies
  seed_halts_with_facts(fuel, seed, limit, ih,
    seed_room(fuel, seed, limit, hu, before, left_reserve, left),
    seed_event_valid(seed, limit, hu, right_reserve, right))
def reserve_copies(+mass: Nat, +limit: Nat, +bound: MNat.lt(Nat.add(Nat.add(mass, 1n), 3n), limit)) ->
  MNat.lt(Nat.add(Nat.add(mass, 1n), 3n), limit) & MNat.lt(Nat.add(Nat.add(mass, 1n), 3n), limit):
  (bound, bound)

def seed_halts_succ(+fuel: Nat, +seed: ReaderSeed, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  ih: @next: ReaderSeed -> seed_halts_goal(fuel, next, limit)) -> seed_halts_goal(1n+fuel, seed, limit):
  before => reserve => valid =>
    seed_halts_succ_copies(fuel, seed, limit, hu, ih, before,
      reserve_copies(Budget.line_mass(seed_length(seed), reader_line(seed_reader(seed))), limit, reserve),
      seed_valid_copy(seed, limit, valid))

def seed_halts(fuel: Nat, +limit: Nat, +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  @seed: ReaderSeed -> seed_halts_goal(fuel, seed, limit):
  match fuel:
    case 0n:
      +seed => before => reserve => valid =>
        Empty.absurd(event_halted(0n, Sse.next(seed_reader(seed))),
          MNat.lt_zero(U32.to_nat((seed_length(seed) - Budget.line_position(reader_line(seed_reader(seed))) : U32)))(before))
    case 1n+ +p:
      seed => seed_halts_succ(p, seed, limit, hu, seed_halts(p, limit, hu))

def event_halted_tail(+fuel: Nat, -rd: Sse.Reader, -message: Sse.Message,
  proof: event_halted(1n+fuel, (rd, Sse.Got{message}))) -> event_halted(fuel, Sse.next(rd)):
  EventHalted{eq} = proof
  EventHalted{eq}

def drain_want(fuel: Nat, -rd: Sse.Reader, -acc: List<&1, Sse.Message>) ->
  {Laws.drain(fuel, (rd, Sse.Want{}), acc) == (rd, acc) : Sse.Reader & List<&1, Sse.Message>}:
  match fuel:
    case 0n: {==}
    case 1n+p: {==}

def drain_sufficient(fuel: Nat, +extra: Nat, result: Sse.Reader & Sse.Next, -acc: List<&1, Sse.Message>,
  halted: event_halted(fuel, result)) ->
  {Laws.drain(Nat.add(fuel, extra), result, acc) == Laws.drain(fuel, result, acc) : Sse.Reader & List<&1, Sse.Message>}:
  match fuel:
    case 0n:
      (Sse.Reader{Bytes.Bytes{+len, a}, +pos, +seen, +cr, st}, next) = result
      match next:
        case Sse.Want{}:
          drain_want(extra, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, acc)
        case Sse.Got{message}:
          EventHalted{eq} = halted
          Empty.absurd({Laws.drain(extra, (Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, Sse.Got{message}), acc) ==
            (Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, acc) : Sse.Reader & List<&1, Sse.Message>},
            MNat.internal_false_ne_true(Equal.sym(Bool, True{}, False{}, eq)))
    case 1n+ +p:
      (rd, next) = result
      match next:
        case Sse.Want{}: {==}
        case Sse.Got{message}:
          drain_sufficient(p, extra, Sse.next(rd), Con{message, acc}, event_halted_tail(p, rd, message, halted))

def runtime_room(+len: U32, +pos: U32, lower: MNat.le(U32.to_nat(pos), U32.to_nat(len))) ->
  MNat.lt(U32.to_nat((len - pos : U32)), Nat.add(U32.to_nat(len), 1n)):
  %Equal.sym(Nat, Nat.add(U32.to_nat(len), 1n), 1n+U32.to_nat(len),
    Equal.trans(Nat, Nat.add(U32.to_nat(len), 1n), 1n+Nat.add(U32.to_nat(len), 0n), 1n+U32.to_nat(len),
      MNat.add_succ(U32.to_nat(len), 0n),
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(U32.to_nat(len), 0n), U32.to_nat(len), MNat.add_zero(U32.to_nat(len))))) :
    MNat.lt(U32.to_nat((len - pos : U32)), _)
  %Equal.sym(Nat, U32.to_nat((len - pos : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(pos)),
    Lemmas.u32_sub_nat(len, pos, lower)) : MNat.lt(_, 1n+U32.to_nat(len))
  MNat.lt_of_le_of_lt(Nat.sub(U32.to_nat(len), U32.to_nat(pos)), U32.to_nat(len), 1n+U32.to_nat(len),
    MNat.sub_le(U32.to_nat(len), U32.to_nat(pos)), MNat.lt_succ_self(U32.to_nat(len)))

def runtime_room_valid(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  MNat.lt(U32.to_nat((len - pos : U32)), Nat.add(U32.to_nat(len), 1n)):
  ((src, prefix, tail, eq, (shape, hl, lower, upper, width, length, reads, clean)), state) = valid
  runtime_room(len, pos, MNat.le_trans(U32.to_nat(pos), U32.to_nat(seen), U32.to_nat(len), lower, upper))

def runtime_halts_copies(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  copies: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit) &
    reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  event_halted(Nat.add(U32.to_nat(len), 1n), Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st})):
  (left, right) = copies
  event_halts_from_seed(Nat.add(U32.to_nat(len), 1n), len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit,
    seed_halts(Nat.add(U32.to_nat(len), 1n), limit, hu),
    runtime_room_valid(len, a, pos, seen, cr, st, limit, left),
    reader_seed(len, a, pos, seen, cr, st, limit, reserve, right))

def runtime_halts(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  event_halted(Nat.add(U32.to_nat(len), 1n), Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st})):
  runtime_halts_copies(len, a, pos, seen, cr, st, limit, hu, reserve,
    reader_valid_copy(len, a, pos, seen, cr, st, limit, valid))

def seed_runtime_halts(+seed: ReaderSeed, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit),
  valid: reader_valid(seed_reader(seed), limit)) ->
  event_halted(Nat.add(U32.to_nat(seed_length(seed)), 1n), Sse.next(seed_reader(seed))):
  ReaderSeed{+len, +src, +pos, +seen, +cr, +name, +data_len, +data, +id, +retry} = seed
  runtime_halts(len, Tree.reify(U32, src), pos, seen, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit, hu, reserve, valid)

def seed_feed_drain(+seed: ReaderSeed, -acc: List<&1, Sse.Message>) ->
  {Laws.feed_drain(seed_reader(seed), acc) ==
    Laws.drain(Nat.add(U32.to_nat(seed_length(seed)), 1n), Sse.next(seed_reader(seed)), acc) :
    Sse.Reader & List<&1, Sse.Message>}:
  ReaderSeed{len, src, pos, seen, cr, name, data_len, data, id, retry} = seed
  {==}

def seed_feed_drain_sufficient(+seed: ReaderSeed, +extra: Nat, -acc: List<&1, Sse.Message>, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(seed_length(seed), reader_line(seed_reader(seed)), limit),
  valid: reader_valid(seed_reader(seed), limit)) ->
  {Laws.drain(Nat.add(Nat.add(U32.to_nat(seed_length(seed)), 1n), extra), Sse.next(seed_reader(seed)), acc) ==
    Laws.feed_drain(seed_reader(seed), acc) : Sse.Reader & List<&1, Sse.Message>}:
  Equal.trans(Sse.Reader & List<&1, Sse.Message>,
    Laws.drain(Nat.add(Nat.add(U32.to_nat(seed_length(seed)), 1n), extra), Sse.next(seed_reader(seed)), acc),
    Laws.drain(Nat.add(U32.to_nat(seed_length(seed)), 1n), Sse.next(seed_reader(seed)), acc),
    Laws.feed_drain(seed_reader(seed), acc),
    drain_sufficient(Nat.add(U32.to_nat(seed_length(seed)), 1n), extra, Sse.next(seed_reader(seed)), acc,
      seed_runtime_halts(seed, limit, hu, reserve, valid)),
    Equal.sym(Sse.Reader & List<&1, Sse.Message>,
      Laws.feed_drain(seed_reader(seed), acc),
      Laws.drain(Nat.add(U32.to_nat(seed_length(seed)), 1n), Sse.next(seed_reader(seed)), acc),
      seed_feed_drain(seed, acc)))

def feed_drain_sufficient_from_seed(+len: U32, -rd: Sse.Reader, +extra: Nat, -acc: List<&1, Sse.Message>, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), inputs: seed_inputs(len, rd, limit)) ->
  {Laws.drain(Nat.add(Nat.add(U32.to_nat(len), 1n), extra), Sse.next(rd), acc) ==
    Laws.feed_drain(rd, acc) : Sse.Reader & List<&1, Sse.Message>}:
  (+seed, length, eq, valid, reserve) = inputs
  %Equal.sym(U32, len, seed_length(seed), length) :
    {Laws.drain(Nat.add(Nat.add(U32.to_nat(_), 1n), extra), Sse.next(rd), acc) ==
      Laws.feed_drain(rd, acc) : Sse.Reader & List<&1, Sse.Message>}
  %Equal.sym(Sse.Reader, rd, seed_reader(seed), eq) :
    {Laws.drain(Nat.add(Nat.add(U32.to_nat(seed_length(seed)), 1n), extra), Sse.next(_), acc) ==
      Laws.feed_drain(_, acc) : Sse.Reader & List<&1, Sse.Message>}
  seed_feed_drain_sufficient(seed, extra, acc, limit, hu, reserve, valid)

def feed_drain_sufficient(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St,
  +extra: Nat, -acc: List<&1, Sse.Message>, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  {Laws.drain(Nat.add(Nat.add(U32.to_nat(len), 1n), extra), Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}), acc) ==
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, acc) : Sse.Reader & List<&1, Sse.Message>}:
  feed_drain_sufficient_from_seed(len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, extra, acc, limit, hu,
    reader_seed(len, a, pos, seen, cr, st, limit, reserve, valid))

def drain_relation_transport(+len: U32, +other: U32, +limit: Nat,
  -left: Sse.Reader & List<&1, Sse.Message>, -right: Sse.Reader & List<&1, Sse.Message>,
  -normalized_left: Sse.Reader & List<&1, Sse.Message>, -normalized_right: Sse.Reader & List<&1, Sse.Message>,
  ea: {left == normalized_left : Sse.Reader & List<&1, Sse.Message>},
  eb: {right == normalized_right : Sse.Reader & List<&1, Sse.Message>},
  relation: drain_relation(len, other, normalized_left, normalized_right, limit)) ->
  drain_relation(len, other, left, right, limit):
  %Equal.sym(Sse.Reader & List<&1, Sse.Message>, left, normalized_left, ea) :
    drain_relation(len, other, _, right, limit)
  %Equal.sym(Sse.Reader & List<&1, Sse.Message>, right, normalized_right, eb) :
    drain_relation(len, other, normalized_left, _, limit)
  relation

def seed_started_seen(+left: ReaderSeed, +right: ReaderSeed, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, seed_length(left), seed_length(right)),
  relation: reader_relation(seed_length(left), seed_length(right), seed_reader(left), seed_reader(right), limit)) ->
  after_next(seed_length(left), seed_length(right), seed_reader(left), seed_reader(right), limit):
  ReaderSeed{+len, +a, +s, +seen, +cr, +name, +data_len, +data, +id, +retry} = left
  ReaderSeed{+other, +b, +t, +other_seen, +other_cr, +other_name, +other_data_len, +other_data, +other_id, +other_retry} = right
  started_seen(len, other, Tree.reify(U32, a), Tree.reify(U32, b), s, t, seen, other_seen, cr, other_cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry},
    Sse.St{other_name, Bytes.Bytes{other_data_len, Tree.reify(U32, other_data)}, other_id, other_retry},
    delta, limit, hu, ends, relation)

def seed_common_budget(+left: ReaderSeed, +right: ReaderSeed, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, seed_length(left), seed_length(right)),
  relation: reader_relation(seed_length(left), seed_length(right), seed_reader(left), seed_reader(right), limit),
  left_reserve: Budget.line_reserved(seed_length(left), reader_line(seed_reader(left)), limit),
  right_reserve: Budget.line_reserved(seed_length(right), reader_line(seed_reader(right)), limit),
  left_valid: reader_valid(seed_reader(left), limit), right_valid: reader_valid(seed_reader(right), limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(seed_length(left), seed_length(right),
    Laws.feed_drain(seed_reader(left), acc), Laws.feed_drain(seed_reader(right), other_acc), limit):
  +a = Nat.add(U32.to_nat(seed_length(left)), 1n)
  +b = Nat.add(U32.to_nat(seed_length(right)), 1n)
  drain_relation_transport(seed_length(left), seed_length(right), limit,
    Laws.feed_drain(seed_reader(left), acc), Laws.feed_drain(seed_reader(right), other_acc),
    Laws.drain(Nat.add(a, b), Sse.next(seed_reader(left)), acc),
    Laws.drain(Nat.add(a, b), Sse.next(seed_reader(right)), other_acc),
    Equal.sym(Sse.Reader & List<&1, Sse.Message>,
      Laws.drain(Nat.add(a, b), Sse.next(seed_reader(left)), acc), Laws.feed_drain(seed_reader(left), acc),
      seed_feed_drain_sufficient(left, b, acc, limit, hu, left_reserve, left_valid)),
    Equal.sym(Sse.Reader & List<&1, Sse.Message>,
      Laws.drain(Nat.add(a, b), Sse.next(seed_reader(right)), other_acc), Laws.feed_drain(seed_reader(right), other_acc),
      (%Equal.sym(Nat, Nat.add(a, b), Nat.add(b, a), MNat.add_comm(a, b)) :
        {Laws.drain(_, Sse.next(seed_reader(right)), other_acc) == Laws.feed_drain(seed_reader(right), other_acc) :
          Sse.Reader & List<&1, Sse.Message>}
       seed_feed_drain_sufficient(right, a, other_acc, limit, hu, right_reserve, right_valid))),
    drain_continue(Nat.add(a, b), seed_length(left), seed_length(right), seed_reader(left), seed_reader(right), limit,
      drain_refines(Nat.add(a, b), seed_length(left), seed_length(right), delta, limit, hu, ends)(
        Sse.next(seed_reader(left)), Sse.next(seed_reader(right))), acc, other_acc,
      seed_started_seen(left, right, delta, limit, hu, ends, relation), same))

def seed_feed_drain_copies(+left: ReaderSeed, +right: ReaderSeed, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, seed_length(left), seed_length(right)),
  ea: {reader_length(seed_reader(left)) == seed_length(left) : U32},
  eb: {reader_length(seed_reader(right)) == seed_length(right) : U32},
  views: {reader_view(seed_reader(left)) == reader_view(seed_reader(right)) : Budget.view_type()},
  left_copies: reader_valid(seed_reader(left), limit) & reader_valid(seed_reader(left), limit),
  right_copies: reader_valid(seed_reader(right), limit) & reader_valid(seed_reader(right), limit),
  reserves: Budget.line_reserved(seed_length(left), reader_line(seed_reader(left)), limit) &
    Budget.line_reserved(seed_length(left), reader_line(seed_reader(left)), limit),
  right_reserve: Budget.line_reserved(seed_length(right), reader_line(seed_reader(right)), limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(seed_length(left), seed_length(right),
    Laws.feed_drain(seed_reader(left), acc), Laws.feed_drain(seed_reader(right), other_acc), limit):
  (left_valid, left_keep) = left_copies
  (right_valid, right_keep) = right_copies
  (reserve, keep) = reserves
  seed_common_budget(left, right, delta, limit, hu, ends,
    (ea, eb, views, left_valid, right_valid, reserve), keep, right_reserve, left_keep, right_keep, acc, other_acc, same)

def seed_feed_drain_refines(+left: ReaderSeed, +right: ReaderSeed, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, seed_length(left), seed_length(right)),
  relation: reader_relation(seed_length(left), seed_length(right), seed_reader(left), seed_reader(right), limit),
  right_reserve: Budget.line_reserved(seed_length(right), reader_line(seed_reader(right)), limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(seed_length(left), seed_length(right),
    Laws.feed_drain(seed_reader(left), acc), Laws.feed_drain(seed_reader(right), other_acc), limit):
  (ea, eb, views, left_valid, right_valid, reserve) = relation
  seed_feed_drain_copies(left, right, delta, limit, hu, ends, ea, eb, views,
    seed_valid_copy(left, limit, left_valid), seed_valid_copy(right, limit, right_valid),
    reserve_copies(Budget.line_mass(seed_length(left), reader_line(seed_reader(left))), limit, reserve),
    right_reserve, acc, other_acc, same)

def scanner_not_exhausted_step(+p: Nat, +s: U32, -e: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(1n+p, U32.to_nat(s)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  stopped: {U32.to_nat(e) != Nat.add(1n+p, U32.to_nat(s)) : Nat}) ->
  {U32.to_nat(e) != Nat.add(p, U32.to_nat((s + 1 : U32))) : Nat}:
  +total = Drain.scan_total_step(p, s, limit, hn, hu)
  eq => stopped(Equal.trans(Nat, U32.to_nat(e), Nat.add(p, U32.to_nat((s + 1 : U32))),
    Nat.add(1n+p, U32.to_nat(s)), eq,
    Equal.sym(Nat, Nat.add(1n+p, U32.to_nat(s)), Nat.add(p, U32.to_nat((s + 1 : U32))), total)))

def scanner_stopped_extend(fuel: Nat, +extra: Nat, r: Array<U32> & U32, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(fuel, U32.to_nat(s)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  stopped: {U32.to_nat(Buffer.index(Sse.eol(fuel, r, s))) != Nat.add(fuel, U32.to_nat(s)) : Nat}) ->
  {Sse.eol(Nat.add(fuel, extra), r, s) == Sse.eol(fuel, r, s) : Array<U32> & U32}:
  match fuel:
    case 0n:
      (a, c) = r
      Empty.absurd({Sse.eol(extra, (a, c), s) == (a, s) : Array<U32> & U32}, stopped({==}))
    case 1n+ +p:
      (a, +c) = r
      Scan.eol_elim(x =>
        {U32.to_nat(Buffer.index(x)) != Nat.add(1n+p, U32.to_nat(s)) : Nat} ->
          {Sse.eol(1n+Nat.add(p, extra), (a, c), s) == x : Array<U32> & U32},
        p, a, c, s,
        lf => no_end => (
          %Equal.sym(U32, c, 10, lf) : {Sse.eol(1n+Nat.add(p, extra), (a, _), s) == (a, s) : Array<U32> & U32}
          {==}),
        cr => no_end => (
          %Equal.sym(U32, c, 13, cr) : {Sse.eol(1n+Nat.add(p, extra), (a, _), s) == (a, s) : Array<U32> & U32}
          {==}),
        good => no_end =>
          Equal.trans(Array<U32> & U32,
            Sse.eol(1n+Nat.add(p, extra), (a, c), s),
            Sse.eol(Nat.add(p, extra), Bytes.peek(a, (s + 1 : U32)), (s + 1 : U32)),
            Sse.eol(p, Bytes.peek(a, (s + 1 : U32)), (s + 1 : U32)),
            Scan.eol_step(Nat.add(p, extra), a, c, s, good),
            scanner_stopped_extend(p, extra, Bytes.peek(a, (s + 1 : U32)), (s + 1 : U32), limit,
              Offset.tail_bound(p, s, limit, hu, hn), hu,
              scanner_not_exhausted_step(p, s,
                Buffer.index(Sse.eol(p, Bytes.peek(a, (s + 1 : U32)), (s + 1 : U32))), limit, hn, hu, no_end))))(stopped)

def text_terminated(text: String) -> Type:
  match text:
    case SNil{}: Empty
    case SCon{Chr{c}, tail}: Scan.clean(c) -> text_terminated(tail)

def terminated_clean_step(+tail: String, +src: Tree.Tree<U32>, +s: U32, +c: U32,
  head: {Model.peek(src, s) == c : U32}, terminated: Scan.clean(c) -> text_terminated(tail),
  clean: Scan.clean(Model.peek(src, s)) &
    Scan.clean_prefix(String.length(tail), Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)), (s + 1 : U32)),
  continue: text_terminated(tail) ->
    Scan.clean_prefix(String.length(tail), Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)), (s + 1 : U32)) -> Empty) -> Empty:
  (good, remaining) = clean
  continue(terminated((%head : Scan.clean(_); good)))(remaining)

def terminated_clean_absurd(text: String, +src: Tree.Tree<U32>, +s: U32,
  reads: Model.Reads(text, src, s), terminated: text_terminated(text),
  clean: Scan.clean_prefix(String.length(text), Bytes.peek(Tree.reify(U32, src), s), s)) -> Empty:
  match text:
    case SNil{}: terminated
    case SCon{Chr{+c}, +tail}:
      (head, rest) = reads
      terminated_clean_step(tail, src, s, c, head, terminated,
        (%Buffer.tree_peek(src, s) : Scan.clean_prefix(1n+String.length(tail), _, s); clean),
        terminated_clean_absurd(tail, src, (s + 1 : U32), rest))

def scanner_terminated_extend(+text: String, +extra: Nat, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(String.length(text), U32.to_nat(s)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  reads: Model.Reads(text, src, s), terminated: text_terminated(text)) ->
  {Sse.eol(Nat.add(String.length(text), extra), Bytes.peek(Tree.reify(U32, src), s), s) ==
    Sse.eol(String.length(text), Bytes.peek(Tree.reify(U32, src), s), s) : Array<U32> & U32}:
  scanner_stopped_extend(String.length(text), extra, Bytes.peek(Tree.reify(U32, src), s), s, limit, hn, hu,
    eq => terminated_clean_absurd(text, src, s, reads, terminated,
      Drain.eol_exhausted(String.length(text), Bytes.peek(Tree.reify(U32, src), s), s, limit, hn, hu)(eq)))

def scanner_prefix_relocated_copies(+text: String, +extra: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +s: U32, +t: U32, +delta: Nat, +limit: Nat,
  ha: MNat.lt(Nat.add(String.length(text), U32.to_nat(s)), limit),
  +hb: MNat.lt(Nat.add(String.length(text), U32.to_nat(t)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  here: Offset.offset(delta, s, t), left: Model.Reads(text, a, s),
  rights: Model.Reads(text, b, t) & Model.Reads(text, b, t), terminated: text_terminated(text)) ->
  Offset.offset(delta, Refinement.eol_index(String.length(text), a, s),
    Refinement.eol_index(Nat.add(String.length(text), extra), b, t)):
  (right, keep) = rights
  Refinement.offset_right(delta, Refinement.eol_index(String.length(text), a, s),
    Refinement.eol_index(String.length(text), b, t), Refinement.eol_index(Nat.add(String.length(text), extra), b, t),
    Offset.scans_read(text, a, b, delta, s, t, limit, ha, hb, hu, here, left, right),
    Equal.sym(U32, Refinement.eol_index(Nat.add(String.length(text), extra), b, t),
      Refinement.eol_index(String.length(text), b, t),
      Equal.cong(Array<U32> & U32, U32, Buffer.index,
        Sse.eol(Nat.add(String.length(text), extra), Bytes.peek(Tree.reify(U32, b), t), t),
        Sse.eol(String.length(text), Bytes.peek(Tree.reify(U32, b), t), t),
        scanner_terminated_extend(text, extra, b, t, limit, hb, hu, keep, terminated))))

def scanner_prefix_relocated(+text: String, +extra: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +s: U32, +t: U32, +delta: Nat, +limit: Nat,
  ha: MNat.lt(Nat.add(String.length(text), U32.to_nat(s)), limit),
  hb: MNat.lt(Nat.add(String.length(text), U32.to_nat(t)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  here: Offset.offset(delta, s, t), left: Model.Reads(text, a, s), right: Model.Reads(text, b, t),
  terminated: text_terminated(text)) ->
  Offset.offset(delta, Refinement.eol_index(String.length(text), a, s),
    Refinement.eol_index(Nat.add(String.length(text), extra), b, t)):
  scanner_prefix_relocated_copies(text, extra, a, b, s, t, delta, limit, ha, hb, hu, here, left,
    Offset.reads_duplicate(text, b, t, right), terminated)

def seed_reader_length(+seed: ReaderSeed) -> {reader_length(seed_reader(seed)) == seed_length(seed) : U32}:
  ReaderSeed{len, src, pos, seen, cr, name, data_len, data, id, retry} = seed
  {==}

def feed_drain_seed_pair(+len: U32, +other: U32, -left: Sse.Reader, -right: Sse.Reader, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other),
  views: {reader_view(left) == reader_view(right) : Budget.view_type()},
  left_inputs: seed_inputs(len, left, limit), right_inputs: seed_inputs(other, right, limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(len, other, Laws.feed_drain(left, acc), Laws.feed_drain(right, other_acc), limit):
  (+a, +la, +ea, left_valid, left_reserve) = left_inputs
  (+b, +lb, +eb, right_valid, right_reserve) = right_inputs
  %Equal.sym(U32, len, seed_length(a), la) :
    drain_relation(_, other, Laws.feed_drain(left, acc), Laws.feed_drain(right, other_acc), limit)
  %Equal.sym(U32, other, seed_length(b), lb) :
    drain_relation(seed_length(a), _, Laws.feed_drain(left, acc), Laws.feed_drain(right, other_acc), limit)
  %Equal.sym(Sse.Reader, left, seed_reader(a), ea) :
    drain_relation(seed_length(a), seed_length(b), Laws.feed_drain(_, acc), Laws.feed_drain(right, other_acc), limit)
  %Equal.sym(Sse.Reader, right, seed_reader(b), eb) :
    drain_relation(seed_length(a), seed_length(b), Laws.feed_drain(seed_reader(a), acc), Laws.feed_drain(_, other_acc), limit)
  seed_feed_drain_refines(a, b, delta, limit, hu,
    (%la : Offset.offset(delta, _, seed_length(b)); %lb : Offset.offset(delta, len, _); ends),
    (seed_reader_length(a), seed_reader_length(b),
      (%ea : {reader_view(_) == reader_view(seed_reader(b)) : Budget.view_type()}
       %eb : {reader_view(left) == reader_view(_) : Budget.view_type()}; views),
      left_valid, right_valid, left_reserve), right_reserve, acc, other_acc, same)

def feed_drain_relocated(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St,
  +delta: Nat, +limit: Nat, +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other),
  relation: reader_relation(len, other, Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st},
    Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, limit),
  right_reserve: Budget.line_reserved(other, Sse.LMore{b, t, other_cr, next}, limit),
  acc: List<&1, Sse.Message>, other_acc: List<&1, Sse.Message>,
  same: {Laws.show(acc) == Laws.show(other_acc) : List<&2, String>}) ->
  drain_relation(len, other,
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, acc),
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next}, other_acc), limit):
  (ea, eb, views, left_valid, right_valid, reserve) = relation
  feed_drain_seed_pair(len, other,
    Sse.Reader{Bytes.Bytes{len, a}, s, seen, cr, st}, Sse.Reader{Bytes.Bytes{other, b}, t, other_seen, other_cr, next},
    delta, limit, hu, ends, views,
    reader_seed(len, a, s, seen, cr, st, limit, reserve, left_valid),
    reader_seed(other, b, t, other_seen, other_cr, next, limit, right_reserve, right_valid), acc, other_acc, same)

def extend_view(+future: String, view: Budget.view_type()) -> Budget.view_type():
  (tag, tail, cr, state, message) = view
  (tag, tail ++ future, cr, state, message)

def prefix_line_relation(+future: String, +len: U32, +other: U32,
  -left: Sse.Line, -right: Sse.Line, +limit: Nat) -> Type:
  {extend_view(future, Drain.line_view(len, left)) == Drain.line_view(other, right) : Budget.view_type()} &
    Drain.line_valid(len, left, limit) & Drain.line_valid(other, right, limit)

def prefix_line_transport(+future: String, +len: U32, +other: U32,
  -left: Sse.Line, -right: Sse.Line, -normalized_left: Sse.Line, -normalized_right: Sse.Line, +limit: Nat,
  ea: {left == normalized_left : Sse.Line}, eb: {right == normalized_right : Sse.Line},
  relation: prefix_line_relation(future, len, other, normalized_left, normalized_right, limit)) ->
  prefix_line_relation(future, len, other, left, right, limit):
  %Equal.sym(Sse.Line, left, normalized_left, ea) : prefix_line_relation(future, len, other, _, right, limit)
  %Equal.sym(Sse.Line, right, normalized_right, eb) : prefix_line_relation(future, len, other, normalized_left, _, limit)
  relation

def more_prefix_parts(+future: String, +len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, -view: String & String & String & Maybe<&2, U32>, +limit: Nat,
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ++ future ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_buffer: Drain.buffer_valid(len, Tree.reify(U32, a), s, s, limit),
  right_buffer: Drain.buffer_valid(other, Tree.reify(U32, b), t, t, limit),
  left_state: {Drain.state_view(st) == view : String & String & String & Maybe<&2, U32>} & Drain.state_valid(st, limit),
  right_state: {Drain.state_view(next) == view : String & String & String & Maybe<&2, U32>} & Drain.state_valid(next, limit)) ->
  prefix_line_relation(future, len, other,
    Sse.LMore{Tree.reify(U32, a), s, cr, st}, Sse.LMore{Tree.reify(U32, b), t, cr, next}, limit):
  (left_eq, left_valid) = left_state
  (right_eq, right_valid) = right_state
  +left = Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ++ future
  +right = Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)
  (Equal.trans(Budget.view_type(), (0, left, cr, Drain.state_view(st), None{}),
    (0, left, cr, view, None{}), (0, right, cr, Drain.state_view(next), None{}),
    Equal.cong(String & String & String & Maybe<&2, U32>, Budget.view_type(), x => (0, left, cr, x, None{}),
      Drain.state_view(st), view, left_eq),
    Equal.trans(Budget.view_type(), (0, left, cr, view, None{}), (0, right, cr, view, None{}),
      (0, right, cr, Drain.state_view(next), None{}),
      Equal.cong(String, Budget.view_type(), x => (0, x, cr, view, None{}), left, right, same),
      Equal.sym(Budget.view_type(), (0, right, cr, Drain.state_view(next), None{}), (0, right, cr, view, None{}),
        Equal.cong(String & String & String & Maybe<&2, U32>, Budget.view_type(), x => (0, right, cr, x, None{}),
          Drain.state_view(next), view, right_eq)))),
    (left_buffer, left_valid), (right_buffer, right_valid))

def field_prefix_finish(+future: String, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  -st: Sse.St, -next: Sse.St, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Model.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Model.as_bits(b)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)), qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(other)),
  same: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, a), pos), pos) ++ future ==
    Buffer.observed(U32.to_nat((other - next_pos : U32)), Bytes.peek(Tree.reify(U32, b), next_pos), next_pos) : String},
  cert: Drain.line_field_refines_type(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, cr, st, next, limit)) ->
  prefix_line_relation(future, len, other,
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, next_pos, cr, next), limit):
  (+value, left, right) = cert
  prefix_line_transport(future, len, other,
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, next_pos, cr, next),
    Sse.LMore{Tree.reify(U32, a), pos, cr, Field.field_state_result(len, a, s, e, st)},
    Sse.LMore{Tree.reify(U32, b), next_pos, cr, Field.field_state_result(other, b, t, f, next)}, limit,
    Drain.line_field_pair(a, len, s, e, pos, cr, st), Drain.line_field_pair(b, other, t, f, next_pos, cr, next),
    more_prefix_parts(future, len, other, a, b, pos, next_pos, cr,
      Field.field_state_result(len, a, s, e, st), Field.field_state_result(other, b, t, f, next),
      Field.text_set(Field.field_kind(a, s, e), value, old, name, id, retry), limit, same,
      (a, "", Drain.restarted_tail(len, a, pos), {==}, Drain.restarted_buffer(len, a, pos, limit, left_shape, hl, pl)),
      (b, "", Drain.restarted_tail(other, b, next_pos), {==}, Drain.restarted_buffer(other, b, next_pos, limit, right_shape, hr, qo)),
      Drain.set_snapshot_observe(Field.field_kind(a, s, e), old, value, name, id, retry,
        Field.field_state_result(len, a, s, e, st), limit, hu,
        Drain.field_result_snapshot(Field.field_kind(a, s, e), old, value, name, id, retry, a, len, s, e, pos, cr, st, limit, left)),
      Drain.set_snapshot_observe(Field.field_kind(a, s, e), old, value, name, id, retry,
        Field.field_state_result(other, b, t, f, next), limit, hu,
        Drain.field_result_snapshot(Field.field_kind(a, s, e), old, value, name, id, retry, b, other, t, f, next_pos, cr, next, limit, right))))

def field_prefix_refines(+future: String, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +pos: U32, +next_pos: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Model.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Model.as_bits(b)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  el: MNat.le(U32.to_nat(e), U32.to_nat(len)), fo: MNat.le(U32.to_nat(f), U32.to_nat(other)),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)), qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, e, f),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  body: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  suffix: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, a), pos), pos) ++ future ==
    Buffer.observed(U32.to_nat((other - next_pos : U32)), Bytes.peek(Tree.reify(U32, b), next_pos), next_pos) : String}) ->
  prefix_line_relation(future, len, other,
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, next_pos, cr, next), limit):
  field_prefix_finish(future, old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, st, next, limit,
    left_shape, right_shape, hl, hr, hu, pl, qo, suffix,
    Drain.line_field_refines(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, cr,
      st, next, delta, limit, hl, hr, hu, se, tf, el, fo, starts, ends, hn, left_state, right_state, body))

def clean_scanner_end(+len: U32, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  clean: Scan.clean_prefix(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s)) ->
  {Sse.eol(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s) == (Tree.reify(U32, src), len) :
    Array<U32> & U32}:
  +n = U32.to_nat((len - s : U32))
  %MNat.add_zero(n) :
    {Sse.eol(_, Bytes.peek(Tree.reify(U32, src), s), s) == (Tree.reify(U32, src), len) : Array<U32> & U32}
  Equal.trans(Array<U32> & U32,
    Sse.eol(Nat.add(n, 0n), Bytes.peek(Tree.reify(U32, src), s), s),
    Sse.eol(0n, Bytes.peek(Tree.reify(U32, src), len), len), (Tree.reify(U32, src), len),
    Reader.restart_scan(n, 0n, src, s, len, limit, hu,
      Refinement.endpoint_bound(n, s, len, len, limit, Field.span_end(s, len, sl), MNat.le_refl(U32.to_nat(len)), hl),
      Field.span_end(s, len, sl), clean),
    (%Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), len),
      (Tree.reify(U32, src), Model.peek(src, len)), Buffer.tree_peek(src, len)) :
      {Sse.eol(0n, _, len) == (Tree.reify(U32, src), len) : Array<U32> & U32}; {==}))

def clean_next(+len: U32, +src: Tree.Tree<U32>, +s: U32, -st: Sse.St, +limit: Nat,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  clean: Scan.clean_prefix(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s)) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, False{}, st}) ==
    (Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, len, False{}, st}, Sse.Want{}) : Sse.Reader & Sse.Next}:
  +fuel = Nat.add(U32.to_nat((len - s : U32)), 2n)
  Equal.trans(Sse.Reader & Sse.Next,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, False{}, st}),
    Sse.loop(fuel, Sse.LWant{Tree.reify(U32, src), s, False{}, st}, len),
    (Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, len, False{}, st}, Sse.Want{}),
    Equal.cong(Sse.Line, Sse.Reader & Sse.Next, line => Sse.loop(fuel, line, len),
      Sse.line(Tree.reify(U32, src), len, s, s, False{}, st), Sse.LWant{Tree.reify(U32, src), s, False{}, st},
      Drain.line_want_scanned(src, len, s, False{}, st,
        Equal.cong(Array<U32> & U32, U32, Buffer.index,
          Sse.eol(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s), (Tree.reify(U32, src), len),
          clean_scanner_end(len, src, s, limit, sl, hl, hu, clean)))),
    Drain.loop_want(fuel, Tree.reify(U32, src), len, s, False{}, st))

def clean_feed_drain(+len: U32, +src: Tree.Tree<U32>, +s: U32, -st: Sse.St, +limit: Nat,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  clean: Scan.clean_prefix(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s),
  -acc: List<&1, Sse.Message>) ->
  {Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, False{}, st}, acc) ==
    (Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, len, False{}, st}, acc) : Sse.Reader & List<&1, Sse.Message>}:
  Equal.trans(Sse.Reader & List<&1, Sse.Message>,
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, False{}, st}, acc),
    Laws.drain(Nat.add(U32.to_nat(len), 1n), (Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, len, False{}, st}, Sse.Want{}), acc),
    (Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, len, False{}, st}, acc),
    Equal.cong(Sse.Reader & Sse.Next, Sse.Reader & List<&1, Sse.Message>, result => Laws.drain(Nat.add(U32.to_nat(len), 1n), result, acc),
      Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, False{}, st}),
      (Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, len, False{}, st}, Sse.Want{}),
      clean_next(len, src, s, st, limit, sl, hl, hu, clean)),
    drain_want(Nat.add(U32.to_nat(len), 1n), Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, len, False{}, st}, acc))

def scanner_lf(fuel: Nat, +src: Tree.Tree<U32>, +e: U32,
  positive: MNat.lt(0n, fuel), lf: {Model.peek(src, e) == 10 : U32}) ->
  {Sse.eol(fuel, Bytes.peek(Tree.reify(U32, src), e), e) == (Tree.reify(U32, src), e) : Array<U32> & U32}:
  match fuel:
    case 0n:
      Empty.absurd({Sse.eol(0n, Bytes.peek(Tree.reify(U32, src), e), e) == (Tree.reify(U32, src), e) : Array<U32> & U32},
        MNat.lt_zero(0n, positive))
    case 1n+p:
      %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), e),
        (Tree.reify(U32, src), Model.peek(src, e)), Buffer.tree_peek(src, e)) :
        {Sse.eol(1n+p, _, e) == (Tree.reify(U32, src), e) : Array<U32> & U32}
      %Equal.sym(U32, Model.peek(src, e), 10, lf) :
        {Sse.eol(1n+p, (Tree.reify(U32, src), _), e) == (Tree.reify(U32, src), e) : Array<U32> & U32}
      {==}

def clean_lf_scanner(+len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  clean: Scan.clean_prefix(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s),
  lf: {Model.peek(src, e) == 10 : U32}) ->
  {Sse.eol(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s) == (Tree.reify(U32, src), e) :
    Array<U32> & U32}:
  +n = U32.to_nat((e - s : U32))
  +g = U32.to_nat((len - e : U32))
  %Refinement.split_span(s, e, len, se, MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el)) :
    {Sse.eol(_, Bytes.peek(Tree.reify(U32, src), s), s) == (Tree.reify(U32, src), e) : Array<U32> & U32}
  Equal.trans(Array<U32> & U32,
    Sse.eol(Nat.add(n, g), Bytes.peek(Tree.reify(U32, src), s), s),
    Sse.eol(g, Bytes.peek(Tree.reify(U32, src), e), e), (Tree.reify(U32, src), e),
    Reader.restart_scan(n, g, src, s, e, limit, hu,
      Refinement.endpoint_bound(n, s, e, len, limit, Field.span_end(s, e, se),
        MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el), hl), Field.span_end(s, e, se), clean),
    scanner_lf(g, src, e,
      (%Equal.sym(Nat, g, Nat.sub(U32.to_nat(len), U32.to_nat(e)),
        Lemmas.u32_sub_nat(len, e, MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el))) : MNat.lt(0n, _)
       MNat.sub_pos_of_lt(U32.to_nat(e), U32.to_nat(len), el)), lf))

def line_lf_prefix_refines(+future: String, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Model.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Model.as_bits(b)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)), +fo: MNat.lt(U32.to_nat(f), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, e, f),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_clean: Scan.clean_prefix(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s),
  right_clean: Scan.clean_prefix(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t),
  +left_lf: {Model.peek(a, e) == 10 : U32}, +right_lf: {Model.peek(b, f) == 10 : U32},
  left_nonblank: {U32.is_eq(s, e) == False{} : Bool}, right_nonblank: {U32.is_eq(t, f) == False{} : Bool},
  body: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  suffix: {Buffer.observed(U32.to_nat((len - (e + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (e + 1 : U32)), (e + 1 : U32)) ++ future ==
    Buffer.observed(U32.to_nat((other - (f + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, b), (f + 1 : U32)), (f + 1 : U32)) : String}) ->
  prefix_line_relation(future, len, other,
    Sse.line(Tree.reify(U32, a), len, s, s, cr, st), Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  +left_bound = MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)
  +right_bound = MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr)
  prefix_line_transport(future, len, other,
    Sse.line(Tree.reify(U32, a), len, s, s, cr, st), Sse.line(Tree.reify(U32, b), other, t, t, cr, next),
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, (f + 1 : U32), False{}, next), limit,
    Drain.line_scanned_lf(a, len, s, e, cr, st,
      Equal.cong(Array<U32> & U32, U32, Buffer.index,
        Sse.eol(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s), (Tree.reify(U32, a), e),
        clean_lf_scanner(len, a, s, e, limit, se, el, left_bound, hu, left_clean, left_lf)),
      el, left_lf, left_nonblank),
    Drain.line_scanned_lf(b, other, t, f, cr, next,
      Equal.cong(Array<U32> & U32, U32, Buffer.index,
        Sse.eol(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), (Tree.reify(U32, b), f),
        clean_lf_scanner(other, b, t, f, limit, tf, fo, right_bound, hu, right_clean, right_lf)),
      fo, right_lf, right_nonblank),
    field_prefix_refines(future, old, name, id, retry, a, b, len, other, s, t, e, f, (e + 1 : U32), (f + 1 : U32), False{},
      st, next, delta, limit, left_shape, right_shape, hl, hr, hu, se, tf,
      MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el), MNat.le_of_lt(U32.to_nat(f), U32.to_nat(other), fo),
      Pair.snd(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
        Drain.cursor_step(e, len, limit, el, left_bound, hu)),
      Pair.snd(MNat.le(U32.to_nat(f), U32.to_nat((f + 1 : U32))), MNat.le(U32.to_nat((f + 1 : U32)), U32.to_nat(other)),
        Drain.cursor_step(f, other, limit, fo, right_bound, hu)),
      starts, ends, hn, left_state, right_state, body, suffix))
