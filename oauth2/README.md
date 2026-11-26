# oauth2

OAuth 2.0 client credentials, refresh, and authorization code with PKCE, over `hairpin`. RFC 6749 and RFC 7636.

```bend
import bend-kit-oauth2@0.17.0.0/oauth2.bend as OAuth
import bend-kit-hairpin@0.19.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.45.0.0/http.bend as Http
import bend-kit-http@0.45.0.0/pure.bend as HttpPure
import bend-kit-time@0.3.0.3/pure.bend as Time
```

Import that HTTP version. `oauth2.bend` uses `HttpPure.Res` from its `pure.bend` model module and `Http.clock.now` from its runtime module. It also imports `bend-kit-crypto@0.2.2.2` and `bend-kit-time@0.3.0.3/pure.bend`, plus the named url, json, encoding, and bytes packages in the entry file.

`Config` is `Config{token, id, secret}`. `token` is the token endpoint URL. An empty `secret` is a public client: `client_id` goes in the body. A non-empty secret uses HTTP Basic.

Every call returns the `Hairpin.Client` beside the result. Pass that client on, and `Hairpin.close` it at the end.

`client_credentials`, `refresh`, and `code` return a `Token{access, kind, refresh, scope, expires}`. `fresh` refreshes when the token expires within `skew` seconds. `bearer` sets the `Authorization` header. `request` sends one bearer request and refreshes when the token is due.

`verifier` and `challenge` build the PKCE pair. `authorize.url` builds the authorization request. `callback` checks `state` and returns the code. A crypto failure is `ErrCrypto`. Secure random and SHA-256 come from the pinned `crypto`, which needs OpenSSL 3 (`BEND_LIBCRYPTO`).

`pure.bend` contains the forms, token codecs, expiry checks, authorization URLs, and callback state checks. It imports `bend-kit-time@0.3.0.3/pure.bend` and has no foreign effects. `LAWS.bend` imports this module; its claims are unchanged. The runtime entry keeps its OAuth domain-model types. Token expiry and clock arguments use the same pure `Time.Instant` values directly.
