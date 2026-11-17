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

def max_comm(+a: U32, +b: U32) -> {U32.max(a, b) == U32.max(b, a) : U32}:
  U.u32_to_nat_inj(U32.max(a, b), U32.max(b, a),
    Equal.trans(Nat, U32.to_nat(U32.max(a, b)), Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(U32.max(b, a)),
      U.u32_max_to_nat(a, b),
      Equal.trans(Nat, Nat.max(U32.to_nat(a), U32.to_nat(b)), Nat.max(U32.to_nat(b), U32.to_nat(a)), U32.to_nat(U32.max(b, a)),
        N.max_comm(U32.to_nat(a), U32.to_nat(b)),
        Equal.sym(Nat, U32.to_nat(U32.max(b, a)), Nat.max(U32.to_nat(b), U32.to_nat(a)), U.u32_max_to_nat(b, a)))))

def Laws.gcd_symmetric(a, b):
  %Equal.sym(U32, U32.min(a, b), U32.min(b, a), min_comm(a, b)) :
    {S.U32.gcd.go(65n, U32.is_zero(_), U32.max(a, b), _) == S.U32.gcd(b, a) : U32}
  %Equal.sym(U32, U32.max(a, b), U32.max(b, a), max_comm(a, b)) :
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

def square_limit() -> {Nat.mul(L.pow2(16n), L.pow2(16n)) == L.pow2(32n) : Nat}:
  Equal.trans(Nat, Nat.mul(L.pow2(16n), L.pow2(16n)), L.pow2(Nat.add(16n, 16n)), L.pow2(32n),
    pow2_mul(16n, 16n), Equal.cong(Nat, Nat, L.pow2, Nat.add(16n, 16n), 32n, {==}))

def Upper(+n: Nat, +r: Nat) -> Data:
  N.lt(n, Nat.mul(1n+r, 1n+r))

def sqrt_math_le_transport(+a: Nat, +b: Nat, +c: Nat, +d: Nat,
  e: {a == c : Nat}, f: {b == d : Nat}, h: N.le(a, b)) -> N.le(c, d):
  %e : N.le(_, d)
  %f : N.le(a, _)
  h

def sqrt_math_sum_succ(+a: Nat, +b: Nat) ->
  {Nat.add(1n+a, 1n+b) == 2n+Nat.add(a, b) : Nat}:
  Equal.cong(Nat, Nat, x => 1n+x, Nat.add(a, 1n+b), 1n+Nat.add(a, b), N.add_succ(a, b))

