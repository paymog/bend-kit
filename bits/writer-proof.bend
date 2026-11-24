import Base
import ./bits.bend as Bits
import ./array-proof.bend as A
import ./LAWS.bend as Laws
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./field-proof.bend as Field
import bend-mathlib@0.8.0.0/bool.bend as MBool
import ./position-proof.bend as Position

type State is Data:
  State{image: A.Tree, dep: U32, pos: Nat}

def build(msb: Bool, s: State) -> Bits.Writer:
  State{image, dep, pos} = s
  Bits.Writer{A.build(image), dep, pos, msb}

def new() -> State:
  State{A.Leaf{0}, 0, 0n}

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
  State{put_parts(t, Bits.pos.index(pos), Bits.parts(msb, Bits.pos.offset(pos), n, v)), dep, Nat.add(pos, U32.to_nat(n))}

def write(+msb: Bool, s: State, +n0: U32, +v: U32) -> State:
  State{t, +dep, +pos} = s
  +n = U32.min(n0, 32)
  write_at(msb, room(U32.is_lt(U32.shln(1, U32.to_nat(dep)), Bits.pos.words(Nat.add(pos, U32.to_nat(n)))), State{t, dep, pos}), n, v)

def puts(fs: List<&2, Laws.F>, +msb: Bool, s: State) -> State:
  match fs:
    case Nil{}:
      s
    case Con{Laws.F{n, v}, t}:
      puts(t, msb, write(msb, s, n, v))

def room_bridge(+msb: Bool, +full: Bool, +s: State) -> {Bits.room(full, build(msb, s)) == build(msb, room(full, s)) : Bits.Writer}:
  match full:
    case False{}:
      {==}
    case True{}:
      match s:
        case State{+t, +dep, +pos}:
          %A.grow_bridge(t, U32.to_nat(dep)) : {Bits.Writer{_, (dep + 1 : U32), pos, msb} == build(msb, room(True{}, State{t, dep, pos})) : Bits.Writer}
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

def write_at_bridge(+msb: Bool, +s: State, +n: U32, +v: U32) -> {Bits.write.at(msb, build(msb, s), n, v) == build(msb, write_at(msb, s, n, v)) : Bits.Writer}:
  match s:
    case State{+t, +dep, +pos}:
      %Equal.sym(Array<U32>, Bits.write.put(Bits.pos.index(pos), Bits.parts(msb, Bits.pos.offset(pos), n, v), A.build(t)), A.build(put_parts(t, Bits.pos.index(pos), Bits.parts(msb, Bits.pos.offset(pos), n, v))), put_parts_bridge(t, Bits.pos.index(pos), Bits.parts(msb, Bits.pos.offset(pos), n, v))) : {Bits.Writer{_, dep, Nat.add(pos, U32.to_nat(n)), msb} == build(msb, write_at(msb, State{t, dep, pos}, n, v)) : Bits.Writer}
      {==}

def xor_self(msb: Bool) -> {Bool.xor(msb, msb) == False{} : Bool}:
  match msb:
    case False{}:
      {==}
    case True{}:
      {==}

def write_bridge(+msb: Bool, +s: State, +n0: U32, +v: U32) -> {Bits.write(msb, build(msb, s), n0, v) == build(msb, write(msb, s, n0, v)) : Bits.Writer}:
  match s:
    case State{+t, +dep, +pos}:
      +n = U32.min(n0, 32)
      +full = U32.is_lt(U32.shln(1, U32.to_nat(dep)), Bits.pos.words(Nat.add(pos, U32.to_nat(n))))
      %Equal.sym(Bool, Bool.xor(msb, msb), False{}, xor_self(msb)) : {Bits.write.at(msb, Bits.room(U32.is_lt(U32.shln(1, U32.to_nat(dep)), Bits.pos.words(Nat.add(Bool.pick(Nat, _, Bits.pos.align(pos), pos), U32.to_nat(n)))), Bits.Writer{A.build(t), dep, Bool.pick(Nat, _, Bits.pos.align(pos), pos), msb}), n, v) == build(msb, write(msb, State{t, dep, pos}, n0, v)) : Bits.Writer}
      %Equal.sym(Bits.Writer, Bits.room(full, build(msb, State{t, dep, pos})), build(msb, room(full, State{t, dep, pos})), room_bridge(msb, full, State{t, dep, pos})) : {Bits.write.at(msb, _, n, v) == build(msb, write(msb, State{t, dep, pos}, n0, v)) : Bits.Writer}
      write_at_bridge(msb, room(full, State{t, dep, pos}), n, v)

def put_order_bridge(+msb: Bool, +s: State, +n: U32, +v: U32) -> {Laws.put(msb, build(msb, s), n, v) == build(msb, write(msb, s, n, v)) : Bits.Writer}:
  match msb:
    case False{}:
      write_bridge(False{}, s, n, v)
    case True{}:
      write_bridge(True{}, s, n, v)

def puts_bridge(+fs: List<&2, Laws.F>, +msb: Bool, +s: State) -> {Laws.puts(fs, msb, build(msb, s)) == build(msb, puts(fs, msb, s)) : Bits.Writer}:
  match fs:
    case Nil{}:
      {==}
    case Con{Laws.F{+n, +v}, +t}:
      %Equal.sym(Bits.Writer, Laws.put(msb, build(msb, s), n, v), build(msb, write(msb, s, n, v)), put_order_bridge(msb, s, n, v)) : {Laws.puts(t, msb, _) == build(msb, puts(Con{Laws.F{n, v}, t}, msb, s)) : Bits.Writer}
      puts_bridge(t, msb, write(msb, s, n, v))

