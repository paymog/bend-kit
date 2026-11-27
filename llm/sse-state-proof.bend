import Base
import ./sse.bend as Sse
import ./sse-drain-proof.bend as Drain
import ./sse-refinement-proof.bend as Refinement
import ../lemmas/array.bend as Tree
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./sse-field-proof.bend as Field
import ../bytes/append-proof.bend as Packed
import ../bytes/bytes.bend as Local
import ../bits/array-proof.bend as Bound
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ./sse-buffer-proof.bend as Buffer
import ./sse-offset-proof.bend as Offset

# Keep scanner inputs opaque: https://github.com/bendlang/bend/issues/1071.
type Scanner is Data:
  Scanner{src: Tree.Tree<U32>, len: U32, start: U32, cr: Bool}

def scanner_length(r: Scanner) -> U32:
  Scanner{src, len, start, cr} = r
  len

def scanner_line(r: Scanner, st: Sse.St) -> Sse.Line:
  Scanner{src, +len, +start, cr} = r
  Sse.line(Tree.reify(U32, src), len, start, start, cr, st)

def scanner_end(r: Scanner, st: Sse.St) -> Sse.Line:
  Scanner{+src, +len, +start, cr} = r
  +e = Refinement.eol_index(U32.to_nat((len - start : U32)), src, start)
  Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, start, e, cr, st)

def scanner_evaluates(r: Scanner, -st: Sse.St) -> {scanner_line(r, st) == scanner_end(r, st) : Sse.Line}:
  match r:
    case Scanner{src, len, start, cr}:
      Drain.line_scanned(src, len, start, cr, st)

def scanner_lift(+a: Scanner, +b: Scanner, -st: Sse.St, -next: Sse.St, +limit: Nat,
  +ea: {scanner_line(a, st) == scanner_end(a, st) : Sse.Line},
  +eb: {scanner_line(b, next) == scanner_end(b, next) : Sse.Line},
  cert: Drain.line_relation(scanner_length(a), scanner_length(b), scanner_end(a, st), scanner_end(b, next), limit)) ->
  Drain.line_relation(scanner_length(a), scanner_length(b), scanner_line(a, st), scanner_line(b, next), limit):
  Drain.line_transport(scanner_length(a), scanner_length(b), scanner_line(a, st), scanner_line(b, next),
    scanner_end(a, st), scanner_end(b, next), limit, ea, eb, cert)

def scanner_lift_concrete(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +limit: Nat,
  cert: Drain.line_relation(len, other,
    Sse.line.end(U32.is_eq(Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), len),
      Tree.reify(U32, a), len, s, Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), cr, st),
    Sse.line.end(U32.is_eq(Refinement.eol_index(U32.to_nat((other - t : U32)), b, t), other),
      Tree.reify(U32, b), other, t, Refinement.eol_index(U32.to_nat((other - t : U32)), b, t), cr, next), limit)) ->
  Drain.line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  scanner_lift(Scanner{a, len, s, cr}, Scanner{b, other, t, cr}, st, next, limit,
    scanner_evaluates(Scanner{a, len, s, cr}, st), scanner_evaluates(Scanner{b, other, t, cr}, next), cert)

def scanner_source(r: Scanner) -> Tree.Tree<U32>:
  Scanner{src, len, start, cr} = r
  src

def scanner_start(r: Scanner) -> U32:
  Scanner{src, len, start, cr} = r
  start

def scanner_body(r: Scanner, +e: U32, +pos: U32, cr: Bool, st: Sse.St) -> Sse.Line:
  Scanner{src, len, start, pending} = r
  Sse.line.body(True{}, Tree.reify(U32, src), len, start, e, pos, cr, st)

