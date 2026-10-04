# Camber authoring and proof study

## Verdict

Both final implementations pass the application, exact dispatch-signature, ordinary proof, and mutation-sensitivity checks. Neither initial submission passed every gate. Grok required two author repairs; Opus required one. This is one case per model, not a model ranking or a production-readiness result.

**The study was not cleanly read-isolated or blinded.** The boundaries were cooperative. Grok read the parent driver and runtime oracle before submitting. Opus read unrelated repository proof examples. Both searched outside the named read set. These deviations limit comparisons, especially Grok's first-pass runtime result. No other-author implementation or historical FINDINGS source heading was found in the inspected visible tool results; that inspection is not a sandbox guarantee. See [read-boundary audit](evidence/setup/read-boundary-audit.json).

## Routes and controls

- Grok 4.7: `xai-oauth/grok-4.7`, through xAI OAuth.
- Opus 5.5: `cursor/claude-opus-5-5`, through Cursor, not direct Anthropic inference.
- Native model-change receipts retain the requested selectors and report no fallback. These attest local resolution, not independent serving-backend identity.
- Fresh author sessions received the same [task](TASK.md), [types](contract.bend), [laws](grok/LAWS.bend), [rubric](RUBRIC.md), recorded guide, public surface/spec, and compiling example. Writable directories and model bindings differed.
- Authors had file-only tools. The host ran compiler and runtime commands serially, with a 20 GiB sampled-RSS guard. Initial sources and each author repair were captured before judging. The host never repaired submitted implementations.
- Pre-author setup was committed as `a42fecc`. Fixed task, rubric, types, laws, guide, and direct driver hashes still match [SETUP.json](SETUP.json); see [final integrity](evidence/setup/final-integrity.json).

## Outcomes by round

| Author and round | Ordinary four-law gate | Native application build | Exact dispatch contract | Direct cases | Socket scenarios |
| --- | --- | --- | --- | --- | --- |
| Grok initial | Fail: unsafe/foreign import closure | Pass | Fail: `+app` binder | 29/29 | 30/30 |
| Grok repair 1 | Pass | Pass | Fail: binder unchanged | 29/29 | Not run |
| Grok repair 2 | Pass | Pass | Pass: native typed consumer | 29/29 | 30/30 |
| Opus initial | Pass | Fail: computed-local matching | Not reached | 0/29 reached | Not reached |
| Opus repair 1 | Pass | Pass | Pass: native typed consumer | 29/29 | 30/30 |

The source/law integrity checks pass, but the study read-boundary requirement does not. Final semantic passes must not be presented as clean protocol passes. Opus's initial build prevented runtime execution; it did not produce 29 observed semantic failures. Runtime success does not imply proof or signature success.

Initial author-job durations were 13m49s for Grok and 10m29s for Opus. These are wall durations, not measurements of thinking or implementation performance. Commands, outputs, errors, elapsed times, sampled RSS, observations, and source hashes are retained in each round's `results.json` and, where exercised, `live-results.json`:

- [Grok initial](evidence/grok/initial/results.json), [repair 1](evidence/grok/repair-1/results.json), [repair 2](evidence/grok/repair-2/results.json).
- [Opus initial](evidence/opus/initial/results.json), [repair 1](evidence/opus/repair-1/results.json).
- [Final Grok sockets](evidence/grok/repair-2/live-results.json), [final Opus sockets](evidence/opus/repair-1/live-results.json).
- [Exact-signature native consumers](evidence/setup/callback-native-results.json).

Initial structured reports contain five assumption entries and five adapter entries for [Grok](evidence/grok/initial/author-report.json), and eight assumption entries and two adapter entries for [Opus](evidence/opus/initial/author-report.json). These counts describe reporting, not quality: several entries repeat task requirements. Opus's claim that it did not read RUBRIC is contradicted by grep excerpts in its visible tools. Its two bash-based Base discovery attempts were denied; no author-side compiler process ran.

## Failures and same-author repairs

### Grok: proof dependency closure

The initial proof command failed with `Error: 275 defs rely on unsafe or foreign code`. The pure domain imported the monolithic HTTP module for `Http.Body` and `Http.from_string`; its closure included wire and other foreign/unsafe definitions. This is a proof dependency failure, not evidence that publication or projection was mathematically false.

After receiving the exact diagnostic, Grok removed that domain import, used the existing canonical `Bytes.Bytes` type underlying `Http.Body`, and used `Json.utf8` for ASCII owner digits. Production `publish` and `view`, the fixed laws, and their proofs were unchanged. Repair 1 passed the ordinary proof gate and every direct case.

### Grok: public quantity contract

Initial `dispatch` used `+app`, contrary to the task's affine exported signature. Direct calls and the socket adapter did not detect this. A template consumer requiring `Contract.State -> Application -> Http.Req -> IO(Contract.State & Http.Res)` rejected `~App.dispatch`, reporting expected affine application versus observed `@+app`.

The exact diagnostic was returned in the second and last repair round. Grok moved its copying body into `dispatch.go` and exported the affine wrapper. The final native typed consumer builds, publishes, writes the journal, and returns the File correctly.

The first Opus signature probe used an entry without an IO main and reached unrelated foreign-import gating. That result is inconclusive, not a signature failure. Native IO consumers subsequently passed for both final candidates. The failed probes remain in [callback-contract-results.json](evidence/setup/callback-contract-results.json).