def initial_room_order(full: Bool, +n: U32, +v: U32) ->
  {Bits.write.at(True{}, Bits.room(full, Bits.Writer.new()), n, v) ==
    Bits.write.at(True{}, Bits.room(full, build(True{}, new())), n, v) : Bits.Writer}:
  match full:
    case False{}:
      {==}
    case True{}:
      {==}

def initial_write_bridge(msb: Bool, +n: U32, +v: U32) ->
  {Laws.put(msb, Bits.Writer.new(), n, v) == build(msb, write(msb, new(), n, v)) : Bits.Writer}:
  match msb:
    case False{}:
      put_order_bridge(False{}, new(), n, v)
    case True{}:
      Equal.trans(Bits.Writer,
        Laws.put(True{}, Bits.Writer.new(), n, v),
        Laws.put(True{}, build(True{}, new()), n, v),
        build(True{}, write(True{}, new(), n, v)),
        initial_room_order(U32.is_lt(1, Bits.pos.words(Nat.add(0n, U32.to_nat(U32.min(n, 32))))), U32.min(n, 32), v),
        put_order_bridge(True{}, new(), n, v))

def prefix_bridge(+fs: List<&2, Laws.F>, +msb: Bool) ->
  {Bits.Writer.finish(Laws.puts(fs, msb, Bits.Writer.new())) ==
    Bits.Writer.finish(build(msb, puts(fs, msb, new()))) : Bytes.Bytes}:
  match fs:
    case Nil{}:
      {==}
    case Con{Laws.F{+n, +v}, +tail}:
      %Equal.sym(Bits.Writer, Laws.put(msb, Bits.Writer.new(), n, v),
        build(msb, write(msb, new(), n, v)), initial_write_bridge(msb, n, v)) :
        {Bits.Writer.finish(Laws.puts(tail, msb, _)) ==
          Bits.Writer.finish(build(msb, puts(Con{Laws.F{n, v}, tail}, msb, new()))) : Bytes.Bytes}
      Equal.cong(Bits.Writer, Bytes.Bytes, Bits.Writer.finish,
        Laws.puts(tail, msb, build(msb, write(msb, new(), n, v))),
        build(msb, puts(tail, msb, write(msb, new(), n, v))),
        puts_bridge(tail, msb, write(msb, new(), n, v)))

def window(msb: Bool, +t: A.Tree, +p: Nat) -> U32:
  match msb:
    case False{}:
      +s = Bits.pos.offset(p)
      (U32.shrn(A.get(t, Bits.pos.index(p)), U32.to_nat(s)) .|. U32.shln(A.get(t, (Bits.pos.index(p) + 1 : U32)), U32.to_nat((32 - s : U32))) : U32)
    case True{}:
      +s = Bits.pos.offset(p)
      (U32.shln(Bytes.bswap(A.get(t, Bits.pos.index(p))), U32.to_nat(s)) .|. U32.shrn(Bytes.bswap(A.get(t, (Bits.pos.index(p) + 1 : U32))), U32.to_nat((32 - s : U32))) : U32)

def window_bridge(+msb: Bool, +t: A.Tree, +p: Nat) -> {Bits.win(msb, A.build(t), p) == (A.build(t), window(msb, t, p)) : Array<U32> & U32}:
  match msb:
    case False{}:
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), Bits.pos.index(p)), (A.build(t), A.get(t, Bits.pos.index(p))), A.get_bridge(t, Bits.pos.index(p))) : {Bits.win.lsb.at(Bits.pos.index(p), Bits.pos.offset(p), _) == (A.build(t), window(False{}, t, p)) : Array<U32> & U32}
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), (Bits.pos.index(p) + 1 : U32)), (A.build(t), A.get(t, (Bits.pos.index(p) + 1 : U32))), A.get_bridge(t, (Bits.pos.index(p) + 1 : U32))) : {Bits.win.lsb.join(Bits.pos.offset(p), A.get(t, Bits.pos.index(p)), _) == (A.build(t), window(False{}, t, p)) : Array<U32> & U32}
      {==}
    case True{}:
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), Bits.pos.index(p)), (A.build(t), A.get(t, Bits.pos.index(p))), A.get_bridge(t, Bits.pos.index(p))) : {Bits.win.msb.at(Bits.pos.index(p), Bits.pos.offset(p), _) == (A.build(t), window(True{}, t, p)) : Array<U32> & U32}
      %Equal.sym(Array<U32> & U32, Array.get(U32, A.build(t), (Bits.pos.index(p) + 1 : U32)), (A.build(t), A.get(t, (Bits.pos.index(p) + 1 : U32))), A.get_bridge(t, (Bits.pos.index(p) + 1 : U32))) : {Bits.win.msb.join(Bits.pos.offset(p), A.get(t, Bits.pos.index(p)), _) == (A.build(t), window(True{}, t, p)) : Array<U32> & U32}
      {==}

