---
title: 'Story 1.4: Normalize Allowance Failures and Terminal Job Outcomes'
type: 'feature'
created: '2026-08-04'
baseline_revision: 'b347d55'
final_revision: '38b57ea'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: []
---

<intent-contract>

## Intent

**Problem:** The isolated App Server harness can validate runtime compatibility and managed authentication, but it has no provider-neutral allowance/failure contract or deterministic job-outcome reducer. Without one, later work could expose vendor wording, misrepresent subscription availability, or create conflicting terminal job results.

**Approach:** Add a manifest-pinned, credential-free allowance read and a pure ProjectOS-owned event reducer. Normalize only explicit protocol signals into safe diagnostics and prove, through fake trace replay, that each durable job has exactly one authoritative terminal outcome.

## Boundaries & Constraints

**Always:** Reuse the immutable executable snapshot, exact schema match, `experimentalApi: false`, compatibility capability, and sole supervisor spawn/process-group cleanup path. Keep method-specific wrappers and explicit allowlists; the ordinary protocol boundary remains initialize-only. Preserve every provider-returned allowance bucket's used percentage, window duration, reset timestamp, and reached-limit classification without inventing a weekly interval. Every normalized event carries a ProjectOS `jobId`, `providerInstanceId`, deterministic provider sequence, and attempt number. Map failures only from an exact pinned structural signal: allowance exhaustion, rate limiting, authentication expiry, network loss, upstream failure, runtime failure, or an explicit retry; otherwise retain `providerFailed` or `unknown`, never parsed text. Persist evidence and diagnostics using only normalized category/code, retry/remedy, safe allowance values, runtime version, timestamps, correlation/job/attempt IDs, and a diagnostic reference.

**Block If:** The exact matched generated schema cannot support a bounded, safe rate-limit request/notification parser; an essential normalized category would require inspecting provider text or raw payloads; or a required test demonstrates a credential, account identifier, project content, prompt/result, raw payload, URL, or local path can survive retention.

**Never:** Construct, receive, persist, log, export, or inspect credentials, account data, API credits, top-up/purchase options, API keys, authorization headers, raw provider errors, or provider event names/types at the port boundary. Do not add generic RPC dispatch, token refresh, real thread/turn/provider work, tool dispatch, proposal persistence, Canonical State changes, production UI, or a claim that fake replay proves a live subscription allowance.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|----------------------------|----------------|
| Allowance available | Exact matched rate-limit response with one or more buckets | Immutable normalized buckets and `available` provider readiness; local work remains available | Reject malformed/unpinned shapes |
| Allowance exhausted | Explicit provider limit/exhaustion signal with reset/remedy data | `temporarily_unavailable`; preserve safe reset/remedy and never suggest API fallback | Classify only the structural signal |
| Explicit provider failure | Exact rate-limit, auth-expiry, network, upstream, runtime, or retry signal | Credential-free normalized failure envelope with correlation ID and retryability | Ambiguity becomes `providerFailed` or `unknown` |
| Duplicate or cross-job event | Replayed event identity is already seen, targets another job, or has stale attempt/sequence | Ignore it; no terminal replacement | Retain no raw event |
| Cancellation race and retry | Cancellation request competes with completion/failure, timeout, or child death; retry begins a newer attempt | Cancellation remains requested until acknowledgement; provider terminal observed before cancellation acknowledgement wins; newer attempt becomes authoritative and stale events are ignored | Reducer emits one final terminal outcome only |
| Post-terminal arrival | Late completion/failure/cancellation after a terminal result | Preserve the first authoritative terminal result | Record safe diagnostic reference only |

</intent-contract>

## Code Map

- `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` and `src/core/failures.ts` -- ProjectOS-owned allowance, readiness, normalized failure, remediation, and job-outcome contract seam.
- `spikes/codex-app-server-harness/src/core/` -- new pure allowance/event/reducer modules; process lifecycle remains separate.
- `spikes/codex-app-server-harness/src/adapters/codex/{protocol-contract.ts,jsonl-rpc-connection.ts,codex-app-server-adapter.ts,app-server-supervisor.ts,runtime-compatibility.ts}` -- exact allowance-only protocol boundary and the existing one-child validation lifecycle.
- `spikes/codex-app-server-harness/protocol/supported-runtime-manifest.json` -- exact runtime method/schema contract, including the pinned rate-limit surface.
- `spikes/codex-app-server-harness/src/evidence/` and `evidence/` -- versioned sanitized diagnostic schema, atomic writer, sanitizer, and retention guidance.
- `spikes/codex-app-server-harness/test/` -- fake rate-limit/error/event traces and focused contract, reducer, evidence, boundary, and CLI coverage.

## Tasks & Acceptance