def sqrt_math_product_succ(+a: Nat, +b: Nat) ->
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
def sqrt_math_amgm(+s: Nat, +a: Nat, +b: Nat,
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
                sqrt_math_le_transport(Nat.add(1n+p, 1n+q), Nat.add(1n+t, 1n+t),
                  2n+Nat.add(p, q), 2n+Nat.add(t, t),
                  sqrt_math_sum_succ(p, q), sqrt_math_sum_succ(t, t), h)
              %Equal.sym(Nat, Nat.mul(1n+p, 1n+q), 1n+Nat.add(Nat.add(p, q), Nat.mul(p, q)),
                sqrt_math_product_succ(p, q)) : N.le(_, Nat.mul(1n+t, 1n+t))
              %Equal.sym(Nat, Nat.mul(1n+t, 1n+t), 1n+Nat.add(Nat.add(t, t), Nat.mul(t, t)),
                sqrt_math_product_succ(t, t)) :
                N.le(1n+Nat.add(Nat.add(p, q), Nat.mul(p, q)), _)
              N.add_le_add(Nat.add(p, q), Nat.mul(p, q), Nat.add(t, t), Nat.mul(t, t),
                hs, sqrt_math_amgm(t, p, q, hs))

def sqrt_math_quotient_strict(+n: Nat, +p: Nat) ->
  N.lt(n, Nat.mul(1n+p, 1n+Nat.div(n, 1n+p))):
  +q = Nat.div(n, 1n+p)
  %N.mul_comm(1n+q, 1n+p) : N.lt(n, _)
  N.lt_of_not_le(Nat.mul(1n+q, 1n+p), n,
    Equal.trans(Bool, Nat.is_le(Nat.mul(1n+q, 1n+p), n), Nat.is_le(1n+q, q), False{},
      Equal.sym(Bool, Nat.is_le(1n+q, q), Nat.is_le(Nat.mul(1n+q, 1n+p), n),
        N.le_div_iff_mul_le(1n+q, n, p)),
      N.not_le_of_lt(q, 1n+q, N.lt_succ_self(q))))

def sqrt_math_mul_two(+s: Nat) -> {Nat.mul(s, 2n) == Nat.add(s, s) : Nat}:
  %N.mul_comm(2n, s) : {_ == Nat.add(s, s) : Nat}
  %Equal.sym(Nat, Nat.add(s, 0n), s, N.add_zero(s)) :
    {Nat.add(s, _) == Nat.add(s, s) : Nat}
  {==}

def sqrt_math_half_sum(+a: Nat, +b: Nat) ->
  N.le(Nat.add(a, 1n+b),
    Nat.add(1n+Nat.div(Nat.add(a, b), 2n), 1n+Nat.div(Nat.add(a, b), 2n))):
  +m = Nat.add(a, b)
  +s = {1n+Nat.div(m, 2n) : Nat}
  sqrt_math_le_transport(1n+m, Nat.mul(s, 2n), Nat.add(a, 1n+b), Nat.add(s, s),
    Equal.sym(Nat, Nat.add(a, 1n+b), 1n+m, N.add_succ(a, b)), sqrt_math_mul_two(s),
    N.succ_le_of_lt(m, Nat.mul(s, 2n),
      (
        %N.mul_comm(2n, s) : N.lt(m, _)
        sqrt_math_quotient_strict(m, 1n)
      )))

def sqrt_next_positive(+n: Nat, +p: Nat) -> Upper(n, S.U32.isqrt.next(n, 1n+p)):
  +q = Nat.div(n, 1n+p)
  +s = {1n+S.U32.isqrt.next(n, 1n+p) : Nat}
  N.lt_of_lt_of_le(n, Nat.mul(1n+p, 1n+q), Nat.mul(s, s),
    sqrt_math_quotient_strict(n, p),
    sqrt_math_amgm(s, 1n+p, 1n+q, sqrt_math_half_sum(1n+p, q)))

def sqrt_next_upper(+n: Nat, +r: Nat, h: Upper(n, r)) -> Upper(n, S.U32.isqrt.next(n, r)):
  match r:
    case 0n:
      h
    case 1n+p:
      sqrt_next_positive(n, p)

def sqrt_refine_upper(k: Nat, +n: Nat, +r: Nat, h: Upper(n, r)) ->
  Upper(n, S.U32.isqrt.refine(k, n, r)):
  match k:
    case 0n:
      h
    case 1n+p:
      sqrt_refine_upper(p, n, S.U32.isqrt.next(n, r), sqrt_next_upper(n, r, h))

def sqrt_correct_lift(+n: Nat, +q: Nat, +result: Nat,
  facts: Laws.SqrtBounds(n, result) & N.le(result, q)) ->
  Laws.SqrtBounds(n, result) & N.le(result, 1n+q):
  (bounds, decreased) = facts
  (bounds, N.le_trans(result, q, 1n+q, decreased, N.le_succ(q)))

def sqrt_correct_zero(high: Bool, n: Nat, +r: Nat) ->
  {S.U32.isqrt.correct_nat(0n, high, n, r) == 0n : Nat}:
  match r:
    case 0n:
      {==}
    case 1n+p:
      {==}

def sqrt_correct_false(+p: Nat, +n: Nat, +r: Nat) ->
  {S.U32.isqrt.correct_nat(1n+p, False{}, n, r) == r : Nat}:
  match r:
    case 0n:
      {==}
    case 1n+q:
      {==}

def sqrt_correct(+k: Nat, high: Bool, +n: Nat, +r: Nat,
  e: {high == Nat.is_lt(n, Nat.mul(r, r)) : Bool},
  upper: Upper(n, r), budget: N.le(r, k)) ->
  Laws.SqrtBounds(n, S.U32.isqrt.correct_nat(k, high, n, r)) &
    N.le(S.U32.isqrt.correct_nat(k, high, n, r), r):
  match k:
    case 0n:
      %Equal.sym(Nat, S.U32.isqrt.correct_nat(0n, high, n, r), 0n, sqrt_correct_zero(high, n, r)) :
        Laws.SqrtBounds(n, _) & N.le(_, r)
      (
        (
          N.zero_le(n),
          (
            %N.le_zero_eq(r, budget) : Upper(n, _)
            upper
          )
        ),
        N.zero_le(r)
      )
    case 1n+p:
      match high:
        case False{}:
          %Equal.sym(Nat, S.U32.isqrt.correct_nat(1n+p, False{}, n, r), r, sqrt_correct_false(p, n, r)) :
            Laws.SqrtBounds(n, _) & N.le(_, r)
          (
            (
              N.le_of_not_lt(n, Nat.mul(r, r),
                Equal.sym(Bool, False{}, Nat.is_lt(n, Nat.mul(r, r)), e)),
              upper
            ),
            N.le_refl(r)
          )
        case True{}:
          match r:
            case 0n:
              Empty.absurd(
                Laws.SqrtBounds(n, 0n) & N.le(0n, 0n),
                N.lt_zero(n)(Equal.sym(Bool, True{}, Nat.is_lt(n, 0n), e)))
            case 1n+q:
              sqrt_correct_lift(n, q, S.U32.isqrt.correct_nat(p, Nat.is_lt(n, Nat.mul(q, q)), n, q),
                sqrt_correct(p, Nat.is_lt(n, Nat.mul(q, q)), n, q, {==},
                  Equal.sym(Bool, True{}, Nat.is_lt(n, Nat.mul(1n+q, 1n+q)), e),
                  N.le_of_succ_le_succ(q, p, budget)))

def sqrt_start(+n: Nat, +limit: Nat,
  square: {Nat.mul(limit, limit) == L.pow2(32n) : Nat}, h: N.lt(n, L.pow2(32n))) -> Upper(n, limit):
  N.lt_trans(n, Nat.mul(limit, limit), Nat.mul(1n+limit, 1n+limit),
    (
      %Equal.sym(Nat, Nat.mul(limit, limit), L.pow2(32n), square) : N.lt(n, _)
      h
    ), N.mul_lt_mul_of_lt_of_lt(limit, limit, 1n+limit, 1n+limit,
      N.lt_succ_self(limit), N.lt_succ_self(limit)))

def sqrt_limit_square(+limit: Nat, e: {limit == L.pow2(16n) : Nat}) ->
  {Nat.mul(limit, limit) == L.pow2(32n) : Nat}:
  Equal.trans(Nat, Nat.mul(limit, limit), Nat.mul(L.pow2(16n), L.pow2(16n)), L.pow2(32n),
    Equal.cong(Nat, Nat, x => Nat.mul(x, x), limit, L.pow2(16n), e), square_limit())

def sqrt_limit_fits(+limit: Nat, e: {limit == L.pow2(16n) : Nat}) -> N.lt(limit, L.pow2(32n)):
  L.lt_rw(limit, L.pow2(16n), L.pow2(32n), e,
    N.lt_of_lt_of_le(L.pow2(16n), L.pow2(17n), L.pow2(32n),
      pow2_lt_step(16n), pow2_le_add(15n, 17n)))

def sqrt_word_le(+a: U32, +b: U32, h: {U32.is_le(a, b) == True{} : Bool}) -> N.le(U32.to_nat(a), U32.to_nat(b)):
  Equal.trans(Bool, Nat.is_le(U32.to_nat(a), U32.to_nat(b)), U32.is_le(a, b), True{},
    Equal.sym(Bool, U32.is_le(a, b), Nat.is_le(U32.to_nat(a), U32.to_nat(b)), L.u32_is_le_nat(a, b)), h)

def sqrt_min_case(left: Bool, +n: Nat, +limit: Nat, +r: Nat,
  e: {Nat.is_le(limit, r) == left : Bool}, hl: Upper(n, limit), hr: Upper(n, r)) ->
  Upper(n, Nat.min(limit, r)):
  match left:
    case True{}:
      %Equal.sym(Nat, Nat.min(limit, r), limit, N.min_eq_left(limit, r, e)) : Upper(n, _)
      hl
    case False{}:
      %Equal.sym(Nat, Nat.min(limit, r), r,
        N.min_eq_right(limit, r, N.le_of_lt(r, limit, N.lt_of_not_le(limit, r, e)))) : Upper(n, _)
      hr

def sqrt_estimate(+limit: Nat, +n: Nat, +seed: Nat, hl: Upper(n, limit)) ->
  Upper(n, S.U32.isqrt.estimate(limit, n, seed)) & N.le(S.U32.isqrt.estimate(limit, n, seed), limit):
  +r = S.U32.isqrt.refine(3n, n, S.U32.isqrt.next(n, 1n+seed))
  (sqrt_min_case(Nat.is_le(r, limit), n, r, limit, {==},
    sqrt_refine_upper(3n, n, S.U32.isqrt.next(n, 1n+seed), sqrt_next_positive(n, seed)), hl),
    N.min_le_right(r, limit))

def sqrt_encode(+n: Nat, +r: Nat, +limit: Nat, bounds: Laws.SqrtBounds(n, r),
  cap: N.le(r, limit), fit: N.lt(limit, L.pow2(32n))) -> Laws.SqrtBounds(n, U32.to_nat(U32.from_nat(r))):
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(r)), r,
    L.u32_to_from_nat(r, N.lt_of_le_of_lt(r, limit, L.pow2(32n), cap, fit))) : Laws.SqrtBounds(n, _)
  bounds

