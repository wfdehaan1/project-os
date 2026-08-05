---
title: 'Story 1.9: Prove Provider Neutrality and Record the Gate Decision'
type: 'feature'
created: '2026-08-05'
baseline_revision: '88ad3324aafacdca0df4a6c0a308c41a63d547c9'
status: 'in-review'
review_loop_iteration: 4
followup_review_recommended: true
context:
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/spec-1-8-prove-crash-safe-provider-session-cleanup.md'
warnings: [oversized]
---

<intent-contract>

## Intent

**Problem:** The spike has individual deterministic proofs but no ProjectOS-owned provider registry, structurally different adapters exercising the same workflows, or final audit that binds all prior evidence to one reproducible decision. Treating completed fake-backed stories as a live Codex authorization would bypass the Epic 1 gate.

**Approach:** Add a narrow, ProjectOS-owned capability/registry and reusable fake-adapter contract proof, then publish a sanitized structural audit that reduces all mandatory gate inputs to `proceed`, `proceed with constraints`, or `reject`. The current real fixture must truthfully record `reject`, not initiate live authentication, generation, session, or deletion work.

## Boundaries & Constraints

**Always:** Capability claims are scoped to the active adapter instance, runtime version, authentication context, and selected model/configuration; their only states are `supported`, `unsupported`, `temporarily_unavailable`, and `unknown`. Mandatory capabilities and user-visible degradations are re-resolved at dispatch. Workflows create at most one pending proposal per durable job, reject stale canonical revision output, and never mutate Canonical State. Provider bindings remain opaque and adapter-owned. Audit records retain only structural gate status, safe codes, fingerprints/digests, aggregate contract results, and reproduction commands; all retained audit inputs and output must reject credential, identity, content, prompt/result, raw payload, session/binding, and local-path canaries.

**Block If:** A required prior gate record cannot be located or validated, any required retained evidence fails the sanitation contract, deterministic adapter replacement requires a domain/persistence change, audit publication is non-atomic/unsafe, or implementation would need live App Server dispatch or a frozen-manifest change. HALT rather than narrow the audit or authorize a bypass.

**Never:** Add production UI/persistence, generic RPC/turn dispatch, live browser/keychain authentication, provider generation/list/delete, protocol manifest changes, credentials/account data, provider or Project content retention, or an API-key/local-model fallback. A deterministic Codex-shaped fake is not an authorization to invoke the installed Codex adapter.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Current capability | Active fake plus claim set | Registry resolves current scoped claims at dispatch; workflow executes only with mandatory support and declares each degradation | Unsupported/unknown/temporary claim blocks dispatch without changed locality, billing, privacy, or proposal guarantee |
| Replacement or race | Codex-shaped or local-shaped fake; duplicate completion, retry, cancel/complete race, concurrent jobs, stale revision | Same Conversation/proposal/re-entry/export/deletion workflow API works; one pending proposal maximum and stale result is discarded | No Canonical State mutation, cross-job result, or adapter-owned binding leak |
| Audit stop | Valid structural prior evidence has containment/cleanup/live-auth/quality gaps or sanitation failure | Atomic final record is `reject`, lists safe failed gates/stop conditions, and blocks production Codex-adapter and Epic 2 authorization | A reject result exits successfully; missing/unsafe/tampered evidence fails closed and publishes no record |
| Reducer coverage | Synthetic all-pass inputs, then all-pass constrained inputs | Reducer emits `proceed` or `proceed_with_constraints` only under their exact prerequisites | Branch tests never turn the real fixture into authorization |

</intent-contract>

## Code Map

- `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` and `src/core/provider-registry.ts` -- ProjectOS-owned immutable capability snapshot and dispatch-lease contract; retain the existing validation-only Codex surface.
- `spikes/codex-app-server-harness/src/core/{provider-contract-workflow,provider-job-coordinator}.ts` -- adapter-independent behavioral workflow seam and serialized stale-revision/cancellation/one-pending-proposal safety rules.
- `spikes/codex-app-server-harness/test/fixtures/{fake-codex-provider-adapter,fake-local-provider-adapter}.ts` and `test/provider-neutrality-contract.test.ts` -- structurally different deterministic adapter fixtures and reusable capability/workflow/race suite.
- `spikes/codex-app-server-harness/test/adapter-boundary.test.ts` -- comprehensive source-tree/static boundary assertions for domain/persistence and adapters.
- `spikes/codex-app-server-harness/src/evidence/gate-decision-evidence-{schema,recorder,loader,source-verify}.ts` and `evidence/gate-decision-validation-run.schema.json` -- bounded, descriptor-pinned audit that validates a source-bound prerequisite-evidence manifest before a decision can be reduced or published.
- `spikes/codex-app-server-harness/test/{gate-decision-evidence,cli,workspace}.test.ts` -- gate input, sanitation, atomicity, CLI, and workspace coverage.
- `spikes/codex-app-server-harness/{src/cli.ts,package.json,README.md,evidence/README.md}` and `_bmad-output/implementation-artifacts/sprint-status.yaml` -- offline command, reproducibility/limitation documentation, and accurate Story tracker.