def read_value_bridge(+msb: Bool, +t: A.Tree, +len: U32, +pos: Nat, +n: U32,
  pos_ok: MNat.le(pos, Nat.mul(U32.to_nat(len), 8n)),
  ok: {Nat.is_le(U32.to_nat(n), Nat.min(32n, Nat.sub(Nat.mul(U32.to_nat(len), 8n), pos))) == True{} : Bool}) ->
  {Laws.read_nat(Bits.read(msb, Bits.Reader.at(len, A.build(t), pos), n)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}:
  +total = Nat.mul(U32.to_nat(len), 8n)
  +left = Nat.sub(total, pos)
  %Equal.sym(Bool, Nat.is_le(U32.to_nat(n), Nat.min(32n, left)), True{}, ok) :
    {Laws.read_nat(Bits.read.if(_, msb, A.build(t), total, left, n, left, None{})) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  %Equal.sym(Nat, Nat.sub(total, left), pos, MNat.sub_sub_self(total, pos, pos_ok)) :
    {Laws.read_nat(Bits.read.got(msb, total, left, n, Bits.win(msb, A.build(t), _))) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  %Equal.sym(Array<U32> & U32, Bits.win(msb, A.build(t), pos), (A.build(t), window(msb, t, pos)), window_bridge(msb, t, pos)) :
    {Laws.read_nat(Bits.read.got(msb, total, left, n, _)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  {==}

def read_order_bridge(+msb: Bool, +t: A.Tree, +len: U32, +pos: Nat, +n: U32,
  pos_ok: MNat.le(pos, Nat.mul(U32.to_nat(len), 8n)),
  ok: {Nat.is_le(U32.to_nat(n), Nat.min(32n, Nat.sub(Nat.mul(U32.to_nat(len), 8n), pos))) == True{} : Bool}) ->
  {Laws.read_nat(Laws.get.at(msb, Bits.Reader.at(len, A.build(t), pos), n)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}:
  match msb:
    case False{}:
      read_value_bridge(False{}, t, len, pos, n, pos_ok, ok)
    case True{}:
      read_value_bridge(True{}, t, len, pos, n, pos_ok, ok)

def skip_read_bridge(+msb: Bool, +t: A.Tree, +len: U32, +pos: Nat, +n: U32,
  +skip_ok: {Nat.is_le(pos, Nat.mul(U32.to_nat(len), 8n)) == True{} : Bool},
  read_ok: {Nat.is_le(U32.to_nat(n), Nat.min(32n, Nat.sub(Nat.mul(U32.to_nat(len), 8n), pos))) == True{} : Bool}) ->
  {Laws.read_after_skip(msb, n, Bits.Reader.skip(Bits.Reader.new(Bytes.Bytes{len, A.build(t)}), pos)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}:
  +total = Nat.mul(U32.to_nat(len), 8n)
  %Equal.sym(Bool, Nat.is_le(pos, total), True{}, skip_ok) :
    {Laws.read_after_skip(msb, n, (Bits.Reader{A.build(t), total, Bool.pick(Nat, _, Nat.sub(total, pos), total), None{}}, _)) == Some{U32.to_nat(Bits.field(msb, n, window(msb, t, pos)))} : Maybe<&2, Nat>}
  read_order_bridge(msb, t, len, pos, n, skip_ok, read_ok)

def position(s: State) -> Nat:
  State{image, dep, pos} = s
  pos

def room_position(+full: Bool, +s: State) -> {position(room(full, s)) == position(s) : Nat}:
  match full:
    case False{}:
      {==}
    case True{}:
      match s:
        case State{t, dep, pos}:
          {==}

def write_at_position(+msb: Bool, +s: State, +n: U32, +v: U32) -> {position(write_at(msb, s, n, v)) == Nat.add(position(s), U32.to_nat(n)) : Nat}:
  match s:
    case State{t, dep, pos}:
      {==}

def write_room_position(+full: Bool, +msb: Bool, +s: State, +n: U32, +v: U32) -> {position(write_at(msb, room(full, s), n, v)) == Nat.add(position(s), U32.to_nat(n)) : Nat}:
  match full s:
    case False{} State{t, dep, pos}:
      {==}
    case True{} State{t, dep, pos}:
      {==}

def write_position_nat(+msb: Bool, +s: State, +n0: U32, +v: U32) -> {position(write(msb, s, n0, v)) == Nat.add(position(s), U32.to_nat(U32.min(n0, 32))) : Nat}:
  match s:
    case State{+t, +dep, +pos}:
      +n = U32.min(n0, 32)
      +full = U32.is_lt(U32.shln(1, U32.to_nat(dep)), Bits.pos.words(Nat.add(pos, U32.to_nat(n))))
      write_room_position(full, msb, State{t, dep, pos}, n, v)

def capacity(depth: Nat) -> Nat:
  Nat.mul(Lemmas.pow2(depth), 32n)

def current_clean(msb: Bool, +offset: U32, word: U32) -> Type:
  match msb:
    case False{}:
      {U32.and(word, U32.not(Bits.mask(offset))) == 0 : U32}
    case True{}:
      {U32.and(Bytes.bswap(word), Bits.mask((32 - offset : U32))) == 0 : U32}

def active_clean(active: Bool, +msb: Bool, +t: A.Tree, +depth: U32, +pos: Nat) -> Type:
  match active:
    case False{}:
      Unit
    case True{}:
      A.zero_after(U32.to_nat(depth), t, Bits.pos.index(pos)) &
        current_clean(msb, Bits.pos.offset(pos), A.get(t, Bits.pos.index(pos)))

def valid(+msb: Bool, s: State) -> Type:
  State{+t, +depth, +pos} = s
  A.shape(U32.to_nat(depth), t) & (MNat.lt(U32.to_nat(depth), 31n) &
    (MNat.le(pos, capacity(U32.to_nat(depth))) &
    active_clean(Nat.is_lt(pos, capacity(U32.to_nat(depth))), msb, t, depth, pos)))

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

def finish_position_induction(+old: Nat, +next: Nat, +width: Nat, +tail: Nat, +final: Nat,
  step: {next == Nat.add(old, width) : Nat},
  result: {final == Nat.add(next, tail) : Nat}) ->
  {final == Nat.add(old, Nat.add(width, tail)) : Nat}:
  Equal.trans(Nat, final, Nat.add(next, tail), Nat.add(old, Nat.add(width, tail)),
    result, append_position(old, next, width, tail, step))

def puts_position(+fs: List<&2, Laws.F>, +msb: Bool, +s: State) ->
  {position(puts(fs, msb, s)) == Nat.add(position(s), Laws.prefix_bits(fs)) : Nat}:
  match fs:
    case Nil{}:
      Equal.sym(Nat, Nat.add(position(s), 0n), position(s), MNat.add_zero(position(s)))
    case Con{Laws.F{+n, +v}, +tail}:
      +p = position(s)
      +width = U32.to_nat(U32.min(n, 32))
      +next = write(msb, s, n, v)
      finish_position_induction(p, position(next), width, Laws.prefix_bits(tail),
        position(puts(tail, msb, next)), write_position_nat(msb, s, n, v),
        puts_position(tail, msb, next))

def skipped_or_zero(+x: U32, h: {U32.is_ne(x, 0) == False{} : Bool}) -> {x == 0 : U32}:
  Lemmas.u32_to_nat_inj(x, 0,
    MNat.eq_of_is_eq(U32.to_nat(x), 0n,
      Equal.trans(Bool, Nat.is_eq(U32.to_nat(x), 0n), U32.is_eq(x, 0), True{},
        Equal.sym(Bool, U32.is_eq(x, 0), Nat.is_eq(U32.to_nat(x), 0n), Lemmas.u32_is_eq_nat(x, 0)),
        MBool.not_inj(U32.is_eq(x, 0), True{}, h))))

def or_zero(+x: U32) -> {U32.or(x, 0) == x : U32}:
  Equal.trans(U32, U32.or(x, 0), U32.or(0, x), x,
    Field.u32_or_comm(x, 0), Field.u32_zero_or(x))

def or_set_if(+some: Bool, +t: A.Tree, +k: U32, +x: U32,
  h: {U32.is_ne(x, 0) == some : Bool}) ->
  {or_if(some, t, k, x) == A.set(t, k, U32.or(A.get(t, k), x)) : A.Tree}:
  match some:
    case False{}:
      %Equal.sym(U32, x, 0, skipped_or_zero(x, h)) :
        {t == A.set(t, k, U32.or(A.get(t, k), _)) : A.Tree}
      %Equal.sym(U32, U32.or(A.get(t, k), 0), A.get(t, k), or_zero(A.get(t, k))) :
        {t == A.set(t, k, _) : A.Tree}
      Equal.sym(A.Tree, A.set(t, k, A.get(t, k)), t, A.set_current(t, k))
    case True{}:
      {==}

def or_set(+t: A.Tree, +k: U32, +x: U32) ->
  {or_if(U32.is_ne(x, 0), t, k, x) == A.set(t, k, U32.or(A.get(t, k), x)) : A.Tree}:
  or_set_if(U32.is_ne(x, 0), t, k, x, {==})

def or_read(+t: A.Tree, +k: U32, +x: U32) ->
  {A.get(or_if(U32.is_ne(x, 0), t, k, x), k) == U32.or(A.get(t, k), x) : U32}:
  Equal.trans(U32, A.get(or_if(U32.is_ne(x, 0), t, k, x), k),
    A.get(A.set(t, k, U32.or(A.get(t, k), x)), k), U32.or(A.get(t, k), x),
    Equal.cong(A.Tree, U32, a => A.get(a, k),
      or_if(U32.is_ne(x, 0), t, k, x), A.set(t, k, U32.or(A.get(t, k), x)), or_set(t, k, x)),
    A.get_set(t, k, U32.or(A.get(t, k), x)))

def or_frame(+depth: Nat, +t: A.Tree, +i: U32, +j: U32, +x: U32,
  sh: A.shape(depth, t), hd: MNat.lt(depth, 32n),
  hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)),
  hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)),
  ne: {U32.is_eq(i, j) == False{} : Bool}) ->
  {A.get(or_if(U32.is_ne(x, 0), t, i, x), j) == A.get(t, j) : U32}:
  Equal.trans(U32, A.get(or_if(U32.is_ne(x, 0), t, i, x), j),
    A.get(A.set(t, i, U32.or(A.get(t, i), x)), j), A.get(t, j),
    Equal.cong(A.Tree, U32, a => A.get(a, j),
      or_if(U32.is_ne(x, 0), t, i, x), A.set(t, i, U32.or(A.get(t, i), x)), or_set(t, i, x)),
    A.frame(depth, t, i, j, U32.or(A.get(t, i), x), sh, hd, hi, hj, ne))

def put_read_low(+depth: Nat, +t: A.Tree, +k: U32, +x0: U32, +x1: U32,
  sh: A.shape(depth, t), hd: MNat.lt(depth, 32n),
  hi: MNat.lt(U32.to_nat(k), Lemmas.pow2(depth)),
  hj: MNat.lt(U32.to_nat((k + 1 : U32)), Lemmas.pow2(depth)),
  ne: {U32.is_eq((k + 1 : U32), k) == False{} : Bool}) ->
  {A.get(put(t, k, x0, x1), k) == U32.or(A.get(t, k), x0) : U32}:
  Equal.trans(U32, A.get(put(t, k, x0, x1), k),
    A.get(or_if(U32.is_ne(x0, 0), t, k, x0), k), U32.or(A.get(t, k), x0),
    or_frame(depth, or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32), k, x1,
      or_shape(depth, U32.is_ne(x0, 0), t, k, x0, sh), hd, hj, hi, ne),
    or_read(t, k, x0))

def put_read_high(+depth: Nat, +t: A.Tree, +k: U32, +x0: U32, +x1: U32,
  sh: A.shape(depth, t), hd: MNat.lt(depth, 32n),
  hi: MNat.lt(U32.to_nat(k), Lemmas.pow2(depth)),
  hj: MNat.lt(U32.to_nat((k + 1 : U32)), Lemmas.pow2(depth)),
  ne: {U32.is_eq(k, (k + 1 : U32)) == False{} : Bool}) ->
  {A.get(put(t, k, x0, x1), (k + 1 : U32)) == U32.or(A.get(t, (k + 1 : U32)), x1) : U32}:
  Equal.trans(U32, A.get(put(t, k, x0, x1), (k + 1 : U32)),
    U32.or(A.get(or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32)), x1),
    U32.or(A.get(t, (k + 1 : U32)), x1),
    or_read(or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32), x1),
    Equal.cong(U32, U32, q => U32.or(q, x1),
      A.get(or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32)), A.get(t, (k + 1 : U32)),
      or_frame(depth, t, k, (k + 1 : U32), x0, sh, hd, hi, hj, ne)))

