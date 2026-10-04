# Camber

Status: staged release behavior contract. Published Camber0.5.0.0 delivers registration/direct dispatch, scoped policies, mapping, response helpers/validation, strict inputs, public shared-transport serving and affine completion-owner lifecycle through published HTTP0.30.0.0. Local breaking Camber0.6.0.0 delivers #337 entered-policy completion notifications, monotonic durations and optional safe access logging; automatic CI publication follows merge. Remaining integrated application, external-supervision and final benchmark work is not delivered by this release. "Must", "must not", and "may" state requirements; pure laws do not attest host IO.

Camber is a small HTTP framework for Bend 2 JSON APIs and services. It combines typed inputs, returned responses, scoped hooks, and explicit ownership. It builds on bend-kit-http rather than implementing another server. Framework influences and their limitations are recorded separately in local research notes, outside this release contract.

Most or all consumers are expected to be AI agents. Correctness and performance take priority over concise authoring. Explicit types, quantities, and ownership transfers are acceptable even when verbose. The interface should minimize duplicate decisions and hidden ordering rules, not line count. Framework code owns routing and lifecycle protocols; application authors supply explicit policies, decoders, handlers, and resource state.

## Scope

The initial release includes method/path routing, named parameters, route groups, typed request context, explicit body decoding, response helpers, response validation, error mapping, optional access logging, in-process dispatch, and safe HTTP/1.1 server operation.

Outside the initial release:

- templates, static files, sessions, CORS helpers, multipart integration, schema languages, OpenAPI, generated clients, plugin registries, WebSocket upgrades, and HTTP/2 serving;
- routed streaming and SSE (existing low-level streaming remains available through `http`);
- rejecting a request before transport buffers its body, including withholding `100 Continue`. Until then, uploads up to the body cap arrive before any hook runs;
- client addresses and interpretation of `Forwarded` or `X-Forwarded-*` headers (R1.4);
- per-group error mappers;
- embedded-server lifecycle isolation: stopping one server while unrelated work continues in the same Bend process;
- preemptive cancellation of arbitrary handler computations or blocking effects.

TLS termination may be handled by a reverse proxy; see the deployment note under R3.

Live serving targets a dedicated server process managed by an external supervisor. The supervisor owns the final termination deadline if graceful shutdown cannot progress. Camber does not implement a supervisor or promise to preserve other work inside that process. Direct dispatch remains available for application checks; it does not imply an embedded-server lifecycle guarantee.

Exact exported names and generic type signatures are not fixed here. A compiled Bend example must demonstrate ownership and composition before those signatures become public (R2.7). This is a behavior spec, not an implementation plan.

## R1. Application and transport

