import Base
import ./storage.bend as S
import ./LAWS.bend as Laws
import bend-kit-collections@0.1.5.0/omap.bend as OMap
import bend-kit-collections@0.1.5.0/LAWS.bend as Col
import bend-kit-collections@0.1.5.0/PROOF.bend as ColProof
import bend-kit-collections@0.1.5.0/order.bend as Order

def true_ne_false(e: {True{} == False{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Unit, Empty)
  Unit{}

def false_ne_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def Sound(~D: Data, ~eq: D -> D -> Bool) -> Type:
  @x: D -> @y: D -> {eq(x, y) == True{} : Bool} -> {x == y : D}

def Refl(~D: Data, ~eq: D -> D -> Bool) -> Type:
  @x: D -> {eq(x, x) == True{} : Bool}

def Inj(~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D) -> Type:
  @a: S.Obj<D, B> -> @b: S.Obj<D, B> -> {H(a) == H(b) : D} -> {a == b : S.Obj<D, B>}

def G(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, +d: D) -> Maybe<&2, S.Obj<D, B>>:
  S.Store.get(~D, ~B, ~eq, s, d)

def Has(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, +d: D) -> Bool:
  S.Store.has(~D, ~B, ~eq, s, d)

def P(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, +d: D, o: S.Obj<D, B>) -> S.Store<D, B>:
  S.Store.put(~D, ~B, ~eq, s, d, o)

def A(~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>, +s: S.Store<D, B>) -> S.Store<D, B>:
  S.Store.apply(~D, ~B, ~eq, xs, s)

def get_hit(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +k: D, +o: S.Obj<D, B>, +r: S.Store<D, B>, +d: D,
  e: {eq(d, k) == True{} : Bool}
) -> {G(~D, ~B, ~eq, S.StCon{k, o, r}, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}:
  %Equal.sym(Bool, eq(d, k), True{}, e) : {S.Store.get.go(~D, ~B, ~eq, S.StCon{k, o, r}, d, _) == Some{o} : Maybe<&2, S.Obj<D, B>>}
  {==}

def get_miss(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +k: D, +o: S.Obj<D, B>, +r: S.Store<D, B>, +d: D,
  e: {eq(d, k) == False{} : Bool}
) -> {G(~D, ~B, ~eq, S.StCon{k, o, r}, d) == G(~D, ~B, ~eq, r, d) : Maybe<&2, S.Obj<D, B>>}:
  %Equal.sym(Bool, eq(d, k), False{}, e) : {S.Store.get.go(~D, ~B, ~eq, S.StCon{k, o, r}, d, _) == G(~D, ~B, ~eq, r, d) : Maybe<&2, S.Obj<D, B>>}
  {==}

def has_some(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, +d: D, -x: S.Obj<D, B>,
  h: {G(~D, ~B, ~eq, s, d) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {Has(~D, ~B, ~eq, s, d) == True{} : Bool}:
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, s, d), Some{x}, h) : {Maybe.is_some(&2, S.Obj<D, B>, _) == True{} : Bool}
  {==}

def has_none(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, +d: D,
  h: {G(~D, ~B, ~eq, s, d) == None{} : Maybe<&2, S.Obj<D, B>>}
) -> {Has(~D, ~B, ~eq, s, d) == False{} : Bool}:
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, s, d), None{}, h) : {Maybe.is_some(&2, S.Obj<D, B>, _) == False{} : Bool}
  {==}

def put_has(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>,
  h: {Has(~D, ~B, ~eq, s, d) == True{} : Bool}
) -> {P(~D, ~B, ~eq, s, d, o) == s : S.Store<D, B>}:
  %Equal.sym(Bool, Has(~D, ~B, ~eq, s, d), True{}, h) : {S.Store.put.if(D, B, _, s, d, o) == s : S.Store<D, B>}
  {==}

def put_new(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>,
  h: {Has(~D, ~B, ~eq, s, d) == False{} : Bool}
) -> {P(~D, ~B, ~eq, s, d, o) == S.StCon{d, o, s} : S.Store<D, B>}:
  %Equal.sym(Bool, Has(~D, ~B, ~eq, s, d), False{}, h) : {S.Store.put.if(D, B, _, s, d, o) == S.StCon{d, o, s} : S.Store<D, B>}
  {==}

# e misses d: the new head does not shadow e.
def get_mono.miss(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), c: Bool, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>, +e: D, -x: S.Obj<D, B>,
  hc: {eq(e, d) == c : Bool}, hn: {Has(~D, ~B, ~eq, s, d) == False{} : Bool},
  h: {G(~D, ~B, ~eq, s, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, S.StCon{d, o, s}, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      Empty.absurd({G(~D, ~B, ~eq, S.StCon{d, o, s}, e) == Some{x} : Maybe<&2, S.Obj<D, B>>},
        false_ne_true(Equal.trans(Bool, False{}, Has(~D, ~B, ~eq, s, d), True{},
          Equal.sym(Bool, Has(~D, ~B, ~eq, s, d), False{}, hn),
          (%sound(e, d, hc) : {Has(~D, ~B, ~eq, s, _) == True{} : Bool}
           has_some(~D, ~B, ~eq, s, e, x, h)))))
    case False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{d, o, s}, e), G(~D, ~B, ~eq, s, e), get_miss(~D, ~B, ~eq, d, o, s, e, hc)) : {_ == Some{x} : Maybe<&2, S.Obj<D, B>>}
      h

def get_mono.if(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), c: Bool, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>, +e: D, -x: S.Obj<D, B>,
  +hc: {Has(~D, ~B, ~eq, s, d) == c : Bool}, h: {G(~D, ~B, ~eq, s, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), e) == Some{x} : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), s, put_has(~D, ~B, ~eq, s, d, o, hc)) : {G(~D, ~B, ~eq, _, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
      h
    case False{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), S.StCon{d, o, s}, put_new(~D, ~B, ~eq, s, d, o, hc)) : {G(~D, ~B, ~eq, _, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
      get_mono.miss(~D, ~B, ~eq, ~sound, eq(e, d), s, d, o, e, x, {==}, hc, h)

# A put never changes what get already finds.
def get_mono(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>, +e: D, -x: S.Obj<D, B>,
  h: {G(~D, ~B, ~eq, s, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), e) == Some{x} : Maybe<&2, S.Obj<D, B>>}:
  get_mono.if(~D, ~B, ~eq, ~sound, Has(~D, ~B, ~eq, s, d), s, d, o, e, x, {==}, h)

def apply_mono(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), xs: S.Store<D, B>, +s: S.Store<D, B>, +e: D, -x: S.Obj<D, B>,
  h: {G(~D, ~B, ~eq, s, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, A(~D, ~B, ~eq, xs, s), e) == Some{x} : Maybe<&2, S.Obj<D, B>>}:
  match xs:
    case S.StNil{}:
      h
    case S.StCon{+d, +o, t}:
      apply_mono(~D, ~B, ~eq, ~sound, t, P(~D, ~B, ~eq, s, d, o), e, x, get_mono(~D, ~B, ~eq, ~sound, s, d, o, e, x, h))

def has_put_self.if(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~refl: Refl(~D, ~eq), c: Bool, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>,
  +hc: {Has(~D, ~B, ~eq, s, d) == c : Bool}
) -> {Has(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), d) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), s, put_has(~D, ~B, ~eq, s, d, o, hc)) : {Has(~D, ~B, ~eq, _, d) == True{} : Bool}
      hc
    case False{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), S.StCon{d, o, s}, put_new(~D, ~B, ~eq, s, d, o, hc)) : {Has(~D, ~B, ~eq, _, d) == True{} : Bool}
      has_some(~D, ~B, ~eq, S.StCon{d, o, s}, d, o, get_hit(~D, ~B, ~eq, d, o, s, d, refl(d)))

def has_put_self(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~refl: Refl(~D, ~eq), +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>
) -> {Has(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), d) == True{} : Bool}:
  has_put_self.if(~D, ~B, ~eq, ~refl, Has(~D, ~B, ~eq, s, d), s, d, o, {==})

def has_mono.if(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), m: Maybe<&2, S.Obj<D, B>>, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>, +e: D,
  hm: {G(~D, ~B, ~eq, s, e) == m : Maybe<&2, S.Obj<D, B>>}, h: {Has(~D, ~B, ~eq, s, e) == True{} : Bool}
) -> {Has(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), e) == True{} : Bool}:
  match m:
    case None{}:
      Empty.absurd({Has(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), e) == True{} : Bool},
        false_ne_true(Equal.trans(Bool, False{}, Has(~D, ~B, ~eq, s, e), True{},
          Equal.sym(Bool, Has(~D, ~B, ~eq, s, e), False{}, has_none(~D, ~B, ~eq, s, e, hm)), h)))
    case Some{x}:
      has_some(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), e, x, get_mono(~D, ~B, ~eq, ~sound, s, d, o, e, x, hm))

def has_mono(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>, +e: D,
  h: {Has(~D, ~B, ~eq, s, e) == True{} : Bool}
) -> {Has(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), e) == True{} : Bool}:
  has_mono.if(~D, ~B, ~eq, ~sound, G(~D, ~B, ~eq, s, e), s, d, o, e, {==}, h)

def has_apply_mono(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), xs: S.Store<D, B>, +s: S.Store<D, B>, +e: D,
  h: {Has(~D, ~B, ~eq, s, e) == True{} : Bool}
) -> {Has(~D, ~B, ~eq, A(~D, ~B, ~eq, xs, s), e) == True{} : Bool}:
  match xs:
    case S.StNil{}:
      h
    case S.StCon{+d, +o, t}:
      has_apply_mono(~D, ~B, ~eq, ~sound, t, P(~D, ~B, ~eq, s, d, o), e, has_mono(~D, ~B, ~eq, ~sound, s, d, o, e, h))

# Every digest of xs is in t.
def HasAll(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +t: S.Store<D, B>, xs: S.Store<D, B>) -> Type:
  match xs:
    case S.StNil{}:
      Unit
    case S.StCon{d, o, r}:
      {Has(~D, ~B, ~eq, t, d) == True{} : Bool} & HasAll(~D, ~B, ~eq, t, r)

def apply_noop(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>, +t: S.Store<D, B>, h: HasAll(~D, ~B, ~eq, t, xs)
) -> {A(~D, ~B, ~eq, xs, t) == t : S.Store<D, B>}:
  match xs:
    case S.StNil{}:
      {==}
    case S.StCon{+d, +o, r}:
      (hd, hr) = h
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, t, d, o), t, put_has(~D, ~B, ~eq, t, d, o, hd)) : {A(~D, ~B, ~eq, r, _) == t : S.Store<D, B>}
      apply_noop(~D, ~B, ~eq, r, t, hr)

def apply_has_all(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq), xs: S.Store<D, B>, +s: S.Store<D, B>
) -> HasAll(~D, ~B, ~eq, A(~D, ~B, ~eq, xs, s), xs):
  match xs:
    case S.StNil{}:
      Unit{}
    case S.StCon{+d, +o, +r}:
      (has_apply_mono(~D, ~B, ~eq, ~sound, r, P(~D, ~B, ~eq, s, d, o), d, has_put_self(~D, ~B, ~eq, ~refl, s, d, o)),
       apply_has_all(~D, ~B, ~eq, ~sound, ~refl, r, P(~D, ~B, ~eq, s, d, o)))

def Laws.apply_twice(D, B, eq, sound, refl, xs, s):
  +xs = xs
  +s = s
  apply_noop(~D, ~B, ~eq, xs, A(~D, ~B, ~eq, xs, s), apply_has_all(~D, ~B, ~eq, ~sound, ~refl, xs, s))

def and_l(a: Bool, -b: Bool, h: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      Empty.absurd({False{} == True{} : Bool}, false_ne_true(h))

def and_r(a: Bool, -b: Bool, h: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      h
    case False{}:
      Empty.absurd({b == True{} : Bool}, false_ne_true(h))

def none_ne_some(-T: Data, -x: T, e: {None{} == Some{x} : Maybe<&2, T>}) -> Empty:
  %e : Bool.pick(Type, Maybe.is_some(&2, T, _), Empty, Unit)
  Unit{}

def some_inj(-T: Data, +a: T, -b: T, e: {Some{a} == Some{b} : Maybe<&2, T>}) -> {a == b : T}:
  Equal.cong(Maybe<&2, T>, T, m => Maybe.default(&2, T, m, a), Some{a}, Some{b}, e)

# Every (d, o) of xs is what get finds in s.
def Holds(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, xs: S.Store<D, B>) -> Type:
  match xs:
    case S.StNil{}:
      Unit
    case S.StCon{d, o, r}:
      {G(~D, ~B, ~eq, s, d) == Some{o} : Maybe<&2, S.Obj<D, B>>} & Holds(~D, ~B, ~eq, s, r)

# Every (d, o) of xs has d == H(o).
def Ok(~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, xs: S.Store<D, B>) -> Type:
  match xs:
    case S.StNil{}:
      Unit
    case S.StCon{d, o, r}:
      {d == H(o) : D} & Ok(~D, ~B, ~H, r)

def V(~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, s: S.Store<D, B>) -> Bool:
  S.valid(~D, ~B, ~H, ~eq, s)

def get_valid.if(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), c: Bool,
  +k: D, +x: S.Obj<D, B>, +r: S.Store<D, B>, +d: D, -o: S.Obj<D, B>,
  +hc: {eq(d, k) == c : Bool}, hk: {k == H(x) : D},
  ih: {G(~D, ~B, ~eq, r, d) == Some{o} : Maybe<&2, S.Obj<D, B>>} -> {d == H(o) : D},
  h: {G(~D, ~B, ~eq, S.StCon{k, x, r}, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}
) -> {d == H(o) : D}:
  match c:
    case True{}:
      %some_inj(S.Obj<D, B>, x, o, Equal.trans(Maybe<&2, S.Obj<D, B>>, Some{x}, G(~D, ~B, ~eq, S.StCon{k, x, r}, d), Some{o},
        Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, x, r}, d), Some{x}, get_hit(~D, ~B, ~eq, k, x, r, d, hc)), h)) : {d == H(_) : D}
      Equal.trans(D, d, k, H(x), sound(d, k, hc), hk)
    case False{}:
      ih(Equal.trans(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, r, d), G(~D, ~B, ~eq, S.StCon{k, x, r}, d), Some{o},
        Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, x, r}, d), G(~D, ~B, ~eq, r, d), get_miss(~D, ~B, ~eq, k, x, r, d, hc)), h))

# In a valid store, get finds only objects that hash to the digest asked for.
def get_valid(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq),
  s: S.Store<D, B>, +d: D, -o: S.Obj<D, B>,
  hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, h: {G(~D, ~B, ~eq, s, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}
) -> {d == H(o) : D}:
  match s:
    case S.StNil{}:
      Empty.absurd({d == H(o) : D}, none_ne_some(S.Obj<D, B>, o, h))
    case S.StCon{+k, +x, +r}:
      +hs = hs
      get_valid.if(~D, ~B, ~H, ~eq, ~sound, eq(d, k), k, x, r, d, o, {==},
        sound(k, H(x), and_l(eq(k, H(x)), V(~D, ~B, ~H, ~eq, r), hs)),
        hr => get_valid(~D, ~B, ~H, ~eq, ~sound, r, d, o, and_r(eq(k, H(x)), V(~D, ~B, ~H, ~eq, r), hs), hr),
        h)

def get_unique(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~inj: Inj(~D, ~B, ~H),
  +s: S.Store<D, B>, +d: D, +x: S.Obj<D, B>, +o: S.Obj<D, B>,
  hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, h: {G(~D, ~B, ~eq, s, d) == Some{x} : Maybe<&2, S.Obj<D, B>>}, hd: {d == H(o) : D}
) -> {x == o : S.Obj<D, B>}:
  Equal.sym(S.Obj<D, B>, o, x, inj(o, x, Equal.trans(D, H(o), d, H(x), Equal.sym(D, d, H(o), hd),
    get_valid(~D, ~B, ~H, ~eq, ~sound, s, d, x, hs, h))))

