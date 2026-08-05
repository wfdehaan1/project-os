---
title: 'Story 1.8: Prove Crash-Safe Provider Session Cleanup'
type: 'feature'
created: '2026-08-05'
baseline_revision: 'c3bd4f5a8a18666dfcfa0bf62aaf1c3571f70406'
status: 'in-review'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/spec-1-7-prove-portable-conversation-ownership-and-restore-separation.md'
warnings: []
---

<intent-contract>

## Intent

**Problem:** A ProjectOS-owned Conversation may have an opaque Codex session binding, but the harness has no durable, crash-safe record that can prove every managed session is eventually deleted, absent, or truthfully pending. Deleting local Project content alone must not become a false claim about provider retention.

**Approach:** Add a deterministic, private, content-free cleanup outbox and coordinator that records an obligation before a fake provider session can be created, survives reload/reconciliation at every interruption boundary, and emits structural evidence plus an explicit gate result. The existing containment rejection means this is an offline state-machine and fake-filesystem proof; it must report `reject` rather than claim a live Codex deletion proof.

## Boundaries & Constraints

**Always:** Persist an exact-shape obligation before the simulated external creation effect. Retain only adapter ID, ProjectOS provider-profile ID, a non-secret authentication-context fingerprint, opaque provider-session ID when known, lifecycle state, retry count, timestamps, and a minimal terminal receipt; never retain project content, canonical IDs, binding/context-preview IDs, credential material, account identity, prompts, results, transcripts, Sources, local paths, raw payloads, or provider metadata. Reconciliation is idempotent, ledger-conserving, and matching-context only; `absent` is a successful terminal result while an unavailable/renamed adapter or context mismatch remains recoverable. Local deletion and provider cleanup are separate outcomes, and portable export/restore retains neither the outbox nor receipts.

**Block If:** The deterministic fake cannot enumerate managed session records and remove their associated fake rollout metadata at every crash boundary. A real Codex list/delete proof would require widening the frozen protocol boundary or lifting Story 1.6 containment; HALT rather than make either change unattended. The known unproven live contract is instead the required `reject` stop condition for this offline story.

**Never:** Expand generic RPC dispatch, alter the frozen protocol manifest, perform live App Server thread operations, create a turn/generation, authenticate interactively, transmit or reconstruct Project content, add production persistence/UI, store the outbox in Project-owned portable state, or treat independent provider backups/user exports as deletable.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pre-create crash | Durable `create_intent`; process dies before/after fake create and before binding | Restart retains the obligation, enumerates only managed fake sessions, binds discovered handle or leaves a truthful pending obligation | Unknown possible creation is never marked complete |
| Retire and local deletion | One binding or many bindings; local Project erase commits before cleanup | Canonical content/bindings are removed; each minimal receipt remains and cleanup runs independently | Failed/offline deletion increments retry state without restoring content |
| Retry and context change | Restart, duplicate retry, already-absent session, missing/renamed adapter, or switched authentication fingerprint | Reconcile is repeatable; `absent` receives a terminal receipt; matching-context work deletes sessions and rollout metadata | Mismatch/unavailable state becomes `reauth_required` or `delete_pending` with residual-data disclosure |
| Evidence and gate | Fixture has complete cleanup, failed metadata removal, and blocked live contract | Atomic sanitized evidence gives aggregate accounting and the validation conclusion is `reject` while containment is unavailable | Canaries or write failure publish no unsafe/partial evidence |

</intent-contract>

## Code Map

- `spikes/codex-app-server-harness/src/core/conversation-ownership.ts` and `src/core/project-{export,restore}.ts` -- existing opaque binding and portable-boundary invariants; preserve their exclusion rules.
- `spikes/codex-app-server-harness/src/core/provider-cleanup-outbox.ts` and `src/core/provider-session-cleanup.ts` -- new strict durable obligation/receipt model, atomic private store, lifecycle reducer, local-deletion separation, and reload reconciliation.
- `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` -- provider-neutral, cleanup-only fake capability contract; it must not become job dispatch.
- `spikes/codex-app-server-harness/src/evidence/provider-cleanup-evidence-{schema,recorder}.ts` and `evidence/provider-cleanup-validation-run.schema.json` -- sanitized aggregate evidence, atomic publication, and explicit `reject`/stop-condition result.
- `spikes/codex-app-server-harness/test/{provider-cleanup-outbox,provider-session-cleanup,provider-cleanup-evidence}.test.ts` -- deterministic lifecycle, crash, fake filesystem, omission, idempotence, sanitizer, and accounting proof.
- `spikes/codex-app-server-harness/test/{conversation-ownership,project-export-restore,adapter-boundary,cli,workspace}.test.ts` -- preserve non-portability, no generation/provider dispatch, command safety, and private-root guarantees.
- `spikes/codex-app-server-harness/{src/cli.ts,package.json,README.md,evidence/README.md}` and `_bmad-output/implementation-artifacts/sprint-status.yaml` -- focused offline validation entry point, limitation/stop condition, evidence documentation, and accurate Story status.

## Tasks & Acceptance