## Tasks & Acceptance

**Execution:**
- [x] `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` and `src/core/provider-registry.ts` -- define frozen scope-and-claim snapshots plus an opaque dispatch lease whose capability/operation mapping is checked by the ProjectOS-owned fixed-operation dispatcher immediately before adapter invocation. Refuse empty mandatory sets, duplicate/ambiguous claims, registry replacement, or scope/claim drift before invocation.
- [x] `spikes/codex-app-server-harness/src/core/{provider-contract-workflow,provider-job-coordinator}.ts` -- run health, generation, streaming, cancellation, structured result, session/cleanup degradation through the fixed leased operations. Serialize each durable job’s compare-and-set transition; refuse duplicate active job creation, clean completed queue entries, bind every completion to its required canonical revision and active attempt, make cancellation terminal, and deep-freeze/clone the accepted proposal so stale, cancelled, duplicate, or concurrent completion cannot alter/create more than one pending proposal.
- [x] `spikes/codex-app-server-harness/test/fixtures/{fake-codex-provider-adapter,fake-local-provider-adapter}.ts` and `test/provider-neutrality-contract.test.ts` -- make fakes behaviorally distinct while satisfying the narrow contract; local fake deliberately lacks authentication, usage, persistent sessions/deletion, and configurable streaming/structured output. Cover each named operation, per-job cancellation, lease-operation mismatch rejection before an effect, scope/replacement/duplicate-claim drift, duplicate creation, queue cleanup, and simultaneous completion/cancellation from the same durable coordinator.
- [x] `spikes/codex-app-server-harness/test/adapter-boundary.test.ts` and relevant existing core tests -- scan the complete domain/persistence source set and fakes to prove no Codex protocol dependency or adapter repository access; preserve conversation ownership, export/restore, deletion, and proposal-only invariants unchanged.
- [x] `spikes/codex-app-server-harness/src/evidence/gate-decision-evidence-{schema,recorder,loader,source-verify}.ts`, `evidence/approved-current-gate-manifest.json`, and `evidence/gate-decision-validation-run.schema.json` -- load a caller-supplied, bounded prerequisite root through descriptor-pinned no-follow reads, but accept it only when its exact-key source manifest hash matches the package-controlled approved current-reject manifest and every expected per-gate source digest/schema/reproduction identity matches. Brand accepted bundles inside the loader module and reject forged/incomplete bundles in both reducer and writer. A passed record may have no stop condition; writer/schema revalidate required gate set, decision consistency, and safe codes before publication. Write a durability-unknown-safe summary before rename, sync staging and published parent directories, and never truncate/replace a visible completed record after publication. No hard-coded/fabricated fallback records are allowed.
- [x] `spikes/codex-app-server-harness/test/{gate-decision-evidence,cli,workspace}.test.ts` -- prove all reducer branches with source-bound on-disk fixture records, current rejected fixture, forged bundle, missing/duplicate/empty/tampered/symlink-swap/oversize/sanitation-failing prerequisite evidence, altered/unexpected manifest and source digest/identity, contradictory decision, stale attempt, lease-operation mismatch, private/public write failure, post-rename durability uncertainty, and fixed CLI reproducibility.
- [x] `spikes/codex-app-server-harness/{src/cli.ts,package.json,README.md,evidence/README.md}` and `_bmad-output/implementation-artifacts/sprint-status.yaml` -- add focused offline test/validation commands and an explicit prerequisite-evidence-root argument; document that this approved evidence set can record only the current `reject`, that reducer `proceed` branches are non-authorizing coverage, evidence provenance/durability behavior, and the explicit architecture-revision requirement for later local work.

