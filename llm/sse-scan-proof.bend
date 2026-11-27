import Base
import ./sse.bend as Sse
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def clean(c: U32) -> Data:
  match c:
    case 10:
      Empty
    case 13:
      Empty
    case _:
      Unit

# Split bits explicitly because numeral wildcard branches retain opaque bits.
def eol_elim(-P: (Array<U32> & U32) -> Type, f: Nat, -a: Array<U32>, +c: U32, +i: U32,
  on_lf: {c == 10 : U32} -> P((a, i)),
  on_cr: {c == 13 : U32} -> P((a, i)),
  on_more: clean(c) -> P(Sse.eol(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)))) ->
  P(Sse.eol(1n+f, (a, c), i)):
  match c:
    case U32{w0}:
      match w0:
        case WCon{False{}, w1}:
          match w1:
            case WCon{False{}, w2}:
              on_more(Unit{})
            case WCon{True{}, w2}:
              match w2:
                case WCon{False{}, w3}:
                  match w3:
                    case WCon{False{}, w4}:
                      on_more(Unit{})
                    case WCon{True{}, w4}:
                      match w4:
                        case WCon{False{}, w5}:
                          match w5:
                            case WCon{False{}, w6}:
                              match w6:
                                case WCon{False{}, w7}:
                                  match w7:
                                    case WCon{False{}, w8}:
                                      match w8:
                                        case WCon{False{}, w9}:
                                          match w9:
                                            case WCon{False{}, w10}:
                                              match w10:
                                                case WCon{False{}, w11}:
                                                  match w11:
                                                    case WCon{False{}, w12}:
                                                      match w12:
                                                        case WCon{False{}, w13}:
                                                          match w13:
                                                            case WCon{False{}, w14}:
                                                              match w14:
                                                                case WCon{False{}, w15}:
                                                                  match w15:
                                                                    case WCon{False{}, w16}:
                                                                      match w16:
                                                                        case WCon{False{}, w17}:
                                                                          match w17:
                                                                            case WCon{False{}, w18}:
                                                                              match w18:
                                                                                case WCon{False{}, w19}:
                                                                                  match w19:
                                                                                    case WCon{False{}, w20}:
                                                                                      match w20:
                                                                                        case WCon{False{}, w21}:
                                                                                          match w21:
                                                                                            case WCon{False{}, w22}:
                                                                                              match w22:
                                                                                                case WCon{False{}, w23}:
                                                                                                  match w23:
                                                                                                    case WCon{False{}, w24}:
                                                                                                      match w24:
                                                                                                        case WCon{False{}, w25}:
                                                                                                          match w25:
                                                                                                            case WCon{False{}, w26}:
                                                                                                              match w26:
                                                                                                                case WCon{False{}, w27}:
                                                                                                                  match w27:
                                                                                                                    case WCon{False{}, w28}:
                                                                                                                      match w28:
                                                                                                                        case WCon{False{}, w29}:
                                                                                                                          match w29:
                                                                                                                            case WCon{False{}, w30}:
                                                                                                                              match w30:
                                                                                                                                case WCon{False{}, w31}:
                                                                                                                                  match w31:
                                                                                                                                    case WCon{False{}, w32}:
                                                                                                                                      match w32:
                                                                                                                                        case WNil{}:
                                                                                                                                          on_lf({==})
                                                                                                                                    case WCon{True{}, w32}:
                                                                                                                                      on_more(Unit{})
                                                                                                                                case WCon{True{}, w31}:
                                                                                                                                  on_more(Unit{})
                                                                                                                            case WCon{True{}, w30}:
                                                                                                                              on_more(Unit{})
                                                                                                                        case WCon{True{}, w29}:
                                                                                                                          on_more(Unit{})
                                                                                                                    case WCon{True{}, w28}:
                                                                                                                      on_more(Unit{})
                                                                                                                case WCon{True{}, w27}:
                                                                                                                  on_more(Unit{})
                                                                                                            case WCon{True{}, w26}:
                                                                                                              on_more(Unit{})
                                                                                                        case WCon{True{}, w25}:
                                                                                                          on_more(Unit{})
                                                                                                    case WCon{True{}, w24}:
                                                                                                      on_more(Unit{})
                                                                                                case WCon{True{}, w23}:
                                                                                                  on_more(Unit{})
                                                                                            case WCon{True{}, w22}:
                                                                                              on_more(Unit{})
                                                                                        case WCon{True{}, w21}:
                                                                                          on_more(Unit{})
                                                                                    case WCon{True{}, w20}:
                                                                                      on_more(Unit{})
                                                                                case WCon{True{}, w19}:
                                                                                  on_more(Unit{})
                                                                            case WCon{True{}, w18}:
                                                                              on_more(Unit{})
                                                                        case WCon{True{}, w17}:
                                                                          on_more(Unit{})
                                                                    case WCon{True{}, w16}:
                                                                      on_more(Unit{})
                                                                case WCon{True{}, w15}:
                                                                  on_more(Unit{})
                                                            case WCon{True{}, w14}:
                                                              on_more(Unit{})
                                                        case WCon{True{}, w13}:
                                                          on_more(Unit{})
                                                    case WCon{True{}, w12}:
                                                      on_more(Unit{})
                                                case WCon{True{}, w11}:
                                                  on_more(Unit{})
                                            case WCon{True{}, w10}:
                                              on_more(Unit{})
                                        case WCon{True{}, w9}:
                                          on_more(Unit{})
                                    case WCon{True{}, w8}:
                                      on_more(Unit{})
                                case WCon{True{}, w7}:
                                  on_more(Unit{})
                            case WCon{True{}, w6}:
                              on_more(Unit{})
                        case WCon{True{}, w5}:
                          on_more(Unit{})
                case WCon{True{}, w3}:
                  on_more(Unit{})
        case WCon{True{}, w1}:
          match w1:
            case WCon{False{}, w2}:
              match w2:
                case WCon{False{}, w3}:
                  on_more(Unit{})
                case WCon{True{}, w3}:
                  match w3:
                    case WCon{False{}, w4}:
                      on_more(Unit{})
                    case WCon{True{}, w4}:
                      match w4:
                        case WCon{False{}, w5}:
                          match w5:
                            case WCon{False{}, w6}:
                              match w6:
                                case WCon{False{}, w7}:
                                  match w7:
                                    case WCon{False{}, w8}:
                                      match w8:
                                        case WCon{False{}, w9}:
                                          match w9:
                                            case WCon{False{}, w10}:
                                              match w10:
                                                case WCon{False{}, w11}:
                                                  match w11:
                                                    case WCon{False{}, w12}:
                                                      match w12:
                                                        case WCon{False{}, w13}:
                                                          match w13:
                                                            case WCon{False{}, w14}:
                                                              match w14:
                                                                case WCon{False{}, w15}:
                                                                  match w15:
                                                                    case WCon{False{}, w16}:
                                                                      match w16:
                                                                        case WCon{False{}, w17}:
                                                                          match w17:
                                                                            case WCon{False{}, w18}:
                                                                              match w18:
                                                                                case WCon{False{}, w19}:
                                                                                  match w19:
                                                                                    case WCon{False{}, w20}:
                                                                                      match w20:
                                                                                        case WCon{False{}, w21}:
                                                                                          match w21:
                                                                                            case WCon{False{}, w22}:
                                                                                              match w22:
                                                                                                case WCon{False{}, w23}:
                                                                                                  match w23:
                                                                                                    case WCon{False{}, w24}:
                                                                                                      match w24:
                                                                                                        case WCon{False{}, w25}:
                                                                                                          match w25:
                                                                                                            case WCon{False{}, w26}:
                                                                                                              match w26:
                                                                                                                case WCon{False{}, w27}:
                                                                                                                  match w27:
                                                                                                                    case WCon{False{}, w28}:
                                                                                                                      match w28:
                                                                                                                        case WCon{False{}, w29}:
                                                                                                                          match w29:
                                                                                                                            case WCon{False{}, w30}:
                                                                                                                              match w30:
                                                                                                                                case WCon{False{}, w31}:
                                                                                                                                  match w31:
                                                                                                                                    case WCon{False{}, w32}:
                                                                                                                                      match w32:
                                                                                                                                        case WNil{}:
                                                                                                                                          on_cr({==})
                                                                                                                                    case WCon{True{}, w32}:
                                                                                                                                      on_more(Unit{})
                                                                                                                                case WCon{True{}, w31}:
                                                                                                                                  on_more(Unit{})
                                                                                                                            case WCon{True{}, w30}:
                                                                                                                              on_more(Unit{})
                                                                                                                        case WCon{True{}, w29}:
                                                                                                                          on_more(Unit{})
                                                                                                                    case WCon{True{}, w28}:
                                                                                                                      on_more(Unit{})
                                                                                                                case WCon{True{}, w27}:
                                                                                                                  on_more(Unit{})
                                                                                                            case WCon{True{}, w26}:
                                                                                                              on_more(Unit{})
                                                                                                        case WCon{True{}, w25}:
                                                                                                          on_more(Unit{})
                                                                                                    case WCon{True{}, w24}:
                                                                                                      on_more(Unit{})
                                                                                                case WCon{True{}, w23}:
                                                                                                  on_more(Unit{})
                                                                                            case WCon{True{}, w22}:
                                                                                              on_more(Unit{})
                                                                                        case WCon{True{}, w21}:
                                                                                          on_more(Unit{})
                                                                                    case WCon{True{}, w20}:
                                                                                      on_more(Unit{})
                                                                                case WCon{True{}, w19}:
                                                                                  on_more(Unit{})
                                                                            case WCon{True{}, w18}:
                                                                              on_more(Unit{})
                                                                        case WCon{True{}, w17}:
                                                                          on_more(Unit{})
                                                                    case WCon{True{}, w16}:
                                                                      on_more(Unit{})
                                                                case WCon{True{}, w15}:
                                                                  on_more(Unit{})
                                                            case WCon{True{}, w14}:
                                                              on_more(Unit{})
                                                        case WCon{True{}, w13}:
                                                          on_more(Unit{})
                                                    case WCon{True{}, w12}:
                                                      on_more(Unit{})
                                                case WCon{True{}, w11}:
                                                  on_more(Unit{})
                                            case WCon{True{}, w10}:
                                              on_more(Unit{})
                                        case WCon{True{}, w9}:
                                          on_more(Unit{})
                                    case WCon{True{}, w8}:
                                      on_more(Unit{})
                                case WCon{True{}, w7}:
                                  on_more(Unit{})
                            case WCon{True{}, w6}:
                              on_more(Unit{})
                        case WCon{True{}, w5}:
                          on_more(Unit{})
            case WCon{True{}, w2}:
              on_more(Unit{})