def put_get_valid.has(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~inj: Inj(~D, ~B, ~H),
  m: Maybe<&2, S.Obj<D, B>>, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>,
  +hm: {G(~D, ~B, ~eq, s, d) == m : Maybe<&2, S.Obj<D, B>>}, hc: {Has(~D, ~B, ~eq, s, d) == True{} : Bool},
  hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, hd: {d == H(o) : D}
) -> {G(~D, ~B, ~eq, s, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}:
  match m:
    case None{}:
      Empty.absurd({G(~D, ~B, ~eq, s, d) == Some{o} : Maybe<&2, S.Obj<D, B>>},
        false_ne_true(Equal.trans(Bool, False{}, Has(~D, ~B, ~eq, s, d), True{},
          Equal.sym(Bool, Has(~D, ~B, ~eq, s, d), False{}, has_none(~D, ~B, ~eq, s, d, hm)), hc)))
    case Some{+x}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, s, d), Some{x}, hm) : {_ == Some{o} : Maybe<&2, S.Obj<D, B>>}
      %get_unique(~D, ~B, ~H, ~eq, ~sound, ~inj, s, d, x, o, hs, hm, hd) : {Some{x} == Some{_} : Maybe<&2, S.Obj<D, B>>}
      {==}

def put_get_valid.if(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq), ~inj: Inj(~D, ~B, ~H),
  c: Bool, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>,
  +hc: {Has(~D, ~B, ~eq, s, d) == c : Bool}, hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, hd: {d == H(o) : D}
) -> {G(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), d) == Some{o} : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), s, put_has(~D, ~B, ~eq, s, d, o, hc)) : {G(~D, ~B, ~eq, _, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}
      put_get_valid.has(~D, ~B, ~H, ~eq, ~sound, ~inj, G(~D, ~B, ~eq, s, d), s, d, o, {==}, hc, hs, hd)
    case False{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), S.StCon{d, o, s}, put_new(~D, ~B, ~eq, s, d, o, hc)) : {G(~D, ~B, ~eq, _, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}
      get_hit(~D, ~B, ~eq, d, o, s, d, refl(d))

# In a valid store, a put of an honest object makes get find it.
def put_get_valid(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq), ~inj: Inj(~D, ~B, ~H),
  +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>, hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, hd: {d == H(o) : D}
) -> {G(~D, ~B, ~eq, P(~D, ~B, ~eq, s, d, o), d) == Some{o} : Maybe<&2, S.Obj<D, B>>}:
  put_get_valid.if(~D, ~B, ~H, ~eq, ~sound, ~refl, ~inj, Has(~D, ~B, ~eq, s, d), s, d, o, {==}, hs, hd)

def put_valid.if(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~refl: Refl(~D, ~eq),
  c: Bool, +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>,
  +hc: {Has(~D, ~B, ~eq, s, d) == c : Bool}, hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, hd: {d == H(o) : D}
) -> {V(~D, ~B, ~H, ~eq, P(~D, ~B, ~eq, s, d, o)) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), s, put_has(~D, ~B, ~eq, s, d, o, hc)) : {V(~D, ~B, ~H, ~eq, _) == True{} : Bool}
      hs
    case False{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, d, o), S.StCon{d, o, s}, put_new(~D, ~B, ~eq, s, d, o, hc)) : {V(~D, ~B, ~H, ~eq, _) == True{} : Bool}
      %Equal.sym(D, d, H(o), hd) : {Bool.and(eq(_, H(o)), V(~D, ~B, ~H, ~eq, s)) == True{} : Bool}
      %Equal.sym(Bool, eq(H(o), H(o)), True{}, refl(H(o))) : {Bool.and(_, V(~D, ~B, ~H, ~eq, s)) == True{} : Bool}
      hs

def put_valid(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~refl: Refl(~D, ~eq),
  +s: S.Store<D, B>, +d: D, +o: S.Obj<D, B>, hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, hd: {d == H(o) : D}
) -> {V(~D, ~B, ~H, ~eq, P(~D, ~B, ~eq, s, d, o)) == True{} : Bool}:
  put_valid.if(~D, ~B, ~H, ~eq, ~refl, Has(~D, ~B, ~eq, s, d), s, d, o, {==}, hs, hd)

def apply_valid(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~refl: Refl(~D, ~eq),
  xs: S.Store<D, B>, +s: S.Store<D, B>, hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, ok: Ok(~D, ~B, ~H, xs)
) -> {V(~D, ~B, ~H, ~eq, A(~D, ~B, ~eq, xs, s)) == True{} : Bool}:
  match xs:
    case S.StNil{}:
      hs
    case S.StCon{+d, +o, r}:
      (hd, hr) = ok
      apply_valid(~D, ~B, ~H, ~eq, ~refl, r, P(~D, ~B, ~eq, s, d, o), put_valid(~D, ~B, ~H, ~eq, ~refl, s, d, o, hs, hd), hr)

# Applying honest objects to a valid store makes get find each of them.
def apply_holds(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq), ~inj: Inj(~D, ~B, ~H),
  xs: S.Store<D, B>, +s: S.Store<D, B>, +hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, ok: Ok(~D, ~B, ~H, xs)
) -> Holds(~D, ~B, ~eq, A(~D, ~B, ~eq, xs, s), xs):
  match xs:
    case S.StNil{}:
      Unit{}
    case S.StCon{+d, +o, +r}:
      (+hd, hr) = ok
      (apply_mono(~D, ~B, ~eq, ~sound, r, P(~D, ~B, ~eq, s, d, o), d, o, put_get_valid(~D, ~B, ~H, ~eq, ~sound, ~refl, ~inj, s, d, o, hs, hd)),
       apply_holds(~D, ~B, ~H, ~eq, ~sound, ~refl, ~inj, r, P(~D, ~B, ~eq, s, d, o), put_valid(~D, ~B, ~H, ~eq, ~refl, s, d, o, hs, hd), hr))

def admit_valid.if(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq),
  c: Bool, +s: S.Store<D, B>, +claimed: D, +o: S.Obj<D, B>, -u: S.Store<D, B>,
  +hc: {eq(claimed, H(o)) == c : Bool}, hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool},
  ha: {S.admit.if(D, B, c, P(~D, ~B, ~eq, s, claimed, o), s) == Some{u} : Maybe<&2, S.Store<D, B>>}
) -> {V(~D, ~B, ~H, ~eq, u) == True{} : Bool}:
  match c:
    case True{}:
      %some_inj(S.Store<D, B>, P(~D, ~B, ~eq, s, claimed, o), u, ha) : {V(~D, ~B, ~H, ~eq, _) == True{} : Bool}
      put_valid(~D, ~B, ~H, ~eq, ~refl, s, claimed, o, hs, sound(claimed, H(o), hc))
    case False{}:
      Empty.absurd({V(~D, ~B, ~H, ~eq, u) == True{} : Bool}, none_ne_some(S.Store<D, B>, u, ha))

def Laws.admit_valid(D, B, H, eq, sound, refl, s, claimed, o, u, hs, ha):
  +s = s
  +claimed = claimed
  +o = o
  admit_valid.if(~D, ~B, ~H, ~eq, ~sound, ~refl, eq(claimed, H(o)), s, claimed, o, u, {==}, hs, ha)

def Cat(-D: Data, -B: Data, xs: S.Store<D, B>, ys: S.Store<D, B>) -> S.Store<D, B>:
  S.Store.cat(D, B, xs, ys)

def holds_split.con(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, -d: D, -o: S.Obj<D, B>, -r: S.Store<D, B>, -ys: S.Store<D, B>, +s: S.Store<D, B>,
  hd: {G(~D, ~B, ~eq, s, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}, pr: Holds(~D, ~B, ~eq, s, r) & Holds(~D, ~B, ~eq, s, ys)
) -> Holds(~D, ~B, ~eq, s, S.StCon{d, o, r}) & Holds(~D, ~B, ~eq, s, ys):
  (a, b) = pr
  ((hd, a), b)

def holds_split(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>, -ys: S.Store<D, B>, +s: S.Store<D, B>,
  h: Holds(~D, ~B, ~eq, s, Cat(D, B, xs, ys))
) -> Holds(~D, ~B, ~eq, s, xs) & Holds(~D, ~B, ~eq, s, ys):
  match xs:
    case S.StNil{}:
      (Unit{}, h)
    case S.StCon{d, o, r}:
      (hd, hr) = h
      holds_split.con(~D, ~B, ~eq, d, o, r, ys, s, hd, holds_split(~D, ~B, ~eq, r, ys, s, hr))

def holds_head(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, -d: D, -o: S.Obj<D, B>, -r: S.Store<D, B>, +s: S.Store<D, B>,
  h: Holds(~D, ~B, ~eq, s, S.StCon{d, o, r})
) -> {G(~D, ~B, ~eq, s, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}:
  (hd, hr) = h
  hd

def holds_cat(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>, -ys: S.Store<D, B>, +s: S.Store<D, B>,
  hx: Holds(~D, ~B, ~eq, s, xs), hy: Holds(~D, ~B, ~eq, s, ys)
) -> Holds(~D, ~B, ~eq, s, Cat(D, B, xs, ys)):
  match xs:
    case S.StNil{}:
      hy
    case S.StCon{d, o, r}:
      (hd, hr) = hx
      (hd, holds_cat(~D, ~B, ~eq, r, ys, s, hr, hy))

def ok_cat(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, xs: S.Store<D, B>, -ys: S.Store<D, B>,
  hx: Ok(~D, ~B, ~H, xs), hy: Ok(~D, ~B, ~H, ys)
) -> Ok(~D, ~B, ~H, Cat(D, B, xs, ys)):
  match xs:
    case S.StNil{}:
      hy
    case S.StCon{d, o, r}:
      (hd, hr) = hx
      (hd, ok_cat(~D, ~B, ~H, r, ys, hr, hy))

def ok_objects(~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, t: S.Tree<B>) -> Ok(~D, ~B, ~H, S.objects(~D, ~B, ~H, t)):
  match t:
    case S.TFile{b}:
      ({==}, Unit{})
    case S.TEnd{}:
      ({==}, Unit{})
    case S.TItem{+n, +c, +r}:
      ok_cat(~D, ~B, ~H, S.objects(~D, ~B, ~H, c),
        Cat(D, B, S.objects(~D, ~B, ~H, r), S.StCon{H(S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}), S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}, S.StNil{}}),
        ok_objects(~D, ~B, ~H, c),
        ok_cat(~D, ~B, ~H, S.objects(~D, ~B, ~H, r), S.StCon{H(S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}), S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}, S.StNil{}},
          ok_objects(~D, ~B, ~H, r), ({==}, Unit{})))

def L(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: S.Store<D, B>, +d: D) -> Maybe<&2, S.Tree<B>>:
  S.load(~D, ~B, ~eq, fuel, s, d)

def Item(-D: Data, -B: Data, n: String, c: S.Tree<B>, r: S.Tree<B>) -> S.Tree<B>:
  S.TItem{n, c, r}

def objects_load.item2(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool,
  +p: Nat, +n: String, +c: S.Tree<B>, +r: S.Tree<B>, +s: S.Store<D, B>,
  h1: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, c)),
  hp: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, r)) & Holds(~D, ~B, ~eq, s, S.StCon{H(S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}), S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}, S.StNil{}}),
  ihc: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, c)) -> {L(~D, ~B, ~eq, p, s, S.hash(~D, ~B, ~H, c)) == Some{c} : Maybe<&2, S.Tree<B>>},
  ihr: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, r)) -> {L(~D, ~B, ~eq, p, s, S.hash(~D, ~B, ~H, r)) == Some{r} : Maybe<&2, S.Tree<B>>}
) -> {L(~D, ~B, ~eq, 1n+p, s, S.hash(~D, ~B, ~H, Item(D, B, n, c, r))) == Some{Item(D, B, n, c, r)} : Maybe<&2, S.Tree<B>>}:
  (h3, h4) = hp
  +hc = S.hash(~D, ~B, ~H, c)
  +hr = S.hash(~D, ~B, ~H, r)
  +o = {S.OItem{n, hc, hr} : S.Obj<D, B>}
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, s, H(o)), Some{o}, holds_head(~D, ~B, ~eq, H(o), o, S.StNil{}, s, h4)) : {S.load.go(~D, ~B, ~eq, 1n+p, s, _) == Some{S.TItem{n, c, r}} : Maybe<&2, S.Tree<B>>}
  %Equal.sym(Maybe<&2, S.Tree<B>>, L(~D, ~B, ~eq, p, s, hc), Some{c}, ihc(h1)) : {S.Tree.item(B, n, _, L(~D, ~B, ~eq, p, s, hr)) == Some{S.TItem{n, c, r}} : Maybe<&2, S.Tree<B>>}
  %Equal.sym(Maybe<&2, S.Tree<B>>, L(~D, ~B, ~eq, p, s, hr), Some{r}, ihr(h3)) : {S.Tree.item(B, n, Some{c}, _) == Some{S.TItem{n, c, r}} : Maybe<&2, S.Tree<B>>}
  {==}

def objects_load.item(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool,
  +p: Nat, +n: String, +c: S.Tree<B>, +r: S.Tree<B>, +s: S.Store<D, B>,
  hp: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, c)) & Holds(~D, ~B, ~eq, s, Cat(D, B, S.objects(~D, ~B, ~H, r), S.StCon{H(S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}), S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)}, S.StNil{}})),
  ihc: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, c)) -> {L(~D, ~B, ~eq, p, s, S.hash(~D, ~B, ~H, c)) == Some{c} : Maybe<&2, S.Tree<B>>},
  ihr: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, r)) -> {L(~D, ~B, ~eq, p, s, S.hash(~D, ~B, ~H, r)) == Some{r} : Maybe<&2, S.Tree<B>>}
) -> {L(~D, ~B, ~eq, 1n+p, s, S.hash(~D, ~B, ~H, Item(D, B, n, c, r))) == Some{Item(D, B, n, c, r)} : Maybe<&2, S.Tree<B>>}:
  (h1, h2) = hp
  +o = {S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)} : S.Obj<D, B>}
  objects_load.item2(~D, ~B, ~H, ~eq, p, n, c, r, s, h1,
    holds_split(~D, ~B, ~eq, S.objects(~D, ~B, ~H, r), S.StCon{H(o), o, S.StNil{}}, s, h2), ihc, ihr)

# A store that holds every object of t loads t from its root.
def objects_load(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool,
  fuel: Nat, t: S.Tree<B>, +s: S.Store<D, B>,
  h: Holds(~D, ~B, ~eq, s, S.objects(~D, ~B, ~H, t)), hf: {S.fits(B, fuel, t) == True{} : Bool}
) -> {L(~D, ~B, ~eq, fuel, s, S.hash(~D, ~B, ~H, t)) == Some{t} : Maybe<&2, S.Tree<B>>}:
  match fuel t:
    case 0n t:
      Empty.absurd({L(~D, ~B, ~eq, 0n, s, S.hash(~D, ~B, ~H, t)) == Some{t} : Maybe<&2, S.Tree<B>>}, false_ne_true(hf))
    case 1n+p S.TFile{+b}:
      (hd, hu) = h
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, s, H(S.OFile{b})), Some{S.OFile{b}}, hd) : {S.load.go(~D, ~B, ~eq, 1n+p, s, _) == Some{S.TFile{b}} : Maybe<&2, S.Tree<B>>}
      {==}
    case 1n+p S.TEnd{}:
      (hd, hu) = h
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, s, H(S.OEnd{})), Some{S.OEnd{}}, hd) : {S.load.go(~D, ~B, ~eq, 1n+p, s, _) == Some{S.TEnd{}} : Maybe<&2, S.Tree<B>>}
      {==}
    case 1n+(+p) S.TItem{+n, +c, +r}:
      +hf = hf
      +o = {S.OItem{n, S.hash(~D, ~B, ~H, c), S.hash(~D, ~B, ~H, r)} : S.Obj<D, B>}
      objects_load.item(~D, ~B, ~H, ~eq, p, n, c, r, s,
        holds_split(~D, ~B, ~eq, S.objects(~D, ~B, ~H, c), Cat(D, B, S.objects(~D, ~B, ~H, r), S.StCon{H(o), o, S.StNil{}}), s, h),
        hc => objects_load(~D, ~B, ~H, ~eq, p, c, s, hc, and_l(S.fits(B, p, c), S.fits(B, p, r), hf)),
        hr => objects_load(~D, ~B, ~H, ~eq, p, r, s, hr, and_r(S.fits(B, p, c), S.fits(B, p, r), hf)))

