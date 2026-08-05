---
title: 'Story 1.7: Prove Portable Conversation Ownership and Restore Separation'
type: 'feature'
created: '2026-08-05'
baseline_revision: 'bef561233d285a90da823424b143be4f345d6ffe'
status: 'in-review'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md'
warnings: []
---

<intent-contract>

## Intent

**Problem:** The disposable harness proves runtime compatibility, credential separation, allowance normalization, structured-output validation, and containment rejection, but it has no local Conversation, replaceable Provider Session Binding, or export/restore model. Without a narrow proof of those boundaries, a future Codex thread could become the de facto record of project history or leak into a portable project.

**Approach:** Add a deterministic, in-memory ProjectOS-owned Conversation/export/restore contract and fake-backed validation. Canonical local IDs, transcript, accepted history, Rationale, Provenance, Sources, versions, and relationships stay inside ProjectOS; an opaque adapter-keyed session binding is runtime-only and deliberately omitted from export and restore.

## Boundaries & Constraints

**Always:** Keep the contract provider-neutral, immutable, strict-schema validated, and entirely offline. The only canonical Conversation identity is a validated ProjectOS ID. A binding contains an opaque provider session handle keyed by adapter and cannot supply, replace, or rewrite local transcript/history. Export writes portable schema v1 and excludes bindings, provider IDs, credentials, authentication, runtime caches, diagnostics, and unknown adapter metadata. Restore supports v1 plus its defined v0 migration only, performs zero provider calls, creates a distinct Project copy, applies one complete Project-owned ID map atomically, retains source IDs only as import-provenance metadata, and starts with zero bindings. Fresh explicitly approved Context Preview work may create a new opaque binding only after restore.

**Block If:** Implementation requires live App Server thread/resume RPC, a manifest/protocol expansion, a generic dispatch path, or a claimed production-persistence/containment proof. The current Story 1.6 `containment_boundary_unavailable` result and pinned manifest forbid those actions.

**Never:** Add production UI, a database/repository layer, provider calls during export/restore, thread/turn dispatch, credentials or account identity, a cleanup outbox (Story 1.8), adapters importing export/restore/domain repositories, or provider bindings in any portable/sanitized artifact.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Local binding and restart | Valid canonical Conversation plus opaque Codex binding; simulated supervisor restart | Resume decision references the local Conversation and existing binding while preserving frozen local transcript/history | Missing, stale, wrong-adapter, or wrong-Conversation binding rejects/resets only the binding; local Conversation is unchanged |
| Portable export | Valid local Project with bindings and hostile provider-leak canaries | Versioned export contains only canonical ProjectOS model and accepted provenance; structural sanitized evidence has counts/digests only | Binding/provider/auth/cache/diagnostic fields or malformed state reject before export publication |
| Offline restore | Valid export, including legacy supported data and unknown adapter metadata | One new Project copy and one complete remap preserve coherent relationships, versions, Source links, Rationale, Provenance, and Conversation content; bindings are empty | Unsupported/corrupt input, duplicate IDs, or incomplete map rejects with no returned/partially committed Project |
| Repeated restore and fresh AI start | Source plus two restores with collision-prone IDs; restored Conversation and approved preview | Each restore gets different Project-owned IDs; source remains unchanged; fresh work creates a new binding only | Exported provider metadata cannot reattach a session or trigger an adapter call |

</intent-contract>

## Code Map

- `spikes/codex-app-server-harness/src/core/conversation-ownership.ts` -- immutable local Conversation, transcript/history, provider-binding validation, safe restart classification, and fresh-binding creation contract.
- `spikes/codex-app-server-harness/src/core/project-export.ts` -- strict versioned portable Project shape, canonical serialization, leak rejection, and content-free ownership-evidence projection.
- `spikes/codex-app-server-harness/src/core/project-restore.ts` -- pure offline preflight/migration and one-pass atomic remap into a new Project copy with import-provenance IDs and no bindings.
- `spikes/codex-app-server-harness/src/core/{ai-provider-port,change-proposal-schema,provider-job-coordinator}.ts` -- preserve the existing ProjectOS-owned, wire-independent boundary; do not expand it into provider dispatch.
- `spikes/codex-app-server-harness/src/evidence/{conversation-ownership-evidence-schema,conversation-ownership-evidence-recorder}.ts` and `evidence/conversation-ownership-validation-run.schema.json` -- atomic structural-only evidence for export/restore checks.
- `spikes/codex-app-server-harness/test/{conversation-ownership,project-export-restore,adapter-boundary,workspace,cli}.test.ts` and `test/fixtures/portable-conversation-project.json` -- deterministic ownership, leak, migration, atomicity, boundary, and command proof.
- `spikes/codex-app-server-harness/{package.json,README.md,evidence/README.md}` and `_bmad-output/implementation-artifacts/sprint-status.yaml` -- offline validation command, explicit limitation, evidence contract, and Story status.

## Tasks & Acceptance

