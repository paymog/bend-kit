# Webhook signatures

The sender signs the exact octets it transmits. A receiver verifies the raw request body before parsing it. Standard Webhooks signs `id.timestamp.body` with an HMAC-SHA256 key decoded from a `whsec_` base64 secret. Stripe signs `timestamp.body` with the literal endpoint secret. GitHub signs the raw body with its literal webhook secret. Signatures are compared with `Crypto.eq.ct.words`, not with string equality.

The verifier rejects missing metadata, malformed signatures, and timestamps more than 300 seconds before or after the receiver's clock. Callers can set another tolerance explicitly. A valid Standard Webhooks delivery returns its signed event ID; the receiver must store seen IDs if it needs replay deduplication. GitHub does not sign a timestamp, so its verifier cannot enforce a replay window. Store secrets outside the repository, and use distinct secrets for distinct endpoints.

`LAWS.bend` proves the pure message framing and freshness decisions. HMAC, constant-time comparison, wall time, HTTP delivery, and cryptographic effects are trust assumptions: Bend cannot prove foreign code. `check.bend` exercises actual signing and verification against the official Standard Webhooks and GitHub vectors, tampering, and timestamp boundaries. The local HTTP smoke test exercises delivery to a live verifying handler.