def dispatch_prefix_snapshot(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, +limit: Nat,
  nonempty: {U32.is_zero(len) == False{} : Bool}, +one: MNat.le(1n, U32.to_nat(len)),
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  length: {U32.to_nat((len - 1 : U32)) == String.length(text) : Nat},
  +bound: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  reads: Packed.Reads(text, src, 0)) ->
  Drain.dispatch_emitted_type(text, name, id, retry, len,
    Sse.dispatch(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry})):
  Drain.dispatch_emitted(text, name, id, retry, len, src, Local.depth(Local.words(len)), U32.to_nat(len), nonempty,
    MNat.lt_of_le_of_lt(Local.depth(Local.words(len)), 30n, 32n,
      Packed.allocation_depth(len, Packed.alloc_capacity(len, limit, bound, hu)), {==}),
    (%Equal.sym(Nat, U32.to_nat((len - 1 : U32)), Nat.sub(U32.to_nat(len), 1n), Lemmas.u32_sub_nat(len, 1, one)) :
      MNat.lt(_, U32.to_nat(len))
     Drain.predecessor_lt(U32.to_nat(len), one)),
    MNat.le_trans(U32.to_nat(len), limit, Lemmas.pow2(32n),
      MNat.le_of_lt(U32.to_nat(len), limit,
        MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit,
          MNat.le_add_right(U32.to_nat(len), 3n), bound)), hu),
    Pair.fst(MNat.le(U32.to_nat(len), Nat.mul(Lemmas.pow2(Local.depth(Local.words(len))), 4n)),
      MNat.le(Local.depth(Local.words(len)), 30n), Packed.alloc_capacity(len, limit, bound, hu)),
    length, shape, reads)

def blank_prefix_snapshot(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, +reader: Scanner, +e: U32, +pos: U32, +cr: Bool, +limit: Nat,
  nonempty: {U32.is_zero(len) == False{} : Bool}, +one: MNat.le(1n, U32.to_nat(len)),
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  length: {U32.to_nat((len - 1 : U32)) == String.length(text) : Nat},
  bound: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  reads: Packed.Reads(text, src, 0)) ->
  Drain.line_blank_emitted_type(text, name, id, retry, len, scanner_source(reader), pos, cr,
    scanner_body(reader, e, pos, cr, Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry})):
  match reader:
    case Scanner{+a, +size, +s, pending}:
      Drain.line_blank_emitted(text, name, id, retry, len, src, a, size, s, e, pos, cr,
        dispatch_prefix_snapshot(text, name, id, retry, len, src, limit, nonempty, one, shape, length, bound, hu, reads))

def trim_bound(+len: U32, +limit: Nat, +one: MNat.le(1n, U32.to_nat(len)),
  bound: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit)) ->
  MNat.lt(U32.to_nat((len - 1 : U32)), limit):
  %Equal.sym(Nat, U32.to_nat((len - 1 : U32)), Nat.sub(U32.to_nat(len), 1n), Lemmas.u32_sub_nat(len, 1, one)) :
    MNat.lt(_, limit)
  MNat.lt_trans(Nat.sub(U32.to_nat(len), 1n), U32.to_nat(len), limit,
    Drain.predecessor_lt(U32.to_nat(len), one),
    MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit,
      MNat.le_add_right(U32.to_nat(len), 3n), bound))

def blank_prefix_refines(+a: Scanner, +b: Scanner,
  +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  +text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +data_len: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(scanner_length(a))), Packed.as_bits(scanner_source(a))),
  right_shape: Bound.shape(Local.depth(Local.words(scanner_length(b))), Packed.as_bits(scanner_source(b))),
  hl: MNat.lt(Nat.add(U32.to_nat(scanner_length(a)), 3n), limit),
  hr: MNat.lt(Nat.add(U32.to_nat(scanner_length(b)), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(scanner_length(a))),
  qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(scanner_length(b))),
  +length: {U32.to_nat((data_len - 1 : U32)) == String.length(text) : Nat},
  +nonempty: {U32.is_zero(data_len) == False{} : Bool}, +one: MNat.le(1n, U32.to_nat(data_len)),
  left_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(src)),
  right_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(dst)),
  +data_bound: MNat.lt(Nat.add(U32.to_nat(data_len), 3n), limit),
  left_reads: Packed.Reads(text, src, 0), right_reads: Packed.Reads(text, dst, 0),
  same: {Buffer.observed(U32.to_nat((scanner_length(a) - pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(a)), pos), pos) ==
    Buffer.observed(U32.to_nat((scanner_length(b) - next_pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(b)), next_pos), next_pos) : String}) ->
  Drain.line_relation(scanner_length(a), scanner_length(b),
    scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, src)}, id, retry}),
    scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry}), limit):
  Drain.blank_emitted_refines(text, name, id, retry, data_len, data_len,
    scanner_source(a), scanner_source(b), scanner_length(a), scanner_length(b), pos, next_pos, cr,
    scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, src)}, id, retry}),
    scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry}), limit,
    left_shape, right_shape, hl, hr, hu, bound, pl, qo, length, length,
    trim_bound(data_len, limit, one, data_bound), trim_bound(data_len, limit, one, data_bound), same,
    blank_prefix_snapshot(text, name, id, retry, data_len, src, a, e, pos, cr, limit,
      nonempty, one, left_data_shape, length, data_bound, hu, left_reads),
    blank_prefix_snapshot(text, name, id, retry, data_len, dst, b, f, next_pos, cr, limit,
      nonempty, one, right_data_shape, length, data_bound, hu, right_reads))

