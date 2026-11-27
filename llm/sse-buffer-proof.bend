import Base
import ./sse.bend as Sse
import ./sse-scan-proof.bend as Scan
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ../lemmas/array.bend as ArrayProof

def index(r: Array<U32> & U32) -> U32:
  (a, i) = r
  i

def related_reads(~R: U32 -> U32 -> Type, f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32) -> Type:
  match f:
    case 0n:
      R(i, j)
    case 1n+p:
      (a, +c) = r
      (b, d) = s
      R(i, j) & ({c == d : U32} & related_reads(~R, p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32)))

def related_step(~R: U32 -> U32 -> Type, +f: Nat, -a: Array<U32>, -b: Array<U32>, +c: U32, +i: U32, +j: U32,
  here: R(i, j),
  next: R(index(Sse.eol(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))), index(Sse.eol(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))))) ->
  R(index(Sse.eol(1n+f, (a, c), i)), index(Sse.eol(1n+f, (b, c), j))):
  -left : Array<U32> & U32 = Sse.eol(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))
  -right : Array<U32> & U32 = Sse.eol(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))
  Scan.eol_elim(x => R(i, j) -> R(index(left), index(right)) -> R(index(x), index(Sse.eol(1n+f, (b, c), j))), f, a, c, i,
    eq => h => n =>
      (%Equal.sym(U32, c, 10, eq) : R(i, index(Sse.eol(1n+f, (b, _), j))); h),
    eq => h => n =>
      (%Equal.sym(U32, c, 13, eq) : R(i, index(Sse.eol(1n+f, (b, _), j))); h),
    good => h => n =>
      (%Equal.sym(Array<U32> & U32, Sse.eol(1n+f, (b, c), j), right, Scan.eol_step(f, b, c, j, good)) :
        R(index(left), index(_)); n))(here)(next)

def eol_related(~R: U32 -> U32 -> Type, f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  ok: related_reads(~R, f, r, s, i, j)) ->
  R(index(Sse.eol(f, r, i)), index(Sse.eol(f, s, j))):
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      ok
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (here, (head, tail)) = ok
      %head : R(index(Sse.eol(1n+p, (a, c), i)), index(Sse.eol(1n+p, (b, _), j)))
      related_step(~R, p, a, b, c, i, j, here,
        eol_related(~R, p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), tail))

def matching_reads(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32) -> Type:
  match f:
    case 0n:
      Unit
    case 1n+p:
      (a, +c) = r
      (b, d) = s
      {c == d : U32} & matching_reads(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32))

def same_index(i: U32, j: U32) -> Type:
  {i == j : U32}

def eol_same(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, ok: matching_reads(f, r, s, i, i)) ->
  {index(Sse.eol(f, r, i)) == index(Sse.eol(f, s, i)) : U32}:
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      {==}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = ok
      %head : {index(Sse.eol(1n+p, (a, c), i)) == index(Sse.eol(1n+p, (b, _), i)) : U32}
      related_step(~same_index, p, a, b, c, i, i, {==},
        eol_same(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32), tail))

def transport_clean(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  same: matching_reads(f, r, s, i, j), clean: Scan.clean_prefix(f, r, i)) ->
  Scan.clean_prefix(f, s, j):
  match f:
    case 0n:
      Unit{}
    case 1n+p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = same
      (hc, tc) = clean
      ((%head : Scan.clean(_); hc),
        transport_clean(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), tail, tc))

def observed(f: Nat, r: Array<U32> & U32, +i: U32) -> String:
  match f:
    case 0n:
      ""
    case 1n+p:
      (a, c) = r
      SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}

def observed.head(s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{Chr{c}, t}:
      c

def observed.tail(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      t

def observations_match(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  +eq: {observed(f, r, i) == observed(f, s, j) : String}) ->
  matching_reads(f, r, s, i, j):
  match f:
    case 0n:
      Unit{}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (Equal.cong(String, U32, observed.head,
        SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))},
        SCon{Chr{d}, observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))}, eq),
        observations_match(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32),
          Equal.cong(String, String, observed.tail,
            SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))},
            SCon{Chr{d}, observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))}, eq)))

def eol_observed(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32,
  +eq: {observed(f, r, i) == observed(f, s, i) : String}) ->
  {index(Sse.eol(f, r, i)) == index(Sse.eol(f, s, i)) : U32}:
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      {==}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      -left : String = SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}
      -right : String = SCon{Chr{d}, observed(p, Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32))}
      %Equal.cong(String, U32, observed.head, left, right, eq) :
        {index(Sse.eol(1n+p, (a, c), i)) == index(Sse.eol(1n+p, (b, _), i)) : U32}
      related_step(~same_index, p, a, b, c, i, i, {==},
        eol_observed(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32),
          Equal.cong(String, String, observed.tail, left, right, eq)))

