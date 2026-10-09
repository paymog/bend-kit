# jwt

Compact JWS tokens. HS256, HS384, HS512, RS256, and ES256. Claim checks, and JWKS lookup over `hairpin`.

```bend
import bend-kit-jwt@0.3.0.0/jwt.bend as Jwt
import bend-kit-hairpin@0.3.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.32.0.0/http.bend as Http
```

`jwt.bend` imports that `http` and `bend-kit-crypto@0.2.0.0`, not `crypto@0.2.2.0`. JSON and bytes are the hashes in the entry file. Times in claims are Unix seconds as `U32`, through 2106.

`policy` pins one algorithm. `iss` and `aud` add the claims you require. `verify` rejects `alg` of `none` and any algorithm other than the pin. An HMAC secret must be at least as long as the digest. `sign` and `verify` are `IO` because the signature goes through libcrypto.

`verify.jwks` fetches or reuses a JWKS document through the `Hairpin.Client` and returns that client beside the result. `jwks.parse` reads a JWKS body you already have.

`check.bend` verifies the RFC 7515 A.1 HS256 vector at time `1300819000`.
