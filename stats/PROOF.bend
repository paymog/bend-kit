import Base
import ./LAWS.bend as Laws
import ./stats.bend as S
import bend-mathlib@0.8.0.0/nat.bend as N
import bend-mathlib@0.8.0.0/u32.bend as U
import ../lemmas/lemmas.bend as L

def Laws.sum():
  {==}

def Laws.sum_empty():
  {==}

def Laws.mean():
  {==}

def Laws.mean_empty():
  {==}

def Laws.pvariance():
  {==}

def Laws.pvariance_one():
  {==}

def Laws.variance():
  {==}

def Laws.variance_one():
  {==}

def Laws.pstdev():
  {==}

def Laws.stdev():
  {==}

def Laws.pstdev_one():
  {==}

def Laws.stdev_one():
  {==}

def Laws.pstdev_empty():
  {==}

def Laws.stdev_empty():
  {==}

def Laws.median_even():
  {==}

def Laws.median_odd():
  {==}

def Laws.median_empty():
  {==}

def Laws.quartile_low():
  {==}

def Laws.quartile_high():
  {==}

def Laws.quantile_min():
  {==}

def Laws.quantile_max():
  {==}

def Laws.percentile_90():
  {==}

def Laws.quantile_past_one():
  {==}

def Laws.quantile_zero_q():
  {==}

def Laws.quantile_big_q():
  {==}

def Laws.histogram():
  {==}

def Laws.histogram_no_bins():
  {==}

def Laws.regression_exact():
  {==}

def Laws.regression():
  {==}

def Laws.regression_flat_x():
  {==}

def Laws.regression_one():
  {==}

def Laws.regression_lengths():
  {==}

def Laws.gcd():
  {==}

def Laws.gcd_zero():
  {==}

def Laws.gcd_zero_zero():
  {==}

def Laws.gcd_fib():
  {==}

def Laws.lcm():
  {==}

def Laws.lcm_zero():
  {==}

def Laws.lcm_max():
  {==}

def Laws.lcm_overflow():
  {==}

def Laws.isqrt_zero():
  {==}

def Laws.isqrt_below():
  {==}

def Laws.isqrt_square():
  {==}

def Laws.isqrt_max():
  {==}

def min_comm(+a: U32, +b: U32) -> {U32.min(a, b) == U32.min(b, a) : U32}:
  U.u32_to_nat_inj(U32.min(a, b), U32.min(b, a),
    Equal.trans(Nat, U32.to_nat(U32.min(a, b)), Nat.min(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(U32.min(b, a)),
      U.u32_min_to_nat(a, b),
      Equal.trans(Nat, Nat.min(U32.to_nat(a), U32.to_nat(b)), Nat.min(U32.to_nat(b), U32.to_nat(a)), U32.to_nat(U32.min(b, a)),
        N.min_comm(U32.to_nat(a), U32.to_nat(b)),
        Equal.sym(Nat, U32.to_nat(U32.min(b, a)), Nat.min(U32.to_nat(b), U32.to_nat(a)), U.u32_min_to_nat(b, a)))))

def Laws.gcd_symmetric(a, b):
  %Equal.sym(U32, U32.min(a, b), U32.min(b, a), min_comm(a, b)) :
    {S.U32.gcd.go(65n, U32.is_zero(_), U32.max(a, b), _) == S.U32.gcd(b, a) : U32}
  %Equal.sym(U32, U32.max(a, b), U32.max(b, a), L.u32_max_comm(a, b)) :
    {S.U32.gcd.go(65n, U32.is_zero(U32.min(b, a)), _, U32.min(b, a)) == S.U32.gcd(b, a) : U32}
  {==}

def Laws.histogram_empty_edges():
  {==}

def Laws.histogram_nan():
  {==}

def Laws.histogram_duplicate_edges():
  {==}

def zero_test_value(+b: U32, h: {U32.is_zero(b) == True{} : Bool}) -> {U32.to_nat(b) == 0n : Nat}:
  N.eq_of_is_eq(U32.to_nat(b), 0n,
    (
      %L.u32_is_eq_nat(b, 0) : {_ == True{} : Bool}
      h
    ))

def nonzero_test_value(+b: U32, h: {U32.is_zero(b) == False{} : Bool}) -> N.lt(0n, U32.to_nat(b)):
  N.pos_of_ne_zero(U32.to_nat(b),
    (
      %L.u32_is_eq_nat(b, 0) : {_ == False{} : Bool}
      h
    ))

def divides_remainder(+d: Nat, +a: Nat, +b: Nat, +q: Nat, +r: Nat,
  hb: Laws.Divides(d, b), hr: Laws.Divides(d, r),
  e: {Nat.add(Nat.mul(q, b), r) == a : Nat}) -> Laws.Divides(d, a):
  %e : {Nat.mod(_, d) == 0n : Nat}
  %N.add_comm(r, Nat.mul(q, b)) : {Nat.mod(_, d) == 0n : Nat}
  %L.mod_add_product(r, q, b, d) : {_ == 0n : Nat}
  %Equal.sym(Nat, Nat.mod(b, d), 0n, hb) : {Nat.mod(Nat.add(r, Nat.mul(q, _)), d) == 0n : Nat}
  %N.mul_zero_sym(q) : {Nat.mod(Nat.add(r, _), d) == 0n : Nat}
  %N.add_zero_sym(r) : {Nat.mod(_, d) == 0n : Nat}
  hr

def gcd_lift(+d: U32, +a: U32, +b: U32,
  h: Laws.Divides(U32.to_nat(d), U32.to_nat(b)) & Laws.Divides(U32.to_nat(d), U32.to_nat(U32.mod(a, b))),
  qr: {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat} &
    N.lt(U32.to_nat(U32.mod(a, b)), U32.to_nat(b))) ->
  Laws.Divides(U32.to_nat(d), U32.to_nat(a)) & Laws.Divides(U32.to_nat(d), U32.to_nat(b)):
  (+hb, hr) = h
  (e, bound) = qr
  (divides_remainder(U32.to_nat(d), U32.to_nat(a), U32.to_nat(b), U32.to_nat(U32.div(a, b)),
    U32.to_nat(U32.mod(a, b)), hb, hr, e), hb)

def gcd_go_divides(+k: Nat, +z: Bool, +a: U32, +b: U32, hz: {z == U32.is_zero(b) : Bool}) ->
  Laws.Divides(U32.to_nat(S.U32.gcd.go(k, z, a, b)), U32.to_nat(a)) &
    Laws.Divides(U32.to_nat(S.U32.gcd.go(k, z, a, b)), U32.to_nat(b)):
  match k z:
    case 0n _:
      (N.mod_one(U32.to_nat(a)), N.mod_one(U32.to_nat(b)))
    case 1n+p True{}:
      (
        N.mod_self(U32.to_nat(a)),
        (
          %Equal.sym(Nat, U32.to_nat(b), 0n,
            zero_test_value(b, Equal.sym(Bool, True{}, U32.is_zero(b), hz))) :
            {Nat.mod(_, U32.to_nat(a)) == 0n : Nat}
          N.zero_mod(U32.to_nat(a))
        )
      )
    case 1n+p False{}:
      gcd_lift(S.U32.gcd.go(p, U32.is_zero(U32.mod(a, b)), b, U32.mod(a, b)), a, b,
        gcd_go_divides(p, U32.is_zero(U32.mod(a, b)), b, U32.mod(a, b), {==}),
        L.u32_divmod_nat(a, b, nonzero_test_value(b, Equal.sym(Bool, False{}, U32.is_zero(b), hz))))

def gcd_ordered_pick(t: Bool, +a: U32, +b: U32, +d: Nat,
  h: Laws.Divides(d, U32.to_nat(Bool.pick(U32, t, b, a))) &
    Laws.Divides(d, U32.to_nat(Bool.pick(U32, t, a, b)))) ->
  Laws.Divides(d, U32.to_nat(a)) & Laws.Divides(d, U32.to_nat(b)):
  match t:
    case True{}:
      (hb, ha) = h
      (ha, hb)
    case False{}:
      h

def gcd_ordered(+a: U32, +b: U32, h: Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(U32.max(a, b))) &
  Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(U32.min(a, b)))) ->
  Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(a)) &
    Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(b)):
  match a b:
    case U32{+x} U32{+y}:
      gcd_ordered_pick(U32.is_lt(U32{x}, U32{y}), U32{x}, U32{y}, U32.to_nat(S.U32.gcd(U32{x}, U32{y})), h)

def Laws.gcd_divides(a, b):
  gcd_ordered(a, b, gcd_go_divides(65n, U32.is_zero(U32.min(a, b)), U32.max(a, b), U32.min(a, b), {==}))

def divides_quotient(+d: Nat, +a: Nat, h: Laws.Divides(d, a)) -> {Nat.mul(Nat.div(a, d), d) == a : Nat}:
  %N.add_zero(Nat.mul(Nat.div(a, d), d)) : {_ == a : Nat}
  %h : {Nat.add(Nat.mul(Nat.div(a, d), d), _) == a : Nat}
  %N.mul_comm(d, Nat.div(a, d)) : {Nat.add(_, Nat.mod(a, d)) == a : Nat}
  N.div_add_mod(a, d)

def quotient_exact(z: Bool, +a: U32, +g: U32, hz: {z == U32.is_zero(g) : Bool},
  h: Laws.Divides(U32.to_nat(g), U32.to_nat(a))) ->
  {Nat.mul(U32.to_nat(U32.div(a, g)), U32.to_nat(g)) == U32.to_nat(a) : Nat}:
  match z:
    case True{}:
      +eg = zero_test_value(g, Equal.sym(Bool, True{}, U32.is_zero(g), hz))
      +ea : {U32.to_nat(a) == 0n : Nat} = (
        %eg : {Nat.mod(U32.to_nat(a), _) == 0n : Nat}
        h
      )
      %Equal.sym(Nat, U32.to_nat(g), 0n, eg) : {Nat.mul(U32.to_nat(U32.div(a, g)), _) == U32.to_nat(a) : Nat}
      Equal.trans(Nat, Nat.mul(U32.to_nat(U32.div(a, g)), 0n), 0n, U32.to_nat(a),
        N.mul_zero(U32.to_nat(U32.div(a, g))), Equal.sym(Nat, U32.to_nat(a), 0n, ea))
    case False{}:
      %Equal.sym(Nat, U32.to_nat(U32.div(a, g)), Nat.div(U32.to_nat(a), U32.to_nat(g)),
        L.u32_div_nat(a, g, nonzero_test_value(g, Equal.sym(Bool, False{}, U32.is_zero(g), hz)))) :
        {Nat.mul(_, U32.to_nat(g)) == U32.to_nat(a) : Nat}
      divides_quotient(U32.to_nat(g), U32.to_nat(a), h)

def lcm_left(+q: Nat, +g: Nat, +a: Nat, +b: Nat,
  eq: {Nat.mul(q, g) == a : Nat}, hb: Laws.Divides(g, b)) -> Laws.Divides(a, Nat.mul(q, b)):
  %divides_quotient(g, b, hb) : {Nat.mod(Nat.mul(q, _), a) == 0n : Nat}
  %N.mul_comm(g, Nat.div(b, g)) : {Nat.mod(Nat.mul(q, _), a) == 0n : Nat}
  %N.mul_assoc(q, g, Nat.div(b, g)) : {Nat.mod(_, a) == 0n : Nat}
  %Equal.sym(Nat, Nat.mul(q, g), a, eq) : {Nat.mod(Nat.mul(_, Nat.div(b, g)), a) == 0n : Nat}
  N.mul_mod_right(a, Nat.div(b, g))

def lcm_product(+q: U32, +g: U32, +a: U32, +b: U32,
  hq: {Nat.mul(U32.to_nat(q), U32.to_nat(g)) == U32.to_nat(a) : Nat},
  hb: Laws.Divides(U32.to_nat(g), U32.to_nat(b)),
  bound: N.lt(Nat.mul(U32.to_nat(q), U32.to_nat(b)), L.pow2(32n))) ->
  Laws.CommonMultiple(a, b, Some{U32.mul(q, b)}):
  %Equal.sym(Nat, U32.to_nat(U32.mul(q, b)), Nat.mul(U32.to_nat(q), U32.to_nat(b)), L.u32_mul_nat(q, b, bound)) :
    Laws.Divides(U32.to_nat(a), _) & Laws.Divides(U32.to_nat(b), _)
  (lcm_left(U32.to_nat(q), U32.to_nat(g), U32.to_nat(a), U32.to_nat(b), hq, hb),
    N.mul_mod_left(U32.to_nat(q), U32.to_nat(b)))

def u32_gt_lt(+a: U32, +b: U32) -> {U32.is_gt(a, b) == Nat.is_lt(U32.to_nat(b), U32.to_nat(a)) : Bool}:
  Equal.trans(Bool, U32.is_gt(a, b), Nat.is_gt(U32.to_nat(a), U32.to_nat(b)),
    Nat.is_lt(U32.to_nat(b), U32.to_nat(a)), U.u32_is_gt_to_nat(a, b), N.is_gt_eq_is_lt(U32.to_nat(a), U32.to_nat(b)))

def lcm_bound(+q: U32, +b: U32, +hb: N.lt(0n, U32.to_nat(b)),
  hq: {U32.is_gt(q, U32.div(4294967295, b)) == False{} : Bool}) ->
  N.lt(Nat.mul(U32.to_nat(q), U32.to_nat(b)), L.pow2(32n)):
  +h : N.le(U32.to_nat(q), U32.to_nat(U32.div(4294967295, b))) =
    N.le_of_not_lt(U32.to_nat(U32.div(4294967295, b)), U32.to_nat(q),
      (
        %u32_gt_lt(q, U32.div(4294967295, b)) : {_ == False{} : Bool}
        hq
      ))
  N.lt_of_le_of_lt(Nat.mul(U32.to_nat(q), U32.to_nat(b)), U32.to_nat(4294967295), L.pow2(32n),
    N.le_trans(Nat.mul(U32.to_nat(q), U32.to_nat(b)),
      Nat.mul(Nat.div(U32.to_nat(4294967295), U32.to_nat(b)), U32.to_nat(b)), U32.to_nat(4294967295),
      (
        %L.u32_div_nat(4294967295, b, hb) :
          N.le(Nat.mul(U32.to_nat(q), U32.to_nat(b)), Nat.mul(_, U32.to_nat(b)))
        N.mul_le_mul_right(U32.to_nat(q), U32.to_nat(U32.div(4294967295, b)), U32.to_nat(b), h)
      ),
      N.div_mul_le_self(U32.to_nat(4294967295), U32.to_nat(b))),
    L.u32_to_nat_lt(4294967295))

def lcm_guard(z: Bool, ov: Bool, +q: U32, +g: U32, +a: U32, +b: U32,
  hz: {z == U32.is_zero(b) : Bool},
  hov: {ov == Bool.and(Bool.not(z), U32.is_gt(q, U32.div(4294967295, b))) : Bool},
  hq: {Nat.mul(U32.to_nat(q), U32.to_nat(g)) == U32.to_nat(a) : Nat},
  hb: Laws.Divides(U32.to_nat(g), U32.to_nat(b))) ->
  Laws.CommonMultiple(a, b, S.U32.lcm.if(ov, q, b)):
  match z ov:
    case True{} True{}:
      Empty.absurd(Unit, N.succ_ne_zero(0n)(Equal.cong(Bool, Nat, L.b2n, True{}, False{}, hov)))
    case True{} False{}:
      +eb = zero_test_value(b, Equal.sym(Bool, True{}, U32.is_zero(b), hz))
      lcm_product(q, g, a, b, hq, hb,
        (
          %Equal.sym(Nat, U32.to_nat(b), 0n, eb) : N.lt(Nat.mul(U32.to_nat(q), _), L.pow2(32n))
          %N.mul_zero_sym(U32.to_nat(q)) : N.lt(_, L.pow2(32n))
          L.lt_rw(0n, U32.to_nat(0), L.pow2(32n), {==}, L.u32_to_nat_lt(0))
        ))
    case False{} True{}:
      Unit{}
    case False{} False{}:
      lcm_product(q, g, a, b, hq, hb,
        lcm_bound(q, b, nonzero_test_value(b, Equal.sym(Bool, False{}, U32.is_zero(b), hz)),
          Equal.sym(Bool, False{}, U32.is_gt(q, U32.div(4294967295, b)), hov)))

def lcm_of(+a: U32, +b: U32, h: Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(a)) &
  Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(b))) -> Laws.CommonMultiple(a, b, S.U32.lcm(a, b)):
  (ha, hb) = h
  lcm_guard(U32.is_zero(b),
    Bool.and(Bool.not(U32.is_zero(b)), U32.is_gt(U32.div(a, S.U32.gcd(a, b)), U32.div(4294967295, b))),
    U32.div(a, S.U32.gcd(a, b)), S.U32.gcd(a, b), a, b, {==}, {==},
    quotient_exact(U32.is_zero(S.U32.gcd(a, b)), a, S.U32.gcd(a, b), {==}, ha), hb)

def Laws.lcm_divisible(a, b):
  lcm_of(a, b, Laws.gcd_divides(a, b))

def remainder_halves(+q: Nat, +r: Nat, +a: Nat, +b: Nat,
  e: {Nat.add(Nat.mul(q, b), r) == a : Nat}, hr: N.lt(r, b), hb: N.le(b, a)) ->
  N.lt(Nat.double(r), a):
  match q:
    case 0n:
      Empty.absurd(N.lt(Nat.double(r), a),
        N.lt_irrefl(a)(N.lt_of_lt_of_le(a, b, a,
          (%e : N.lt(_, b); hr), hb)))
    case 1n+p:
      %N.double_eq_add_sym(r) : N.lt(_, a)
      N.lt_of_lt_of_le(Nat.add(r, r), Nat.add(b, r), a,
        N.add_lt_add_right(r, b, r, hr),
        N.le_of_add_eq(Nat.add(b, r), Nat.mul(p, b), a,
          (
            %e : {Nat.add(Nat.add(b, r), Nat.mul(p, b)) == _ : Nat}
            %Equal.sym(Nat, Nat.add(Nat.add(b, r), Nat.mul(p, b)), Nat.add(b, Nat.add(r, Nat.mul(p, b))),
              N.add_assoc(b, r, Nat.mul(p, b))) : {_ == Nat.add(Nat.mul(1n+p, b), r) : Nat}
            %N.add_comm(Nat.mul(p, b), r) : {Nat.add(b, _) == Nat.add(Nat.mul(1n+p, b), r) : Nat}
            Equal.sym(Nat, Nat.add(Nat.add(b, Nat.mul(p, b)), r), Nat.add(b, Nat.add(Nat.mul(p, b), r)),
              N.add_assoc(b, Nat.mul(p, b), r))
          )))

def divmod_equation(+a: U32, +b: U32,
  qr: {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat} &
    N.lt(U32.to_nat(U32.mod(a, b)), U32.to_nat(b))) ->
  {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat}:
  (e, h) = qr
  e

def divmod_bound(+a: U32, +b: U32,
  qr: {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat} &
    N.lt(U32.to_nat(U32.mod(a, b)), U32.to_nat(b))) ->
  N.lt(U32.to_nat(U32.mod(a, b)), U32.to_nat(b)):
  (e, h) = qr
  h

