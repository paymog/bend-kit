import Base
import ./oauth2.bend as O
import bend-kit-time@0.1.0.0/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def octs(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{x, t}:
      SCon{Chr{x}, octs(t)}

def of(+xs: List<&2, U32>) -> Bytes.Bytes:
  Bytes.from_string(octs(xs))

def at(+s: U32) -> Time.Instant:
  Time.Instant.of_unix(Time.i64(s))

def cfg() -> O.Config:
  O.Config{"https://as.example/token", "s6BhdRkqt3", "gX1fBat3bV"}

def tok(e: Maybe<&2, Time.Instant>) -> O.Token:
  O.Token{"at", "Bearer", "rt", "", e}

# RFC 7636 Appendix B: the 32 random octets encode to the verifier.
law pkce_verifier_rfc7636:
  {O.b64url(of([116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186, 22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, 132, 141, 121]))
    == "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk" : String}

# RFC 7636 Appendix B: SHA-256 of that verifier encodes to the S256 challenge.
law pkce_challenge_rfc7636:
  {O.b64url(of([19, 211, 30, 150, 26, 26, 216, 236, 47, 22, 177, 12, 76, 152, 46, 8, 118, 168, 120, 173, 109, 241, 68, 86, 110, 225, 137, 74, 203, 112, 249, 195]))
    == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM" : String}

# RFC 4648 §5: '-' and '_' replace '+' and '/', and there is no padding.
law b64url_alphabet:
  {O.b64url(of([251, 255])) == "-_8" : String}

# RFC 6749 §4.1.3 example credentials, as HTTP Basic.
law basic_rfc6749:
  {O.basic("s6BhdRkqt3", "gX1fBat3bV") == "Basic czZCaGRSa3F0MzpnWDFmQmF0M2JW" : String}

# A public client (secret "") names itself in the body; a confidential one does not.
law body_public:
  {O.body("app", "", O.form("grant_type", "client_credentials")) == "client_id=app&grant_type=client_credentials" : String}

law body_confidential:
  {O.body("app", "pw", O.scoped("read write", O.form("grant_type", "client_credentials"))) == "grant_type=client_credentials&scope=read%20write" : String}

# RFC 7636 §4.3: the challenge and S256 ride on the authorization request.
law authorize_url:
  {O.authorize.url(cfg(), "https://as.example/authorize", "https://app.example/cb", "", "xyz", "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    == "https://as.example/authorize?client_id=s6BhdRkqt3&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256&redirect_uri=https%3A%2F%2Fapp.example%2Fcb&response_type=code&state=xyz" : String}

law authorize_url_query:
  {O.authorize.url(cfg(), "https://as.example/auth?tenant=1", "cb", "openid", "s", "c")
    == "https://as.example/auth?tenant=1&client_id=s6BhdRkqt3&code_challenge=c&code_challenge_method=S256&redirect_uri=cb&response_type=code&scope=openid&state=s" : String}

law callback_code:
  {O.callback("https://app.example/cb?code=Spl%20xOBe&state=xyz#frag", "xyz") == Done{"Spl xOBe"} : Result<&1, &1, O.Err, String>}

# RFC 6749 §10.12: a state that is not ours is refused, even when a code came with it.
law callback_state:
  {O.callback("https://app.example/cb?code=a&state=evil", "xyz") == Fail{O.ErrState{}} : Result<&1, &1, O.Err, String>}

law callback_error:
  {O.callback("https://app.example/cb?error=access_denied&error_description=no&state=xyz", "xyz")
    == Fail{O.ErrOAuth{0, "access_denied", "no"}} : Result<&1, &1, O.Err, String>}

# RFC 6749 §5.1.
law parse_token:
  {O.parse(200, "", at(0), Bytes.from_string("{\"access_token\":\"2YotnFZFEjr1zCsicMWpAA\",\"token_type\":\"Bearer\",\"refresh_token\":\"tGzv3JOkF0XG5Qx2TlKWIA\",\"scope\":\"read\"}"))
    == Done{O.Token{"2YotnFZFEjr1zCsicMWpAA", "Bearer", "tGzv3JOkF0XG5Qx2TlKWIA", "read", None{}}} : Result<&1, &1, O.Err, O.Token>}

# §6: a refresh reply without refresh_token keeps the old one.
law parse_keeps_refresh:
  {O.parse(200, "old", at(0), Bytes.from_string("{\"access_token\":\"new\",\"token_type\":\"bearer\"}"))
    == Done{O.Token{"new", "bearer", "old", "", None{}}} : Result<&1, &1, O.Err, O.Token>}

# expires_in counts from when the request was made; a string number counts too.
law parse_expires:
  {O.parse(200, "", at(1000), Bytes.from_string("{\"access_token\":\"a\",\"token_type\":\"Bearer\",\"expires_in\":3600}"))
    == Done{O.Token{"a", "Bearer", "", "", Some{at(4600)}}} : Result<&1, &1, O.Err, O.Token>}

law parse_expires_string:
  {O.parse(200, "", at(0), Bytes.from_string("{\"access_token\":\"a\",\"token_type\":\"BEARER\",\"expires_in\":\"60\"}"))
    == Done{O.Token{"a", "BEARER", "", "", Some{at(60)}}} : Result<&1, &1, O.Err, O.Token>}

# RFC 6750: request sends Bearer, so a token of another type, or of no type, is refused.
law parse_not_bearer:
  {O.parse(200, "", at(0), Bytes.from_string("{\"access_token\":\"a\",\"token_type\":\"mac\"}"))
    == Fail{O.ErrReply{200, "{\"access_token\":\"a\",\"token_type\":\"mac\"}"}} : Result<&1, &1, O.Err, O.Token>}

law parse_no_type:
  {O.parse(200, "", at(0), Bytes.from_string("{\"access_token\":\"a\"}"))
    == Fail{O.ErrReply{200, "{\"access_token\":\"a\"}"}} : Result<&1, &1, O.Err, O.Token>}

# §5.2.
law parse_error:
  {O.parse(400, "", at(0), Bytes.from_string("{\"error\":\"invalid_grant\",\"error_description\":\"bad code\"}"))
    == Fail{O.ErrOAuth{400, "invalid_grant", "bad code"}} : Result<&1, &1, O.Err, O.Token>}

law parse_not_json:
  {O.parse(502, "", at(0), Bytes.from_string("<html>")) == Fail{O.ErrReply{502, "<html>"}} : Result<&1, &1, O.Err, O.Token>}

# A 2xx without access_token is not a token.
law parse_no_access:
  {O.parse(200, "", at(0), Bytes.from_string("{\"token_type\":\"Bearer\"}")) == Fail{O.ErrReply{200, "{\"token_type\":\"Bearer\"}"}} : Result<&1, &1, O.Err, O.Token>}

law expiring_none:
  {O.expiring(tok(None{}), at(4000000000), 30) == False{} : Bool}

# Due once now + skew reaches the expiry.
law expiring_within_skew:
  {O.expiring(tok(Some{at(100)}), at(70), 30) == True{} : Bool}

law expiring_before_skew:
  {O.expiring(tok(Some{at(100)}), at(69), 30) == False{} : Bool}
