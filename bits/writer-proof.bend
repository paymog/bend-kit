import Base
import ./bits.bend as Bits
import ./array-proof.bend as A
import ./LAWS.bend as Laws
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat

type State is Data:
  State{image: A.Tree, dep: U32, pos: U32}

def build(s: State) -> Bits.Writer:
  State{image, dep, pos} = s
  Bits.Writer{A.build(image), dep, pos}

def new() -> State:
  State{A.Leaf{0}, 0, 0}

def room(full: Bool, s: State) -> State:
  match full:
    case False{}:
      s
    case True{}:
      State{image, +dep, pos} = s
      State{A.grow(image, U32.to_nat(dep)), (dep + 1 : U32), pos}

def or_if(some: Bool, +t: A.Tree, +k: U32, x: U32) -> A.Tree:
  match some:
    case False{}:
      t
    case True{}:
      A.set(t, k, U32.or(A.get(t, k), x))

def put(+t: A.Tree, +k: U32, +x0: U32, +x1: U32) -> A.Tree:
  or_if(U32.is_ne(x1, 0), or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32), x1)

def put_parts(t: A.Tree, k: U32, parts: U32 & U32) -> A.Tree:
  (x0, x1) = parts
  put(t, k, x0, x1)

def or_shape(+depth: Nat, some: Bool, +t: A.Tree, +k: U32, +x: U32,
  h: A.shape(depth, t)) -> A.shape(depth, or_if(some, t, k, x)):
  match some:
    case False{}:
      h
    case True{}:
      A.set_shape(depth, t, k, U32.or(A.get(t, k), x), h)

def put_shape(+depth: Nat, +t: A.Tree, +k: U32, +x0: U32, +x1: U32,
  h: A.shape(depth, t)) -> A.shape(depth, put(t, k, x0, x1)):
  or_shape(depth, U32.is_ne(x1, 0), or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32), x1,
    or_shape(depth, U32.is_ne(x0, 0), t, k, x0, h))

def put_parts_shape(+depth: Nat, +t: A.Tree, +k: U32, parts: U32 & U32,
  h: A.shape(depth, t)) -> A.shape(depth, put_parts(t, k, parts)):
  (x0, x1) = parts
  put_shape(depth, t, k, x0, x1, h)

def or_zero_after(+depth: Nat, some: Bool, +t: A.Tree, +k: U32, +x: U32,
  h: A.zero_after(depth, t, k)) -> A.zero_after(depth, or_if(some, t, k, x), k):
  match some:
    case False{}:
      h
    case True{}:
      A.zero_after_set(depth, t, k, U32.or(A.get(t, k), x), h)

def write_at(+msb: Bool, s: State, +n: U32, v: U32) -> State:
  State{t, dep, +pos} = s
  State{put_parts(t, (pos >> 5n : U32), Bits.parts(msb, (pos .&. 31 : U32), n, v)), dep, (pos + n : U32)}

def write(+msb: Bool, s: State, +n0: U32, +v: U32) -> State:
  State{t, +dep, +pos} = s
  +n = U32.min(n0, 32)
  write_at(msb, room(U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((pos + n + 31) >> 5n : U32)), State{t, dep, pos}), n, v)

def puts(fs: List<&2, Laws.F>, +msb: Bool, s: State) -> State:
  match fs:
    case Nil{}:
      s
    case Con{Laws.F{n, v}, t}:
      puts(t, msb, write(msb, s, n, v))

def room_bridge(+full: Bool, +s: State) -> {Bits.room(full, build(s)) == build(room(full, s)) : Bits.Writer}:
  match full:
    case False{}:
      {==}
    case True{}:
      match s:
        case State{+t, +dep, +pos}:
          %A.grow_bridge(t, U32.to_nat(dep)) : {Bits.Writer{_, (dep + 1 : U32), pos} == build(room(True{}, State{t, dep, pos})) : Bits.Writer}
          {==}

