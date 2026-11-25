import Base
import ./LAWS.bend as Laws
import ./pure.bend as Jwt
import ../lemmas/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat

def and_lt_sub(+a: Nat, +b: Nat, +c: Nat) -> {Bool.and(Nat.is_lt(a, c), Nat.is_lt(b, Nat.sub(c, a))) == Nat.is_lt(Nat.add(a, b), c) : Bool}:
  match a b c:
    case 0n 0n 0n:
      {==}
    case 0n 1n+p 0n:
      {==}
    case 0n +b 1n+q:
      {==}
    case 1n+p +b 0n:
      {==}
    case 1n+p +b 1n+q:
      and_lt_sub(p, b, q)

def and_lt_wrap(c: Bool, +now: Nat, +t: Nat, +lw: Nat, -s: Nat,
  +hc: {Nat.is_lt(now, t) == c : Bool},
  hs: MNat.le(now, t) -> {s == Nat.sub(t, now) : Nat}
) -> {Bool.and(c, Nat.is_lt(lw, s)) == Nat.is_lt(Nat.add(now, lw), t) : Bool}:
  match c:
    case True{}:
      %Equal.sym(Nat, s, Nat.sub(t, now), hs(MNat.le_of_lt(now, t, hc))) :
        {Bool.and(True{}, Nat.is_lt(lw, _)) == Nat.is_lt(Nat.add(now, lw), t) : Bool}
      %hc : {Bool.and(_, Nat.is_lt(lw, Nat.sub(t, now))) == Nat.is_lt(Nat.add(now, lw), t) : Bool}
      and_lt_sub(now, lw, t)
    case False{}:
      %and_lt_sub(now, lw, t) : {Bool.and(False{}, Nat.is_lt(lw, s)) == _ : Bool}
      %Equal.sym(Bool, Nat.is_lt(now, t), False{}, hc) :
        {Bool.and(False{}, Nat.is_lt(lw, s)) == Bool.and(_, Nat.is_lt(lw, Nat.sub(t, now))) : Bool}
      {==}

def Laws.late_time(now, t, lw):
  %MNat.add_comm(U32.to_nat(lw), U32.to_nat(t)) :
    {Jwt.late(now, lw, Some{t}) == Nat.is_le(_, U32.to_nat(now)) : Bool}
  Lemmas.u32_fits_nat(now, lw, t)

def Laws.early_time(now, t, lw):
  %Equal.sym(Bool, U32.is_lt(now, t), Nat.is_lt(U32.to_nat(now), U32.to_nat(t)), Lemmas.u32_is_lt_nat(now, t)) :
    {Bool.and(_, U32.is_lt(lw, U32.sub(t, now))) == Nat.is_lt(Nat.add(U32.to_nat(now), U32.to_nat(lw)), U32.to_nat(t)) : Bool}
  %Equal.sym(Bool, U32.is_lt(lw, U32.sub(t, now)), Nat.is_lt(U32.to_nat(lw), U32.to_nat(U32.sub(t, now))), Lemmas.u32_is_lt_nat(lw, U32.sub(t, now))) :
    {Bool.and(Nat.is_lt(U32.to_nat(now), U32.to_nat(t)), _) == Nat.is_lt(Nat.add(U32.to_nat(now), U32.to_nat(lw)), U32.to_nat(t)) : Bool}
  and_lt_wrap(Nat.is_lt(U32.to_nat(now), U32.to_nat(t)), U32.to_nat(now), U32.to_nat(t), U32.to_nat(lw), U32.to_nat(U32.sub(t, now)), {==}, h => Lemmas.u32_sub_nat(t, now, h))

def Laws.late_exact(t):
  %Equal.sym(Bool, Jwt.late(t, 0, Some{t}), Nat.is_le(Nat.add(U32.to_nat(t), 0n), U32.to_nat(t)), Laws.late_time(t, t, 0)) :
    {_ == True{} : Bool}
  %Equal.sym(Nat, Nat.add(U32.to_nat(t), 0n), U32.to_nat(t), MNat.add_zero(U32.to_nat(t))) :
    {Nat.is_le(_, U32.to_nat(t)) == True{} : Bool}
  MNat.le_refl(U32.to_nat(t))

def Laws.early_exact(t, lw):
  %Equal.sym(Bool, U32.is_lt(t, t), Nat.is_lt(U32.to_nat(t), U32.to_nat(t)), Lemmas.u32_is_lt_nat(t, t)) :
    {Bool.and(_, U32.is_lt(lw, U32.sub(t, t))) == False{} : Bool}
  %Equal.sym(Bool, Nat.is_lt(U32.to_nat(t), U32.to_nat(t)), False{}, MNat.not_lt_of_le(U32.to_nat(t), U32.to_nat(t), MNat.le_refl(U32.to_nat(t)))) :
    {Bool.and(_, U32.is_lt(lw, U32.sub(t, t))) == False{} : Bool}
  {==}

