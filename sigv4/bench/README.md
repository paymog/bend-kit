# SigV4 signing benchmark

This times signing one fixed S3 request with AWS Signature Version 4, 10,000 times, in Bend and in C, Rust, JavaScript (Bun and Node), and Python. Each non-Bend variant calls the signer the AWS SDK for that language uses. No request is sent.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend` (2.0.32, the version CI pins), `clang` with aws-c-auth (`brew install aws-c-auth`; set `AWS_CRT_PREFIX` if it is not under `/opt/homebrew`), `cargo`, `npm`, `bun`, `node`, and `uv`. On the first run, Cargo fetches `aws-sigv4`, `npm` installs the smithy signer into `out/js`, and `uv` fetches `botocore`. Binaries go to `out/`, which git ignores. `rs/Cargo.toml` sets `rust-version = "1.91"` with resolver 3, so Cargo picks aws crate versions that build on that rustc. The runner exits non-zero if a build or a run fails, or if the signatures differ.

## Input

```
PUT https://examplebucket.s3.amazonaws.com/test.txt?x-id=PutObject
body: Welcome to Amazon S3.
access key AKIAIOSFODNN7EXAMPLE, secret wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY, no session token
date 20130524T000000Z, region us-east-1, service s3
```

Every variant signs with S3's settings: `SignedHeaders=host;x-amz-content-sha256;x-amz-date`, the payload's SHA-256 in `x-amz-content-sha256`, the path encoded once, and no dot-segment normalization. The clock is pinned to the date above. Each iteration builds a fresh request and signs it; only the loop is timed. Every program prints the hex signature of the last iteration. `run.py` signs the same request itself from the SigV4 spec with `hashlib` and `hmac`, and every run of every variant must print that signature: `a2ca22c4a94c6c44b315a8f64267b6342256bd0e2f2b08889110503e9bc9e039`. The Bend program exits non-zero if `authorize` fails.

## The calls

| language | library | sign |
|---|---|---|
| Bend | `sigv4` | `Sigv4.authorize(creds, region, service, date, method, path, query, host, payload)` |
| C | aws-c-auth 1.0.0 (AWS Common Runtime) | `aws_sign_request_aws` on an `aws_signable_new_http_request`, `AWS_SBHT_X_AMZ_CONTENT_SHA256` |
| Rust | aws-sigv4 1.4.1 (aws-credential-types 1.2.13, aws-smithy-runtime-api 1.11.5) | `aws_sigv4::http_request::sign` with `PayloadChecksumKind::XAmzSha256`, `PercentEncodingMode::Single` |
| JavaScript | @aws-sdk/signature-v4-multi-region 3.996.47, the signer @aws-sdk/client-s3 3.1141.0 uses (over @smithy/signature-v4 5.7.4), with @smithy/hash-node 4.5.2 and @smithy/protocol-http 5.6.2 | `new SignatureV4MultiRegion({uriEscapePath: false, applyChecksum: true}).sign(new HttpRequest(...), {signingDate})` |
| Python | botocore 1.42.55 | `S3SigV4Auth.add_auth(AWSRequest(...))`, with `botocore.auth.get_current_datetime` pinned |

`SignatureV4MultiRegion` hands a SigV4 region to @smithy/signature-v4, which caches the derived signing key per date, region, service, and credentials, so after the first iteration it skips four HMACs; the others derive the key on every sign. aws-c-auth signs synchronously when the config carries credentials rather than a provider, so its callback runs before `aws_sign_request_aws` returns.

## Results

M4 Pro, macOS 26.6.2, 2026-09-28. `python3 run.py 5`, median of five runs, 10,000 signatures per run. Times in ms; multiples relative to C.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| sign | 57.4 (1.0x) | 77.0 (1.3x) | 86.0 (1.5x) | 125.6 (2.2x) | 320.1 (5.6x) | 379.4 (6.6x) |
