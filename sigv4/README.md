# sigv4

AWS Signature V4, and an S3 client over `hairpin`.

```bend
import bend-kit-sigv4@0.1.0.0/sigv4.bend as Sig
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
```

`sigv4.bend` imports that `http`, `bend-kit-crypto@0.1.1.0`, and `bend-kit-time@0.1.0.0`. HMAC-SHA256 needs OpenSSL 3 (`BEND_LIBCRYPTO` on the crypto package).

`Credentials` holds the access key, secret, and session token. An empty token means a long-term key. `sign` returns the `Authorization` value. The date argument is `x-amz-date` form, `YYYYMMDDTHHMMSSZ`. `authorize` returns that header and the signed `x-amz-date`. `presign` builds a query-string signature with an expiry in seconds.

S3 path encoding is not the encoding used for other services. `new`, `put`, `get`, and `list` are the S3 client. `from_env` reads the usual AWS environment variables. `put` and `get` return the `Client` beside the result.

`check.bend` signs the AWS suite vectors. `smoke.bend` talks to a live bucket when the environment is set.
