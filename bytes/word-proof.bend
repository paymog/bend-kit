# Packed-byte word laws, proved one independent Bool at a time.
import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat

def read(+w: U32, +lane: Nat) -> U32:
  U32.and(U32.shrn(w, Nat.mul(lane, 8n)), 255)

def write(+w: U32, +v: U32, +lane: Nat) -> U32:
  +sh = Nat.mul(lane, 8n)
  U32.or(U32.and(w, U32.xor(U32.shln(255, sh), 4294967295)),
    U32.shln(U32.and(v, 255), sh))

# Extensionality walks the Word spine, never the 2^32 possible words.
def bit_equal(n: Nat, a: Word(n), b: Word(n)) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      match a b:
        case WCon{x, xs} WCon{y, ys}:
          {x == y : Bool} & bit_equal(p, xs, ys)

def word_ext(+n: Nat, +a: Word(n), +b: Word(n), h: bit_equal(n, a, b)) -> {a == b : Word(n)}:
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case 1n+ +p:
      match a b:
        case WCon{+x, +xs} WCon{+y, +ys}:
          (hx, ht) = h
          %hx : {WCon{x, xs} == WCon{_, ys} : Word(1n+p)}
          %word_ext(p, xs, ys, ht) : {WCon{x, xs} == WCon{x, _} : Word(1n+p)}
          {==}

def u32_bits(a: U32, b: U32) -> Type:
  match a b:
    case U32{x} U32{y}:
      bit_equal(32n, x, y)

def u32_ext(+a: U32, +b: U32, h: u32_bits(a, b)) -> {a == b : U32}:
  match a b:
    case U32{+x} U32{+y}:
      Equal.cong(Word(32n), U32, w => U32{w}, x, y, word_ext(32n, x, y, h))

def own_bit(+w: Bool, +v: Bool) -> {
  Bool.and(Bool.or(Bool.and(w, False{}), Bool.and(v, True{})), True{})
  == Bool.and(v, True{}) : Bool}:
  match w v:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def keep_bit(+w: Bool, +v: Bool) -> {
  Bool.and(Bool.or(Bool.and(w, True{}), Bool.and(v, False{})), True{})
  == Bool.and(w, True{}) : Bool}:
  match w v:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def zero_bit(+a: Bool, +b: Bool) -> {Bool.and(a, False{}) == Bool.and(b, False{}) : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def same_0(+w: U32, +v: U32) -> {read(write(w, v, 0n), 0n) == U32.and(v, 255) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 0n), 0n), U32.and(b, 255),
        (own_bit(w0, v0), (own_bit(w1, v1), (own_bit(w2, v2), (own_bit(w3, v3), (own_bit(w4, v4), (own_bit(w5, v5), (own_bit(w6, v6), (own_bit(w7, v7), (zero_bit(Bool.or(Bool.and(w8, True{}), Bool.and(v8, False{})), v8), (zero_bit(Bool.or(Bool.and(w9, True{}), Bool.and(v9, False{})), v9), (zero_bit(Bool.or(Bool.and(w10, True{}), Bool.and(v10, False{})), v10), (zero_bit(Bool.or(Bool.and(w11, True{}), Bool.and(v11, False{})), v11), (zero_bit(Bool.or(Bool.and(w12, True{}), Bool.and(v12, False{})), v12), (zero_bit(Bool.or(Bool.and(w13, True{}), Bool.and(v13, False{})), v13), (zero_bit(Bool.or(Bool.and(w14, True{}), Bool.and(v14, False{})), v14), (zero_bit(Bool.or(Bool.and(w15, True{}), Bool.and(v15, False{})), v15), (zero_bit(Bool.or(Bool.and(w16, True{}), Bool.and(v16, False{})), v16), (zero_bit(Bool.or(Bool.and(w17, True{}), Bool.and(v17, False{})), v17), (zero_bit(Bool.or(Bool.and(w18, True{}), Bool.and(v18, False{})), v18), (zero_bit(Bool.or(Bool.and(w19, True{}), Bool.and(v19, False{})), v19), (zero_bit(Bool.or(Bool.and(w20, True{}), Bool.and(v20, False{})), v20), (zero_bit(Bool.or(Bool.and(w21, True{}), Bool.and(v21, False{})), v21), (zero_bit(Bool.or(Bool.and(w22, True{}), Bool.and(v22, False{})), v22), (zero_bit(Bool.or(Bool.and(w23, True{}), Bool.and(v23, False{})), v23), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v24, False{})), v24), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v25, False{})), v25), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v26, False{})), v26), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v27, False{})), v27), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v28, False{})), v28), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v29, False{})), v29), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v30, False{})), v30), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v31, False{})), v31), Unit{})))))))))))))))))))))))))))))))))