def or_bridge(+some: Bool, +t: A.Tree, +k: U32, +x: U32) -> {Bits.or.if(some, A.build(t), k, x) == A.build(or_if(some, t, k, x)) : Array<U32>}:
  match some:
    case False{}:
      {==}
    case True{}:
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), k), (A.build(t), A.get(t, k)), A.get_bridge(t, k)) : {Bits.or.of(k, x, _) == A.build(or_if(True{}, t, k, x)) : Array<U32>}
      A.set_bridge(t, k, U32.or(A.get(t, k), x))

def put_bridge(+t: A.Tree, +k: U32, +x0: U32, +x1: U32) -> {Bits.write.put(k, (x0, x1), A.build(t)) == A.build(put(t, k, x0, x1)) : Array<U32>}:
  %Equal.sym(Array<U32>, Bits.or.if(U32.is_ne(x0, 0), A.build(t), k, x0), A.build(or_if(U32.is_ne(x0, 0), t, k, x0)), or_bridge(U32.is_ne(x0, 0), t, k, x0)) : {Bits.or.if(U32.is_ne(x1, 0), _, (k + 1 : U32), x1) == A.build(put(t, k, x0, x1)) : Array<U32>}
  or_bridge(U32.is_ne(x1, 0), or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32), x1)

def put_parts_bridge(+t: A.Tree, +k: U32, parts: U32 & U32) -> {Bits.write.put(k, parts, A.build(t)) == A.build(put_parts(t, k, parts)) : Array<U32>}:
  (x0, x1) = parts
  put_bridge(t, k, x0, x1)

def write_at_bridge(+msb: Bool, +s: State, +n: U32, +v: U32) -> {Bits.write.at(msb, build(s), n, v) == build(write_at(msb, s, n, v)) : Bits.Writer}:
  match s:
    case State{+t, +dep, +pos}:
      %Equal.sym(Array<U32>, Bits.write.put((pos >> 5n : U32), Bits.parts(msb, (pos .&. 31 : U32), n, v), A.build(t)), A.build(put_parts(t, (pos >> 5n : U32), Bits.parts(msb, (pos .&. 31 : U32), n, v))), put_parts_bridge(t, (pos >> 5n : U32), Bits.parts(msb, (pos .&. 31 : U32), n, v))) : {Bits.Writer{_, dep, (pos + n : U32)} == build(write_at(msb, State{t, dep, pos}, n, v)) : Bits.Writer}
      {==}

def write_bridge(+msb: Bool, +s: State, +n0: U32, +v: U32) -> {Bits.write(msb, build(s), n0, v) == build(write(msb, s, n0, v)) : Bits.Writer}:
  match s:
    case State{+t, +dep, +pos}:
      +n = U32.min(n0, 32)
      +full = U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((pos + n + 31) >> 5n : U32))
      %Equal.sym(Bits.Writer, Bits.room(full, build(State{t, dep, pos})), build(room(full, State{t, dep, pos})), room_bridge(full, State{t, dep, pos})) : {Bits.write.at(msb, _, n, v) == build(write(msb, State{t, dep, pos}, n0, v)) : Bits.Writer}
      write_at_bridge(msb, room(full, State{t, dep, pos}), n, v)

def put_order_bridge(+msb: Bool, +s: State, +n: U32, +v: U32) -> {Laws.put(msb, build(s), n, v) == build(write(msb, s, n, v)) : Bits.Writer}:
  match msb:
    case False{}:
      write_bridge(False{}, s, n, v)
    case True{}:
      write_bridge(True{}, s, n, v)

def puts_bridge(+fs: List<&2, Laws.F>, +msb: Bool, +s: State) -> {Laws.puts(fs, msb, build(s)) == build(puts(fs, msb, s)) : Bits.Writer}:
  match fs:
    case Nil{}:
      {==}
    case Con{Laws.F{+n, +v}, +t}:
      %Equal.sym(Bits.Writer, Laws.put(msb, build(s), n, v), build(write(msb, s, n, v)), put_order_bridge(msb, s, n, v)) : {Laws.puts(t, msb, _) == build(puts(Con{Laws.F{n, v}, t}, msb, s)) : Bits.Writer}
      puts_bridge(t, msb, write(msb, s, n, v))