def common_trimmed_prefix(+text: String, +len: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>,
  length: {U32.to_nat(len) == String.length(text) : Nat}, one: MNat.le(1n, U32.to_nat(len)),
  left: Packed.Reads(text, src, 0), right: Packed.Reads(text, dst, 0)) ->
  &short: String -> {U32.to_nat((len - 1 : U32)) == String.length(short) : Nat} &
    Packed.Reads(short, src, 0) & Packed.Reads(short, dst, 0):
  (String.take(text, U32.to_nat((len - 1 : U32))), Drain.trimmed_length(text, len, length, one),
    Drain.reads_take(text, U32.to_nat((len - 1 : U32)), src, 0, left),
    Drain.reads_take(text, U32.to_nat((len - 1 : U32)), dst, 0, right))

def blank_nonempty_prefix(+a: Scanner, +b: Scanner,
  +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  +data_len: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(scanner_length(a))), Packed.as_bits(scanner_source(a))),
  right_shape: Bound.shape(Local.depth(Local.words(scanner_length(b))), Packed.as_bits(scanner_source(b))),
  hl: MNat.lt(Nat.add(U32.to_nat(scanner_length(a)), 3n), limit),
  hr: MNat.lt(Nat.add(U32.to_nat(scanner_length(b)), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)), bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(scanner_length(a))),
  qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(scanner_length(b))),
  nonempty: {U32.is_zero(data_len) == False{} : Bool}, one: MNat.le(1n, U32.to_nat(data_len)),
  left_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(src)),
  right_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(dst)),
  data_bound: MNat.lt(Nat.add(U32.to_nat(data_len), 3n), limit),
  same: {Buffer.observed(U32.to_nat((scanner_length(a) - pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(a)), pos), pos) ==
    Buffer.observed(U32.to_nat((scanner_length(b) - next_pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(b)), next_pos), next_pos) : String},
  prefix: &short: String -> {U32.to_nat((data_len - 1 : U32)) == String.length(short) : Nat} &
    Packed.Reads(short, src, 0) & Packed.Reads(short, dst, 0)) ->
  Drain.line_relation(scanner_length(a), scanner_length(b),
    scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, src)}, id, retry}),
    scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry}), limit):
  (+short, length, left, right) = prefix
  blank_prefix_refines(a, b, e, f, pos, next_pos, cr, short, name, id, retry, data_len, src, dst, limit,
    left_shape, right_shape, hl, hr, hu, bound, pl, qo, length, nonempty, one,
    left_data_shape, right_data_shape, data_bound, left, right, same)

