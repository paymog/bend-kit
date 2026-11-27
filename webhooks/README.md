# Webhooks

Standard Webhooks signing and delivery, with verify-only support for Stripe and GitHub. The raw body must be verified **before** parsing JSON. Keep endpoint secrets out of source control, use a separate secret per endpoint, and retain seen event IDs in caller-owned storage to deduplicate retries. Only the symmetric HMAC `v1` format is supported; asymmetric `v1a` is not.

`webhooks.bend` imports `bend-kit-http@0.45.0.3`, `bend-kit-hairpin@0.19.0.3`, `bend-kit-retry@0.3.0.0`, and `bend-kit-crypto@0.2.2.2`. HMAC uses that crypto package, so OpenSSL 3 must load (`BEND_LIBCRYPTO`).

`pure.bend` contains header parsing, timestamp checks, and signature framing. It imports `bend-kit-time@0.3.0.5/pure.bend`. The laws use this module without HTTP, clock, or cryptographic effects. Verification and delivery use this same pure `Time.Instant`; obtain live timestamps with `Http.clock.now()`. HTTP request, response, and error types come from HTTP's `pure.bend`; network and clock effects come from `http.bend`.
Delivery verdicts and judges come from Hairpin's `pure.bend`. The client comes from `hairpin.bend`.


```bend
import bend-kit-webhooks@0.17.0.3/webhooks.bend as Webhooks
import bend-kit-hairpin@0.19.0.3/hairpin.bend as Hairpin
import bend-kit-hairpin@0.19.0.3/pure.bend as HairpinPure
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-http@0.45.0.3/http.bend as Http
import bend-kit-http@0.45.0.3/pure.bend as HttpPure
import bend-kit-time@0.3.0.5/pure.bend as Time

# send POSTs through Hairpin with three extra attempts on a timeout, a refused connect, 408, 429, or 5xx,
# and returns (updated client, result). send.with(n, ...) sets the extra attempts.
# Keep the same id when deliberately redelivering an event.
sent <- Webhooks.send(Hairpin.new(), endpoint, event_id, whsec_secret, raw_body)

# A caller with its own retry layer passes one Retry.Budget through every delivery of an operation:
# send.in(c, budget, ...) returns (client, budget left, result).
sent <- Webhooks.send.in(Hairpin.retry(client, 2), Retry.Budget.new(4n, now_ms, None{}), endpoint, event_id, whsec_secret, raw_body)

# Inside an HttpPure.Req -> IO(HttpPure.Res) handler:
# HttpPure.Req{method, path, +headers, body} = req
# now : Time.Instant <- Http.clock.now()
# (body, result) <- Webhooks.verify([whsec_secret], now, headers, body)
# Done{id} means the signature and five-minute window passed; deduplicate id.
```

`sign` returns the raw body and three lowercase HTTP headers (`webhook-id`, `webhook-timestamp`, `webhook-signature`). `verify.with(seconds, secrets, now, headers, body)` changes the default 300-second past-and-future window. Multiple `v1,` signatures separated by spaces and multiple candidate secrets support rotation. `stripe.verify` reads the comma-separated `Stripe-Signature` and signs `timestamp.body` using the **literal** Stripe `whsec_` secret. `github.verify` reads `X-Hub-Signature-256`, signs the body using the literal GitHub secret, and has no timestamp window because GitHub does not sign one. All comparisons use the constant-time crypto effect.

`send` returns `SendSign` for invalid ID/secret or crypto errors and `SendNet` with a `Hairpin.Err` for transport errors: `ErrHttp` when the last attempt failed, `ErrDenied` when the budget, deadline, or breaker admitted no attempt. A final non-2xx response remains an `HttpPure.Res` with its status. The retries are Hairpin's: bounded jittered backoff, `Retry-After`, the client's circuit breaker, and the shared budget. HTTP redirects are not followed so that the signed event and secret are not sent to another origin. `Hairpin.close` must be called on the returned client. Signatures are over the exact bytes sent; don't reserialize payloads in a receiver.

Run `bend PROOF.bend` and `bend check.bend` in this directory. `check.bend` also delivers to a local receiver that verifies every attempt: a 501 retried to a 200, then two deliveries on one budget of 3 (3 attempts, then none). `bench/README.md` describes the cross-language verification benchmark.