def window(msb: Bool, +t: A.Tree, +p: U32) -> U32:
  match msb:
    case False{}:
      +s = (p .&. 31 : U32)
      (U32.shrn(A.get(t, (p >> 5n : U32)), U32.to_nat(s)) .|. U32.shln(A.get(t, ((p >> 5n) + 1 : U32)), U32.to_nat((32 - s : U32))) : U32)
    case True{}:
      +s = (p .&. 31 : U32)
      (U32.shln(Bytes.bswap(A.get(t, (p >> 5n : U32))), U32.to_nat(s)) .|. U32.shrn(Bytes.bswap(A.get(t, ((p >> 5n) + 1 : U32))), U32.to_nat((32 - s : U32))) : U32)

def window_bridge(+msb: Bool, +t: A.Tree, +p: U32) -> {Bits.win(msb, A.build(t), p) == (A.build(t), window(msb, t, p)) : Array<U32> & U32}:
  match msb:
    case False{}:
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), (p >> 5n : U32)), (A.build(t), A.get(t, (p >> 5n : U32))), A.get_bridge(t, (p >> 5n : U32))) : {Bits.win.lsb.at(p, _) == (A.build(t), window(False{}, t, p)) : Array<U32> & U32}
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), ((p >> 5n) + 1 : U32)), (A.build(t), A.get(t, ((p >> 5n) + 1 : U32))), A.get_bridge(t, ((p >> 5n) + 1 : U32))) : {Bits.win.lsb.join((p .&. 31 : U32), A.get(t, (p >> 5n : U32)), _) == (A.build(t), window(False{}, t, p)) : Array<U32> & U32}
      {==}
    case True{}:
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), (p >> 5n : U32)), (A.build(t), A.get(t, (p >> 5n : U32))), A.get_bridge(t, (p >> 5n : U32))) : {Bits.win.msb.at(p, _) == (A.build(t), window(True{}, t, p)) : Array<U32> & U32}
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), ((p >> 5n) + 1 : U32)), (A.build(t), A.get(t, ((p >> 5n) + 1 : U32))), A.get_bridge(t, ((p >> 5n) + 1 : U32))) : {Bits.win.msb.join((p .&. 31 : U32), A.get(t, (p >> 5n : U32)), _) == (A.build(t), window(True{}, t, p)) : Array<U32> & U32}
      {==}

def add_zero_right(x: U32) -> {(x + 0 : U32) == x : U32}:
  match x:
    case U32{+w}:
      Equal.cong(Word(32n), U32, a => U32{a}, Word.add(32n, w, Word.zero(32n)), w, Lemmas.adc_zero(32n, w, False{}))

def add_zero_left(+x: U32) -> {(0 + x : U32) == x : U32}:
  Equal.trans(U32, (0 + x : U32), (x + 0 : U32), x, U32.add_comm(0, x), add_zero_right(x))