def put_zero_after_next(+depth: Nat, +t: A.Tree, +k: U32, +x0: U32, +x1: U32,
  sh: A.shape(depth, t), h: A.zero_after(depth, t, k),
  +hd: MNat.lt(depth, 32n),
  +hi: MNat.lt(U32.to_nat(k), Lemmas.pow2(depth)),
  hj: MNat.lt(U32.to_nat((k + 1 : U32)), Lemmas.pow2(depth))) ->
  A.zero_after(depth, put(t, k, x0, x1), (k + 1 : U32)):
  or_zero_after(depth, U32.is_ne(x1, 0), or_if(U32.is_ne(x0, 0), t, k, x0), (k + 1 : U32), x1,
    A.zero_after_next(depth, or_if(U32.is_ne(x0, 0), t, k, x0), k,
      or_shape(depth, U32.is_ne(x0, 0), t, k, x0, sh),
      or_zero_after(depth, U32.is_ne(x0, 0), t, k, x0, h), hd, hi, hj))

def join(msb: Bool, s: U32, lo: U32, hi: U32) -> U32:
  match msb:
    case False{}:
      Field.lsb_join(s, lo, hi)
    case True{}:
      Field.msb_join(s, lo, hi)

def window_join(+msb: Bool, +t: A.Tree, +p: Nat) ->
  {window(msb, t, p) == join(msb, Bits.pos.offset(p),
    A.get(t, Bits.pos.index(p)), A.get(t, (Bits.pos.index(p) + 1 : U32))) : U32}:
  match msb:
    case False{}:
      {==}
    case True{}:
      {==}