def Laws.build_load(D, B, H, eq, sound, refl, inj, t, s, fuel, hs, hf):
  +t = t
  +s = s
  objects_load(~D, ~B, ~H, ~eq, fuel, t, A(~D, ~B, ~eq, S.objects(~D, ~B, ~H, t), s),
    apply_holds(~D, ~B, ~H, ~eq, ~sound, ~refl, ~inj, S.objects(~D, ~B, ~H, t), s, hs, ok_objects(~D, ~B, ~H, t)),
    hf)

def HashM(~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, m: Maybe<&2, S.Tree<B>>, d: D) -> Type:
  match m:
    case None{}:
      Unit
    case Some{t}:
      {S.hash(~D, ~B, ~H, t) == d : D}

def load_hash.item(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, mc: Maybe<&2, S.Tree<B>>, mr: Maybe<&2, S.Tree<B>>,
  +n: String, +c: D, +r: D, -d: D,
  ihc: HashM(~D, ~B, ~H, mc, c), ihr: HashM(~D, ~B, ~H, mr, r), hd: {d == H(S.OItem{n, c, r}) : D}
) -> HashM(~D, ~B, ~H, S.Tree.item(B, n, mc, mr), d):
  match mc mr:
    case Some{+x} Some{+y}:
      %Equal.sym(D, S.hash(~D, ~B, ~H, x), c, ihc) : {H(S.OItem{n, _, S.hash(~D, ~B, ~H, y)}) == d : D}
      %Equal.sym(D, S.hash(~D, ~B, ~H, y), r, ihr) : {H(S.OItem{n, c, _}) == d : D}
      Equal.sym(D, d, H(S.OItem{n, c, r}), hd)
    case Some{x} None{}:
      Unit{}
    case None{} mr:
      Unit{}

def load_hash.go(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq),
  fuel: Nat, +s: S.Store<D, B>, +d: D, m: Maybe<&2, S.Obj<D, B>>,
  hm: {G(~D, ~B, ~eq, s, d) == m : Maybe<&2, S.Obj<D, B>>}, +hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}
) -> HashM(~D, ~B, ~H, S.load.go(~D, ~B, ~eq, fuel, s, m), d):
  match fuel m:
    case 0n m:
      Unit{}
    case 1n+p None{}:
      Unit{}
    case 1n+p Some{S.OFile{+b}}:
      Equal.sym(D, d, H(S.OFile{b}), get_valid(~D, ~B, ~H, ~eq, ~sound, s, d, S.OFile{b}, hs, hm))
    case 1n+p Some{S.OEnd{}}:
      Equal.sym(D, d, H(S.OEnd{}), get_valid(~D, ~B, ~H, ~eq, ~sound, s, d, S.OEnd{}, hs, hm))
    case 1n+(+p) Some{S.OItem{+n, +c, +r}}:
      load_hash.item(~D, ~B, ~H,
        S.load.go(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), S.load.go(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r)), n, c, r, d,
        load_hash.go(~D, ~B, ~H, ~eq, ~sound, p, s, c, G(~D, ~B, ~eq, s, c), {==}, hs),
        load_hash.go(~D, ~B, ~H, ~eq, ~sound, p, s, r, G(~D, ~B, ~eq, s, r), {==}, hs),
        get_valid(~D, ~B, ~H, ~eq, ~sound, s, d, S.OItem{n, c, r}, hs, hm))

def Laws.load_hash(D, B, H, eq, sound, fuel, s, d, t, hs, hl):
  +s = s
  +d = d
  %hl : HashM(~D, ~B, ~H, _, d)
  load_hash.go(~D, ~B, ~H, ~eq, ~sound, fuel, s, d, G(~D, ~B, ~eq, s, d), {==}, hs)

def HoldsM(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: S.Store<D, B>, m: Maybe<&2, S.Store<D, B>>) -> Type:
  match m:
    case None{}:
      Unit
    case Some{xs}:
      Holds(~D, ~B, ~eq, s, xs)

def IfSome(-D: Data, -B: Data, m: Maybe<&2, S.Store<D, B>>, T: Type) -> Type:
  match m:
    case None{}:
      Unit
    case Some{xs}:
      T

def C(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: S.Store<D, B>, +d: D, m: Maybe<&2, S.Obj<D, B>>) -> Maybe<&2, S.Store<D, B>>:
  S.closure.go(~D, ~B, ~eq, fuel, s, d, m)

def closure_holds.item(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, mc: Maybe<&2, S.Store<D, B>>, mr: Maybe<&2, S.Store<D, B>>,
  +s: S.Store<D, B>, -d: D, -o: S.Obj<D, B>,
  hm: {G(~D, ~B, ~eq, s, d) == Some{o} : Maybe<&2, S.Obj<D, B>>}, ihc: HoldsM(~D, ~B, ~eq, s, mc), ihr: HoldsM(~D, ~B, ~eq, s, mr)
) -> HoldsM(~D, ~B, ~eq, s, S.closure.item(D, B, d, o, mc, mr)):
  match mc mr:
    case Some{+xs} Some{ys}:
      (hm, holds_cat(~D, ~B, ~eq, xs, ys, s, ihc, ihr))
    case Some{xs} None{}:
      Unit{}
    case None{} mr:
      Unit{}

# Every object closure lists is what get finds in s.
def closure_holds(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: S.Store<D, B>, +d: D, m: Maybe<&2, S.Obj<D, B>>,
  hm: {G(~D, ~B, ~eq, s, d) == m : Maybe<&2, S.Obj<D, B>>}
) -> HoldsM(~D, ~B, ~eq, s, C(~D, ~B, ~eq, fuel, s, d, m)):
  match fuel m:
    case 0n m:
      Unit{}
    case 1n+p None{}:
      Unit{}
    case 1n+p Some{S.OFile{b}}:
      (hm, Unit{})
    case 1n+p Some{S.OEnd{}}:
      (hm, Unit{})
    case 1n+(+p) Some{S.OItem{+n, +c, +r}}:
      closure_holds.item(~D, ~B, ~eq, C(~D, ~B, ~eq, p, s, c, G(~D, ~B, ~eq, s, c)), C(~D, ~B, ~eq, p, s, r, G(~D, ~B, ~eq, s, r)),
        s, d, S.OItem{n, c, r}, hm,
        closure_holds(~D, ~B, ~eq, p, s, c, G(~D, ~B, ~eq, s, c), {==}),
        closure_holds(~D, ~B, ~eq, p, s, r, G(~D, ~B, ~eq, s, r), {==}))

def holds_ok(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq),
  xs: S.Store<D, B>, +s: S.Store<D, B>, +hs: {V(~D, ~B, ~H, ~eq, s) == True{} : Bool}, h: Holds(~D, ~B, ~eq, s, xs)
) -> Ok(~D, ~B, ~H, xs):
  match xs:
    case S.StNil{}:
      Unit{}
    case S.StCon{+d, +o, r}:
      (hd, hr) = h
      (get_valid(~D, ~B, ~H, ~eq, ~sound, s, d, o, hs, hd), holds_ok(~D, ~B, ~H, ~eq, ~sound, r, s, hs, hr))

def LG(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: S.Store<D, B>, m: Maybe<&2, S.Obj<D, B>>) -> Maybe<&2, S.Tree<B>>:
  S.load.go(~D, ~B, ~eq, fuel, s, m)

def load_agree.both(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +p: Nat, +n: String, +c: D, +r: D, +s: S.Store<D, B>, +t: S.Store<D, B>, +d: D,
  -xs: S.Store<D, B>, -ys: S.Store<D, B>,
  hd: {G(~D, ~B, ~eq, t, d) == Some{S.OItem{n, c, r}} : Maybe<&2, S.Obj<D, B>>},
  hp: Holds(~D, ~B, ~eq, t, xs) & Holds(~D, ~B, ~eq, t, ys),
  ihc: Holds(~D, ~B, ~eq, t, xs) -> {LG(~D, ~B, ~eq, p, t, G(~D, ~B, ~eq, t, c)) == LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)) : Maybe<&2, S.Tree<B>>},
  ihr: Holds(~D, ~B, ~eq, t, ys) -> {LG(~D, ~B, ~eq, p, t, G(~D, ~B, ~eq, t, r)) == LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r)) : Maybe<&2, S.Tree<B>>}
) -> {LG(~D, ~B, ~eq, 1n+p, t, G(~D, ~B, ~eq, t, d)) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r))) : Maybe<&2, S.Tree<B>>}:
  (hx, hy) = hp
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, t, d), Some{S.OItem{n, c, r}}, hd) : {LG(~D, ~B, ~eq, 1n+p, t, _) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r))) : Maybe<&2, S.Tree<B>>}
  %Equal.sym(Maybe<&2, S.Tree<B>>, LG(~D, ~B, ~eq, p, t, G(~D, ~B, ~eq, t, c)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), ihc(hx)) : {S.Tree.item(B, n, _, LG(~D, ~B, ~eq, p, t, G(~D, ~B, ~eq, t, r))) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r))) : Maybe<&2, S.Tree<B>>}
  %Equal.sym(Maybe<&2, S.Tree<B>>, LG(~D, ~B, ~eq, p, t, G(~D, ~B, ~eq, t, r)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r)), ihr(hy)) : {S.Tree.item(B, n, LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), _) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r))) : Maybe<&2, S.Tree<B>>}
  {==}

def load_agree.item(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, mc: Maybe<&2, S.Store<D, B>>, mr: Maybe<&2, S.Store<D, B>>,
  +p: Nat, +n: String, +c: D, +r: D, +s: S.Store<D, B>, +t: S.Store<D, B>, +d: D,
  h: HoldsM(~D, ~B, ~eq, t, S.closure.item(D, B, d, S.OItem{n, c, r}, mc, mr)),
  ihc: HoldsM(~D, ~B, ~eq, t, mc) -> IfSome(D, B, mc, {LG(~D, ~B, ~eq, p, t, G(~D, ~B, ~eq, t, c)) == LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)) : Maybe<&2, S.Tree<B>>}),
  ihr: HoldsM(~D, ~B, ~eq, t, mr) -> IfSome(D, B, mr, {LG(~D, ~B, ~eq, p, t, G(~D, ~B, ~eq, t, r)) == LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r)) : Maybe<&2, S.Tree<B>>})
) -> IfSome(D, B, S.closure.item(D, B, d, S.OItem{n, c, r}, mc, mr),
     {LG(~D, ~B, ~eq, 1n+p, t, G(~D, ~B, ~eq, t, d)) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r))) : Maybe<&2, S.Tree<B>>}):
  match mc mr:
    case Some{+xs} Some{+ys}:
      (hd, hrest) = h
      load_agree.both(~D, ~B, ~eq, p, n, c, r, s, t, d, xs, ys, hd, holds_split(~D, ~B, ~eq, xs, ys, t, hrest), ihc, ihr)
    case Some{xs} None{}:
      Unit{}
    case None{} mr:
      Unit{}

# A store t that holds the closure of d in s loads d as s does.
def load_agree(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: S.Store<D, B>, +t: S.Store<D, B>, +d: D, m: Maybe<&2, S.Obj<D, B>>,
  h: HoldsM(~D, ~B, ~eq, t, C(~D, ~B, ~eq, fuel, s, d, m))
) -> IfSome(D, B, C(~D, ~B, ~eq, fuel, s, d, m), {LG(~D, ~B, ~eq, fuel, t, G(~D, ~B, ~eq, t, d)) == LG(~D, ~B, ~eq, fuel, s, m) : Maybe<&2, S.Tree<B>>}):
  match fuel m:
    case 0n m:
      Unit{}
    case 1n+p None{}:
      Unit{}
    case 1n+p Some{S.OFile{+b}}:
      (hd, hu) = h
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, t, d), Some{S.OFile{b}}, hd) : {LG(~D, ~B, ~eq, 1n+p, t, _) == Some{S.TFile{b}} : Maybe<&2, S.Tree<B>>}
      {==}
    case 1n+p Some{S.OEnd{}}:
      (hd, hu) = h
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, t, d), Some{S.OEnd{}}, hd) : {LG(~D, ~B, ~eq, 1n+p, t, _) == Some{S.TEnd{}} : Maybe<&2, S.Tree<B>>}
      {==}
    case 1n+(+p) Some{S.OItem{+n, +c, +r}}:
      load_agree.item(~D, ~B, ~eq, C(~D, ~B, ~eq, p, s, c, G(~D, ~B, ~eq, s, c)), C(~D, ~B, ~eq, p, s, r, G(~D, ~B, ~eq, s, r)),
        p, n, c, r, s, t, d, h,
        hc => load_agree(~D, ~B, ~eq, p, s, t, c, G(~D, ~B, ~eq, s, c), hc),
        hr => load_agree(~D, ~B, ~eq, p, s, t, r, G(~D, ~B, ~eq, s, r), hr))

def N(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +xs: S.Store<D, B>, +t: S.Store<D, B>) -> S.Store<D, B>:
  S.need(~D, ~B, ~eq, xs, t)

def need_apply.if(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, c: Bool, +d: D, +o: S.Obj<D, B>, +rest: S.Store<D, B>, +t: S.Store<D, B>,
  +hc: {Has(~D, ~B, ~eq, t, d) == c : Bool},
  ih: @u: S.Store<D, B> -> {A(~D, ~B, ~eq, N(~D, ~B, ~eq, rest, u), u) == A(~D, ~B, ~eq, rest, u) : S.Store<D, B>}
) -> {A(~D, ~B, ~eq, S.need.go(~D, ~B, ~eq, S.StCon{d, o, rest}, t, c), t) == A(~D, ~B, ~eq, S.StCon{d, o, rest}, t) : S.Store<D, B>}:
  match c:
    case True{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, t, d, o), t, put_has(~D, ~B, ~eq, t, d, o, hc)) : {A(~D, ~B, ~eq, N(~D, ~B, ~eq, rest, t), t) == A(~D, ~B, ~eq, rest, _) : S.Store<D, B>}
      ih(t)
    case False{}:
      ih(P(~D, ~B, ~eq, t, d, o))

# Applying the needed entries gives the same store as applying all of them.
def need_apply(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>, +t: S.Store<D, B>
) -> {A(~D, ~B, ~eq, N(~D, ~B, ~eq, xs, t), t) == A(~D, ~B, ~eq, xs, t) : S.Store<D, B>}:
  match xs:
    case S.StNil{}:
      {==}
    case S.StCon{+d, +o, +rest}:
      need_apply.if(~D, ~B, ~eq, Has(~D, ~B, ~eq, t, d), d, o, rest, t, {==}, u => need_apply(~D, ~B, ~eq, rest, u))

def CL(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: S.Store<D, B>, +d: D) -> Maybe<&2, S.Store<D, B>>:
  S.closure(~D, ~B, ~eq, fuel, s, d)

