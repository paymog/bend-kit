# Webhooks

Standard Webhooks signing and delivery, with verify-only support for Stripe and GitHub. The raw body must be verified **before** parsing JSON. Keep endpoint secrets out of source control, use a separate secret per endpoint, and retain seen event IDs in caller-owned storage to deduplicate retries. Only the symmetric HMAC `v1` format is supported; asymmetric `v1a` is not.

```bend
import bend-kit-webhooks@0.1.0.0/webhooks.bend as Webhooks
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin

# send uses Hairpin for POST, retries timeouts and 5xx with three extra attempts,
# and returns (updated client, result). send.with(n, ...) sets the retry count.
# Keep the same id when deliberately redelivering an event.
sent <- Webhooks.send(Hairpin.new(), endpoint, event_id, whsec_secret, raw_body)

# Inside an Http.Req -> IO(Http.Res) handler:
# Http.Req{method, path, +headers, body} = req
# now : Time.Instant <- Time.now()
# (body, result) <- Webhooks.verify([whsec_secret], now, headers, body)
# Done{id} means the signature and five-minute window passed; deduplicate id.
```

`sign` returns the raw body and three lowercase HTTP headers (`webhook-id`, `webhook-timestamp`, `webhook-signature`). `verify.with(seconds, secrets, now, headers, body)` changes the default 300-second past-and-future window. Multiple `v1,` signatures separated by spaces and multiple candidate secrets support rotation. `stripe.verify` reads the comma-separated `Stripe-Signature` and signs `timestamp.body` using the **literal** Stripe `whsec_` secret. `github.verify` reads `X-Hub-Signature-256`, signs the body using the literal GitHub secret, and has no timestamp window because GitHub does not sign one. All comparisons use the constant-time crypto effect.

`send` returns `SendSign` for invalid ID/secret or crypto errors and `SendNet` for transport errors. A final non-2xx response remains an `Http.Res` with its status. HTTP redirects are not followed so that the signed event and secret are not sent to another origin. `Hairpin.close` must be called on the returned client. Signatures are over the exact bytes sent; don't reserialize payloads in a receiver.

Run `bend PROOF.bend`, `bend check.bend`, and `bend smoke.bend` in this directory. `bench/README.md` describes the cross-language verification benchmark.
