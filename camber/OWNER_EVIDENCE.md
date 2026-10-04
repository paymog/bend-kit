# Public dependency owner evidence

Issue #331; package version `0.1.0.0`. The independent owner ships without fake dispatch/serve entrypoints. It imports only Base. The native worker runtime model identity was supplied as `openai-codex/gpt-6.1-sol:medium`; no separate served-model receipt was available. Compiler receipt: `bend 2.0.35`.

## Commands and observed results

From the isolated issue workspace:

```sh
python3 camber/run_owner.py
bash scripts/publish.sh --check camber
```

The runner executes `bash scripts/check.sh camber`, compiles `camber/check.bend` to a temporary native binary and executes it, then compiles to JavaScript and executes it with Bun. Commands run sequentially. Before each command it requires at least 10 GiB free disk; it monitors the process subtree, kills its process group above 20 GiB per-process RSS or a 120-second command deadline, checks real journal contents, and removes journals/binaries.

The final gate and both actual compiled executions exited 0. Both lanes printed:

```text
COUNTS capacity=2 in_use=2 completed=0 rejected=0
COUNTS capacity=2 in_use=2 completed=0 rejected=1
SUCCESS principal=7
EXPECTED principal=8
SUCCESS principal=12
COUNTS capacity=2 in_use=0 completed=4 rejected=1
CLOSED 1
CLOSED 0
PARTIAL CLOSED
CLOSED 1
CLOSED 0
CLOSED 1
camber owner: PASS
journals/explicit closes: PASS
```

Final command receipts (sampled process-subtree peak, not a benchmark):

| Command | Exit | Peak RSS KiB observed |
| --- | ---: | ---: |
| `bash scripts/check.sh camber` | 0 | 80,944 |
| `bend camber/check.bend -o <temporary>/owner` | 0 | 182,048 |
| `<temporary>/owner` | 0 | 32 |
| `bend camber/check.bend -o <temporary>/owner.js` | 0 | 8,912 |
| `bun <temporary>/owner.js` | 0 | 40,144 |

The very short native scenario ran between RSS samples; its 32 KiB observation is not a native memory measurement. Overall runner result: `owner native/JS acceptance: PASS`. Publication dry-run: `== bend-kit-camber@0.1.0.0 will publish` (exit 0). No manual publication occurred.

## Acceptance interpretation

- Two admitted principals hold distinct bundles concurrently behind deterministic barriers. Each bundle owns two real Files; the two operations access them in opposite orders without separate checkout. Their replies retain only their own typed principal.
- A third principal receives `Exhausted` and writes no journal. Counts show both occupied bundles before and after this rejection. Active `close` returns `Busy` rather than waiting or closing held handles.
- Principal 7 succeeds and principal 8 returns an expected failure; both bundles return. A request with an already closed reply channel also completes and returns its bundle. Counts recover; principal 12 then succeeds using restored capacity.
- The runner reads both actual journals for each slot. The paired journals match exactly, and the combined identities are exactly 7, 8, 10, and 12. No rejected principal 9 appears.
- Idle close executes two bundle destructors. Partial initialization of a second File deliberately fails: the initializer closes its partial first File, and the owner closes its previously completed bundle. A separate successful owner initialization is followed by actual `TCP.listen` rejection for an invalid address, then explicit idle-owner close. The exact destructor markers above cover these three lifecycles.
- Calls after close return `Stopped`. Resource handles never appear in caller replies: output/error/principal/input types are `Data`, while the whole affine bundle returns through the private owner inbox first.

## Corrections observed during verification

The checker rejected a Base constructor collision, forward template calls, out-of-order matching, and missing affine-copy annotations; those were corrected before the final passing gates. Initial runtime verification also caught misuse of `IO.join` on reusable channels: it closes the channel after receiving one value. The owner inbox and repeated test barriers now use checked `Chan.recv`; one-shot replies retain `IO.join`. The initial native closed-reply observation bound was too fast for native File helper threads; bounded polling now yields between observations. The final native and JS runs both observed restored counts and a later successful operation.

## Proof and operational limits

The entry gate honestly reports `SOME PROOFS FAIL` for exactly `owner`, `start.ready`, and `start`, which rely on the lifecycle loop's disclosed `@unsafe`. The standard package checker accepts that exclusion. The post-close inbox drain is structurally bounded by the configured inbox room. The empty human-law inventory reports `ALL PROOFS CHECK`; this proves no Camber IO or lifecycle claim. No human-owned laws were invented or edited.

Held/stalled capacity is observed as occupied and `Busy`; this does not prove cancellation, rollback, crash containment, forced close, or indefinite scheduler responsiveness. External admission must count callers blocked submitting to the bounded inbox. Asynchronous callers supply fresh one-slot reply channels. Protocol constructors/inbox handles are not protected by Bend module privacy; callers must not forge messages or close the private inbox. This evidence does not claim the remaining HTTP framework, complete server lifecycle, or performance gates are delivered.
