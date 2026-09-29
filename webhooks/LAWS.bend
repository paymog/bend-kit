import Base
import ./webhooks.bend as W
import bend-kit-time@0.1.0.0/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

# Pure framing and freshness only. HMAC and the constant-time compare are foreign code; check.bend runs them.

def at(+s: U32) -> Time.Instant:
  Time.Instant.of_unix(Time.i64(s))

def hs() -> Map<&2, List<&2, String>>:
  Map.new(&2, List<&2, String>)

def one(+k: String, +v: String) -> Map<&2, List<&2, String>>:
  W.put(hs(), k, v)

# The Standard Webhooks reference delivery's headers.
def std.h(+ts: String) -> Map<&2, List<&2, String>>:
  W.put(W.put(one("webhook-id", "msg_p5jXN8AQM9LWM0D4loKWxJek"), "webhook-timestamp", ts), "webhook-signature",
    "v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=")

# ---- timestamps: unix seconds, 1 to 18 ASCII digits

law ts_read:
  {W.ts.read("1614265330") == Done{Time.i64(1614265330)} : Result<&1, &1, W.Err, Int.I64>}

law ts_read_zero:
  {W.ts.read("0") == Done{Time.i64(0)} : Result<&1, &1, W.Err, Int.I64>}

law ts_read_empty:
  {W.ts.read("") == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Int.I64>}

law ts_read_sign:
  {W.ts.read("-1") == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Int.I64>}

law ts_read_plus:
  {W.ts.read("+1") == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Int.I64>}

law ts_read_letter:
  {W.ts.read("16142653x0") == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Int.I64>}

law ts_read_space:
  {W.ts.read(" 1614265330") == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Int.I64>}

# 19 digits could overflow an I64, so they are refused.
law ts_read_19_digits:
  {W.ts.read("1000000000000000000") == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Int.I64>}

# ---- freshness: within tol seconds of now, either way, bounds included

law window_equal:
  {W.window(300, at(1614265330), Time.i64(1614265330)) == Done{Unit{}} : Result<&1, &1, W.Err, Unit>}

law window_old_edge:
  {W.window(300, at(1614265630), Time.i64(1614265330)) == Done{Unit{}} : Result<&1, &1, W.Err, Unit>}

law window_too_old:
  {W.window(300, at(1614265631), Time.i64(1614265330)) == Fail{W.TooOld{}} : Result<&1, &1, W.Err, Unit>}

law window_new_edge:
  {W.window(300, at(1614265030), Time.i64(1614265330)) == Done{Unit{}} : Result<&1, &1, W.Err, Unit>}

law window_too_new:
  {W.window(300, at(1614265029), Time.i64(1614265330)) == Fail{W.TooNew{}} : Result<&1, &1, W.Err, Unit>}

law window_zero_tol:
  {W.window(0, at(1614265331), Time.i64(1614265330)) == Fail{W.TooOld{}} : Result<&1, &1, W.Err, Unit>}

# ---- ids: not empty, no '.', so id.timestamp.body frames one way

law id_ok:
  {W.id.check("msg_p5jXN8AQM9LWM0D4loKWxJek") == Done{Unit{}} : Result<&1, &1, W.Err, Unit>}

law id_empty:
  {W.id.check("") == Fail{W.BadId{}} : Result<&1, &1, W.Err, Unit>}

law id_dot:
  {W.id.check("msg.1") == Fail{W.BadId{}} : Result<&1, &1, W.Err, Unit>}

# ---- Standard Webhooks framing

# Only v1 entries are candidates; other versions are skipped, order kept.
law std_sigs:
  {W.std.sigs(["v1,a", "v2,b", "v1a", "v1,c"]) == ["a", "c"] : List<&2, String>}

# The reference delivery signs "id.timestamp." then the body.
law std_frame_reference:
  {W.std.check(300, at(1614265330), std.h("1614265330"))
    == Done{("msg_p5jXN8AQM9LWM0D4loKWxJek", "msg_p5jXN8AQM9LWM0D4loKWxJek.1614265330.", ["g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE="])}
    : Result<&1, &1, W.Err, String & String & List<&2, String>>}