def sync.of(
  ~D: Data, ~B: Data, ~H: S.Obj<D, B> -> D, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq), ~inj: Inj(~D, ~B, ~H),
  mc: Maybe<&2, S.Store<D, B>>, +fuel: Nat, +src: S.Store<D, B>, +dst: S.Store<D, B>, +root: D, -ys: S.Store<D, B>,
  +hmc: {CL(~D, ~B, ~eq, fuel, src, root) == mc : Maybe<&2, S.Store<D, B>>},
  +hs: {V(~D, ~B, ~H, ~eq, src) == True{} : Bool}, +hd: {V(~D, ~B, ~H, ~eq, dst) == True{} : Bool},
  hp: {S.plan.of(~D, ~B, ~eq, dst, mc) == Some{ys} : Maybe<&2, S.Store<D, B>>}
) -> {L(~D, ~B, ~eq, fuel, A(~D, ~B, ~eq, ys, dst), root) == L(~D, ~B, ~eq, fuel, src, root) : Maybe<&2, S.Tree<B>>}:
  match mc:
    case None{}:
      Empty.absurd({L(~D, ~B, ~eq, fuel, A(~D, ~B, ~eq, ys, dst), root) == L(~D, ~B, ~eq, fuel, src, root) : Maybe<&2, S.Tree<B>>},
        none_ne_some(S.Store<D, B>, ys, hp))
    case Some{+xs}:
      %some_inj(S.Store<D, B>, N(~D, ~B, ~eq, xs, dst), ys, hp) : {L(~D, ~B, ~eq, fuel, A(~D, ~B, ~eq, _, dst), root) == L(~D, ~B, ~eq, fuel, src, root) : Maybe<&2, S.Tree<B>>}
      %Equal.sym(S.Store<D, B>, A(~D, ~B, ~eq, N(~D, ~B, ~eq, xs, dst), dst), A(~D, ~B, ~eq, xs, dst), need_apply(~D, ~B, ~eq, xs, dst)) : {L(~D, ~B, ~eq, fuel, _, root) == L(~D, ~B, ~eq, fuel, src, root) : Maybe<&2, S.Tree<B>>}
      +t = A(~D, ~B, ~eq, xs, dst)
      %hmc : IfSome(D, B, _, {L(~D, ~B, ~eq, fuel, t, root) == L(~D, ~B, ~eq, fuel, src, root) : Maybe<&2, S.Tree<B>>})
      load_agree(~D, ~B, ~eq, fuel, src, t, root, G(~D, ~B, ~eq, src, root),
        (%Equal.sym(Maybe<&2, S.Store<D, B>>, CL(~D, ~B, ~eq, fuel, src, root), Some{xs}, hmc) : HoldsM(~D, ~B, ~eq, t, _)
         apply_holds(~D, ~B, ~H, ~eq, ~sound, ~refl, ~inj, xs, dst, hd, holds_ok(~D, ~B, ~H, ~eq, ~sound, xs, src, hs,
           (%hmc : HoldsM(~D, ~B, ~eq, src, _)
            closure_holds(~D, ~B, ~eq, fuel, src, root, G(~D, ~B, ~eq, src, root), {==}))))))

def Laws.sync_load(D, B, H, eq, sound, refl, inj, fuel, src, dst, root, ys, hs, hd, hp):
  +fuel = fuel
  +src = src
  +root = root
  sync.of(~D, ~B, ~H, ~eq, ~sound, ~refl, ~inj, CL(~D, ~B, ~eq, fuel, src, root), fuel, src, dst, root, ys, {==}, hs, hd, hp)

def IsS(-D: Data, -B: Data, m: Maybe<&2, S.Store<D, B>>) -> Bool:
  Maybe.is_some(&2, S.Store<D, B>, m)

def IsT(-B: Data, m: Maybe<&2, S.Tree<B>>) -> Bool:
  Maybe.is_some(&2, S.Tree<B>, m)

def some_agree.r(
  -D: Data, -B: Data, mr: Maybe<&2, S.Store<D, B>>, lr: Maybe<&2, S.Tree<B>>, -d: D, -o: S.Obj<D, B>, -xs: S.Store<D, B>, -n: String, -tc: S.Tree<B>,
  h: {IsS(D, B, mr) == IsT(B, lr) : Bool}
) -> {IsS(D, B, S.closure.item(D, B, d, o, Some{xs}, mr)) == IsT(B, S.Tree.item(B, n, Some{tc}, lr)) : Bool}:
  match mr lr:
    case Some{y} Some{z}:
      {==}
    case Some{y} None{}:
      Empty.absurd({True{} == False{} : Bool}, true_ne_false(h))
    case None{} Some{z}:
      Empty.absurd({False{} == True{} : Bool}, false_ne_true(h))
    case None{} None{}:
      {==}

def some_agree.item(
  -D: Data, -B: Data, mc: Maybe<&2, S.Store<D, B>>, lc: Maybe<&2, S.Tree<B>>, mr: Maybe<&2, S.Store<D, B>>, lr: Maybe<&2, S.Tree<B>>,
  -d: D, -o: S.Obj<D, B>, -n: String,
  hc: {IsS(D, B, mc) == IsT(B, lc) : Bool}, hr: {IsS(D, B, mr) == IsT(B, lr) : Bool}
) -> {IsS(D, B, S.closure.item(D, B, d, o, mc, mr)) == IsT(B, S.Tree.item(B, n, lc, lr)) : Bool}:
  match mc lc:
    case Some{xs} Some{tc}:
      some_agree.r(D, B, mr, lr, d, o, xs, n, tc, hr)
    case Some{xs} None{}:
      Empty.absurd({IsS(D, B, S.closure.item(D, B, d, o, Some{xs}, mr)) == False{} : Bool}, true_ne_false(hc))
    case None{} Some{tc}:
      Empty.absurd({False{} == IsT(B, S.Tree.item(B, n, Some{tc}, lr)) : Bool}, false_ne_true(hc))
    case None{} None{}:
      {==}

# closure succeeds exactly when load does.
def closure_some(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: S.Store<D, B>, +d: D, m: Maybe<&2, S.Obj<D, B>>
) -> {IsS(D, B, C(~D, ~B, ~eq, fuel, s, d, m)) == IsT(B, LG(~D, ~B, ~eq, fuel, s, m)) : Bool}:
  match fuel m:
    case 0n m:
      {==}
    case 1n+p None{}:
      {==}
    case 1n+p Some{S.OFile{b}}:
      {==}
    case 1n+p Some{S.OEnd{}}:
      {==}
    case 1n+(+p) Some{S.OItem{+n, +c, +r}}:
      some_agree.item(D, B, C(~D, ~B, ~eq, p, s, c, G(~D, ~B, ~eq, s, c)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, c)),
        C(~D, ~B, ~eq, p, s, r, G(~D, ~B, ~eq, s, r)), LG(~D, ~B, ~eq, p, s, G(~D, ~B, ~eq, s, r)), d, S.OItem{n, c, r}, n,
        closure_some(~D, ~B, ~eq, p, s, c, G(~D, ~B, ~eq, s, c)), closure_some(~D, ~B, ~eq, p, s, r, G(~D, ~B, ~eq, s, r)))

def plan_of_some(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +dst: S.Store<D, B>, m: Maybe<&2, S.Store<D, B>>) -> {IsS(D, B, S.plan.of(~D, ~B, ~eq, dst, m)) == IsS(D, B, m) : Bool}:
  match m:
    case None{}:
      {==}
    case Some{xs}:
      {==}

def Laws.plan_some(D, B, eq, fuel, src, dst, root):
  +fuel = fuel
  +src = src
  +root = root
  Equal.trans(Bool, IsS(D, B, S.plan(~D, ~B, ~eq, fuel, src, dst, root)), IsS(D, B, CL(~D, ~B, ~eq, fuel, src, root)), IsT(B, L(~D, ~B, ~eq, fuel, src, root)),
    plan_of_some(~D, ~B, ~eq, dst, CL(~D, ~B, ~eq, fuel, src, root)),
    closure_some(~D, ~B, ~eq, fuel, src, root, G(~D, ~B, ~eq, src, root)))

def or_true_r(a: Bool) -> {Bool.or(a, True{}) == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      {==}

def M(~D: Data, ~B: Data, ~eq: D -> D -> Bool, ls: S.Store<D, B>, +d: D) -> Bool:
  S.mem(~D, ~B, ~eq, ls, d)

def mem_cons(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +k: D, -o: S.Obj<D, B>, +ls: S.Store<D, B>, +d: D,
  h: {M(~D, ~B, ~eq, ls, d) == True{} : Bool}
) -> {M(~D, ~B, ~eq, S.StCon{k, o, ls}, d) == True{} : Bool}:
  %Equal.sym(Bool, M(~D, ~B, ~eq, ls, d), True{}, h) : {Bool.or(eq(d, k), _) == True{} : Bool}
  or_true_r(eq(d, k))

def mem_cat_r(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>, +ys: S.Store<D, B>, +d: D,
  h: {M(~D, ~B, ~eq, ys, d) == True{} : Bool}
) -> {M(~D, ~B, ~eq, Cat(D, B, xs, ys), d) == True{} : Bool}:
  match xs:
    case S.StNil{}:
      h
    case S.StCon{k, o, +r}:
      mem_cons(~D, ~B, ~eq, k, o, Cat(D, B, r, ys), d, mem_cat_r(~D, ~B, ~eq, r, ys, d, h))

# Every digest of xs is in ls.
def AllIn(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +ls: S.Store<D, B>, xs: S.Store<D, B>) -> Type:
  match xs:
    case S.StNil{}:
      Unit
    case S.StCon{d, o, r}:
      {M(~D, ~B, ~eq, ls, d) == True{} : Bool} & AllIn(~D, ~B, ~eq, ls, r)

def allin_cons(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +k: D, +o: S.Obj<D, B>, +ls: S.Store<D, B>, xs: S.Store<D, B>,
  h: AllIn(~D, ~B, ~eq, ls, xs)
) -> AllIn(~D, ~B, ~eq, S.StCon{k, o, ls}, xs):
  match xs:
    case S.StNil{}:
      Unit{}
    case S.StCon{+d, x, r}:
      (hd, hr) = h
      (mem_cons(~D, ~B, ~eq, k, o, ls, d, hd), allin_cons(~D, ~B, ~eq, k, o, ls, r, hr))

def allin_cat_r(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +xs: S.Store<D, B>, +ys: S.Store<D, B>, zs: S.Store<D, B>,
  h: AllIn(~D, ~B, ~eq, ys, zs)
) -> AllIn(~D, ~B, ~eq, Cat(D, B, xs, ys), zs):
  match zs:
    case S.StNil{}:
      Unit{}
    case S.StCon{+d, x, r}:
      (hd, hr) = h
      (mem_cat_r(~D, ~B, ~eq, xs, ys, d, hd), allin_cat_r(~D, ~B, ~eq, xs, ys, r, hr))

def allin_prefix(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~refl: Refl(~D, ~eq), xs: S.Store<D, B>, +zs: S.Store<D, B>
) -> AllIn(~D, ~B, ~eq, Cat(D, B, xs, zs), xs):
  match xs:
    case S.StNil{}:
      Unit{}
    case S.StCon{+k, +o, +r}:
      ((%Equal.sym(Bool, eq(k, k), True{}, refl(k)) : {Bool.or(_, M(~D, ~B, ~eq, Cat(D, B, r, zs), k)) == True{} : Bool}
        {==}),
       allin_cons(~D, ~B, ~eq, k, o, Cat(D, B, r, zs), r, allin_prefix(~D, ~B, ~eq, ~refl, r, zs)))

def InM(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +ls: S.Store<D, B>, m: Maybe<&2, S.Store<D, B>>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{xs}:
      AllIn(~D, ~B, ~eq, ls, xs)

def inm_cat_r(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, +xs: S.Store<D, B>, +ys: S.Store<D, B>, m: Maybe<&2, S.Store<D, B>>,
  h: InM(~D, ~B, ~eq, ys, m)
) -> InM(~D, ~B, ~eq, Cat(D, B, xs, ys), m):
  match m:
    case None{}:
      h
    case Some{zs}:
      allin_cat_r(~D, ~B, ~eq, xs, ys, zs, h)

def Live(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +fuel: Nat, +s: S.Store<D, B>, roots: List<&2, D>) -> Maybe<&2, S.Store<D, B>>:
  S.live(~D, ~B, ~eq, fuel, s, roots)

def Mem(~D: Data, ~eq: D -> D -> Bool, xs: List<&2, D>, +d: D) -> Bool:
  Laws.member(~D, ~eq, xs, d)

def live_in.pick(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq),
  c: Bool, +fuel: Nat, +s: S.Store<D, B>, +x: D, -t: List<&2, D>, +r: D, +xs: S.Store<D, B>, +ys: S.Store<D, B>,
  +hc: {eq(r, x) == c : Bool}, hmx: {CL(~D, ~B, ~eq, fuel, s, x) == Some{xs} : Maybe<&2, S.Store<D, B>>},
  hr: {Bool.or(eq(r, x), Mem(~D, ~eq, t, r)) == True{} : Bool},
  ih: @lt: S.Store<D, B> -> {Mem(~D, ~eq, t, r) == True{} : Bool} -> {Live(~D, ~B, ~eq, fuel, s, t) == Some{lt} : Maybe<&2, S.Store<D, B>>} -> InM(~D, ~B, ~eq, lt, CL(~D, ~B, ~eq, fuel, s, r)),
  hmt: {Live(~D, ~B, ~eq, fuel, s, t) == Some{ys} : Maybe<&2, S.Store<D, B>>}
) -> InM(~D, ~B, ~eq, Cat(D, B, xs, ys), CL(~D, ~B, ~eq, fuel, s, r)):
  match c:
    case True{}:
      %Equal.sym(D, r, x, sound(r, x, hc)) : InM(~D, ~B, ~eq, Cat(D, B, xs, ys), CL(~D, ~B, ~eq, fuel, s, _))
      %Equal.sym(Maybe<&2, S.Store<D, B>>, CL(~D, ~B, ~eq, fuel, s, x), Some{xs}, hmx) : InM(~D, ~B, ~eq, Cat(D, B, xs, ys), _)
      allin_prefix(~D, ~B, ~eq, ~refl, xs, ys)
    case False{}:
      inm_cat_r(~D, ~B, ~eq, xs, ys, CL(~D, ~B, ~eq, fuel, s, r),
        ih(ys, (%hc : {Bool.or(_, Mem(~D, ~eq, t, r)) == True{} : Bool}
          hr), hmt))

def live_in.cat(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq),
  mx: Maybe<&2, S.Store<D, B>>, mt: Maybe<&2, S.Store<D, B>>, +fuel: Nat, +s: S.Store<D, B>, +x: D, -t: List<&2, D>, +r: D, -ls: S.Store<D, B>,
  hmx: {CL(~D, ~B, ~eq, fuel, s, x) == mx : Maybe<&2, S.Store<D, B>>},
  hmt: {Live(~D, ~B, ~eq, fuel, s, t) == mt : Maybe<&2, S.Store<D, B>>},
  hl: {S.live.cat(D, B, mx, mt) == Some{ls} : Maybe<&2, S.Store<D, B>>},
  hr: {Bool.or(eq(r, x), Mem(~D, ~eq, t, r)) == True{} : Bool},
  ih: @lt: S.Store<D, B> -> {Mem(~D, ~eq, t, r) == True{} : Bool} -> {Live(~D, ~B, ~eq, fuel, s, t) == Some{lt} : Maybe<&2, S.Store<D, B>>} -> InM(~D, ~B, ~eq, lt, CL(~D, ~B, ~eq, fuel, s, r))
) -> InM(~D, ~B, ~eq, ls, CL(~D, ~B, ~eq, fuel, s, r)):
  match mx mt:
    case Some{+xs} Some{+ys}:
      %some_inj(S.Store<D, B>, Cat(D, B, xs, ys), ls, hl) : InM(~D, ~B, ~eq, _, CL(~D, ~B, ~eq, fuel, s, r))
      live_in.pick(~D, ~B, ~eq, ~sound, ~refl, eq(r, x), fuel, s, x, t, r, xs, ys, {==}, hmx, hr, ih, hmt)
    case Some{xs} None{}:
      Empty.absurd(InM(~D, ~B, ~eq, ls, CL(~D, ~B, ~eq, fuel, s, r)), none_ne_some(S.Store<D, B>, ls, hl))
    case None{} mt:
      Empty.absurd(InM(~D, ~B, ~eq, ls, CL(~D, ~B, ~eq, fuel, s, r)), none_ne_some(S.Store<D, B>, ls, hl))