**Acceptance Criteria:**
- Given active scoped claims, when the registry dispatches through either deterministic fake, then current mandatory capability support is required and every unsupported surface yields its declared degradation without implicit privacy, locality, billing, or output change.
- Given a registry replacement and race/staleness fixtures, when the shared contract runs, then domain workflows need no adapter-specific change, no pending-proposal duplication or Canonical State mutation occurs, and stale output cannot persist.
- Given static dependency inspection, when all domain/persistence and adapter sources are checked, then core imports no Codex protocol types and adapters have no Canonical State, Conversation, Change Proposal, export, or deletion repository access.
- Given Stories 1.1–1.8 evidence, when the final audit executes, then it validates required structural evidence and sanitation, emits only safe aggregate evidence, and produces the current `reject` with containment, cleanup, live-auth, quality, neutrality, or sanitation stops as actually evidenced.
- Given any failed mandatory gate, when the decision is recorded, then production Codex-adapter work and Epic 2 authorization are blocked; only an explicit architecture revision can reopen later local work. Given synthetic all-pass inputs, the reducer covers `proceed` and `proceed_with_constraints` without authorizing the real fixture.

## Spec Change Log

### 2026-08-05 — Review repair 1
- Trigger: The first implementation fabricated in-process prior gate records rather than reading the required evidence, allowed optional revision/cancellation safety, and did not fail closed on ambiguous claims or empty gate evidence.
- Amendment: Made the prerequisite-evidence root and no-fallback rule explicit; required non-empty one-per-gate records, immutable post-await scope comparison, mandatory revision/cancellation terminal behavior, duplicate-claim rejection, and per-job cancellation fixtures.
- Avoids: A successful synthetic `reject` record being mistaken for an evidence-bound gate decision, stale/cancelled output becoming pending, or ambiguous/unevidenced capability claims enabling work.
- KEEP: Preserve the test-only fake adapter seam, no live Codex action or manifest expansion, strict structural sanitation, atomic publication, and deterministic `reject` for valid current failed evidence.

### 2026-08-05 — Review repair 2
- Trigger: The repaired loader trusted self-authored pass records, reduction/publication could be called with incomplete or contradictory data, and asynchronous callback/state handling could report a block only after an effect.
- Amendment: Require source-bound evidence provenance, bounded descriptor-pinned loading, reducer/writer invariants and directory sync; replace callback-after-check dispatch with an opaque adapter-validated lease; make workflow behavioral and job transitions serialized with immutable accepted proposals.
- Avoids: Fabricated all-pass evidence authorizing Epic 2, audit loss/tampering, retrospective capability blocking after a provider effect, and completion/cancellation races altering pending state.
- KEEP: Preserve the explicitly supplied evidence root, all offline/no-live-Codex rules, deterministic current reject fixture, strict sanitizer, and adapter/domain separation.

### 2026-08-05 — Review repair 3
- Trigger: The external evidence root could self-attest an all-pass manifest, a lease did not bind its operation, duplicate job creation could overwrite state, and a post-rename sync exception could misreport publication.
- Amendment: Pin the accepted current-reject manifest to package-controlled source, bind lease operation to capability, reject duplicate jobs and clean queues, and model post-rename sync failure truthfully as durability unknown rather than an unpublished failure.
- Avoids: A caller-forged `proceed`, unsupported effect under a valid lease, stale queued work completing a replacement job, and contradictory publication status after a crash boundary.
- KEEP: The evidence root remains explicit and descriptor-pinned; only the approved current evidence set can drive the production CLI, while synthetic reducer branches stay non-authorizing test coverage.

### 2026-08-05 — Review repair 4
- Trigger: Reducer input was structurally forgeable outside the loader, completions did not bind active retry attempt, and lease/durability enforcement retained ambiguous bypass paths.
- Amendment: Brand loader-created evidence bundles in module-private state and verify the brand before reduce/write; require active attempt; invoke adapters only through a ProjectOS fixed-operation lease dispatcher; publish a durability-unknown-safe record before rename without overwriting any visible run.
- Avoids: In-process fabricated `proceed`, stale retry adoption, a valid lease used for another provider effect, and readers observing a truncated post-rename record.
- KEEP: Retain the pinned current-reject manifest, offline-only no-live-Codex boundary, explicit evidence root, serialized job model, and synthetic reducer branches only as non-authorizing tests.