def blank_nonempty_observed(+a: Scanner, +b: Scanner,
  +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  +text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +data_len: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(scanner_length(a))), Packed.as_bits(scanner_source(a))),
  right_shape: Bound.shape(Local.depth(Local.words(scanner_length(b))), Packed.as_bits(scanner_source(b))),
  hl: MNat.lt(Nat.add(U32.to_nat(scanner_length(a)), 3n), limit),
  hr: MNat.lt(Nat.add(U32.to_nat(scanner_length(b)), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)), bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(scanner_length(a))),
  qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(scanner_length(b))),
  length: {U32.to_nat(data_len) == String.length(text) : Nat},
  nonempty: {U32.is_zero(data_len) == False{} : Bool}, +one: MNat.le(1n, U32.to_nat(data_len)),
  left_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(src)),
  right_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(dst)),
  data_bound: MNat.lt(Nat.add(U32.to_nat(data_len), 3n), limit),
  left_reads: Packed.Reads(text, src, 0), right_reads: Packed.Reads(text, dst, 0),
  same: {Buffer.observed(U32.to_nat((scanner_length(a) - pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(a)), pos), pos) ==
    Buffer.observed(U32.to_nat((scanner_length(b) - next_pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(b)), next_pos), next_pos) : String}) ->
  Drain.line_relation(scanner_length(a), scanner_length(b),
    scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, src)}, id, retry}),
    scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry}), limit):
  blank_nonempty_prefix(a, b, e, f, pos, next_pos, cr, name, id, retry, data_len, src, dst, limit,
    left_shape, right_shape, hl, hr, hu, bound, pl, qo, nonempty, one,
    left_data_shape, right_data_shape, data_bound, same,
    common_trimmed_prefix(text, data_len, src, dst, length, one, left_reads, right_reads))

def blank_empty_scanners(+a: Scanner, +b: Scanner,
  +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(scanner_length(a))), Packed.as_bits(scanner_source(a))),
  right_shape: Bound.shape(Local.depth(Local.words(scanner_length(b))), Packed.as_bits(scanner_source(b))),
  hl: MNat.lt(Nat.add(U32.to_nat(scanner_length(a)), 3n), limit),
  hr: MNat.lt(Nat.add(U32.to_nat(scanner_length(b)), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)), bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(scanner_length(a))),
  qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(scanner_length(b))),
  left_data_shape: Bound.shape(Local.depth(Local.words(0)), Packed.as_bits(src)),
  right_data_shape: Bound.shape(Local.depth(Local.words(0)), Packed.as_bits(dst)),
  same: {Buffer.observed(U32.to_nat((scanner_length(a) - pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(a)), pos), pos) ==
    Buffer.observed(U32.to_nat((scanner_length(b) - next_pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(b)), next_pos), next_pos) : String}) ->
  Drain.line_relation(scanner_length(a), scanner_length(b),
    scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}),
    scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, dst)}, id, retry}), limit):
  match a b:
    case Scanner{left, len, s, pending} Scanner{right, other, t, next_pending}:
      Drain.blank_empty_refines(name, id, retry, src, dst, left, right, len, other, s, t, e, f,
        pos, next_pos, cr, limit, left_shape, right_shape, left_data_shape, right_data_shape,
        hl, hr, hu, bound, pl, qo, same)

def data_length_case(text: String, +len: U32,
  length: {U32.to_nat(len) == String.length(text) : Nat}) ->
  {len == 0 : U32} | MNat.le(1n, U32.to_nat(len)):
  match text:
    case SNil{}:
      Inl{Lemmas.u32_to_nat_inj(len, 0, length)}
    case SCon{head, tail}:
      Inr{(%Equal.sym(Nat, U32.to_nat(len), String.length(SCon{head, tail}), length) :
        MNat.le(1n, _)
       MNat.succ_le_succ(0n, String.length(tail), MNat.zero_le(String.length(tail))))}

