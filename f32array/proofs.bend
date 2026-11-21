import Base
import ./f32array.bend as A
import ../lemmas/lemmas.bend as L
import ../lemmas/array.bend as Arr
import ./LAWS.bend as Laws

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def absurd(-T: Type, e: Empty) -> T:
  match e:

def not_lt_zero(n: Nat, h: {Nat.is_lt(n, 0n) == True{} : Bool}) -> Empty:
  match n:
    case 0n:
      false_true(h)
    case 1n+p:
      false_true(h)

def lane_nat(c: A.Cell, +n: Nat, +v: F32, h: {Nat.is_lt(n, 8n) == True{} : Bool}) -> {A.lane(A.put(c, U32.from_nat(n), v), U32.from_nat(n)) == v : F32}:
  match c:
    case A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}:
      match n:
        case 0n:
          {==}
        case 1n+p0:
          match p0:
            case 0n:
              {==}
            case 1n+p1:
              match p1:
                case 0n:
                  {==}
                case 1n+p2:
                  match p2:
                    case 0n:
                      {==}
                    case 1n+p3:
                      match p3:
                        case 0n:
                          {==}
                        case 1n+p4:
                          match p4:
                            case 0n:
                              {==}
                            case 1n+p5:
                              match p5:
                                case 0n:
                                  {==}
                                case 1n+p6:
                                  match p6:
                                    case 0n:
                                      {==}
                                    case 1n+p7:
                                      absurd({A.lane(A.put(A.Cell{v0, v1, v2, v3, v4, v5, v6, v7}, U32.from_nat(8n+p7), v), U32.from_nat(8n+p7)) == v : F32}, not_lt_zero(p7, h))

def lane_put(c: A.Cell, +k: U32, +v: F32, h: {U32.is_lt(k, 8) == True{} : Bool}) -> {A.lane(A.put(c, k, v), k) == v : F32}:
  %L.u32_from_to_nat(k) : {A.lane(A.put(c, _, v), _) == v : F32}
  lane_nat(c, U32.to_nat(k), v, Equal.trans(Bool, Nat.is_lt(U32.to_nat(k), 8n), U32.is_lt(k, 8), True{}, Equal.sym(Bool, U32.is_lt(k, 8), Nat.is_lt(U32.to_nat(k), 8n), L.u32_is_lt_nat(k, 8)), h))

def and_zero(n: Nat, w: Word(n)) -> {Word.and(n, w, Word.zero(n)) == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{b, t}:
          match b:
            case False{}:
              Equal.cong(Word(p), Word(1n+p), x => WCon{False{}, x}, Word.and(p, t, Word.zero(p)), Word.zero(p), and_zero(p, t))
            case True{}:
              Equal.cong(Word(p), Word(1n+p), x => WCon{False{}, x}, Word.and(p, t, Word.zero(p)), Word.zero(p), and_zero(p, t))

def low3_bits(b0: Bool, b1: Bool, b2: Bool) -> {U32.is_lt(U32{WCon{b0, WCon{b1, WCon{b2, Word.zero(29n)}}}}, 8) == True{} : Bool}:
  match b0 b1 b2:
    case False{} False{} False{}:
      {==}
    case False{} False{} True{}:
      {==}
    case False{} True{} False{}:
      {==}
    case False{} True{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} True{} False{}:
      {==}
    case True{} True{} True{}:
      {==}

def low3(+i: U32) -> {U32.is_lt((i .&. 7 : U32), 8) == True{} : Bool}:
  match i:
    case U32{WCon{b0, WCon{b1, WCon{b2, t}}}}:
      %Equal.sym(Word(29n), Word.and(29n, t, Word.zero(29n)), Word.zero(29n), and_zero(29n, t)) : {U32.is_lt(U32{WCon{Bool.and(b0, True{}), WCon{Bool.and(b1, True{}), WCon{Bool.and(b2, True{}), _}}}}, 8) == True{} : Bool}
      low3_bits(Bool.and(b0, True{}), Bool.and(b1, True{}), Bool.and(b2, True{}))

def get_written(+len: U32, +i: U32, +v: F32, +c: A.Cell, -a: Array<A.Cell>, +h: {U32.is_lt(i, len) == True{} : Bool}, f: Arr.Read(A.Cell, Array.get(A.Cell, Array.set(A.Cell, a, (i >> 3n : U32), A.put(c, (i .&. 7 : U32), v)), (i >> 3n : U32)), A.put(c, (i .&. 7 : U32), v))) -> {Laws.value(A.get(A.F32Array{len, A.poke.of(i, v, (a, c))}, i)) == Some{v} : Maybe<&2, F32>}:
  match f:
    case Tuple{+val, Tuple{+eta, u}}:
      %Equal.sym(Bool, U32.is_lt(i, len), True{}, h) : {Laws.value(A.get.if(_, len, A.poke.of(i, v, (a, c)), i)) == Some{v} : Maybe<&2, F32>}
      %eta : {Laws.value(A.get.some(len, A.peek.of((i .&. 7 : U32), _))) == Some{v} : Maybe<&2, F32>}
      %Equal.sym(A.Cell, Pair.snd(Array<A.Cell>, A.Cell, Array.get(A.Cell, Array.set(A.Cell, a, (i >> 3n : U32), A.put(c, (i .&. 7 : U32), v)), (i >> 3n : U32))), A.put(c, (i .&. 7 : U32), v), val) : {Some{A.lane(_, (i .&. 7 : U32))} == Some{v} : Maybe<&2, F32>}
      Equal.cong(F32, Maybe<&2, F32>, x => Some{x}, A.lane(A.put(c, (i .&. 7 : U32), v), (i .&. 7 : U32)), v, lane_put(c, (i .&. 7 : U32), v, low3(i)))

def get_poke_of(+len: U32, +i: U32, +v: F32, r: Array<A.Cell> & A.Cell, +h: {U32.is_lt(i, len) == True{} : Bool}) -> {Laws.value(A.get(A.F32Array{len, A.poke.of(i, v, r)}, i)) == Some{v} : Maybe<&2, F32>}:
  match r:
    case Tuple{a, +c}:
      get_written(len, i, v, c, a, h, Arr.read_after_set(A.Cell, a, (i >> 3n : U32), A.put(c, (i .&. 7 : U32), v)))

def get_after_set(a: A.F32Array, +i: U32, +v: F32, +h: {U32.is_lt(i, Laws.len(a)) == True{} : Bool}) -> {Laws.value(A.get(A.set(a, i, v), i)) == Some{v} : Maybe<&2, F32>}:
  match a:
    case A.F32Array{+len, buf}:
      %Equal.sym(Bool, U32.is_lt(i, len), True{}, h) : {Laws.value(A.get(A.set.if(_, len, buf, i, v), i)) == Some{v} : Maybe<&2, F32>}
      get_poke_of(len, i, v, Array.get(A.Cell, buf, (i >> 3n : U32)), h)

