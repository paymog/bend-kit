# Changelog

Older changes are in the git history. Each package's version is `<pkg>/VERSION`. On merge to `main`, CI publishes `bend-kit-<package>@<VERSION>` unless that version is already on the hub.

The kit is in alpha. A breaking change bumps the second number (`0.3.0.0` to `0.4.0.0`). Do not keep a compatibility shim.

When you change `<pkg>.bend` or `effs/`, raise `VERSION` and add a line here for that package.

## Unreleased

- `hairpin` 0.2.1.0: `Hairpin.request.as` takes the retry judge, the idempotency, and the `Accept-Encoding` value from the caller, so an API with its own retry rules keeps the shared budget, deadline, backoff, and breaker. `Hairpin.budget(c)` gives the budget of one plain request.
- `hairpin` 0.2.0.0: a proven retry policy in `retry.bend`: a shared attempt budget across nested layers (`Hairpin.request.in`), operation deadlines (`Hairpin.deadline`), bounded jittered backoff, and a circuit breaker (`Hairpin.circuit`). Breaking: results are `Result<Hairpin.Err, Http.Res>`, where `ErrDenied` says why no attempt started.
- `resources` 0.1.0.0: bounded capacity pools with affine reservations. Reserve, release, split, and combine, with proved conservation laws.
- `http` 0.31.1.1: admission imports `bend-kit-resources@0.1.0.0` from the hub, not a bundled copy.
- `http` 0.31.1.0: admission keeps its connection, active, and buffered counts in `resources` pools. A give with no matching take stops the server instead of wrapping a counter.
- `websocket` 0.2.0.0: frame decoding is `next`, proved on a list model: read boundaries do not change frames, rest, or faults, decoded frames and faults stay fixed, every frame consumes input, payloads obey max, and pending input is bounded. `parse` takes a `Bytes.Cursor` and `push` appends reads, so a frame no longer copies the rest of its read; `Conn.input` is a `Bytes.Cursor`. A 64-bit length of 2^32 or more is rejected even with the largest max.
- `crypto` 0.2.2.1, `dns` 0.6.0.1, `files` 0.1.1.1, `random` 0.1.0.1, `sqlite` 0.1.0.1, `tty` 0.1.0.1, `wire` 0.4.6.1, `zlib` 0.2.0.1, and `time` 0.1.2.1: register C effects with the two-argument `io_eff` of Bend 2.0.36, so native builds that use these packages compile.
- `process` 0.2.0.1: register C effects with the two-argument `io_eff` of Bend 2.0.36 and name them with `CID(...)`. Before, `wait` registered under the runtime's own `CID_WAIT`, so a native `wait` call failed with "an alien request".
- `protobuf` 0.1.0.0: bounded pure proto3 wire codec and a standard `protoc` plugin for typed Bend messages, with unknown fields and published Bytes/F64 types.
- `f64` 0.1.0.0: IEEE 754 binary64 add, subtract, multiply, and divide. Soft-float until Base has `F64`.
- Apache-2.0 license, contributor guide, security policy, and issue templates.
- Local HTTP smokes fail CI. A live fetch failure does not.