def blank_concrete_cases(+data_len: U32, choice: {data_len == 0 : U32} | MNat.le(1n, U32.to_nat(data_len)),
  +text: String, +a: Scanner, +b: Scanner,
  +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(scanner_length(a))), Packed.as_bits(scanner_source(a))),
  right_shape: Bound.shape(Local.depth(Local.words(scanner_length(b))), Packed.as_bits(scanner_source(b))),
  hl: MNat.lt(Nat.add(U32.to_nat(scanner_length(a)), 3n), limit),
  hr: MNat.lt(Nat.add(U32.to_nat(scanner_length(b)), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)), bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(scanner_length(a))),
  qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(scanner_length(b))),
  +length: {U32.to_nat(data_len) == String.length(text) : Nat},
  left_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(src)),
  right_data_shape: Bound.shape(Local.depth(Local.words(data_len)), Packed.as_bits(dst)),
  data_bound: MNat.lt(Nat.add(U32.to_nat(data_len), 3n), limit),
  left_reads: Packed.Reads(text, src, 0), right_reads: Packed.Reads(text, dst, 0),
  same: {Buffer.observed(U32.to_nat((scanner_length(a) - pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(a)), pos), pos) ==
    Buffer.observed(U32.to_nat((scanner_length(b) - next_pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(b)), next_pos), next_pos) : String}) ->
  Drain.line_relation(scanner_length(a), scanner_length(b),
    scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, src)}, id, retry}),
    scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry}), limit):
  match choice:
    case Inl{+zero}:
      %Equal.sym(U32, data_len, 0, zero) :
        Drain.line_relation(scanner_length(a), scanner_length(b),
          scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{_, Tree.reify(U32, src)}, id, retry}),
          scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{_, Tree.reify(U32, dst)}, id, retry}), limit)
      blank_empty_scanners(a, b, e, f, pos, next_pos, cr, name, id, retry, src, dst, limit,
        left_shape, right_shape, hl, hr, hu, bound, pl, qo,
        (%zero : Bound.shape(Local.depth(Local.words(_)), Packed.as_bits(src)); left_data_shape),
        (%zero : Bound.shape(Local.depth(Local.words(_)), Packed.as_bits(dst)); right_data_shape), same)
    case Inr{+one}:
      blank_nonempty_observed(a, b, e, f, pos, next_pos, cr, text, name, id, retry,
        data_len, src, dst, limit, left_shape, right_shape, hl, hr, hu, bound, pl, qo, length,
        Lemmas.u32_nonzero(data_len, MNat.lt_of_succ_le(0n, U32.to_nat(data_len), one)), one,
        left_data_shape, right_data_shape, data_bound,
        left_reads, right_reads, same)

def blank_body_refines(+a: Scanner, +b: Scanner,
  +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  +text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  -st: Sse.St, -next: Sse.St, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(scanner_length(a))), Packed.as_bits(scanner_source(a))),
  right_shape: Bound.shape(Local.depth(Local.words(scanner_length(b))), Packed.as_bits(scanner_source(b))),
  hl: MNat.lt(Nat.add(U32.to_nat(scanner_length(a)), 3n), limit),
  hr: MNat.lt(Nat.add(U32.to_nat(scanner_length(b)), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)), bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(scanner_length(a))),
  qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(scanner_length(b))),
  same: {Buffer.observed(U32.to_nat((scanner_length(a) - pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(a)), pos), pos) ==
    Buffer.observed(U32.to_nat((scanner_length(b) - next_pos : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(b)), next_pos), next_pos) : String},
  left_state: Field.state_snapshot(name, text, id, retry, st, limit),
  right_state: Field.state_snapshot(name, text, id, retry, next, limit)) ->
  Drain.line_relation(scanner_length(a), scanner_length(b),
    scanner_body(a, e, pos, cr, st), scanner_body(b, f, next_pos, cr, next), limit):
  (+data_len, +src, ea, left_data_shape, +length, data_bound, left_reads) = left_state
  (+other_len, +dst, eb, right_data_shape, other_length, other_bound, right_reads) = right_state
  +same_len = Lemmas.u32_to_nat_inj(other_len, data_len,
    Equal.trans(Nat, U32.to_nat(other_len), String.length(text), U32.to_nat(data_len), other_length,
      Equal.sym(Nat, U32.to_nat(data_len), String.length(text), length)))
  Drain.line_transport(scanner_length(a), scanner_length(b),
    scanner_body(a, e, pos, cr, st), scanner_body(b, f, next_pos, cr, next),
    scanner_body(a, e, pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, src)}, id, retry}),
    scanner_body(b, f, next_pos, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry}), limit,
    Equal.cong(Sse.St, Sse.Line, state => scanner_body(a, e, pos, cr, state),
      st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, src)}, id, retry}, ea),
    Equal.cong(Sse.St, Sse.Line, state => scanner_body(b, f, next_pos, cr, state),
      next, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry},
      Equal.trans(Sse.St, next, Sse.St{name, Bytes.Bytes{other_len, Tree.reify(U32, dst)}, id, retry},
        Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, dst)}, id, retry}, eb,
        Equal.cong(U32, Sse.St, size => Sse.St{name, Bytes.Bytes{size, Tree.reify(U32, dst)}, id, retry},
          other_len, data_len, same_len))),
    blank_concrete_cases(data_len, data_length_case(text, data_len, length),
      text, a, b, e, f, pos, next_pos, cr, name, id, retry, src, dst, limit,
      left_shape, right_shape, hl, hr, hu, bound, pl, qo, length, left_data_shape,
      (%same_len : Bound.shape(Local.depth(Local.words(_)), Packed.as_bits(dst)); right_data_shape),
      data_bound, left_reads, right_reads, same))

