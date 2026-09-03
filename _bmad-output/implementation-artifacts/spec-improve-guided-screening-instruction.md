---
title: 'Improve guided listing-screening instruction'
type: 'bugfix'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
baseline_commit: '1d7d5c4541195f19059410a6ea034f7bd62b1b61'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The guided Foundation Models run improved formatting and latency, but warranty answers remained unsafe: silent listings were classified as `no`, included warranty was sometimes reversed to `no`, evidence was fabricated, and `unknown` often carried non-null evidence. The generic property guidance does not explain the warranty decision boundary or the exact evidence contract strongly enough.

**Approach:** Strengthen only the guided-generation instructions with an explicit evidence-first decision procedure and warranty-specific rules derived from the grading failures. Keep the corpus, labels, grading thresholds, free-form prompt, and recorded result files unchanged so a rerun remains comparable.

## Boundaries & Constraints

**Always:** Preserve the three-valued answer contract. Require explicit input evidence before `yes` or `no`; absence is `unknown`. For `warranty_included`, distinguish included/default warranty (`yes`) from optional, extra-cost, or explicitly excluded warranty (`no`), treat contradictions as `unknown`, and do not treat `warrantyExists` alone as proof of price inclusion or exclusion. Require a short, exact, contiguous input span for non-unknown evidence and `nil` for `unknown`.

**Ask First:** Any proposal to change labels, expected answers, criterion semantics, grader classification, corpus contents, or to post-process model decisions into different values.

**Never:** Tune against listing IDs or copy corpus-specific answers into the instruction; silently coerce an invalid model decision into a valid one; claim guided output is schema-safe when the generated type cannot encode the `unknown`/evidence dependency; overwrite the user's `Package.swift` change or prior response files.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Included warranty | Text says the standard/included delivery has warranty | `yes` with an exact supporting span | No inference from unrelated maintenance text |
| Extra-cost warranty | Warranty exists only in an optional paid package or price explicitly excludes it | `no` with an exact supporting span | Do not confuse availability with inclusion |
| Silent listing | No text explicitly establishes warranty inclusion or exclusion, including `warrantyExists: false` alone | `unknown`, evidence `nil` | Absence must not become `no` |
| Contradictory listing | Input contains credible included and excluded claims | `unknown`, evidence `nil` | Do not select one side |
| Unknown evidence | Model abstains | `unknown`, evidence `nil`, never `"unknown"` or `"null"` | Remains visibly invalid if the model violates the contract |

</frozen-after-approval>

## Code Map

- `spikes/listing-screening/runner/Sources/screen/main.swift` -- guided `@Generable` answer descriptions and session instructions.
- `spikes/listing-screening/src/criteria.ts` -- authoritative warranty question semantics that guided wording must preserve.
- `spikes/listing-screening/src/schema.ts` -- strict cross-field evidence invariant used by the grader.
- `spikes/listing-screening/README.md` -- experiment interpretation and currently overstated guided-schema claim.
- `spikes/listing-screening/responses-guided.jsonl` -- observed failures used as diagnostic evidence; must remain unchanged.

## Tasks & Acceptance

**Execution:**
- [x] `spikes/listing-screening/runner/Sources/screen/main.swift` -- add concise guided-only decision instructions and tighten `@Guide` descriptions around warranty polarity, abstention, and exact evidence.
- [x] `spikes/listing-screening/README.md` and runner comments -- correct the claim that all schema violations are impossible, because the generated type permits `unknown` plus a string.

**Acceptance Criteria:**
- Given guided generation for a silent warranty listing, when the instruction is read, then it explicitly requires `unknown` and forbids using `warrantyExists` alone as proof.
- Given included, paid-optional, and contradictory warranty language, when the instruction is read, then it maps those cases respectively to `yes`, `no`, and `unknown`.
- Given any non-unknown answer, when evidence is generated, then the instruction requires a short exact contiguous span from the supplied input and forbids paraphrase, translation, or invented text.
- Given an `unknown` answer, when evidence is generated, then the instruction requires Swift `nil` rather than a textual placeholder.
- Given the changed Swift runner, when it is built and the existing TypeScript tests run, then both checks pass without changing corpus, labels, fixtures, or recorded responses.

## Spec Change Log

## Design Notes

The instruction should follow the model's decision order: first locate decisive text, then classify it, otherwise abstain. Warranty wording needs a compact decision table because the observed model treated a missing/false structured flag as explicit exclusion and reversed phrases such as `Standaard (inbegrepen)`. The instruction improves behavior but does not hide violations; dependent schema enforcement or serialization hardening is separate work.

## Verification

**Commands:**
- `cd spikes/listing-screening && npm test` -- expected: all TypeScript tests pass.
- `cd spikes/listing-screening/runner && swift build` -- expected: the Foundation Models runner compiles on the current macOS SDK.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks:**
- Inspect the diff to confirm only guided instructions and truthful explanatory documentation changed, with `Package.swift` preserved.

## Suggested Review Order

**Guided decision behavior**

- Start with the evidence-first contract applied to every guided answer.
  [`main.swift:61`](../../spikes/listing-screening/runner/Sources/screen/main.swift#L61)

- Review warranty polarity, abstention, and multiple-tier handling.
  [`main.swift:68`](../../spikes/listing-screening/runner/Sources/screen/main.swift#L68)

- Confirm warranty guidance is isolated and free-form instructions remain unchanged.
  [`main.swift:109`](../../spikes/listing-screening/runner/Sources/screen/main.swift#L109)

**Experiment interpretation**

- Verify documentation accurately describes guided schema limits and the changed variable.
  [`README.md:120`](../../spikes/listing-screening/README.md#L120)

- Review follow-up harness risks intentionally kept outside this change.
  [`deferred-work.md:1`](deferred-work.md#L1)

**Build compatibility**

- Note the preserved user-authored Swift tools-version update used by verification.
  [`Package.swift:1`](../../spikes/listing-screening/runner/Package.swift#L1)