def scaled_equation(+s: Nat, +q: Nat, +b: Nat, +r: Nat, +a: Nat,
  e: {Nat.add(Nat.mul(q, b), r) == a : Nat}) ->
  {Nat.add(Nat.mul(q, Nat.mul(s, b)), Nat.mul(s, r)) == Nat.mul(s, a) : Nat}:
  %e : {Nat.add(Nat.mul(q, Nat.mul(s, b)), Nat.mul(s, r)) == Nat.mul(s, _) : Nat}
  %N.mul_add_sym(s, Nat.mul(q, b), r) :
    {Nat.add(Nat.mul(q, Nat.mul(s, b)), Nat.mul(s, r)) == _ : Nat}
  Equal.cong(Nat, Nat, x => Nat.add(x, Nat.mul(s, r)),
    Nat.mul(q, Nat.mul(s, b)), Nat.mul(s, Nat.mul(q, b)),
    Equal.trans(Nat, Nat.mul(q, Nat.mul(s, b)), Nat.mul(Nat.mul(q, s), b), Nat.mul(s, Nat.mul(q, b)),
      Equal.sym(Nat, Nat.mul(Nat.mul(q, s), b), Nat.mul(q, Nat.mul(s, b)), N.mul_assoc(q, s, b)),
      Equal.trans(Nat, Nat.mul(Nat.mul(q, s), b), Nat.mul(Nat.mul(s, q), b), Nat.mul(s, Nat.mul(q, b)),
        Equal.cong(Nat, Nat, x => Nat.mul(x, b), Nat.mul(q, s), Nat.mul(s, q), N.mul_comm(q, s)),
        N.mul_assoc(s, q, b))))

def common_remainder(+s: Nat, +d: Nat, +a: U32, +b: U32,
  ha: Laws.Divides(d, Nat.mul(s, U32.to_nat(a))), hb: Laws.Divides(d, Nat.mul(s, U32.to_nat(b))),
  pos: N.lt(0n, U32.to_nat(b))) -> Laws.Divides(d, Nat.mul(s, U32.to_nat(U32.mod(a, b)))):
  +q = U32.to_nat(U32.div(a, b))
  +r = Nat.mul(s, U32.to_nat(U32.mod(a, b)))
  +v = Nat.mul(s, U32.to_nat(b))
  +w = Nat.mul(s, U32.to_nat(a))
  +e = scaled_equation(s, q, U32.to_nat(b), U32.to_nat(U32.mod(a, b)), U32.to_nat(a),
    divmod_equation(a, b, L.u32_divmod_nat(a, b, pos)))
  +step : {Nat.mod(r, d) == Nat.mod(w, d) : Nat} = (
    %e : {Nat.mod(r, d) == Nat.mod(_, d) : Nat}
    %N.add_comm(r, Nat.mul(q, v)) : {Nat.mod(r, d) == Nat.mod(_, d) : Nat}
    %L.mod_add_product(r, q, v, d) : {Nat.mod(r, d) == _ : Nat}
    %Equal.sym(Nat, Nat.mod(v, d), 0n, hb) : {Nat.mod(r, d) == Nat.mod(Nat.add(r, Nat.mul(q, _)), d) : Nat}
    %N.mul_zero_sym(q) : {Nat.mod(r, d) == Nat.mod(Nat.add(r, _), d) : Nat}
    %N.add_zero_sym(r) : {Nat.mod(r, d) == Nat.mod(_, d) : Nat}
    {==}
  )
  Equal.trans(Nat, Nat.mod(r, d), Nat.mod(w, d), 0n, step, ha)
 

def gcd_fuel(+k: Nat) -> Nat:
  1n+Nat.double(k)

def bool_split(-P: Bool -> Type, +t: Bool,
  yes: {t == True{} : Bool} -> P(True{}),
  no: {t == False{} : Bool} -> P(False{})) -> P(t):
  match t:
    case True{}:
      yes({==})
    case False{}:
      no({==})

def gcd_greatest_go(+k: Nat, +z: Bool, +a: U32, +b: U32, +s: Nat, +d: Nat,
  hz: {z == U32.is_zero(b) : Bool}, order: N.le(U32.to_nat(b), U32.to_nat(a)),
  bound: N.lt(U32.to_nat(a), L.pow2(k)),
  +ha: Laws.Divides(d, Nat.mul(s, U32.to_nat(a))), +hb: Laws.Divides(d, Nat.mul(s, U32.to_nat(b)))) ->
  Laws.Divides(d, Nat.mul(s, U32.to_nat(S.U32.gcd.go(gcd_fuel(k), z, a, b)))):
  match k z:
    case 0n True{}:
      ha
    case 0n False{}:
      +ea = N.le_zero_eq(U32.to_nat(a), N.le_of_lt_succ(U32.to_nat(a), 0n, bound))
      Empty.absurd(Laws.Divides(d, Nat.mul(s, U32.to_nat(S.U32.gcd.go(gcd_fuel(0n), False{}, a, b)))),
        N.lt_zero(0n)(N.lt_of_lt_of_le(0n, U32.to_nat(b), 0n,
          nonzero_test_value(b, Equal.sym(Bool, False{}, U32.is_zero(b), hz)),
          (%ea : N.le(U32.to_nat(b), _); order))))
    case 1n+p True{}:
      ha
    case 1n+p False{}:
      +pos = nonzero_test_value(b, Equal.sym(Bool, False{}, U32.is_zero(b), hz))
      +r = U32.mod(a, b)
      +e = divmod_equation(a, b, L.u32_divmod_nat(a, b, pos))
      +hr = divmod_bound(a, b, L.u32_divmod_nat(a, b, pos))
      bool_split(t => Laws.Divides(d, Nat.mul(s, U32.to_nat(S.U32.gcd.go(2n+Nat.double(p), t, b, r)))), U32.is_zero(r),
        yes => (
          hb
        ),
        no => (
          +rpos = nonzero_test_value(r, no)
          gcd_greatest_go(p, U32.is_zero(U32.mod(b, r)), r, U32.mod(b, r), s, d, {==},
            N.le_of_lt(U32.to_nat(U32.mod(b, r)), U32.to_nat(r),
              divmod_bound(b, r, L.u32_divmod_nat(b, r, rpos))),
            L.lt_of_double_lt(U32.to_nat(r), L.pow2(p),
              N.lt_trans(Nat.double(U32.to_nat(r)), U32.to_nat(a), L.pow2(1n+p),
                remainder_halves(U32.to_nat(U32.div(a, b)), U32.to_nat(r), U32.to_nat(a), U32.to_nat(b), e, hr, order), bound)),
            common_remainder(s, d, a, b, ha, hb, pos),
            common_remainder(s, d, b, r, hb, common_remainder(s, d, a, b, ha, hb, pos), rpos))
        ))

def greatest_ordered(+a: U32, +b: U32, +s: Nat, +d: Nat,
  h: Laws.Divides(d, Nat.mul(s, U32.to_nat(U32.max(a, b)))) & Laws.Divides(d, Nat.mul(s, U32.to_nat(U32.min(a, b))))) ->
  Laws.Divides(d, Nat.mul(s, U32.to_nat(S.U32.gcd(a, b)))):
  (ha, hb) = h
  gcd_greatest_go(32n, U32.is_zero(U32.min(a, b)), U32.max(a, b), U32.min(a, b), s, d, {==},
    (
      %Equal.sym(Nat, U32.to_nat(U32.min(a, b)), Nat.min(U32.to_nat(a), U32.to_nat(b)), U.u32_min_to_nat(a, b)) :
        N.le(_, U32.to_nat(U32.max(a, b)))
      %Equal.sym(Nat, U32.to_nat(U32.max(a, b)), Nat.max(U32.to_nat(a), U32.to_nat(b)), U.u32_max_to_nat(a, b)) :
        N.le(Nat.min(U32.to_nat(a), U32.to_nat(b)), _)
      N.le_trans(Nat.min(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(a), Nat.max(U32.to_nat(a), U32.to_nat(b)),
        N.min_le_left(U32.to_nat(a), U32.to_nat(b)), N.le_max_left(U32.to_nat(a), U32.to_nat(b)))
    ), L.u32_to_nat_lt(U32.max(a, b)), ha, hb)

def common_ordered(t: Bool, +a: U32, +b: U32, +s: Nat, +d: Nat,
  ha: Laws.Divides(d, Nat.mul(s, U32.to_nat(a))), hb: Laws.Divides(d, Nat.mul(s, U32.to_nat(b)))) ->
  Laws.Divides(d, Nat.mul(s, U32.to_nat(Bool.pick(U32, t, b, a)))) &
    Laws.Divides(d, Nat.mul(s, U32.to_nat(Bool.pick(U32, t, a, b)))):
  match t:
    case True{}:
      (hb, ha)
    case False{}:
      (ha, hb)

def gcd_scaled(+a: U32, +b: U32, +s: Nat, +d: Nat,
  ha: Laws.Divides(d, Nat.mul(s, U32.to_nat(a))), hb: Laws.Divides(d, Nat.mul(s, U32.to_nat(b)))) ->
  Laws.Divides(d, Nat.mul(s, U32.to_nat(S.U32.gcd(a, b)))):
  match a b:
    case U32{+x} U32{+y}:
      greatest_ordered(U32{x}, U32{y}, s, d,
        common_ordered(U32.is_lt(U32{x}, U32{y}), U32{x}, U32{y}, s, d, ha, hb))

def Laws.gcd_greatest(a, b, d, ha, hb):
  %N.one_mul(U32.to_nat(S.U32.gcd(a, b))) : Laws.Divides(d, _)
  gcd_scaled(a, b, 1n, d,
    (%Equal.sym(Nat, Nat.mul(1n, U32.to_nat(a)), U32.to_nat(a), N.one_mul(U32.to_nat(a))) : Laws.Divides(d, _); ha),
    (%Equal.sym(Nat, Nat.mul(1n, U32.to_nat(b)), U32.to_nat(b), N.one_mul(U32.to_nat(b))) : Laws.Divides(d, _); hb))

def mul_exchange(+x: Nat, +y: Nat, +z: Nat) ->
  {Nat.mul(Nat.mul(x, y), z) == Nat.mul(Nat.mul(x, z), y) : Nat}:
  Equal.trans(Nat, Nat.mul(Nat.mul(x, y), z), Nat.mul(x, Nat.mul(y, z)), Nat.mul(Nat.mul(x, z), y),
    N.mul_assoc(x, y, z),
    Equal.trans(Nat, Nat.mul(x, Nat.mul(y, z)), Nat.mul(x, Nat.mul(z, y)), Nat.mul(Nat.mul(x, z), y),
      Equal.cong(Nat, Nat, t => Nat.mul(x, t), Nat.mul(y, z), Nat.mul(z, y), N.mul_comm(y, z)),
      Equal.sym(Nat, Nat.mul(Nat.mul(x, z), y), Nat.mul(x, Nat.mul(z, y)), N.mul_assoc(x, z, y))))

def common_product(+a: Nat, +b: Nat, +c: Nat, h: Laws.Divides(b, c)) ->
  Laws.Divides(Nat.mul(a, b), Nat.mul(c, a)):
  +k = Nat.div(c, b)
  %divides_quotient(b, c, h) : Laws.Divides(Nat.mul(a, b), Nat.mul(_, a))
  %mul_exchange(k, a, b) : Laws.Divides(Nat.mul(a, b), _)
  %Equal.sym(Nat, Nat.mul(Nat.mul(k, a), b), Nat.mul(k, Nat.mul(a, b)), N.mul_assoc(k, a, b)) :
    Laws.Divides(Nat.mul(a, b), _)
  N.mul_mod_left(k, Nat.mul(a, b))

def positive_cancel(+g: Nat, +x: Nat, +y: Nat, h: N.lt(0n, g),
  e: {Nat.mul(x, g) == Nat.mul(y, g) : Nat}) -> {x == y : Nat}:
  match g:
    case 0n:
      Empty.absurd({x == y : Nat}, N.lt_irrefl(0n)(h))
    case 1n+p:
      Equal.trans(Nat, x, Nat.div(Nat.mul(x, 1n+p), 1n+p), y,
        Equal.sym(Nat, Nat.div(Nat.mul(x, 1n+p), 1n+p), x, N.mul_div_cancel(x, p)),
        Equal.trans(Nat, Nat.div(Nat.mul(x, 1n+p), 1n+p), Nat.div(Nat.mul(y, 1n+p), 1n+p), y,
          Equal.cong(Nat, Nat, t => Nat.div(t, 1n+p), Nat.mul(x, 1n+p), Nat.mul(y, 1n+p), e),
          N.mul_div_cancel(y, p)))

def divides_cancel(+m: Nat, +c: Nat, +g: Nat, pos: N.lt(0n, g),
  h: Laws.Divides(Nat.mul(m, g), Nat.mul(c, g))) -> Laws.Divides(m, c):
  +k = Nat.div(Nat.mul(c, g), Nat.mul(m, g))
  +e = divides_quotient(Nat.mul(m, g), Nat.mul(c, g), h)
  +ec = positive_cancel(g, Nat.mul(k, m), c, pos,
    Equal.trans(Nat, Nat.mul(Nat.mul(k, m), g), Nat.mul(k, Nat.mul(m, g)), Nat.mul(c, g),
      N.mul_assoc(k, m, g), e))
  %ec : Laws.Divides(m, _)
  N.mul_mod_left(k, m)

def least_zero(result: Maybe<&2, U32>, +c: Nat, ec: {c == 0n : Nat}) -> Laws.LeastMultiple(c, result):
  match result:
    case None{}:
      Unit{}
    case Some{+m}:
      %Equal.sym(Nat, c, 0n, ec) : Laws.Divides(U32.to_nat(m), _)
      N.zero_mod(U32.to_nat(m))

def lcm_least_product(+q: U32, +g: U32, +a: U32, +b: U32, +c: Nat,
  hq: {Nat.mul(U32.to_nat(q), U32.to_nat(g)) == U32.to_nat(a) : Nat},
  hs: Laws.Divides(Nat.mul(U32.to_nat(a), U32.to_nat(b)), Nat.mul(c, U32.to_nat(g))),
  pos: N.lt(0n, U32.to_nat(g)),
  bound: N.lt(Nat.mul(U32.to_nat(q), U32.to_nat(b)), L.pow2(32n))) ->
  Laws.LeastMultiple(c, Some{U32.mul(q, b)}):
  %Equal.sym(Nat, U32.to_nat(U32.mul(q, b)), Nat.mul(U32.to_nat(q), U32.to_nat(b)), L.u32_mul_nat(q, b, bound)) :
    Laws.Divides(_, c)
  divides_cancel(Nat.mul(U32.to_nat(q), U32.to_nat(b)), c, U32.to_nat(g), pos,
    (
      %mul_exchange(U32.to_nat(q), U32.to_nat(g), U32.to_nat(b)) :
        Laws.Divides(_, Nat.mul(c, U32.to_nat(g)))
      %Equal.sym(Nat, Nat.mul(U32.to_nat(q), U32.to_nat(g)), U32.to_nat(a), hq) :
        Laws.Divides(Nat.mul(_, U32.to_nat(b)), Nat.mul(c, U32.to_nat(g)))
      hs
    ))

def lcm_least_guard(z: Bool, ov: Bool, +q: U32, +g: U32, +a: U32, +b: U32, +c: Nat,
  hz: {z == U32.is_zero(b) : Bool},
  hov: {ov == Bool.and(Bool.not(z), U32.is_gt(q, U32.div(4294967295, b))) : Bool},
  hq: {Nat.mul(U32.to_nat(q), U32.to_nat(g)) == U32.to_nat(a) : Nat},
  hs: Laws.Divides(Nat.mul(U32.to_nat(a), U32.to_nat(b)), Nat.mul(c, U32.to_nat(g))),
  hb: Laws.Divides(U32.to_nat(b), c), pos: N.lt(0n, U32.to_nat(g))) ->
  Laws.LeastMultiple(c, S.U32.lcm.if(ov, q, b)):
  match z ov:
    case True{} True{}:
      Empty.absurd(Unit, N.succ_ne_zero(0n)(Equal.cong(Bool, Nat, L.b2n, True{}, False{}, hov)))
    case True{} False{}:
      least_zero(Some{U32.mul(q, b)}, c,
        (
          %zero_test_value(b, Equal.sym(Bool, True{}, U32.is_zero(b), hz)) : Laws.Divides(_, c)
          hb
        ))
    case False{} True{}:
      Unit{}
    case False{} False{}:
      lcm_least_product(q, g, a, b, c, hq, hs, pos,
        lcm_bound(q, b, nonzero_test_value(b, Equal.sym(Bool, False{}, U32.is_zero(b), hz)),
          Equal.sym(Bool, False{}, U32.is_gt(q, U32.div(4294967295, b)), hov)))

def lcm_least_gcd(z: Bool, +a: U32, +b: U32, +c: Nat,
  +hz: {z == U32.is_zero(S.U32.gcd(a, b)) : Bool},
  ha: Laws.Divides(U32.to_nat(a), c), +hb: Laws.Divides(U32.to_nat(b), c),
  +hg: Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(a))) ->
  Laws.LeastMultiple(c, S.U32.lcm(a, b)):
  match z:
    case True{}:
      +ea : {U32.to_nat(a) == 0n : Nat} = (
        %zero_test_value(S.U32.gcd(a, b), Equal.sym(Bool, True{}, U32.is_zero(S.U32.gcd(a, b)), hz)) :
          Laws.Divides(_, U32.to_nat(a))
        hg
      )
      least_zero(S.U32.lcm(a, b), c,
        (%ea : Laws.Divides(_, c); ha))
    case False{}:
      lcm_least_guard(U32.is_zero(b),
        Bool.and(Bool.not(U32.is_zero(b)), U32.is_gt(U32.div(a, S.U32.gcd(a, b)), U32.div(4294967295, b))),
        U32.div(a, S.U32.gcd(a, b)), S.U32.gcd(a, b), a, b, c, {==}, {==},
        quotient_exact(False{}, a, S.U32.gcd(a, b), hz, hg),
        gcd_scaled(a, b, c, Nat.mul(U32.to_nat(a), U32.to_nat(b)),
          common_product(U32.to_nat(a), U32.to_nat(b), c, hb),
          (
            %Equal.sym(Nat, Nat.mul(U32.to_nat(a), U32.to_nat(b)), Nat.mul(U32.to_nat(b), U32.to_nat(a)),
              N.mul_comm(U32.to_nat(a), U32.to_nat(b))) : Laws.Divides(_, Nat.mul(c, U32.to_nat(b)))
            common_product(U32.to_nat(b), U32.to_nat(a), c, ha)
          )),
        hb, nonzero_test_value(S.U32.gcd(a, b), Equal.sym(Bool, False{}, U32.is_zero(S.U32.gcd(a, b)), hz)))

def lcm_least_inputs(+a: U32, +b: U32, +c: Nat,
  ha: Laws.Divides(U32.to_nat(a), c), hb: Laws.Divides(U32.to_nat(b), c),
  h: Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(a)) &
    Laws.Divides(U32.to_nat(S.U32.gcd(a, b)), U32.to_nat(b))) ->
  Laws.LeastMultiple(c, S.U32.lcm(a, b)):
  (hg, unused) = h
  lcm_least_gcd(U32.is_zero(S.U32.gcd(a, b)), a, b, c, {==}, ha, hb, hg)