# Compose scalar observations before specializing words: https://github.com/bendlang/bend/issues/1071.
def field_observation(+msb: Bool, +s: U32, +n: U32, +lo: U32, +hi: U32,
  +old: U32, +x0: U32, +x1: U32,
  elo: {lo == U32.or(old, x0) : U32}, ehi: {hi == U32.or(0, x1) : U32}) ->
  {Bits.field(msb, n, join(msb, s, lo, hi)) ==
    Bits.field(msb, n, join(msb, s, U32.or(old, x0), x1)) : U32}:
  %Equal.sym(U32, lo, U32.or(old, x0), elo) :
    {Bits.field(msb, n, join(msb, s, _, hi)) ==
      Bits.field(msb, n, join(msb, s, U32.or(old, x0), x1)) : U32}
  %Equal.sym(U32, hi, U32.or(0, x1), ehi) :
    {Bits.field(msb, n, join(msb, s, U32.or(old, x0), _)) ==
      Bits.field(msb, n, join(msb, s, U32.or(old, x0), x1)) : U32}
  Equal.cong(U32, U32, q => Bits.field(msb, n, join(msb, s, U32.or(old, x0), q)),
    U32.or(0, x1), x1, Field.u32_zero_or(x1))

def put_field_observation(+depth: Nat, +t: A.Tree, +k: U32, +x0: U32, +x1: U32,
  +msb: Bool, +s: U32, +n: U32,
  shapes: A.shape(depth, t) & A.shape(depth, t),
  +hd: MNat.lt(depth, 32n),
  +hi: MNat.lt(U32.to_nat(k), Lemmas.pow2(depth)),
  +hj: MNat.lt(U32.to_nat((k + 1 : U32)), Lemmas.pow2(depth)),
  ne0: {U32.is_eq((k + 1 : U32), k) == False{} : Bool},
  ne1: {U32.is_eq(k, (k + 1 : U32)) == False{} : Bool},
  zero: {A.get(t, (k + 1 : U32)) == 0 : U32}) ->
  {Bits.field(msb, n, join(msb, s, A.get(put(t, k, x0, x1), k),
    A.get(put(t, k, x0, x1), (k + 1 : U32)))) ==
    Bits.field(msb, n, join(msb, s, U32.or(A.get(t, k), x0), x1)) : U32}:
  (sh0, sh1) = shapes
  field_observation(msb, s, n, A.get(put(t, k, x0, x1), k),
    A.get(put(t, k, x0, x1), (k + 1 : U32)), A.get(t, k), x0, x1,
    put_read_low(depth, t, k, x0, x1, sh0, hd, hi, hj, ne0),
    Equal.trans(U32, A.get(put(t, k, x0, x1), (k + 1 : U32)),
      U32.or(A.get(t, (k + 1 : U32)), x1), U32.or(0, x1),
      put_read_high(depth, t, k, x0, x1, sh1, hd, hi, hj, ne1),
      Equal.cong(U32, U32, q => U32.or(q, x1), A.get(t, (k + 1 : U32)), 0, zero)))

