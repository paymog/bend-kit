import Base
import ./sigv4.bend as Sigv4

# AWS SigV4 test suite (aws-sig-v4-test-suite, as mirrored in mongodb/libmongocrypt kms-message):
# region us-east-1, service "service", date 20150830T123600Z. Each vector pins the canonical request
# (.creq) and the string to sign (.sts). check.bend pins the signatures, which need HMAC.

law get_vanilla_creq:
  {Sigv4.canonical("service", "GET", "/", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\n\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_vanilla_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "bb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\nbb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63" : String}

law get_vanilla_query_order_key_case_creq:
  {Sigv4.canonical("service", "GET", "/", "Param2=value2&Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\nParam1=value1&Param2=value2\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_vanilla_query_order_key_case_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "816cd5b414d056048ba4f7c5386d6e0533120fb1fcfa93762cf0fc39e2cf19e0") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\n816cd5b414d056048ba4f7c5386d6e0533120fb1fcfa93762cf0fc39e2cf19e0" : String}

law get_vanilla_query_order_value_creq:
  {Sigv4.canonical("service", "GET", "/", "Param1=value2&Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\nParam1=value1&Param1=value2\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_vanilla_query_order_value_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "c968629d70850097a2d8781c9bf7edcb988b04cac14cca9be4acc3595f884606") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\nc968629d70850097a2d8781c9bf7edcb988b04cac14cca9be4acc3595f884606" : String}

law get_vanilla_query_unreserved_creq:
  {Sigv4.canonical("service", "GET", "/", "-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz=-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\n-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz=-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_vanilla_query_unreserved_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "c30d4703d9f799439be92736156d47ccfb2d879ddf56f5befa6d1d6aab979177") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\nc30d4703d9f799439be92736156d47ccfb2d879ddf56f5befa6d1d6aab979177" : String}

law get_vanilla_utf8_query_creq:
  {Sigv4.canonical("service", "GET", "/", "ሴ=bar", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\n%E1%88%B4=bar\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_vanilla_utf8_query_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "eb30c5bed55734080471a834cc727ae56beb50e5f39d1bff6d0d38cb192a7073") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\neb30c5bed55734080471a834cc727ae56beb50e5f39d1bff6d0d38cb192a7073" : String}

law get_vanilla_empty_query_key_creq:
  {Sigv4.canonical("service", "GET", "/", "Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\nParam1=value1\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_vanilla_empty_query_key_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "1e24db194ed7d0eec2de28d7369675a243488e08526e8c1c73571282f7c517ab") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\n1e24db194ed7d0eec2de28d7369675a243488e08526e8c1c73571282f7c517ab" : String}

law get_unreserved_creq:
  {Sigv4.canonical("service", "GET", "/-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\n\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_unreserved_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "6a968768eefaa713e2a6b16b589a8ea192661f098f37349f4e2c0082757446f9") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\n6a968768eefaa713e2a6b16b589a8ea192661f098f37349f4e2c0082757446f9" : String}

law get_utf8_creq:
  {Sigv4.canonical("service", "GET", "/ሴ", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/%E1%88%B4\n\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_utf8_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "2a0a97d02205e45ce2e994789806b19270cfbbb0921b278ccf58f5249ac42102") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\n2a0a97d02205e45ce2e994789806b19270cfbbb0921b278ccf58f5249ac42102" : String}

law get_header_value_trim_creq:
  {Sigv4.canonical("service", "GET", "/", "", [("Host", "example.amazonaws.com"), ("My-Header1", " value1"), ("My-Header2", " \"a   b   c\""), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\n\nhost:example.amazonaws.com\nmy-header1:value1\nmy-header2:\"a b c\"\nx-amz-date:20150830T123600Z\n\nhost;my-header1;my-header2;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_header_value_trim_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "a726db9b0df21c14f559d0a978e563112acb1b9e05476f0a6a1c7d68f28605c7") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\na726db9b0df21c14f559d0a978e563112acb1b9e05476f0a6a1c7d68f28605c7" : String}

law get_space_creq:
  {Sigv4.canonical("service", "GET", "/example space/", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/example%20space/\n\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_space_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "63ee75631ed7234ae61b5f736dfc7754cdccfedbff4b5128a915706ee9390d86") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\n63ee75631ed7234ae61b5f736dfc7754cdccfedbff4b5128a915706ee9390d86" : String}

law get_slash_creq:
  {Sigv4.canonical("service", "GET", "//", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\n\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_slash_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "bb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\nbb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63" : String}

law get_slash_dot_slash_creq:
  {Sigv4.canonical("service", "GET", "/./", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\n\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law get_slash_dot_slash_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "bb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\nbb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63" : String}

law post_vanilla_query_creq:
  {Sigv4.canonical("service", "POST", "/", "Param1=value1", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "POST\n/\nParam1=value1\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\nhost;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law post_vanilla_query_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "9d659678c1756bb3113e2ce898845a0a79dbbc57b740555917687f1b3340fbbd") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\n9d659678c1756bb3113e2ce898845a0a79dbbc57b740555917687f1b3340fbbd" : String}

law post_x_www_form_urlencoded_creq:
  {Sigv4.canonical("service", "POST", "/", "", [("Content-Type", "application/x-www-form-urlencoded"), ("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z")], "9095672bbd1f56dfc5b65f3e153adc8731a4a654192329106275f4c7b24d0b6e") == "POST\n/\n\ncontent-type:application/x-www-form-urlencoded\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\n\ncontent-type;host;x-amz-date\n9095672bbd1f56dfc5b65f3e153adc8731a4a654192329106275f4c7b24d0b6e" : String}

law post_x_www_form_urlencoded_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "42a5e5bb34198acb3e84da4f085bb7927f2bc277ca766e6d19c73c2154021281") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\n42a5e5bb34198acb3e84da4f085bb7927f2bc277ca766e6d19c73c2154021281" : String}

law post_sts_header_before_creq:
  {Sigv4.canonical("service", "POST", "/", "", [("Host", "example.amazonaws.com"), ("X-Amz-Date", "20150830T123600Z"), ("X-Amz-Security-Token", "AQoDYXdzEPT//////////wEXAMPLEtc764bNrC9SAPBSM22wDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMicRXmxfpSPfIeoIYRqTflfKD8YUuwthAx7mSEI/qkPpKPi/kMcGdQrmGdeehM4IC1NtBmUpp2wUE8phUZampKsburEDy0KPkyQDYwT7WZ0wq5VSXDvp75YU9HFvlRd8Tx6q6fE8YQcHNVXAkiY9q6d+xo0rKwT38xVqr7ZD0u0iPPkUL64lIZbqBAz+scqKmlzm8FDrypNC9Yjc8fPOLn9FX9KSYvKTr4rvx3iSIlTJabIQwj2ICCR/oLxBA==")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "POST\n/\n\nhost:example.amazonaws.com\nx-amz-date:20150830T123600Z\nx-amz-security-token:AQoDYXdzEPT//////////wEXAMPLEtc764bNrC9SAPBSM22wDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMicRXmxfpSPfIeoIYRqTflfKD8YUuwthAx7mSEI/qkPpKPi/kMcGdQrmGdeehM4IC1NtBmUpp2wUE8phUZampKsburEDy0KPkyQDYwT7WZ0wq5VSXDvp75YU9HFvlRd8Tx6q6fE8YQcHNVXAkiY9q6d+xo0rKwT38xVqr7ZD0u0iPPkUL64lIZbqBAz+scqKmlzm8FDrypNC9Yjc8fPOLn9FX9KSYvKTr4rvx3iSIlTJabIQwj2ICCR/oLxBA==\n\nhost;x-amz-date;x-amz-security-token\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law post_sts_header_before_sts:
  {Sigv4.to_sign("20150830T123600Z", Sigv4.scope("20150830T123600Z", "us-east-1", "service"), "c237e1b440d4c63c32ca95b5b99481081cb7b13c7e40434868e71567c1a882f6") == "AWS4-HMAC-SHA256\n20150830T123600Z\n20150830/us-east-1/service/aws4_request\nc237e1b440d4c63c32ca95b5b99481081cb7b13c7e40434868e71567c1a882f6" : String}

# S3 (docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html and
# sigv4-query-string-auth.html): examplebucket, us-east-1, 20130524T000000Z. S3 signs x-amz-content-sha256.

law s3_lifecycle_creq:
  {Sigv4.canonical("s3", "GET", "/", "lifecycle", [("host", "examplebucket.s3.amazonaws.com"), ("x-amz-content-sha256", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"), ("x-amz-date", "20130524T000000Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\nlifecycle=\nhost:examplebucket.s3.amazonaws.com\nx-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\nx-amz-date:20130524T000000Z\n\nhost;x-amz-content-sha256;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

# Out of order on the wire; canonical order is by key.
law s3_list_creq:
  {Sigv4.canonical("s3", "GET", "/", "prefix=J&max-keys=2", [("host", "examplebucket.s3.amazonaws.com"), ("x-amz-content-sha256", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"), ("x-amz-date", "20130524T000000Z")], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "GET\n/\nmax-keys=2&prefix=J\nhost:examplebucket.s3.amazonaws.com\nx-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\nx-amz-date:20130524T000000Z\n\nhost;x-amz-content-sha256;x-amz-date\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" : String}

law s3_presign_query:
  {Sigv4.presign.query("AKIAIOSFODNN7EXAMPLE", "", Sigv4.scope("20130524T000000Z", "us-east-1", "s3"), "20130524T000000Z", 86400, "") == "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host" : String}

# The session token joins the signed query in key order, encoded.
law presign_token_query:
  {Sigv4.presign.query("AK", "t+/=", "20130524/us-east-1/s3/aws4_request", "20130524T000000Z", 60, "b=1") == "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AK%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=60&X-Amz-Security-Token=t%2B%2F%3D&X-Amz-SignedHeaders=host&b=1" : String}

law authorization_header:
  {Sigv4.header("AKIDEXAMPLE", "20150830/us-east-1/service/aws4_request", "host;x-amz-date", "5fa0") == "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, SignedHeaders=host;x-amz-date, Signature=5fa0" : String}

# Canonical URI and query: S3 keeps dot and empty segments; other services encode wire escapes twice.
# Duplicate query keys stay, ordered by value.
law uri_s3_as_sent:
  {Sigv4.uri("s3", "/a//b/./c/../d") == "/a//b/./c/../d" : String}

law uri_s3_reencodes:
  {Sigv4.uri("s3", "/my key/%e1%88%b4%2F+.txt") == "/my%20key/%E1%88%B4%2F%2B.txt" : String}

law uri_s3_raw_utf8:
  {Sigv4.uri("s3", "/ሴ") == "/%E1%88%B4" : String}

law uri_dots:
  {Sigv4.uri("service", "//a/./b/../c/") == "/a/c/" : String}

law uri_dots_pop_all:
  {Sigv4.uri("service", "/example1/example2/../..") == "/" : String}

law uri_non_s3_wire_escape:
  {Sigv4.uri("lambda", "/2015-03-31/functions/arn%3Aaws%3Alambda/invocations") == "/2015-03-31/functions/arn%253Aaws%253Alambda/invocations" : String}

law uri_empty:
  {Sigv4.uri("s3", "") == "/" : String}

law query_dup_keys:
  {Sigv4.query("Param1=value2&Param1=Value1&&a") == "Param1=Value1&Param1=value2&a=" : String}

law query_value_eq:
  {Sigv4.query("k=a=b&j=%7e%20") == "j=~%20&k=a%3Db" : String}

law query_bad_escape:
  {Sigv4.query("k=100%") == "k=100%25" : String}

law encode_key:
  {Sigv4.encode("a b/é~", True{}) == "a%20b/%C3%A9~" : String}

law encode_value:
  {Sigv4.encode("a b/é~", False{}) == "a%20b%2F%C3%A9~" : String}

law header_dup_trim:
  {Sigv4.canonical("s3", "GET", "/", "", [("X-B", " 1  2 "), ("host", "h"), ("x-b", "3")], "UNSIGNED-PAYLOAD") == "GET\n/\n\nhost:h\nx-b:1 2,3\n\nhost;x-b\nUNSIGNED-PAYLOAD" : String}
