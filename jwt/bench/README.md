# JWT benchmark

This times verifying one fixed HS256 token and one fixed RS256 token, 10,000 times each, in Bend, C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, a C compiler, `pkg-config`, libjwt 3 (`brew install libjwt`, or your distro's `libjwt` 3.x dev package), `cargo`, `bun`, `node`, `uv`, and OpenSSL 3 for Bend's crypto effects. `run.py` reads libjwt's flags from `pkg-config libjwt`; set `PKG_CONFIG_PATH` for another install. Cargo fetches `jsonwebtoken`, `bun install --frozen-lockfile` fetches `jose` into `node_modules/` (git ignores it), and `uv` fetches PyJWT on the first run. Binaries go to `out/`, which git ignores. The run exits non-zero if a build fails, if a program fails to verify, or if two languages print different checksums.

## Input

Both tokens carry the same claims, `{"sub":"bend-kit","name":"Bench User","admin":true,"iat":1700000000,"exp":4102444800}`, under the header `{"alg":"HS256","typ":"JWT"}` or `{"alg":"RS256","typ":"JWT"}`. The tokens, the HMAC secret, and the RSA public key are string constants in each program; nothing is signed at run time.

- **hs256**: secret `bend-kit-jwt-bench-hs256-secret-0123456789` (42 octets).
- **rs256**: a 2048-bit RSA key, public exponent 65537, given as an SPKI `PUBLIC KEY` PEM. The private key was thrown away after it signed the token.

`exp` is 2100-01-01, so every library's default expiry check passes without a clock override. Each timed op is one verify call per iteration: split, base64url-decode, check the signature, parse the claims, check `exp`, and read `iat`:

| variant | call | key setup before the timer |
|---|---|---|
| Bend | `Jwt.verify(Jwt.policy(alg), key, token, 1700000000)` | none: `Key` is not copyable, so each call builds `Jwt.Hmac` or `Jwt.Pem` from the fixed text, and the RS256 path parses the PEM in OpenSSL each call |
| C | libjwt `jwt_checker_verify`, `iat` read with `jwt_claim_get` | `jwks_create_fromkey` (PEM, or raw HMAC octets), `jwt_checker_setkey` |
| Rust | `jsonwebtoken::decode::<Claims>` with `Validation::new(alg)` | `DecodingKey::from_secret`, `DecodingKey::from_rsa_pem` |
| Bun, Node | jose `jwtVerify(token, key, { algorithms: [alg] })` | `importSPKI` |
| Python | PyJWT `jwt.decode(token, key, algorithms=[alg])` | `load_pem_public_key` from `cryptography` |

Each program prints, per op, the u32 sum of the verified `iat` claims. A failed verify stops C, Rust, JavaScript, and Python, and adds 0 in Bend, so a wrong result changes the checksum. Expected for both ops: **519442432** (1,700,000,000 × 10,000 mod 2^32).

## Results

Apple arm64, three runs per variant (median), 10,000 verifies per algorithm; checksum **519442432** for each.

| variant | hs256 ms | µs/verify | vs fastest | rs256 ms | µs/verify | vs fastest |
|---:|---:|---:|---:|---:|---:|---:|
| C | 29.2 | 2.92 | 1.9x | 119.9 | 11.99 | 1.0x |
| Rust | 15.7 | 1.57 | 1.0x | 888.4 | 88.84 | 7.4x |
| Bun | 151.0 | 15.10 | 9.6x | 201.5 | 20.15 | 1.7x |
| Node | 206.2 | 20.62 | 13.1x | 273.7 | 27.37 | 2.3x |
| Python | 185.6 | 18.56 | 11.8x | 445.0 | 44.50 | 3.7x |
| Bend | 241.0 | 24.10 | 15.3x | 777.8 | 77.78 | 6.5x |

## Caveats

- Rust uses `jsonwebtoken`'s `rust_crypto` backend: RSA from the pure-Rust `rsa` crate, HMAC from `hmac`/`sha2`. C (libjwt), Bun, Node, Python (`cryptography`), and Bend all verify through OpenSSL or BoringSSL-class native code, so Rust's rs256 is slower for that reason, not because of its JWT layer.
- Bend rebuilds and re-parses its key every call; the others parse the key once.
- jose is async; each verify is awaited in turn.

Versions: libjwt 3.6.1 (jansson 2.15.1, OpenSSL 4.0.2), Apple clang 17.0.0, Rust 1.91.0 (`jsonwebtoken` 10.4.0, `rsa` 0.9.10), jose 6.2.12 on Bun 1.3.14 and Node 24.0.1, Python 3.14.6 (PyJWT 2.15.1, `cryptography` 50.0.1), Bend 2.0.32.