**Execution:**
- [x] `spikes/codex-app-server-harness/src/core/conversation-ownership.ts` -- define frozen ProjectOS Conversation and adapter-keyed opaque Binding types plus create/replace/resume decisions; reject identity conflation and leave canonical local content untouched on binding failure.
- [x] `spikes/codex-app-server-harness/src/core/project-export.ts` and `src/core/project-restore.ts` -- implement exact-shape portable export and pure offline restore/preflight/migration, with one collision-safe map covering every Project-owned ID and zero restored bindings.
- [x] `spikes/codex-app-server-harness/src/evidence/{conversation-ownership-evidence-schema,conversation-ownership-evidence-recorder}.ts` and `evidence/conversation-ownership-validation-run.schema.json` -- write atomically published, schema-checked counts/digests/outcomes that reject content, IDs, session data, adapter metadata, credentials, paths, and raw payloads.
- [x] `spikes/codex-app-server-harness/test/fixtures/portable-conversation-project.json`, `test/conversation-ownership.test.ts`, and `test/project-export-restore.test.ts` -- prove every matrix scenario, mapped equivalence, source immutability, no partial restore result, legacy migration, unknown adapter metadata inertness, and new binding creation only after fresh explicit initiation.
- [x] `spikes/codex-app-server-harness/test/{adapter-boundary,workspace,cli}.test.ts` and `src/cli.ts` -- keep core export/restore free of Codex imports and provider calls; add only an offline ownership-validation command with safe exit behavior.
- [x] `spikes/codex-app-server-harness/{package.json,README.md,evidence/README.md}` and `_bmad-output/implementation-artifacts/sprint-status.yaml` -- add the focused deterministic command, document that fake proof is not live resume/containment proof, and mark Story 1.7 accurately after validation.

**Acceptance Criteria:**
- Given provider work creates a thread for a new validation Conversation, when the binding is recorded, then the ProjectOS Conversation ID remains canonical and the opaque session ID is only adapter-keyed metadata.
- Given a bound Conversation survives a simulated owned-process restart, when provider state is stale or missing, then local transcript and accepted history remain unchanged and only the binding is safely rejected or replaced.
- Given a bound Project is exported, when serialization and leak checks run, then the package includes canonical Conversation/provenance state but excludes every provider binding, session ID, credential, authentication/runtime state, cache, and unsanitized diagnostic.
- Given a valid portable export is restored offline, when preflight and commit run, then no provider interface is invoked, a distinct Project copy has no binding, and later approved work creates a new binding without changing the restored canonical Conversation ID.
- Given repeated restores, source-side restore, collision-prone identifiers, recognized import-provenance IDs, unknown adapter metadata, and older supported schema input, when each operation runs, then remapped Project-owned data is internally equivalent and coherent while unsupported/corrupt input returns no partial Project.

## Spec Change Log

## Review Triage Log

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 15 (high 9, medium 4, low 2)
- defer: 0
- reject: 1 (low 1)
- addressed_findings:
  - `[high]` `[patch]` Made default restore identifiers unique per restore and reject factories that preserve a source identifier.
  - `[high]` `[patch]` Retained every original identifier as portable import-provenance metadata across a restore followed by a new export.
  - `[high]` `[patch]` Replaced caller-controlled approval booleans with one-use opaque Context Preview approvals bound to Conversation and preview IDs.
  - `[medium]` `[patch]` Rejected duplicate adapter/Conversation bindings, unknown binding states, impossible timestamps, extra Conversation fields, and collection-order-dependent portable digests.
  - `[high]` `[patch]` Made the ownership CLI execute the offline contract and write sanitized atomic evidence without constructing a provider.
  - `[high]` `[patch]` Sanitized evidence before using a run ID in a staging path and required a stop condition for rejected evidence.
  - `[low]` `[patch]` Rejected unsupported ownership CLI path input and completed the CLI usage text.

## Design Notes

The implementation proves the ownership architecture without pretending this validation harness is the production persistence layer. The single restore map is the key invariant: every local reference is transformed from one immutable source snapshot, so a duplicate restore cannot accidentally preserve a source or previous-restore identity. Provider metadata is intentionally neither translated nor retained, preventing it from becoming a hidden reattachment capability.

## Verification

**Commands:**
- `npm run typecheck` -- expected: strict TypeScript passes.
- `npm run test:conversation-ownership` -- expected: offline fixture-backed ownership, export, restore, migration, and evidence checks pass with no provider child/call.
- `npm run validate:conversation-ownership` -- expected: typecheck plus the focused test command passes.
- `npm run validate:protocol` -- expected: manifest, default-deny dispatch, and containment-era protocol boundary remain unchanged.
- `npm test` -- expected: full offline harness regression passes and live probes remain opt-in/skipped.
- `git diff --check` -- expected: no whitespace errors.

## Auto Run Result

Summary: Added the offline, provider-neutral Story 1.7 proof that ProjectOS owns canonical Conversations while provider session bindings remain opaque, replaceable, and non-portable. Versioned export and pure restore preserve local history, Rationale, Provenance, Sources, versions, and relationships through a complete ID map; restores have no binding and later approved work mints a fresh one.

Files changed: Core ownership/export/restore contracts and structural evidence; fixture-backed ownership/export/restore tests; offline CLI and validation scripts; boundary/workspace tests; evidence and harness documentation; Epic 1 tracker.

Review: 15 review-driven patches applied (9 high, 4 medium, 2 low); 0 deferred; 1 overlapping test-coverage observation rejected. Follow-up review recommended because the repair set changed identity generation, provenance persistence, approval capabilities, and evidence execution boundaries.

Verification: `npm run validate:conversation-ownership` passed (24 tests); `npm run validate:protocol` passed (100 tests); `npm test` passed (159 tests, 4 expected opt-in skips); `git diff --check` passed.

Residual risk: This deterministic in-memory proof does not demonstrate live Codex thread resume, production persistence transactions, or preventive containment. Story 1.6 remains `containment_boundary_unavailable`; no App Server provider operation is enabled.