def sqrt_finish(+n: Nat, +r: Nat, +limit: Nat, +result: Nat,
  facts: Laws.SqrtBounds(n, result) & N.le(result, r), cap: N.le(r, limit), fit: N.lt(limit, L.pow2(32n))) ->
  Laws.SqrtBounds(n, U32.to_nat(U32.from_nat(result))):
  (bounds, decreased) = facts
  sqrt_encode(n, result, limit, bounds, N.le_trans(result, r, limit, decreased, cap), fit)

def sqrt_from_estimate(+n: Nat, +r: Nat, +limit: Nat, +fuel: Nat,
  upper: Upper(n, r), +cap: N.le(r, limit), fit: N.lt(limit, L.pow2(32n)), budget: N.le(limit, fuel)) ->
  Laws.SqrtBounds(n, U32.to_nat(U32.from_nat(S.U32.isqrt.correct_nat(fuel, Nat.is_lt(n, Nat.mul(r, r)), n, r)))):
  sqrt_finish(n, r, limit, S.U32.isqrt.correct_nat(fuel, Nat.is_lt(n, Nat.mul(r, r)), n, r),
    sqrt_correct(fuel, Nat.is_lt(n, Nat.mul(r, r)), n, r, {==}, upper,
      N.le_trans(r, limit, fuel, cap, budget)), cap, fit)