def other_0_1(+w: U32, +v: U32) -> {read(write(w, v, 0n), 1n) == read(w, 1n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 0n), 1n), read(a, 1n),
        (keep_bit(w8, v8), (keep_bit(w9, v9), (keep_bit(w10, v10), (keep_bit(w11, v11), (keep_bit(w12, v12), (keep_bit(w13, v13), (keep_bit(w14, v14), (keep_bit(w15, v15), (zero_bit(Bool.or(Bool.and(w16, True{}), Bool.and(v16, False{})), w16), (zero_bit(Bool.or(Bool.and(w17, True{}), Bool.and(v17, False{})), w17), (zero_bit(Bool.or(Bool.and(w18, True{}), Bool.and(v18, False{})), w18), (zero_bit(Bool.or(Bool.and(w19, True{}), Bool.and(v19, False{})), w19), (zero_bit(Bool.or(Bool.and(w20, True{}), Bool.and(v20, False{})), w20), (zero_bit(Bool.or(Bool.and(w21, True{}), Bool.and(v21, False{})), w21), (zero_bit(Bool.or(Bool.and(w22, True{}), Bool.and(v22, False{})), w22), (zero_bit(Bool.or(Bool.and(w23, True{}), Bool.and(v23, False{})), w23), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v24, False{})), w24), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v25, False{})), w25), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v26, False{})), w26), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v27, False{})), w27), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v28, False{})), w28), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v29, False{})), w29), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v30, False{})), w30), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v31, False{})), w31), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def other_0_2(+w: U32, +v: U32) -> {read(write(w, v, 0n), 2n) == read(w, 2n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 0n), 2n), read(a, 2n),
        (keep_bit(w16, v16), (keep_bit(w17, v17), (keep_bit(w18, v18), (keep_bit(w19, v19), (keep_bit(w20, v20), (keep_bit(w21, v21), (keep_bit(w22, v22), (keep_bit(w23, v23), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v24, False{})), w24), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v25, False{})), w25), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v26, False{})), w26), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v27, False{})), w27), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v28, False{})), w28), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v29, False{})), w29), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v30, False{})), w30), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v31, False{})), w31), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def other_0_3(+w: U32, +v: U32) -> {read(write(w, v, 0n), 3n) == read(w, 3n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 0n), 3n), read(a, 3n),
        (keep_bit(w24, v24), (keep_bit(w25, v25), (keep_bit(w26, v26), (keep_bit(w27, v27), (keep_bit(w28, v28), (keep_bit(w29, v29), (keep_bit(w30, v30), (keep_bit(w31, v31), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def other_1_0(+w: U32, +v: U32) -> {read(write(w, v, 1n), 0n) == read(w, 0n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 1n), 0n), read(a, 0n),
        (keep_bit(w0, False{}), (keep_bit(w1, False{}), (keep_bit(w2, False{}), (keep_bit(w3, False{}), (keep_bit(w4, False{}), (keep_bit(w5, False{}), (keep_bit(w6, False{}), (keep_bit(w7, False{}), (zero_bit(Bool.or(Bool.and(w8, False{}), Bool.and(v0, True{})), w8), (zero_bit(Bool.or(Bool.and(w9, False{}), Bool.and(v1, True{})), w9), (zero_bit(Bool.or(Bool.and(w10, False{}), Bool.and(v2, True{})), w10), (zero_bit(Bool.or(Bool.and(w11, False{}), Bool.and(v3, True{})), w11), (zero_bit(Bool.or(Bool.and(w12, False{}), Bool.and(v4, True{})), w12), (zero_bit(Bool.or(Bool.and(w13, False{}), Bool.and(v5, True{})), w13), (zero_bit(Bool.or(Bool.and(w14, False{}), Bool.and(v6, True{})), w14), (zero_bit(Bool.or(Bool.and(w15, False{}), Bool.and(v7, True{})), w15), (zero_bit(Bool.or(Bool.and(w16, True{}), Bool.and(v8, False{})), w16), (zero_bit(Bool.or(Bool.and(w17, True{}), Bool.and(v9, False{})), w17), (zero_bit(Bool.or(Bool.and(w18, True{}), Bool.and(v10, False{})), w18), (zero_bit(Bool.or(Bool.and(w19, True{}), Bool.and(v11, False{})), w19), (zero_bit(Bool.or(Bool.and(w20, True{}), Bool.and(v12, False{})), w20), (zero_bit(Bool.or(Bool.and(w21, True{}), Bool.and(v13, False{})), w21), (zero_bit(Bool.or(Bool.and(w22, True{}), Bool.and(v14, False{})), w22), (zero_bit(Bool.or(Bool.and(w23, True{}), Bool.and(v15, False{})), w23), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v16, False{})), w24), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v17, False{})), w25), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v18, False{})), w26), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v19, False{})), w27), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v20, False{})), w28), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v21, False{})), w29), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v22, False{})), w30), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v23, False{})), w31), Unit{})))))))))))))))))))))))))))))))))

