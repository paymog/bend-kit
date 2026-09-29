import Base
import ./jwt.bend as Jwt
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Pure halves: base64url, NumericDate, header and claim checks, and JWKS key choice.
# check.bend verifies the RFC 7515 signatures and signs round trips, which need libcrypto.

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

def of(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def dec(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Some{Bytes.to_string(b)}

# RFC 7515 A.1: the HS256 JWS of the RFC 7519 §3.1 claims.
def rfc() -> String:
  "eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

def hs() -> Jwt.Policy:
  Jwt.policy(Jwt.HS256{})

def keyset() -> List<&2, Jwt.Jwk>:
  Maybe.default(&2, List<&2, Jwt.Jwk>, Jwt.jwks.parse(of("{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"k1\",\"use\":\"enc\",\"n\":\"AA\",\"e\":\"AQAB\"},{\"kty\":\"RSA\",\"kid\":\"k1\",\"alg\":\"RS256\",\"n\":\"nn\",\"e\":\"AQAB\"},{\"kty\":\"EC\",\"kid\":\"e1\",\"crv\":\"P-384\",\"x\":\"AA\",\"y\":\"AA\"},{\"kty\":\"EC\",\"kid\":\"e1\",\"crv\":\"P-256\",\"x\":\"xx\",\"y\":\"yy\"},{\"kty\":\"oct\",\"kid\":\"h1\",\"k\":\"AA\"}]}")), Nil{})

# base64url (RFC 4648 §5), as RFC 7515 §2 uses it: RFC 7515 A.1's header and signature.
law b64u_rfc_header:
  {dec(Jwt.unb64u("eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9")) == Some{"{\"typ\":\"JWT\",\r\n \"alg\":\"HS256\"}"} : Maybe<&2, String>}

law b64u_rfc_signature:
  {Jwt.b64u(of(bytes([116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186, 22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, 132, 141, 121]))) == "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk" : String}

law b64u_url_alphabet:
  {dec(Jwt.unb64u("-_8")) == Some{bytes([251, 255])} : Maybe<&2, String>}

law b64u_unpadded:
  {Jwt.b64u(of("f")) == "Zg" : String}

law b64u_rejects_padding:
  {dec(Jwt.unb64u("Zg==")) == None{} : Maybe<&2, String>}

law b64u_rejects_std_alphabet:
  {dec(Jwt.unb64u("+/8")) == None{} : Maybe<&2, String>}

# RFC 4648 §3.5: pad bits must be 0, so "Zh" is not the canonical text of "f".
law b64u_rejects_pad_bits:
  {dec(Jwt.unb64u("Zh")) == None{} : Maybe<&2, String>}

law b64u_rejects_one_char_group:
  {dec(Jwt.unb64u("Zm9vY")) == None{} : Maybe<&2, String>}

# NumericDate (RFC 7519 §2): whole seconds, fractions rounded up, the U32 top as a cap.
law secs_whole:
  {Jwt.secs("1300819380") == Some{1300819380} : Maybe<&2, U32>}

law secs_fraction_up:
  {Jwt.secs("1300819380.25") == Some{1300819381} : Maybe<&2, U32>}

law secs_zero_fraction:
  {Jwt.secs("1300819380.000") == Some{1300819380} : Maybe<&2, U32>}

law secs_cap:
  {Jwt.secs("99999999999") == Some{4294967295} : Maybe<&2, U32>}

law secs_negative:
  {Jwt.secs("-1") == None{} : Maybe<&2, U32>}

law secs_exponent:
  {Jwt.secs("1e3") == None{} : Maybe<&2, U32>}

# RFC 7519 §3.1 claims under RFC 7515 A.1's header: exp is 1300819380 and iss is "joe".
law rfc_before_exp:
  {Jwt.inspect(hs(), rfc(), 1300819379) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

law rfc_at_exp:
  {Jwt.inspect(hs(), rfc(), 1300819380) == Fail{Jwt.Expired{}} : Result<&1, &1, Jwt.Err, Unit>}

law rfc_leeway:
  {Jwt.inspect(Jwt.leeway(hs(), 60), rfc(), 1300819439) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

law rfc_past_leeway:
  {Jwt.inspect(Jwt.leeway(hs(), 60), rfc(), 1300819440) == Fail{Jwt.Expired{}} : Result<&1, &1, Jwt.Err, Unit>}

law rfc_iss:
  {Jwt.inspect(Jwt.iss(hs(), "joe"), rfc(), 1300819000) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

law rfc_wrong_iss:
  {Jwt.inspect(Jwt.iss(hs(), "bob"), rfc(), 1300819000) == Fail{Jwt.BadIss{}} : Result<&1, &1, Jwt.Err, Unit>}

# RFC 7519 §4.1.3: wanting an audience the token lacks fails.
law rfc_missing_aud:
  {Jwt.inspect(Jwt.aud(hs(), "a"), rfc(), 1300819000) == Fail{Jwt.BadAud{}} : Result<&1, &1, Jwt.Err, Unit>}

# The pinned alg is RS256, the header says HS256: alg confusion fails before any key is used.
law rfc_alg_mismatch:
  {Jwt.inspect(Jwt.policy(Jwt.RS256{}), rfc(), 1300819000) == Fail{Jwt.AlgMismatch{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"alg":"none"}.{"iss":"joe"}. with no signature.
law alg_none:
  {Jwt.inspect(hs(), "eyJhbGciOiJub25lIn0.eyJpc3MiOiJqb2UifQ.", 0) == Fail{Jwt.AlgMismatch{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"typ":"JWT"}: no alg at all.
law alg_missing:
  {Jwt.inspect(hs(), "eyJ0eXAiOiJKV1QifQ.e30.c2ln", 0) == Fail{Jwt.Malformed{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"alg":"HS256","alg":"none"}: a repeated name fails, rather than trusting either one.
law header_dup:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiIsImFsZyI6Im5vbmUifQ.e30.c2ln", 0) == Fail{Jwt.Malformed{}} : Result<&1, &1, Jwt.Err, Unit>}

law header_crit:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiIsImNyaXQiOlsiZXhwIl0sImV4cCI6MX0.e30.c2ln", 0) == Fail{Jwt.Crit{}} : Result<&1, &1, Jwt.Err, Unit>}

law header_b64:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiIsImI2NCI6ZmFsc2V9.e30.c2ln", 0) == Fail{Jwt.Crit{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"aud":["a","b"],"exp":2000}
law aud_in_array:
  {Jwt.inspect(Jwt.aud(hs(), "b"), "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOlsiYSIsImIiXSwiZXhwIjoyMDAwfQ.c2ln", 1000) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

law aud_wrong:
  {Jwt.inspect(Jwt.aud(hs(), "c"), "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOlsiYSIsImIiXSwiZXhwIjoyMDAwfQ.c2ln", 1000) == Fail{Jwt.BadAud{}} : Result<&1, &1, Jwt.Err, Unit>}

# A token for some audience, checked by a verifier that names none.
law aud_unwanted:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOlsiYSIsImIiXSwiZXhwIjoyMDAwfQ.c2ln", 1000) == Fail{Jwt.BadAud{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"aud":"a"}
law aud_string:
  {Jwt.inspect(Jwt.aud(hs(), "a"), "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJhIn0.c2ln", 0) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"nbf":1000,"iat":900}
law nbf_early:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJuYmYiOjEwMDAsImlhdCI6OTAwfQ.c2ln", 999) == Fail{Jwt.NotYet{}} : Result<&1, &1, Jwt.Err, Unit>}

law nbf_reached:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJuYmYiOjEwMDAsImlhdCI6OTAwfQ.c2ln", 1000) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

law nbf_leeway:
  {Jwt.inspect(Jwt.leeway(hs(), 5), "eyJhbGciOiJIUzI1NiJ9.eyJuYmYiOjEwMDAsImlhdCI6OTAwfQ.c2ln", 995) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"iat":1100}: issued in the future.
law iat_future:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJpYXQiOjExMDB9.c2ln", 1000) == Fail{Jwt.Future{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"exp":1000.5}: valid at 1000, expired at 1001.
law exp_fraction_valid:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjEwMDAuNX0.c2ln", 1000) == Done{Unit{}} : Result<&1, &1, Jwt.Err, Unit>}

law exp_fraction_expired:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjEwMDAuNX0.c2ln", 1001) == Fail{Jwt.Expired{}} : Result<&1, &1, Jwt.Err, Unit>}

# {"exp":"1000"} and {"exp":1e3}: a time that is not a plain number fails.
law exp_string:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOiIxMDAwIn0.c2ln", 0) == Fail{Jwt.BadClaim{}} : Result<&1, &1, Jwt.Err, Unit>}

law exp_exponent:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjFlM30.c2ln", 0) == Fail{Jwt.BadClaim{}} : Result<&1, &1, Jwt.Err, Unit>}

# Claims that are [1], not an object.
law claims_not_object:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.WzFd.c2ln", 0) == Fail{Jwt.Malformed{}} : Result<&1, &1, Jwt.Err, Unit>}

law two_segments:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.e30", 0) == Fail{Jwt.Malformed{}} : Result<&1, &1, Jwt.Err, Unit>}

law padded_segment:
  {Jwt.inspect(hs(), "eyJhbGciOiJIUzI1NiJ9.e30=.c2ln", 0) == Fail{Jwt.Malformed{}} : Result<&1, &1, Jwt.Err, Unit>}

# JWKS: an enc key and a P-384 key under the same kids are skipped; oct keys are never used.
law jwks_rsa_sig_key:
  {Jwt.jwk.pick(keyset(), "k1", Jwt.RS256{}) == Some{Jwt.Jwk{"k1", True{}, "RS256", "nn", "AQAB"}} : Maybe<&2, Jwt.Jwk>}

law jwks_ec_p256:
  {Jwt.jwk.pick(keyset(), "e1", Jwt.ES256{}) == Some{Jwt.Jwk{"e1", False{}, "", "xx", "yy"}} : Maybe<&2, Jwt.Jwk>}

law jwks_kty_mismatch:
  {Jwt.jwk.pick(keyset(), "k1", Jwt.ES256{}) == None{} : Maybe<&2, Jwt.Jwk>}

law jwks_no_oct:
  {Jwt.jwk.pick(keyset(), "h1", Jwt.HS256{}) == None{} : Maybe<&2, Jwt.Jwk>}

law jwks_unknown_kid:
  {Jwt.jwk.pick(keyset(), "k2", Jwt.RS256{}) == None{} : Maybe<&2, Jwt.Jwk>}