def sqrt_estimate_lift(+n: Nat, +seed: Nat, +limit: Nat, +fuel: Nat,
  facts: Upper(n, S.U32.isqrt.estimate(limit, n, seed)) & N.le(S.U32.isqrt.estimate(limit, n, seed), limit),
  fit: N.lt(limit, L.pow2(32n)), budget: N.le(limit, fuel)) ->
  Laws.SqrtBounds(n, U32.to_nat(U32.from_nat(S.U32.isqrt.correct_nat(fuel,
    Nat.is_lt(n, Nat.mul(S.U32.isqrt.estimate(limit, n, seed), S.U32.isqrt.estimate(limit, n, seed))),
    n, S.U32.isqrt.estimate(limit, n, seed))))):
  (upper, cap) = facts
  sqrt_from_estimate(n, S.U32.isqrt.estimate(limit, n, seed), limit, fuel, upper, cap, fit, budget)

def sqrt_result(+n: Nat, +seed: Nat, +limit: Nat, +fuel: Nat,
  start: Upper(n, limit), fit: N.lt(limit, L.pow2(32n)), budget: N.le(limit, fuel)) ->
  Laws.SqrtBounds(n, U32.to_nat(U32.from_nat(S.U32.isqrt.correct_nat(fuel,
    Nat.is_lt(n, Nat.mul(S.U32.isqrt.estimate(limit, n, seed), S.U32.isqrt.estimate(limit, n, seed))),
    n, S.U32.isqrt.estimate(limit, n, seed))))):
  sqrt_estimate_lift(n, seed, limit, fuel, sqrt_estimate(limit, n, seed, start), fit, budget)

def sqrt_of_bounds(+limit: U32, +fuel: U32, +n: U32, +seed: U32,
  +e: {U32.to_nat(limit) == L.pow2(16n) : Nat}, budget: {U32.is_le(limit, fuel) == True{} : Bool}) ->
  Laws.SqrtBounds(U32.to_nat(n),
    U32.to_nat(S.U32.isqrt.of(U32.to_nat(limit), U32.to_nat(fuel), U32.to_nat(n), U32.to_nat(seed)))):
  sqrt_result(U32.to_nat(n), U32.to_nat(seed), U32.to_nat(limit), U32.to_nat(fuel),
    sqrt_start(U32.to_nat(n), U32.to_nat(limit), sqrt_limit_square(U32.to_nat(limit), e), L.u32_to_nat_lt(n)),
    sqrt_limit_fits(U32.to_nat(limit), e), sqrt_word_le(limit, fuel, budget))

def Laws.isqrt_bounds(n):
  sqrt_of_bounds(65536, 65537, n, (1 << Nat.add(1n, Nat.div(U32.log2(n), 2n)) : U32), initial_step(), {==})
