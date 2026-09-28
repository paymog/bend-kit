import Base
import ./sigv4.bend as Sigv4
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Signatures need HMAC-SHA256 through libcrypto, so they run here, not in LAWS.bend.

def ok(b: Bool, +name: String, +got: String) -> IO(Unit):
  match b:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " gave " ++ got)

def same(+name: String, +want: String, r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{+got}:
      ok(String.eq(got, want), name, got)

def pair(+name: String, +want: String, +hash: String, r: Result<&1, &1, U32 & String, String & String>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+got, +h)}:
      do IO<Unit>:
        ok(String.eq(got, want), name, got)
        ok(String.eq(h, hash), name ++ " payload hash", h)

def fails(+name: String, r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      ok(U32.is_eq(code, 22), name, U32.show(code))
    case Done{+got}:
      IO.die(Unit, 1, name ++ " did not fail: " ++ got)

def suite() -> Sigv4.Credentials:
  Sigv4.Credentials{"AKIDEXAMPLE", "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY", ""}

def s3() -> Sigv4.Credentials:
  Sigv4.Credentials{"AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", ""}

def s3.token() -> Sigv4.Credentials:
  Sigv4.Credentials{"AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", "SESSIONTOKEN+/=abc"}

def vec(+name: String, +method: String, +path: String, +q: String, +hs: List<&2, Sigma<&2, &2, String, _ => String>>, +phash: String, +signed: String, +sig: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, String> <- Sigv4.sign(suite(), "us-east-1", "service", "20150830T123600Z", method, path, q, hs, phash)
    same(name, "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, SignedHeaders=" ++ signed ++ ", Signature=" ++ sig, r)

def main() -> IO(Unit):
  do IO<Unit>:
    # AWS SigV4 test suite: the .authz of each vector LAWS.bend pins.
    vec("get-vanilla", "GET", "/", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31")
    vec("get-vanilla-query-order-key-case", "GET", "/", "Param2=value2&Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "b97d918cfa904a5beff61c982a1b6f458b799221646efd99d3219ec94cdf2500")
    vec("get-vanilla-query-order-value", "GET", "/", "Param1=value2&Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "5772eed61e12b33fae39ee5e7012498b51d56abc0abb7c60486157bd471c4694")
    vec("get-vanilla-query-unreserved", "GET", "/", "-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz=-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "9c3e54bfcdf0b19771a7f523ee5669cdf59bc7cc0884027167c21bb143a40197")
    vec("get-vanilla-utf8-query", "GET", "/", "ሴ=bar", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "2cdec8eed098649ff3a119c94853b13c643bcf08f8b0a1d91e12c9027818dd04")
    vec("get-vanilla-empty-query-key", "GET", "/", "Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "a67d582fa61cc504c4bae71f336f98b97f1ea3c7a6bfe1b6e45aec72011b9aeb")
    vec("get-unreserved", "GET", "/-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "07ef7494c76fa4850883e2b006601f940f8a34d404d0cfa977f52a65bbf5f24f")
    vec("get-utf8", "GET", "/ሴ", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "8318018e0b0f223aa2bbf98705b62bb787dc9c0e678f255a891fd03141be5d85")
    vec("get-header-value-trim", "GET", "/", "", [("Host", "example.amazonaws.com"), ("My-Header1", " value1"), ("My-Header2", " \"a   b   c\""), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;my-header1;my-header2;x-amz-date", "acc3ed3afb60bb290fc8d2dd0098b9911fcaa05412b367055dee359757a9c736")
    vec("get-space", "GET", "/example space/", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "652487583200325589f1fba4c7e578f72c47cb61beeca81406b39ddec1366741")
    vec("get-slash", "GET", "//", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31")
    vec("get-slash-dot-slash", "GET", "/./", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31")
    vec("post-vanilla-query", "POST", "/", "Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date", "28038455d6de14eafc1f9222cf5aa6f1a96197d7deb8263271d420d138af7f11")
    vec("post-x-www-form-urlencoded", "POST", "/", "", [("Content-Type", "application/x-www-form-urlencoded"), ("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "9095672bbd1f56dfc5b65f3e153adc8731a4a654192329106275f4c7b24d0b6e", "content-type;host;x-amz-date", "ff11897932ad3f4e8b18135d722051e5ac45fc38421b1da7b9d196a0fe09473a")
    vec("post-sts-header-before", "POST", "/", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z"), ("X-Amz-Security-Token", "AQoDYXdzEPT//////////wEXAMPLEtc764bNrC9SAPBSM22wDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMicRXmxfpSPfIeoIYRqTflfKD8YUuwthAx7mSEI/qkPpKPi/kMcGdQrmGdeehM4IC1NtBmUpp2wUE8phUZampKsburEDy0KPkyQDYwT7WZ0wq5VSXDvp75YU9HFvlRd8Tx6q6fE8YQcHNVXAkiY9q6d+xo0rKwT38xVqr7ZD0u0iPPkUL64lIZbqBAz+scqKmlzm8FDrypNC9Yjc8fPOLn9FX9KSYvKTr4rvx3iSIlTJabIQwj2ICCR/oLxBA==")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "host;x-amz-date;x-amz-security-token", "85d96828115b5dc0cfc3bd16ad9e210dd772bbebba041836c64533a82be05ead")
    # The form body hashes to post-x-www-form-urlencoded's payload hash.
    h : Result<&1, &1, U32 & String, String> <- Sigv4.sha("Param1=value1")
    same("form body hash", "9095672bbd1f56dfc5b65f3e153adc8731a4a654192329106275f4c7b24d0b6e", h)
    # S3 docs: GET Bucket lifecycle, ListObjects, and the presigned GET example.
    a : Result<&1, &1, U32 & String, String & String> <- Sigv4.authorize(s3(), "us-east-1", "s3", "20130524T000000Z", "GET", "/", "lifecycle", "examplebucket.s3.amazonaws.com", Bytes.from_string(""))
    pair("s3 lifecycle", "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", a)
    b : Result<&1, &1, U32 & String, String & String> <- Sigv4.authorize(s3(), "us-east-1", "s3", "20130524T000000Z", "GET", "/", "prefix=J&max-keys=2", "examplebucket.s3.amazonaws.com", Bytes.from_string(""))
    pair("s3 list", "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", b)
    p : Result<&1, &1, U32 & String, String> <- Sigv4.presign(s3(), "us-east-1", "s3", "20130524T000000Z", "GET", "/test.txt", "", "examplebucket.s3.amazonaws.com", 86400)
    same("s3 presign", "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404", p)
    # Session tokens, checked against botocore 1.42 (S3SigV4Auth, S3SigV4QueryAuth).
    t : Result<&1, &1, U32 & String, String & String> <- Sigv4.authorize(s3.token(), "us-east-1", "s3", "20260928T180350Z", "PUT", "/my%20key/%E1%88%B4.txt", "x-id=PutObject", "examplebucket.s3.amazonaws.com", Bytes.from_string("hello"))
    pair("s3 token put", "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20260928/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-security-token, Signature=c37580d30220ddedca50d17d90c4f3729a72e0c754f12fc45374bf9d882b64d3", "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", t)
    u : Result<&1, &1, U32 & String, String> <- Sigv4.presign(s3.token(), "us-east-1", "s3", "20260928T180355Z", "GET", "/test.txt", "", "examplebucket.s3.amazonaws.com", 3600)
    same("s3 token presign", "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20260928%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260928T180355Z&X-Amz-Expires=3600&X-Amz-Security-Token=SESSIONTOKEN%2B%2F%3Dabc&X-Amz-SignedHeaders=host&X-Amz-Signature=d713c83396f6bb183cddf654c276d6301a2e92b45c808de76017a560743252fe", u)
    z : Result<&1, &1, U32 & String, String> <- Sigv4.presign(s3(), "us-east-1", "s3", "20130524T000000Z", "GET", "/test.txt", "", "examplebucket.s3.amazonaws.com", 0)
    fails("presign expires 0", z)
    y : Result<&1, &1, U32 & String, String> <- Sigv4.presign(s3(), "us-east-1", "s3", "20130524T000000Z", "GET", "/test.txt", "", "examplebucket.s3.amazonaws.com", 604801)
    fails("presign expires > 7 days", y)
