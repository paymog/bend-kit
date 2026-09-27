# bend-kit

A general-purpose library for Bend 2. Each package is proved against its own laws and published to the Bend hub on its own. Networking came first, so `http` and its dependencies are the most complete today. [ROADMAP.md](ROADMAP.md) lists what comes next.

This project was called bend-net. Its old hub names, `bend-net-*`, still resolve but get no new versions.

## Install

You need [Bend 2.0.27 or newer](https://bend-lang.com/install.sh) and [Bun 1.4.2](https://bun.sh/docs/installation). macOS or Linux, including WSL. Windows is not supported.

Import a package at the top of your file. `bend` fetches it from the hub and checks it against its hash:

```bend
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

A name and its hash import the same package. Each version is a distinct type: `process` still imports `bytes@0.2.0.0` (`0xbf22530d1ea11c951d1ecaa353ed1580`), so import that hash to pass a `Bytes.Bytes` to it.

## Packages

| Package | Import | What it does |
|---|---|---|
| [`bytes`](bytes) | `0x49814d83de8f70993a43e1002be29ecd/bytes.bend` | Byte buffers packed four bytes to a `U32`, with bounds-checked access, endian integers, search, hex, and base64. |
| [`encoding`](encoding) | `0xcfc8be7b076f41f95c8e118383892d55/encoding.bend` | UTF-8 and hex encoding for byte strings. |
| [`json`](json) | `0xc0344463a222d4d3057e74f8fc810bc0/json.bend` | JSON values, parsed and encoded as RFC 8259. |
| [`zlib`](zlib) | `0x9d101c075b333e2b07242347f7c35b1c/zlib.bend` | DEFLATE, gzip, and zlib encoding and decoding (RFC 1951, 1952, 1950). |
| [`url`](url) | `0xd248560355ba8929ae030bc9c72f40be/url.bend` | URL parsing, resolution, and percent-encoding (RFC 3986). |
| [`wire`](wire) | `0x096635686408886b7d907f16c4550317/wire.bend` | Byte-exact TCP, UDP, and TLS sockets. |
| [`dns`](dns) | `0xc10a5eaaa9c896e1570e279945f4241e/dns.bend` | DNS A-record lookup over UDP. |
| [`http`](http) | `0xe2e828b46585a523091ea59e50bff494/http.bend` | HTTP/1.1 client and server for http and https, with DNS and TLS. See [http/README.md](http/README.md). |
| [`router`](router) | `0xf2239decc78af956c471ebf7f2f50374/router.bend` | Match an HTTP method and path to a handler. |
| [`files`](files) | `0x902b9f92801b87d6be0bcd03919d01bb/files.bend` | POSIX path operations, directory listing, metadata, mkdir, remove, rename, and private temp directories. |
| [`process`](process) | `0xb9c171843853f26eb0a0cfd88782e4d3/process.bend` | Run commands without a shell, with byte-exact stdin, stdout, and stderr, exit status, streaming pipes, and signals. |
| [`collections`](collections) | `0x620317aa272e53852c5b5baae68a727b/collections.bend` | An ordered map and set keyed by any `Data` type, a growable vector, a deque, and a priority queue. Import the file you need: `omap.bend`, `vec.bend`, `deque.bend`, or `heap.bend`. |
| [`unicode`](unicode) | `0x6c784a08486e2e02415e89c5249e9e8a/unicode.bend` | Unicode 17.0 general category, NFC/NFD, full case folding, and grapheme clusters. See [unicode/README.md](unicode/README.md). |
| [`regex`](regex) | `0x6fa820747435b3188e7e4f3d1ffc0325/regex.bend` | Linear-time regular expressions: RE2 syntax, capture groups, and Unicode categories. See [regex/README.md](regex/README.md). |
| [`parse`](parse) | `0x154e0a68ef9a0223bacaacefc589cad8/parse.bend` | Parser combinators over text, with positioned errors: sequence, choice, `many`, `sep_by`, `opt`, and `rec` for nested grammars. `parse/json.bend` is a JSON grammar on it. |
| [`int`](int) | `0x0c38aaf55cb892078ec5d3c0609798a9/int.bend` | Fixed-width `U8`, `U16`, `U64`, `I32`, and `I64`, with wrapping, checked, and saturating arithmetic, and conversions to `U32` and `Nat`. `U8`, `U16`, and `I32` run at native speed on Base's `U32`. `U64` and `I64` use `Word(64n)` and are slow. |
| [`hash`](hash) | `bend-kit-hash@0.1.0.0/hash.bend` | Non-cryptographic hashes over `Bytes`: FNV-1a (32 and 64), xxHash (32 and 64), SipHash-1-3, CRC-32, and Adler-32. 64-bit results are `Hash.W64{hi, lo}`. |

Each package is named `bend-kit-<package>` on the hub. The hub versions are `bytes@0.3.0.0`, `encoding@0.3.0.0`, `json@0.4.0.0`, `zlib@0.1.3.0`, `url@0.4.0.0`, `wire@0.4.0.3`, `dns@0.3.2.1`, `http@0.15.0.5`, `router@0.1.1.0`, `files@0.1.0.0`, `process@0.1.0.1`, `collections@0.1.0.0`, `unicode@0.1.0.0`, `regex@0.6.0.0`, `parse@0.1.0.0`, `int@0.1.0.0`, and `hash@0.1.0.0`.

`wire`, `http`, `files`, and `process` ship `.c` and `.js` effects. They run host code, and proofs do not cover them.

In `process`, `env` entries are `KEY=VALUE` overrides of the inherited environment. Close the
spawned child's stdin to send EOF, drain stdout and stderr, then call `wait`.
Its C and JS effects require macOS or Linux and are not covered by the proofs.
On the JS target, `run` blocks other Bend fibers until the child exits; use
`spawn` and pipe handles when the program must remain responsive. JS signal
polling uses Bun's built-in FFI C compiler to install a signal-safe handler.

## Layout

Each package is one folder at the root. The folder name is the package name:

```
<package>/
  <package>.bend   entry file; its first comment line is the hub description
  VERSION          the hub version; CI publishes it on merge
  LAWS.bend        the claims
  PROOF.bend       a proof of each claim
  check.bend       runs the package on the native runtime (optional)
  effs/            .c and .js effects (optional)
  bench/           benchmarks (optional)
```

`http` also has `smoke.bend`, which does live fetches, and `demo.bend`, a small server for the serve smoke test.

## Checks

```sh
scripts/check.sh              # every package
scripts/check.sh bytes http   # some packages
scripts/packages.sh origin/main   # the packages changed since origin/main
```

`check.sh` type-checks the entry file, then runs `PROOF.bend` and `check.bend` in the package folder. `bend PROOF.bend` prints "All terms check." when every law holds.

CI runs `check.sh` once for each package that a pull request changes. A change to `.github/` or `scripts/` checks every package, and so does each push to `main`. The `http` smoke tests run only when `http` changes.

On each push to `main`, a package that passes its checks runs `scripts/publish.sh`. It publishes the package as `bend-kit-<package>@<VERSION>` unless that version is already on the hub. If the hub has that version with different files, the job fails, and the package needs a higher `VERSION`. Pull requests run `scripts/publish.sh --check`, which reports the same failure and publishes nothing.
