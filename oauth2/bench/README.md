# OAuth2 benchmark

This times the two per-request pieces of `oauth2` that run in the client: the PKCE S256 challenge, and parsing a token endpoint's reply. It runs in Bend, C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `cargo`, `bun`, `node`, `python3`, and OpenSSL 3. `run.py` builds C against `/opt/homebrew/opt/openssl@3`; set `OPENSSL_PREFIX` for another install. The binaries go to `out/`, which git ignores. It exits non-zero if a build fails or if two languages print different checksums.

## Input

**pkce**: **N = 10,000** chained S256 challenges, starting from the RFC 7636 Appendix B verifier: v(i+1) = BASE64URL(SHA256(v(i))). Each challenge is 43 base64url chars, so it is a valid verifier for the next step, and no language can skip one.

**parse**: **N = 10,000** parses of one token response: a 1,024-char `access_token`, `token_type`, `expires_in` 3600, a `refresh_token`, and a `scope`, about 1.1 KB.

- **Bend**: `O.challenge` (`Crypto.sha256.words` into libcrypto, then `O.b64url`) and `O.parse`, which is `Json.parse.bytes` plus the token fields.
- **C**: `EVP_Digest` and `EVP_EncodeBlock` in OpenSSL 3 libcrypto. C has no standard JSON parser, so C has no parse time.
- **Rust**: `Sha256::digest` from `sha2`, `URL_SAFE_NO_PAD` from `base64`, and `serde_json::from_slice` into a `Value`.
- **Bun and Node**: `createHash("sha256").digest("base64url")` from `node:crypto`, and `JSON.parse` of the decoded body.
- **Python**: `hashlib.sha256`, `base64.urlsafe_b64encode`, and `json.loads`.

Each program prints the last challenge, and for parse the good count and the last token's access length, refresh token, scope, and expires_in. Expected:

- pkce: **_h0O-eTcY3lh5-2H0DW4YNyqEBxw5lDnuJd-sByYD68**
- parse: **10000 1024 tGzv3JOkF0XG5Qx2TlKWIA openid profile email 3600**

## Results

M4 Pro, macOS, arm64, 2026-09-28. Median of three runs (`python3 run.py`). Times are in ms.

| variant | pkce ms | per s | vs fastest | parse ms | per s | vs fastest |
|---:|---:|---:|---:|---:|---:|---:|
| C | 4.2 | 2,403,846 | 1.9x | — | — | — |
| Rust | 2.2 | 4,494,382 | 1.0x | 6.5 | 1,527,417 | 1.3x |
| Bun | 4.0 | 2,495,633 | 1.8x | 5.1 | 1,945,147 | 1.0x |
| Node | 6.1 | 1,635,590 | 2.7x | 6.8 | 1,469,076 | 1.3x |
| Python | 4.3 | 2,318,034 | 1.9x | 17.9 | 560,099 | 3.5x |
| Bend | 13.3 | 752,375 | 6.0x | 273.3 | 36,591 | 53.2x |

Bend's pkce time is one libcrypto call per challenge plus base64url over a 44-char `String`. Its parse time is pure-Bend JSON over `Bytes` and the token fields as `String`s: 28 µs per reply, far below one network round trip to a token endpoint.

Versions: Bend 2.0.32, Apple clang, Rust (`sha2` 0.10, `base64` 0.22, `serde_json` 1), Bun, Node 24.0.1, Python 3.