def same_1(+w: U32, +v: U32) -> {read(write(w, v, 1n), 1n) == U32.and(v, 255) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 1n), 1n), U32.and(b, 255),
        (own_bit(w8, v0), (own_bit(w9, v1), (own_bit(w10, v2), (own_bit(w11, v3), (own_bit(w12, v4), (own_bit(w13, v5), (own_bit(w14, v6), (own_bit(w15, v7), (zero_bit(Bool.or(Bool.and(w16, True{}), Bool.and(v8, False{})), v8), (zero_bit(Bool.or(Bool.and(w17, True{}), Bool.and(v9, False{})), v9), (zero_bit(Bool.or(Bool.and(w18, True{}), Bool.and(v10, False{})), v10), (zero_bit(Bool.or(Bool.and(w19, True{}), Bool.and(v11, False{})), v11), (zero_bit(Bool.or(Bool.and(w20, True{}), Bool.and(v12, False{})), v12), (zero_bit(Bool.or(Bool.and(w21, True{}), Bool.and(v13, False{})), v13), (zero_bit(Bool.or(Bool.and(w22, True{}), Bool.and(v14, False{})), v14), (zero_bit(Bool.or(Bool.and(w23, True{}), Bool.and(v15, False{})), v15), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v16, False{})), v16), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v17, False{})), v17), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v18, False{})), v18), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v19, False{})), v19), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v20, False{})), v20), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v21, False{})), v21), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v22, False{})), v22), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v23, False{})), v23), (zero_bit(False{}, v24), (zero_bit(False{}, v25), (zero_bit(False{}, v26), (zero_bit(False{}, v27), (zero_bit(False{}, v28), (zero_bit(False{}, v29), (zero_bit(False{}, v30), (zero_bit(False{}, v31), Unit{})))))))))))))))))))))))))))))))))

def other_1_2(+w: U32, +v: U32) -> {read(write(w, v, 1n), 2n) == read(w, 2n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 1n), 2n), read(a, 2n),
        (keep_bit(w16, v8), (keep_bit(w17, v9), (keep_bit(w18, v10), (keep_bit(w19, v11), (keep_bit(w20, v12), (keep_bit(w21, v13), (keep_bit(w22, v14), (keep_bit(w23, v15), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v16, False{})), w24), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v17, False{})), w25), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v18, False{})), w26), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v19, False{})), w27), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v20, False{})), w28), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v21, False{})), w29), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v22, False{})), w30), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v23, False{})), w31), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def other_1_3(+w: U32, +v: U32) -> {read(write(w, v, 1n), 3n) == read(w, 3n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 1n), 3n), read(a, 3n),
        (keep_bit(w24, v16), (keep_bit(w25, v17), (keep_bit(w26, v18), (keep_bit(w27, v19), (keep_bit(w28, v20), (keep_bit(w29, v21), (keep_bit(w30, v22), (keep_bit(w31, v23), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def other_2_0(+w: U32, +v: U32) -> {read(write(w, v, 2n), 0n) == read(w, 0n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 2n), 0n), read(a, 0n),
        (keep_bit(w0, False{}), (keep_bit(w1, False{}), (keep_bit(w2, False{}), (keep_bit(w3, False{}), (keep_bit(w4, False{}), (keep_bit(w5, False{}), (keep_bit(w6, False{}), (keep_bit(w7, False{}), (zero_bit(Bool.or(Bool.and(w8, True{}), False{}), w8), (zero_bit(Bool.or(Bool.and(w9, True{}), False{}), w9), (zero_bit(Bool.or(Bool.and(w10, True{}), False{}), w10), (zero_bit(Bool.or(Bool.and(w11, True{}), False{}), w11), (zero_bit(Bool.or(Bool.and(w12, True{}), False{}), w12), (zero_bit(Bool.or(Bool.and(w13, True{}), False{}), w13), (zero_bit(Bool.or(Bool.and(w14, True{}), False{}), w14), (zero_bit(Bool.or(Bool.and(w15, True{}), False{}), w15), (zero_bit(Bool.or(Bool.and(w16, False{}), Bool.and(v0, True{})), w16), (zero_bit(Bool.or(Bool.and(w17, False{}), Bool.and(v1, True{})), w17), (zero_bit(Bool.or(Bool.and(w18, False{}), Bool.and(v2, True{})), w18), (zero_bit(Bool.or(Bool.and(w19, False{}), Bool.and(v3, True{})), w19), (zero_bit(Bool.or(Bool.and(w20, False{}), Bool.and(v4, True{})), w20), (zero_bit(Bool.or(Bool.and(w21, False{}), Bool.and(v5, True{})), w21), (zero_bit(Bool.or(Bool.and(w22, False{}), Bool.and(v6, True{})), w22), (zero_bit(Bool.or(Bool.and(w23, False{}), Bool.and(v7, True{})), w23), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v8, False{})), w24), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v9, False{})), w25), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v10, False{})), w26), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v11, False{})), w27), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v12, False{})), w28), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v13, False{})), w29), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v14, False{})), w30), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v15, False{})), w31), Unit{})))))))))))))))))))))))))))))))))

