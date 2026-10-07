# oauth2

OAuth 2.0 client credentials, refresh, and authorization code with PKCE, over `hairpin`. RFC 6749 and RFC 7636.

```bend
import bend-kit-oauth2@0.1.0.0/oauth2.bend as OAuth
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
```

Import that `http` version. `oauth2.bend` does. `bend-kit-http@0.30.0.0` is a different `Http.Res`. It also imports `bend-kit-crypto@0.1.1.0` and `bend-kit-time@0.1.0.0`, plus the url, json, encoding, and bytes hashes named in the entry file.

`Config` is `Config{token, id, secret}`. `token` is the token endpoint URL. An empty `secret` is a public client: `client_id` goes in the body. A non-empty secret uses HTTP Basic.

Every call returns the `Hairpin.Client` beside the result. Pass that client on, and `Hairpin.close` it at the end.

`client_credentials`, `refresh`, and `code` return a `Token{access, kind, refresh, scope, expires}`. `fresh` refreshes when the token expires within `skew` seconds. `bearer` sets the `Authorization` header. `request` sends one bearer request and refreshes when the token is due.

`verifier` and `challenge` build the PKCE pair. `authorize.url` builds the authorization request. `callback` checks `state` and returns the code. A crypto failure is `ErrCrypto`. Secure random and SHA-256 come from the pinned `crypto`, which needs OpenSSL 3 (`BEND_LIBCRYPTO`).