def Laws.late_leeway_at(now, t, lw, h):
  %Equal.sym(Bool, Jwt.late(now, lw, Some{t}), Nat.is_le(Nat.add(U32.to_nat(t), U32.to_nat(lw)), U32.to_nat(now)), Laws.late_time(now, t, lw)) :
    {_ == True{} : Bool}
  %Equal.sym(Nat, Nat.add(U32.to_nat(t), U32.to_nat(lw)), U32.to_nat(now), h) :
    {Nat.is_le(_, U32.to_nat(now)) == True{} : Bool}
  MNat.le_refl(U32.to_nat(now))

def Laws.early_leeway_at(now, t, lw, h):
  %Equal.sym(Bool, Jwt.early(now, lw, Some{t}), Nat.is_lt(Nat.add(U32.to_nat(now), U32.to_nat(lw)), U32.to_nat(t)), Laws.early_time(now, t, lw)) :
    {_ == False{} : Bool}
  %Equal.sym(Nat, Nat.add(U32.to_nat(now), U32.to_nat(lw)), U32.to_nat(t), h) :
    {Nat.is_lt(_, U32.to_nat(t)) == False{} : Bool}
  MNat.not_lt_of_le(U32.to_nat(t), U32.to_nat(t), MNat.le_refl(U32.to_nat(t)))

def Laws.late_leeway_sides(now, t, lw, side, h):
  Equal.trans(Bool, Jwt.late(now, lw, Some{t}), Nat.is_le(Nat.add(U32.to_nat(t), U32.to_nat(lw)), U32.to_nat(now)), side, Laws.late_time(now, t, lw), h)

def Laws.early_leeway_sides(now, t, lw, side, h):
  Equal.trans(Bool, Jwt.early(now, lw, Some{t}), Nat.is_lt(Nat.add(U32.to_nat(now), U32.to_nat(lw)), U32.to_nat(t)), side, Laws.early_time(now, t, lw), h)

def Laws.late_absent(now, lw):
  {==}

def Laws.early_absent(now, lw):
  {==}

def Laws.b64u_rfc_header():
  {==}

def Laws.b64u_rfc_signature():
  {==}

def Laws.b64u_url_alphabet():
  {==}

def Laws.b64u_unpadded():
  {==}

def Laws.b64u_rejects_padding():
  {==}

def Laws.b64u_rejects_std_alphabet():
  {==}

def Laws.b64u_rejects_pad_bits():
  {==}

def Laws.b64u_rejects_one_char_group():
  {==}

def Laws.secs_whole():
  {==}

def Laws.secs_fraction_up():
  {==}

def Laws.secs_zero_fraction():
  {==}

def Laws.secs_cap():
  {==}

def Laws.secs_negative():
  {==}

def Laws.secs_exponent():
  {==}

def Laws.rfc_before_exp():
  {==}

def Laws.rfc_at_exp():
  {==}

def Laws.rfc_leeway():
  {==}

def Laws.rfc_past_leeway():
  {==}

def Laws.rfc_iss():
  {==}

def Laws.rfc_wrong_iss():
  {==}

def Laws.rfc_missing_aud():
  {==}

def Laws.rfc_alg_mismatch():
  {==}

def Laws.alg_none():
  {==}

def Laws.alg_missing():
  {==}

def Laws.header_dup():
  {==}

def Laws.header_crit():
  {==}

def Laws.header_b64():
  {==}

def Laws.aud_in_array():
  {==}

def Laws.aud_wrong():
  {==}

def Laws.aud_unwanted():
  {==}

def Laws.aud_string():
  {==}

def Laws.nbf_early():
  {==}

def Laws.nbf_reached():
  {==}

def Laws.nbf_leeway():
  {==}

def Laws.iat_future():
  {==}

def Laws.exp_fraction_valid():
  {==}

def Laws.exp_fraction_expired():
  {==}

def Laws.exp_string():
  {==}

def Laws.exp_exponent():
  {==}

def Laws.claims_not_object():
  {==}

def Laws.two_segments():
  {==}

def Laws.padded_segment():
  {==}

def Laws.jwks_rsa_sig_key():
  {==}

def Laws.jwks_ec_p256():
  {==}

def Laws.jwks_kty_mismatch():
  {==}

def Laws.jwks_no_oct():
  {==}

def Laws.jwks_unknown_kid():
  {==}