**Execution:**
- [x] `src/core/ai-provider-port.ts`, `src/core/failures.ts`, `src/core/allowance.ts`, and `src/core/job-outcome-reducer.ts` -- define immutable ProjectOS-owned allowance buckets, availability, lossless normalized-failure envelope, safe remedies, durable job event identity, and terminal result types; keep all provider wire shapes outside the port.
- [x] `src/core/job-outcome-reducer.ts`, `test/core-contract.test.ts`, and `test/job-outcome-reducer.test.ts` -- implement and exhaustively replay a pure deterministic reducer with event deduplication, per-instance sequence/attempt ordering, cancellation acknowledgement, retry authority, and exactly-one-terminal-result traces.
- [x] `protocol/supported-runtime-manifest.json`, `src/adapters/codex/protocol-contract.ts`, `src/adapters/codex/jsonl-rpc-connection.ts`, and `test/protocol-contract.test.ts` -- pin and structurally validate only the allowance read/update surface from the same generated schema; expose a method-specific wrapper and forbid all turn/tool/generic dispatch.
- [x] `src/adapters/codex/codex-app-server-adapter.ts`, `app-server-supervisor.ts`, and `runtime-compatibility.ts` -- add a bounded compatibility-authorized allowance-validation mode using the sole owned child, normalize explicit signals, and surface temporary provider unavailability without enabling provider or Canonical State actions.
- [x] `src/evidence/allowance-evidence-schema.ts`, `src/evidence/allowance-evidence-sanitizer.ts`, `src/evidence/allowance-evidence-recorder.ts`, `evidence/allowance-validation-run.schema.json`, `test/evidence.test.ts`, and `test/adapter-boundary.test.ts` -- atomically retain only the diagnostic allowlist and prove secret/content/path/provider-type canaries are rejected.
- [x] `test/fixtures/fake-codex-runtime.ts`, `test/fixtures/fake-runtime-manifest.ts`, `test/fixtures/fake-protocol-schema-bundle.ts`, `test/allowance.test.ts`, `test/cli.test.ts`, `package.json`, `README.md`, and `evidence/README.md` -- add deterministic traces for every matrix row, `test:allowance`/`validate:allowance` offline commands, and an explicitly opt-in `test:allowance:live` command that is excluded from defaults.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` and this spec -- record implementation/review progress, executed evidence, changed files, and any reject/blocked outcome truthfully.

**Acceptance Criteria:**
- Given an exact compatible runtime returns rate-limit buckets, when allowance validation runs, then each bucket preserves reported usage, window, reset, and reached classification without a hard-coded weekly model.
- Given an explicit exhausted-allowance signal, when ProjectOS derives provider readiness, then it returns `temporarily_unavailable` with a safe reset/remedy while local ProjectOS capability remains available and no API-credit fallback is offered.
- Given every supported explicit error signal and an ambiguous one, when normalization runs, then supported categories retain only safe structured fields and ambiguity maps to `providerFailed` or `unknown` without message inspection.
- Given duplicate, delayed, reordered, cross-job, cancellation-race, timeout/retry, duplicate-completion, and child-death traces, when the shared reducer replays them, then each job has one immutable authoritative terminal outcome and stale events cannot replace it.
- Given any diagnostic or retained evidence, when sanitizer and boundary audits run, then it excludes credentials, account data, content, prompts/results, raw payloads, provider event types, URLs, and local paths.

## Design Notes

The reducer is a fake-backed harness contract, not a provider-job implementation. Its ordering key is `(providerInstanceId, jobId, attempt, sequence)`; retry creates the authoritative newer attempt, while a cancellation request is non-terminal until its explicit acknowledgement. This yields deterministic replay without claiming that Story 1.4 can safely dispatch turns before the containment and structured-output gates.

## Verification

**Commands:**
- `npm run typecheck` -- expected: strict TypeScript passes.
- `npm test` -- expected: all existing plus deterministic allowance, normalization, reducer, privacy, and boundary tests pass without a live account.
- `npm run validate:protocol` -- expected: exact manifest/schema and restricted protocol boundaries remain fail-closed.
- New focused offline allowance command -- expected: Story 1.4 fake traces and evidence canaries pass.
- New explicitly opt-in live allowance command -- expected: only after user action and eligible managed sign-in, structural allowance evidence is retained without sensitive data; never run by default.

## Review Triage Log

### 2026-08-04 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 9 (high 5, medium 3, low 1)
- defer: 0
- reject: 3
- addressed_findings:
  - `[high]` `[patch]` Reject empty or impossible rate-limit buckets and retain the latest reached reset across exhausted buckets.
  - `[high]` `[patch]` Preserve one immutable terminal outcome; a late retry cannot revive a completed job.
  - `[high]` `[patch]` Map structural allowance RPC errors to provider failure and retain client request IDs accurately.
  - `[high]` `[patch]` Enforce safe allowance constraints and path rejection again at the evidence boundary.
  - `[medium]` `[patch]` Bound invalid allowance timeouts and report allowance-evidence write failures distinctly.
  - `[low]` `[patch]` Add the structural client request-ID class to the protocol evidence contract.

## Auto Run Result

Status: done

- Summary: Added a credential-free, manifest-pinned allowance validation mode and ProjectOS-owned terminal job reducer without enabling provider turns, tools, or Canonical State operations.
- Files changed: Core allowance/failure/reducer contracts; method-specific Codex allowance boundary and adapter lifecycle; sanitized allowance evidence; fake fixtures; deterministic tests and opt-in docs/scripts; sprint tracking.
- Review: 9 patches applied, 0 deferred, 3 rejected as review-input or non-reachable concerns.
- Follow-up review recommendation: true. The review changed terminality, provider-failure classification, and retained-diagnostic privacy behavior.
- Verification: `npm run typecheck` passed; `npm run validate:protocol` passed (96 tests); `npm test` had one intermittent parallel authentication EOF, while its isolated suite passed 13/13 immediately afterward; `git diff --check` passed.
- Residual risk: live allowance validation remains deliberately opt-in and was not run; deterministic fake evidence cannot establish a real subscription's current allowance.
