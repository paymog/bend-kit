# jwt

Compact JWS tokens. HS256, HS384, HS512, RS256, and ES256. Claim checks, and JWKS lookup over `hairpin`.

```bend
import bend-kit-jwt@0.17.0.3/jwt.bend as Jwt
import bend-kit-hairpin@0.19.0.3/hairpin.bend as Hairpin
import bend-kit-http@0.45.0.3/pure.bend as HttpPure
```

`jwt.bend` imports that HTTP model module and `bend-kit-crypto@0.2.2.2`. JWKS response boundaries use `HttpPure.Res`. JSON and bytes use the named versions in the entry file. Times in claims are Unix seconds as `U32`, through 2106.

`policy` pins one algorithm. `iss` and `aud` add the claims you require. `verify` rejects `alg` of `none` and any algorithm other than the pin. An HMAC secret must be at least as long as the digest. `sign` and `verify` are `IO` because the signature goes through libcrypto.

A header, claims object, or JWK that repeats a member name at any depth is rejected: `verify` fails with `Malformed`, `sign` with `BadClaim`, and `jwks.parse` skips that key. Names compare after JSON escapes are decoded.

`verify.jwks` fetches or reuses a JWKS document through the `Hairpin.Client` and returns that client beside the result. `jwks.parse` reads a JWKS body you already have.

`check.bend` verifies the RFC 7515 A.1 HS256 vector at time `1300819000`.

`pure.bend` holds the shared encoding, parsing, claim checks, and JWKS key selection. The existing laws import this module so the proof gate has no foreign effects. `jwt.bend` preserves the runtime API and maps its public types at the boundary.