def clean_lf(-G: Type, +c: U32, eq: {c == 10 : U32}) -> clean(c) -> G:
  %Equal.sym(U32, c, 10, eq) : clean(_) -> G
  bad => Empty.absurd(G, bad)

def clean_cr(-G: Type, +c: U32, eq: {c == 13 : U32}) -> clean(c) -> G:
  %Equal.sym(U32, c, 13, eq) : clean(_) -> G
  bad => Empty.absurd(G, bad)

def eol_step(p: Nat, -a: Array<U32>, +c: U32, +i: U32, +ok: clean(c)) ->
  {Sse.eol(1n+p, (a, c), i) == Sse.eol(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)) : Array<U32> & U32}:
  eol_elim(x => {x == Sse.eol(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)) : Array<U32> & U32}, p, a, c, i,
    eq => clean_lf({(a, i) == Sse.eol(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)) : Array<U32> & U32}, c, eq)(ok),
    eq => clean_cr({(a, i) == Sse.eol(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)) : Array<U32> & U32}, c, eq)(ok),
    good => {==})

def clean_prefix(f: Nat, r: Array<U32> & U32, +i: U32) -> Type:
  match f:
    case 0n:
      Unit
    case 1n+p:
      (a, +c) = r
      clean(c) & clean_prefix(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))