def Laws.lcm_least(a, b, c, ha, hb):
  lcm_least_inputs(a, b, c, ha, hb, Laws.gcd_divides(a, b))

def pow2_mul(+a: Nat, +b: Nat) -> {Nat.mul(L.pow2(a), L.pow2(b)) == L.pow2(Nat.add(a, b)) : Nat}:
  match a:
    case 0n:
      N.one_mul(L.pow2(b))
    case 1n+p:
      %N.double_mul(L.pow2(p), L.pow2(b)) : {_ == L.pow2(Nat.add(1n+p, b)) : Nat}
      Equal.cong(Nat, Nat, Nat.double, Nat.mul(L.pow2(p), L.pow2(b)), L.pow2(Nat.add(p, b)), pow2_mul(p, b))

def pow2_lt_step(+p: Nat) -> N.lt(L.pow2(p), L.pow2(1n+p)):
  match p:
    case 0n:
      {==}
    case 1n+q:
      N.double_lt_double(L.pow2(q), L.pow2(1n+q), pow2_lt_step(q))

def pow2_le_add(+m: Nat, +n: Nat) -> N.le(L.pow2(n), L.pow2(Nat.add(m, n))):
  match m:
    case 0n:
      N.le_refl(L.pow2(n))
    case 1n+p:
      N.le_trans(L.pow2(n), L.pow2(Nat.add(p, n)), L.pow2(1n+Nat.add(p, n)),
        pow2_le_add(p, n), N.le_double(L.pow2(Nat.add(p, n))))

def halve_pow2(+p: Nat) -> {Nat.div(L.pow2(1n+p), 2n) == L.pow2(p) : Nat}:
  %N.double_eq_two_mul_sym(L.pow2(p)) : {Nat.div(_, 2n) == L.pow2(p) : Nat}
  N.mul_div_cancel_left(L.pow2(p), 1n)

def Frame(+k: Nat, +n: Nat, +r: Nat, +limit: Nat) -> Type:
  N.le(Nat.mul(r, r), n) &
    (N.lt(n, Nat.mul(Nat.add(r, L.pow2(k)), Nat.add(r, L.pow2(k)))) &
      N.le(Nat.add(r, L.pow2(k)), limit))

def candidate_next(+p: Nat, +r: Nat, +c: Nat, ec: {c == Nat.add(r, L.pow2(p)) : Nat}) ->
  {Nat.add(c, L.pow2(p)) == Nat.add(r, L.pow2(1n+p)) : Nat}:
  %Equal.sym(Nat, c, Nat.add(r, L.pow2(p)), ec) : {Nat.add(_, L.pow2(p)) == Nat.add(r, L.pow2(1n+p)) : Nat}
  %N.double_eq_add_sym(L.pow2(p)) : {Nat.add(Nat.add(r, L.pow2(p)), L.pow2(p)) == Nat.add(r, _) : Nat}
  N.add_assoc(r, L.pow2(p), L.pow2(p))

def candidate_lt(+p: Nat, +n: Nat, +r: Nat, +limit: Nat, h: Frame(1n+p, n, r, limit)) ->
  N.lt(Nat.add(r, L.pow2(p)), limit):
  (lo, interval) = h
  (hi, cap) = interval
  N.lt_of_lt_of_le(Nat.add(r, L.pow2(p)), Nat.add(r, L.pow2(1n+p)), limit,
    N.add_lt_add_left(L.pow2(p), L.pow2(1n+p), r, pow2_lt_step(p)), cap)

def frame_taken(+p: Nat, +n: Nat, +r: Nat, +c: Nat, +limit: Nat,
  ec: {c == Nat.add(r, L.pow2(p)) : Nat}, lo: N.le(Nat.mul(c, c), n), h: Frame(1n+p, n, r, limit)) ->
  Frame(p, n, c, limit):
  (old_lo, interval) = h
  (
    lo,
    (
      %Equal.sym(Nat, Nat.add(c, L.pow2(p)), Nat.add(r, L.pow2(1n+p)), candidate_next(p, r, c, ec)) :
        N.lt(n, Nat.mul(_, _)) & N.le(_, limit)
      interval
    )
  )

def frame_rejected(+p: Nat, +n: Nat, +r: Nat, +c: Nat, +limit: Nat,
  ec: {c == Nat.add(r, L.pow2(p)) : Nat}, hi: N.lt(n, Nat.mul(c, c)), h: Frame(1n+p, n, r, limit)) ->
  Frame(p, n, r, limit):
  (lo, interval) = h
  (old_hi, cap) = interval
  (
    lo,
    (
      (
        %ec : N.lt(n, Nat.mul(_, _))
        hi
      ),
      N.le_trans(Nat.add(r, L.pow2(p)), Nat.add(r, L.pow2(1n+p)), limit,
        N.add_le_add_left(L.pow2(p), L.pow2(1n+p), r, N.le_double(L.pow2(p))), cap)
    )
  )

def frame_pick(ok: Bool, +p: Nat, +n: Nat, +r: Nat, +c: Nat, +limit: Nat,
  ec: {c == Nat.add(r, L.pow2(p)) : Nat},
  test: {Nat.is_le(Nat.mul(c, c), n) == ok : Bool}, h: Frame(1n+p, n, r, limit)) ->
  Frame(p, n, Bool.pick(Nat, ok, c, r), limit):
  match ok:
    case True{}:
      frame_taken(p, n, r, c, limit, ec, test, h)
    case False{}:
      frame_rejected(p, n, r, c, limit, ec, N.lt_of_not_le(Nat.mul(c, c), n, test), h)

def half_word(+p: Nat, +step: U32, hstep: {U32.to_nat(step) == L.pow2(1n+p) : Nat}) ->
  {U32.to_nat(U32.div(step, 2)) == L.pow2(p) : Nat}:
  Equal.trans(Nat, U32.to_nat(U32.div(step, 2)), Nat.div(U32.to_nat(step), 2n), L.pow2(p),
    L.u32_div_nat(step, 2, {==}),
    (
      %Equal.sym(Nat, U32.to_nat(step), L.pow2(1n+p), hstep) :
        {Nat.div(_, 2n) == L.pow2(p) : Nat}
      halve_pow2(p)
    ))

def candidate_word(+p: Nat, +n: Nat, +r: U32, +half: U32, +limit: Nat,
  hhalf: {U32.to_nat(half) == L.pow2(p) : Nat}, h: Frame(1n+p, n, U32.to_nat(r), limit),
  hlimit: N.le(limit, L.pow2(32n))) ->
  {U32.to_nat(U32.add(r, half)) == Nat.add(U32.to_nat(r), L.pow2(p)) : Nat}:
  +e = Equal.cong(Nat, Nat, v => Nat.add(U32.to_nat(r), v), U32.to_nat(half), L.pow2(p), hhalf)
  Equal.trans(Nat, U32.to_nat(U32.add(r, half)), Nat.add(U32.to_nat(r), U32.to_nat(half)),
    Nat.add(U32.to_nat(r), L.pow2(p)),
    L.u32_add_nat(r, half,
      L.lt_rw(Nat.add(U32.to_nat(r), U32.to_nat(half)), Nat.add(U32.to_nat(r), L.pow2(p)), L.pow2(32n), e,
        N.lt_of_lt_of_le(Nat.add(U32.to_nat(r), L.pow2(p)), limit, L.pow2(32n),
          candidate_lt(p, n, U32.to_nat(r), limit, h), hlimit))), e)

def square_word(+c: U32, +limit: Nat, hlimit: {Nat.mul(limit, limit) == L.pow2(32n) : Nat},
  +hc: N.lt(U32.to_nat(c), limit)) ->
  {U32.to_nat(U32.mul(c, c)) == Nat.mul(U32.to_nat(c), U32.to_nat(c)) : Nat}:
  L.u32_mul_nat(c, c,
    (
      %hlimit : N.lt(Nat.mul(U32.to_nat(c), U32.to_nat(c)), _)
      N.mul_lt_mul_of_lt_of_lt(U32.to_nat(c), U32.to_nat(c), limit, limit, hc, hc)
    ))

def square_test(+c: U32, +n: U32,
  es: {U32.to_nat(U32.mul(c, c)) == Nat.mul(U32.to_nat(c), U32.to_nat(c)) : Nat}) ->
  {U32.is_le(U32.mul(c, c), n) == Nat.is_le(Nat.mul(U32.to_nat(c), U32.to_nat(c)), U32.to_nat(n)) : Bool}:
  Equal.trans(Bool, U32.is_le(U32.mul(c, c), n), Nat.is_le(U32.to_nat(U32.mul(c, c)), U32.to_nat(n)),
    Nat.is_le(Nat.mul(U32.to_nat(c), U32.to_nat(c)), U32.to_nat(n)), L.u32_is_le_nat(U32.mul(c, c), n),
    Equal.cong(Nat, Bool, v => Nat.is_le(v, U32.to_nat(n)), U32.to_nat(U32.mul(c, c)),
      Nat.mul(U32.to_nat(c), U32.to_nat(c)), es))

def pick_nat(ok: Bool, +c: U32, +r: U32) ->
  {U32.to_nat(S.U32.isqrt.pick(ok, c, r)) == Bool.pick(Nat, ok, U32.to_nat(c), U32.to_nat(r)) : Nat}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def frame_pick_word(+ok: Bool, +p: Nat, +n: U32, +r: U32, +c: U32, +limit: Nat,
  ec: {U32.to_nat(c) == Nat.add(U32.to_nat(r), L.pow2(p)) : Nat},
  test: {Nat.is_le(Nat.mul(U32.to_nat(c), U32.to_nat(c)), U32.to_nat(n)) == ok : Bool},
  h: Frame(1n+p, U32.to_nat(n), U32.to_nat(r), limit)) ->
  Frame(p, U32.to_nat(n), U32.to_nat(S.U32.isqrt.pick(ok, c, r)), limit):
  %Equal.sym(Nat, U32.to_nat(S.U32.isqrt.pick(ok, c, r)), Bool.pick(Nat, ok, U32.to_nat(c), U32.to_nat(r)),
    pick_nat(ok, c, r)) : Frame(p, U32.to_nat(n), _, limit)
  frame_pick(ok, p, U32.to_nat(n), U32.to_nat(r), U32.to_nat(c), limit, ec, test, h)

def frame_done(+n: Nat, +r: Nat, +limit: Nat, h: Frame(0n, n, r, limit)) -> Laws.SqrtBounds(n, r):
  (lo, interval) = h
  (hi, cap) = interval
  (
    lo,
    (
      %N.add_comm(r, 1n) : N.lt(n, Nat.mul(_, _))
      hi
    )
  )

def sqrt_frame(+p: Nat, +n: U32, +r: U32, +step: U32, +limit: Nat,
  hlimit: {Nat.mul(limit, limit) == L.pow2(32n) : Nat}, hlelimit: N.le(limit, L.pow2(32n)),
  hstep: {U32.to_nat(step) == L.pow2(1n+p) : Nat}, h: Frame(1n+p, U32.to_nat(n), U32.to_nat(r), limit)) ->
  Frame(p, U32.to_nat(n), U32.to_nat(S.U32.isqrt.pick(
    U32.is_le(U32.mul(U32.add(r, U32.div(step, 2)), U32.add(r, U32.div(step, 2))), n),
    U32.add(r, U32.div(step, 2)), r)), limit):
  (+lo, interval) = h
  (+hi, cap) = interval
  +cap : N.le(Nat.add(U32.to_nat(r), L.pow2(1n+p)), limit) = cap
  +half = U32.div(step, 2)
  +c = U32.add(r, half)
  +eh = half_word(p, step, hstep)
  +ec = candidate_word(p, U32.to_nat(n), r, half, limit, eh, (lo, (hi, cap)), hlelimit)
  +hc = L.lt_rw(U32.to_nat(c), Nat.add(U32.to_nat(r), L.pow2(p)), limit, ec,
    candidate_lt(p, U32.to_nat(n), U32.to_nat(r), limit, (lo, (hi, cap))))
  +es = square_word(c, limit, hlimit, hc)
  frame_pick_word(U32.is_le(U32.mul(c, c), n), p, n, r, c, limit, ec,
    Equal.sym(Bool, U32.is_le(U32.mul(c, c), n), Nat.is_le(Nat.mul(U32.to_nat(c), U32.to_nat(c)), U32.to_nat(n)),
      square_test(c, n, es)), (lo, (hi, cap)))

def sqrt_go(+k: Nat, +n: U32, +r: U32, +step: U32, +limit: Nat,
  +hlimit: {Nat.mul(limit, limit) == L.pow2(32n) : Nat}, +hlelimit: N.le(limit, L.pow2(32n)),
  +hstep: {U32.to_nat(step) == L.pow2(k) : Nat}, h: Frame(k, U32.to_nat(n), U32.to_nat(r), limit)) ->
  Laws.SqrtBounds(U32.to_nat(n), U32.to_nat(S.U32.isqrt.go(k, n, r, step))):
  match k:
    case 0n:
      frame_done(U32.to_nat(n), U32.to_nat(r), limit, h)
    case 1n+p:
      +half = U32.div(step, 2)
      +c = U32.add(r, half)
      sqrt_go(p, n, S.U32.isqrt.pick(U32.is_le(U32.mul(c, c), n), c, r), half, limit, hlimit, hlelimit,
        half_word(p, step, hstep), sqrt_frame(p, n, r, step, limit, hlimit, hlelimit, hstep, h))

def power_word(+n: Nat, +p: Nat) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+np:
      match p:
        case 0n:
          WCon{True{}, Word.zero(np)}
        case 1n+pp:
          WCon{False{}, power_word(np, pp)}

def power_word_nat(+n: Nat, +p: Nat, h: N.lt(p, n)) ->
  {Word.to_nat(n, power_word(n, p)) == L.pow2(p) : Nat}:
  match n:
    case 0n:
      Empty.absurd({Word.to_nat(0n, power_word(0n, p)) == L.pow2(p) : Nat}, N.lt_zero(p)(h))
    case 1n+np:
      match p:
        case 0n:
          Equal.cong(Nat, Nat, v => 1n+Nat.double(v), Word.to_nat(np, Word.zero(np)), 0n, L.word_zero_nat(np))
        case 1n+pp:
          Equal.cong(Nat, Nat, Nat.double, Word.to_nat(np, power_word(np, pp)),
            L.pow2(pp), power_word_nat(np, pp, h))

def power_word_literal() -> {U32{power_word(32n, 16n)} == 65536 : U32}:
  {==}

def initial_step() -> {U32.to_nat(65536) == L.pow2(16n) : Nat}:
  Equal.trans(Nat, U32.to_nat(65536), Word.to_nat(32n, power_word(32n, 16n)), L.pow2(16n),
    Equal.sym(Nat, Word.to_nat(32n, power_word(32n, 16n)), U32.to_nat(65536),
      Equal.trans(Nat, Word.to_nat(32n, power_word(32n, 16n)), U32.to_nat(U32{power_word(32n, 16n)}), U32.to_nat(65536),
        L.u32_to_nat_word(power_word(32n, 16n)),
        Equal.cong(U32, Nat, U32.to_nat, U32{power_word(32n, 16n)}, 65536, power_word_literal()))),
    power_word_nat(32n, 16n, {==}))

def initial_frame(+p: Nat, +n: U32, +r: U32, +limit: Nat, +e: {limit == L.pow2(p) : Nat},
  square: {Nat.mul(limit, limit) == L.pow2(32n) : Nat}, er: {U32.to_nat(r) == 0n : Nat}) ->
  Frame(p, U32.to_nat(n), U32.to_nat(r), limit):
  %Equal.sym(Nat, U32.to_nat(r), 0n, er) : Frame(p, U32.to_nat(n), _, limit)
  (
    N.zero_le(U32.to_nat(n)),
    (
      (
        %e : N.lt(U32.to_nat(n), Nat.mul(_, _))
        %Equal.sym(Nat, Nat.mul(limit, limit), L.pow2(32n), square) : N.lt(U32.to_nat(n), _)
        L.u32_to_nat_lt(n)
      ),
      (
        %e : N.le(_, limit)
        N.le_refl(limit)
      )
    )
  )

def square_limit() -> {Nat.mul(L.pow2(16n), L.pow2(16n)) == L.pow2(32n) : Nat}:
  Equal.trans(Nat, Nat.mul(L.pow2(16n), L.pow2(16n)), L.pow2(Nat.add(16n, 16n)), L.pow2(32n),
    pow2_mul(16n, 16n), Equal.cong(Nat, Nat, L.pow2, Nat.add(16n, 16n), 32n, {==}))

def le_limit() -> N.le(L.pow2(16n), L.pow2(32n)):
  %Equal.cong(Nat, Nat, L.pow2, Nat.add(16n, 16n), 32n, {==}) : N.le(L.pow2(16n), _)
  pow2_le_add(16n, 16n)

def sqrt_fallback(+n: U32) -> Laws.SqrtBounds(U32.to_nat(n), U32.to_nat(S.U32.isqrt.go(16n, n, 0, 65536))):
  sqrt_go(16n, n, 0, 65536, L.pow2(16n), square_limit(), le_limit(),
    initial_step(), initial_frame(16n, n, 0, L.pow2(16n), {==}, square_limit(), {==}))

def max_root_cap() -> N.lt(U32.to_nat(65535), L.pow2(16n)):
  %initial_step() :
    N.lt(U32.to_nat(65535), _)
  Equal.trans(Bool, Nat.is_lt(U32.to_nat(65535), U32.to_nat(65536)), U32.is_lt(65535, 65536), True{},
    Equal.sym(Bool, U32.is_lt(65535, 65536), Nat.is_lt(U32.to_nat(65535), U32.to_nat(65536)),
      L.u32_is_lt_nat(65535, 65536)), {==})

def max_root_next() -> {1n+U32.to_nat(65535) == L.pow2(16n) : Nat}:
  Equal.trans(Nat, 1n+U32.to_nat(65535), U32.to_nat(U32.inc(65535)), L.pow2(16n),
    Equal.sym(Nat, U32.to_nat(U32.inc(65535)), 1n+U32.to_nat(65535),
      L.u32_inc_nat(65535,
        N.lt_of_le_of_lt(1n+U32.to_nat(65535), L.pow2(16n), L.pow2(32n),
          N.succ_le_of_lt(U32.to_nat(65535), L.pow2(16n), max_root_cap()),
          N.lt_of_lt_of_le(L.pow2(16n), L.pow2(17n), L.pow2(32n),
            pow2_lt_step(16n), pow2_le_add(15n, 17n))))),
    Equal.trans(Nat, U32.to_nat(U32.inc(65535)), U32.to_nat(65536), L.pow2(16n),
      Equal.cong(U32, Nat, U32.to_nat, U32.inc(65535), 65536, {==}), initial_step()))

def root_low(+n: U32, +r: U32, cap: N.lt(U32.to_nat(r), L.pow2(16n)),
  h: {U32.is_le(U32.mul(r, r), n) == True{} : Bool}) ->
  N.le(Nat.mul(U32.to_nat(r), U32.to_nat(r)), U32.to_nat(n)):
  Equal.trans(Bool, Nat.is_le(Nat.mul(U32.to_nat(r), U32.to_nat(r)), U32.to_nat(n)),
    U32.is_le(U32.mul(r, r), n), True{},
    Equal.sym(Bool, U32.is_le(U32.mul(r, r), n),
      Nat.is_le(Nat.mul(U32.to_nat(r), U32.to_nat(r)), U32.to_nat(n)),
      square_test(r, n, square_word(r, L.pow2(16n), square_limit(), cap))), h)

