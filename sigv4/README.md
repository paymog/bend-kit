# sigv4

AWS Signature V4, and an S3 client over `hairpin`.

```bend
import bend-kit-sigv4@0.17.0.4/sigv4.bend as Sig
import bend-kit-hairpin@0.19.0.3/hairpin.bend as Hairpin
import bend-kit-hairpin@0.19.0.3/pure.bend as HairpinPure
import bend-kit-http@0.45.0.3/pure.bend as HttpPure
```

`sigv4.bend` imports HTTP models from `pure.bend` and live clocks from `http.bend`, plus `bend-kit-crypto@0.2.2.2`, `bend-kit-time@0.3.0.5/pure.bend`, and `bend-kit-collections@0.1.6.0`, whose `Order.string` sorts the canonical query. `Http.clock.now` supplies the pure timestamp used for signing. HMAC-SHA256 needs OpenSSL 3 (`BEND_LIBCRYPTO` on the crypto package).
The request judge comes from Hairpin's `pure.bend`.

`Credentials` holds the access key, secret, and session token. An empty token means a long-term key. `sign` returns the `Authorization` value. The date argument is `x-amz-date` form, `YYYYMMDDTHHMMSSZ`. `authorize` returns that header and the signed `x-amz-date`. `presign` builds a query-string signature with an expiry in seconds.

S3 path encoding is not the encoding used for other services. `new`, `put`, `get`, and `list` are the S3 client. `from_env` reads the usual AWS environment variables. `put` and `get` return the `Client` beside the result. `retry(c, n)` gives an idempotent request up to n more attempts through Hairpin's retry policy. `ErrNet` holds a `Hairpin.Err`.

`check.bend` signs the AWS suite vectors and checks S3 error and list response adapters. `smoke.bend` talks to a live bucket when the environment is set.

`pure.bend` builds canonical requests, signing strings, authorization headers, and presign queries without cryptographic or network effects. `xml.bend` parses XML, S3 error fields, and ListObjectsV2 pages. Its object constructor template lets the runtime keep its public `Object`, `Page`, and `Err` types without copying object lists.

`LAWS.bend` imports only these pure modules. The XML fixtures cover namespace prefixes, nested elements, attributes, entities, comments, CDATA, malformed input, error fields, and list pages. Run `bend sigv4/PROOF.bend --verdict` from the repository root to check every claim with the pure proof gate. The runtime delegates to the same definitions. Numeric references must contain digits and name an XML 1.0 character. Invalid references make the document fail. The parser still does not validate XML names, attribute syntax, or DTD internal subsets.