def advance(f: Nat, r: Array<U32> & U32, +i: U32) -> (Array<U32> & U32) & U32:
  match f:
    case 0n:
      (r, i)
    case 1n+p:
      (a, c) = r
      advance(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))

def resume(g: Nat, s: (Array<U32> & U32) & U32) -> Array<U32> & U32:
  (r, i) = s
  Sse.eol(g, r, i)

def extend(f: Nat, +g: Nat, r: Array<U32> & U32, +i: U32, ok: clean_prefix(f, r, i)) ->
  {Sse.eol(Nat.add(f, g), r, i) == resume(g, advance(f, r, i)) : Array<U32> & U32}:
  match f:
    case 0n:
      {==}
    case 1n+ +p:
      (a, +c) = r
      (head, tail) = ok
      Equal.trans(Array<U32> & U32,
        Sse.eol(1n+Nat.add(p, g), (a, c), i),
        Sse.eol(Nat.add(p, g), Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)),
        resume(g, advance(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))),
        eol_step(Nat.add(p, g), a, c, i, head),
        extend(p, g, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), tail))

def clean_after(g: Nat, s: (Array<U32> & U32) & U32) -> Type:
  (r, i) = s
  clean_prefix(g, r, i)

def prepend(-H: Type, -L: Type, -R: Type, head: H, pair: L & R) -> (H & L) & R:
  (left, right) = pair
  ((head, left), right)

def split_clean(f: Nat, +g: Nat, r: Array<U32> & U32, +i: U32, ok: clean_prefix(Nat.add(f, g), r, i)) ->
  clean_prefix(f, r, i) & clean_after(g, advance(f, r, i)):
  match f:
    case 0n:
      (Unit{}, ok)
    case 1n+p:
      (a, c) = r
      (head, tail) = ok
      prepend(clean(c),
        clean_prefix(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)),
        clean_after(g, advance(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))),
        head, split_clean(p, g, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), tail))

def join_clean(f: Nat, +g: Nat, r: Array<U32> & U32, +i: U32, ok: clean_prefix(f, r, i) & clean_after(g, advance(f, r, i))) ->
  clean_prefix(Nat.add(f, g), r, i):
  match f:
    case 0n:
      (left, right) = ok
      right
    case 1n+p:
      (a, c) = r
      ((head, left), right) = ok
      (head, join_clean(p, g, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (left, right)))