**Execution:**
- [x] `spikes/codex-app-server-harness/src/core/provider-cleanup-outbox.ts` and `src/core/provider-session-cleanup.ts` -- implement strict content-free records, private atomic durable storage, allowed transitions (`create_intent`, `bound`, `retired`, `delete_pending`, `reauth_required`, `confirmed`, `absent`), and an injected fake-provider reconciliation coordinator so every created handle is accounted for across simulated crashes.
- [x] `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` -- add only a provider-neutral cleanup/list/delete result boundary with explicit managed-source filtering and context matching; preserve the validation-only dispatch boundary.
- [x] `spikes/codex-app-server-harness/src/evidence/provider-cleanup-evidence-schema.ts`, `src/evidence/provider-cleanup-evidence-recorder.ts`, and `evidence/provider-cleanup-validation-run.schema.json` -- publish atomic, structural-only aggregate evidence and a durable gate decision; reject content/identity/path/session canaries before publication.
- [x] `spikes/codex-app-server-harness/test/{provider-cleanup-outbox,provider-session-cleanup,provider-cleanup-evidence}.test.ts` -- cover every matrix path, all local/external failpoints, multi-binding deletion, duplicate/lost-response retry, absent, adapter/context loss, metadata-removal failure, receipt exclusion, and no forgotten fake session.
- [x] `spikes/codex-app-server-harness/test/{conversation-ownership,project-export-restore,adapter-boundary,cli,workspace}.test.ts` -- assert the outbox is not portable Project state, no cleanup path can generate/transmit content or widen Codex dispatch, and all disk artifacts are private/sanitized.
- [x] `spikes/codex-app-server-harness/{src/cli.ts,package.json,README.md,evidence/README.md}` and `_bmad-output/implementation-artifacts/sprint-status.yaml` -- add the focused fake-backed validation command; document that the unproven manifest-pinned live list/delete path and Story 1.6 containment force a `reject` conclusion.

**Acceptance Criteria:**
- Given a cleanup obligation is stored before a managed session creation, when a simulated crash occurs at any local or external effect boundary, then reload reconciliation reaches `confirmed`/`absent` or retains an explicit pending obligation without forgetting a created fake session.
- Given local Project deletion and pending provider cleanup, when the local erase commits, then Project content and ordinary bindings disappear while the minimal receipt survives, and the two outcomes are independently truthful.
- Given retries encounter an offline provider, adapter rename/removal, authentication-context change, duplicate invocation, or an already-absent session, when reconciliation runs after restart, then no Project content is restored or resent and only matching-context cleanup can become terminal.
- Given the focused audit fixture completes and the live pinned list/delete contract remains unproven under containment, when evidence is published, then every fake-created session has a terminal or pending ledger entry, evidence contains only sanitized aggregates, and the Story records `reject` with its stop condition.

## Spec Change Log

## Review Triage Log

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 12 (high 10, medium 2)
- defer: 0
- reject: 0
- addressed_findings:
  - `[high]` `[patch]` Reconciliation now retains active bindings, binds a discovered post-crash session before deleting only after a local-erasure fact, and preserves unknown pre-create intent on a list failure.
  - `[high]` `[patch]` Added managed-source/profile/context/handle agreement checks, complete-list gating, and profile-scoped fake records so a malformed or partial response cannot terminalize another session.
  - `[high]` `[patch]` Hardened durable publication with directory sync, stale-handle merge protection, monotonic transition time, and a regression that preserves independent intents from stale handles.
  - `[high]` `[patch]` Added explicit local-erasure completion hook, multi-binding cleanup, lost-delete-response, adapter-rename, absent, and metadata-removal coverage; this prevents a cleanup receipt from outrunning the separate local outcome.
  - `[medium]` `[patch]` Made the fake audit derive ledger gaps from persistent created-session accounting instead of a hard-coded zero.
  - `[medium]` `[patch]` Kept the fake-only create capability internal to the cleanup module so the provider-neutral port remains list/delete-only.

## Design Notes

The cleanup receipt is not shareable evidence and is not Project state. It is a private continuity record that survives the intentional erasure of local Project content; published evidence reports only aggregate counts/digests and cannot become a provider reattachment capability. A fake provider filesystem makes both session enumeration and rollout-metadata removal deterministic, while the final gate accurately separates that state-machine proof from an unapproved live Codex action.

## Verification

**Commands:**
- `npm run typecheck` -- expected: strict TypeScript passes.
- `npm run test:provider-cleanup` -- expected: deterministic lifecycle, failpoint, fake-filesystem, privacy, and boundary tests pass without provider calls.
- `npm run validate:provider-cleanup` -- expected: typecheck plus the focused cleanup suite passes and writes only sanitized evidence.
- `npm run validate:conversation-ownership` -- expected: portable export/restore remains binding- and receipt-free.
- `npm run validate:protocol` -- expected: pinned manifest and default-deny/containment-era protocol boundary remain unchanged.
- `npm test` -- expected: full offline harness regression passes; live probes remain opt-in/skipped.
- `git diff --check` -- expected: no whitespace errors.