def word_sub_zero(n: Nat, w: Word(n)) -> {Word.sub(n, w, Word.zero(n)) == w : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+p:
      match w:
        case WCon{False{}, +t}:
          Equal.cong(Word(p), Word(1n+p), a => WCon{False{}, a}, Word.sub(p, t, Word.zero(p)), t, word_sub_zero(p, t))
        case WCon{True{}, +t}:
          Equal.cong(Word(p), Word(1n+p), a => WCon{True{}, a}, Word.sub(p, t, Word.zero(p)), t, word_sub_zero(p, t))

def sub_zero_right(x: U32) -> {(x - 0 : U32) == x : U32}:
  match x:
    case U32{+w}:
      Equal.cong(Word(32n), U32, a => U32{a}, Word.sub(32n, w, Word.zero(32n)), w, word_sub_zero(32n, w))


def read_value_bridge(+msb: Bool, +t: A.Tree, +len: U32, +pos: U32, +n: U32,
  ok: {U32.is_le(n, U32.min(32, ((len << 3n) - pos : U32))) == True{} : Bool}) ->
  {Laws.read_nat(Bits.read(msb, Bits.Reader{len, A.build(t), pos}, n)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}:
  %Equal.sym(Bool, U32.is_le(n, U32.min(32, ((len << 3n) - pos : U32))), True{}, ok) : {Laws.read_nat(Bits.read.if(_, msb, len, A.build(t), pos, n)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  %Equal.sym(Array<U32> & U32, Bits.win(msb, A.build(t), pos), (A.build(t), window(msb, t, pos)), window_bridge(msb, t, pos)) : {Laws.read_nat(Bits.read.got(msb, len, pos, n, _)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  {==}

def read_order_bridge(+msb: Bool, +t: A.Tree, +len: U32, +pos: U32, +n: U32,
  ok: {U32.is_le(n, U32.min(32, ((len << 3n) - pos : U32))) == True{} : Bool}) ->
  {Laws.read_nat(Laws.get.at(msb, Bits.Reader{len, A.build(t), pos}, n)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}:
  match msb:
    case False{}:
      read_value_bridge(False{}, t, len, pos, n, ok)
    case True{}:
      read_value_bridge(True{}, t, len, pos, n, ok)

def skip_read_bridge(+msb: Bool, +t: A.Tree, +len: U32, +pos: U32, +n: U32,
  skip_ok: {U32.is_le(pos, (len << 3n : U32)) == True{} : Bool},
  read_ok: {U32.is_le(n, U32.min(32, ((len << 3n) - pos : U32))) == True{} : Bool}) ->
  {Laws.read_after_skip(msb, n, Bits.Reader.skip(Bits.Reader{len, A.build(t), 0}, pos)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}:
  %Equal.sym(U32, ((len << 3n) - 0 : U32), (len << 3n : U32), sub_zero_right((len << 3n : U32))) : {Laws.read_after_skip(msb, n, (Bits.Reader{len, A.build(t), Bool.pick(U32, U32.is_le(pos, _), (0 + pos : U32), 0)}, U32.is_le(pos, _))) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  %Equal.sym(Bool, U32.is_le(pos, (len << 3n : U32)), True{}, skip_ok) : {Laws.read_after_skip(msb, n, (Bits.Reader{len, A.build(t), Bool.pick(U32, _, (0 + pos : U32), 0)}, _)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  %Equal.sym(U32, (0 + pos : U32), pos, add_zero_left(pos)) : {Laws.read_nat(Laws.get.at(msb, Bits.Reader{len, A.build(t), _}, n)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  read_order_bridge(msb, t, len, pos, n, read_ok)

def position(s: State) -> U32:
  State{image, dep, pos} = s
  pos

def room_position(+full: Bool, +s: State) -> {position(room(full, s)) == position(s) : U32}:
  match full:
    case False{}:
      {==}
    case True{}:
      match s:
        case State{t, dep, pos}:
          {==}

def write_at_position(+msb: Bool, +s: State, +n: U32, +v: U32) -> {position(write_at(msb, s, n, v)) == (position(s) + n : U32) : U32}:
  match s:
    case State{t, dep, pos}:
      {==}

def write_room_position(+full: Bool, +msb: Bool, +s: State, +n: U32, +v: U32) -> {position(write_at(msb, room(full, s), n, v)) == (position(s) + n : U32) : U32}:
  match full s:
    case False{} State{t, dep, pos}:
      {==}
    case True{} State{t, dep, pos}:
      {==}

def write_position(+msb: Bool, +s: State, +n0: U32, +v: U32) -> {position(write(msb, s, n0, v)) == (position(s) + U32.min(n0, 32) : U32) : U32}:
  match s:
    case State{+t, +dep, +pos}:
      +n = U32.min(n0, 32)
      +full = U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((pos + n + 31) >> 5n : U32))
      write_room_position(full, msb, State{t, dep, pos}, n, v)

def write_position_nat(+msb: Bool, +s: State, +n: U32, +v: U32,
  bound: MNat.lt(Nat.add(U32.to_nat(position(s)), U32.to_nat(U32.min(n, 32))), Lemmas.pow2(32n))) ->
  {U32.to_nat(position(write(msb, s, n, v))) == Nat.add(U32.to_nat(position(s)), U32.to_nat(U32.min(n, 32))) : Nat}:
  Equal.trans(Nat, U32.to_nat(position(write(msb, s, n, v))),
    U32.to_nat((position(s) + U32.min(n, 32) : U32)),
    Nat.add(U32.to_nat(position(s)), U32.to_nat(U32.min(n, 32))),
    Equal.cong(U32, Nat, U32.to_nat, position(write(msb, s, n, v)),
      (position(s) + U32.min(n, 32) : U32), write_position(msb, s, n, v)),
    Lemmas.u32_add_nat(position(s), U32.min(n, 32), bound))

def prefix_step_bound(+p: Nat, +n: Nat, +tail: Nat, +limit: Nat,
  h: MNat.lt(Nat.add(p, Nat.add(n, tail)), limit)) ->
  MNat.lt(Nat.add(p, n), limit):
  MNat.lt_of_le_of_lt(Nat.add(p, n), Nat.add(Nat.add(p, n), tail), limit,
    MNat.le_add_right(Nat.add(p, n), tail),
    Lemmas.lt_rw(Nat.add(Nat.add(p, n), tail), Nat.add(p, Nat.add(n, tail)), limit,
      MNat.add_assoc(p, n, tail), h))


def capacity(depth: Nat) -> Nat:
  Nat.mul(Lemmas.pow2(depth), 32n)

def current_clean(msb: Bool, +offset: U32, word: U32) -> Type:
  match msb:
    case False{}:
      {U32.and(word, U32.not(Bits.mask(offset))) == 0 : U32}
    case True{}:
      {U32.and(Bytes.bswap(word), Bits.mask((32 - offset : U32))) == 0 : U32}

def active_clean(active: Bool, +msb: Bool, +t: A.Tree, +depth: U32, +pos: U32) -> Type:
  match active:
    case False{}:
      Unit
    case True{}:
      A.zero_after(U32.to_nat(depth), t, (pos >> 5n : U32)) &
        current_clean(msb, (pos .&. 31 : U32), A.get(t, (pos >> 5n : U32)))

def valid(+msb: Bool, s: State) -> Type:
  State{+t, +depth, +pos} = s
  A.shape(U32.to_nat(depth), t) & (MNat.lt(U32.to_nat(depth), 28n) &
    (MNat.le(U32.to_nat(pos), capacity(U32.to_nat(depth))) &
    active_clean(Nat.is_lt(U32.to_nat(pos), capacity(U32.to_nat(depth))), msb, t, depth, pos)))

def word_zero_and(+d: Nat, w: Word(d)) -> {Word.and(d, Word.zero(d), w) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{b, +t}:
          Equal.cong(Word(p), Word(1n+p), a => WCon{False{}, a}, Word.and(p, Word.zero(p), t), Word.zero(p), word_zero_and(p, t))

def zero_and(x: U32) -> {U32.and(0, x) == 0 : U32}:
  match x:
    case U32{+w}:
      Equal.cong(Word(32n), U32, a => U32{a}, Word.and(32n, Word.zero(32n), w), Word.zero(32n), word_zero_and(32n, w))

def zero_clean(msb: Bool, offset: U32) -> current_clean(msb, offset, 0):
  match msb:
    case False{}:
      zero_and(U32.not(Bits.mask(offset)))
    case True{}:
      zero_and(Bits.mask((32 - offset : U32)))

def new_valid(msb: Bool) -> valid(msb, new()):
  (Unit{}, ({==}, ({==}, (Unit{}, zero_clean(msb, 0)))))

# Keep arithmetic transport opaque to the checker: https://github.com/bendlang/bend/issues/1071.
def append_position(+old: Nat, +next: Nat, +width: Nat, +tail: Nat,
  e: {next == Nat.add(old, width) : Nat}) ->
  {Nat.add(next, tail) == Nat.add(old, Nat.add(width, tail)) : Nat}:
  Equal.trans(Nat, Nat.add(next, tail), Nat.add(Nat.add(old, width), tail),
    Nat.add(old, Nat.add(width, tail)),
    Equal.cong(Nat, Nat, q => Nat.add(q, tail), next, Nat.add(old, width), e),
    MNat.add_assoc(old, width, tail))

def advance_position_bound(+old: Nat, +next: Nat, +width: Nat, +tail: Nat, +limit: Nat,
  e: {next == Nat.add(old, width) : Nat},
  h: MNat.lt(Nat.add(old, Nat.add(width, tail)), limit)) ->
  MNat.lt(Nat.add(next, tail), limit):
  Lemmas.lt_rw(Nat.add(next, tail), Nat.add(old, Nat.add(width, tail)), limit,
    append_position(old, next, width, tail, e), h)

def finish_position_induction(+old: Nat, +next: Nat, +width: Nat, +tail: Nat, +final: Nat,
  step: {next == Nat.add(old, width) : Nat},
  result: {final == Nat.add(next, tail) : Nat}) ->
  {final == Nat.add(old, Nat.add(width, tail)) : Nat}:
  Equal.trans(Nat, final, Nat.add(next, tail), Nat.add(old, Nat.add(width, tail)),
    result, append_position(old, next, width, tail, step))

def puts_position_bound(+fs: List<&2, Laws.F>, +msb: Bool, +s: State, +limit: Nat,
  +limit_ok: MNat.le(limit, Lemmas.pow2(32n)),
  +bound: MNat.lt(Nat.add(U32.to_nat(position(s)), Laws.prefix_bits(fs)), limit)) ->
  {U32.to_nat(position(puts(fs, msb, s))) == Nat.add(U32.to_nat(position(s)), Laws.prefix_bits(fs)) : Nat}:
  match fs:
    case Nil{}:
      Equal.sym(Nat, Nat.add(U32.to_nat(position(s)), 0n), U32.to_nat(position(s)), MNat.add_zero(U32.to_nat(position(s))))
    case Con{Laws.F{+n, +v}, +tail}:
      +p = U32.to_nat(position(s))
      +width = U32.to_nat(U32.min(n, 32))
      +next = write(msb, s, n, v)
      +step = write_position_nat(msb, s, n, v,
        MNat.lt_of_lt_of_le(Nat.add(p, width), limit, Lemmas.pow2(32n),
          prefix_step_bound(p, width, Laws.prefix_bits(tail), limit, bound), limit_ok))
      finish_position_induction(p, U32.to_nat(position(next)), width, Laws.prefix_bits(tail),
        U32.to_nat(position(puts(tail, msb, next))), step,
        puts_position_bound(tail, msb, next, limit, limit_ok,
          advance_position_bound(p, U32.to_nat(position(next)), width, Laws.prefix_bits(tail), limit, step, bound)))

def puts_position(+fs: List<&2, Laws.F>, +msb: Bool, +s: State,
  bound: MNat.lt(Nat.add(U32.to_nat(position(s)), Laws.prefix_bits(fs)), Lemmas.pow2(32n))) ->
  {U32.to_nat(position(puts(fs, msb, s))) == Nat.add(U32.to_nat(position(s)), Laws.prefix_bits(fs)) : Nat}:
  puts_position_bound(fs, msb, s, Lemmas.pow2(32n), MNat.le_refl(Lemmas.pow2(32n)), bound)