def scanner_lf_blank(r: Scanner, +e: U32, -st: Sse.St,
  scan: {Refinement.eol_index(U32.to_nat((scanner_length(r) - scanner_start(r) : U32)),
    scanner_source(r), scanner_start(r)) == e : U32},
  before: MNat.lt(U32.to_nat(e), U32.to_nat(scanner_length(r))),
  lf: {Packed.peek(scanner_source(r), e) == 10 : U32},
  blank: {U32.is_eq(scanner_start(r), e) == True{} : Bool}) ->
  {scanner_line(r, st) == scanner_body(r, e, (e + 1 : U32), False{}, st) : Sse.Line}:
  match r:
    case Scanner{+src, +len, +s, +cr}:
      Equal.trans(Sse.Line, Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
        Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st),
        Sse.line.body(True{}, Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
        Drain.line_scanned_at(src, len, s, e, cr, st, scan),
        Equal.trans(Sse.Line, Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st),
          Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)),
          Sse.line.body(True{}, Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
          Drain.line_end_term(src, len, s, e, cr, st, before),
          Equal.trans(Sse.Line, Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)),
            Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
            Sse.line.body(True{}, Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
            Drain.line_term_lf(src, len, s, e, st, lf),
            Equal.cong(Bool, Sse.Line,
              is_blank => Sse.line.body(is_blank, Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
              U32.is_eq(s, e), True{}, blank))))