def clean_observed(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  +eq: {observed(f, r, i) == observed(f, s, j) : String}, clean: Scan.clean_prefix(f, r, i)) ->
  Scan.clean_prefix(f, s, j):
  match f:
    case 0n:
      Unit{}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = clean
      -left : String = SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}
      -right : String = SCon{Chr{d}, observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))}
      ((%Equal.cong(String, U32, observed.head, left, right, eq) : Scan.clean(_); head),
        clean_observed(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32),
          Equal.cong(String, String, observed.tail, left, right, eq), tail))

def colon_clean(c: U32) -> Data:
  match c:
    case 58:
      Empty
    case _:
      Unit

# Split bits explicitly because numeral wildcard branches retain opaque bits.
def colon_elim(-P: (Array<U32> & U32) -> Type, f: Nat, -a: Array<U32>, +c: U32, +i: U32,
  on_colon: {c == 58 : U32} -> P((a, i)),
  on_more: colon_clean(c) -> P(Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)))) ->
  P(Sse.colon(1n+f, (a, c), i)):
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
                          on_more(Unit{})
                        case WCon{True{}, w5}:
                          match w5:
                            case WCon{False{}, w6}:
                              on_more(Unit{})
                            case WCon{True{}, w6}:
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
                                                                                                                                          on_colon({==})
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
                case WCon{True{}, w3}:
                  on_more(Unit{})
        case WCon{True{}, w1}:
          on_more(Unit{})

def colon_bad(-G: Type, +c: U32, eq: {c == 58 : U32}) -> colon_clean(c) -> G:
  %Equal.sym(U32, c, 58, eq) : colon_clean(_) -> G
  bad => Empty.absurd(G, bad)

def colon_plain(f: Nat, -a: Array<U32>, +c: U32, +i: U32, +ok: colon_clean(c)) ->
  {Sse.colon(1n+f, (a, c), i) == Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)) : Array<U32> & U32}:
  colon_elim(x => {x == Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)) : Array<U32> & U32}, f, a, c, i,
    eq => colon_bad({(a, i) == Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)) : Array<U32> & U32}, c, eq)(ok),
    good => {==})

def colon_step(~R: U32 -> U32 -> Type, +f: Nat, -a: Array<U32>, -b: Array<U32>, +c: U32, +i: U32, +j: U32,
  here: R(i, j),
  next: R(index(Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))), index(Sse.colon(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))))) ->
  R(index(Sse.colon(1n+f, (a, c), i)), index(Sse.colon(1n+f, (b, c), j))):
  -left : Array<U32> & U32 = Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))
  -right : Array<U32> & U32 = Sse.colon(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))
  colon_elim(x => R(i, j) -> R(index(left), index(right)) -> R(index(x), index(Sse.colon(1n+f, (b, c), j))), f, a, c, i,
    eq => h => n =>
      (%Equal.sym(U32, c, 58, eq) : R(i, index(Sse.colon(1n+f, (b, _), j))); h),
    good => h => n =>
      (%Equal.sym(Array<U32> & U32, Sse.colon(1n+f, (b, c), j), right, colon_plain(f, b, c, j, good)) :
        R(index(left), index(_)); n))(here)(next)

def colon_related(~R: U32 -> U32 -> Type, f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  ok: related_reads(~R, f, r, s, i, j)) ->
  R(index(Sse.colon(f, r, i)), index(Sse.colon(f, s, j))):
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      ok
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (here, (head, tail)) = ok
      %head : R(index(Sse.colon(1n+p, (a, c), i)), index(Sse.colon(1n+p, (b, _), j)))
      colon_step(~R, p, a, b, c, i, j, here,
        colon_related(~R, p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), tail))

def colon_observed(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32,
  +eq: {observed(f, r, i) == observed(f, s, i) : String}) ->
  {index(Sse.colon(f, r, i)) == index(Sse.colon(f, s, i)) : U32}:
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      {==}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      -left : String = SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}
      -right : String = SCon{Chr{d}, observed(p, Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32))}
      %Equal.cong(String, U32, observed.head, left, right, eq) :
        {index(Sse.colon(1n+p, (a, c), i)) == index(Sse.colon(1n+p, (b, _), i)) : U32}
      colon_step(~same_index, p, a, b, c, i, i, {==},
        colon_observed(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32),
          Equal.cong(String, String, observed.tail, left, right, eq)))

