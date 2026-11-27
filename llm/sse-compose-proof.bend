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

def drain_want(fuel: Nat, rd: Sse.Reader, acc: List<&1, Sse.Message>) ->
  {Laws.drain(fuel, (rd, Sse.Want{}), acc) == (rd, acc) : Sse.Reader & List<&1, Sse.Message>}:
  match fuel:
    case 0n: {==}
    case 1n+p: {==}

def drain_sufficient(fuel: Nat, +extra: Nat, result: Sse.Reader & Sse.Next, acc: List<&1, Sse.Message>,
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

def seed_feed_drain_sufficient(+seed: ReaderSeed, +extra: Nat, acc: List<&1, Sse.Message>, +limit: Nat,
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

def feed_drain_sufficient_from_seed(+len: U32, -rd: Sse.Reader, +extra: Nat, acc: List<&1, Sse.Message>, +limit: Nat,
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
  +extra: Nat, acc: List<&1, Sse.Message>, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserve: Budget.line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  valid: reader_valid(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, limit)) ->
  {Laws.drain(Nat.add(Nat.add(U32.to_nat(len), 1n), extra), Sse.next(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}), acc) ==
    Laws.feed_drain(Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, acc) : Sse.Reader & List<&1, Sse.Message>}:
  feed_drain_sufficient_from_seed(len, Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, extra, acc, limit, hu,
    reader_seed(len, a, pos, seen, cr, st, limit, reserve, valid))