def scalar_parts(+msb: Bool, s: U32, +n: U32, lo: U32, parts: U32 & U32) -> U32:
  (x0, x1) = parts
  Bits.field(msb, n, join(msb, s, U32.or(lo, x0), x1))

def scalar(+msb: Bool, +s: U32, +n: U32, v: U32, lo: U32) -> U32:
  scalar_parts(msb, s, n, lo, Bits.parts(msb, s, n, v))

def put_parts_observation(+depth: Nat, +t: A.Tree, +k: U32, parts: U32 & U32,
  +msb: Bool, +s: U32, +n: U32,
  shapes: A.shape(depth, t) & A.shape(depth, t),
  +hd: MNat.lt(depth, 32n),
  +hi: MNat.lt(U32.to_nat(k), Lemmas.pow2(depth)),
  +hj: MNat.lt(U32.to_nat((k + 1 : U32)), Lemmas.pow2(depth)),
  ne0: {U32.is_eq((k + 1 : U32), k) == False{} : Bool},
  ne1: {U32.is_eq(k, (k + 1 : U32)) == False{} : Bool},
  zero: {A.get(t, (k + 1 : U32)) == 0 : U32}) ->
  {Bits.field(msb, n, join(msb, s, A.get(put_parts(t, k, parts), k),
    A.get(put_parts(t, k, parts), (k + 1 : U32)))) ==
    scalar_parts(msb, s, n, A.get(t, k), parts) : U32}:
  match parts:
    case (x0, x1):
      put_field_observation(depth, t, k, x0, x1, msb, s, n, shapes, hd, hi, hj, ne0, ne1, zero)

def scalar_roundtrip(+msb: Bool, +s: U32, +n: U32, +v: U32, +lo: U32,
  hs: MNat.le(U32.to_nat(s), 31n), hn: MNat.le(U32.to_nat(n), 32n),
  clean: current_clean(msb, s, lo)) ->
  {U32.to_nat(scalar(msb, s, n, v, lo)) ==
    Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  match msb:
    case False{}:
      Field.lsb_roundtrip(s, n, v, lo, hs, hn, clean)
    case True{}:
      Field.msb_roundtrip(s, n, v, lo, hs, hn, clean)

def written_field(+depth: Nat, +t: A.Tree, +p: Nat, +msb: Bool, +n: U32, +v: U32,
  sh: A.shape(depth, t), +hd: MNat.lt(depth, 32n),
  +hi: MNat.lt(U32.to_nat(Bits.pos.index(p)), Lemmas.pow2(depth)),
  +hj: MNat.lt(U32.to_nat((Bits.pos.index(p) + 1 : U32)), Lemmas.pow2(depth)),
  ne0: {U32.is_eq((Bits.pos.index(p) + 1 : U32), Bits.pos.index(p)) == False{} : Bool},
  ne1: {U32.is_eq(Bits.pos.index(p), (Bits.pos.index(p) + 1 : U32)) == False{} : Bool},
  zero: {A.get(t, (Bits.pos.index(p) + 1 : U32)) == 0 : U32},
  hs: MNat.le(U32.to_nat(Bits.pos.offset(p)), 31n),
  hn: MNat.le(U32.to_nat(n), 32n),
  clean: current_clean(msb, Bits.pos.offset(p), A.get(t, Bits.pos.index(p)))) ->
  {U32.to_nat(Bits.field(msb, n,
    window(msb, put_parts(t, Bits.pos.index(p), Bits.parts(msb, Bits.pos.offset(p), n, v)), p))) ==
    Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  +out = put_parts(t, Bits.pos.index(p), Bits.parts(msb, Bits.pos.offset(p), n, v))
  %Equal.sym(U32, window(msb, out, p),
    join(msb, Bits.pos.offset(p), A.get(out, Bits.pos.index(p)), A.get(out, (Bits.pos.index(p) + 1 : U32))),
    window_join(msb, out, p)) :
    {U32.to_nat(Bits.field(msb, n, _)) == Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}
  Equal.trans(Nat,
    U32.to_nat(Bits.field(msb, n, join(msb, Bits.pos.offset(p),
      A.get(out, Bits.pos.index(p)), A.get(out, (Bits.pos.index(p) + 1 : U32))))),
    U32.to_nat(scalar(msb, Bits.pos.offset(p), n, v, A.get(t, Bits.pos.index(p)))),
    Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))),
    Equal.cong(U32, Nat, U32.to_nat,
      Bits.field(msb, n, join(msb, Bits.pos.offset(p),
        A.get(out, Bits.pos.index(p)), A.get(out, (Bits.pos.index(p) + 1 : U32)))),
      scalar(msb, Bits.pos.offset(p), n, v, A.get(t, Bits.pos.index(p))),
      put_parts_observation(depth, t, Bits.pos.index(p), Bits.parts(msb, Bits.pos.offset(p), n, v),
        msb, Bits.pos.offset(p), n, A.shape_copy(depth, t, sh), hd, hi, hj, ne0, ne1, zero)),
    scalar_roundtrip(msb, Bits.pos.offset(p), n, v, A.get(t, Bits.pos.index(p)), hs, hn, clean))

