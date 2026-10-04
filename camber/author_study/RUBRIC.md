# Independent author rubric

Two single-author runs are a case study, not a statistical model ranking. Grok uses `xai-oauth/grok-4.7`; Opus uses `cursor/claude-opus-5-5`. Preserve requested selector, resolved provider/model, and whether the serving backend independently attests that identity. A catalog or local selector is not backend attestation. No Anthropic direct inference is permitted.

Both authors receive the same task, type contract, laws, guide, and compiling example. Their writable paths and model bindings differ. They have file tools only. The host runs one guarded Bend process at a time and returns exact diagnostics for at most two repair rounds; no human implementation fixes are applied to author submissions. Judge round zero separately from the final round.

## Gates

1. Integrity: fixed files unchanged; only assigned app/domain/proof files edited; no unsafe/unproved proof dependencies; endpoint uses production domain functions and the canonical prepared table.
2. Compile: all submitted implementation terms type-check and native driver builds.
3. Runtime: every fixed case passes exact status/body/headers/lifecycle, public-field projection, journal contents, and real returned-File read/close checks. A build alone earns no runtime credit.
4. Proof: all four universal laws close over production functions. Record checker and, when supported, independent verdict results separately.
5. Sensitivity: mutations that preserve unpublished status and leak the secret must be caught by corresponding proofs and runtime cases. Keep originals immutable; mutations run on copies.

Report pass/fail/not reached per gate, with commands, outputs, elapsed time, sampled peak RSS, and failures retained. A submission with any failed semantic gate is not correct; do not average failures into a flattering overall score.

## Ergonomics observations

Count initial/final successful scenarios, compiler/proof repair rounds, and author-reported assumptions. Review raw transcripts for guessed API facts, duplicated routing decisions, ownership/signature adapters, framework-internal edits, law weakening, and disconnected proof models. Give evidence for each observation. Do not treat line count as quality or infer time spent thinking from tool gaps.

Distinguish author errors, unclear task material, current surface friction, and compiler limitations. Proposed interface changes require an observed failure or repeated workaround, not aesthetic preference. Affine typing and pure proofs do not establish IO cleanup, network behavior, crash containment, or production readiness.