# A retained root's closure lies inside the live set.
def live_in(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq),
  +fuel: Nat, +s: S.Store<D, B>, roots: List<&2, D>, +r: D, -ls: S.Store<D, B>,
  hr: {Mem(~D, ~eq, roots, r) == True{} : Bool}, hl: {Live(~D, ~B, ~eq, fuel, s, roots) == Some{ls} : Maybe<&2, S.Store<D, B>>}
) -> InM(~D, ~B, ~eq, ls, CL(~D, ~B, ~eq, fuel, s, r)):
  match roots:
    case Nil{}:
      Empty.absurd(InM(~D, ~B, ~eq, ls, CL(~D, ~B, ~eq, fuel, s, r)), false_ne_true(hr))
    case Con{+x, +t}:
      live_in.cat(~D, ~B, ~eq, ~sound, ~refl, CL(~D, ~B, ~eq, fuel, s, x), Live(~D, ~B, ~eq, fuel, s, t), fuel, s, x, t, r, ls,
        {==}, {==}, hl, hr, lt => h1 => h2 => live_in(~D, ~B, ~eq, ~sound, ~refl, fuel, s, t, r, lt, h1, h2))

def K(~D: Data, ~B: Data, ~eq: D -> D -> Bool, s: S.Store<D, B>, +ls: S.Store<D, B>) -> S.Store<D, B>:
  S.keep(~D, ~B, ~eq, s, ls)

def keep_get.live(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, c: Bool, +k: D, +o: S.Obj<D, B>, +kr: S.Store<D, B>, +r: S.Store<D, B>, +d: D,
  +hc: {eq(d, k) == c : Bool}, ih: {G(~D, ~B, ~eq, kr, d) == G(~D, ~B, ~eq, r, d) : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, S.StCon{k, o, kr}, d) == G(~D, ~B, ~eq, S.StCon{k, o, r}, d) : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      Equal.trans(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, kr}, d), Some{o}, G(~D, ~B, ~eq, S.StCon{k, o, r}, d),
        get_hit(~D, ~B, ~eq, k, o, kr, d, hc),
        Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, r}, d), Some{o}, get_hit(~D, ~B, ~eq, k, o, r, d, hc)))
    case False{}:
      Equal.trans(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, kr}, d), G(~D, ~B, ~eq, kr, d), G(~D, ~B, ~eq, S.StCon{k, o, r}, d),
        get_miss(~D, ~B, ~eq, k, o, kr, d, hc),
        Equal.trans(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, kr, d), G(~D, ~B, ~eq, r, d), G(~D, ~B, ~eq, S.StCon{k, o, r}, d), ih,
          Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, r}, d), G(~D, ~B, ~eq, r, d), get_miss(~D, ~B, ~eq, k, o, r, d, hc))))

def keep_get.dead(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), c: Bool, +k: D, +o: S.Obj<D, B>, +kr: S.Store<D, B>, +r: S.Store<D, B>, +ls: S.Store<D, B>, +d: D,
  +hc: {eq(d, k) == c : Bool}, hk: {M(~D, ~B, ~eq, ls, k) == False{} : Bool}, hm: {M(~D, ~B, ~eq, ls, d) == True{} : Bool},
  ih: {G(~D, ~B, ~eq, kr, d) == G(~D, ~B, ~eq, r, d) : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, kr, d) == G(~D, ~B, ~eq, S.StCon{k, o, r}, d) : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      Empty.absurd({G(~D, ~B, ~eq, kr, d) == G(~D, ~B, ~eq, S.StCon{k, o, r}, d) : Maybe<&2, S.Obj<D, B>>},
        false_ne_true(Equal.trans(Bool, False{}, M(~D, ~B, ~eq, ls, k), True{},
          Equal.sym(Bool, M(~D, ~B, ~eq, ls, k), False{}, hk),
          (%sound(d, k, hc) : {M(~D, ~B, ~eq, ls, _) == True{} : Bool}
           hm))))
    case False{}:
      Equal.trans(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, kr, d), G(~D, ~B, ~eq, r, d), G(~D, ~B, ~eq, S.StCon{k, o, r}, d), ih,
        Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, r}, d), G(~D, ~B, ~eq, r, d), get_miss(~D, ~B, ~eq, k, o, r, d, hc)))

def keep_get.if(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), c: Bool, +k: D, +o: S.Obj<D, B>, +r: S.Store<D, B>, +ls: S.Store<D, B>, +d: D,
  +hc: {M(~D, ~B, ~eq, ls, k) == c : Bool}, hm: {M(~D, ~B, ~eq, ls, d) == True{} : Bool},
  ih: {G(~D, ~B, ~eq, K(~D, ~B, ~eq, r, ls), d) == G(~D, ~B, ~eq, r, d) : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, S.keep.if(D, B, c, k, o, K(~D, ~B, ~eq, r, ls)), d) == G(~D, ~B, ~eq, S.StCon{k, o, r}, d) : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      keep_get.live(~D, ~B, ~eq, eq(d, k), k, o, K(~D, ~B, ~eq, r, ls), r, d, {==}, ih)
    case False{}:
      keep_get.dead(~D, ~B, ~eq, ~sound, eq(d, k), k, o, K(~D, ~B, ~eq, r, ls), r, ls, d, {==}, hc, hm, ih)

# keep leaves get unchanged on every live digest.
def keep_get(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), s: S.Store<D, B>, +ls: S.Store<D, B>, +d: D,
  +hm: {M(~D, ~B, ~eq, ls, d) == True{} : Bool}
) -> {G(~D, ~B, ~eq, K(~D, ~B, ~eq, s, ls), d) == G(~D, ~B, ~eq, s, d) : Maybe<&2, S.Obj<D, B>>}:
  match s:
    case S.StNil{}:
      {==}
    case S.StCon{+k, +o, +r}:
      keep_get.if(~D, ~B, ~eq, ~sound, M(~D, ~B, ~eq, ls, k), k, o, r, ls, d, {==}, hm, keep_get(~D, ~B, ~eq, ~sound, r, ls, d, hm))

def holds_keep(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), xs: S.Store<D, B>, +s: S.Store<D, B>, +ls: S.Store<D, B>,
  ha: AllIn(~D, ~B, ~eq, ls, xs), h: Holds(~D, ~B, ~eq, s, xs)
) -> Holds(~D, ~B, ~eq, K(~D, ~B, ~eq, s, ls), xs):
  match xs:
    case S.StNil{}:
      Unit{}
    case S.StCon{+d, +o, r}:
      (hm, har) = ha
      (hd, hr) = h
      (Equal.trans(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, K(~D, ~B, ~eq, s, ls), d), G(~D, ~B, ~eq, s, d), Some{o},
         keep_get(~D, ~B, ~eq, ~sound, s, ls, d, hm), hd),
       holds_keep(~D, ~B, ~eq, ~sound, r, s, ls, har, hr))

def gc.load(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq),
  mc: Maybe<&2, S.Store<D, B>>, +fuel: Nat, +s: S.Store<D, B>, +ls: S.Store<D, B>, +r: D,
  +hmc: {CL(~D, ~B, ~eq, fuel, s, r) == mc : Maybe<&2, S.Store<D, B>>}, hin: InM(~D, ~B, ~eq, ls, mc)
) -> {L(~D, ~B, ~eq, fuel, K(~D, ~B, ~eq, s, ls), r) == L(~D, ~B, ~eq, fuel, s, r) : Maybe<&2, S.Tree<B>>}:
  match mc:
    case None{}:
      Empty.absurd({L(~D, ~B, ~eq, fuel, K(~D, ~B, ~eq, s, ls), r) == L(~D, ~B, ~eq, fuel, s, r) : Maybe<&2, S.Tree<B>>}, hin)
    case Some{+xs}:
      +k = K(~D, ~B, ~eq, s, ls)
      %hmc : IfSome(D, B, _, {L(~D, ~B, ~eq, fuel, k, r) == L(~D, ~B, ~eq, fuel, s, r) : Maybe<&2, S.Tree<B>>})
      load_agree(~D, ~B, ~eq, fuel, s, k, r, G(~D, ~B, ~eq, s, r),
        (%Equal.sym(Maybe<&2, S.Store<D, B>>, CL(~D, ~B, ~eq, fuel, s, r), Some{xs}, hmc) : HoldsM(~D, ~B, ~eq, k, _)
         holds_keep(~D, ~B, ~eq, ~sound, xs, s, ls, hin,
           (%hmc : HoldsM(~D, ~B, ~eq, s, _)
            closure_holds(~D, ~B, ~eq, fuel, s, r, G(~D, ~B, ~eq, s, r), {==})))))

def gc.of_live(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ~refl: Refl(~D, ~eq),
  ml: Maybe<&2, S.Store<D, B>>, +fuel: Nat, +s: S.Store<D, B>, +roots: List<&2, D>, +r: D, -g: S.Store<D, B>,
  hml: {Live(~D, ~B, ~eq, fuel, s, roots) == ml : Maybe<&2, S.Store<D, B>>},
  hg: {S.gc.of(~D, ~B, ~eq, s, ml) == Some{g} : Maybe<&2, S.Store<D, B>>},
  hr: {Mem(~D, ~eq, roots, r) == True{} : Bool}
) -> {L(~D, ~B, ~eq, fuel, g, r) == L(~D, ~B, ~eq, fuel, s, r) : Maybe<&2, S.Tree<B>>}:
  match ml:
    case None{}:
      Empty.absurd({L(~D, ~B, ~eq, fuel, g, r) == L(~D, ~B, ~eq, fuel, s, r) : Maybe<&2, S.Tree<B>>}, none_ne_some(S.Store<D, B>, g, hg))
    case Some{+ls}:
      %some_inj(S.Store<D, B>, K(~D, ~B, ~eq, s, ls), g, hg) : {L(~D, ~B, ~eq, fuel, _, r) == L(~D, ~B, ~eq, fuel, s, r) : Maybe<&2, S.Tree<B>>}
      gc.load(~D, ~B, ~eq, ~sound, CL(~D, ~B, ~eq, fuel, s, r), fuel, s, ls, r, {==},
        live_in(~D, ~B, ~eq, ~sound, ~refl, fuel, s, roots, r, ls, hr, hml))

def Laws.gc_load(D, B, eq, sound, refl, fuel, s, roots, g, r, hg, hr):
  +fuel = fuel
  +s = s
  +roots = roots
  gc.of_live(~D, ~B, ~eq, ~sound, ~refl, Live(~D, ~B, ~eq, fuel, s, roots), fuel, s, roots, r, g, {==}, hg, hr)

def Laws.admit_rejects(D, B, eq, s, claimed, computed, o, he):
  %Equal.sym(Bool, eq(claimed, computed), False{}, he) : {S.admit.if(D, B, _, S.Store.put(~D, ~B, ~eq, s, claimed, o), s) == None{} : Maybe<&2, S.Store<D, B>>}
  {==}

def Laws.fixture_root():
  {==}

def Laws.fixture_build():
  {==}

def Laws.fixture_fuel():
  {==}

def Laws.fixture_dedup():
  {==}

def Laws.fixture_missing():
  {==}

def Laws.fixture_plan():
  {==}

def Laws.fixture_tamper():
  {==}

def Laws.fixture_gc():
  {==}

def Laws.fixture_index_build():
  {==}

def Laws.fixture_index_dedup():
  {==}

def Laws.fixture_index_plan():
  {==}

# ---- The index refines the list store.

def CRefl(~D: Data, ~cmp: D -> D -> Cmp) -> Type:
  @x: D -> {cmp(x, x) == EQ{} : Cmp}

def CEq(~D: Data, ~cmp: D -> D -> Cmp) -> Type:
  @x: D -> @y: D -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : D}

def CFlip(~D: Data, ~cmp: D -> D -> Cmp) -> Type:
  @x: D -> @y: D -> {cmp(y, x) == Col.flip(cmp(x, y)) : Cmp}

def CTrans(~D: Data, ~cmp: D -> D -> Cmp) -> Type:
  @x: D -> @y: D -> @z: D -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}

def Agree(~D: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool) -> Type:
  @x: D -> @y: D -> {eq(x, y) == Cmp.is_eq(cmp(x, y)) : Bool}

def cmp_eq_of(c: Cmp, h: {Cmp.is_eq(c) == True{} : Bool}) -> {c == EQ{} : Cmp}:
  match c:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_ne_true(h))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_ne_true(h))

def flip_eq(c: Cmp, h: {Col.flip(c) == EQ{} : Cmp}) -> {c == EQ{} : Cmp}:
  match c:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_ne_true(Equal.cong(Cmp, Bool, x => Cmp.is_eq(x), GT{}, EQ{}, h)))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_ne_true(Equal.cong(Cmp, Bool, x => Cmp.is_eq(x), LT{}, EQ{}, h)))

# eq is sound when it agrees with cmp and EQ means equal.
def sound_of(
  ~D: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~ceq: CEq(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  +x: D, +y: D, h: {eq(x, y) == True{} : Bool}
) -> {x == y : D}:
  ceq(x, y, cmp_eq_of(cmp(x, y), Equal.trans(Bool, Cmp.is_eq(cmp(x, y)), eq(x, y), True{},
    Equal.sym(Bool, eq(x, y), Cmp.is_eq(cmp(x, y)), agree(x, y)), h)))

def ne_of_false(
  ~D: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~cflip: CFlip(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  +d: D, +k: D, h: {eq(d, k) == False{} : Bool}
) -> {cmp(k, d) != EQ{} : Cmp}:
  e => false_ne_true(Equal.trans(Bool, False{}, eq(d, k), True{}, Equal.sym(Bool, eq(d, k), False{}, h),
    Equal.trans(Bool, eq(d, k), Cmp.is_eq(cmp(d, k)), True{}, agree(d, k),
      Equal.cong(Cmp, Bool, x => Cmp.is_eq(x), cmp(d, k), EQ{},
        flip_eq(cmp(d, k), Equal.trans(Cmp, Col.flip(cmp(d, k)), cmp(k, d), EQ{},
          Equal.sym(Cmp, cmp(k, d), Col.flip(cmp(d, k)), cflip(d, k)), e))))))

def IG(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, m: S.Index(D, B), +d: D) -> Maybe<&2, S.Obj<D, B>>:
  S.Index.get(~D, ~B, ~cmp, m, d)

def IHas(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, m: S.Index(D, B), +d: D) -> Bool:
  S.Index.has(~D, ~B, ~cmp, m, d)

def IP(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +m: S.Index(D, B), +d: D, o: S.Obj<D, B>) -> S.Index(D, B):
  S.Index.put(~D, ~B, ~cmp, m, d, o)

def OP(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, m: S.Index(D, B), +d: D, +o: S.Obj<D, B>) -> S.Index(D, B):
  OMap.OMap.put(~D, ~S.Obj<D, B>, ~cmp, m, d, o)

def IA(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, xs: S.Store<D, B>, +m: S.Index(D, B)) -> S.Index(D, B):
  S.Index.apply(~D, ~B, ~cmp, xs, m)

def ST(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, m: S.Index(D, B)) -> Bool:
  Col.searchtree(~D, ~S.Obj<D, B>, ~cmp, m)

def ihas_some(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +m: S.Index(D, B), +d: D, -x: S.Obj<D, B>,
  h: {IG(~D, ~B, ~cmp, m, d) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {IHas(~D, ~B, ~cmp, m, d) == True{} : Bool}:
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, m, d), Some{x}, h) : {Maybe.is_some(&2, S.Obj<D, B>, _) == True{} : Bool}
  {==}

def ihas_none(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +m: S.Index(D, B), +d: D,
  h: {IG(~D, ~B, ~cmp, m, d) == None{} : Maybe<&2, S.Obj<D, B>>}
) -> {IHas(~D, ~B, ~cmp, m, d) == False{} : Bool}:
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, m, d), None{}, h) : {Maybe.is_some(&2, S.Obj<D, B>, _) == False{} : Bool}
  {==}

def iput_has(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +m: S.Index(D, B), +d: D, +o: S.Obj<D, B>,
  h: {IHas(~D, ~B, ~cmp, m, d) == True{} : Bool}
) -> {IP(~D, ~B, ~cmp, m, d, o) == m : S.Index(D, B)}:
  %Equal.sym(Bool, IHas(~D, ~B, ~cmp, m, d), True{}, h) : {S.Index.put.if(~D, ~B, ~cmp, _, m, d, o) == m : S.Index(D, B)}
  {==}

