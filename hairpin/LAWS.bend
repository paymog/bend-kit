import Base
import ./hairpin.bend as Hairpin
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-http@0.38.1.1/http.bend as Http
import bend-kit-time@0.3.0.0/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def hs(k: String, v: String) -> Map<&2, List<&2, String>>:
  Http.set(Http.empty(), k, v)

# With no base, the URL goes as given, even when it is not absolute.
law target_no_base:
  {Hairpin.target("", "https://a.example/x") == Some{"https://a.example/x"} : Maybe<&2, String>}

law target_relative:
  {Hairpin.target("https://api.example/v1/", "users/7") == Some{"https://api.example/v1/users/7"} : Maybe<&2, String>}

law target_absolute_ref:
  {Hairpin.target("https://api.example/v1/", "http://b.example/y") == Some{"http://b.example/y"} : Maybe<&2, String>}

law target_bad_base:
  {Hairpin.target("/v1/", "users") == None{} : Maybe<&2, String>}

law merge_default:
  {Http.header(Hairpin.merge(hs("Accept", "a"), Http.empty()), "accept") == "a" : String}

# A request header replaces the default of its name, whatever the case of either.
law merge_override:
  {Http.fields(Hairpin.merge(hs("accept", "a"), hs("ACCEPT", "b")), "accept") == ["b"] : List<&2, String>}

law merge_both:
  {Http.header(Hairpin.merge(hs("x-a", "1"), hs("x-b", "2")), "x-a") == "1" : String}

# The client owns Host and Content-Length, so a default cannot set them.
law merge_reserved:
  {Http.fields(Hairpin.merge(hs("Host", "evil"), hs("content-length", "9")), "host") == Nil{} : List<&2, String>}

# ---- Hairpin's outcome classification

def verdict(x: Result<&1, &1, Http.Err, Http.Res> & Hairpin.Verdict) -> Hairpin.Verdict:
  (res, v) = x
  v

def epoch() -> Time.Instant:
  Time.Instant.of_unix(Int.I64.from_u32(0))

def judged(+idem: Bool, r: Result<&1, &1, Http.Err, Http.Res>) -> Retry.Outcome:
  Hairpin.outcome(idem, verdict(Hairpin.judge(r)), epoch())

def counted(r: Result<&1, &1, Http.Err, Http.Res>) -> Bool:
  Retry.failed(judged(True{}, r))

def res(+status: U32, h: Map<&2, List<&2, String>>) -> Result<&1, &1, Http.Err, Http.Res>:
  Done{Http.Res{status, h, Bytes.new(0)}}

# A transient failure of an idempotent request may try again, after the server's Retry-After.
law outcome_get_503:
  {judged(True{}, res(503, hs("retry-after", "2"))) == Retry.Transient{Some{2000n}} : Retry.Outcome}

law outcome_get_connect:
  {judged(True{}, Fail{Http.ErrConnect{61, "refused"}}) == Retry.Transient{None{}} : Retry.Outcome}

# The same failure of a POST counts against the breaker, but is never tried again.
law outcome_post_503:
  {judged(False{}, res(503, Http.empty())) == Retry.Unsafe{} : Retry.Outcome}

# A success and a redirect returned in manual mode are settled.
law outcome_settled:
  {[judged(True{}, res(200, Http.empty())), judged(True{}, res(302, Http.empty()))] == [Retry.Settled{}, Retry.Settled{}] : List<&2, Retry.Outcome>}

# A client error is rejected: it stops, and it is not the target's failure.
law outcome_rejected:
  {[judged(True{}, res(404, Http.empty())), judged(False{}, res(400, Http.empty()))] == [Retry.Rejected{}, Retry.Rejected{}] : List<&2, Retry.Outcome>}

# A server error that is not transient, and an error that would repeat, are failed.
law outcome_failed:
  {[judged(True{}, res(501, Http.empty())), judged(True{}, Fail{Http.ErrDns{}})] == [Retry.Failed{}, Retry.Failed{}] : List<&2, Retry.Outcome>}

# The breaker counts the target's failures, and not a success or a client error.
law breaker_counts:
  {[counted(res(200, Http.empty())), counted(res(404, Http.empty())), counted(res(501, Http.empty())), counted(Fail{Http.ErrDns{}}), counted(res(503, Http.empty()))] == [False{}, False{}, True{}, True{}, True{}] : List<&2, Bool>}