def root_top(+n: U32, +r: U32, htop: {U32.is_eq(r, 65535) == True{} : Bool},
  hlo: {U32.is_le(U32.mul(r, r), n) == True{} : Bool}) ->
  Laws.SqrtBounds(U32.to_nat(n), U32.to_nat(r)):
  +er = N.eq_of_is_eq(U32.to_nat(r), U32.to_nat(65535),
    Equal.trans(Bool, Nat.is_eq(U32.to_nat(r), U32.to_nat(65535)), U32.is_eq(r, 65535), True{},
      Equal.sym(Bool, U32.is_eq(r, 65535), Nat.is_eq(U32.to_nat(r), U32.to_nat(65535)),
        L.u32_is_eq_nat(r, 65535)), htop))
  +en = Equal.trans(Nat, 1n+U32.to_nat(r), 1n+U32.to_nat(65535), L.pow2(16n),
    Equal.cong(Nat, Nat, x => 1n+x, U32.to_nat(r), U32.to_nat(65535), er), max_root_next())
  (
    root_low(n, r,
      (
        %en : N.lt(U32.to_nat(r), _)
        N.lt_succ_self(U32.to_nat(r))
      ), hlo),
    (
      %Equal.sym(Nat, 1n+U32.to_nat(r), L.pow2(16n), en) : N.lt(U32.to_nat(n), Nat.mul(_, _))
      %Equal.sym(Nat, Nat.mul(L.pow2(16n), L.pow2(16n)), L.pow2(32n), square_limit()) :
        N.lt(U32.to_nat(n), _)
      L.u32_to_nat_lt(n)
    )
  )

def root_cap(+r: U32, +bound: U32, +limit: Nat, e: {U32.to_nat(bound) == limit : Nat},
  h: {U32.is_lt(r, bound) == True{} : Bool}) -> N.lt(U32.to_nat(r), limit):
  %e : N.lt(U32.to_nat(r), _)
  Equal.trans(Bool, Nat.is_lt(U32.to_nat(r), U32.to_nat(bound)), U32.is_lt(r, bound), True{},
    Equal.sym(Bool, U32.is_lt(r, bound), Nat.is_lt(U32.to_nat(r), U32.to_nat(bound)),
      L.u32_is_lt_nat(r, bound)), h)

def root_inc_bound(+r: Nat, h: N.lt(r, L.pow2(16n))) -> N.lt(1n+r, L.pow2(32n)):
  N.lt_of_le_of_lt(1n+r, L.pow2(16n), L.pow2(32n),
    N.succ_le_of_lt(r, L.pow2(16n), h),
    N.lt_of_lt_of_le(L.pow2(16n), L.pow2(17n), L.pow2(32n),
      pow2_lt_step(16n), pow2_le_add(15n, 17n)))

def root_inner(+n: U32, +r: U32,
  hcap: {U32.is_lt(r, 65536) == True{} : Bool},
  hncap: {U32.is_lt(U32.inc(r), 65536) == True{} : Bool},
  hlo: {U32.is_le(U32.mul(r, r), n) == True{} : Bool},
  hhi: {U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r))) == True{} : Bool}) ->
  Laws.SqrtBounds(U32.to_nat(n), U32.to_nat(r)):
  +cap = root_cap(r, 65536, L.pow2(16n), initial_step(), hcap)
  +next_cap = root_cap(U32.inc(r), 65536, L.pow2(16n), initial_step(), hncap)
  +er = L.u32_inc_nat(r, root_inc_bound(U32.to_nat(r), cap))
  +es = square_word(U32.inc(r), L.pow2(16n), square_limit(), next_cap)
  (
    root_low(n, r, cap, hlo),
    (
      %er : N.lt(U32.to_nat(n), Nat.mul(_, _))
      %es : N.lt(U32.to_nat(n), _)
      Equal.trans(Bool, Nat.is_lt(U32.to_nat(n), U32.to_nat(U32.mul(U32.inc(r), U32.inc(r)))),
        U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r))), True{},
        Equal.sym(Bool, U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r))),
          Nat.is_lt(U32.to_nat(n), U32.to_nat(U32.mul(U32.inc(r), U32.inc(r)))),
          L.u32_is_lt_nat(n, U32.mul(U32.inc(r), U32.inc(r)))), hhi)
    )
  )

def root_and_left(a: Bool, b: Bool, h: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      h

def root_and_right(a: Bool, +b: Bool, h: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      h
    case False{}:
      Empty.absurd({b == True{} : Bool},
        N.succ_ne_zero(0n)(Equal.cong(Bool, Nat, L.b2n, True{}, False{},
          Equal.sym(Bool, False{}, True{}, h))))

def root_valid(top: Bool, +n: U32, +r: U32,
  htop: {U32.is_eq(r, 65535) == top : Bool},
  hlo: {U32.is_le(U32.mul(r, r), n) == True{} : Bool},
  +h: {Bool.or(top, Bool.and(U32.is_lt(r, 65536),
    Bool.and(U32.is_lt(U32.inc(r), 65536), U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r)))))) == True{} : Bool}) ->
  Laws.SqrtBounds(U32.to_nat(n), U32.to_nat(r)):
  match top:
    case True{}:
      root_top(n, r, htop, hlo)
    case False{}:
      +cap = U32.is_lt(r, 65536)
      +next_cap = U32.is_lt(U32.inc(r), 65536)
      +hi = U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r)))
      +tail = root_and_right(cap, Bool.and(next_cap, hi), h)
      root_inner(n, r, root_and_left(cap, Bool.and(next_cap, hi), h),
        root_and_left(next_cap, hi, tail), hlo, root_and_right(next_cap, hi, tail))

def root_accept(ok: Bool, +n: U32, +r: U32,
  +h: {Bool.and(U32.is_le(U32.mul(r, r), n),
    Bool.or(U32.is_eq(r, 65535), Bool.and(U32.is_lt(r, 65536),
      Bool.and(U32.is_lt(U32.inc(r), 65536), U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r))))))) == ok : Bool}) ->
  Laws.SqrtBounds(U32.to_nat(n), U32.to_nat(S.U32.isqrt.accept(ok, n, r))):
  match ok:
    case True{}:
      +lo = U32.is_le(U32.mul(r, r), n)
      +rest = Bool.or(U32.is_eq(r, 65535), Bool.and(U32.is_lt(r, 65536),
        Bool.and(U32.is_lt(U32.inc(r), 65536), U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r))))))
      root_valid(U32.is_eq(r, 65535), n, r, {==},
        root_and_left(lo, rest, h), root_and_right(lo, rest, h))
    case False{}:
      sqrt_fallback(n)

def root_certify(+n: U32, +r: U32) ->
  Laws.SqrtBounds(U32.to_nat(n), U32.to_nat(S.U32.isqrt.certify(n, r))):
  root_accept(Bool.and(U32.is_le(U32.mul(r, r), n),
    Bool.or(U32.is_eq(r, 65535), Bool.and(U32.is_lt(r, 65536),
      Bool.and(U32.is_lt(U32.inc(r), 65536), U32.is_lt(n, U32.mul(U32.inc(r), U32.inc(r))))))),
    n, r, {==})

def newton_nat(+n: U32, +r: U32,
  positive: N.lt(0n, U32.to_nat(r)),
  fits: N.lt(Nat.add(U32.to_nat(r), U32.to_nat(U32.div(n, r))), L.pow2(32n))) ->
  {U32.to_nat(S.U32.isqrt.newton(n, r)) ==
    Nat.div(Nat.add(U32.to_nat(r), Nat.div(U32.to_nat(n), U32.to_nat(r))), 2n) : Nat}:
  %Equal.sym(Nat, U32.to_nat(2), 2n, {==}) :
    {U32.to_nat(S.U32.isqrt.newton(n, r)) ==
      Nat.div(Nat.add(U32.to_nat(r), Nat.div(U32.to_nat(n), U32.to_nat(r))), _) : Nat}
  Equal.trans(Nat,
    U32.to_nat(S.U32.isqrt.newton(n, r)),
    Nat.div(U32.to_nat(U32.add(r, U32.div(n, r))), U32.to_nat(2)),
    Nat.div(Nat.add(U32.to_nat(r), Nat.div(U32.to_nat(n), U32.to_nat(r))), U32.to_nat(2)),
    L.u32_div_nat(U32.add(r, U32.div(n, r)), 2, {==}),
    Equal.cong(Nat, Nat, x => Nat.div(x, U32.to_nat(2)),
      U32.to_nat(U32.add(r, U32.div(n, r))),
      Nat.add(U32.to_nat(r), Nat.div(U32.to_nat(n), U32.to_nat(r))),
      Equal.trans(Nat, U32.to_nat(U32.add(r, U32.div(n, r))),
        Nat.add(U32.to_nat(r), U32.to_nat(U32.div(n, r))),
        Nat.add(U32.to_nat(r), Nat.div(U32.to_nat(n), U32.to_nat(r))),
        L.u32_add_nat(r, U32.div(n, r), fits),
        Equal.cong(Nat, Nat, x => Nat.add(U32.to_nat(r), x),
          U32.to_nat(U32.div(n, r)), Nat.div(U32.to_nat(n), U32.to_nat(r)),
          L.u32_div_nat(n, r, positive)))))

def log2_budget(k: Nat) -> Nat:
  match k:
    case 0n:
      0n
    case 1n+ +p:
      Nat.add(U32.to_nat(U32.shln(1, p)), log2_budget(p))

def bit_weight(s: Nat, bit: Bool) ->
  N.le(Nat.mul(s, U32.to_nat(Bool.to_u32(bit))), s):
  match s:
    case 0n:
      {==}
    case 1n+ +p:
      match bit:
        case False{}:
          N.le_trans(Nat.mul(p, 0n), p, 1n+p,
            bit_weight(p, False{}), N.le_of_lt(p, 1n+p, N.lt_succ_self(p)))
        case True{}:
          bit_weight(p, True{})

def log2_go_bound(k: Nat, +n: U32, +b: Nat) ->
  N.le(U32.log2.go(k, n, b), Nat.add(b, log2_budget(k))):
  match k:
    case 0n:
      %Equal.sym(Nat, Nat.add(b, 0n), b, N.add_zero(b)) : N.le(b, _)
      N.le_refl(b)
    case 1n+ +p:
      +s = U32.to_nat(U32.shln(1, p))
      +flag = U32.is_ne(U32.shrn(n, s), 0)
      +t = Nat.mul(s, U32.to_nat(Bool.to_u32(flag)))
      N.le_trans(U32.log2.go(p, U32.shrn(n, t), Nat.add(b, t)),
        Nat.add(Nat.add(b, t), log2_budget(p)),
        Nat.add(b, Nat.add(s, log2_budget(p))),
        log2_go_bound(p, U32.shrn(n, t), Nat.add(b, t)),
        (
          %N.add_assoc(b, s, log2_budget(p)) :
            N.le(Nat.add(Nat.add(b, t), log2_budget(p)), _)
          N.add_le_add_right(Nat.add(b, t), Nat.add(b, s), log2_budget(p),
            N.add_le_add_left(t, s, b, bit_weight(s, flag)))
        ))

def log2_bound(n: U32) -> N.le(U32.log2(n), 31n):
  log2_go_bound(5n, n, 0n)

def seed_exponent_bound(+n: U32) ->
  N.le(Nat.add(1n, Nat.div(U32.log2(n), 2n)), 16n):
  N.div_le_div(U32.log2(n), 31n, 1n, log2_bound(n))