### Opus: computed-local tuple matching

Opus's initial domain and four proofs passed. The application build failed at a computed `filled` local followed by `(kept, fine) = filled`: Bend requires a parameter or field scrutinee. The exact diagnostic was returned to the author.

Opus added `field.title`, `field.secret`, and `field.published` helpers that destructure parameter pairs. It also renamed `new` to `got` speculatively; no observed diagnostic established that `new` was reserved. Only `app.bend` changed. The repaired implementation passed all application checks. Its domain already avoided HTTP imports by using the underlying canonical Bytes type.

## What the checks establish

The four universal laws quantify over the actual production `publish` and `view`: publication preserves owner/title/secret and sets the flag; projection preserves the public fields; publication is idempotent; and changing the secret does not change public view. Both final ordinary proof commands print `ALL PROOFS CHECK` and `Use --verdict for mathematical validity.`

Independent kernel attestation is **unavailable**. The calibration `--verdict` command reported missing Lean; it requires Lean v4.34.0 or a built `BENDTT` kernel. That environment failure is not an author failure. Ordinary checker acceptance is not represented as an independent mathematical-kernel verdict.

For each final candidate, copies were mutated in two ways: leave publication status unchanged, and project secret as title. Each mutation failed the fixed proof command and a real native publish/public-projection oracle. The mutated applications still built, so these are behavioral and proof checks rather than syntax failures. Originals were never mutated. See [mutation evidence](evidence/setup/mutation-results.json).

The 29 direct cases cover typed Alice/Bob authentication before decoding, exact input shape and duplicate rejection, malformed/media failures, public sibling isolation, prepared percent-encoded and absolute-target routing, root-only 404/405 lifecycle, exact Allow/policy/auth headers, Unicode/escape-preserving public JSON, actual journal writes, and returned read-only File readback on failures. The 30 socket scenarios add the same-worker Alice/public/Bob sequence, cumulative journal verification, natural exit, and listener closure over the existing finite transport.

These proofs do not cover encoding, File effects, sockets, cleanup, crash containment, or network safety. Those paths have concrete runtime evidence, not universal guarantees. This study ran native Bend only; it does not establish JS-lane equivalence or performance.

## Ergonomics and supported next changes

- **Document proof-safe dependencies.** Grok's observed import failure and Opus's successful Bytes-based domain show that naming a pure body through an effectful HTTP module can block proofs. Show the canonical existing Bytes type in proof-oriented examples rather than adding another body abstraction.
- **Keep public quantity contracts executable.** Both authors used `.go`/affine wrapper pairs around scoped callbacks. Grok also needed one at the exported dispatcher. A direct-call smoke alone missed that contract mismatch; the typed consumer catches it.
- **Explain Data inputs in affine slots.** Grok added an affine `Input` wrapper around `Contract.Record`, citing the endpoint's `Result<&2, &1, E, I>` success slot. Opus passes the Record directly and succeeds. The wrapper is not required for this task.
- **Show parameter-matching decoder examples.** Opus's computed-local match failure is a concrete Bend authoring hazard. Its small helper repair works without framework-internal changes.
- **Retain quality concerns rather than optimize submissions.** Both implementations encode public JSON twice, once for journal IO and once for the response. This is observed duplicated work, not a measured performance regression. Neither builds a second method/path router; both use the prepared table, then dispatch its selected action into scoped policy execution.
- **Improve author reference access before repeating.** File-only authors cannot invoke `bend base`. They searched repository examples for File/quantity facts instead. A shared captured Base reference and enforced read boundaries would make a repeat more controlled.

Both authors assume exact `application/json` media matching and the task's explicit empty/error bodies. The task overrides SPEC R6.6: generated 404/405 responses enter root only, not a matched path group. Passing this task does not establish full SPEC conformance. Grok drops `Router.Resolved.target` rather than using `Registry.with_target`; canonical route selection passes, but absolute-form Host propagation and query extraction are not established by these cases.

## Evidence, revisions, and replay

Each round retains immutable app/domain/proof/law snapshots and a cumulative visible `author-session.jsonl`. Exports preserve visible text, tool calls/results, displayed repair feedback, and model-resolution receipts. Private reasoning, credentials, and private session configuration are excluded. Native originals remain private; export metadata records their digest. Read-set deviations are preserved rather than hidden.

[Harness revisions](evidence/setup/harness-revisions.json) disclose the optional-verdict environment guard, a pre-judging fix for Python treating JSON `1` as equal to `true`, added socket checks of existing requirements, and the later typed consumer of the existing dispatch contract. The task, laws, types, fixed direct cases, and direct driver were not weakened. Calibration and negative-oracle evidence remain under `evidence/setup/`.

From the repository root, use new round names because evidence must not be overwritten:

```sh
python3 -B camber/author_study/run.py self-check
python3 -B camber/author_study/run.py grok --round replay-grok
python3 -B camber/author_study/run_live.py grok --round replay-grok
python3 -B camber/author_study/run.py opus --round replay-opus
python3 -B camber/author_study/run_live.py opus --round replay-opus
```

Run one Bend process at a time with swap headroom. The runners record outcomes; inspect proof commands and runtime results separately rather than treating CLI exit alone as the verdict. No package was published. Inline reuse/quality/efficiency review covered the parent harness; no independent code review or PR watcher is claimed.
