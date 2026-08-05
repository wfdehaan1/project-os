---
title: 'Story 1.5: Validate Structured Output for Representative Project Work'
type: 'feature'
created: '2026-08-05'
baseline_revision: '31988e734e11be29d2afdb2628628a2fb129414e'
final_revision: '777e6b9'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: []
---

<intent-contract>

## Intent

**Problem:** The isolated App Server harness proves runtime, subscription-authentication, and allowance seams, but it has not shown that Codex can extract trustworthy non-coding ProjectOS state into a Change Proposal. A plausible response is not sufficient: adoption must be rejected when it misses governing or re-entry meaning.

**Approach:** Define a ProjectOS-owned proposal/result and scoring contract; exercise it deterministically against three pre-annotated representative fixtures through a deliberately narrow, manifest-pinned structured-output adapter path. Record only controlled, sanitized scoring evidence and fail closed on schema, completeness, quality, or safety-precondition failure.

## Boundaries & Constraints

**Always:** Reuse the immutable executable snapshot, exact schema/manifest compatibility capability, sole App Server supervisor, `experimentalApi: false`, profile isolation, credential/content sanitization, and method-specific RPC wrappers from Stories 1.1–1.4. The provider receives only an explicit Context Preview and per-turn ProjectOS Change Proposal schema; results are independently revalidated before a ProjectOS-owned coordinator can retain one pending *validation* proposal. Preserve the predeclared denominator and score precision, recall, unsupported claims, provenance, governing-state omissions, and user-correction effort by artifact type. A missing containment attestation must prevent a real child/thread/turn dispatch before it starts; fake-backed validation remains allowed.

**Block If:** The exact pinned generated schema lacks a bounded structured-output branch; a required method/result cannot be structurally parsed without raw payload/text inspection; a live run lacks a verified pre-side-effect containment capability; or sanitized evidence cannot preserve the required metric while excluding project content and sensitive data.

**Never:** Add generic RPC dispatch, raw result retention, domain-repository access, Canonical State mutation, production UI, tools/connectors/web/command execution, unapproved filesystem context, API-key fallback, or a claim that fake fixtures establish live provider quality. Do not dispatch a live quality job merely to gather evidence before Story 1.6 proves preventive containment.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Annotated fixture | Garden-office, used-car, or technical-supersession preview with predeclared expected record | Schema-valid normalized pending validation proposal and per-type quality score | Reject if the denominator is incomplete or fixture annotation is invalid |
| Completed structured reply | Allowed manifest-pinned response | Revalidate against ProjectOS schema; coordinator records at most one proposal for job/attempt | Unsupported assertion, invalid provenance, or schema mismatch is a normalized rejection |
| Stream/cancel/partial/malformed reply | Delta sequence, cancellation, truncated or malformed result | No pending proposal; safe terminal result/evidence identifies the failed gate | Discard partial state and retain no raw reply |
| Retry/duplicate completion | Duplicate or stale event for an already accepted/rejected attempt | One immutable authoritative result and no duplicate proposal | Ignore stale identity and record only safe reference |
| Quality/safety failure | Below 85%, governing/re-entry omission, missing denominator, or unavailable containment attestation | Adapter path is marked `reject`; later production work is blocked | Retain failed metric/stop condition, not source content |

</intent-contract>

## Code Map

- `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` and new `src/core/{change-proposal-schema,structured-output,quality-score,provider-job-coordinator}.ts` -- ProjectOS-owned preview, proposal, normalized outcome, idempotent validation-proposal, and scoring contracts.
- `spikes/codex-app-server-harness/src/adapters/codex/{protocol-contract,jsonl-rpc-connection,codex-app-server-adapter,runtime-compatibility}.ts` and `protocol/supported-runtime-manifest.json` -- exact-schema, method-specific constrained thread/turn surface, structural event/result parsing, and a default-deny live containment precondition.
- `spikes/codex-app-server-harness/src/evidence/structured-output-*.ts` and `evidence/structured-output-validation-run.schema.json` -- atomic sanitizer/recorder and controlled quality-gate evidence shape.
- `spikes/codex-app-server-harness/test/fixtures/representative-project-work/` and `test/fixtures/fake-codex-runtime.ts` -- the three expected-answer fixtures and deterministic structured-turn traces.
- `spikes/codex-app-server-harness/test/{structured-output,quality-score,adapter-boundary,evidence,cli,workspace}.test.ts` -- fixture, schema, retry, privacy, command, and no-generic-dispatch proof.

## Tasks & Acceptance

