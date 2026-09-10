---
title: 'Improve guided screening baseline accuracy'
type: 'bugfix'
created: '2026-09-03'
status: 'in-review'
review_loop_iteration: 0
baseline_commit: '91749ea87fdfa74b0eab6faa24778f642364e9d4'
context:
  - '{project-root}/_bmad-output/planning-artifacts/product-direction-exploration-2026-09-02.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `responses-guided-v5.jsonl` is structurally valid but fails the fixed warranty baseline: `full` scores 6/17 correct with zero hallucinations; `text_only` scores 8/17 with one. It over-abstains on explicit warranty language, reverses one paid-package case, and fabricates two citations.

**Approach:** Make guided inference criterion-focused and align its generated cases with the warranty decision boundary. Remove incompatible free-form serialization instructions, exclude distracting fields, use stable sampling, and grade a fresh untouched run against the existing gate.

## Boundaries & Constraints

**Always:** Preserve D10's three-valued contract and D16's fixed bar: both modes independently need at least 9/17 correct warranty answers and at most two hallucinations. Preserve corpus, labels, criterion meanings, verbatim seller text, exact-quote evidence, fresh sessions, and the structural value/evidence invariant. Include only structured fields relevant to the active criterion. Keep live-run provenance and failure diagnostics.

**Ask First:** Changes to labels, corpus, baselines, grading, gate, criterion semantics, generated decisions after inference, or calls-per-criterion. Also ask before treating fabricated evidence as trustworthy.

**Never:** Tune against listing IDs or expected answers; infer from make/model/trim; treat missing fields as negative evidence; overwrite old responses; or use mock output as live proof.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Included warranty | Delivery claim, included/default package, or warranty label establishes qualifying warranty | `yes` plus exact span | Optional higher tier does not negate included coverage |
| Excluded/conditional | Price excludes it, or it is only optional, negotiable, or extra-cost | `no` plus exact span | Paid package contents do not imply inclusion |
| Silent or statutory-only listing | No qualifying warranty statement, or only statutory warranty | `unknown` with no evidence | Missing/false structured fields are not evidence |
| Conflicting listing | Credible inclusion claims disagree | `unknown` with no evidence | Included plus optional tiers alone are not conflict |
| Guided serialization | Model returns a semantic decision | Inject criterion and encode valid wire JSON | Record model errors for grading |

</frozen-after-approval>

## Code Map

- `spikes/listing-screening/src/prompt.ts` -- criterion/mode evidence and free-form prompting.
- `spikes/listing-screening/runner/Sources/screen/main.swift` -- guided generation and serialization.
- `spikes/listing-screening/src/grade.ts`, `src/run.ts` -- evidence checks and fixed gate.
- `spikes/listing-screening/test/grade.test.ts` -- prompt/evidence/gate regressions.
- `spikes/listing-screening/README.md` -- experiment method and interpretation.

## Tasks & Acceptance

**Execution:**
- [x] `spikes/listing-screening/src/prompt.ts`, `test/grade.test.ts` -- restrict structured evidence to active-criterion fields, omit absence markers, and test that neither unrelated facts nor the question become warranty evidence.
- [x] `spikes/listing-screening/runner/Sources/screen/main.swift` -- use concise guided-only instructions, semantic cases with structural evidence payloads, and stable sampling; leave free-form behavior unchanged.
- [x] `spikes/listing-screening/src/grade.ts`, `src/run.ts` -- preserve the fixed gate and exact-evidence boundary; fail closed on incomplete modes.
- [x] `spikes/listing-screening/README.md` -- document the controlled variable, fresh result, and outcome without rewriting history.
- [x] `spikes/listing-screening/responses-guided-v9.jsonl` -- run the live guided path and grade untouched local evidence.

**Acceptance Criteria:**
- Given a guided session, when constructed, then it excludes free-form JSON instructions while its type enforces value/evidence dependency.
- Given full-mode warranty input, when assembled, then unrelated and unreliable fields are absent and seller text is verbatim.
- Given the changes, when static checks, tests, build, and whitespace checks run, then all pass.
- Given a fresh live run, when graded unchanged, then both modes pass 9/17 with at most two hallucinations and no schema violations; fabricated quotes remain visible and block a trust claim.

## Spec Change Log

## Design Notes

Generated cases should express included, excluded/conditional, or unresolved before mapping to wire values. Greedy sampling makes runs comparable; it does not permit retrying until chance produces a pass.

The final untouched `v9` run passes the fixed value gate in both modes at 13/17 correct with two hallucinations, zero wrong-direction answers, two over-abstentions, zero schema violations, and zero runner errors. Five fabricated warranty quotes per mode remain visible, so the result improves value accuracy but does not authorize D16 or a shipping trust claim.

## Verification

**Commands:**
- `cd spikes/listing-screening && npm run validate` -- expected: all checks and baselines pass.
- `cd spikes/listing-screening/runner && swift build` -- expected: runner compiles.
- `cd spikes/listing-screening && npm run emit` -- expected: 102 focused prompts.
- `cd spikes/listing-screening/runner && swift run screen --guided ../fixtures/prompts.jsonl > ../responses-guided-v9.jsonl` -- observed: 102 live records, no dropped errors.
- `cd spikes/listing-screening && npm run grade -- responses-guided-v9.jsonl` -- observed: `screening gate: ACCEPT`, no schema violations, five fabricated warranty quotes per mode reported.
- `git diff --check` -- expected: no whitespace errors.