def iput_new(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +m: S.Index(D, B), +d: D, +o: S.Obj<D, B>,
  h: {IHas(~D, ~B, ~cmp, m, d) == False{} : Bool}
) -> {IP(~D, ~B, ~cmp, m, d, o) == OP(~D, ~B, ~cmp, m, d, o) : S.Index(D, B)}:
  %Equal.sym(Bool, IHas(~D, ~B, ~cmp, m, d), False{}, h) : {S.Index.put.if(~D, ~B, ~cmp, _, m, d, o) == OP(~D, ~B, ~cmp, m, d, o) : S.Index(D, B)}
  {==}

def iput_tree.if(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp),
  c: Bool, +m: S.Index(D, B), tree: {ST(~D, ~B, ~cmp, m) == True{} : Bool}, +d: D, +o: S.Obj<D, B>,
  +hc: {IHas(~D, ~B, ~cmp, m, d) == c : Bool}
) -> {ST(~D, ~B, ~cmp, IP(~D, ~B, ~cmp, m, d, o)) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(S.Index(D, B), IP(~D, ~B, ~cmp, m, d, o), m, iput_has(~D, ~B, ~cmp, m, d, o, hc)) : {ST(~D, ~B, ~cmp, _) == True{} : Bool}
      tree
    case False{}:
      %Equal.sym(S.Index(D, B), IP(~D, ~B, ~cmp, m, d, o), OP(~D, ~B, ~cmp, m, d, o), iput_new(~D, ~B, ~cmp, m, d, o, hc)) : {ST(~D, ~B, ~cmp, _) == True{} : Bool}
      Col.omap_put_searchtree(~D, ~S.Obj<D, B>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, d, o)

def iput_tree(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp),
  +m: S.Index(D, B), tree: {ST(~D, ~B, ~cmp, m) == True{} : Bool}, +d: D, +o: S.Obj<D, B>
) -> {ST(~D, ~B, ~cmp, IP(~D, ~B, ~cmp, m, d, o)) == True{} : Bool}:
  iput_tree.if(~D, ~B, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, IHas(~D, ~B, ~cmp, m, d), m, tree, d, o, {==})

def iget_mono.miss(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  c: Bool, +m: S.Index(D, B), tree: {ST(~D, ~B, ~cmp, m) == True{} : Bool}, +d: D, +o: S.Obj<D, B>, +e: D, -x: S.Obj<D, B>,
  +hc: {eq(e, d) == c : Bool}, hn: {IHas(~D, ~B, ~cmp, m, d) == False{} : Bool},
  h: {IG(~D, ~B, ~cmp, m, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {IG(~D, ~B, ~cmp, OP(~D, ~B, ~cmp, m, d, o), e) == Some{x} : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      Empty.absurd({IG(~D, ~B, ~cmp, OP(~D, ~B, ~cmp, m, d, o), e) == Some{x} : Maybe<&2, S.Obj<D, B>>},
        false_ne_true(Equal.trans(Bool, False{}, IHas(~D, ~B, ~cmp, m, d), True{},
          Equal.sym(Bool, IHas(~D, ~B, ~cmp, m, d), False{}, hn),
          (%sound_of(~D, ~cmp, ~eq, ~ceq, ~agree, e, d, hc) : {IHas(~D, ~B, ~cmp, m, _) == True{} : Bool}
           ihas_some(~D, ~B, ~cmp, m, e, x, h)))))
    case False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, OP(~D, ~B, ~cmp, m, d, o), e), IG(~D, ~B, ~cmp, m, e),
        Col.omap_get_put_other_key(~D, ~S.Obj<D, B>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, d, e,
          ne_of_false(~D, ~cmp, ~eq, ~cflip, ~agree, e, d, hc), o)) : {_ == Some{x} : Maybe<&2, S.Obj<D, B>>}
      h

def iget_mono.if(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  c: Bool, +m: S.Index(D, B), tree: {ST(~D, ~B, ~cmp, m) == True{} : Bool}, +d: D, +o: S.Obj<D, B>, +e: D, -x: S.Obj<D, B>,
  +hc: {IHas(~D, ~B, ~cmp, m, d) == c : Bool}, h: {IG(~D, ~B, ~cmp, m, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {IG(~D, ~B, ~cmp, IP(~D, ~B, ~cmp, m, d, o), e) == Some{x} : Maybe<&2, S.Obj<D, B>>}:
  match c:
    case True{}:
      %Equal.sym(S.Index(D, B), IP(~D, ~B, ~cmp, m, d, o), m, iput_has(~D, ~B, ~cmp, m, d, o, hc)) : {IG(~D, ~B, ~cmp, _, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
      h
    case False{}:
      %Equal.sym(S.Index(D, B), IP(~D, ~B, ~cmp, m, d, o), OP(~D, ~B, ~cmp, m, d, o), iput_new(~D, ~B, ~cmp, m, d, o, hc)) : {IG(~D, ~B, ~cmp, _, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
      iget_mono.miss(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, eq(e, d), m, tree, d, o, e, x, {==}, hc, h)

def iapply_mono(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  xs: S.Store<D, B>, +m: S.Index(D, B), +tree: {ST(~D, ~B, ~cmp, m) == True{} : Bool}, +e: D, -x: S.Obj<D, B>,
  h: {IG(~D, ~B, ~cmp, m, e) == Some{x} : Maybe<&2, S.Obj<D, B>>}
) -> {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, xs, m), e) == Some{x} : Maybe<&2, S.Obj<D, B>>}:
  match xs:
    case S.StNil{}:
      h
    case S.StCon{+d, +o, t}:
      iapply_mono(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, IP(~D, ~B, ~cmp, m, d, o),
        iput_tree(~D, ~B, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, d, o), e, x,
        iget_mono.if(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, IHas(~D, ~B, ~cmp, m, d), m, tree, d, o, e, x, {==}, h))

# The entry of xs decides a digest that the start index lacks.
def iapply_miss.step(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  ch: Bool, ce: Bool, +t: S.Store<D, B>, +m: S.Index(D, B), +tree: {ST(~D, ~B, ~cmp, m) == True{} : Bool}, +k: D, +o: S.Obj<D, B>, +e: D,
  +hch: {IHas(~D, ~B, ~cmp, m, k) == ch : Bool}, +hce: {eq(e, k) == ce : Bool},
  hn: {IG(~D, ~B, ~cmp, m, e) == None{} : Maybe<&2, S.Obj<D, B>>},
  ih: {IG(~D, ~B, ~cmp, IP(~D, ~B, ~cmp, m, k, o), e) == None{} : Maybe<&2, S.Obj<D, B>>} -> {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, t, IP(~D, ~B, ~cmp, m, k, o)), e) == G(~D, ~B, ~eq, t, e) : Maybe<&2, S.Obj<D, B>>}
) -> {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, t, IP(~D, ~B, ~cmp, m, k, o)), e) == G(~D, ~B, ~eq, S.StCon{k, o, t}, e) : Maybe<&2, S.Obj<D, B>>}:
  match ch ce:
    case True{} True{}:
      Empty.absurd({IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, t, IP(~D, ~B, ~cmp, m, k, o)), e) == G(~D, ~B, ~eq, S.StCon{k, o, t}, e) : Maybe<&2, S.Obj<D, B>>},
        false_ne_true(Equal.trans(Bool, False{}, IHas(~D, ~B, ~cmp, m, k), True{},
          Equal.sym(Bool, IHas(~D, ~B, ~cmp, m, k), False{}, ihas_none(~D, ~B, ~cmp, m, k,
            (%sound_of(~D, ~cmp, ~eq, ~ceq, ~agree, e, k, hce) : {IG(~D, ~B, ~cmp, m, _) == None{} : Maybe<&2, S.Obj<D, B>>} hn))),
          hch)))
    case False{} True{}:
      %Equal.sym(S.Index(D, B), IP(~D, ~B, ~cmp, m, k, o), OP(~D, ~B, ~cmp, m, k, o), iput_new(~D, ~B, ~cmp, m, k, o, hch)) : {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, t, _), e) == G(~D, ~B, ~eq, S.StCon{k, o, t}, e) : Maybe<&2, S.Obj<D, B>>}
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, e), Some{o}, get_hit(~D, ~B, ~eq, k, o, t, e, hce)) : {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, t, OP(~D, ~B, ~cmp, m, k, o)), e) == _ : Maybe<&2, S.Obj<D, B>>}
      iapply_mono(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, OP(~D, ~B, ~cmp, m, k, o),
        Col.omap_put_searchtree(~D, ~S.Obj<D, B>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, k, o), e, o,
        (%Equal.sym(D, e, k, sound_of(~D, ~cmp, ~eq, ~ceq, ~agree, e, k, hce)) : {IG(~D, ~B, ~cmp, OP(~D, ~B, ~cmp, m, k, o), _) == Some{o} : Maybe<&2, S.Obj<D, B>>}
         Col.omap_get_put_same(~D, ~S.Obj<D, B>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, k, o)))
    case True{} False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, e), G(~D, ~B, ~eq, t, e), get_miss(~D, ~B, ~eq, k, o, t, e, hce)) : {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, t, IP(~D, ~B, ~cmp, m, k, o)), e) == _ : Maybe<&2, S.Obj<D, B>>}
      ih((%Equal.sym(S.Index(D, B), IP(~D, ~B, ~cmp, m, k, o), m, iput_has(~D, ~B, ~cmp, m, k, o, hch)) : {IG(~D, ~B, ~cmp, _, e) == None{} : Maybe<&2, S.Obj<D, B>>} hn))
    case False{} False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, e), G(~D, ~B, ~eq, t, e), get_miss(~D, ~B, ~eq, k, o, t, e, hce)) : {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, t, IP(~D, ~B, ~cmp, m, k, o)), e) == _ : Maybe<&2, S.Obj<D, B>>}
      ih((%Equal.sym(S.Index(D, B), IP(~D, ~B, ~cmp, m, k, o), OP(~D, ~B, ~cmp, m, k, o), iput_new(~D, ~B, ~cmp, m, k, o, hch)) : {IG(~D, ~B, ~cmp, _, e) == None{} : Maybe<&2, S.Obj<D, B>>}
        (%Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, OP(~D, ~B, ~cmp, m, k, o), e), IG(~D, ~B, ~cmp, m, e),
          Col.omap_get_put_other_key(~D, ~S.Obj<D, B>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, k, e,
            ne_of_false(~D, ~cmp, ~eq, ~cflip, ~agree, e, k, hce), o)) : {_ == None{} : Maybe<&2, S.Obj<D, B>>} hn)))

# From an index that lacks e, apply finds e where xs first has it.
def iapply_miss(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  xs: S.Store<D, B>, +m: S.Index(D, B), +tree: {ST(~D, ~B, ~cmp, m) == True{} : Bool}, +e: D,
  hn: {IG(~D, ~B, ~cmp, m, e) == None{} : Maybe<&2, S.Obj<D, B>>}
) -> {IG(~D, ~B, ~cmp, IA(~D, ~B, ~cmp, xs, m), e) == G(~D, ~B, ~eq, xs, e) : Maybe<&2, S.Obj<D, B>>}:
  match xs:
    case S.StNil{}:
      hn
    case S.StCon{+k, +o, +t}:
      iapply_miss.step(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, IHas(~D, ~B, ~cmp, m, k), eq(e, k), t, m, tree, k, o, e, {==}, {==}, hn,
        hn2 => iapply_miss(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, IP(~D, ~B, ~cmp, m, k, o),
          iput_tree(~D, ~B, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, k, o), e, hn2))

def lapply_miss.step(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq),
  ch: Bool, ce: Bool, +t: S.Store<D, B>, +s: S.Store<D, B>, +k: D, +o: S.Obj<D, B>, +e: D,
  +hch: {Has(~D, ~B, ~eq, s, k) == ch : Bool}, +hce: {eq(e, k) == ce : Bool},
  hn: {G(~D, ~B, ~eq, s, e) == None{} : Maybe<&2, S.Obj<D, B>>},
  ih: {G(~D, ~B, ~eq, P(~D, ~B, ~eq, s, k, o), e) == None{} : Maybe<&2, S.Obj<D, B>>} -> {G(~D, ~B, ~eq, A(~D, ~B, ~eq, t, P(~D, ~B, ~eq, s, k, o)), e) == G(~D, ~B, ~eq, t, e) : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, A(~D, ~B, ~eq, t, P(~D, ~B, ~eq, s, k, o)), e) == G(~D, ~B, ~eq, S.StCon{k, o, t}, e) : Maybe<&2, S.Obj<D, B>>}:
  match ch ce:
    case True{} True{}:
      Empty.absurd({G(~D, ~B, ~eq, A(~D, ~B, ~eq, t, P(~D, ~B, ~eq, s, k, o)), e) == G(~D, ~B, ~eq, S.StCon{k, o, t}, e) : Maybe<&2, S.Obj<D, B>>},
        false_ne_true(Equal.trans(Bool, False{}, Has(~D, ~B, ~eq, s, k), True{},
          Equal.sym(Bool, Has(~D, ~B, ~eq, s, k), False{}, has_none(~D, ~B, ~eq, s, k,
            (%sound(e, k, hce) : {G(~D, ~B, ~eq, s, _) == None{} : Maybe<&2, S.Obj<D, B>>} hn))),
          hch)))
    case False{} True{}:
      %Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, k, o), S.StCon{k, o, s}, put_new(~D, ~B, ~eq, s, k, o, hch)) : {G(~D, ~B, ~eq, A(~D, ~B, ~eq, t, _), e) == G(~D, ~B, ~eq, S.StCon{k, o, t}, e) : Maybe<&2, S.Obj<D, B>>}
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, e), Some{o}, get_hit(~D, ~B, ~eq, k, o, t, e, hce)) : {G(~D, ~B, ~eq, A(~D, ~B, ~eq, t, S.StCon{k, o, s}), e) == _ : Maybe<&2, S.Obj<D, B>>}
      apply_mono(~D, ~B, ~eq, ~sound, t, S.StCon{k, o, s}, e, o, get_hit(~D, ~B, ~eq, k, o, s, e, hce))
    case True{} False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, e), G(~D, ~B, ~eq, t, e), get_miss(~D, ~B, ~eq, k, o, t, e, hce)) : {G(~D, ~B, ~eq, A(~D, ~B, ~eq, t, P(~D, ~B, ~eq, s, k, o)), e) == _ : Maybe<&2, S.Obj<D, B>>}
      ih((%Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, k, o), s, put_has(~D, ~B, ~eq, s, k, o, hch)) : {G(~D, ~B, ~eq, _, e) == None{} : Maybe<&2, S.Obj<D, B>>} hn))
    case False{} False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, e), G(~D, ~B, ~eq, t, e), get_miss(~D, ~B, ~eq, k, o, t, e, hce)) : {G(~D, ~B, ~eq, A(~D, ~B, ~eq, t, P(~D, ~B, ~eq, s, k, o)), e) == _ : Maybe<&2, S.Obj<D, B>>}
      ih((%Equal.sym(S.Store<D, B>, P(~D, ~B, ~eq, s, k, o), S.StCon{k, o, s}, put_new(~D, ~B, ~eq, s, k, o, hch)) : {G(~D, ~B, ~eq, _, e) == None{} : Maybe<&2, S.Obj<D, B>>}
        (%Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, s}, e), G(~D, ~B, ~eq, s, e), get_miss(~D, ~B, ~eq, k, o, s, e, hce)) : {_ == None{} : Maybe<&2, S.Obj<D, B>>} hn)))

# From a store that lacks e, apply finds e where xs first has it.
def lapply_miss(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq),
  xs: S.Store<D, B>, +s: S.Store<D, B>, +e: D, hn: {G(~D, ~B, ~eq, s, e) == None{} : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, A(~D, ~B, ~eq, xs, s), e) == G(~D, ~B, ~eq, xs, e) : Maybe<&2, S.Obj<D, B>>}:
  match xs:
    case S.StNil{}:
      hn
    case S.StCon{+k, +o, +t}:
      lapply_miss.step(~D, ~B, ~eq, ~sound, Has(~D, ~B, ~eq, s, k), eq(e, k), t, s, k, o, e, {==}, {==}, hn,
        hn2 => lapply_miss(~D, ~B, ~eq, ~sound, t, P(~D, ~B, ~eq, s, k, o), e, hn2))