def finished_read_guarded(+msb: Bool, +t: A.Tree, +p: Nat, +n: U32, +end: Nat, +value: Nat,
  field: {U32.to_nat(Bits.field(msb, n, window(msb, t, p))) == value : Nat},
  guards: {Nat.is_le(p, Position.finish_bits(end)) == True{} : Bool} &
    {Nat.is_le(U32.to_nat(n), Nat.min(32n, Nat.sub(Position.finish_bits(end), p))) == True{} : Bool}) ->
  {Laws.read_after_skip(msb, n,
    Bits.Reader.skip(Bits.Reader.new(Bytes.Bytes{Position.finish_bytes(end), A.build(t)}), p)) ==
    Some{value} : Maybe<&2, Nat>}:
  (skip_ok, read_ok) = guards
  Equal.trans(Maybe<&2, Nat>,
    Laws.read_after_skip(msb, n,
      Bits.Reader.skip(Bits.Reader.new(Bytes.Bytes{Position.finish_bytes(end), A.build(t)}), p)),
    Some{U32.to_nat(Bits.field(msb, n, window(msb, t, p)))}, Some{value},
    skip_read_bridge(msb, t, Position.finish_bytes(end), p, n, skip_ok, read_ok),
    Equal.cong(Nat, Maybe<&2, Nat>, q => Some{q},
      U32.to_nat(Bits.field(msb, n, window(msb, t, p))), value, field))

def finished_read(+msb: Bool, +t: A.Tree, +p: Nat, +n: U32, +end: Nat, +value: Nat,
  step: {end == Nat.add(p, U32.to_nat(n)) : Nat},
  room: MNat.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), Lemmas.pow2(35n)),
  width: MNat.le(U32.to_nat(n), 32n),
  field: {U32.to_nat(Bits.field(msb, n, window(msb, t, p))) == value : Nat}) ->
  {Laws.read_after_skip(msb, n,
    Bits.Reader.skip(Bits.Reader.new(Bytes.Bytes{Position.finish_bytes(end), A.build(t)}), p)) ==
    Some{value} : Maybe<&2, Nat>}:
  finished_read_guarded(msb, t, p, n, end, value, field,
    Position.finish_guards(p, n, end, step, room, width))

def low_full(+d: Nat, +extra: Nat, w: Word(d)) ->
  {Field.low(d, Nat.add(d, extra), w) == w : Word(d)}:
  match d w:
    case 0n WNil{}:
      {==}
    case 1n++p WCon{+b, +tail}:
      Equal.cong(Word(p), Word(1n+p), q => WCon{b, q},
        Field.low(p, Nat.add(p, extra), tail), tail, low_full(p, extra, tail))

def low_full_bound(+d: Nat, +k: Nat, +w: Word(d), h: MNat.le(d, k)) ->
  {Field.low(d, k, w) == w : Word(d)}:
  %MNat.add_sub_of_le(d, k, h) : {Field.low(d, _, w) == w : Word(d)}
  low_full(d, Nat.sub(k, d), w)

def word_zero_value(+v: U32, h: {Field.word(v) == Word.zero(32n) : Word(32n)}) ->
  {v == 0 : U32}:
  match v:
    case U32{w}:
      Equal.cong(Word(32n), U32, q => U32{q}, w, Word.zero(32n), h)

def lsb_no_spill(+s: U32, +n: U32, +v: U32,
  h: MNat.le(U32.to_nat(n), U32.to_nat((32 - s : U32)))) ->
  {Field.written_hi(False{}, s, n, v) == 0 : U32}:
  word_zero_value(Field.written_hi(False{}, s, n, v),
    Equal.sym(Word(32n), Word.zero(32n), Field.word(Field.written_hi(False{}, s, n, v)),
      (%MNat.sub_eq_zero_of_le(U32.to_nat(n), U32.to_nat((32 - s : U32)), h) :
        {Field.low(32n, _, Field.word(Field.written_hi(False{}, s, n, v))) ==
          Field.word(Field.written_hi(False{}, s, n, v)) : Word(32n)}
       Field.lsb_hi_suffix(s, n, v))))

def spill_zero_bound(+gap: Nat, +n: Nat, hn: MNat.le(n, 32n), h: MNat.le(n, gap)) ->
  MNat.le(32n, Nat.add(gap, Nat.sub(32n, n))):
  %MNat.add_sub_of_le(n, 32n, hn) : MNat.le(_, Nat.add(gap, Nat.sub(32n, n)))
  MNat.add_le_add_right(n, gap, Nat.sub(32n, n), h)

def msb_no_spill(+s: U32, +n: U32, +v: U32,
  +hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(U32.to_nat(n), U32.to_nat((32 - s : U32)))) ->
  {Field.written_hi(True{}, s, n, v) == 0 : U32}:
  +part = Field.written_hi(True{}, s, n, v)
  +k = Nat.add(U32.to_nat((32 - s : U32)), U32.to_nat((32 - n : U32)))
  bound : MNat.le(32n, k) = (%Equal.sym(Nat, U32.to_nat((32 - n : U32)), Nat.sub(32n, U32.to_nat(n)),
    Lemmas.u32_sub_nat(32, n, hn)) :
    MNat.le(32n, Nat.add(U32.to_nat((32 - s : U32)), _))
    spill_zero_bound(U32.to_nat((32 - s : U32)), U32.to_nat(n), hn, h))
  e = word_zero_value(Bytes.bswap(part),
    Equal.trans(Word(32n), Field.word(Bytes.bswap(part)),
      Field.low(32n, k, Field.word(Bytes.bswap(part))), Word.zero(32n),
      Equal.sym(Word(32n), Field.low(32n, k, Field.word(Bytes.bswap(part))),
        Field.word(Bytes.bswap(part)), low_full_bound(32n, k, Field.word(Bytes.bswap(part)), bound)),
      Field.msb_hi_suffix(s, n, v)))
  Equal.trans(U32, part, Bytes.bswap(Bytes.bswap(part)), 0,
    Equal.sym(U32, Bytes.bswap(Bytes.bswap(part)), part, Field.bswap_invol(part)),
    Equal.cong(U32, U32, q => Bytes.bswap(q), Bytes.bswap(part), 0, e))