# A rotated sender sends several space-separated signatures.
law std_frame_rotated:
  {W.std.check(300, at(1614265330), W.put(W.put(one("webhook-id", "m"), "webhook-timestamp", "1614265330"), "webhook-signature", "v1,aa v2,bb v1,cc"))
    == Done{("m", "m.1614265330.", ["aa", "cc"])} : Result<&1, &1, W.Err, String & String & List<&2, String>>}

law std_missing_id:
  {W.std.check(300, at(1614265330), W.put(one("webhook-timestamp", "1614265330"), "webhook-signature", "v1,aa"))
    == Fail{W.Missing{"webhook-id"}} : Result<&1, &1, W.Err, String & String & List<&2, String>>}

law std_missing_signature:
  {W.std.check(300, at(1614265330), W.put(one("webhook-id", "m"), "webhook-timestamp", "1614265330"))
    == Fail{W.Missing{"webhook-signature"}} : Result<&1, &1, W.Err, String & String & List<&2, String>>}

law std_bad_id:
  {W.std.check(300, at(1614265330), W.put(W.put(one("webhook-id", "a.b"), "webhook-timestamp", "1614265330"), "webhook-signature", "v1,aa"))
    == Fail{W.BadId{}} : Result<&1, &1, W.Err, String & String & List<&2, String>>}

law std_bad_timestamp:
  {W.std.check(300, at(1614265330), std.h("1614265330.0"))
    == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, String & String & List<&2, String>>}

law std_too_old:
  {W.std.check(300, at(1614265631), std.h("1614265330"))
    == Fail{W.TooOld{}} : Result<&1, &1, W.Err, String & String & List<&2, String>>}

law std_too_new:
  {W.std.check(300, at(1614265029), std.h("1614265330"))
    == Fail{W.TooNew{}} : Result<&1, &1, W.Err, String & String & List<&2, String>>}

# The timestamp sign writes is the decimal it frames.
law sign_check:
  {W.sign.check("m", Time.i64(1614265330)) == Done{("m", "1614265330")} : Result<&1, &1, W.Err, String & String>}

law sign_check_negative:
  {W.sign.check("m", Int.I64.neg(Time.i64(1))) == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, String & String>}

law sign_check_bad_id:
  {W.sign.check("", Time.i64(1)) == Fail{W.BadId{}} : Result<&1, &1, W.Err, String & String>}

# Unpadded whsec_ keys are padded before decoding.
law pad_two:
  {W.pad("ab") == "ab==" : String}

law pad_three:
  {W.pad("abc") == "abc=" : String}

law pad_none:
  {W.pad("abcd") == "abcd" : String}

# ---- Stripe framing: t=<ts>,v1=<hex>,...; signs "t." then the body

law stripe_frame:
  {W.stripe.check(300, at(1614265330), one("stripe-signature", "t=1614265330,v1=aa,v0=bb,v1=cc"))
    == Done{(Unit{}, "1614265330.", ["aa", "cc"])} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

law stripe_no_t:
  {W.stripe.check(300, at(1614265330), one("stripe-signature", "v1=aa"))
    == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

# Two t= would leave the signed timestamp ambiguous.
law stripe_two_t:
  {W.stripe.check(300, at(1614265330), one("stripe-signature", "t=1614265330,t=1614265331,v1=aa"))
    == Fail{W.BadTimestamp{}} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

law stripe_too_old:
  {W.stripe.check(300, at(1614265631), one("stripe-signature", "t=1614265330,v1=aa"))
    == Fail{W.TooOld{}} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

law stripe_too_new:
  {W.stripe.check(300, at(1614265029), one("stripe-signature", "t=1614265330,v1=aa"))
    == Fail{W.TooNew{}} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

law stripe_missing:
  {W.stripe.check(300, at(1614265330), hs())
    == Fail{W.Missing{"stripe-signature"}} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

# ---- GitHub framing: sha256=<hex> over the body alone

law github_frame:
  {W.github.check(one("x-hub-signature-256", "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"))
    == Done{(Unit{}, "", ["757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"])}
    : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

# Without the sha256= prefix there is no candidate, so nothing can match.
law github_no_prefix:
  {W.github.check(one("x-hub-signature-256", "757107ea"))
    == Done{(Unit{}, "", [])} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}

law github_missing:
  {W.github.check(hs())
    == Fail{W.Missing{"x-hub-signature-256"}} : Result<&1, &1, W.Err, Unit & String & List<&2, String>>}