- **R1.1 Transport seam.** Camber must use the existing `Http.Req`, `Http.Res`, and packed `Http.Body` types at its transport seam. A plain handler of type `Http.Req -> IO(Http.Res)` must be usable as a route without converting its body through `String`. Camber may add typed application context around that seam.
- **R1.2 One dispatch path.** Live serving and direct dispatch must use the same target parsing, routing, hooks, decoding, response validation, and error mapping. Direct dispatch returns the response Camber would hand to transport, without binding a port. It does not add framing headers, suppress HEAD/204/304 bodies, or simulate socket writes, disconnects, or transport completion; body suppression is checked over a real socket.
- **R1.3 Transport ownership.** `http` and `wire` own framing, keep-alive, pipelining, socket IO, limits, deadlines, admission, and server lifecycle. Camber configures them and must not maintain a second implementation. What Camber needs from them is listed under [Transport requirements](#transport-requirements); changes belong in those packages.
- **R1.4 No client address.** `Http.Req` carries no peer address, and `wire` does not expose one for TCP connections. The initial release exposes no client address and does not interpret forwarding headers; they remain ordinary request headers.

## R2. Ownership, context, and typed input

- **R2.1 One body consumer.** Request metadata and application configuration must be separate from the affine body and resource handles. Parsing consumes the body once and returns either validated input or a rejection. The handler does not receive a second implicit body copy.
- **R2.2 Raw bytes.** Raw-byte routes and plain HTTP handlers retain body access. A route that verifies a signed body must explicitly pass those same bounded bytes into its decoder afterward. Body caching and conversion to a linked-list byte string must not happen implicitly.
- **R2.3 Typed context.** Applications supply typed dependencies and request-local context. Authentication may establish a typed principal for downstream work. Context must not be a string-key service locator, and request identity must not leak between concurrent requests.
- **R2.4 Shared versus affine.** Copyable configuration may be shared by all requests. Each affine dependency instance, such as a database connection or client pool, must be held by at most one in-flight request at a time. A reusable route must not capture a one-use handle as though it were shared configuration.
- **R2.5 Bounded instances.** Affine instances live in a bounded owner set created before the application serves or dispatches. A request that needs an instance when none is free either waits as counted buffered work within admission limits or receives `503`; there is no unbounded wait queue. Concurrency for routes that need a dependency is therefore at most the size of its set.
- **R2.6 Return and loss.** Success and expected failure must return the instance to its set. An instance kept by a crashed or stalled request stays unavailable. The number of instances in use must be observable to the server owner, so lost capacity is visible rather than silent. During graceful shutdown, Camber explicitly closes the instances after admitted requests finish and return them. Forced process termination may skip explicit close hooks; OS descriptor cleanup is not application cleanup or rollback.
- **R2.7 Mechanism decision.** The public owner uses one bounded command inbox, an owner task, and closed-template operations over whole affine dependency bundles. Bundles are initialized before operations are admitted; checkout is one owner transition and never acquires separate sets in competing orders. A copyable typed context carries only the inbox, while typed principals and inputs remain request-local. The handler returns its bundle on both success and expected failure through the private owner protocol before any disposable `Data` caller reply is sent. Closing a caller reply cannot erase resource handles or strand capacity. Owner counts expose held/lost capacity. Exhaustion rejects immediately; inbox-blocked callers must remain counted inside external admission limits. Explicit close returns `Busy` without waiting on held work, and idle close invokes every bundle destructor, closes the private inbox, and rejects buffered commands. Startup failure closes prior initialized bundles; the initializer owns cleanup of partial handles inside one bundle. The native/JS consumer in `check.bend` exercises two concurrent principals, opposite resource operation orders, failure/return, counts, closed replies, startup recovery, and explicit close. The lifecycle receive loop uses disclosed `@unsafe`; the post-close drain is structurally bounded by inbox slots. These runtime checks are not mathematical IO or cancellation proofs.

## R3. Route matching

- **R3.1 Pattern syntax.** A pattern is `/` (the root) or a sequence of `/`-prefixed segments. Each segment is a nonempty literal or a whole-segment parameter such as `:id`. Parameter names match `[A-Za-z_][A-Za-z0-9_]*` and must not repeat within a pattern. A pattern may end with `/`, which adds an empty final segment matched exactly; any other empty segment is invalid. Literals are decoded UTF-8 text without NUL or `/`, and a literal cannot begin with `:`. Regexes, optional segments, and wildcards are not supported.
- **R3.2 Exact matching.** Paths are case-sensitive. `/`, `/users`, `/users/`, and `//users` are distinct. Camber does not redirect, collapse empty segments, normalize Unicode, or remove dot segments. A parameter matches one nonempty segment, so a path with an empty interior segment matches no parameter.
- **R3.3 Target handling.** `Http.Req.path` holds the raw request target. Transport currently accepts origin-form (`/…`), `*`, and absolute-form `http://…` targets with any method. Camber must:
  - for absolute-form, route the path and query regardless of scheme and authority; an empty path is `/`. After target parsing, the authority supplies the application's `Host` value instead of the received `Host` header, as required by [RFC 9112 §3.2.2](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2.2);
  - accept `*` only with OPTIONS (R4.5) and answer any other method with `400`;
  - answer `400` for a raw `#`, a byte below `0x21`, or a byte above `0x7E` anywhere in the target;
  - separate the query at the first `?`, split the path at literal `/` bytes, then percent-decode each segment exactly once as strict UTF-8.

  Malformed escapes, invalid UTF-8, NUL, and a decoded `/` produce `400`. `+` stays literal in paths. A captured value is never decoded again. Pattern literals are compared with decoded segments, so the pattern `/café` matches `/caf%C3%A9`.
- **R3.4 Precedence.** The most specific matching path is chosen before its method. Segments are compared left to right; a literal outranks a parameter at the first differing position. Registration order must not change the result. Thus `GET /users/me` and `POST /users/:id` make `POST /users/me` a `405`, not a call to the parameter route. This keeps a path's `Allow` set and group policy dependent only on that path. The route description must list each literal path that hides methods of a parameter route, so this effect is visible.
- **R3.5 Registration errors.** Application construction must reject invalid patterns and duplicate method/shape pairs, before direct dispatch or serving is possible. `/users/:id` and `/users/:name` are the same shape. They may share one path entry with different methods, but the same method cannot be registered twice. Each method keeps its own parameter names. Methods sharing a path entry must have the same group ancestry; conflicting placement is a registration error. Per-method route hooks may differ, so a public GET and an authenticated DELETE on one path use a route-level authentication hook rather than different groups.
- **R3.6 Prepared table.** Routes are fixed after construction. Patterns and effective group policies are prepared once, not split on every request. The route description must expose each method, pattern, group membership, and the hidden methods of R3.4 without starting a server.

Deployment note: Camber matches the target as received. A reverse proxy that merges slashes, removes dot segments, or decodes the path can disagree with Camber about which route a request reaches. Path-based access control belongs in Camber groups, or the proxy must forward the target unchanged.

## R4. HTTP method behavior

- **R4.1 Misses.** An unknown path produces `404`. A known path without the requested method produces `405` with a deduplicated, alphabetically sorted `Allow` header listing the path's registered methods, HEAD when GET exists, and OPTIONS. Method names are case-sensitive.
- **R4.2 HEAD.** Explicit HEAD and OPTIONS routes take precedence over generated behavior. Otherwise HEAD uses the selected path's GET route, including its decoding and hooks; the handler sees the original HEAD method, and transport suppresses the response body. `Allow` includes HEAD when GET exists.
- **R4.3 OPTIONS.** Without an explicit OPTIONS route, a known path returns `204` with `Allow`, including OPTIONS. An OPTIONS request for an unknown path returns `404`.
- **R4.4 Generated responses.** Generated OPTIONS and `405` responses do not decode a body or invoke a business handler. Generated HEAD, OPTIONS, and `405` keep the selected path's group policy. Route-local hooks follow the selected explicit handler, including GET used for HEAD. Which scopes run is fixed by the table in R6.6.
- **R4.5 Server-wide OPTIONS.** `OPTIONS *` returns `204` with `Allow` set to the union of registered and implied methods, through global policy only. Any other method with target `*` produces `400` (R3.3).

## R5. Query, body, and response

- **R5.1 Query syntax.** Query decoding uses strict UTF-8 percent decoding and interprets `+` as space. A field splits at its first `=`; the key may be empty, so `?=x` has key `""` and value `x`. Repeated keys and their order are preserved: `?tag=a&tag=b` gives two values, and `?flag` and `?flag=` each give an empty value. Empty fields between `&` separators are ignored. Malformed escapes, invalid UTF-8, or NUL produce `400`. Query values never overwrite route parameters or headers.
- **R5.2 Repeated query keys.** A typed decoder that reads one value must reject a repeated key with `400` rather than pick the first or last. List-valued decoders receive all values in order.
- **R5.3 JSON media type.** The JSON decoder accepts `application/json` or an `application/*+json` media type, matched case-insensitively. A missing `Content-Type`, another media type, a `charset` parameter other than `utf-8`, or a non-identity `Content-Encoding` produces `415`. Other media-type parameters are ignored. There is no implicit request decompression.
- **R5.4 JSON content.** With an accepted media type, each of the following produces `400`: a missing, empty, or invalid JSON body; invalid UTF-8; a leading byte-order mark; an unpaired surrogate escape such as `\uD800`; a repeated key within one object; nesting deeper than a configurable limit, default 64; and an application validation failure. Parsing must reject rather than repair input. Numbers keep their exact text until a decoder converts them with a checked range.
- **R5.5 Text and raw bytes.** Raw bytes, text decoding, and JSON decoding are explicit choices. The text decoder accepts a `text/*` media type with no charset or `utf-8`, otherwise `415`. It rejects invalid UTF-8 with `400`, unlike `Http.text`, which substitutes U+FFFD.
- **R5.6 Response helpers.** Helpers produce JSON (`application/json`), UTF-8 text (`text/plain; charset=utf-8`), bytes with no guessed content type, empty responses, and redirects. A redirect requires an explicit `301`, `302`, `303`, `307`, or `308` status and a `Location`. A public output encoder must not implicitly serialize extra fields from an internal domain record.
- **R5.7 Response validation.** The application sets status and headers; transport owns framing headers and body suppression. Camber validates the final response, after transforms, before handing it to transport. This includes responses from plain HTTP handlers. A valid response has:
  - a status from `200` to `599`, since transport sends `1xx` itself and upgrades are out of scope;
  - header names that are RFC 9110 tokens, stored lowercase so lookup and replacement are case-insensitive and no name reaches transport in two spellings;
  - header values with no CR, LF, NUL, or other control byte except HTAB;
  - no `Content-Length`, `Transfer-Encoding`, `Keep-Alive`, `Upgrade`, `TE`, `Trailer`, or `Proxy-Connection` header, and no `Connection` value other than `close`.

  Repeated values remain distinct, including `Set-Cookie`. A violation is an expected failure handled by R6.5; no bytes are sent first.

  Delivered response boundary: standalone `validate` and `plain` return expected `Result<&2, &1, ResponseError, Http.Res>` with `InvalidResponse`. Public `dispatch` now consumes validation failures through the R6.5 mapper and returns `Completion<S,H>` with the final safe response and actual entered policies. It never sends bytes or invents a transport outcome. Field values remain octet Strings (0..255), matching Http's byte packing; safe obs-text and HTAB remain intact. Output helper, scoped lifecycle, and native/JS loopback receipts are in `README.md`.

Today transport removes CR and LF from header names and values without reporting it, and writes any `U32` as the status. It sets its own lowercase `content-length`, but would also send an application `Transfer-Encoding` header or a differently cased `Content-Length` header beside it. R5.7 closes those gaps at the Camber layer; transport stripping remains as defense in depth.

- **R5.8 Typed path parameters.** Typed path decoders read the captured values already decoded under R3.3 and must not percent-decode them again. They run during input decoding and validation, after the applicable before hooks. Validation or checked-conversion failures produce an expected `400` failure handled by R6.5; the handler must not run.

## R6. Hook and error lifecycle

- **R6.1 Roles and inheritance.** Hooks have four roles: before-handler, response transform, completion notification, and application error mapping. Group policies inherit from root to child, never from child to parent or between siblings. A group's policy applies to all its routes regardless of builder statement order.
- **R6.2 Flow.** The normal flow applies to requests admitted by transport. Framing and transport-limit rejections do not enter application hooks or error mapping.

  ```text
  Global before hooks
    -> target parsing and route selection
    -> selected group and route before hooks
    -> input decoding and validation
    -> handler
    -> response transforms
    -> response validation
    -> transport write
    -> completion notification
  ```

- **R6.3 Before hooks.** Before hooks run outermost to innermost, in declaration order within each scope. They receive metadata and context, not an implicitly parsed body. Each returns continued state, an early response, or an expected failure. An early response or failure skips later before hooks, decoding, and the handler. Transport has already buffered the body by this point (see Scope).
- **R6.4 Scopes and transforms.** The scopes are the root, each enclosing group from outermost, and the route. A scope is entered when processing reaches it, before its first before hook runs, even if it has none. Only entered scopes participate in transforms and completion notifications. Transforms run route to root, in reverse declaration order within each scope.
- **R6.5 Error mapping.** Expected failures from before hooks, response transforms, decoders, handlers, response validation, and the framework (`400` target errors, `404`, `405`, `415`) pass through the application's single error mapper at most once. Deliberate early responses do not. The default mapper produces [RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457.html) for framework errors. Unrecognized application failures produce a generic `500` without internal diagnostics. A transform or validation failure stops the transform chain. If mapping has not occurred, the failure is mapped once and the mapped response is validated without further transforms. Otherwise, or if the mapper fails or its result is invalid, Camber sends a fixed minimal `500`. Camber must not restart transforms, handlers, or domain effects to recover from an error.
- **R6.6 Outcomes.** The scopes entered for each outcome:

  | Outcome | Scopes entered | Mapper runs |
  | --- | --- | --- |
  | Invalid target or `*` misuse | root | yes |
  | Unknown path (`404`) | root | yes |
  | `OPTIONS *` | root | no |
  | Known path, method missing (`405`) | root, the path's groups | yes |
  | Generated OPTIONS | root, the path's groups | no |
  | Group hook returns an early response or failure | root through that group | failure only |
  | Route hook returns an early response or failure | all, including the route | failure only |
  | Decoder or handler failure | all | yes |
  | Response validation failure | scopes already entered | only if mapping has not occurred; otherwise a fixed minimal 500 |
  | Success | all | no |

  Consequently an authentication rejection in `/users` receives the `/users` group's transforms but not those of the route it guarded.
- **R6.7 Completion notifications.** While the process continues operating, completion notifications run once for actual immutable entered policies, inner to outer, after a live response write succeeds or fails. Repeated policy labels do not collapse distinct scopes. They observe status, duration, application mapping/recovery flags, and the actual transport outcome, cannot change the response, and do not claim the peer received it. Expected notification failures go to the server's owner error-reporting path and do not replace a response, stop remaining notifications, re-enter the mapper, or replay effects. Direct dispatch emits explicit application-only completion, never host-write success. Monotonic duration runs from before direct application dispatch through final validation, or from before live private-pipe/dependency work through actual HTTP write/suppression completion. It is captured once before notices, excluding live framing/body reads and callback/log latency. Callbacks remain inline, outside the Admission actor, and counted until actual return; they may query real server stats. Runtime failure or forced process termination may prevent notifications from running.
- **R6.8 Failure limits and logging.** Transport failures after response commitment cannot become a second HTTP response. Runtime crashes and stalled computations are not expected application failures, and this lifecycle does not promise their containment. Optional access logging uses published Notch0.1.0.0 with a closed field projection: status, duration_ms, mapped, stopped, and explicit application/transport outcome, plus Notch's envelope. It never receives bodies, query strings, raw targets/routes, credentials, headers (including Authorization/Cookie/Set-Cookie), arbitrary logger context, or internal diagnostics. Disabled access logging produces no access output; owner error reporting remains independent. Access lines cover Camber Reply completions, including dependency-capacity503, not transport-generated replies that never reached Camber. The raw transport observer remains separate.

## R7. Server operation

- **R7.1 Defaults.** `server.config(port)` explicitly supplies loopback127.0.0.1, body1048576 bytes, headers65536 bytes,128 open connections,128 active requests and128 conservative buffered reservations, header5000ms and body/idle/write30000ms. Public binding and raised limits require explicit `Http.ServerConfig` configuration, rather than inheriting transport defaults. The deployment supervisor has a proposed5-second shutdown grace period followed by a1-second forced-termination/reaping budget. The external supervisor, not an embedded Bend timer, enforces that final process deadline.
- **R7.2 Startup and errors.** Invalid configuration, route registration errors, and bind failures return a startup error before the application is reported as listening. Server operation exposes errors to its owner without requiring access logging. Expected completion-notification failures are reported without stopping the server.
- **R7.3 Overload.** A parsed request rejected for application capacity, including a dependency wait under R2.5, receives `503` and closes without invoking business effects.
- **R7.4 Shutdown.** Graceful shutdown stops accepting connections and new requests on existing keep-alive connections, closes idle connections, and lets admitted requests finish during the grace period. Completed requests return their affine dependencies for explicit cleanup. If the process has not exited when grace expires, the external supervisor forcibly terminates the entire dedicated server process and observes its exit within the configured teardown budget. This fallback applies when CPU work or blocking effects prevent graceful shutdown from progressing. There is no same-process isolation guarantee, and forced termination may skip notifications, flushes, and cleanup hooks. Interrupted handlers are not replayed automatically. Timeout, disconnect, and process termination do not undo completed external side effects; an outstanding remote operation may still complete after the local process exits.
- **R7.5 Proof of operation.** Public Camber0.6.0.0 source runs the sole dispatcher through published HTTP0.30.0.0 and keeps the actual actor completion future in an affine owner. Native/JS serving scenarios and commands are in `serving_check.bend`, `run_serving.py` and `serving_results.json`; actual entered-policy completion, safe logging and explicit reset/recovery evidence are in `notices_check.bend`, `run_notices.py` and `notices_results.json`. A returned stop request is not drain: real transport completion (including inline callbacks) precedes bundle destruction and actual owner join. Busy close preserves its affine owner for retry. A documented external-supervisor deployment remains separate #339 work; no arbitrary-handler cancellation, hard CPU timeout or embedded isolation is claimed.

## Transport requirements

Camber's release depends on the following `http` and `wire` behaviors. They are stated here because Camber needs them; their implementation and checks belong in those packages.

- **T1 Limits.** Header and body limits are separate and configurable. Body accounting counts bytes after transfer decoding, not declared `Content-Length`. Oversized bodies produce `413`, oversized headers `431`, and malformed framing `400`. HTTP 0.27.0.0 implements separate configurable caps on the shared whole-request, streamed-request, writer, and runtime-context paths; [native/JS socket evidence](../http/limits_results.json) includes decoded at-cap bodies and independent header/body caps in one socket send.
- **T2 Deadlines.** The phase deadlines in R7.1 apply, and progress does not reset a phase. An expired header or body read produces `408` and closes when a response remains possible. Idle expiry closes silently. Write expiry closes the connection and reports failure. HTTP 0.27.0.0 implements absolute read phases and bounded packed response writes using published Wire 0.4.4.0. HTTP 0.29.0.0 preserves actual `WriteFailed` outcomes on whole/context, stream, writer, configured, and convenience paths; [native/JS outcome evidence](../http/outcome_results.json) includes blocked writes and real RST. Socket closure is not handler cancellation or generic streamed-state cleanup.
- **T3 Admission.** Admission bounds sockets, active handlers, and buffered work, not just currently executing handlers, with no unbounded queue. At the connection cap, a connection without a safely parsed request may be closed. Connection permits and transport buffers are released on success, rejection, and IO failure. Handler and dependency capacity remain counted until their work actually returns or the process terminates; a timeout or disconnect alone does not free a still-owned instance. Published HTTP 0.28.0.0 implements shared finite connection, active-operation, and retained-input reservations on production whole/context, stream, writer, configured, and convenience paths. [Native/JS admission evidence](../http/admission_results.json) covers all three independently exceeded caps in all modes, exact rejection counts and zero rejected-ID effects, release/recovery, disconnected still-running callbacks, reset pipelined input, failed writer callbacks, and concurrent/post-close copied public observations. The [quantitative retained-input contract](../http/README.md#quantitative-input-retention) distinguishes logical bytes and metadata structure from allocator/kernel/application RSS. An unsafe excess connection is one synchronous close-only accept slot, without a reader/task/buffer; it is not admitted ownership.
- **T4 Startup.** The listen result is returned to the caller, and readiness is signaled once the socket accepts connections. Published runtime-context `Http.server.start` returns the affine application owner on success, invalid configuration, and bind failure; native/JS startup evidence verifies rollback, accepting readiness, and shared context. Convenience `Http.serve` still returns neither a recoverable listen result nor a readiness signal; the historical convenience probe's exit 48 is not a startup-ownership success.
- **T5 Write outcome.** Transport reports each final response write outcome for R6.7. Published HTTP0.30.0.0 (`0x8bc87dd4d1e610fe1bf336b567537a8c`) preserves `HostAccepted`, actual host/deadline `WriteFailed`, and known-length `IncompleteResponse`, once after callback return and final framing. Host acceptance is not peer receipt. Typed Data receipts carry copied metadata beside affine response ownership, without application handles, handler replay or global request maps. [Native/JS evidence](../http/outcome_results.json) covers configured/convenience whole, stream/writer paths, suppression, real resets, partial failures, known-length/terminal-chunk boundaries, disposal and late receive. Camber0.6.0.0 consumes actual inline transport completion for entered-policy notifications, monotonic duration, and optional safe Notch output; [native/JS evidence](notices_results.json) includes definitive gated RST after retained file effects.
- **T6 Lifecycle.** Published breaking HTTP0.30.0.0 (`0x8bc87dd4d1e610fe1bf336b567537a8c`) supplies copied stop controls and actual affine-owner drain results. Its single transport owner uses published Wire0.4.5.0 (`0x1435aec27074c8141b74747909079afc`) bounded accepts; idle/unadmitted reads use real slices without renewing absolute phases. Stop rejects new business admissions and closes idle input. Admitted streams retain state through real completion or explicit typed abort; skipped writers consume state through explicit disposal before reporting/release. [64 native/JS socket scenarios](../http/drain_results.json) include real File descriptors changing1→0 while cleanup remains held. Delayed/stuck work stays counted, not canceled. Forced-exit evidence is separate; no generic destructor, arbitrary preemption or same-process isolation is promised. The external supervisor remains #339, not a second transport.

## Acceptance examples

The example application has a public `GET /health` route and an authenticated `/users` group containing `GET /users/:id`, `GET /users/me`, and `POST /users`. Its dependencies supply user lookup and creation through an affine store handle; Camber does not supply persistence or an authentication product.

| Route | Input and result |
| --- | --- |
| `GET /health` | No decoder; `200` JSON `{"ok":true}`. |
| `GET /users/:id` | Require a nonempty decimal U32 ID with checked overflow; `200` public `{id, name}` or an application not-found `404`. |
| `GET /users/me` | No decoder; `200` public `{id, name}` for the authenticated principal. |
| `POST /users` | Require a JSON object containing only `name`, a string of 1–100 Unicode scalar values; `201` public `{id, name}` and `Location: /users/<id>`. |

The example auth hook returns a typed principal for accepted bearer credentials, or `401` with `WWW-Authenticate: Bearer`. Only the supplied application decides which credentials are accepted.

| Example | Expected behavior | Covers |
| --- | --- | --- |
| Health request with no credentials | `200`; user-group auth does not run. | R1.2, R6.4 |
| `HEAD /health` | `200` with no body over a socket; direct dispatch returns the GET body unchanged. | R1.2, R4.2 |
| Unknown path with no credentials | `404` Problem Details; user-group auth does not run; only global transforms apply. | R4.1, R6.6 |
| User lookup with ID `7`, valid auth, and an existing user | Lookup receives U32 `7`; output excludes internal fields. | R2.1, R5.6 |
| User lookup with `abc` or `4294967296` and valid auth | `400`; lookup is not called. | R5.8 |
| User lookup with a missing user and valid auth | Application mapper returns `404`; creation is not called. | R6.5 |
| `GET /users/me` with valid auth, registered before or after `/users/:id` | Returns the principal's user; the ID route is not called. | R3.4 |
| `POST /users/me` with valid auth | `405` with `Allow: GET, HEAD, OPTIONS`; no fallback to the parameter route. | R3.4, R4.1 |
| Valid user creation and auth | Creation receives validated input; `201` and `Location` identify its result. | R2.1, R5.6 |
| Malformed JSON with no credentials | `401`; neither JSON decoding nor creation runs. | R6.3 |
| Valid auth with malformed JSON, a missing/wrong/extra field, a repeated `name` key, or an empty name | `400`; creation does not run. | R5.4 |
| Valid auth with a missing or unsupported content type | `415`; creation does not run. | R5.3 |
| `/users/7?tag=a&tag=b` | ID is `7`; query retains both tag values in order. | R3.3, R5.1 |
| Absolute-form `GET http://example.test/users/7` with valid auth | Same result as `/users/7`. | R3.3 |
| `/users/7/` or `//users/7` | `404`; no slash normalization occurs. | R3.2 |
| `/users/%37` and `/users/%2537`, with valid auth | First decodes to ID `7`; second decodes once to `%37` and fails ID validation. | R3.3, R5.8 |
| `/users/a%2Fb`, malformed `%`, invalid UTF-8, or a raw non-ASCII byte | `400`; no domain function runs. | R3.3 |
| Wrong method on `/users/7`, with valid auth | `405` with `Allow: GET, HEAD, OPTIONS`; no domain function runs. | R4.1, R4.4 |
| Generated HEAD or OPTIONS on `/users/7`, with valid auth | HEAD uses GET but sends no body; OPTIONS sends `204` and `Allow` without lookup. | R4.2, R4.3 |
| `OPTIONS *` and `GET *` | `204` with `Allow: GET, HEAD, OPTIONS, POST`; `GET *` is `400`. | R3.3, R4.5 |
| Duplicate GET patterns `/users/:id` and `/users/:name` | Application construction fails; neither dispatch nor serving starts. | R3.5 |
| A handler returns a header value containing CR/LF, or sets `Transfer-Encoding` | Mapped `500`; no bytes of the invalid response are written. | R5.7, R6.5 |
| Root/group/route hooks on success | Before order is root, group, route; transforms and live completion notifications unwind route, group, root. | R6.3, R6.4, R6.7 |
| Group auth rejection or response-transform failure | Only entered scopes participate; effects are not retried and the mapper runs at most once. | R6.5, R6.6 |
| Two concurrent requests with different principals, one of which fails in the store | Each sees only its own principal; the store handle is held by one request at a time and returned after the failure. | R2.3–R2.6 |
| Graceful shutdown with cooperative requests | New requests stop, admitted requests finish, affine instances return and explicitly close, and the process exits without forced termination. | R2.6, R7.4, T6 |
| Shutdown with a stuck CPU handler or idle socket | An external supervisor records shutdown request, grace expiry, forced termination, actual process exit, and peer closure separately in both lanes. Retained side effects are not rolled back; explicit cleanup and notifications are not required after forced termination. Passing a timer or sending a signal is insufficient. | R7.4, R7.5, T6 |
| Additional plain-handler fixture, outside the four-route application | A plain `Http.Req -> IO(Http.Res)` handler consumes packed body bytes without conversion through `String`, receives its group's hooks, and passes response validation. Direct dispatch and a real socket return matching status, application headers, and body bytes for a body-bearing response. | R1.1, R1.2, R5.7 |

Application examples run through both direct dispatch and a real socket where applicable. Transport acceptance, owned by `http`, must also cover chunked bodies at and over the cap, slow trickle headers and bodies, slow readers, keep-alive during shutdown, overload recovery, and side effects that complete before a response write fails.

## Performance gates

Build a raw `Http.serve` baseline before measuring Camber, with identical behavior, payloads, transport limits, connection reuse, and CPU budgets. From the baseline, record a framework-overhead budget for direct dispatch and for end-to-end serving, for each workload below, before measuring Camber. Existing [HTTP](../http/bench/README.md) and [router](../router/bench/README.md) harnesses are starting points, not Camber results.

Measure fixed text and JSON responses, parameter extraction, a 1 KiB JSON decode/validation workload, zero, one, and five hooks, and route hits, misses, and method failures with 10, 100, and 1,000 routes. Include 64 KiB and 4 MiB byte bodies with explicitly raised limits. Record construction/startup cost, native build time, binary size, successful requests/sec, latency percentiles, errors, CPU, and peak RSS.

The package benchmark must include idiomatic C, Rust, Python, and JavaScript comparisons using popular libraries, not Camber reimplemented in each language:

- C: libevent's HTTP server, compared with the raw `Http.serve` baseline, since it has no framework layer;
- Rust: axum;
- Python: Flask under a production WSGI server;
- JavaScript: Node HTTP as a transport baseline, with Fastify, Hono, and Elysia as framework comparisons, recording each runtime.

The research note's chi and Phoenix candidates are left out to keep the four-language harness. Status, required headers, and body checksums must agree for shared fixtures; incompatible semantics are documented, not hidden.

Use warmup, repeated trials, documented versions and commands, and both saturation and fixed-offered-rate loads. Sustained overload must show bounded retained memory and recovery after load falls. Native and JS results are reported separately. Run one Bend process at a time, start small, and enforce the repository's memory safety limits.

Measure ordinary-request progress beside yielding work and CPU-heavy work, including worst-case permitted parsing and validation. Record ordinary latency, actual client-visible IO timeout behavior, and recovery after compute completion. Compare native single-thread, native default CPU-thread configuration, and JS separately. A bounded request count or an IO timeout does not establish scheduler isolation; do not infer responsiveness from the ability of an external supervisor to terminate the process.

Record internal monotonic work time separately from client latency and host receipt of buffered logs. Show that a progress request overlaps the work rather than starting after the work finished. Exercise bounded inputs at admitted concurrency as well as one at a time; a body/depth limit alone does not establish an aggregate CPU or memory bound.

No absolute throughput promise is made. Published hello-world rankings are not evidence that Camber meets this contract.

## Dependencies and proof boundary

- **HTTP server.** The [current server](../http/README.md#serve) supplies shared HTTP/1.1 framing, packed bodies, keep-alive/pipelining, bounded rejection drain, and upload/download callbacks. HTTP 0.27.0.0 added T1/T2; #316 supplied startup ownership; published 0.28.0.0 added T3; published 0.29.0.0 added T5 actual outcomes and typed Data completion receipts. Local 0.30.0.0 adds T6 stop/drain and explicit affine stream-abort/writer-disposal callbacks, pending merge and CI publication. Whole serving sends `100 Continue` before its handler; streams start with headers, then finish only after complete body read/discard. Failed uploads instead consume state through abort. All convenience paths use the same owner. Transport deadlines do not preempt handlers; explicit application cleanup must actually return.
- **Router.** The shared `router` now supplies a prepared table, path-first precedence, capture maps, target validation, and method negotiation. The local breaking release is `0.2.0.0`, pending merge and CI publication. Camber's experiments use that table; the release must import the published package and meet R3 semantics. Camber must not keep its own router.
- **JSON.** Published Json `0.5.1.0` supplies `parse.strict.bytes(body, cap)`: it rejects invalid UTF-8 and lone surrogate escapes and enforces container nesting at each opening, before parsing its contents. Legacy `parse.bytes` retains law-required replacement and unbounded-by-policy depth. Camber's explicit JSON input choice uses only the strict bounded parser (default64), then checks decoded-key uniqueness independently at every object level without copying the body or changing exact number text. Checked numeric conversion and application validation remain explicit decoder steps.
- **Process lifecycle, not runtime cancellation.** [Base has no cancellation](../concurrency/README.md#io). `Conc.timeout` leaves its action running; Bend 2.0.34 explicitly [excludes cancellation of blocking effects](https://github.com/bendlang/bend/blob/v2.0.34/WONTFIX.txt). Camber does not require that runtime feature for release. A documented external supervisor must enforce the dedicated process's shutdown deadline and observe its exit in native and JS. Arbitrary uncooperative handler code cannot be treated as canceled because a timer won. This deployment boundary does not establish graceful cleanup, transaction rollback, descendant cleanup, or restart safety.
- **Compiler.** The R2.7 example must compile against the installed compiler before signatures are chosen. Support is not inferred from Rust or TypeScript interfaces.

No human-authored Camber pure laws have been supplied. `LAWS.bend` records the empty inventory; `PROOF.bend` imports it without asserting invented claims. The package has no mathematical proof coverage beyond type checking and structurally checked pure helpers. Future `LAWS.bend` claims remain human-owned. Suitable pure claims include deterministic route precedence, single percent-decoding, sibling policy isolation, entered-scope selection, and skipping handlers after rejection, where the checker can express them. Host IO, clock behavior, cancellation, socket cleanup, and process lifecycle remain trust assumptions supported by real-runtime checks. A proved matcher does not prove the server.

## Delivery gates

1. Compile the R2.7 ownership/composition example and record the chosen mechanism in this spec. Establish the raw HTTP baseline and record the framework-overhead budget.

Before gate 2, the prepared-router breaking release must be published, and JSON must reject an unpaired surrogate escape or report that replacement and support a configurable nesting limit enforced during parsing. These are already required under Dependencies.

2. Deliver one complete route-to-response slice covering the four example routes and the additional plain-handler fixture, direct dispatch, live serving, decoding, hooks, response validation, and errors.
3. Meet R7 and T1–T6 with cooperative drain and the documented external-supervisor fallback. Runtime cancellation and embedded-server lifecycle isolation are not release gates. Run package checks, proofs where available, and the cross-language benchmark against the recorded budget with matching outputs.

The initial release is not ready until all three gates pass. This spec does not authorize silently reducing the accepted shutdown, safety, or benchmark requirements.

## Deferred / Open Questions

### From 2026-10-01 review

- **Stuck-handler boundary resolved by dedicated-process scope** — R7.4/R7.5 — user-approved scope change, 2026-10-02

  Live serving no longer promises embedded lifecycle isolation or preemptive handler cancellation. Graceful drain remains required for cooperative work; an external supervisor terminates the whole dedicated process if work stalls. The acceptance boundary is actual process exit, not a timer result. Forced termination may skip logical cleanup and cannot undo external side effects.

- **Cross-language benchmark blocks release beyond the stated goals** — Performance gates and Delivery gate 3 — cross-language release benchmark (P1, scope-guardian, product-lens-codex, confidence 100)

  The initial release must ship comparison applications across four languages before its HTTP behavior can ship. The raw HTTP baseline already measures framework overhead. The stated goals are typed input, scoped hooks, ownership, and safe server operation. The document gives no goal that requires this harness.

- **Launch is a platform migration, not a small framework** — Dependencies and proof boundary — Release dependencies (P1, product-lens-codex, confidence 75)

  Adopters cannot take Camber as a self-contained framework. The release still needs coordinated changes to the router, HTTP transport, and JSON parsing, plus a documented supervisor deployment. Runtime cancellation is no longer a release dependency.

- **Public bind can send credentials in plaintext** — Scope — TLS deployment posture; Acceptance examples — bearer authentication (P1, security-lens, security-lens-codex, confidence 100)

  A deployment can follow this contract and still send bearer credentials over a publicly reachable plaintext connection. Proxy TLS is optional, and a public bind only has to be explicit. Absolute-form targets discard scheme and authority, so Camber cannot enforce HTTPS itself.

- **Overhead gate has no pass/fail cap** — Performance gates — framework overhead (P1, whole-doc-codex, adversarial-codex, confidence 100)

  Camber can pass the performance gate with unacceptable overhead. The contract records a budget from the raw baseline and gives no derivation or cap. A slow baseline can make a slow framework look compliant.

- **No adopter, pain, or reason not to call the HTTP server** — Overview — Camber's product premise (P1, product-lens-codex, confidence 75)

  The team can complete this contract and still ship a framework with no adopters. The document does not name a target user, a current workaround, observed pain, or why Camber beats calling the HTTP server directly.

- **Two dependency sets can deadlock** — R2.4–R2.7 — Affine dependency ownership and mechanism test (P1, adversarial-codex, confidence 75)

  Two concurrent requests can deadlock by each holding one affine instance while waiting for another that the other request holds. That consumes the admission slots the owner set is meant to bound. The ownership example requires one affine dependency, not two sets.

- **Access-log redaction is only the default** — R6.8 — Failure limits and logging (P1, security-lens-codex, confidence 75)

  Enabling or extending access logging can send bearer credentials or cookies to the log sink. The contract promises redaction only by default. A leaked authorization or cookie value can be replayed.

- **Configurable limits can disable overload protection** — R7.1 — Defaults and server limits (P1, security-lens-codex, confidence 75)

  A public server can accept settings that remove size, admission, or timeout protections and still satisfy "all configurable." That reopens slow-client and resource-exhaustion attacks the limit requirements are meant to prevent.

- **Overload test has no numeric memory cap** — Performance gates — overload recovery (P1, adversarial-codex, confidence 75)

  Implementers cannot tell when the overload test passes. Bounded retained memory has no numeric bound, steady-state window, or recovery threshold. A slow leak can be accepted as bounded.

- **Typed routes wait on transport lifecycle** — Delivery gates — Release sequencing (P1, product-lens-codex, confidence 75)

  Users must wait for production-server safety and transport changes before typed inputs and hooks can receive adoption feedback. Direct dispatch is already defined as a usable path. The dedicated-process contract removes the runtime-cancellation dependency, not the remaining transport requirements.

- **One client pool counts as one request of capacity** — R2.4–R2.7 — affine dependency ownership and concurrency (P2, adversarial, confidence 75)

  A service with one client pool of several connections would be limited to one dependency-using request at a time, even when the pool has idle connections. The contract treats a client pool like a single connection. Increasing the owner-set size could instead multiply whole pools.

- **Busy pool may wait or return 503** — R2.5/R7.3 — Dependency exhaustion and 503 policy (P2, adversarial-codex, confidence 75)

  Two conforming implementations can differ when an affine pool is exhausted. One may wait within counted admission capacity. Another may return 503 immediately. The contract sets neither a maximum wait nor a fairness rule.

- **Encoded carriage return and line feed pass the raw-byte check** — R3.3 — Target handling (P2, security-lens-codex, confidence 75)

  Percent-encoded C0 controls can reach handlers even though raw controls are rejected. Those bytes are printable in the raw target, and post-decode checks reject only NUL and a decoded slash. They can then enter logs or header construction.

- **Router ownership has no alternative test** — Dependencies — Router ownership (P2, adversarial-codex, confidence 75)

  Camber's delivery is coupled to a breaking change in the existing router even though that router's only callers are its own checks, laws, and benchmark. The specification mandates shared ownership without comparing a Camber-owned prepared table.