def put_zero(n: Nat) ->
  {Word.shl.put(n, False{}, Word.zero(n)) == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      Equal.cong(Word(p), Word(1n+p), w => WCon{False{}, w},
        Word.shl.put(p, False{}, Word.zero(p)), Word.zero(p), put_zero(p))

def one_put(n: Nat) ->
  {Word.shl.put(n, True{}, Word.zero(n)) == power_word(n, 0n) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      Equal.cong(Word(p), Word(1n+p), w => WCon{True{}, w},
        Word.shl.put(p, False{}, Word.zero(p)), Word.zero(p), put_zero(p))

def false_put(n: Nat, w: Word(n)) ->
  {Word.shl.put(n, False{}, w) == Word.shl(n, w) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{b, t}:
          {==}

def power_shift(+n: Nat, +p: Nat) ->
  {Word.shl(n, power_word(n, p)) == power_word(n, 1n+p) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+ +np:
      match p:
        case 0n:
          Equal.cong(Word(np), Word(1n+np), w => WCon{False{}, w},
            Word.shl.put(np, True{}, Word.zero(np)), power_word(np, 0n), one_put(np))
        case 1n+ +pp:
          Equal.cong(Word(np), Word(1n+np), w => WCon{False{}, w},
            Word.shl.put(np, False{}, power_word(np, pp)), power_word(np, 1n+pp),
            Equal.trans(Word(np),
              Word.shl.put(np, False{}, power_word(np, pp)),
              Word.shl(np, power_word(np, pp)), power_word(np, 1n+pp),
              false_put(np, power_word(np, pp)), power_shift(np, pp)))

def seed_word(+p: Nat) ->
  {U32.shln(1, p) == U32{power_word(32n, p)} : U32}:
  match p:
    case 0n:
      {==}
    case 1n+ +pp:
      Equal.trans(U32, U32.shln(1, 1n+pp),
        U32.shl(U32{power_word(32n, pp)}), U32{power_word(32n, 1n+pp)},
        Equal.cong(U32, U32, U32.shl, U32.shln(1, pp), U32{power_word(32n, pp)}, seed_word(pp)),
        Equal.cong(Word(32n), U32, w => U32{w},
          Word.shl(32n, power_word(32n, pp)), power_word(32n, 1n+pp), power_shift(32n, pp)))

def seed_nat(+p: Nat, h: N.lt(p, 32n)) ->
  {U32.to_nat(U32.shln(1, p)) == L.pow2(p) : Nat}:
  Equal.trans(Nat, U32.to_nat(U32.shln(1, p)), U32.to_nat(U32{power_word(32n, p)}), L.pow2(p),
    Equal.cong(U32, Nat, U32.to_nat, U32.shln(1, p), U32{power_word(32n, p)}, seed_word(p)),
    Equal.trans(Nat, U32.to_nat(U32{power_word(32n, p)}),
      Word.to_nat(32n, power_word(32n, p)), L.pow2(p),
      Equal.sym(Nat, Word.to_nat(32n, power_word(32n, p)), U32.to_nat(U32{power_word(32n, p)}),
        L.u32_to_nat_word(power_word(32n, p))), power_word_nat(32n, p, h)))

def pad_nat(+n: Nat, w: Word(n)) ->
  {Word.to_nat(1n+n, Word.shr.pad(n, w)) == Word.to_nat(n, w) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{False{}, +t}:
          Equal.cong(Nat, Nat, Nat.double,
            Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t), pad_nat(p, t))
        case WCon{True{}, +t}:
          Equal.cong(Nat, Nat, x => 1n+Nat.double(x),
            Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t), pad_nat(p, t))

def half_even(+q: Nat) -> {Nat.div(Nat.double(q), 2n) == q : Nat}:
  %Equal.sym(Nat, Nat.double(q), Nat.mul(2n, q), N.double_eq_two_mul(q)) : {Nat.div(_, 2n) == q : Nat}
  N.mul_div_cancel_left(q, 1n)

def half_odd(+q: Nat) -> {Nat.div(1n+Nat.double(q), 2n) == q : Nat}:
  %Equal.sym(Nat, Nat.double(q), Nat.mul(2n, q), N.double_eq_two_mul(q)) : {Nat.div(1n+_, 2n) == q : Nat}
  N.add_mul_div_left(1n, q, 1n)

def word_shr_nat(+n: Nat, +w: Word(n)) ->
  {Word.to_nat(n, Word.shr(n, w)) == Nat.div(Word.to_nat(n, w), 2n) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{False{}, +t}:
          Equal.trans(Nat,
            Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t),
            Nat.div(Nat.double(Word.to_nat(p, t)), 2n),
            pad_nat(p, t), Equal.sym(Nat, Nat.div(Nat.double(Word.to_nat(p, t)), 2n),
              Word.to_nat(p, t), half_even(Word.to_nat(p, t))))
        case WCon{True{}, +t}:
          Equal.trans(Nat,
            Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t),
            Nat.div(1n+Nat.double(Word.to_nat(p, t)), 2n),
            pad_nat(p, t), Equal.sym(Nat, Nat.div(1n+Nat.double(Word.to_nat(p, t)), 2n),
              Word.to_nat(p, t), half_odd(Word.to_nat(p, t))))

def u32_shr_nat(n: U32) ->
  {U32.to_nat(U32.shr(n)) == Nat.div(U32.to_nat(n), 2n) : Nat}:
  match n:
    case U32{+w}:
      Equal.trans(Nat, U32.to_nat(U32.shr(U32{w})),
        Word.to_nat(32n, Word.shr(32n, w)), Nat.div(U32.to_nat(U32{w}), 2n),
        Equal.sym(Nat, Word.to_nat(32n, Word.shr(32n, w)),
          U32.to_nat(U32.shr(U32{w})), L.u32_to_nat_word(Word.shr(32n, w))),
        Equal.trans(Nat, Word.to_nat(32n, Word.shr(32n, w)),
          Nat.div(Word.to_nat(32n, w), 2n), Nat.div(U32.to_nat(U32{w}), 2n),
          word_shr_nat(32n, w),
          Equal.cong(Nat, Nat, x => Nat.div(x, 2n),
            Word.to_nat(32n, w), U32.to_nat(U32{w}), L.u32_to_nat_word(w))))

def half_upper(+x: Nat, +m: Nat, h: N.lt(Nat.div(x, 2n), m)) ->
  N.lt(x, Nat.mul(m, 2n)):
  N.lt_of_not_le(Nat.mul(m, 2n), x,
    Equal.trans(Bool, Nat.is_le(Nat.mul(m, 2n), x), Nat.is_le(m, Nat.div(x, 2n)), False{},
      Equal.sym(Bool, Nat.is_le(m, Nat.div(x, 2n)), Nat.is_le(Nat.mul(m, 2n), x),
        N.le_div_iff_mul_le(m, x, 1n)), N.not_le_of_lt(Nat.div(x, 2n), m, h)))

def scale_twice(+m: Nat, +p: Nat) ->
  {Nat.mul(Nat.mul(m, 2n), L.pow2(p)) == Nat.mul(m, L.pow2(1n+p)) : Nat}:
  Equal.trans(Nat, Nat.mul(Nat.mul(m, 2n), L.pow2(p)),
    Nat.mul(m, Nat.mul(2n, L.pow2(p))), Nat.mul(m, Nat.double(L.pow2(p))),
    N.mul_assoc(m, 2n, L.pow2(p)),
    Equal.cong(Nat, Nat, x => Nat.mul(m, x), Nat.mul(2n, L.pow2(p)), Nat.double(L.pow2(p)),
      Equal.sym(Nat, Nat.double(L.pow2(p)), Nat.mul(2n, L.pow2(p)), N.double_eq_two_mul(L.pow2(p)))))

def shrn_upper(s: Nat, +n: U32, +m: Nat, h: N.lt(U32.to_nat(U32.shrn(n, s)), m)) ->
  N.lt(U32.to_nat(n), Nat.mul(m, L.pow2(s))):
  match s:
    case 0n:
      %Equal.sym(Nat, Nat.mul(m, 1n), m, N.mul_one(m)) : N.lt(U32.to_nat(n), _)
      h
    case 1n+ +p:
      %scale_twice(m, p) : N.lt(U32.to_nat(n), _)
      shrn_upper(p, n, Nat.mul(m, 2n),
        half_upper(U32.to_nat(U32.shrn(n, p)), m,
          (
            %u32_shr_nat(U32.shrn(n, p)) : N.lt(_, m)
            h
          )))

def log2_initial_budget(+n: U32) ->
  N.lt(U32.to_nat(n), L.pow2(L.pow2(5n))):
  %Equal.sym(Nat, L.pow2(L.pow2(5n)), L.pow2(32n),
    Equal.cong(Nat, Nat, L.pow2, L.pow2(5n), 32n, {==})) : N.lt(U32.to_nat(n), _)
  L.u32_to_nat_lt(n)

def shrn_lower(s: Nat, +n: U32, +m: Nat, h: N.le(m, U32.to_nat(U32.shrn(n, s)))) ->
  N.le(Nat.mul(m, L.pow2(s)), U32.to_nat(n)):
  match s:
    case 0n:
      %Equal.sym(Nat, Nat.mul(m, 1n), m, N.mul_one(m)) : N.le(_, U32.to_nat(n))
      h
    case 1n+ +p:
      %scale_twice(m, p) : N.le(_, U32.to_nat(n))
      shrn_lower(p, n, Nat.mul(m, 2n),
        Equal.trans(Bool,
          Nat.is_le(Nat.mul(m, 2n), U32.to_nat(U32.shrn(n, p))),
          Nat.is_le(m, Nat.div(U32.to_nat(U32.shrn(n, p)), 2n)), True{},
          Equal.sym(Bool,
            Nat.is_le(m, Nat.div(U32.to_nat(U32.shrn(n, p)), 2n)),
            Nat.is_le(Nat.mul(m, 2n), U32.to_nat(U32.shrn(n, p))),
            N.le_div_iff_mul_le(m, U32.to_nat(U32.shrn(n, p)), 1n)),
          (
            %u32_shr_nat(U32.shrn(n, p)) : N.le(m, _)
            h
          )))

def shrn_small_case(flag: Bool, +s: Nat, +n: U32, +m: Nat,
  h: N.lt(U32.to_nat(n), Nat.mul(m, L.pow2(s))),
  eq: {Nat.is_le(m, U32.to_nat(U32.shrn(n, s))) == flag : Bool}) ->
  N.lt(U32.to_nat(U32.shrn(n, s)), m):
  match flag:
    case False{}:
      N.lt_of_not_le(m, U32.to_nat(U32.shrn(n, s)), eq)
    case True{}:
      Empty.absurd(N.lt(U32.to_nat(U32.shrn(n, s)), m),
        N.lt_irrefl(Nat.mul(m, L.pow2(s)))(
          N.lt_of_le_of_lt(Nat.mul(m, L.pow2(s)), U32.to_nat(n), Nat.mul(m, L.pow2(s)),
            shrn_lower(s, n, m, eq), h)))

def shrn_small(+s: Nat, +n: U32, +m: Nat,
  h: N.lt(U32.to_nat(n), Nat.mul(m, L.pow2(s)))) ->
  N.lt(U32.to_nat(U32.shrn(n, s)), m):
  shrn_small_case(Nat.is_le(m, U32.to_nat(U32.shrn(n, s))), s, n, m, h, {==})

def log2_acc(k: Nat, +n: U32, +b: Nat) ->
  {U32.log2.go(k, n, b) == Nat.add(b, U32.log2.go(k, n, 0n)) : Nat}:
  match k:
    case 0n:
      Equal.sym(Nat, Nat.add(b, 0n), b, N.add_zero(b))
    case 1n+ +p:
      +s = U32.to_nat(U32.shln(1, p))
      +t = Nat.mul(s, U32.to_nat(Bool.to_u32(U32.is_ne(U32.shrn(n, s), 0))))
      +q = U32.shrn(n, t)
      Equal.trans(Nat, U32.log2.go(p, q, Nat.add(b, t)),
        Nat.add(Nat.add(b, t), U32.log2.go(p, q, 0n)),
        Nat.add(b, U32.log2.go(p, q, t)),
        log2_acc(p, q, Nat.add(b, t)),
        Equal.trans(Nat, Nat.add(Nat.add(b, t), U32.log2.go(p, q, 0n)),
          Nat.add(b, Nat.add(t, U32.log2.go(p, q, 0n))),
          Nat.add(b, U32.log2.go(p, q, t)),
          N.add_assoc(b, t, U32.log2.go(p, q, 0n)),
          Equal.cong(Nat, Nat, x => Nat.add(b, x),
            Nat.add(t, U32.log2.go(p, q, 0n)), U32.log2.go(p, q, t),
            Equal.sym(Nat, U32.log2.go(p, q, t), Nat.add(t, U32.log2.go(p, q, 0n)), log2_acc(p, q, t)))))

def not_false(+t: Bool, h: {Bool.not(t) == False{} : Bool}) -> {t == True{} : Bool}:
  match t:
    case True{}:
      {==}
    case False{}:
      Empty.absurd({False{} == True{} : Bool},
        N.internal_false_ne_true(Equal.sym(Bool, True{}, False{}, h)))

def shrn_zero_bound(+s: Nat, +n: U32,
  h: {U32.is_ne(U32.shrn(n, s), 0) == False{} : Bool}) ->
  N.lt(U32.to_nat(n), L.pow2(s)):
  %N.one_mul(L.pow2(s)) : N.lt(U32.to_nat(n), _)
  shrn_upper(s, n, 1n,
    (
      %Equal.sym(Nat, U32.to_nat(U32.shrn(n, s)), 0n,
        zero_test_value(U32.shrn(n, s), not_false(U32.is_zero(U32.shrn(n, s)), h))) : N.lt(_, 1n)
      {==}
    ))

def log_square_budget(+p: Nat) ->
  {Nat.mul(L.pow2(L.pow2(p)), L.pow2(L.pow2(p))) == L.pow2(L.pow2(1n+p)) : Nat}:
  Equal.trans(Nat, Nat.mul(L.pow2(L.pow2(p)), L.pow2(L.pow2(p))),
    L.pow2(Nat.add(L.pow2(p), L.pow2(p))), L.pow2(Nat.double(L.pow2(p))),
    pow2_mul(L.pow2(p), L.pow2(p)),
    Equal.cong(Nat, Nat, L.pow2, Nat.add(L.pow2(p), L.pow2(p)), Nat.double(L.pow2(p)),
      Equal.sym(Nat, Nat.double(L.pow2(p)), Nat.add(L.pow2(p), L.pow2(p)), N.double_eq_add(L.pow2(p)))))

def log_shift_cap(+p: Nat, +n: U32, h: N.lt(U32.to_nat(n), L.pow2(L.pow2(1n+p)))) ->
  N.lt(U32.to_nat(U32.shrn(n, L.pow2(p))), L.pow2(L.pow2(p))):
  shrn_small(L.pow2(p), n, L.pow2(L.pow2(p)),
    (
      %Equal.sym(Nat, Nat.mul(L.pow2(L.pow2(p)), L.pow2(L.pow2(p))),
        L.pow2(L.pow2(1n+p)), log_square_budget(p)) : N.lt(U32.to_nat(n), _)
      h
    ))

def log_scale(+k: Nat, +q: U32, +s: Nat) ->
  {Nat.mul(L.pow2(1n+U32.log2.go(k, q, 0n)), L.pow2(s)) ==
    L.pow2(1n+U32.log2.go(k, q, s)) : Nat}:
  Equal.trans(Nat,
    Nat.mul(L.pow2(1n+U32.log2.go(k, q, 0n)), L.pow2(s)),
    L.pow2(Nat.add(1n+U32.log2.go(k, q, 0n), s)),
    L.pow2(1n+U32.log2.go(k, q, s)),
    pow2_mul(1n+U32.log2.go(k, q, 0n), s),
    Equal.cong(Nat, Nat, L.pow2,
      Nat.add(1n+U32.log2.go(k, q, 0n), s), 1n+U32.log2.go(k, q, s),
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(U32.log2.go(k, q, 0n), s), U32.log2.go(k, q, s),
        Equal.trans(Nat, Nat.add(U32.log2.go(k, q, 0n), s),
          Nat.add(s, U32.log2.go(k, q, 0n)), U32.log2.go(k, q, s),
          N.add_comm(U32.log2.go(k, q, 0n), s),
          Equal.sym(Nat, U32.log2.go(k, q, s), Nat.add(s, U32.log2.go(k, q, 0n)), log2_acc(k, q, s))))))

def log_next(+p: Nat, +n: U32, +t: Nat) -> Nat:
  U32.log2.go(p, U32.shrn(n, t), t)

def log_update(+p: Nat, +n: U32, +s: Nat) -> Nat:
  log_next(p, n, Nat.mul(s, U32.to_nat(Bool.to_u32(U32.is_ne(U32.shrn(n, s), 0)))))

def log2_input_bound(k: Nat, +n: U32, +hk: N.le(k, 5n),
  cap: N.lt(U32.to_nat(n), L.pow2(L.pow2(k)))) ->
  N.lt(U32.to_nat(n), L.pow2(1n+U32.log2.go(k, n, 0n))):
  match k:
    case 0n:
      cap
    case 1n+ +p:
      %Equal.sym(Nat, U32.to_nat(U32.shln(1, p)), L.pow2(p),
        seed_nat(p, N.lt_of_le_of_lt(p, 4n, 32n, hk, {==}))) :
        N.lt(U32.to_nat(n), L.pow2(1n+log_update(p, n, _)))
      bool_split(
        flag => N.lt(U32.to_nat(n), L.pow2(1n+log_next(p, n, Nat.mul(L.pow2(p), U32.to_nat(Bool.to_u32(flag)))))),
        U32.is_ne(U32.shrn(n, L.pow2(p)), 0),
        yes => (
          %Equal.sym(Nat, Nat.mul(L.pow2(p), 1n), L.pow2(p), N.mul_one(L.pow2(p))) :
            N.lt(U32.to_nat(n), L.pow2(1n+log_next(p, n, _)))
          %log_scale(p, U32.shrn(n, L.pow2(p)), L.pow2(p)) : N.lt(U32.to_nat(n), _)
          shrn_upper(L.pow2(p), n, L.pow2(1n+U32.log2.go(p, U32.shrn(n, L.pow2(p)), 0n)),
            log2_input_bound(p, U32.shrn(n, L.pow2(p)),
              N.le_trans(p, 4n, 5n, hk, {==}), log_shift_cap(p, n, cap)))
        ),
        no => (
          %Equal.sym(Nat, Nat.mul(L.pow2(p), 0n), 0n, N.mul_zero(L.pow2(p))) :
            N.lt(U32.to_nat(n), L.pow2(1n+log_next(p, n, _)))
          log2_input_bound(p, n, N.le_trans(p, 4n, 5n, hk, {==}), shrn_zero_bound(L.pow2(p), n, no))
        ))

def log2_input(+n: U32) ->
  N.lt(U32.to_nat(n), L.pow2(1n+U32.log2(n))):
  log2_input_bound(5n, n, {==}, log2_initial_budget(n))

def pow2_mono(+a: Nat, +b: Nat, h: N.le(a, b)) -> N.le(L.pow2(a), L.pow2(b)):
  %Equal.cong(Nat, Nat, L.pow2, Nat.add(Nat.sub(b, a), a), b, N.sub_add_cancel(b, a, h)) :
    N.le(L.pow2(a), _)
  pow2_le_add(Nat.sub(b, a), a)

def half_exponent(+k: Nat) ->
  N.le(1n+k, Nat.add(1n+Nat.div(k, 2n), 1n+Nat.div(k, 2n))):
  %N.double_eq_add(1n+Nat.div(k, 2n)) : N.le(1n+k, _)
  N.succ_le_of_lt(k, Nat.double(1n+Nat.div(k, 2n)),
    (
      %N.double_div_two_add_mod_two(k) : N.lt(_, Nat.double(1n+Nat.div(k, 2n)))
      %N.add_comm(Nat.double(Nat.div(k, 2n)), 2n) :
        N.lt(Nat.add(Nat.double(Nat.div(k, 2n)), Nat.mod(k, 2n)), _)
      N.add_lt_add_left(Nat.mod(k, 2n), 2n, Nat.double(Nat.div(k, 2n)), N.mod_lt(k, 1n))
    ))

def seed_upper(+n: U32) ->
  N.lt(U32.to_nat(n),
    Nat.mul(U32.to_nat(U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))),
      U32.to_nat(U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))))):
  +e = {1n+Nat.div(U32.log2(n), 2n) : Nat}
  %Equal.sym(Nat, U32.to_nat(U32.shln(1, e)), L.pow2(e),
    seed_nat(e, N.lt_of_le_of_lt(e, 16n, 32n, seed_exponent_bound(n), {==}))) :
    N.lt(U32.to_nat(n), Nat.mul(_, _))
  %Equal.sym(Nat, Nat.mul(L.pow2(e), L.pow2(e)), L.pow2(Nat.add(e, e)), pow2_mul(e, e)) :
    N.lt(U32.to_nat(n), _)
  N.lt_of_lt_of_le(U32.to_nat(n), L.pow2(1n+U32.log2(n)), L.pow2(Nat.add(e, e)),
    log2_input(n), pow2_mono(1n+U32.log2(n), Nat.add(e, e), half_exponent(U32.log2(n))))

def newton_raw_bound(+n: Nat, +r: Nat) ->
  N.le(Nat.mul(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n), r),
    Nat.add(Nat.mul(r, r), n)):
  N.le_trans(
    Nat.mul(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n), r),
    Nat.mul(Nat.add(r, Nat.div(n, r)), r), Nat.add(Nat.mul(r, r), n),
    N.mul_le_mul_right(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n),
      Nat.add(r, Nat.div(n, r)), r, N.div_mul_le_self(Nat.add(r, Nat.div(n, r)), 2n)),
    (
      %Equal.sym(Nat, Nat.mul(Nat.add(r, Nat.div(n, r)), r),
        Nat.add(Nat.mul(r, r), Nat.mul(Nat.div(n, r), r)), N.add_mul(r, Nat.div(n, r), r)) :
        N.le(_, Nat.add(Nat.mul(r, r), n))
      N.add_le_add_left(Nat.mul(Nat.div(n, r), r), n, Nat.mul(r, r), N.div_mul_le_self(n, r))
    ))

def twice_product(+m: Nat, +r: Nat) ->
  {Nat.mul(Nat.mul(m, 2n), r) == Nat.add(Nat.mul(m, r), Nat.mul(m, r)) : Nat}:
  Equal.trans(Nat, Nat.mul(Nat.mul(m, 2n), r), Nat.mul(Nat.add(m, m), r),
    Nat.add(Nat.mul(m, r), Nat.mul(m, r)),
    Equal.cong(Nat, Nat, x => Nat.mul(x, r), Nat.mul(m, 2n), Nat.add(m, m), N.mul_two(m)),
    N.add_mul(m, m, r))

def difference_complete(+a: Nat, +b: Nat, +c: Nat, h: N.le(c, b)) ->
  {Nat.sub(Nat.add(a, c), Nat.add(b, b)) ==
    Nat.sub(Nat.sub(a, b), Nat.sub(b, c)) : Nat}:
  +d = Nat.sub(b, c)
  %N.add_comm(c, a) :
    {Nat.sub(_, Nat.add(b, b)) == Nat.sub(Nat.sub(a, b), d) : Nat}
  %Equal.sym(Nat, Nat.add(b, b), Nat.add(c, Nat.add(d, b)),
    Equal.trans(Nat, Nat.add(b, b), Nat.add(Nat.add(c, d), b), Nat.add(c, Nat.add(d, b)),
      Equal.cong(Nat, Nat, x => Nat.add(x, b), b, Nat.add(c, d),
        Equal.sym(Nat, Nat.add(c, d), b, N.add_sub_of_le(c, b, h))), N.add_assoc(c, d, b))) :
    {Nat.sub(Nat.add(c, a), _) == Nat.sub(Nat.sub(a, b), d) : Nat}
  %Equal.sym(Nat, Nat.sub(Nat.add(c, a), Nat.add(c, Nat.add(d, b))), Nat.sub(a, Nat.add(d, b)),
    N.add_sub_add_left(c, a, Nat.add(d, b))) :
    {_ == Nat.sub(Nat.sub(a, b), d) : Nat}
  %N.add_comm(b, d) : {Nat.sub(a, _) == Nat.sub(Nat.sub(a, b), d) : Nat}
  Equal.sym(Nat, Nat.sub(Nat.sub(a, b), d), Nat.sub(a, Nat.add(b, d)), N.sub_sub(a, b, d))

def quadratic_identity(+r: Nat, +m: Nat, hr: N.le(m, r)) ->
  {Nat.sub(Nat.add(Nat.mul(r, r), Nat.mul(m, m)), Nat.mul(Nat.mul(m, 2n), r)) ==
    Nat.mul(Nat.sub(r, m), Nat.sub(r, m)) : Nat}:
  %Equal.sym(Nat, Nat.mul(Nat.mul(m, 2n), r), Nat.add(Nat.mul(m, r), Nat.mul(m, r)),
    twice_product(m, r)) :
    {Nat.sub(Nat.add(Nat.mul(r, r), Nat.mul(m, m)), _) == Nat.mul(Nat.sub(r, m), Nat.sub(r, m)) : Nat}
  %Equal.sym(Nat,
    Nat.sub(Nat.add(Nat.mul(r, r), Nat.mul(m, m)), Nat.add(Nat.mul(m, r), Nat.mul(m, r))),
    Nat.sub(Nat.sub(Nat.mul(r, r), Nat.mul(m, r)), Nat.sub(Nat.mul(m, r), Nat.mul(m, m))),
    difference_complete(Nat.mul(r, r), Nat.mul(m, r), Nat.mul(m, m), N.mul_le_mul_left(m, r, m, hr))) :
    {_ == Nat.mul(Nat.sub(r, m), Nat.sub(r, m)) : Nat}
  %N.mul_comm(r, m) :
    {Nat.sub(Nat.sub(Nat.mul(r, r), Nat.mul(m, r)), Nat.sub(_, Nat.mul(m, m))) ==
      Nat.mul(Nat.sub(r, m), Nat.sub(r, m)) : Nat}
  %N.sub_mul(r, m, r) :
    {Nat.sub(_, Nat.sub(Nat.mul(r, m), Nat.mul(m, m))) == Nat.mul(Nat.sub(r, m), Nat.sub(r, m)) : Nat}
  %N.sub_mul(r, m, m) :
    {Nat.sub(Nat.mul(Nat.sub(r, m), r), _) == Nat.mul(Nat.sub(r, m), Nat.sub(r, m)) : Nat}
  Equal.sym(Nat, Nat.mul(Nat.sub(r, m), Nat.sub(r, m)),
    Nat.sub(Nat.mul(Nat.sub(r, m), r), Nat.mul(Nat.sub(r, m), m)), N.mul_sub(Nat.sub(r, m), r, m))