def other_2_1(+w: U32, +v: U32) -> {read(write(w, v, 2n), 1n) == read(w, 1n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 2n), 1n), read(a, 1n),
        (keep_bit(w8, False{}), (keep_bit(w9, False{}), (keep_bit(w10, False{}), (keep_bit(w11, False{}), (keep_bit(w12, False{}), (keep_bit(w13, False{}), (keep_bit(w14, False{}), (keep_bit(w15, False{}), (zero_bit(Bool.or(Bool.and(w16, False{}), Bool.and(v0, True{})), w16), (zero_bit(Bool.or(Bool.and(w17, False{}), Bool.and(v1, True{})), w17), (zero_bit(Bool.or(Bool.and(w18, False{}), Bool.and(v2, True{})), w18), (zero_bit(Bool.or(Bool.and(w19, False{}), Bool.and(v3, True{})), w19), (zero_bit(Bool.or(Bool.and(w20, False{}), Bool.and(v4, True{})), w20), (zero_bit(Bool.or(Bool.and(w21, False{}), Bool.and(v5, True{})), w21), (zero_bit(Bool.or(Bool.and(w22, False{}), Bool.and(v6, True{})), w22), (zero_bit(Bool.or(Bool.and(w23, False{}), Bool.and(v7, True{})), w23), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v8, False{})), w24), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v9, False{})), w25), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v10, False{})), w26), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v11, False{})), w27), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v12, False{})), w28), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v13, False{})), w29), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v14, False{})), w30), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v15, False{})), w31), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def same_2(+w: U32, +v: U32) -> {read(write(w, v, 2n), 2n) == U32.and(v, 255) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 2n), 2n), U32.and(b, 255),
        (own_bit(w16, v0), (own_bit(w17, v1), (own_bit(w18, v2), (own_bit(w19, v3), (own_bit(w20, v4), (own_bit(w21, v5), (own_bit(w22, v6), (own_bit(w23, v7), (zero_bit(Bool.or(Bool.and(w24, True{}), Bool.and(v8, False{})), v8), (zero_bit(Bool.or(Bool.and(w25, True{}), Bool.and(v9, False{})), v9), (zero_bit(Bool.or(Bool.and(w26, True{}), Bool.and(v10, False{})), v10), (zero_bit(Bool.or(Bool.and(w27, True{}), Bool.and(v11, False{})), v11), (zero_bit(Bool.or(Bool.and(w28, True{}), Bool.and(v12, False{})), v12), (zero_bit(Bool.or(Bool.and(w29, True{}), Bool.and(v13, False{})), v13), (zero_bit(Bool.or(Bool.and(w30, True{}), Bool.and(v14, False{})), v14), (zero_bit(Bool.or(Bool.and(w31, True{}), Bool.and(v15, False{})), v15), (zero_bit(False{}, v16), (zero_bit(False{}, v17), (zero_bit(False{}, v18), (zero_bit(False{}, v19), (zero_bit(False{}, v20), (zero_bit(False{}, v21), (zero_bit(False{}, v22), (zero_bit(False{}, v23), (zero_bit(False{}, v24), (zero_bit(False{}, v25), (zero_bit(False{}, v26), (zero_bit(False{}, v27), (zero_bit(False{}, v28), (zero_bit(False{}, v29), (zero_bit(False{}, v30), (zero_bit(False{}, v31), Unit{})))))))))))))))))))))))))))))))))