def IOf(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, xs: S.Store<D, B>) -> S.Index(D, B):
  S.Index.of(~D, ~B, ~cmp, xs)

def LOf(~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>) -> S.Store<D, B>:
  A(~D, ~B, ~eq, xs, S.Store.new(D, B))

# The index of xs finds what xs finds.
def ig.xs(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  +xs: S.Store<D, B>, +d: D
) -> {IG(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, xs), d) == G(~D, ~B, ~eq, xs, d) : Maybe<&2, S.Obj<D, B>>}:
  iapply_miss(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, S.Index.new(D, B),
    Col.omap_new_searchtree(~D, ~S.Obj<D, B>, ~cmp), d, {==})

def ig(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  +xs: S.Store<D, B>, +d: D
) -> {IG(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, xs), d) == G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d) : Maybe<&2, S.Obj<D, B>>}:
  Equal.trans(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, xs), d), G(~D, ~B, ~eq, xs, d), G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d),
    ig.xs(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, d),
    Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d), G(~D, ~B, ~eq, xs, d),
      lapply_miss(~D, ~B, ~eq, ~(x => y => h => sound_of(~D, ~cmp, ~eq, ~ceq, ~agree, x, y, h)), xs, S.Store.new(D, B), d, {==})))

def Laws.index_get(D, B, cmp, eq, crefl, ceq, cflip, ctrans, agree, xs, d):
  ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, d)

def ILG(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, fuel: Nat, +s: S.Index(D, B), m: Maybe<&2, S.Obj<D, B>>) -> Maybe<&2, S.Tree<B>>:
  S.Index.load.go(~D, ~B, ~cmp, fuel, s, m)

def index_load.go(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  fuel: Nat, +xs: S.Store<D, B>, m: Maybe<&2, S.Obj<D, B>>
) -> {ILG(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), m) == LG(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), m) : Maybe<&2, S.Tree<B>>}:
  match fuel m:
    case 0n _:
      {==}
    case 1n+p None{}:
      {==}
    case 1n+p Some{S.OFile{b}}:
      {==}
    case 1n+p Some{S.OEnd{}}:
      {==}
    case 1n+(+p) Some{S.OItem{+n, +c, +r}}:
      +si = IOf(~D, ~B, ~cmp, xs)
      +sl = LOf(~D, ~B, ~eq, xs)
      %Equal.sym(Maybe<&2, S.Tree<B>>, ILG(~D, ~B, ~cmp, p, si, IG(~D, ~B, ~cmp, si, c)), LG(~D, ~B, ~eq, p, sl, IG(~D, ~B, ~cmp, si, c)),
        index_load.go(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, p, xs, IG(~D, ~B, ~cmp, si, c)))
        : {S.Tree.item(B, n, _, ILG(~D, ~B, ~cmp, p, si, IG(~D, ~B, ~cmp, si, r))) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, c)), LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Tree<B>>}
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, si, c), G(~D, ~B, ~eq, sl, c), ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, c))
        : {S.Tree.item(B, n, LG(~D, ~B, ~eq, p, sl, _), ILG(~D, ~B, ~cmp, p, si, IG(~D, ~B, ~cmp, si, r))) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, c)), LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Tree<B>>}
      %Equal.sym(Maybe<&2, S.Tree<B>>, ILG(~D, ~B, ~cmp, p, si, IG(~D, ~B, ~cmp, si, r)), LG(~D, ~B, ~eq, p, sl, IG(~D, ~B, ~cmp, si, r)),
        index_load.go(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, p, xs, IG(~D, ~B, ~cmp, si, r)))
        : {S.Tree.item(B, n, LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, c)), _) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, c)), LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Tree<B>>}
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, si, r), G(~D, ~B, ~eq, sl, r), ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, r))
        : {S.Tree.item(B, n, LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, c)), LG(~D, ~B, ~eq, p, sl, _)) == S.Tree.item(B, n, LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, c)), LG(~D, ~B, ~eq, p, sl, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Tree<B>>}
      {==}

def Laws.index_load(D, B, cmp, eq, crefl, ceq, cflip, ctrans, agree, fuel, xs, d):
  +fuel = fuel
  +xs = xs
  +d = d
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, xs), d), G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d), ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, d))
    : {ILG(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), _) == LG(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d)) : Maybe<&2, S.Tree<B>>}
  index_load.go(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, fuel, xs, G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d))

def ICG(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, fuel: Nat, +s: S.Index(D, B), +d: D, m: Maybe<&2, S.Obj<D, B>>) -> Maybe<&2, S.Store<D, B>>:
  S.Index.closure.go(~D, ~B, ~cmp, fuel, s, d, m)

def index_closure.go(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  fuel: Nat, +xs: S.Store<D, B>, +d: D, m: Maybe<&2, S.Obj<D, B>>
) -> {ICG(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), d, m) == C(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), d, m) : Maybe<&2, S.Store<D, B>>}:
  match fuel m:
    case 0n _:
      {==}
    case 1n+p None{}:
      {==}
    case 1n+p Some{S.OFile{b}}:
      {==}
    case 1n+p Some{S.OEnd{}}:
      {==}
    case 1n+(+p) Some{S.OItem{+n, +c, +r}}:
      +si = IOf(~D, ~B, ~cmp, xs)
      +sl = LOf(~D, ~B, ~eq, xs)
      +o = {S.OItem{n, c, r} : S.Obj<D, B>}
      %Equal.sym(Maybe<&2, S.Store<D, B>>, ICG(~D, ~B, ~cmp, p, si, c, IG(~D, ~B, ~cmp, si, c)), C(~D, ~B, ~eq, p, sl, c, IG(~D, ~B, ~cmp, si, c)),
        index_closure.go(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, p, xs, c, IG(~D, ~B, ~cmp, si, c)))
        : {S.closure.item(D, B, d, o, _, ICG(~D, ~B, ~cmp, p, si, r, IG(~D, ~B, ~cmp, si, r))) == S.closure.item(D, B, d, o, C(~D, ~B, ~eq, p, sl, c, G(~D, ~B, ~eq, sl, c)), C(~D, ~B, ~eq, p, sl, r, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Store<D, B>>}
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, si, c), G(~D, ~B, ~eq, sl, c), ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, c))
        : {S.closure.item(D, B, d, o, C(~D, ~B, ~eq, p, sl, c, _), ICG(~D, ~B, ~cmp, p, si, r, IG(~D, ~B, ~cmp, si, r))) == S.closure.item(D, B, d, o, C(~D, ~B, ~eq, p, sl, c, G(~D, ~B, ~eq, sl, c)), C(~D, ~B, ~eq, p, sl, r, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Store<D, B>>}
      %Equal.sym(Maybe<&2, S.Store<D, B>>, ICG(~D, ~B, ~cmp, p, si, r, IG(~D, ~B, ~cmp, si, r)), C(~D, ~B, ~eq, p, sl, r, IG(~D, ~B, ~cmp, si, r)),
        index_closure.go(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, p, xs, r, IG(~D, ~B, ~cmp, si, r)))
        : {S.closure.item(D, B, d, o, C(~D, ~B, ~eq, p, sl, c, G(~D, ~B, ~eq, sl, c)), _) == S.closure.item(D, B, d, o, C(~D, ~B, ~eq, p, sl, c, G(~D, ~B, ~eq, sl, c)), C(~D, ~B, ~eq, p, sl, r, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Store<D, B>>}
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, si, r), G(~D, ~B, ~eq, sl, r), ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, r))
        : {S.closure.item(D, B, d, o, C(~D, ~B, ~eq, p, sl, c, G(~D, ~B, ~eq, sl, c)), C(~D, ~B, ~eq, p, sl, r, _)) == S.closure.item(D, B, d, o, C(~D, ~B, ~eq, p, sl, c, G(~D, ~B, ~eq, sl, c)), C(~D, ~B, ~eq, p, sl, r, G(~D, ~B, ~eq, sl, r))) : Maybe<&2, S.Store<D, B>>}
      {==}

def index_closure(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  +fuel: Nat, +xs: S.Store<D, B>, +d: D
) -> {S.Index.closure(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), d) == CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), d) : Maybe<&2, S.Store<D, B>>}:
  %Equal.sym(Maybe<&2, S.Obj<D, B>>, IG(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, xs), d), G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d), ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, xs, d))
    : {ICG(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), d, _) == C(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), d, G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d)) : Maybe<&2, S.Store<D, B>>}
  index_closure.go(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, fuel, xs, d, G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, xs), d))

def IN(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +xs: S.Store<D, B>, +t: S.Index(D, B)) -> S.Store<D, B>:
  S.Index.need(~D, ~B, ~cmp, xs, t)

def iapply_cat(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, xs: S.Store<D, B>, +ys: S.Store<D, B>, +m: S.Index(D, B)) -> {IA(~D, ~B, ~cmp, Cat(D, B, xs, ys), m) == IA(~D, ~B, ~cmp, ys, IA(~D, ~B, ~cmp, xs, m)) : S.Index(D, B)}:
  match xs:
    case S.StNil{}:
      {==}
    case S.StCon{+d, +o, t}:
      iapply_cat(~D, ~B, ~cmp, t, ys, IP(~D, ~B, ~cmp, m, d, o))

def lapply_cat(~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: S.Store<D, B>, +ys: S.Store<D, B>, +s: S.Store<D, B>) -> {A(~D, ~B, ~eq, Cat(D, B, xs, ys), s) == A(~D, ~B, ~eq, ys, A(~D, ~B, ~eq, xs, s)) : S.Store<D, B>}:
  match xs:
    case S.StNil{}:
      {==}
    case S.StCon{+d, +o, t}:
      lapply_cat(~D, ~B, ~eq, t, ys, P(~D, ~B, ~eq, s, d, o))

def index_need.step(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool,
  c: Bool, +d: D, +o: S.Obj<D, B>, +rest: S.Store<D, B>, +ts: S.Store<D, B>,
  ih1: {IN(~D, ~B, ~cmp, rest, IOf(~D, ~B, ~cmp, ts)) == N(~D, ~B, ~eq, rest, LOf(~D, ~B, ~eq, ts)) : S.Store<D, B>},
  ih2: {IN(~D, ~B, ~cmp, rest, IOf(~D, ~B, ~cmp, Cat(D, B, ts, S.StCon{d, o, S.StNil{}}))) == N(~D, ~B, ~eq, rest, LOf(~D, ~B, ~eq, Cat(D, B, ts, S.StCon{d, o, S.StNil{}}))) : S.Store<D, B>}
) -> {S.Index.need.go(~D, ~B, ~cmp, S.StCon{d, o, rest}, IOf(~D, ~B, ~cmp, ts), c) == S.need.go(~D, ~B, ~eq, S.StCon{d, o, rest}, LOf(~D, ~B, ~eq, ts), c) : S.Store<D, B>}:
  match c:
    case True{}:
      ih1
    case False{}:
      +one = {S.StCon{d, o, S.StNil{}} : S.Store<D, B>}
      %iapply_cat(~D, ~B, ~cmp, ts, one, S.Index.new(D, B))
        : {S.StCon{d, o, IN(~D, ~B, ~cmp, rest, _)} == S.StCon{d, o, N(~D, ~B, ~eq, rest, P(~D, ~B, ~eq, LOf(~D, ~B, ~eq, ts), d, o))} : S.Store<D, B>}
      %lapply_cat(~D, ~B, ~eq, ts, one, S.Store.new(D, B))
        : {S.StCon{d, o, IN(~D, ~B, ~cmp, rest, IOf(~D, ~B, ~cmp, Cat(D, B, ts, one)))} == S.StCon{d, o, N(~D, ~B, ~eq, rest, _)} : S.Store<D, B>}
      %Equal.sym(S.Store<D, B>, IN(~D, ~B, ~cmp, rest, IOf(~D, ~B, ~cmp, Cat(D, B, ts, one))), N(~D, ~B, ~eq, rest, LOf(~D, ~B, ~eq, Cat(D, B, ts, one))), ih2)
        : {S.StCon{d, o, _} == S.StCon{d, o, N(~D, ~B, ~eq, rest, LOf(~D, ~B, ~eq, Cat(D, B, ts, one)))} : S.Store<D, B>}
      {==}

# need against the index of ts lists what need against the store of ts lists.
def index_need(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  xs: S.Store<D, B>, +ts: S.Store<D, B>
) -> {IN(~D, ~B, ~cmp, xs, IOf(~D, ~B, ~cmp, ts)) == N(~D, ~B, ~eq, xs, LOf(~D, ~B, ~eq, ts)) : S.Store<D, B>}:
  match xs:
    case S.StNil{}:
      {==}
    case S.StCon{+d, +o, +rest}:
      %Equal.sym(Bool, IHas(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, ts), d), Has(~D, ~B, ~eq, LOf(~D, ~B, ~eq, ts), d),
        Equal.cong(Maybe<&2, S.Obj<D, B>>, Bool, mm => Maybe.is_some(&2, S.Obj<D, B>, mm), IG(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, ts), d), G(~D, ~B, ~eq, LOf(~D, ~B, ~eq, ts), d),
          ig(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, ts, d)))
        : {S.Index.need.go(~D, ~B, ~cmp, S.StCon{d, o, rest}, IOf(~D, ~B, ~cmp, ts), _) == S.need.go(~D, ~B, ~eq, S.StCon{d, o, rest}, LOf(~D, ~B, ~eq, ts), Has(~D, ~B, ~eq, LOf(~D, ~B, ~eq, ts), d)) : S.Store<D, B>}
      index_need.step(~D, ~B, ~cmp, ~eq, Has(~D, ~B, ~eq, LOf(~D, ~B, ~eq, ts), d), d, o, rest, ts,
        index_need(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, rest, ts),
        index_need(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, rest, Cat(D, B, ts, S.StCon{d, o, S.StNil{}})))

def index_plan.of(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  +ys: S.Store<D, B>, m: Maybe<&2, S.Store<D, B>>
) -> {S.Index.plan.of(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, ys), m) == S.plan.of(~D, ~B, ~eq, LOf(~D, ~B, ~eq, ys), m) : Maybe<&2, S.Store<D, B>>}:
  match m:
    case None{}:
      {==}
    case Some{zs}:
      +zs = zs
      %Equal.sym(S.Store<D, B>, IN(~D, ~B, ~cmp, zs, IOf(~D, ~B, ~cmp, ys)), N(~D, ~B, ~eq, zs, LOf(~D, ~B, ~eq, ys)),
        index_need(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, zs, ys))
        : {Some{_} == Some{N(~D, ~B, ~eq, zs, LOf(~D, ~B, ~eq, ys))} : Maybe<&2, S.Store<D, B>>}
      {==}

def Laws.index_plan(D, B, cmp, eq, crefl, ceq, cflip, ctrans, agree, fuel, xs, ys, root):
  +fuel = fuel
  +xs = xs
  +ys = ys
  +root = root
  %Equal.sym(Maybe<&2, S.Store<D, B>>, S.Index.closure(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), root), CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), root),
    index_closure(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, fuel, xs, root))
    : {S.Index.plan.of(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, ys), _) == S.plan.of(~D, ~B, ~eq, LOf(~D, ~B, ~eq, ys), CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), root)) : Maybe<&2, S.Store<D, B>>}
  index_plan.of(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, ys, CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), root))