## Review Triage Log

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 6 (high 6)
- patch: 0
- defer: 0
- reject: 0
- addressed_findings:
  - `[high]` `[bad_spec]` Require the audit CLI to discover and validate actual prerequisite evidence rather than fabricate records and placeholder digests.
  - `[high]` `[bad_spec]` Require post-await scope identity verification, mandatory canonical-revision validation, terminal cancellation ordering, duplicate-claim fail-closed behavior, and non-empty evidence proof.

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 8 (high 8)
- patch: 0
- defer: 0
- reject: 8
- addressed_findings:
  - `[high]` `[bad_spec]` Bind every prerequisite record to a verified source manifest and make complete-bundle/decision consistency an invariant of both reducer and writer.
  - `[high]` `[bad_spec]` Require bounded descriptor-pinned evidence reads, publication directory sync, and a dispatch lease validated before any adapter effect.
  - `[high]` `[bad_spec]` Require behavioral fake coverage and serialized, deeply immutable job transitions for cancellation/completion concurrency.

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 4 (high 1, medium 3)
- patch: 0
- defer: 0
- reject: 3
- addressed_findings:
  - `[high]` `[bad_spec]` Anchor production prerequisite evidence to the approved current-reject manifest; no caller-supplied all-pass root may authorize work.
  - `[medium]` `[bad_spec]` Bind leases to their operation, protect duplicate job creation/queue lifecycle, and make post-rename durability uncertainty truthful.

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 3 (high 2, medium 1)
- patch: 0
- defer: 0
- reject: 1
- addressed_findings:
  - `[high]` `[bad_spec]` Require module-private validated-bundle branding and active-attempt completion binding.
  - `[high]` `[bad_spec]` Require ProjectOS-owned fixed-operation lease dispatch before adapter invocation.
  - `[medium]` `[bad_spec]` Require a durability-unknown-safe pre-rename summary without post-publication replacement.

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 1 (medium 1)
- defer: 0
- reject: 1
- addressed_findings:
  - `[medium]` `[patch]` Propagate a capability claim's declared user-facing degradation through the fixed workflow instead of collapsing it to a generic dispatch error.

## Design Notes

The audit is deliberately stricter than earlier evidence publication: prior protocol-private artifacts intentionally contain absolute paths, while Story 1.9 requires every retained audit input to pass local-path sanitation. The implementation must surface that conflict as a failed audit gate and current `reject`; it must not relabel private artifacts as sanitized or silently omit them.

## Verification

**Commands:**
- `npm run typecheck` -- expected: strict TypeScript passes.
- `npm run test:provider-neutrality` -- expected: fake-adapter contract, registry, workflow, race, and static-boundary tests pass without provider calls.
- `npm run validate:gate-decision` -- expected: typecheck plus audit/evidence/CLI/workspace suite passes and records the deterministic current `reject` safely.
- `npm run validate:protocol` -- expected: manifest-pinned default-deny and containment-era boundary remain unchanged.
- `npm run validate:conversation-ownership` -- expected: opaque bindings, export/restore, and deletion separation remain provider-neutral.
- `npm run validate:provider-cleanup` -- expected: cleanup evidence remains fake-backed and truthfully rejects unproven live cleanup.
- `npm test` -- expected: offline harness regression passes; opt-in live tests remain skipped.
- `git diff --check` -- expected: no whitespace errors.

## Auto Run Result

Summary: Added the final provider-neutral contract proof and evidence-bound gate audit. The approved, descriptor-pinned current evidence bundle deterministically records `reject`; it cannot authorize Epic 2 or production Codex work.

Files changed: ProjectOS capability registry/fixed-operation workflow and active-attempt coordinator; deterministic Codex/local fakes; pinned prerequisite evidence loader and atomic gate recorder/schema/current-reject bundle; CLI/package/docs/workspace/test updates; Story tracker and this specification.

Review: Four bad-spec repair loops addressed evidence provenance, scope/operation dispatch, active-attempt concurrency, and durability truthfulness. The final pass applied one medium degradation-propagation patch; no deferred issues. Follow-up review recommended because the review-driven changes are broad and safety-sensitive.

Verification: `npm run validate:gate-decision` passed (22 focused tests and deterministic offline reject); `npm test` passed (178 tests, 4 expected opt-in skips); `npm run validate:protocol` passed (102 tests); `npm run validate:conversation-ownership` and `npm run validate:provider-cleanup` passed; `git diff --check` passed.

Residual risk: The result remains `reject`: live managed authentication is unproven, quality remains fake-backed, preventive containment is unavailable, and live Codex cleanup is unproven. Reopening any production Codex path or a different evidence set requires an explicit architecture revision.
