# Changelog

Older changes are in the git history. Each package's version is `<pkg>/VERSION`. On merge to `main`, CI publishes `bend-kit-<package>@<VERSION>` unless that version is already on the hub.

The kit is in alpha. A breaking change bumps the second number (`0.3.0.0` to `0.4.0.0`). Do not keep a compatibility shim.

When you change `<pkg>.bend` or `effs/`, raise `VERSION` and add a line here for that package.

## Unreleased

- `hairpin` 0.2.0.0: a proven retry policy in `retry.bend`: a shared attempt budget across nested layers (`Hairpin.request.in`), operation deadlines (`Hairpin.deadline`), bounded jittered backoff, and a circuit breaker (`Hairpin.circuit`). Breaking: results are `Result<Hairpin.Err, Http.Res>`, where `ErrDenied` says why no attempt started.
- `resources` 0.1.0.0: bounded capacity pools with affine reservations. Reserve, release, split, and combine, with proved conservation laws.
- `http` 0.31.1.0: admission keeps its connection, active, and buffered counts in `resources` pools. A give with no matching take stops the server instead of wrapping a counter.
- `protobuf` 0.1.0.0: bounded pure proto3 wire codec and a standard `protoc` plugin for typed Bend messages, with unknown fields and published Bytes/F64 types.
- `f64` 0.1.0.0: IEEE 754 binary64 add, subtract, multiply, and divide. Soft-float until Base has `F64`.
- Apache-2.0 license, contributor guide, security policy, and issue templates.
- Local HTTP smokes fail CI. A live fetch failure does not.
