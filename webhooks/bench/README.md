# Webhook verify benchmark

This times verifying one fixed Standard Webhooks message, 10,000 times, in Bend and in C, Rust, JavaScript (Bun and Node), and Python. Rust, JavaScript, and Python call the official `standardwebhooks` package for that language. C has no Standard Webhooks library, so `bench.c` writes the spec's verify over OpenSSL's `HMAC` and base64.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend` (2.0.35, the version CI pins), `clang` with OpenSSL 3 (`brew install openssl@3`; set `OPENSSL_PREFIX` if it is not `/opt/homebrew/opt/openssl@3`), `cargo`, `npm`, `bun`, `node`, and `uv`. On the first run, Cargo fetches `standardwebhooks`, `npm` installs `standardwebhooks` into `out/js`, and `uv` fetches `standardwebhooks`. Binaries go to `out/`, which git ignores. The runner exits non-zero if a build or a run fails, or if any run prints a checksum other than `10000 msg_p5jXN8AQM9LWM0D4loKWxJek`. It prints the tool versions and a results table.

## Input

The id, secret, and body of the Standard Webhooks spec's reference vector:

```
webhook-id: msg_p5jXN8AQM9LWM0D4loKWxJek
secret: whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw
body: {"test": 2432232314}
```

The libraries check `webhook-timestamp` against the real clock with a five-minute tolerance, and none lets you set the clock, so the spec's fixed timestamp (1614265330) would fail. Before each run, `run.py` signs this message at the current time with `hmac` and base64, and passes `WEBHOOK_TS` and `WEBHOOK_SIG` in the environment. Every variant uses those two values for `webhook-timestamp` and `webhook-signature`. At timestamp 1614265330, the signing produces the spec's `v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=`. C reads the clock with `time(NULL)`. Bend's `verify` takes the time as an argument, and the bench passes `WEBHOOK_TS`. The headers, body, and verifier are built once, and only the loop is timed. Every program prints the number of verifies that passed and the webhook-id. The Bend id comes from `verify`'s result. The other variants echo the header, because their verify returns nothing.

## The calls

| language | library | verify |
|---|---|---|
| Bend | `webhooks` | `Webhooks.verify(secrets, now, headers, body)` |
| C | OpenSSL 3 `libcrypto` | `HMAC(EVP_sha256(), ...)`, `EVP_EncodeBlock`, `CRYPTO_memcmp` |
| Rust | standardwebhooks 1.0.1 | `Webhook::new(secret)?.verify(body, &HeaderMap)` |
| JavaScript | standardwebhooks 1.1.1 | `new Webhook(secret).verify(body, headers, {jsonParse: false})` |
| Python | standardwebhooks 1.1.0 | `Webhook(secret).verify(body, headers, json_parse=False)` |

Bend takes the secrets on each call, so its `verify` decodes the secret every time. The libraries decode it once in the constructor, and C decodes it once before the loop.

## Results

M4 Pro, macOS 26.6.2, Bend 2.0.32, Apple clang 17.0.0, OpenSSL 3.6.4, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs on 10,000 verifications. All checksums: `10000 msg_p5jXN8AQM9LWM0D4loKWxJek`.

| variant | ms | µs/verify | vs fastest |
|---|---:|---:|---:|
| C / OpenSSL | 9.3 | 0.93 | 1.0× |
| Rust / standardwebhooks | 10.6 | 1.06 | 1.1× |
| Bun / standardwebhooks | 55.2 | 5.52 | 5.9× |
| Node / standardwebhooks | 39.0 | 3.90 | 4.2× |
| Python / standardwebhooks | 34.6 | 3.46 | 3.7× |
| Bend / webhooks | 15,649.6 | 1,564.96 | 1686.0× |

Bend verifies the raw body and decodes each supplied secret on every call; the other libraries use a verifier initialized before the timed loop. This measures the public verification API, not just OpenSSL's HMAC. It is not an apples-to-apples crypto throughput comparison.