def newton_error_bound(+n: Nat, +r: Nat, +m: Nat,
  hn: N.le(n, Nat.mul(m, m)), hr: N.le(m, r)) ->
  N.le(
    Nat.sub(Nat.mul(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n), r),
      Nat.mul(Nat.mul(m, 2n), r)),
    Nat.mul(Nat.sub(r, m), Nat.sub(r, m))):
  %quadratic_identity(r, m, hr) :
    N.le(Nat.sub(Nat.mul(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n), r),
      Nat.mul(Nat.mul(m, 2n), r)), _)
  N.sub_le_sub_right(
    Nat.mul(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n), r),
    Nat.add(Nat.mul(r, r), Nat.mul(m, m)),
    N.le_trans(Nat.mul(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n), r),
      Nat.add(Nat.mul(r, r), n), Nat.add(Nat.mul(r, r), Nat.mul(m, m)),
      newton_raw_bound(n, r), N.add_le_add_left(n, Nat.mul(m, m), Nat.mul(r, r), hn)),
    Nat.mul(Nat.mul(m, 2n), r))

def error_product(+a: Nat, +b: Nat, +r: Nat) ->
  {Nat.mul(Nat.mul(Nat.sub(a, b), 2n), r) ==
    Nat.sub(Nat.mul(Nat.mul(a, 2n), r), Nat.mul(Nat.mul(b, 2n), r)) : Nat}:
  Equal.trans(Nat, Nat.mul(Nat.mul(Nat.sub(a, b), 2n), r),
    Nat.mul(Nat.sub(Nat.mul(a, 2n), Nat.mul(b, 2n)), r),
    Nat.sub(Nat.mul(Nat.mul(a, 2n), r), Nat.mul(Nat.mul(b, 2n), r)),
    Equal.cong(Nat, Nat, x => Nat.mul(x, r),
      Nat.mul(Nat.sub(a, b), 2n), Nat.sub(Nat.mul(a, 2n), Nat.mul(b, 2n)), N.sub_mul(a, b, 2n)),
    N.sub_mul(Nat.mul(a, 2n), Nat.mul(b, 2n), r))

def newton_error(+n: Nat, +r: Nat, +m: Nat, hn: N.le(n, Nat.mul(m, m)), hr: N.le(m, r)) ->
  N.le(Nat.mul(Nat.mul(Nat.sub(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), m), 2n), r),
    Nat.mul(Nat.sub(r, m), Nat.sub(r, m))):
  %Equal.sym(Nat,
    Nat.mul(Nat.mul(Nat.sub(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), m), 2n), r),
    Nat.sub(Nat.mul(Nat.mul(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 2n), r), Nat.mul(Nat.mul(m, 2n), r)),
    error_product(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), m, r)) :
    N.le(_, Nat.mul(Nat.sub(r, m), Nat.sub(r, m)))
  newton_error_bound(n, r, m, hn, hr)

def mul_four(+a: Nat, +b: Nat, +c: Nat, +d: Nat) ->
  {Nat.mul(Nat.mul(a, b), Nat.mul(c, d)) == Nat.mul(Nat.mul(a, c), Nat.mul(b, d)) : Nat}:
  Equal.trans(Nat, Nat.mul(Nat.mul(a, b), Nat.mul(c, d)),
    Nat.mul(Nat.mul(Nat.mul(a, b), c), d), Nat.mul(Nat.mul(a, c), Nat.mul(b, d)),
    Equal.sym(Nat, Nat.mul(Nat.mul(Nat.mul(a, b), c), d), Nat.mul(Nat.mul(a, b), Nat.mul(c, d)),
      N.mul_assoc(Nat.mul(a, b), c, d)),
    Equal.trans(Nat, Nat.mul(Nat.mul(Nat.mul(a, b), c), d),
      Nat.mul(Nat.mul(Nat.mul(a, c), b), d), Nat.mul(Nat.mul(a, c), Nat.mul(b, d)),
      Equal.cong(Nat, Nat, x => Nat.mul(x, d),
        Nat.mul(Nat.mul(a, b), c), Nat.mul(Nat.mul(a, c), b), mul_exchange(a, b, c)),
      N.mul_assoc(Nat.mul(a, c), b, d)))

def positive_le_cancel(+a: Nat, +b: Nat, c: Nat, pos: N.lt(0n, c),
  h: N.le(Nat.mul(a, c), Nat.mul(b, c))) -> N.le(a, b):
  match c:
    case 0n:
      Empty.absurd(N.le(a, b), N.lt_irrefl(0n)(pos))
    case 1n+ +p:
      %N.mul_div_cancel(a, p) : N.le(_, b)
      %N.mul_div_cancel(b, p) : N.le(Nat.div(Nat.mul(a, 1n+p), 1n+p), _)
      N.div_le_div(Nat.mul(a, 1n+p), Nat.mul(b, 1n+p), p, h)

def error_contract(+e: Nat, +d: Nat, +r: Nat, +m: Nat, +scale: Nat,
  pos: N.lt(0n, m), hr: N.le(m, r),
  weighted: N.le(Nat.mul(Nat.mul(e, 2n), r), Nat.mul(d, d)),
  +scaled: N.le(Nat.mul(d, scale), m)) ->
  N.le(Nat.mul(e, Nat.mul(2n, Nat.mul(scale, scale))), m):
  %N.mul_assoc(e, 2n, Nat.mul(scale, scale)) : N.le(_, m)
  positive_le_cancel(Nat.mul(Nat.mul(e, 2n), Nat.mul(scale, scale)), m, m, pos,
    N.le_trans(
      Nat.mul(Nat.mul(Nat.mul(e, 2n), Nat.mul(scale, scale)), m),
      Nat.mul(Nat.mul(Nat.mul(e, 2n), Nat.mul(scale, scale)), r), Nat.mul(m, m),
      N.mul_le_mul_left(m, r, Nat.mul(Nat.mul(e, 2n), Nat.mul(scale, scale)), hr),
      N.le_trans(
        Nat.mul(Nat.mul(Nat.mul(e, 2n), Nat.mul(scale, scale)), r),
        Nat.mul(Nat.mul(d, scale), Nat.mul(d, scale)), Nat.mul(m, m),
        (
          %mul_exchange(Nat.mul(e, 2n), r, Nat.mul(scale, scale)) :
            N.le(_, Nat.mul(Nat.mul(d, scale), Nat.mul(d, scale)))
          %mul_four(d, d, scale, scale) :
            N.le(Nat.mul(Nat.mul(Nat.mul(e, 2n), r), Nat.mul(scale, scale)), _)
          N.mul_le_mul_right(Nat.mul(Nat.mul(e, 2n), r), Nat.mul(d, d), Nat.mul(scale, scale), weighted)
        ),
        N.mul_le_mul(Nat.mul(d, scale), Nat.mul(d, scale), m, m, scaled, scaled))))

def first_error_contract(+e: Nat, +d: Nat, +r: Nat, +m: Nat,
  pos: N.lt(0n, r), sum: {Nat.add(m, d) == r : Nat}, +hd: N.le(d, m),
  weighted: N.le(Nat.mul(Nat.mul(e, 2n), r), Nat.mul(d, d))) ->
  N.le(Nat.mul(e, 4n), m):
  positive_le_cancel(Nat.mul(e, 4n), m, r, pos,
    N.le_trans(Nat.mul(Nat.mul(e, 4n), r), Nat.mul(Nat.mul(d, d), 2n), Nat.mul(m, r),
      (
        %N.mul_assoc(e, 2n, 2n) :
          N.le(Nat.mul(_, r), Nat.mul(Nat.mul(d, d), 2n))
        %mul_exchange(Nat.mul(e, 2n), r, 2n) :
          N.le(_, Nat.mul(Nat.mul(d, d), 2n))
        N.mul_le_mul_right(Nat.mul(Nat.mul(e, 2n), r), Nat.mul(d, d), 2n, weighted)
      ),
      (
        %Equal.sym(Nat, Nat.mul(Nat.mul(d, d), 2n), Nat.add(Nat.mul(d, d), Nat.mul(d, d)),
          N.mul_two(Nat.mul(d, d))) : N.le(_, Nat.mul(m, r))
        %Equal.cong(Nat, Nat, x => Nat.mul(m, x), Nat.add(m, d), r, sum) :
          N.le(Nat.add(Nat.mul(d, d), Nat.mul(d, d)), _)
        %Equal.sym(Nat, Nat.mul(m, Nat.add(m, d)), Nat.add(Nat.mul(m, m), Nat.mul(m, d)),
          N.mul_add(m, m, d)) :
          N.le(Nat.add(Nat.mul(d, d), Nat.mul(d, d)), _)
        N.add_le_add(Nat.mul(d, d), Nat.mul(d, d), Nat.mul(m, m), Nat.mul(m, d),
          N.mul_le_mul(d, d, m, m, hd, hd), N.mul_le_mul_right(d, m, d, hd))
      )))

def initial_error(+r: Nat, +m: Nat, cap: N.le(r, Nat.mul(m, 2n))) ->
  N.le(Nat.sub(r, m), m):
  %N.add_sub_cancel_left(m, m) : N.le(Nat.sub(r, m), _)
  N.sub_le_sub_right(r, Nat.add(m, m),
    (
      %N.mul_two(m) : N.le(r, _)
      cap
    ), m)

def newton_floor.le_transport(+a: Nat, +b: Nat, +c: Nat, +d: Nat,
  e: {a == c : Nat}, f: {b == d : Nat}, h: N.le(a, b)) -> N.le(c, d):
  %e : N.le(_, d)
  %f : N.le(a, _)
  h

def newton_floor.sum_succ(+a: Nat, +b: Nat) ->
  {Nat.add(1n+a, 1n+b) == 2n+Nat.add(a, b) : Nat}:
  Equal.cong(Nat, Nat, x => 1n+x, Nat.add(a, 1n+b), 1n+Nat.add(a, b), N.add_succ(a, b))

def newton_floor.product_succ(+a: Nat, +b: Nat) ->
  {Nat.mul(1n+a, 1n+b) == 1n+Nat.add(Nat.add(a, b), Nat.mul(a, b)) : Nat}:
  %Equal.sym(Nat, Nat.mul(a, 1n+b), Nat.add(Nat.mul(a, b), a), N.mul_succ(a, b)) :
    {1n+Nat.add(b, _) == 1n+Nat.add(Nat.add(a, b), Nat.mul(a, b)) : Nat}
  %N.add_comm(a, Nat.mul(a, b)) :
    {1n+Nat.add(b, _) == 1n+Nat.add(Nat.add(a, b), Nat.mul(a, b)) : Nat}
  %N.add_assoc(b, a, Nat.mul(a, b)) :
    {1n+_ == 1n+Nat.add(Nat.add(a, b), Nat.mul(a, b)) : Nat}
  %N.add_comm(a, b) :
    {1n+Nat.add(_, Nat.mul(a, b)) == 1n+Nat.add(Nat.add(a, b), Nat.mul(a, b)) : Nat}
  {==}

# Strip one from each positive factor and one from the half-sum bound.
def newton_floor.amgm(+s: Nat, +a: Nat, +b: Nat,
  h: N.le(Nat.add(a, b), Nat.add(s, s))) -> N.le(Nat.mul(a, b), Nat.mul(s, s)):
  match s:
    case 0n:
      match a:
        case 0n:
          N.zero_le(0n)
        case 1n+p:
          Empty.absurd(N.le(Nat.mul(1n+p, b), 0n),
            N.succ_ne_zero(Nat.add(p, b))(N.le_zero_eq(1n+Nat.add(p, b), h)))
    case 1n+t:
      match a:
        case 0n:
          N.zero_le(Nat.mul(1n+t, 1n+t))
        case 1n+p:
          match b:
            case 0n:
              %Equal.sym(Nat, Nat.mul(1n+p, 0n), 0n, N.mul_zero(1n+p)) :
                N.le(_, Nat.mul(1n+t, 1n+t))
              N.zero_le(Nat.mul(1n+t, 1n+t))
            case 1n+q:
              +hs : N.le(Nat.add(p, q), Nat.add(t, t)) =
                newton_floor.le_transport(Nat.add(1n+p, 1n+q), Nat.add(1n+t, 1n+t),
                  2n+Nat.add(p, q), 2n+Nat.add(t, t),
                  newton_floor.sum_succ(p, q), newton_floor.sum_succ(t, t), h)
              %Equal.sym(Nat, Nat.mul(1n+p, 1n+q), 1n+Nat.add(Nat.add(p, q), Nat.mul(p, q)),
                newton_floor.product_succ(p, q)) : N.le(_, Nat.mul(1n+t, 1n+t))
              %Equal.sym(Nat, Nat.mul(1n+t, 1n+t), 1n+Nat.add(Nat.add(t, t), Nat.mul(t, t)),
                newton_floor.product_succ(t, t)) :
                N.le(1n+Nat.add(Nat.add(p, q), Nat.mul(p, q)), _)
              N.add_le_add(Nat.add(p, q), Nat.mul(p, q), Nat.add(t, t), Nat.mul(t, t),
                hs, newton_floor.amgm(t, p, q, hs))

def newton_floor.quotient_strict(+n: Nat, +p: Nat) ->
  N.lt(n, Nat.mul(1n+p, 1n+Nat.div(n, 1n+p))):
  +q = Nat.div(n, 1n+p)
  %N.mul_comm(1n+q, 1n+p) : N.lt(n, _)
  N.lt_of_not_le(Nat.mul(1n+q, 1n+p), n,
    Equal.trans(Bool, Nat.is_le(Nat.mul(1n+q, 1n+p), n), Nat.is_le(1n+q, q), False{},
      Equal.sym(Bool, Nat.is_le(1n+q, q), Nat.is_le(Nat.mul(1n+q, 1n+p), n),
        N.le_div_iff_mul_le(1n+q, n, p)),
      N.not_le_of_lt(q, 1n+q, N.lt_succ_self(q))))

def newton_floor.mul_two(+s: Nat) -> {Nat.mul(s, 2n) == Nat.add(s, s) : Nat}:
  %N.mul_comm(2n, s) : {_ == Nat.add(s, s) : Nat}
  %Equal.sym(Nat, Nat.add(s, 0n), s, N.add_zero(s)) :
    {Nat.add(s, _) == Nat.add(s, s) : Nat}
  {==}

def newton_floor.half_sum(+a: Nat, +b: Nat) ->
  N.le(Nat.add(a, 1n+b),
    Nat.add(1n+Nat.div(Nat.add(a, b), 2n), 1n+Nat.div(Nat.add(a, b), 2n))):
  +m = Nat.add(a, b)
  +s = {1n+Nat.div(m, 2n) : Nat}
  newton_floor.le_transport(1n+m, Nat.mul(s, 2n), Nat.add(a, 1n+b), Nat.add(s, s),
    Equal.sym(Nat, Nat.add(a, 1n+b), 1n+m, N.add_succ(a, b)), newton_floor.mul_two(s),
    N.succ_le_of_lt(m, Nat.mul(s, 2n),
      (
        %N.mul_comm(2n, s) : N.lt(m, _)
        newton_floor.quotient_strict(m, 1n)
      )))

def newton_floor.upper(+n: Nat, +p: Nat) ->
  N.lt(n, Nat.mul(1n+Nat.div(Nat.add(1n+p, Nat.div(n, 1n+p)), 2n),
                  1n+Nat.div(Nat.add(1n+p, Nat.div(n, 1n+p)), 2n))):
  +q = Nat.div(n, 1n+p)
  +s = {1n+Nat.div(Nat.add(1n+p, q), 2n) : Nat}
  N.lt_of_lt_of_le(n, Nat.mul(1n+p, 1n+q), Nat.mul(s, s),
    newton_floor.quotient_strict(n, p),
    newton_floor.amgm(s, 1n+p, 1n+q, newton_floor.half_sum(1n+p, q)))

def newton_floor.lower_case(test: Bool, +n: Nat, +s: Nat, +t: Nat,
  decision: {Nat.is_le(t, s) == test : Bool}, square: N.le(Nat.mul(t, t), n),
  upper: N.lt(n, Nat.mul(1n+s, 1n+s))) -> N.le(t, s):
  match test:
    case True{}:
      decision
    case False{}:
      +lower = N.succ_le_of_lt(s, t, N.lt_of_not_le(t, s, decision))
      Empty.absurd(N.le(t, s),
        N.lt_irrefl(n)(N.lt_of_lt_of_le(n, Nat.mul(1n+s, 1n+s), n, upper,
          N.le_trans(Nat.mul(1n+s, 1n+s), Nat.mul(t, t), n,
            N.mul_le_mul(1n+s, 1n+s, t, t, lower, lower), square))))

def newton_floor_lower(+n: Nat, +r: Nat, +t: Nat,
  positive: N.lt(0n, r), square: N.le(Nat.mul(t, t), n)) ->
  N.le(t, Nat.div(Nat.add(r, Nat.div(n, r)), 2n)):
  match r:
    case 0n:
      Empty.absurd(N.le(t, Nat.div(Nat.add(0n, Nat.div(n, 0n)), 2n)),
        N.lt_irrefl(0n)(positive))
    case 1n+p:
      +s = Nat.div(Nat.add(1n+p, Nat.div(n, 1n+p)), 2n)
      newton_floor.lower_case(Nat.is_le(t, s), n, s, t, {==}, square,
        newton_floor.upper(n, p))

# (r + 1)^2 = 1 + r * (r + 2), with products left folded.
def newton_near_square(+r: Nat) ->
  {Nat.mul(1n+r, 1n+r) == 1n+Nat.mul(r, 2n+r) : Nat}:
  %Equal.sym(Nat, Nat.mul(r, 2n+r),
    Nat.add(Nat.mul(r, 1n+r), r), N.mul_succ(r, 1n+r)) :
    {Nat.mul(1n+r, 1n+r) == 1n+_ : Nat}
  Equal.cong(Nat, Nat, x => 1n+x,
    Nat.add(r, Nat.mul(r, 1n+r)), Nat.add(Nat.mul(r, 1n+r), r),
    N.add_comm(r, Nat.mul(r, 1n+r)))

def newton_near_sum(+r: Nat) ->
  {Nat.add(r, 2n+r) == Nat.mul(2n, 1n+r) : Nat}:
  %Equal.sym(Nat, Nat.add(1n+r, 0n), 1n+r, N.add_zero(1n+r)) :
    {Nat.add(r, 2n+r) == Nat.add(1n+r, _) : Nat}
  N.add_succ(r, 1n+r)

# Monotonicity and exact cancellation give the upper quotient bound.
def newton_near_div_bound(+a: Nat, +b: Nat, +k: Nat,
  positive: N.lt(0n, b), bound: N.le(a, Nat.mul(b, k))) ->
  N.le(Nat.div(a, b), k):
  match b:
    case 0n:
      Empty.absurd(N.le(Nat.div(a, 0n), k), N.lt_irrefl(0n)(positive))
    case 1n+ +p:
      %N.mul_div_cancel_left(k, p) : N.le(Nat.div(a, 1n+p), _)
      N.div_le_div(a, Nat.mul(1n+p, k), p, bound)