def other_2_3(+w: U32, +v: U32) -> {read(write(w, v, 2n), 3n) == read(w, 3n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 2n), 3n), read(a, 3n),
        (keep_bit(w24, v8), (keep_bit(w25, v9), (keep_bit(w26, v10), (keep_bit(w27, v11), (keep_bit(w28, v12), (keep_bit(w29, v13), (keep_bit(w30, v14), (keep_bit(w31, v15), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def other_3_0(+w: U32, +v: U32) -> {read(write(w, v, 3n), 0n) == read(w, 0n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 3n), 0n), read(a, 0n),
        (keep_bit(w0, False{}), (keep_bit(w1, False{}), (keep_bit(w2, False{}), (keep_bit(w3, False{}), (keep_bit(w4, False{}), (keep_bit(w5, False{}), (keep_bit(w6, False{}), (keep_bit(w7, False{}), (zero_bit(Bool.or(Bool.and(w8, True{}), False{}), w8), (zero_bit(Bool.or(Bool.and(w9, True{}), False{}), w9), (zero_bit(Bool.or(Bool.and(w10, True{}), False{}), w10), (zero_bit(Bool.or(Bool.and(w11, True{}), False{}), w11), (zero_bit(Bool.or(Bool.and(w12, True{}), False{}), w12), (zero_bit(Bool.or(Bool.and(w13, True{}), False{}), w13), (zero_bit(Bool.or(Bool.and(w14, True{}), False{}), w14), (zero_bit(Bool.or(Bool.and(w15, True{}), False{}), w15), (zero_bit(Bool.or(Bool.and(w16, True{}), False{}), w16), (zero_bit(Bool.or(Bool.and(w17, True{}), False{}), w17), (zero_bit(Bool.or(Bool.and(w18, True{}), False{}), w18), (zero_bit(Bool.or(Bool.and(w19, True{}), False{}), w19), (zero_bit(Bool.or(Bool.and(w20, True{}), False{}), w20), (zero_bit(Bool.or(Bool.and(w21, True{}), False{}), w21), (zero_bit(Bool.or(Bool.and(w22, True{}), False{}), w22), (zero_bit(Bool.or(Bool.and(w23, True{}), False{}), w23), (zero_bit(Bool.or(Bool.and(w24, False{}), Bool.and(v0, True{})), w24), (zero_bit(Bool.or(Bool.and(w25, False{}), Bool.and(v1, True{})), w25), (zero_bit(Bool.or(Bool.and(w26, False{}), Bool.and(v2, True{})), w26), (zero_bit(Bool.or(Bool.and(w27, False{}), Bool.and(v3, True{})), w27), (zero_bit(Bool.or(Bool.and(w28, False{}), Bool.and(v4, True{})), w28), (zero_bit(Bool.or(Bool.and(w29, False{}), Bool.and(v5, True{})), w29), (zero_bit(Bool.or(Bool.and(w30, False{}), Bool.and(v6, True{})), w30), (zero_bit(Bool.or(Bool.and(w31, False{}), Bool.and(v7, True{})), w31), Unit{})))))))))))))))))))))))))))))))))

def other_3_1(+w: U32, +v: U32) -> {read(write(w, v, 3n), 1n) == read(w, 1n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 3n), 1n), read(a, 1n),
        (keep_bit(w8, False{}), (keep_bit(w9, False{}), (keep_bit(w10, False{}), (keep_bit(w11, False{}), (keep_bit(w12, False{}), (keep_bit(w13, False{}), (keep_bit(w14, False{}), (keep_bit(w15, False{}), (zero_bit(Bool.or(Bool.and(w16, True{}), False{}), w16), (zero_bit(Bool.or(Bool.and(w17, True{}), False{}), w17), (zero_bit(Bool.or(Bool.and(w18, True{}), False{}), w18), (zero_bit(Bool.or(Bool.and(w19, True{}), False{}), w19), (zero_bit(Bool.or(Bool.and(w20, True{}), False{}), w20), (zero_bit(Bool.or(Bool.and(w21, True{}), False{}), w21), (zero_bit(Bool.or(Bool.and(w22, True{}), False{}), w22), (zero_bit(Bool.or(Bool.and(w23, True{}), False{}), w23), (zero_bit(Bool.or(Bool.and(w24, False{}), Bool.and(v0, True{})), w24), (zero_bit(Bool.or(Bool.and(w25, False{}), Bool.and(v1, True{})), w25), (zero_bit(Bool.or(Bool.and(w26, False{}), Bool.and(v2, True{})), w26), (zero_bit(Bool.or(Bool.and(w27, False{}), Bool.and(v3, True{})), w27), (zero_bit(Bool.or(Bool.and(w28, False{}), Bool.and(v4, True{})), w28), (zero_bit(Bool.or(Bool.and(w29, False{}), Bool.and(v5, True{})), w29), (zero_bit(Bool.or(Bool.and(w30, False{}), Bool.and(v6, True{})), w30), (zero_bit(Bool.or(Bool.and(w31, False{}), Bool.and(v7, True{})), w31), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def other_3_2(+w: U32, +v: U32) -> {read(write(w, v, 3n), 2n) == read(w, 2n) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 3n), 2n), read(a, 2n),
        (keep_bit(w16, False{}), (keep_bit(w17, False{}), (keep_bit(w18, False{}), (keep_bit(w19, False{}), (keep_bit(w20, False{}), (keep_bit(w21, False{}), (keep_bit(w22, False{}), (keep_bit(w23, False{}), (zero_bit(Bool.or(Bool.and(w24, False{}), Bool.and(v0, True{})), w24), (zero_bit(Bool.or(Bool.and(w25, False{}), Bool.and(v1, True{})), w25), (zero_bit(Bool.or(Bool.and(w26, False{}), Bool.and(v2, True{})), w26), (zero_bit(Bool.or(Bool.and(w27, False{}), Bool.and(v3, True{})), w27), (zero_bit(Bool.or(Bool.and(w28, False{}), Bool.and(v4, True{})), w28), (zero_bit(Bool.or(Bool.and(w29, False{}), Bool.and(v5, True{})), w29), (zero_bit(Bool.or(Bool.and(w30, False{}), Bool.and(v6, True{})), w30), (zero_bit(Bool.or(Bool.and(w31, False{}), Bool.and(v7, True{})), w31), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), (zero_bit(False{}, False{}), Unit{})))))))))))))))))))))))))))))))))

def same_3(+w: U32, +v: U32) -> {read(write(w, v, 3n), 3n) == U32.and(v, 255) : U32}:
  match w v:
    case U32{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WCon{+w7, WCon{+w8, WCon{+w9, WCon{+w10, WCon{+w11, WCon{+w12, WCon{+w13, WCon{+w14, WCon{+w15, WCon{+w16, WCon{+w17, WCon{+w18, WCon{+w19, WCon{+w20, WCon{+w21, WCon{+w22, WCon{+w23, WCon{+w24, WCon{+w25, WCon{+w26, WCon{+w27, WCon{+w28, WCon{+w29, WCon{+w30, WCon{+w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+v0, WCon{+v1, WCon{+v2, WCon{+v3, WCon{+v4, WCon{+v5, WCon{+v6, WCon{+v7, WCon{+v8, WCon{+v9, WCon{+v10, WCon{+v11, WCon{+v12, WCon{+v13, WCon{+v14, WCon{+v15, WCon{+v16, WCon{+v17, WCon{+v18, WCon{+v19, WCon{+v20, WCon{+v21, WCon{+v22, WCon{+v23, WCon{+v24, WCon{+v25, WCon{+v26, WCon{+v27, WCon{+v28, WCon{+v29, WCon{+v30, WCon{+v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +a : U32 = U32{WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WCon{w8, WCon{w9, WCon{w10, WCon{w11, WCon{w12, WCon{w13, WCon{w14, WCon{w15, WCon{w16, WCon{w17, WCon{w18, WCon{w19, WCon{w20, WCon{w21, WCon{w22, WCon{w23, WCon{w24, WCon{w25, WCon{w26, WCon{w27, WCon{w28, WCon{w29, WCon{w30, WCon{w31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      +b : U32 = U32{WCon{v0, WCon{v1, WCon{v2, WCon{v3, WCon{v4, WCon{v5, WCon{v6, WCon{v7, WCon{v8, WCon{v9, WCon{v10, WCon{v11, WCon{v12, WCon{v13, WCon{v14, WCon{v15, WCon{v16, WCon{v17, WCon{v18, WCon{v19, WCon{v20, WCon{v21, WCon{v22, WCon{v23, WCon{v24, WCon{v25, WCon{v26, WCon{v27, WCon{v28, WCon{v29, WCon{v30, WCon{v31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
      u32_ext(read(write(a, b, 3n), 3n), U32.and(b, 255),
        (own_bit(w24, v0), (own_bit(w25, v1), (own_bit(w26, v2), (own_bit(w27, v3), (own_bit(w28, v4), (own_bit(w29, v5), (own_bit(w30, v6), (own_bit(w31, v7), (zero_bit(False{}, v8), (zero_bit(False{}, v9), (zero_bit(False{}, v10), (zero_bit(False{}, v11), (zero_bit(False{}, v12), (zero_bit(False{}, v13), (zero_bit(False{}, v14), (zero_bit(False{}, v15), (zero_bit(False{}, v16), (zero_bit(False{}, v17), (zero_bit(False{}, v18), (zero_bit(False{}, v19), (zero_bit(False{}, v20), (zero_bit(False{}, v21), (zero_bit(False{}, v22), (zero_bit(False{}, v23), (zero_bit(False{}, v24), (zero_bit(False{}, v25), (zero_bit(False{}, v26), (zero_bit(False{}, v27), (zero_bit(False{}, v28), (zero_bit(False{}, v29), (zero_bit(False{}, v30), (zero_bit(False{}, v31), Unit{})))))))))))))))))))))))))))))))))

# The public API keeps lanes natural and makes both bounds explicit.
def read_write(+w: U32, +v: U32, +lane: Nat, h: MNat.lt(lane, 4n)) -> {
  read(write(w, v, lane), lane) == U32.and(v, 255) : U32}:
  match lane:
    case 0n:
      same_0(w, v)
    case 1n:
      same_1(w, v)
    case 2n:
      same_2(w, v)
    case 3n:
      same_3(w, v)
    case 4n+p:
      Empty.absurd({read(write(w, v, 4n+p), 4n+p) == U32.and(v, 255) : U32},
        MNat.lt_zero(p)(h))

def read_write_other(+w: U32, +v: U32, +i: Nat, +j: Nat,
  hi: MNat.lt(i, 4n), hj: MNat.lt(j, 4n), ne: {i != j : Nat}) -> {
  read(write(w, v, i), j) == read(w, j) : U32}:
  match i j:
    case 0n 0n:
      Empty.absurd({read(write(w, v, 0n), 0n) == read(w, 0n) : U32}, ne({==}))
    case 0n 1n:
      other_0_1(w, v)
    case 0n 2n:
      other_0_2(w, v)
    case 0n 3n:
      other_0_3(w, v)
    case 0n 4n+q:
      Empty.absurd({read(write(w, v, 0n), 4n+q) == read(w, 4n+q) : U32},
        MNat.lt_zero(q)(hj))
    case 1n 0n:
      other_1_0(w, v)
    case 1n 1n:
      Empty.absurd({read(write(w, v, 1n), 1n) == read(w, 1n) : U32}, ne({==}))
    case 1n 2n:
      other_1_2(w, v)
    case 1n 3n:
      other_1_3(w, v)
    case 1n 4n+q:
      Empty.absurd({read(write(w, v, 1n), 4n+q) == read(w, 4n+q) : U32},
        MNat.lt_zero(q)(hj))
    case 2n 0n:
      other_2_0(w, v)
    case 2n 1n:
      other_2_1(w, v)
    case 2n 2n:
      Empty.absurd({read(write(w, v, 2n), 2n) == read(w, 2n) : U32}, ne({==}))
    case 2n 3n:
      other_2_3(w, v)
    case 2n 4n+q:
      Empty.absurd({read(write(w, v, 2n), 4n+q) == read(w, 4n+q) : U32},
        MNat.lt_zero(q)(hj))
    case 3n 0n:
      other_3_0(w, v)
    case 3n 1n:
      other_3_1(w, v)
    case 3n 2n:
      other_3_2(w, v)
    case 3n 3n:
      Empty.absurd({read(write(w, v, 3n), 3n) == read(w, 3n) : U32}, ne({==}))
    case 3n 4n+q:
      Empty.absurd({read(write(w, v, 3n), 4n+q) == read(w, 4n+q) : U32},
        MNat.lt_zero(q)(hj))
    case 4n+p +q:
      Empty.absurd({read(write(w, v, 4n+p), q) == read(w, q) : U32},
        MNat.lt_zero(p)(hi))

# Boolean and comparison helpers for the byte range.
def false_true(h: {False{} == True{} : Bool}) -> Empty:
  %h : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def and_true(+x: Bool) -> {Bool.and(x, True{}) == x : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      {==}

def and_false(+x: Bool) -> {Bool.and(x, False{}) == False{} : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      {==}

def word_and_zero(+n: Nat, +w: Word(n)) -> {
  Word.and(n, w, Word.zero(n)) == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{+x, +t}:
          %and_false(x) : {WCon{Bool.and(x, False{}), Word.and(p, t, Word.zero(p))} == WCon{_, Word.zero(p)} : Word(1n+p)}
          %word_and_zero(p, t) : {WCon{Bool.and(x, False{}), Word.and(p, t, Word.zero(p))} == WCon{Bool.and(x, False{}), _} : Word(1n+p)}
          {==}

def cmp_zero_self(+n: Nat) -> {Word.cmp(n, Word.zero(n), Word.zero(n)) == EQ{} : Cmp}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      Equal.cong(Cmp, Cmp, c => Word.cmp.fin(False{}, False{}, c),
        Word.cmp(p, Word.zero(p), Word.zero(p)), EQ{}, cmp_zero_self(p))

def fin_not_gt_tail(+x: Bool, +t: Cmp,
  h: {Cmp.is_gt(Word.cmp.fin(x, False{}, t)) == False{} : Bool}) -> {
  Cmp.is_gt(t) == False{} : Bool}:
  match x t:
    case False{} LT{}:
      {==}
    case False{} EQ{}:
      {==}
    case False{} GT{}:
      h
    case True{} LT{}:
      {==}
    case True{} EQ{}:
      {==}
    case True{} GT{}:
      h

def zero_of_ne_gt(+n: Nat, +w: Word(n), +h: {Cmp.is_gt(Word.cmp(n, w, Word.zero(n))) == False{} : Bool}) -> {
  w == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+ +p:
      match w:
        case WCon{False{}, +t}:
          ht = zero_of_ne_gt(p, t, fin_not_gt_tail(False{}, Word.cmp(p, t, Word.zero(p)), h))
          Equal.cong(Word(p), Word(1n+p), z => WCon{False{}, z}, t, Word.zero(p), ht)
        case WCon{True{}, +t}:
          ht = zero_of_ne_gt(p, t, fin_not_gt_tail(True{}, Word.cmp(p, t, Word.zero(p)), h))
          ct = Equal.trans(Cmp, Word.cmp(p, t, Word.zero(p)),
            Word.cmp(p, Word.zero(p), Word.zero(p)), EQ{},
            Equal.cong(Word(p), Cmp, z => Word.cmp(p, z, Word.zero(p)), t, Word.zero(p), ht),
            cmp_zero_self(p))
          Empty.absurd({WCon{True{}, t} == Word.zero(1n+p) : Word(1n+p)},
            false_true(Equal.sym(Bool, True{}, False{}, Equal.trans(Bool,
              True{}, Cmp.is_gt(Word.cmp.fin(True{}, False{}, Word.cmp(p, t, Word.zero(p)))), False{},
              Equal.sym(Bool, Cmp.is_gt(Word.cmp.fin(True{}, False{}, Word.cmp(p, t, Word.zero(p)))), True{},
                Equal.cong(Cmp, Bool, c => Cmp.is_gt(Word.cmp.fin(True{}, False{}, c)),
                  Word.cmp(p, t, Word.zero(p)), EQ{}, ct)), h))))

def fin_ne_gt(+x: Bool, +y: Bool, +t: Cmp,
  h: {Cmp.is_lt(Word.cmp.fin(x, y, t)) == True{} : Bool}) -> {Cmp.is_gt(t) == False{} : Bool}:
  match t:
    case LT{}:
      {==}
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({True{} == False{} : Bool}, false_true(h))

def fin_lt_tail(+x: Bool, +t: Cmp,
  h: {Cmp.is_lt(Word.cmp.fin(x, False{}, t)) == True{} : Bool}) -> {Cmp.is_lt(t) == True{} : Bool}:
  match x t:
    case False{} LT{}:
      {==}
    case False{} EQ{}:
      Empty.absurd({False{} == True{} : Bool}, false_true(h))
    case False{} GT{}:
      h
    case True{} LT{}:
      {==}
    case True{} EQ{}:
      h
    case True{} GT{}:
      h

def lt_one_head(+x: Bool, +t: Cmp, ct: {t == EQ{} : Cmp},
  h: {Cmp.is_lt(Word.cmp.fin(x, True{}, t)) == True{} : Bool}) -> {x == False{} : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, false_true(Equal.trans(Bool, False{},
        Cmp.is_lt(Word.cmp.fin(True{}, True{}, t)), True{},
        Equal.sym(Bool, Cmp.is_lt(Word.cmp.fin(True{}, True{}, t)), False{},
          Equal.cong(Cmp, Bool, c => Cmp.is_lt(Word.cmp.fin(True{}, True{}, c)), t, EQ{}, ct)), h)))

def lt_one(+p: Nat, +w: Word(1n+p), +h: {
  Cmp.is_lt(Word.cmp(1n+p, w, WCon{True{}, Word.zero(p)})) == True{} : Bool}) -> {
  w == Word.zero(1n+p) : Word(1n+p)}:
  match w:
    case WCon{+x, +t}:
      +ht = zero_of_ne_gt(p, t, fin_ne_gt(x, True{}, Word.cmp(p, t, Word.zero(p)), h))
      ct = Equal.trans(Cmp, Word.cmp(p, t, Word.zero(p)),
        Word.cmp(p, Word.zero(p), Word.zero(p)), EQ{},
        Equal.cong(Word(p), Cmp, z => Word.cmp(p, z, Word.zero(p)), t, Word.zero(p), ht),
        cmp_zero_self(p))
      hx = lt_one_head(x, Word.cmp(p, t, Word.zero(p)), ct, h)
      %hx : {WCon{x, t} == WCon{_, Word.zero(p)} : Word(1n+p)}
      %ht : {WCon{x, t} == WCon{x, _} : Word(1n+p)}
      {==}

def and255_small(+v: U32, h: {U32.is_lt(v, 256) == True{} : Bool}) -> {U32.and(v, 255) == v : U32}:
  match v:
    case U32{WCon{+x0, WCon{+x1, WCon{+x2, WCon{+x3, WCon{+x4, WCon{+x5, WCon{+x6, WCon{+x7, +t}}}}}}}}}:
      h1 = fin_lt_tail(x0, Word.cmp(31n, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, t}}}}}}}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, Word.zero(23n)}}}}}}}}), h)
      h2 = fin_lt_tail(x1, Word.cmp(30n, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, t}}}}}}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, Word.zero(23n)}}}}}}}), h1)
      h3 = fin_lt_tail(x2, Word.cmp(29n, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, t}}}}}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, Word.zero(23n)}}}}}}), h2)
      h4 = fin_lt_tail(x3, Word.cmp(28n, WCon{x4, WCon{x5, WCon{x6, WCon{x7, t}}}}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, Word.zero(23n)}}}}}), h3)
      h5 = fin_lt_tail(x4, Word.cmp(27n, WCon{x5, WCon{x6, WCon{x7, t}}}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, Word.zero(23n)}}}}), h4)
      h6 = fin_lt_tail(x5, Word.cmp(26n, WCon{x6, WCon{x7, t}}, WCon{False{}, WCon{False{}, WCon{True{}, Word.zero(23n)}}}), h5)
      h7 = fin_lt_tail(x6, Word.cmp(25n, WCon{x7, t}, WCon{False{}, WCon{True{}, Word.zero(23n)}}), h6)
      h8 = fin_lt_tail(x7, Word.cmp(24n, t, WCon{True{}, Word.zero(23n)}), h7)
      ht = lt_one(23n, t, h8)
      %Equal.sym(Word(24n), t, Word.zero(24n), ht) : {U32.and(U32{WCon{x0, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, _}}}}}}}}}, 255) == U32{WCon{x0, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, _}}}}}}}}} : U32}
      u32_ext(U32.and(U32{WCon{x0, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, Word.zero(24n)}}}}}}}}}, 255), U32{WCon{x0, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, Word.zero(24n)}}}}}}}}},
        (and_true(x0), (and_true(x1), (and_true(x2), (and_true(x3), (and_true(x4), (and_true(x5), (and_true(x6), (and_true(x7), ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, Unit{})))))))))))))))))))))))))))))))))

def and255_lt(+v: U32) -> {U32.is_lt(U32.and(v, 255), 256) == True{} : Bool}:
  match v:
    case U32{WCon{+x0, WCon{+x1, WCon{+x2, WCon{+x3, WCon{+x4, WCon{+x5, WCon{+x6, WCon{+x7, +t}}}}}}}}}:
      %Equal.sym(Word(24n), Word.and(24n, t, Word.zero(24n)), Word.zero(24n), word_and_zero(24n, t)) : {U32.is_lt(U32{WCon{Bool.and(x0, True{}), WCon{Bool.and(x1, True{}), WCon{Bool.and(x2, True{}), WCon{Bool.and(x3, True{}), WCon{Bool.and(x4, True{}), WCon{Bool.and(x5, True{}), WCon{Bool.and(x6, True{}), WCon{Bool.and(x7, True{}), _}}}}}}}}}, 256) == True{} : Bool}
      {==}

def read_small(+w: U32, +v: U32, +lane: Nat,
  h: MNat.lt(lane, 4n), hv: {U32.is_lt(v, 256) == True{} : Bool}) -> {
  read(write(w, v, lane), lane) == v : U32}:
  Equal.trans(U32, read(write(w, v, lane), lane), U32.and(v, 255), v,
    read_write(w, v, lane, h), and255_small(v, hv))

def read_lt(+w: U32, +lane: Nat, h: MNat.lt(lane, 4n)) -> {
  U32.is_lt(read(w, lane), 256) == True{} : Bool}:
  and255_lt(U32.shrn(w, Nat.mul(lane, 8n)))