def line_lf_blank_refines(+a: Scanner, +b: Scanner,
  +e: U32, +f: U32, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(scanner_length(a))), Packed.as_bits(scanner_source(a))),
  right_shape: Bound.shape(Local.depth(Local.words(scanner_length(b))), Packed.as_bits(scanner_source(b))),
  +hl: MNat.lt(Nat.add(U32.to_nat(scanner_length(a)), 3n), limit),
  +hr: MNat.lt(Nat.add(U32.to_nat(scanner_length(b)), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(scanner_start(a)), U32.to_nat(e)),
  +tf: MNat.le(U32.to_nat(scanner_start(b)), U32.to_nat(f)),
  +el: MNat.lt(U32.to_nat(e), U32.to_nat(scanner_length(a))),
  +fo: MNat.lt(U32.to_nat(f), U32.to_nat(scanner_length(b))),
  +starts: Offset.offset(delta, scanner_start(a), scanner_start(b)),
  +scanned: Offset.offset(delta, e, f), +ends: Offset.offset(delta, scanner_length(a), scanner_length(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_scan: {Refinement.eol_index(U32.to_nat((scanner_length(a) - scanner_start(a) : U32)),
    scanner_source(a), scanner_start(a)) == e : U32},
  right_scan: {Refinement.eol_index(U32.to_nat((scanner_length(b) - scanner_start(b) : U32)),
    scanner_source(b), scanner_start(b)) == f : U32},
  left_lf: {Packed.peek(scanner_source(a), e) == 10 : U32},
  right_lf: {Packed.peek(scanner_source(b), f) == 10 : U32},
  left_blank: {U32.is_eq(scanner_start(a), e) == True{} : Bool},
  right_blank: {U32.is_eq(scanner_start(b), f) == True{} : Bool},
  same: {Buffer.observed(U32.to_nat((scanner_length(a) - scanner_start(a) : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(a)), scanner_start(a)), scanner_start(a)) ==
    Buffer.observed(U32.to_nat((scanner_length(b) - scanner_start(b) : U32)),
      Bytes.peek(Tree.reify(U32, scanner_source(b)), scanner_start(b)), scanner_start(b)) : String}) ->
  Drain.line_relation(scanner_length(a), scanner_length(b), scanner_line(a, st), scanner_line(b, next), limit):
  +len = scanner_length(a)
  +other = scanner_length(b)
  +hl0 = MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)
  +hr0 = MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr)
  +ep = Pair.fst(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
    Drain.cursor_step(e, len, limit, el, hl0, hu))
  +pl = Pair.snd(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
    Drain.cursor_step(e, len, limit, el, hl0, hu))
  +fq = Pair.fst(MNat.le(U32.to_nat(f), U32.to_nat((f + 1 : U32))), MNat.le(U32.to_nat((f + 1 : U32)), U32.to_nat(other)),
    Drain.cursor_step(f, other, limit, fo, hr0, hu))
  +qo = Pair.snd(MNat.le(U32.to_nat(f), U32.to_nat((f + 1 : U32))), MNat.le(U32.to_nat((f + 1 : U32)), U32.to_nat(other)),
    Drain.cursor_step(f, other, limit, fo, hr0, hu))
  +advanced = Offset.increment(delta, e, f, limit,
    MNat.lt_of_le_of_lt(1n+U32.to_nat(e), U32.to_nat(len), limit, MNat.succ_le_of_lt(U32.to_nat(e), U32.to_nat(len), el), hl0),
    MNat.lt_of_le_of_lt(1n+U32.to_nat(f), U32.to_nat(other), limit, MNat.succ_le_of_lt(U32.to_nat(f), U32.to_nat(other), fo), hr0), hu, scanned)
  Drain.line_transport(len, other, scanner_line(a, st), scanner_line(b, next),
    scanner_body(a, e, (e + 1 : U32), False{}, st), scanner_body(b, f, (f + 1 : U32), False{}, next), limit,
    scanner_lf_blank(a, e, st, left_scan, el, left_lf, left_blank),
    scanner_lf_blank(b, f, next, right_scan, fo, right_lf, right_blank),
    blank_body_refines(a, b, e, f, (e + 1 : U32), (f + 1 : U32), False{}, old, name, id, retry, st, next, limit,
      left_shape, right_shape, hl, hr, hu,
      MNat.lt_of_le_of_lt(3n, Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_left(3n, U32.to_nat(len)), hl),
      pl, qo,
      Refinement.subspan(scanner_source(a), scanner_source(b), scanner_start(a), scanner_start(b), len, other,
        (e + 1 : U32), (f + 1 : U32), delta, limit,
        MNat.le_trans(U32.to_nat(scanner_start(a)), U32.to_nat(e), U32.to_nat((e + 1 : U32)), se, ep),
        MNat.le_trans(U32.to_nat(scanner_start(b)), U32.to_nat(f), U32.to_nat((f + 1 : U32)), tf, fq),
        pl, qo, hl0, hr0, hu, starts, advanced, ends, same), left_state, right_state))

def line_lf_blank_concrete(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  el: MNat.lt(U32.to_nat(e), U32.to_nat(len)), fo: MNat.lt(U32.to_nat(f), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), scanned: Offset.offset(delta, e, f), ends: Offset.offset(delta, len, other),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_scan: {Refinement.eol_index(U32.to_nat((len - s : U32)), a, s) == e : U32},
  right_scan: {Refinement.eol_index(U32.to_nat((other - t : U32)), b, t) == f : U32},
  left_lf: {Packed.peek(a, e) == 10 : U32}, right_lf: {Packed.peek(b, f) == 10 : U32},
  left_blank: {U32.is_eq(s, e) == True{} : Bool}, right_blank: {U32.is_eq(t, f) == True{} : Bool},
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Drain.line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  line_lf_blank_refines(Scanner{a, len, s, cr}, Scanner{b, other, t, cr}, e, f, old, name, id, retry,
    st, next, delta, limit, left_shape, right_shape, hl, hr, hu, se, tf, el, fo, starts, scanned, ends,
    left_state, right_state, left_scan, right_scan, left_lf, right_lf, left_blank, right_blank, same)