def newton_near_root(+n: Nat, +r: Nat,
  positive: N.lt(0n, r), cap: N.lt(n, Nat.mul(1n+r, 1n+r))) ->
  N.le(Nat.div(Nat.add(r, Nat.div(n, r)), 2n), 1n+r):
  newton_near_div_bound(Nat.add(r, Nat.div(n, r)), 2n, 1n+r, {==}, (
    %newton_near_sum(r) : N.le(Nat.add(r, Nat.div(n, r)), _)
    N.add_le_add_left(Nat.div(n, r), 2n+r, r,
      newton_near_div_bound(n, r, 2n+r, positive,
        N.le_of_lt_succ(n, Nat.mul(r, 2n+r), (
          %newton_near_square(r) : N.lt(n, _)
          cap
        ))))
  ))

def next_nat(+n: Nat, +r: Nat) -> Nat:
  Nat.div(Nat.add(r, Nat.div(n, r)), 2n)

def scale_step(+k: Nat) ->
  {Nat.mul(2n, Nat.mul(L.pow2(k), L.pow2(k))) == L.pow2(1n+Nat.add(k, k)) : Nat}:
  Equal.trans(Nat, Nat.mul(2n, Nat.mul(L.pow2(k), L.pow2(k))),
    Nat.mul(2n, L.pow2(Nat.add(k, k))), Nat.double(L.pow2(Nat.add(k, k))),
    Equal.cong(Nat, Nat, x => Nat.mul(2n, x),
      Nat.mul(L.pow2(k), L.pow2(k)), L.pow2(Nat.add(k, k)), pow2_mul(k, k)),
    Equal.sym(Nat, Nat.double(L.pow2(Nat.add(k, k))), Nat.mul(2n, L.pow2(Nat.add(k, k))),
      N.double_eq_two_mul(L.pow2(Nat.add(k, k)))))

def scaled_near(+n: Nat, +r: Nat, +t: Nat, +k: Nat,
  pos: N.lt(0n, t), upper: N.lt(n, Nat.mul(1n+t, 1n+t)), low: N.le(t, r),
  fail: {Nat.is_le(1n+t, r) == False{} : Bool}) ->
  N.le(Nat.mul(Nat.sub(next_nat(n, r), 1n+t), L.pow2(1n+Nat.add(k, k))), 1n+t):
  +er = N.le_antisymm(r, t, N.le_of_lt_succ(r, t, N.lt_of_not_le(1n+t, r, fail)), low)
  %Equal.sym(Nat, r, t, er) :
    N.le(Nat.mul(Nat.sub(next_nat(n, _), 1n+t), L.pow2(1n+Nat.add(k, k))), 1n+t)
  %Equal.sym(Nat, Nat.sub(next_nat(n, t), 1n+t), 0n,
    N.sub_eq_zero_of_le(next_nat(n, t), 1n+t, newton_near_root(n, t, pos, upper))) :
    N.le(Nat.mul(_, L.pow2(1n+Nat.add(k, k))), 1n+t)
  N.zero_le(1n+t)

def newton_scaled_step(+n: Nat, +r: Nat, +t: Nat, +k: Nat,
  +pos: N.lt(0n, t), +upper: N.lt(n, Nat.mul(1n+t, 1n+t)), +low: N.le(t, r),
  scaled: N.le(Nat.mul(Nat.sub(r, 1n+t), L.pow2(k)), 1n+t)) ->
  N.le(Nat.mul(Nat.sub(next_nat(n, r), 1n+t), L.pow2(1n+Nat.add(k, k))), 1n+t):
  bool_split(
    flag => N.le(Nat.mul(Nat.sub(next_nat(n, r), 1n+t), L.pow2(1n+Nat.add(k, k))), 1n+t),
    Nat.is_le(1n+t, r),
    +yes => (
      %Equal.cong(Nat, Nat, x => Nat.mul(Nat.sub(next_nat(n, r), 1n+t), x),
        Nat.mul(2n, Nat.mul(L.pow2(k), L.pow2(k))), L.pow2(1n+Nat.add(k, k)), scale_step(k)) : N.le(_, 1n+t)
      error_contract(Nat.sub(next_nat(n, r), 1n+t), Nat.sub(r, 1n+t), r, 1n+t, L.pow2(k),
        {==}, yes, newton_error(n, r, 1n+t, N.le_of_lt(n, Nat.mul(1n+t, 1n+t), upper), yes), scaled)
    ),
    no => scaled_near(n, r, t, k, pos, upper, low, no))

def square_strict_case(flag: Bool, +a: Nat, +b: Nat,
  h: N.lt(Nat.mul(a, a), Nat.mul(b, b)), eq: {Nat.is_lt(a, b) == flag : Bool}) -> N.lt(a, b):
  match flag:
    case True{}:
      eq
    case False{}:
      Empty.absurd(N.lt(a, b),
        N.lt_irrefl(Nat.mul(a, a))(
          N.lt_of_lt_of_le(Nat.mul(a, a), Nat.mul(b, b), Nat.mul(a, a), h,
            N.mul_self_le_mul_self(b, a, N.le_of_not_lt(a, b, eq)))))

def square_strict(+a: Nat, +b: Nat, h: N.lt(Nat.mul(a, a), Nat.mul(b, b))) -> N.lt(a, b):
  square_strict_case(Nat.is_lt(a, b), a, b, h, {==})

def square_le_case(flag: Bool, +a: Nat, +b: Nat,
  h: N.le(Nat.mul(a, a), Nat.mul(b, b)), eq: {Nat.is_le(a, b) == flag : Bool}) -> N.le(a, b):
  match flag:
    case True{}:
      eq
    case False{}:
      Empty.absurd(N.le(a, b),
        N.lt_irrefl(Nat.mul(b, b))(
          N.lt_of_lt_of_le(Nat.mul(b, b), Nat.mul(a, a), Nat.mul(b, b),
            N.mul_self_lt_mul_self(b, a, N.lt_of_not_le(a, b, eq)), h)))

def square_le(+a: Nat, +b: Nat, h: N.le(Nat.mul(a, a), Nat.mul(b, b))) -> N.le(a, b):
  square_le_case(Nat.is_le(a, b), a, b, h, {==})

def seed_cap(+n: U32) ->
  N.le(U32.to_nat(U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))), L.pow2(16n)):
  +e = {1n+Nat.div(U32.log2(n), 2n) : Nat}
  %Equal.sym(Nat, U32.to_nat(U32.shln(1, e)), L.pow2(e),
    seed_nat(e, N.lt_of_le_of_lt(e, 16n, 32n, seed_exponent_bound(n), {==}))) :
    N.le(_, L.pow2(16n))
  pow2_mono(e, 16n, seed_exponent_bound(n))

def root_positive(+n: Nat, t: Nat, pos: N.lt(0n, n),
  upper: N.lt(n, Nat.mul(1n+t, 1n+t))) -> N.lt(0n, t):
  match t:
    case 0n:
      Empty.absurd(N.lt(0n, 0n),
        N.lt_irrefl(0n)(N.lt_of_lt_of_le(0n, n, 0n, pos, N.le_of_lt_succ(n, 0n, upper))))
    case 1n+p:
      {==}

def quotient_near_bound(+n: Nat, +r: Nat, +t: Nat,
  pos: N.lt(0n, t), +low: N.le(t, r), upper: N.lt(n, Nat.mul(1n+t, 1n+t))) ->
  N.le(Nat.div(n, r), 2n+t):
  newton_near_div_bound(n, r, 2n+t, N.lt_of_lt_of_le(0n, t, r, pos, low),
    N.le_trans(n, Nat.mul(t, 2n+t), Nat.mul(r, 2n+t),
      N.le_of_lt_succ(n, Nat.mul(t, 2n+t),
        (
          %newton_near_square(t) : N.lt(n, _)
          upper
        )), N.mul_le_mul_right(t, r, 2n+t, low)))

def newton_sum_cap(+n: Nat, +r: Nat, +t: Nat, +limit: Nat,
  pos: N.lt(0n, t), low: N.le(t, r), upper: N.lt(n, Nat.mul(1n+t, 1n+t)),
  rootcap: N.le(1n+t, limit), bound: N.le(r, limit)) ->
  N.le(Nat.add(r, Nat.div(n, r)), 1n+Nat.double(limit)):
  %Equal.cong(Nat, Nat, x => 1n+x, Nat.add(limit, limit), Nat.double(limit),
    Equal.sym(Nat, Nat.double(limit), Nat.add(limit, limit), N.double_eq_add(limit))) :
    N.le(Nat.add(r, Nat.div(n, r)), _)
  %N.add_succ(limit, limit) : N.le(Nat.add(r, Nat.div(n, r)), _)
  N.add_le_add(r, Nat.div(n, r), limit, 1n+limit, bound,
    N.le_trans(Nat.div(n, r), 2n+t, 1n+limit, quotient_near_bound(n, r, t, pos, low, upper), rootcap))

def next_cap(+n: Nat, +r: Nat, +t: Nat, +limit: Nat,
  pos: N.lt(0n, t), low: N.le(t, r), upper: N.lt(n, Nat.mul(1n+t, 1n+t)),
  rootcap: N.le(1n+t, limit), bound: N.le(r, limit)) ->
  N.le(next_nat(n, r), limit):
  %half_odd(limit) : N.le(next_nat(n, r), _)
  N.div_le_div(Nat.add(r, Nat.div(n, r)), 1n+Nat.double(limit), 1n,
    newton_sum_cap(n, r, t, limit, pos, low, upper, rootcap, bound))

def scaled_zero(e: Nat, +scale: Nat, +m: Nat,
  cap: N.lt(m, scale), h: N.le(Nat.mul(e, scale), m)) -> {e == 0n : Nat}:
  match e:
    case 0n:
      {==}
    case 1n+ +p:
      Empty.absurd({1n+p == 0n : Nat},
        N.lt_irrefl(m)(N.lt_of_lt_of_le(m, scale, m, cap,
          N.le_trans(scale, Nat.add(scale, Nat.mul(p, scale)), m,
            N.le_add_right(scale, Nat.mul(p, scale)), h))))

def zero_error_le(r: Nat, m: Nat, eq: {Nat.sub(r, m) == 0n : Nat}) -> N.le(r, m):
  match r m:
    case 0n q:
      N.zero_le(q)
    case 1n+p 0n:
      Empty.absurd(N.le(1n+p, 0n), N.succ_ne_zero(p)(eq))
    case 1n+p 1n+q:
      zero_error_le(p, q, eq)

def seed_not_true(+b: Bool, h: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, N.internal_false_ne_true(h))

def log_lower_scale(+k: Nat, +q: U32, +s: Nat) ->
  {Nat.mul(L.pow2(U32.log2.go(k, q, 0n)), L.pow2(s)) ==
    L.pow2(U32.log2.go(k, q, s)) : Nat}:
  Equal.trans(Nat,
    Nat.mul(L.pow2(U32.log2.go(k, q, 0n)), L.pow2(s)),
    L.pow2(Nat.add(U32.log2.go(k, q, 0n), s)),
    L.pow2(U32.log2.go(k, q, s)),
    pow2_mul(U32.log2.go(k, q, 0n), s),
    Equal.cong(Nat, Nat, L.pow2,
      Nat.add(U32.log2.go(k, q, 0n), s), U32.log2.go(k, q, s),
      Equal.trans(Nat, Nat.add(U32.log2.go(k, q, 0n), s),
        Nat.add(s, U32.log2.go(k, q, 0n)), U32.log2.go(k, q, s),
        N.add_comm(U32.log2.go(k, q, 0n), s),
        Equal.sym(Nat, U32.log2.go(k, q, s),
          Nat.add(s, U32.log2.go(k, q, 0n)), log2_acc(k, q, s)))))

def log2_go_lower(k: Nat, +n: U32, pos: N.lt(0n, U32.to_nat(n))) ->
  N.le(L.pow2(U32.log2.go(k, n, 0n)), U32.to_nat(n)):
  match k:
    case 0n:
      N.succ_le_of_lt(0n, U32.to_nat(n), pos)
    case 1n+ +p:
      +s = U32.to_nat(U32.shln(1, p))
      bool_split(
        flag => N.le(L.pow2(log_next(p, n, Nat.mul(s, U32.to_nat(Bool.to_u32(flag))))), U32.to_nat(n)),
        U32.is_ne(U32.shrn(n, s), 0),
        yes => (
          %Equal.sym(Nat, Nat.mul(s, 1n), s, N.mul_one(s)) :
            N.le(L.pow2(log_next(p, n, _)), U32.to_nat(n))
          %log_lower_scale(p, U32.shrn(n, s), s) : N.le(_, U32.to_nat(n))
          shrn_lower(s, n, L.pow2(U32.log2.go(p, U32.shrn(n, s), 0n)),
            log2_go_lower(p, U32.shrn(n, s),
              nonzero_test_value(U32.shrn(n, s),
                seed_not_true(U32.is_zero(U32.shrn(n, s)), yes))))
        ),
        no => (
          %Equal.sym(Nat, Nat.mul(s, 0n), 0n, N.mul_zero(s)) :
            N.le(L.pow2(log_next(p, n, _)), U32.to_nat(n))
          log2_go_lower(p, n, pos)
        ))

def log2_lower(+n: U32, pos: N.lt(0n, U32.to_nat(n))) ->
  N.le(L.pow2(U32.log2(n)), U32.to_nat(n)):
  log2_go_lower(5n, n, pos)

def seed_half_exponent_upper(+k: Nat) ->
  N.le(Nat.add(1n+Nat.div(k, 2n), 1n+Nat.div(k, 2n)), Nat.add(2n, k)):
  %N.double_eq_add(1n+Nat.div(k, 2n)) : N.le(_, Nat.add(2n, k))
  N.add_le_add_left(Nat.double(Nat.div(k, 2n)), k, 2n,
    (
      %Equal.trans(Nat, Nat.mul(Nat.div(k, 2n), 2n),
        Nat.add(Nat.div(k, 2n), Nat.div(k, 2n)), Nat.double(Nat.div(k, 2n)),
        N.mul_two(Nat.div(k, 2n)),
        Equal.sym(Nat, Nat.double(Nat.div(k, 2n)),
          Nat.add(Nat.div(k, 2n), Nat.div(k, 2n)), N.double_eq_add(Nat.div(k, 2n)))) : N.le(_, k)
      N.div_mul_le_self(k, 2n)
    ))

def seed_square_ratio(+n: U32, pos: N.lt(0n, U32.to_nat(n))) ->
  N.le(
    Nat.mul(U32.to_nat(U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))),
      U32.to_nat(U32.shln(1, 1n+Nat.div(U32.log2(n), 2n)))),
    Nat.mul(4n, U32.to_nat(n))):
  +e = {1n+Nat.div(U32.log2(n), 2n) : Nat}
  %Equal.sym(Nat, U32.to_nat(U32.shln(1, e)), L.pow2(e),
    seed_nat(e, N.lt_of_le_of_lt(e, 16n, 32n, seed_exponent_bound(n), {==}))) :
    N.le(Nat.mul(_, _), Nat.mul(4n, U32.to_nat(n)))
  %Equal.sym(Nat, Nat.mul(L.pow2(e), L.pow2(e)), L.pow2(Nat.add(e, e)), pow2_mul(e, e)) :
    N.le(_, Nat.mul(4n, U32.to_nat(n)))
  N.le_trans(L.pow2(Nat.add(e, e)), L.pow2(Nat.add(2n, U32.log2(n))),
    Nat.mul(4n, U32.to_nat(n)),
    pow2_mono(Nat.add(e, e), Nat.add(2n, U32.log2(n)), seed_half_exponent_upper(U32.log2(n))),
    (
      %pow2_mul(2n, U32.log2(n)) : N.le(_, Nat.mul(4n, U32.to_nat(n)))
      N.mul_le_mul_left(L.pow2(U32.log2(n)), U32.to_nat(n), 4n, log2_lower(n, pos))
    ))

def seed_square_cancel_case(flag: Bool, +a: Nat, +b: Nat,
  h: N.le(Nat.mul(a, a), Nat.mul(b, b)),
  eq: {Nat.is_lt(b, a) == flag : Bool}) -> N.le(a, b):
  match flag:
    case False{}:
      N.le_of_not_lt(b, a, eq)
    case True{}:
      Empty.absurd(N.le(a, b),
        N.internal_false_ne_true(Equal.trans(Bool, False{},
          Nat.is_lt(Nat.mul(b, b), Nat.mul(a, a)), True{},
          Equal.sym(Bool, Nat.is_lt(Nat.mul(b, b), Nat.mul(a, a)), False{},
            N.not_lt_of_le(Nat.mul(a, a), Nat.mul(b, b), h)),
          N.mul_self_lt_mul_self(b, a, eq))))

def seed_square_cancel(+a: Nat, +b: Nat,
  h: N.le(Nat.mul(a, a), Nat.mul(b, b))) -> N.le(a, b):
  seed_square_cancel_case(Nat.is_lt(b, a), a, b, h, {==})

def seed_le_twice_root(+n: U32, +m: Nat,
  pos: N.lt(0n, U32.to_nat(n)), hn: N.le(U32.to_nat(n), Nat.mul(m, m))) ->
  N.le(U32.to_nat(U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))), Nat.mul(2n, m)):
  +r = U32.to_nat(U32.shln(1, 1n+Nat.div(U32.log2(n), 2n)))
  seed_square_cancel(r, Nat.mul(2n, m),
    (
      %Equal.sym(Nat, Nat.mul(Nat.mul(2n, m), Nat.mul(2n, m)),
        Nat.mul(4n, Nat.mul(m, m)), mul_four(2n, m, 2n, m)) : N.le(Nat.mul(r, r), _)
      N.le_trans(Nat.mul(r, r), Nat.mul(4n, U32.to_nat(n)), Nat.mul(4n, Nat.mul(m, m)),
        seed_square_ratio(n, pos), N.mul_le_mul_left(U32.to_nat(n), Nat.mul(m, m), 4n, hn))
    ))

def correction_div_lower(+n: Nat, +r: Nat,
  positive: N.lt(0n, r), square: N.le(Nat.mul(r, r), n)) ->
  N.le(r, Nat.div(n, r)):
  match r:
    case 0n:
      Empty.absurd(N.le(0n, Nat.div(n, 0n)), N.lt_irrefl(0n)(positive))
    case 1n+ +p:
      Equal.trans(Bool,
        Nat.is_le(1n+p, Nat.div(n, 1n+p)),
        Nat.is_le(Nat.mul(1n+p, 1n+p), n), True{},
        N.le_div_iff_mul_le(1n+p, n, p), square)

def correction_div_upper(+n: Nat, +r: Nat,
  positive: N.lt(0n, r), upper: N.lt(n, Nat.mul(r, r))) ->
  N.lt(Nat.div(n, r), r):
  match r:
    case 0n:
      Empty.absurd(N.lt(Nat.div(n, 0n), 0n), N.lt_irrefl(0n)(positive))
    case 1n+ +p:
      N.lt_of_not_le(1n+p, Nat.div(n, 1n+p),
        Equal.trans(Bool,
          Nat.is_le(1n+p, Nat.div(n, 1n+p)),
          Nat.is_le(Nat.mul(1n+p, 1n+p), n), False{},
          N.le_div_iff_mul_le(1n+p, n, p),
          N.not_le_of_lt(n, Nat.mul(1n+p, 1n+p), upper)))

