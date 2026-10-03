# Camber independent-author study

Implement a small publishing application against the current experimental Camber surface. Submit `app.bend`, `domain.bend`, and `PROOF.bend` in your assigned submission directory. These are the only repository files you may change. Use the supplied `contract.bend` types and fixed `LAWS.bend` unchanged.

Read `camber/author_study/evidence/setup/bend-guide.txt`, `camber/SPEC.md` (Author-facing application surface), `camber/surface.bend`, `camber/interface_check.bend`, and the compiling example `camber/surface_app.bend`. You may consult Base and the existing HTTP, JSON, router, response, and ownership modules. Only this task, these public materials, and the shared contract are author input; another author's submission and historical findings are outside your read set.

## Application

Export these definitions from `app.bend`:

- `Application` returns your copyable application plan type.
- `application() -> IO(Application)` prepares the canonical route registry.
- `dispatch(state: Contract.State, app: Application, req: Http.Req) -> IO(Contract.State & Http.Res)` is the single execution path.

Register `POST /publish` and `GET /public` with the prepared router. Reuse Camber's typed `Surface.scope` and `Surface.endpoint`, and the existing prepared registry. Route selection must come from that table, not a separate method/path selector. Do not change framework internals.

`POST /publish` is in a protected group. `Bearer alice` authenticates owner 7; `Bearer bob` authenticates owner 8. Other authorization values reject with 401 and `www-authenticate: Bearer`, before body decoding or handler effects. The principal must become typed context, not a global or a handler-side token check.

The request has `content-type: application/json` and exactly three fields: `title` (string), `secret` (string), and `published` (boolean). Reject missing, extra, duplicate, or wrong-type fields and malformed JSON with 400, body `invalid input`. Other media types reject with 415, body `unsupported media type`. Owner comes only from authenticated context.

Use the pure production functions in `domain.bend`:

- `publish(record: Contract.Record) -> Contract.Record` sets `published` to True and preserves owner, title, and secret.
- `view(record: Contract.Record) -> Contract.Public` projects owner, title, and published, with no secret.
- `encode(value: Contract.Public) -> Http.Body` encodes exactly those three fields as JSON using the existing JSON encoder. Preserve string contents, including Unicode and escapes.

The handler must call these functions. Write the encoded public value and a newline through the real affine journal File. A successful write returns 201 and that public JSON. A failed write returns 503, body `store unavailable`. Recover the same File in returned state on success and all rejection/failure paths; the host will read through the returned read-only File and explicitly close it. Do not replace or reopen the File. No secret enters the response or journal.

`GET /public` returns 200, body `public`, with no authentication, JSON decoding, or journal write. Its group must not inherit protected policies. Percent-encoded targets and query strings must use canonical prepared-router resolution. Unknown paths return 404. `GET /publish` with valid authorization returns 405 and `allow: OPTIONS, POST`.

## Observable lifecycle

Append events to `Contract.State.events` in reverse chronological order (head is newest). Each scoped response transform adds its header with value `yes` and records its event. Headers not named below must be absent.

| Scope | Entry event | Exit event and header |
|---|---|---|
| Root | `root-before` | `root-after`, `x-root-policy` |
| Protected group | `auth` | `protected-after`, `x-protected-policy` |
| Publish route | none | `publish-after`, `x-publish-policy` |
| Public group | `public-before` | `public-after`, `x-public-policy` |

Record `decode` once when the publish decoder is entered, before media or JSON validation. Record `handle` once when the publishing handler is entered. Record `public-handle` once for the public handler. The error mapper records exactly one of `map/unauthorized`, `map/input`, `map/media`, or `map/write`, once per expected failure.

Successful publish order: root-before, auth, decode, handle, publish-after, protected-after, root-after. Authorization failure unwinds the entered protected and root scopes only. Decoder/handler failures also unwind the publish scope. Public order: root-before, public-before, public-handle, public-after, root-after. Unknown path or method mismatch has only root-before, root-after.

## Proofs and submission

Prove every fixed law in `PROOF.bend`, importing `./LAWS.bend`. The laws quantify over the actual production `publish` and `view` functions. Preserve termination and safe proof dependencies. Do not weaken laws, use `@unsafe`, assume an unproved claim, or prove a disconnected model.

Authoring tools are file-only. Do not run builds, tests, formatters, or Git operations. The host serializes compiler/runtime checks and will return diagnostics for at most two repair rounds. Initial submissions and each repair are preserved and scored separately. Compiler access here means host-mediated diagnostics, not concurrent author-side compiler processes.

When finished, report changed files, undocumented assumptions or missing API facts, and any quantity/signature adapters you needed. Report verification as not run; do not claim a compiler or runtime pass.