**Execution:**
- [x] `src/core/ai-provider-port.ts` and new core structured-output modules -- define immutable Context Preview, Change Proposal JSON Schema, normalized terminal result, scoring record, and idempotent coordinator; keep all wire types outside the port.
- [x] `protocol/supported-runtime-manifest.json`, `src/adapters/codex/protocol-contract.ts`, and `src/adapters/codex/jsonl-rpc-connection.ts` -- authorize and structurally validate only the named structured thread/turn methods and completion/delta/cancellation notifications after exact compatibility; retain generic dispatch denial.
- [x] `src/adapters/codex/codex-app-server-adapter.ts` and `runtime-compatibility.ts` -- route structured validation only through the owned child and require an opaque containment attestation for live dispatch; return a safe rejection otherwise.
- [x] `src/evidence/structured-output-*.ts` and `evidence/structured-output-validation-run.schema.json` -- write atomic, allowlisted expected-versus-actual metrics and reject credentials, identities, raw content, prompts/results, payloads, URLs, and paths.
- [x] `test/fixtures/representative-project-work/`, fake-runtime fixtures, and focused structured-output/quality tests -- pre-annotate all three domains and deterministically cover matrix variants, per-type scoring, denominator, provenance, governing/re-entry omissions, and duplicate-free retry.
- [x] `test/adapter-boundary.test.ts`, `test/cli.test.ts`, `test/workspace.test.ts`, `package.json`, `README.md`, and `evidence/README.md` -- prove the narrow boundary and add offline `test:structured-output`/`validate:structured-output`; add an opt-in live command that fails closed without containment and is excluded from defaults.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` and this spec -- truthfully record implementation, evidence, reject/blocked outcome, and changed files.

**Acceptance Criteria:**
- Given the three required domains, when their fixtures are finalized before execution, then each exercises Facts, Decisions, Research, Open Questions, Tasks, relationships, provenance, expected governing effects, and a fixed evaluated-item denominator.
- Given an annotated preview, when a constrained structured job completes, then only a schema-revalidated normalized result can become one pending validation proposal and it contains no unrelated project or filesystem context.
- Given every artifact type is scored, when the quality gate evaluates its controlled evidence, then it keeps separate precision and recall, unsupported claims, provenance quality, governing-state omissions, correction effort, and the 85-percent threshold without exposing raw project content.
- Given streaming, cancellation, partial/malformed output, retry, or duplicate completion, when the coordinator processes it, then partial/malformed output never persists and stale events cannot add or replace a proposal.
- Given any score, denominator, omission, malformed-output, or containment-precondition failure, when validation concludes, then the adapter path records `reject` with the failed metric/stop condition and does not enable later production work.

## Review Triage Log

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 9 (high 4, medium 5, low 0)
- defer: 0
- reject: 0
- addressed_findings:
  - `[high]` `[patch]` Connected fixture-specific fake execution to normalization, scoring, and coordinator persistence; added rich pre-annotated ground truth so metadata-only fixtures cannot pass.
  - `[high]` `[patch]` Deep-cloned and froze accepted terminal proposals, required typed preview provenance, and rejected cross-job completion input to prevent altered or misclassified pending proposals.
  - `[high]` `[patch]` Strictly allowlisted nested metric evidence fields and values; evidence-write failure now returns a distinct safe no-dispatch rejection.
  - `[medium]` `[patch]` Made false positives lower the quality score, validated incoming score shape, and deep-froze the structured manifest capability.

## Design Notes

The Story 1.5 live-quality gate is deliberately contingent on preventive containment, which Story 1.6 must prove. Its safe default is therefore a deterministic fake-backed result or a `reject` outcome before any provider turn—not a bypass of the later hard gate. The protocol expansion is a named structured-validation capability, never a reusable chat/agent transport.

## Verification

**Commands:**
- `npm run typecheck` -- expected: strict TypeScript passes.
- `npm run validate:protocol` -- expected: the exact manifest and default-deny protocol boundary still pass.
- `npm run test:structured-output` -- expected: all three fake fixtures, malformed/partial/retry paths, scoring, privacy, and coordinator tests pass offline.
- `npm run validate:structured-output` -- expected: typecheck plus the focused offline suite pass.
- `npm test` -- expected: all offline harness tests pass; no live provider process is started.
- `git diff --check` -- expected: no whitespace errors.

## Auto Run Result

Status: done

Implementation is fake-backed and offline only. The committed protocol manifest declares the bounded structured thread/turn capability, but `structured-output-validate` rejects before discovery, spawn, thread, or turn dispatch because Story 1.6 has not supplied a preventive containment attestation. This is a required `reject` gate outcome, not evidence of live provider quality.

Validation completed on 2026-08-05:

- `npm run typecheck` — passed.
- `npm run validate:protocol` — passed (97 tests).
- `npm run validate:structured-output` — passed (16 tests).
- `npm test` — passed (140 tests; 4 explicit live tests skipped).
- `git diff --check` — passed.

Changed implementation areas: core proposal/schema/scoring/coordinator modules; structured metric evidence; bounded manifest/protocol declaration; safe CLI rejection; three annotated fixtures with fixture-specific fake integration; focused tests; harness/evidence documentation and scripts. Follow-up review hardened typed provenance, deep immutability, cross-job rejection, false-positive scoring, strict nested metric allowlisting, evidence-write failure reporting, and manifest deep freezing.

Review: 9 review-driven patches applied; 0 deferred; 0 rejected. Follow-up review recommendation: false; the final repair pass was covered by focused and full offline regression suites.

Residual risk: live provider quality remains intentionally unproven and the adapter path stays `reject` until Story 1.6 supplies preventive containment evidence. This run did not start a live provider process.
