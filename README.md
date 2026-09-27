# bend-kit

A general-purpose library for Bend 2. Each package is proved against its own laws and published to the Bend hub on its own. Networking came first, so `http` and its dependencies are the most complete today. [ROADMAP.md](ROADMAP.md) lists what comes next.

This project was called bend-net. Its old hub names, `bend-net-*`, still resolve but get no new versions.

## Install

You need [Bend 2.0.27 or newer](https://bend-lang.com/install.sh) and [Bun 1.4.2](https://bun.sh/docs/installation). macOS or Linux, including WSL. Windows is not supported.

Import a package at the top of your file. `bend` fetches it from the hub and checks it against its hash:

```bend
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

A name and its hash import the same package. Each version is a distinct type: `http` and `process` still import `bytes@0.2.0.0` (`0xbf22530d1ea11c951d1ecaa353ed1580`), so import that hash to pass a `Bytes.Bytes` to them.

## Packages

| Package | Import | What it does |
|---|---|---|
| [`bytes`](bytes) | `0x49814d83de8f70993a43e1002be29ecd/bytes.bend` | Byte buffers packed four bytes to a `U32`, with bounds-checked access, endian integers, search, hex, and base64. |
| [`encoding`](encoding) | `0xaec630f7a2f6b6ef96750f95d6e4195b/encoding.bend` | UTF-8 and hex encoding for byte strings. |
| [`json`](json) | `0xaaa10a97bf5ac6990143da2c863f8a3f/json.bend` | JSON values, parsed and encoded as RFC 8259. |
| [`zlib`](zlib) | `0xe01785b64266bf3ba0068183b9f9f5e3/zlib.bend` | DEFLATE, gzip, and zlib encoding and decoding (RFC 1951, 1952, 1950). |
| [`url`](url) | `0xd248560355ba8929ae030bc9c72f40be/url.bend` | URL parsing, resolution, and percent-encoding (RFC 3986). |
| [`wire`](wire) | `0x8a1034c8824c5fdecbaa2e3d762aadad/wire.bend` | Byte-exact TCP, UDP, and TLS sockets. |
| [`dns`](dns) | `0xa12defba527c5f86a84d6fb74968f8ef/dns.bend` | DNS A-record lookup over UDP. |
| [`http`](http) | `0x310b0480ce5b511ff8da9704b3d27ef3/http.bend` | HTTP/1.1 client and server for http and https, with DNS and TLS. See [http/README.md](http/README.md). |
| [`router`](router) | `0xf2239decc78af956c471ebf7f2f50374/router.bend` | Match an HTTP method and path to a handler. |
| [`files`](files) | `./files/files.bend` (local; not yet published) | POSIX path operations, directory listing, metadata, mkdir, remove, rename, and private temp directories. |
| [`collections`](collections) | `./collections/collections.bend` (local; not yet published) | An ordered map and set keyed by any `Data` type, a growable vector, a deque, and a priority queue. Import the file you need: `omap.bend`, `vec.bend`, `deque.bend`, or `heap.bend`. |
| [`unicode`](unicode) | `./unicode/unicode.bend` (local; not yet published) | Unicode 17.0 general category, NFC/NFD, full case folding, and grapheme clusters. See [unicode/README.md](unicode/README.md). |
| [`regex`](regex) | `./regex/regex.bend` (local; not yet published) | Linear-time regular expressions: RE2 syntax, capture groups, and Unicode categories. See [regex/README.md](regex/README.md). |
| [`parse`](parse) | `./parse/parse.bend` (local; not yet published) | Parser combinators over text, with positioned errors: sequence, choice, `many`, `sep_by`, `opt`, and `rec` for nested grammars. `parse/json.bend` is a JSON grammar on it. |

The hub versions are `bytes@0.3.0.0`, `encoding@0.2.1.0`, `json@0.3.0.0`, `zlib@0.1.0.0`, `url@0.4.0.0`, `wire@0.4.0.0`, `dns@0.3.1.0`, `http@0.14.0.0`, and `router@0.1.1.0`, each named `bend-kit-<package>`.

`wire`, `http`, and `files` ship `.c` and `.js` effects. They run host code, and proofs do not cover them.

The unpublished [`process`](process) package runs commands without a shell, captures
byte-exact stdin/stdout/stderr and exit status, and exposes streaming pipes and
process-level OS effects. Import `./process/process.bend` locally; its `env`
entries are `KEY=VALUE` overrides of the inherited environment. Close the
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