def matched(r: Array<U32> & Bool) -> Bool:
  (a, ok) = r
  ok

def tree_octet(+t: ArrayProof.Tree<U32>, +i: U32) -> U32:
  Bytes.b8(U32.shrn(ArrayProof.read(U32, t, (i >> 2n : U32)), Bytes.shift(i)))

def tree_peek(+t: ArrayProof.Tree<U32>, +i: U32) ->
  {Bytes.peek(ArrayProof.reify(U32, t), i) == (ArrayProof.reify(U32, t), tree_octet(t, i)) : Array<U32> & U32}:
  %ArrayProof.tree_get(U32, t, (i >> 2n : U32)) :
    {Bytes.peek.of(Bytes.shift(i), _) == (ArrayProof.reify(U32, t), tree_octet(t, i)) : Array<U32> & U32}
  {==}

def colon_buffer(f: Nat, +t: ArrayProof.Tree<U32>, +c: U32, +i: U32) ->
  {Sse.colon(f, (ArrayProof.reify(U32, t), c), i) ==
    (ArrayProof.reify(U32, t), index(Sse.colon(f, (ArrayProof.reify(U32, t), c), i))) : Array<U32> & U32}:
  match f:
    case 0n:
      {==}
    case 1n+ +p:
      colon_elim(x => {x == (ArrayProof.reify(U32, t), index(x)) : Array<U32> & U32}, p, ArrayProof.reify(U32, t), c, i,
        eq => {==},
        good =>
          (%Equal.sym(Array<U32> & U32, Bytes.peek(ArrayProof.reify(U32, t), (i + 1 : U32)),
            (ArrayProof.reify(U32, t), tree_octet(t, (i + 1 : U32))), tree_peek(t, (i + 1 : U32))) :
            {Sse.colon(p, _, (i + 1 : U32)) == (ArrayProof.reify(U32, t), index(Sse.colon(p, _, (i + 1 : U32)))) : Array<U32> & U32}
          colon_buffer(p, t, tree_octet(t, (i + 1 : U32)), (i + 1 : U32))))

def eol_buffer(f: Nat, +t: ArrayProof.Tree<U32>, +c: U32, +i: U32) ->
  {Sse.eol(f, (ArrayProof.reify(U32, t), c), i) ==
    (ArrayProof.reify(U32, t), index(Sse.eol(f, (ArrayProof.reify(U32, t), c), i))) : Array<U32> & U32}:
  match f:
    case 0n:
      {==}
    case 1n+ +p:
      Scan.eol_elim(x => {x == (ArrayProof.reify(U32, t), index(x)) : Array<U32> & U32}, p, ArrayProof.reify(U32, t), c, i,
        eq => {==},
        eq => {==},
        good =>
          (%Equal.sym(Array<U32> & U32, Bytes.peek(ArrayProof.reify(U32, t), (i + 1 : U32)),
            (ArrayProof.reify(U32, t), tree_octet(t, (i + 1 : U32))), tree_peek(t, (i + 1 : U32))) :
            {Sse.eol(p, _, (i + 1 : U32)) == (ArrayProof.reify(U32, t), index(Sse.eol(p, _, (i + 1 : U32)))) : Array<U32> & U32}
          eol_buffer(p, t, tree_octet(t, (i + 1 : U32)), (i + 1 : U32))))

def at_buffer(+needle: String, +ok: Bool, +t: ArrayProof.Tree<U32>, +c: U32, +i: U32) ->
  {Bytes.at.go(needle, ok, (ArrayProof.reify(U32, t), c), i) ==
    (ArrayProof.reify(U32, t), matched(Bytes.at.go(needle, ok, (ArrayProof.reify(U32, t), c), i))) : Array<U32> & Bool}:
  match needle:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +rest}:
      match ok:
        case False{}:
          {==}
        case True{}:
          %Equal.sym(Array<U32> & U32, Bytes.peek(ArrayProof.reify(U32, t), (i + 1 : U32)),
            (ArrayProof.reify(U32, t), tree_octet(t, (i + 1 : U32))), tree_peek(t, (i + 1 : U32))) :
            {Bytes.at.go(rest, U32.is_eq(c, n), _, (i + 1 : U32)) ==
              (ArrayProof.reify(U32, t), matched(Bytes.at.go(rest, U32.is_eq(c, n), _, (i + 1 : U32)))) : Array<U32> & Bool}
          at_buffer(rest, U32.is_eq(c, n), t, tree_octet(t, (i + 1 : U32)), (i + 1 : U32))