def correction_test_nat(+n: U32, +r: U32,
  positive: N.lt(0n, U32.to_nat(r))) ->
  {U32.is_gt(r, U32.div(n, r)) ==
    Nat.is_lt(Nat.div(U32.to_nat(n), U32.to_nat(r)), U32.to_nat(r)) : Bool}:
  Equal.trans(Bool,
    U32.is_gt(r, U32.div(n, r)),
    Nat.is_lt(U32.to_nat(U32.div(n, r)), U32.to_nat(r)),
    Nat.is_lt(Nat.div(U32.to_nat(n), U32.to_nat(r)), U32.to_nat(r)),
    u32_gt_lt(r, U32.div(n, r)),
    Equal.cong(Nat, Bool, x => Nat.is_lt(x, U32.to_nat(r)),
      U32.to_nat(U32.div(n, r)), Nat.div(U32.to_nat(n), U32.to_nat(r)),
      L.u32_div_nat(n, r, positive)))

def correction_at_root(+n: U32, +r: U32, +t: Nat,
  pos: N.lt(0n, t), square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +eq: {U32.to_nat(r) == t : Nat}) ->
  {U32.to_nat(S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)) == t : Nat}:
  +positive : N.lt(0n, U32.to_nat(r)) =
    Equal.trans(Bool, Nat.is_lt(0n, U32.to_nat(r)), Nat.is_lt(0n, t), True{},
      Equal.cong(Nat, Bool, x => Nat.is_lt(0n, x), U32.to_nat(r), t, eq), pos)
  +square_r : N.le(Nat.mul(U32.to_nat(r), U32.to_nat(r)), U32.to_nat(n)) =
    Equal.trans(Bool,
      Nat.is_le(Nat.mul(U32.to_nat(r), U32.to_nat(r)), U32.to_nat(n)),
      Nat.is_le(Nat.mul(t, t), U32.to_nat(n)), True{},
      Equal.cong(Nat, Bool, +x => Nat.is_le(Nat.mul(x, x), U32.to_nat(n)),
        U32.to_nat(r), t, eq), square)
  +test : {U32.is_gt(r, U32.div(n, r)) == False{} : Bool} =
    Equal.trans(Bool, U32.is_gt(r, U32.div(n, r)),
      Nat.is_lt(Nat.div(U32.to_nat(n), U32.to_nat(r)), U32.to_nat(r)), False{},
      correction_test_nat(n, r, positive),
      N.not_lt_of_le(U32.to_nat(r), Nat.div(U32.to_nat(n), U32.to_nat(r)),
        correction_div_lower(U32.to_nat(n), U32.to_nat(r), positive, square_r)))
  Equal.trans(Nat,
    U32.to_nat(S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)),
    U32.to_nat(S.U32.isqrt.correct(False{}, r)), t,
    Equal.cong(Bool, Nat, flag => U32.to_nat(S.U32.isqrt.correct(flag, r)),
      U32.is_gt(r, U32.div(n, r)), False{}, test), eq)

def correction_above_root(+n: U32, +r: U32, +t: Nat,
  upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  +eq: {U32.to_nat(r) == 1n+t : Nat}) ->
  {U32.to_nat(S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)) == t : Nat}:
  +positive : N.lt(0n, U32.to_nat(r)) =
    Equal.trans(Bool, Nat.is_lt(0n, U32.to_nat(r)), Nat.is_lt(0n, 1n+t), True{},
      Equal.cong(Nat, Bool, x => Nat.is_lt(0n, x), U32.to_nat(r), 1n+t, eq), {==})
  +upper_r : N.lt(U32.to_nat(n), Nat.mul(U32.to_nat(r), U32.to_nat(r))) =
    Equal.trans(Bool,
      Nat.is_lt(U32.to_nat(n), Nat.mul(U32.to_nat(r), U32.to_nat(r))),
      Nat.is_lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)), True{},
      Equal.cong(Nat, Bool, +x => Nat.is_lt(U32.to_nat(n), Nat.mul(x, x)),
        U32.to_nat(r), 1n+t, eq), upper)
  +test : {U32.is_gt(r, U32.div(n, r)) == True{} : Bool} =
    Equal.trans(Bool, U32.is_gt(r, U32.div(n, r)),
      Nat.is_lt(Nat.div(U32.to_nat(n), U32.to_nat(r)), U32.to_nat(r)), True{},
      correction_test_nat(n, r, positive),
      correction_div_upper(U32.to_nat(n), U32.to_nat(r), positive, upper_r))
  Equal.trans(Nat,
    U32.to_nat(S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)),
    U32.to_nat(S.U32.isqrt.correct(True{}, r)), t,
    Equal.cong(Bool, Nat, flag => U32.to_nat(S.U32.isqrt.correct(flag, r)),
      U32.is_gt(r, U32.div(n, r)), True{}, test),
    Equal.trans(Nat, U32.to_nat(U32.sub(r, 1)), Nat.sub(U32.to_nat(r), 1n), t,
      L.u32_sub_nat(r, 1, N.succ_le_of_lt(0n, U32.to_nat(r), positive)),
      Equal.trans(Nat, Nat.sub(U32.to_nat(r), 1n), Nat.sub(1n+t, 1n), t,
        Equal.cong(Nat, Nat, x => Nat.sub(x, 1n), U32.to_nat(r), 1n+t, eq),
        N.sub_zero(t))))

def correction_nat_case(test: Bool, +n: U32, +r: U32, +t: Nat,
  decision: {Nat.is_le(U32.to_nat(r), t) == test : Bool},
  pos: N.lt(0n, t), square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  low: N.le(t, U32.to_nat(r)), high: N.le(U32.to_nat(r), 1n+t)) ->
  {U32.to_nat(S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)) == t : Nat}:
  match test:
    case True{}:
      correction_at_root(n, r, t, pos, square,
        N.le_antisymm(U32.to_nat(r), t, decision, low))
    case False{}:
      correction_above_root(n, r, t, upper,
        N.le_antisymm(U32.to_nat(r), 1n+t, high,
          N.succ_le_of_lt(t, U32.to_nat(r),
            N.lt_of_not_le(U32.to_nat(r), t, decision))))

def correction_nat(+n: U32, +r: U32, +t: Nat,
  pos: N.lt(0n, t), square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  low: N.le(t, U32.to_nat(r)), high: N.le(U32.to_nat(r), 1n+t)) ->
  {U32.to_nat(S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)) == t : Nat}:
  correction_nat_case(Nat.is_le(U32.to_nat(r), t), n, r, t, {==},
    pos, square, upper, low, high)

def NatState(+t: Nat, +k: Nat, +r: Nat, limit: Nat) -> Type:
  N.le(r, limit) & (N.le(t, r) & N.le(Nat.mul(Nat.sub(r, 1n+t), L.pow2(k)), 1n+t))

def u32_sum_fits(+n: U32, +r: U32, +t: Nat, +limit: Nat,
  +pos: N.lt(0n, t), +low: N.le(t, U32.to_nat(r)),
  upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  rootcap: N.le(1n+t, limit), bound: N.le(U32.to_nat(r), limit),
  sumlimit: N.lt(1n+Nat.double(limit), L.pow2(32n))) ->
  N.lt(Nat.add(U32.to_nat(r), U32.to_nat(U32.div(n, r))), L.pow2(32n)):
  %Equal.sym(Nat, U32.to_nat(U32.div(n, r)), Nat.div(U32.to_nat(n), U32.to_nat(r)),
    L.u32_div_nat(n, r, N.lt_of_lt_of_le(0n, t, U32.to_nat(r), pos, low))) :
    N.lt(Nat.add(U32.to_nat(r), _), L.pow2(32n))
  N.lt_of_le_of_lt(Nat.add(U32.to_nat(r), Nat.div(U32.to_nat(n), U32.to_nat(r))),
    1n+Nat.double(limit), L.pow2(32n),
    newton_sum_cap(U32.to_nat(n), U32.to_nat(r), t, limit, pos, low, upper, rootcap, bound), sumlimit)

def state_step(+n: U32, +r: U32, +t: Nat, +k: Nat, +limit: Nat,
  +pos: N.lt(0n, t), square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  +rootcap: N.le(1n+t, limit), sumlimit: N.lt(1n+Nat.double(limit), L.pow2(32n)),
  state: NatState(t, k, U32.to_nat(r), limit)) ->
  NatState(t, 1n+Nat.add(k, k), U32.to_nat(S.U32.isqrt.newton(n, r)), limit):
  (+bound, (+low, scaled)) = state
  +positive = N.lt_of_lt_of_le(0n, t, U32.to_nat(r), pos, low)
  relation = newton_nat(n, r, positive,
    u32_sum_fits(n, r, t, limit, pos, low, upper, rootcap, bound, sumlimit))
  %Equal.sym(Nat, U32.to_nat(S.U32.isqrt.newton(n, r)), next_nat(U32.to_nat(n), U32.to_nat(r)), relation) :
    NatState(t, 1n+Nat.add(k, k), _, limit)
  (
    next_cap(U32.to_nat(n), U32.to_nat(r), t, limit, pos, low, upper, rootcap, bound),
    (
      newton_floor_lower(U32.to_nat(n), U32.to_nat(r), t, positive, square),
      newton_scaled_step(U32.to_nat(n), U32.to_nat(r), t, k, pos, upper, low, scaled)
    )
  )

def first_state(+n: U32, +r: U32, +t: Nat, +limit: Nat,
  +pos: N.lt(0n, t), square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)), +rootcap: N.le(1n+t, limit),
  +bound: N.le(U32.to_nat(r), limit), +hr: N.le(1n+t, U32.to_nat(r)),
  cap2: N.le(U32.to_nat(r), Nat.mul(1n+t, 2n)),
  sumlimit: N.lt(1n+Nat.double(limit), L.pow2(32n))) ->
  NatState(t, 2n, U32.to_nat(S.U32.isqrt.newton(n, r)), limit):
  +low = N.le_trans(t, 1n+t, U32.to_nat(r), N.le_of_lt(t, 1n+t, N.lt_succ_self(t)), hr)
  +positive = N.lt_of_lt_of_le(0n, t, U32.to_nat(r), pos, low)
  relation = newton_nat(n, r, positive,
    u32_sum_fits(n, r, t, limit, pos, low, upper, rootcap, bound, sumlimit))
  %Equal.sym(Nat, U32.to_nat(S.U32.isqrt.newton(n, r)), next_nat(U32.to_nat(n), U32.to_nat(r)), relation) :
    NatState(t, 2n, _, limit)
  (
    next_cap(U32.to_nat(n), U32.to_nat(r), t, limit, pos, low, upper, rootcap, bound),
    (
      newton_floor_lower(U32.to_nat(n), U32.to_nat(r), t, positive, square),
      first_error_contract(Nat.sub(next_nat(U32.to_nat(n), U32.to_nat(r)), 1n+t),
        Nat.sub(U32.to_nat(r), 1n+t), U32.to_nat(r), 1n+t,
        positive, N.add_sub_of_le(1n+t, U32.to_nat(r), hr), initial_error(U32.to_nat(r), 1n+t, cap2),
        newton_error(U32.to_nat(n), U32.to_nat(r), 1n+t,
          N.le_of_lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t), upper), hr))
    )
  )

def sum_limit() -> N.lt(1n+Nat.double(L.pow2(16n)), L.pow2(32n)):
  N.lt_of_le_of_lt(1n+L.pow2(17n), L.pow2(18n), L.pow2(32n),
    N.succ_le_of_lt(L.pow2(17n), L.pow2(18n), pow2_lt_step(17n)),
    N.lt_of_lt_of_le(L.pow2(18n), L.pow2(19n), L.pow2(32n),
      pow2_lt_step(18n), pow2_le_add(13n, 19n)))

def newton_root_cap(+n: U32, +t: Nat, square: N.le(Nat.mul(t, t), U32.to_nat(n))) ->
  N.le(1n+t, L.pow2(16n)):
  N.succ_le_of_lt(t, L.pow2(16n),
    square_strict(t, L.pow2(16n),
      (
        %Equal.sym(Nat, Nat.mul(L.pow2(16n), L.pow2(16n)), L.pow2(32n), square_limit()) :
          N.lt(Nat.mul(t, t), _)
        N.lt_of_le_of_lt(Nat.mul(t, t), U32.to_nat(n), L.pow2(32n), square, L.u32_to_nat_lt(n))
      )))

def seed_state(+n: U32, +t: Nat,
  +npos: N.lt(0n, U32.to_nat(n)), +square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t))) ->
  NatState(t, 2n,
    U32.to_nat(S.U32.isqrt.newton(n, U32.shln(1, 1n+Nat.div(U32.log2(n), 2n)))), L.pow2(16n)):
  +seed = U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))
  first_state(n, seed, t, L.pow2(16n), root_positive(U32.to_nat(n), t, npos, upper),
    square, upper, newton_root_cap(n, t, square), seed_cap(n),
    N.succ_le_of_lt(t, U32.to_nat(seed),
      square_strict(t, U32.to_nat(seed),
        N.lt_of_le_of_lt(Nat.mul(t, t), U32.to_nat(n), Nat.mul(U32.to_nat(seed), U32.to_nat(seed)),
          square, seed_upper(n)))),
    (
      %N.mul_comm(2n, 1n+t) : N.le(U32.to_nat(seed), _)
      seed_le_twice_root(n, 1n+t, npos, N.le_of_lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t), upper))
    ), sum_limit())

def scale_index(+k: Nat) -> Nat:
  1n+Nat.add(k, k)

# An input-indexed constant prevents eager Nat expansion (bendlang/bend#1071).
def opaque_two(n: U32) -> Nat:
  match n:
    case U32{w}:
      2n

def opaque_two_eq(n: U32) -> {opaque_two(n) == 2n : Nat}:
  match n:
    case U32{w}:
      {==}

def state_three(+n: U32, +r: U32, +t: Nat, +k: Nat, +limit: Nat,
  +pos: N.lt(0n, t), +square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  +rootcap: N.le(1n+t, limit), +sumlimit: N.lt(1n+Nat.double(limit), L.pow2(32n)),
  state: NatState(t, k, U32.to_nat(r), limit)) ->
  NatState(t, scale_index(scale_index(scale_index(k))),
    U32.to_nat(S.U32.isqrt.newton(n, S.U32.isqrt.newton(n, S.U32.isqrt.newton(n, r)))), limit):
  +r1 = S.U32.isqrt.newton(n, r)
  +r2 = S.U32.isqrt.newton(n, r1)
  s1 = state_step(n, r, t, k, limit, pos, square, upper, rootcap, sumlimit, state)
  s2 = state_step(n, r1, t, scale_index(k), limit, pos, square, upper, rootcap, sumlimit, s1)
  state_step(n, r2, t, scale_index(scale_index(k)), limit, pos, square, upper, rootcap, sumlimit, s2)

def opaque_seed_state(+n: U32, +t: Nat,
  npos: N.lt(0n, U32.to_nat(n)), square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t))) ->
  NatState(t, opaque_two(n),
    U32.to_nat(S.U32.isqrt.newton(n, U32.shln(1, 1n+Nat.div(U32.log2(n), 2n)))), L.pow2(16n)):
  %Equal.sym(Nat, opaque_two(n), 2n, opaque_two_eq(n)) :
    NatState(t, _, U32.to_nat(S.U32.isqrt.newton(n, U32.shln(1, 1n+Nat.div(U32.log2(n), 2n)))), L.pow2(16n))
  seed_state(n, t, npos, square, upper)

def four_state(+n: U32, +t: Nat,
  +npos: N.lt(0n, U32.to_nat(n)), +square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t))) ->
  NatState(t, scale_index(scale_index(scale_index(opaque_two(n)))),
    U32.to_nat(S.U32.isqrt.newton(n, S.U32.isqrt.newton(n, S.U32.isqrt.newton(n,
      S.U32.isqrt.newton(n, U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))))))), L.pow2(16n)):
  state_three(n, S.U32.isqrt.newton(n, U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))),
    t, opaque_two(n), L.pow2(16n), root_positive(U32.to_nat(n), t, npos, upper),
    square, upper, newton_root_cap(n, t, square), sum_limit(), opaque_seed_state(n, t, npos, square, upper))

def final_exponent(n: U32) -> Nat:
  scale_index(scale_index(scale_index(opaque_two(n))))

def final_exponent_bound(+n: U32) -> N.le(17n, final_exponent(n)):
  %Equal.sym(Nat, final_exponent(n), 23n,
    Equal.cong(Nat, Nat, k => scale_index(scale_index(scale_index(k))),
      opaque_two(n), 2n, opaque_two_eq(n))) : N.le(17n, _)
  {==}

def final_scale_cap(+n: U32, +t: Nat, square: N.le(Nat.mul(t, t), U32.to_nat(n))) ->
  N.lt(1n+t, L.pow2(final_exponent(n))):
  N.lt_of_le_of_lt(1n+t, L.pow2(16n), L.pow2(final_exponent(n)), newton_root_cap(n, t, square),
    N.lt_of_lt_of_le(L.pow2(16n), L.pow2(17n), L.pow2(final_exponent(n)),
      pow2_lt_step(16n), pow2_mono(17n, final_exponent(n), final_exponent_bound(n))))

def result_from_state(+n: U32, +r: U32, +t: Nat,
  +npos: N.lt(0n, U32.to_nat(n)), +square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  state: NatState(t, final_exponent(n), U32.to_nat(r), L.pow2(16n))) ->
  {U32.to_nat(S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)) == t : Nat}:
  (bound, (low, scaled)) = state
  high = zero_error_le(U32.to_nat(r), 1n+t,
    scaled_zero(Nat.sub(U32.to_nat(r), 1n+t), L.pow2(final_exponent(n)), 1n+t,
      final_scale_cap(n, t, square), scaled))
  correction_nat(n, r, t, root_positive(U32.to_nat(n), t, npos, upper), square, upper, low, high)

def four_raw(+n: U32) -> U32:
  r = U32.shln(1, 1n+Nat.div(U32.log2(n), 2n))
  r = S.U32.isqrt.newton(n, r)
  r = S.U32.isqrt.newton(n, r)
  r = S.U32.isqrt.newton(n, r)
  S.U32.isqrt.newton(n, r)

def finish_raw(+n: U32, +r: U32) -> U32:
  S.U32.isqrt.correct(U32.is_gt(r, U32.div(n, r)), r)

def newton_candidate_word(+n: U32) -> {S.U32.isqrt.candidate(n) == finish_raw(n, four_raw(n)) : U32}:
  {==}

def candidate_result(+n: U32, +r: U32, +t: Nat, +candidate: U32,
  word: {candidate == finish_raw(n, r) : U32},
  +npos: N.lt(0n, U32.to_nat(n)), +square: N.le(Nat.mul(t, t), U32.to_nat(n)),
  +upper: N.lt(U32.to_nat(n), Nat.mul(1n+t, 1n+t)),
  state: NatState(t, final_exponent(n), U32.to_nat(r), L.pow2(16n))) ->
  {U32.to_nat(candidate) == t : Nat}:
  Equal.trans(Nat, U32.to_nat(candidate), U32.to_nat(finish_raw(n, r)), t,
    Equal.cong(U32, Nat, U32.to_nat, candidate, finish_raw(n, r), word),
    result_from_state(n, r, t, npos, square, upper, state))

def Laws.isqrt_bounds(n):
  root_certify(n, S.U32.isqrt.candidate(n))