def index_live(
  ~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, ~eq: D -> D -> Bool, ~crefl: CRefl(~D, ~cmp), ~ceq: CEq(~D, ~cmp), ~cflip: CFlip(~D, ~cmp), ~ctrans: CTrans(~D, ~cmp), ~agree: Agree(~D, ~cmp, ~eq),
  +fuel: Nat, +xs: S.Store<D, B>, roots: List<&2, D>
) -> {S.Index.live(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), roots) == Live(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), roots) : Maybe<&2, S.Store<D, B>>}:
  match roots:
    case Nil{}:
      {==}
    case Con{+r, +t}:
      %Equal.sym(Maybe<&2, S.Store<D, B>>, S.Index.closure(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), r), CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), r),
        index_closure(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, fuel, xs, r))
        : {S.live.cat(D, B, _, S.Index.live(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), t)) == S.live.cat(D, B, CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), r), Live(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), t)) : Maybe<&2, S.Store<D, B>>}
      %Equal.sym(Maybe<&2, S.Store<D, B>>, S.Index.live(~D, ~B, ~cmp, fuel, IOf(~D, ~B, ~cmp, xs), t), Live(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), t),
        index_live(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, fuel, xs, t))
        : {S.live.cat(D, B, CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), r), _) == S.live.cat(D, B, CL(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), r), Live(~D, ~B, ~eq, fuel, LOf(~D, ~B, ~eq, xs), t)) : Maybe<&2, S.Store<D, B>>}
      {==}

def Laws.index_live(D, B, cmp, eq, crefl, ceq, cflip, ctrans, agree, fuel, xs, roots):
  index_live(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, fuel, xs, roots)

def gmem.step(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, c: Bool, +k: D, +o: S.Obj<D, B>, +t: S.Store<D, B>, +d: D,
  +hc: {eq(d, k) == c : Bool}, ih: {Maybe.is_some(&2, S.Obj<D, B>, G(~D, ~B, ~eq, t, d)) == M(~D, ~B, ~eq, t, d) : Bool}
) -> {Maybe.is_some(&2, S.Obj<D, B>, G(~D, ~B, ~eq, S.StCon{k, o, t}, d)) == M(~D, ~B, ~eq, S.StCon{k, o, t}, d) : Bool}:
  match c:
    case True{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, d), Some{o}, get_hit(~D, ~B, ~eq, k, o, t, d, hc))
        : {Maybe.is_some(&2, S.Obj<D, B>, _) == M(~D, ~B, ~eq, S.StCon{k, o, t}, d) : Bool}
      %Equal.sym(Bool, eq(d, k), True{}, hc) : {True{} == Bool.or(_, M(~D, ~B, ~eq, t, d)) : Bool}
      {==}
    case False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, t}, d), G(~D, ~B, ~eq, t, d), get_miss(~D, ~B, ~eq, k, o, t, d, hc))
        : {Maybe.is_some(&2, S.Obj<D, B>, _) == M(~D, ~B, ~eq, S.StCon{k, o, t}, d) : Bool}
      %Equal.sym(Bool, eq(d, k), False{}, hc) : {Maybe.is_some(&2, S.Obj<D, B>, G(~D, ~B, ~eq, t, d)) == Bool.or(_, M(~D, ~B, ~eq, t, d)) : Bool}
      ih

# get finds d exactly when mem does.
def gmem(~D: Data, ~B: Data, ~eq: D -> D -> Bool, ls: S.Store<D, B>, +d: D) -> {Maybe.is_some(&2, S.Obj<D, B>, G(~D, ~B, ~eq, ls, d)) == M(~D, ~B, ~eq, ls, d) : Bool}:
  match ls:
    case S.StNil{}:
      {==}
    case S.StCon{+k, +o, +t}:
      gmem.step(~D, ~B, ~eq, eq(d, k), k, o, t, d, {==}, gmem(~D, ~B, ~eq, t, d))

def Laws.index_has_mem(D, B, cmp, eq, crefl, ceq, cflip, ctrans, agree, ls, d):
  +ls = ls
  +d = d
  Equal.trans(Bool, IHas(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, ls), d), Maybe.is_some(&2, S.Obj<D, B>, G(~D, ~B, ~eq, ls, d)), M(~D, ~B, ~eq, ls, d),
    Equal.cong(Maybe<&2, S.Obj<D, B>>, Bool, mm => Maybe.is_some(&2, S.Obj<D, B>, mm), IG(~D, ~B, ~cmp, IOf(~D, ~B, ~cmp, ls), d), G(~D, ~B, ~eq, ls, d),
      ig.xs(~D, ~B, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, ls, d)),
    gmem(~D, ~B, ~eq, ls, d))

def keep_none.step(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), ck: Bool, ce: Bool, +k: D, +o: S.Obj<D, B>, +kr: S.Store<D, B>, +ls: S.Store<D, B>, +d: D,
  +hck: {M(~D, ~B, ~eq, ls, k) == ck : Bool}, +hce: {eq(d, k) == ce : Bool}, hm: {M(~D, ~B, ~eq, ls, d) == False{} : Bool},
  ih: {G(~D, ~B, ~eq, kr, d) == None{} : Maybe<&2, S.Obj<D, B>>}
) -> {G(~D, ~B, ~eq, S.keep.if(D, B, ck, k, o, kr), d) == None{} : Maybe<&2, S.Obj<D, B>>}:
  match ck ce:
    case True{} True{}:
      Empty.absurd({G(~D, ~B, ~eq, S.keep.if(D, B, True{}, k, o, kr), d) == None{} : Maybe<&2, S.Obj<D, B>>},
        false_ne_true(Equal.trans(Bool, False{}, M(~D, ~B, ~eq, ls, d), True{}, Equal.sym(Bool, M(~D, ~B, ~eq, ls, d), False{}, hm),
          (%Equal.sym(D, d, k, sound(d, k, hce)) : {M(~D, ~B, ~eq, ls, _) == True{} : Bool} hck))))
    case True{} False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, S.StCon{k, o, kr}, d), G(~D, ~B, ~eq, kr, d), get_miss(~D, ~B, ~eq, k, o, kr, d, hce))
        : {_ == None{} : Maybe<&2, S.Obj<D, B>>}
      ih
    case False{} _:
      ih

# keep drops every digest that is not in ls.
def keep_none(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), s: S.Store<D, B>, +ls: S.Store<D, B>, +d: D,
  +hm: {M(~D, ~B, ~eq, ls, d) == False{} : Bool}
) -> {G(~D, ~B, ~eq, K(~D, ~B, ~eq, s, ls), d) == None{} : Maybe<&2, S.Obj<D, B>>}:
  match s:
    case S.StNil{}:
      {==}
    case S.StCon{+k, +o, +r}:
      keep_none.step(~D, ~B, ~eq, ~sound, M(~D, ~B, ~eq, ls, k), eq(d, k), k, o, K(~D, ~B, ~eq, r, ls), ls, d, {==}, {==}, hm,
        keep_none(~D, ~B, ~eq, ~sound, r, ls, d, hm))

def gc_has.if(
  ~D: Data, ~B: Data, ~eq: D -> D -> Bool, ~sound: Sound(~D, ~eq), c: Bool, +s: S.Store<D, B>, +ls: S.Store<D, B>, +d: D,
  +hc: {M(~D, ~B, ~eq, ls, d) == c : Bool}, hd: {Has(~D, ~B, ~eq, s, d) == True{} : Bool}
) -> {Has(~D, ~B, ~eq, K(~D, ~B, ~eq, s, ls), d) == c : Bool}:
  match c:
    case True{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, K(~D, ~B, ~eq, s, ls), d), G(~D, ~B, ~eq, s, d), keep_get(~D, ~B, ~eq, ~sound, s, ls, d, hc))
        : {Maybe.is_some(&2, S.Obj<D, B>, _) == True{} : Bool}
      hd
    case False{}:
      %Equal.sym(Maybe<&2, S.Obj<D, B>>, G(~D, ~B, ~eq, K(~D, ~B, ~eq, s, ls), d), None{}, keep_none(~D, ~B, ~eq, ~sound, s, ls, d, hc))
        : {Maybe.is_some(&2, S.Obj<D, B>, _) == False{} : Bool}
      {==}

def Laws.gc_has(D, B, eq, sound, s, ls, d, hd):
  +ls = ls
  +d = d
  gc_has.if(~D, ~B, ~eq, ~sound, M(~D, ~B, ~eq, ls, d), s, ls, d, {==}, hd)

# ---- Digest.cmp is a total order, as Order.string is, over U32 words.

def DO(a: List<&2, U32>, b: List<&2, U32>) -> Cmp:
  S.Digest.order(a, b)

def dord_refl(x: List<&2, U32>) -> {DO(x, x) == EQ{} : Cmp}:
  match x:
    case Nil{}:
      {==}
    case Con{+c, t}:
      %Equal.sym(Cmp, U32.cmp(c, c), EQ{}, ColProof.ucmp_refl(c)) : {Order.string.fin(_, DO(t, t)) == EQ{} : Cmp}
      dord_refl(t)

def dord_eq.step(
  +a: U32, +b: U32, +s: List<&2, U32>, +t: List<&2, U32>, c: Cmp, h: {U32.cmp(a, b) == c : Cmp},
  e: {Order.string.fin(c, DO(s, t)) == EQ{} : Cmp},
  ih: {DO(s, t) == EQ{} : Cmp} -> {s == t : List<&2, U32>}
) -> {Con{a, s} == Con{b, t} : List<&2, U32>}:
  match c:
    case LT{}:
      ColProof.ne_absurd({Con{a, s} == Con{b, t} : List<&2, U32>}, LT{}, {==}, e)
    case EQ{}:
      +ea = ColProof.ucmp_eq(a, b, h)
      +es = ih(e)
      %ea : {Con{a, s} == Con{_, t} : List<&2, U32>}
      %es : {Con{a, s} == Con{a, _} : List<&2, U32>}
      {==}
    case GT{}:
      ColProof.ne_absurd({Con{a, s} == Con{b, t} : List<&2, U32>}, GT{}, {==}, e)

def dord_eq(x: List<&2, U32>, y: List<&2, U32>, e: {DO(x, y) == EQ{} : Cmp}) -> {x == y : List<&2, U32>}:
  match x y:
    case Nil{} Nil{}:
      {==}
    case Nil{} Con{b, t}:
      ColProof.ne_absurd({Nil{} == Con{b, t} : List<&2, U32>}, LT{}, {==}, e)
    case Con{a, s} Nil{}:
      ColProof.ne_absurd({Con{a, s} == Nil{} : List<&2, U32>}, GT{}, {==}, e)
    case Con{+a, +s} Con{+b, +t}:
      dord_eq.step(a, b, s, t, U32.cmp(a, b), {==}, e, p => dord_eq(s, t, p))

def dord_flip(x: List<&2, U32>, y: List<&2, U32>) -> {DO(y, x) == Col.flip(DO(x, y)) : Cmp}:
  match x y:
    case Nil{} Nil{}:
      {==}
    case Nil{} Con{b, t}:
      {==}
    case Con{a, s} Nil{}:
      {==}
    case Con{+a, +s} Con{+b, +t}:
      %Equal.sym(Cmp, U32.cmp(b, a), Col.flip(U32.cmp(a, b)), ColProof.ucmp_flip(a, b)) :
        {Order.string.fin(_, DO(t, s)) == Col.flip(Order.string.fin(U32.cmp(a, b), DO(s, t))) : Cmp}
      %Equal.sym(Cmp, DO(t, s), Col.flip(DO(s, t)), dord_flip(s, t)) :
        {Order.string.fin(Col.flip(U32.cmp(a, b)), _) == Col.flip(Order.string.fin(U32.cmp(a, b), DO(s, t))) : Cmp}
      ColProof.sfin_flip(U32.cmp(a, b), DO(s, t))

def dord_trans.step(
  +a: U32, +b: U32, +c: U32, -s: List<&2, U32>, -t: List<&2, U32>, -u: List<&2, U32>, c1: Cmp, c2: Cmp,
  h1: {U32.cmp(a, b) == c1 : Cmp}, h2: {U32.cmp(b, c) == c2 : Cmp},
  e1: {Order.string.fin(c1, DO(s, t)) == LT{} : Cmp},
  e2: {Order.string.fin(c2, DO(t, u)) == LT{} : Cmp},
  ih: {DO(s, t) == LT{} : Cmp} -> {DO(t, u) == LT{} : Cmp} -> {DO(s, u) == LT{} : Cmp}
) -> {Order.string.fin(U32.cmp(a, c), DO(s, u)) == LT{} : Cmp}:
  match c1 c2:
    case LT{} LT{}:
      %Equal.sym(Cmp, U32.cmp(a, c), LT{}, ColProof.ucmp_trans(a, b, c, h1, h2)) : {Order.string.fin(_, DO(s, u)) == LT{} : Cmp}
      {==}
    case LT{} EQ{}:
      +ebc = ColProof.ucmp_eq(b, c, h2)
      +eac = ColProof.rw(U32, w => {U32.cmp(a, w) == LT{} : Cmp}, c, b, Equal.sym(U32, b, c, ebc), h1)
      %Equal.sym(Cmp, U32.cmp(a, c), LT{}, eac) : {Order.string.fin(_, DO(s, u)) == LT{} : Cmp}
      {==}
    case EQ{} LT{}:
      +eab = ColProof.ucmp_eq(a, b, h1)
      +eac = ColProof.rw(U32, w => {U32.cmp(w, c) == LT{} : Cmp}, a, b, eab, h2)
      %Equal.sym(Cmp, U32.cmp(a, c), LT{}, eac) : {Order.string.fin(_, DO(s, u)) == LT{} : Cmp}
      {==}
    case EQ{} EQ{}:
      +eca = Equal.sym(U32, a, c, Equal.trans(U32, a, b, c, ColProof.ucmp_eq(a, b, h1), ColProof.ucmp_eq(b, c, h2)))
      +eac = ColProof.rw(U32, w => {U32.cmp(a, w) == EQ{} : Cmp}, c, a, eca, ColProof.ucmp_refl(a))
      %Equal.sym(Cmp, U32.cmp(a, c), EQ{}, eac) : {Order.string.fin(_, DO(s, u)) == LT{} : Cmp}
      ih(e1, e2)
    case GT{} _:
      ColProof.lt_absurd({Order.string.fin(U32.cmp(a, c), DO(s, u)) == LT{} : Cmp}, GT{}, {==}, e1)
    case _ GT{}:
      ColProof.lt_absurd({Order.string.fin(U32.cmp(a, c), DO(s, u)) == LT{} : Cmp}, GT{}, {==}, e2)

def dord_trans(
  x: List<&2, U32>, y: List<&2, U32>, z: List<&2, U32>, e1: {DO(x, y) == LT{} : Cmp}, e2: {DO(y, z) == LT{} : Cmp}
) -> {DO(x, z) == LT{} : Cmp}:
  match x y z:
    case Nil{} Nil{} _:
      ColProof.lt_absurd({DO(Nil{}, z) == LT{} : Cmp}, EQ{}, {==}, e1)
    case Con{a, s} Nil{} _:
      ColProof.lt_absurd({DO(Con{a, s}, z) == LT{} : Cmp}, GT{}, {==}, e1)
    case Nil{} Con{b, t} Nil{}:
      ColProof.lt_absurd({DO(Nil{}, Nil{}) == LT{} : Cmp}, GT{}, {==}, e2)
    case Con{a, s} Con{b, t} Nil{}:
      ColProof.lt_absurd({DO(Con{a, s}, Nil{}) == LT{} : Cmp}, GT{}, {==}, e2)
    case Nil{} Con{b, t} Con{c, u}:
      {==}
    case Con{+a, +s} Con{+b, +t} Con{+c, +u}:
      dord_trans.step(a, b, c, s, t, u, U32.cmp(a, b), U32.cmp(b, c), {==}, {==}, e1, e2,
        p => q => dord_trans(s, t, u, p, q))

def Laws.digest_cmp_refl(x):
  match x:
    case S.Digest{ws}:
      dord_refl(ws)

def Laws.digest_cmp_eq(x, y, e):
  match x y:
    case S.Digest{+a} S.Digest{+b}:
      %dord_eq(a, b, e) : {S.Digest{a} == S.Digest{_} : S.Digest}
      {==}

def Laws.digest_cmp_flip(x, y):
  match x y:
    case S.Digest{a} S.Digest{b}:
      dord_flip(a, b)

def Laws.digest_cmp_trans(x, y, z, e1, e2):
  match x y z:
    case S.Digest{a} S.Digest{b} S.Digest{c}:
      dord_trans(a, b, c, e1, e2)