def array(r: Array<U32> & U32) -> Array<U32>:
  (a, c) = r
  a

def colon_preserves_snapshot(+f: Nat, -a: Array<U32>, +c: U32, +i: U32, snap: ArrayProof.Snapshot(U32, a)) ->
  {array(Sse.colon(f, (a, c), i)) == a : Array<U32>}:
  match snap:
    case Tuple{+t, Tuple{+eq, u}}:
      %eq : {array(Sse.colon(f, (_, c), i)) == _ : Array<U32>}
      Equal.cong(Array<U32> & U32, Array<U32>, array,
        Sse.colon(f, (ArrayProof.reify(U32, t), c), i),
        (ArrayProof.reify(U32, t), index(Sse.colon(f, (ArrayProof.reify(U32, t), c), i))),
        colon_buffer(f, t, c, i))

def colon_preserves(+f: Nat, a: Array<U32>, +c: U32, +i: U32) ->
  {array(Sse.colon(f, (a, c), i)) == a : Array<U32>}:
  colon_preserves_snapshot(f, a, c, i, ArrayProof.snapshot(U32, a))

def eol_preserves_snapshot(+f: Nat, -a: Array<U32>, +c: U32, +i: U32, snap: ArrayProof.Snapshot(U32, a)) ->
  {array(Sse.eol(f, (a, c), i)) == a : Array<U32>}:
  match snap:
    case Tuple{+t, Tuple{+eq, u}}:
      %eq : {array(Sse.eol(f, (_, c), i)) == _ : Array<U32>}
      Equal.cong(Array<U32> & U32, Array<U32>, array,
        Sse.eol(f, (ArrayProof.reify(U32, t), c), i),
        (ArrayProof.reify(U32, t), index(Sse.eol(f, (ArrayProof.reify(U32, t), c), i))),
        eol_buffer(f, t, c, i))

def eol_preserves(+f: Nat, a: Array<U32>, +c: U32, +i: U32) ->
  {array(Sse.eol(f, (a, c), i)) == a : Array<U32>}:
  eol_preserves_snapshot(f, a, c, i, ArrayProof.snapshot(U32, a))

def at_array(r: Array<U32> & Bool) -> Array<U32>:
  (a, ok) = r
  a

def at_preserves_snapshot(+needle: String, +ok: Bool, -a: Array<U32>, +c: U32, +i: U32, snap: ArrayProof.Snapshot(U32, a)) ->
  {at_array(Bytes.at.go(needle, ok, (a, c), i)) == a : Array<U32>}:
  match snap:
    case Tuple{+t, Tuple{+eq, u}}:
      %eq : {at_array(Bytes.at.go(needle, ok, (_, c), i)) == _ : Array<U32>}
      Equal.cong(Array<U32> & Bool, Array<U32>, at_array,
        Bytes.at.go(needle, ok, (ArrayProof.reify(U32, t), c), i),
        (ArrayProof.reify(U32, t), matched(Bytes.at.go(needle, ok, (ArrayProof.reify(U32, t), c), i))),
        at_buffer(needle, ok, t, c, i))

def at_preserves(+needle: String, +ok: Bool, a: Array<U32>, +c: U32, +i: U32) ->
  {at_array(Bytes.at.go(needle, ok, (a, c), i)) == a : Array<U32>}:
  at_preserves_snapshot(needle, ok, a, c, i, ArrayProof.snapshot(U32, a))

def at_observed(+needle: String, +ok: Bool, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  +eq: {observed(String.length(needle), r, i) == observed(String.length(needle), s, j) : String}) ->
  {matched(Bytes.at.go(needle, ok, r, i)) == matched(Bytes.at.go(needle, ok, s, j)) : Bool}:
  match needle:
    case SNil{}:
      (a, c) = r
      (b, d) = s
      {==}
    case SCon{Chr{+c}, +t}:
      match ok:
        case False{}:
          (a, v) = r
          (b, w) = s
          {==}
        case True{}:
          (a, +v) = r
          (b, +w) = s
          -left : String = SCon{Chr{v}, observed(String.length(t), Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}
          -right : String = SCon{Chr{w}, observed(String.length(t), Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))}
          %Equal.cong(String, U32, observed.head, left, right, eq) :
            {matched(Bytes.at.go(t, U32.is_eq(v, c), Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))) ==
              matched(Bytes.at.go(t, U32.is_eq(_, c), Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))) : Bool}
          at_observed(t, U32.is_eq(v, c), Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32),
            Equal.cong(String, String, observed.tail, left, right, eq))