def no_spill(+msb: Bool, +s: U32, +n: U32, +v: U32,
  hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(U32.to_nat(n), U32.to_nat((32 - s : U32)))) ->
  {Field.written_hi(msb, s, n, v) == 0 : U32}:
  match msb:
    case False{}:
      lsb_no_spill(s, n, v, h)
    case True{}:
      msb_no_spill(s, n, v, hn, h)

def put_no_spill(+t: A.Tree, +k: U32, +x0: U32, +x1: U32,
  e: {x1 == 0 : U32}) ->
  {put(t, k, x0, x1) == or_if(U32.is_ne(x0, 0), t, k, x0) : A.Tree}:
  %Equal.sym(U32, x1, 0, e) :
    {put(t, k, x0, _) == or_if(U32.is_ne(x0, 0), t, k, x0) : A.Tree}
  {==}

def put_parts_no_spill(+t: A.Tree, +k: U32, parts: U32 & U32,
  e: {Field.second(parts) == 0 : U32}) ->
  {put_parts(t, k, parts) ==
    or_if(U32.is_ne(Field.first(parts), 0), t, k, Field.first(parts)) : A.Tree}:
  match parts:
    case (x0, x1):
      put_no_spill(t, k, x0, x1, e)

def put_parts_noncross_read(+t: A.Tree, +k: U32, +msb: Bool, +s: U32, +n: U32, +v: U32,
  hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(U32.to_nat(n), U32.to_nat((32 - s : U32)))) ->
  {A.get(put_parts(t, k, Bits.parts(msb, s, n, v)), k) ==
    Field.written_lo(msb, s, n, v, A.get(t, k)) : U32}:
  Equal.trans(U32, A.get(put_parts(t, k, Bits.parts(msb, s, n, v)), k),
    A.get(or_if(U32.is_ne(Field.first(Bits.parts(msb, s, n, v)), 0), t, k,
      Field.first(Bits.parts(msb, s, n, v))), k),
    Field.written_lo(msb, s, n, v, A.get(t, k)),
    Equal.cong(A.Tree, U32, q => A.get(q, k),
      put_parts(t, k, Bits.parts(msb, s, n, v)),
      or_if(U32.is_ne(Field.first(Bits.parts(msb, s, n, v)), 0), t, k,
        Field.first(Bits.parts(msb, s, n, v))),
      put_parts_no_spill(t, k, Bits.parts(msb, s, n, v), no_spill(msb, s, n, v, hn, h))),
    or_read(t, k, Field.first(Bits.parts(msb, s, n, v))))

def noncross_roundtrip(+msb: Bool, +s: U32, +n: U32, +v: U32, +old: U32, +hi: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(U32.to_nat(n), U32.to_nat((32 - s : U32))),
  clean: current_clean(msb, s, old)) ->
  {U32.to_nat(Bits.field(msb, n, join(msb, s, Field.written_lo(msb, s, n, v, old), hi))) ==
    Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  match msb:
    case False{}:
      Field.lsb_noncrossing_roundtrip(s, n, v, old, hi, hs, hn, h, clean)
    case True{}:
      Field.msb_noncrossing_roundtrip(s, n, v, old, hi, hs, hn, h, clean)

def written_noncross_field(+t: A.Tree, +p: Nat, +msb: Bool, +n: U32, +v: U32,
  hs: MNat.le(U32.to_nat(Bits.pos.offset(p)), 32n),
  +hn: MNat.le(U32.to_nat(n), 32n),
  +h: MNat.le(U32.to_nat(n), U32.to_nat((32 - Bits.pos.offset(p) : U32))),
  clean: current_clean(msb, Bits.pos.offset(p), A.get(t, Bits.pos.index(p)))) ->
  {U32.to_nat(Bits.field(msb, n,
    window(msb, put_parts(t, Bits.pos.index(p), Bits.parts(msb, Bits.pos.offset(p), n, v)), p))) ==
    Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  +out = put_parts(t, Bits.pos.index(p), Bits.parts(msb, Bits.pos.offset(p), n, v))
  %Equal.sym(U32, window(msb, out, p),
    join(msb, Bits.pos.offset(p), A.get(out, Bits.pos.index(p)), A.get(out, (Bits.pos.index(p) + 1 : U32))),
    window_join(msb, out, p)) :
    {U32.to_nat(Bits.field(msb, n, _)) == Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}
  %Equal.sym(U32, A.get(out, Bits.pos.index(p)),
    Field.written_lo(msb, Bits.pos.offset(p), n, v, A.get(t, Bits.pos.index(p))),
    put_parts_noncross_read(t, Bits.pos.index(p), msb, Bits.pos.offset(p), n, v, hn, h)) :
    {U32.to_nat(Bits.field(msb, n, join(msb, Bits.pos.offset(p), _, A.get(out, (Bits.pos.index(p) + 1 : U32))))) ==
      Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}
  noncross_roundtrip(msb, Bits.pos.offset(p), n, v, A.get(t, Bits.pos.index(p)),
    A.get(out, (Bits.pos.index(p) + 1 : U32)), hs, hn, h, clean)
