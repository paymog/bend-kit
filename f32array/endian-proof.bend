import Base
import ./f32array.bend as A
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

def BitsEqual(n: Nat, a: Word(n), b: Word(n)) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      match a b:
        case WCon{x, xs} WCon{y, ys}:
          {x == y : Bool} & BitsEqual(p, xs, ys)

def word_equal(+n: Nat, +a: Word(n), +b: Word(n), h: BitsEqual(n, a, b)) -> {a == b : Word(n)}:
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case 1n++p:
      match a b:
        case WCon{+x, +xs} WCon{+y, +ys}:
          (first, rest) = h
          Equal.trans(Word(1n+p), WCon{x, xs}, WCon{y, xs}, WCon{y, ys},
            Equal.cong(Bool, Word(1n+p), z => WCon{z, xs}, x, y, first),
            Equal.cong(Word(p), Word(1n+p), z => WCon{y, z}, xs, ys, word_equal(p, xs, ys, rest)))

def bit0(a: Bool, b: Bool) -> {Bool.or(Bool.or(Bool.or(Bool.and(a, True{}), Bool.and(b, False{})), False{}), False{}) == a : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def bit1(a: Bool, b: Bool) -> {Bool.or(Bool.and(Bool.or(Bool.or(Bool.and(a, True{}), Bool.and(b, False{})), False{}), True{}), False{}) == a : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def bit2(a: Bool, b: Bool) -> {Bool.or(Bool.or(Bool.and(Bool.or(Bool.and(a, True{}), False{}), True{}), Bool.and(Bool.or(Bool.or(Bool.or(Bool.and(b, True{}), Bool.and(a, False{})), False{}), False{}), False{})), False{}) == a : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def bit3(a: Bool, b: Bool) -> {Bool.or(Bool.or(Bool.or(Bool.and(a, True{}), Bool.and(Bool.or(Bool.or(Bool.and(b, True{}), Bool.and(a, False{})), False{}), False{})), False{}), False{}) == a : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def word_of(v: U32) -> Word(32n):
  match v:
    case U32{w}:
      w

def swap(w: Word(32n)) -> Word(32n):
  word_of(Bytes.bswap(Bytes.bswap(U32{w})))

def word_roundtrip(+w: Word(32n)) -> {swap(w) == w : Word(32n)}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      word_equal(32n, swap(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}), WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, (bit0(b0, b16), bit0(b1, b17), bit0(b2, b18), bit0(b3, b19), bit0(b4, b20), bit0(b5, b21), bit0(b6, b22), bit0(b7, b23), bit1(b8, b24), bit1(b9, b25), bit1(b10, b26), bit1(b11, b27), bit1(b12, b28), bit1(b13, b29), bit1(b14, b30), bit1(b15, b31), bit2(b16, b0), bit2(b17, b1), bit2(b18, b2), bit2(b19, b3), bit2(b20, b4), bit2(b21, b5), bit2(b22, b6), bit2(b23, b7), bit3(b24, b8), bit3(b25, b9), bit3(b26, b10), bit3(b27, b11), bit3(b28, b12), bit3(b29, b13), bit3(b30, b14), bit3(b31, b15), Unit{}))

def roundtrip(v: F32) -> {A.of_bits.be(A.to_bits.be(v)) == v : F32}:
  match v:
    case F32{+w}:
      Equal.cong(Word(32n), F32, x => F32{x}, swap(w), w, word_roundtrip(w))
