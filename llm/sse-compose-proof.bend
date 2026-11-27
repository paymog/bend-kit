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
