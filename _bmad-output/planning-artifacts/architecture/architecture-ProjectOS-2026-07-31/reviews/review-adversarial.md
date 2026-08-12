---
title: Adversarial Review — ProjectOS AI Provider Architecture Spine
reviewer: adversarial-divergence
date: 2026-07-31
artifact: ../ARCHITECTURE-SPINE.md
companion: ../validation-spike.md
verdict: revise
status: historical-superseded
---

# Adversarial Review

> This review applies to the superseded 2026-07-31 Codex App Server architecture. It is preserved as historical evidence and does not validate the 2026-08-09 replacement architecture.

## Verdict

**Revise before implementation.** The spine chooses the right paradigm and identifies the right seams, but it does not yet make independently built units converge on write ownership, capability scope, event ordering, authentication isolation, crash-safe session cleanup, deletion outcomes, or export identity. Its strongest claimed prevention—no orphaned provider sessions—does not survive a process crash between provider-side creation and local binding persistence.

No finding requires making Codex the domain model. The fixes are provider-neutral invariants that make the abstraction real.

## Divergence construction

The following two implementation units are both plausible one-level-down realizations of all eleven ADs. Both use only ProjectOS types at the port, keep Codex protocol types inside the Codex adapter, validate structured results, own their child processes, leave tokens to Codex, and expose every named capability and normalized state. They are nevertheless incompatible at their shared seams.

| Concern | Unit A — workflow-centric adapter | Unit B — adapter-service boundary | Why both currently comply yet diverge |
|---|---|---|---|
| Shared data and mutation | The adapter is pure. It returns a validated pending proposal and opaque session ID; an application workflow writes proposals and bindings. | The adapter receives ProjectOS repositories, validates output, writes the pending proposal and binding, then returns their ProjectOS IDs. | AD-1 constrains types, not dependency direction. AD-6 says validation occurs “before creating persisted proposals” without naming the sole writer. The seed names owners but does not prohibit adapter persistence access. |
| Duplicate/concurrent completion | The workflow deduplicates on a durable `jobId` and expected Conversation revision. | The adapter deduplicates only within the current process and treats a retried request as new after restart. | No AD defines request identity, idempotency, optimistic revision preconditions, or concurrent-turn policy. Both can preserve explicit review while creating different pending proposal sets. |
| Session lifecycle | One mutable current binding exists per `(Conversation, adapter)`. Rebinding deletes the old session first and uses in-memory compensation if a subsequent local write fails. | An append-only session ledger retains active, retired, and cleanup-pending sessions; a durable reconciliation job closes incomplete transitions after restart. | “Replaceable bindings keyed by adapter” permits the current-row model. “Owns cleanup” does not specify a durable cleanup obligation or crash recovery. Unit A leaks a newly created provider session if the process dies before the binding write. |
| Capabilities | Capabilities are provider-wide booleans cached when the registry loads; `structuredOutput=true` means the runtime protocol supports an output schema. | Capabilities are a per-runtime/account/model snapshot; `structuredOutput=true` means the selected configuration can satisfy the ProjectOS proposal job now. | AD-2 names capability labels but not scope, value semantics, freshness, or job requirement resolution. UI and dispatch code will disagree about availability as models/accounts change. |
| Events and cancellation | A local cancellation immediately emits terminal `interrupted`; late provider completion is discarded. Rate-limit classification is inferred from transport status. | Cancellation is only a request; provider `completed` wins if it races ahead of cancellation acknowledgement. Rate-limit classification comes from provider usage state. | AD-7 lists state names but defines no event envelope, ordering, terminal exclusivity, cancellation race rule, or classification precedence. Both normalize vendor events while producing incompatible workflow behavior. |
| Process and auth isolation | One app-lifetime owned child inherits the normal user environment and default Codex configuration/auth storage. Logout can therefore affect the user’s other Codex use, although ProjectOS never handles a token. | One owned child per ProjectOS provider profile runs with an allowlisted environment and dedicated runtime configuration/auth storage. | AD-4 requires an owned child, not a storage/configuration boundary. AD-5 leaves credentials runtime-owned, but does not decide whether that runtime state is shared or ProjectOS-isolated. Both obey the literal rules. |
| Deletion | Local Project deletion commits first. A minimal cleanup receipt outside the deleted Project retries provider deletion; UI reports `local deleted / provider cleanup incomplete`. | The Project is tombstoned first and remains recoverable until provider cleanup succeeds or the user explicitly confirms local-only completion with a residual-data warning. | AD-9 does not define the local deletion transaction, what “completion” names, where cleanup obligations survive after Project removal, or the exact two-dimensional outcome. Both fit the PRD’s allowance for local deletion to continue with a warning. |
| Export and restore | Export omits every adapter field, preserves canonical IDs, and starts a new session after restore. | Export includes sanitized provider/audit metadata, including historical opaque session identifiers; restore ignores those bindings, remaps colliding canonical IDs, and starts a new session. | AD-3 only requires restore to work without original bindings. AD-5 excludes authentication material, not all provider identifiers. The spike silently chooses Unit A’s export policy, while the spine permits both and says nothing about ID collisions. |

This is not stylistic variance. Connecting Unit A’s workflow assumptions to Unit B’s adapter assumptions can double-persist proposals, enable unavailable jobs, display contradictory terminal states, reuse or sign out an unrelated Codex account, lose provider cleanup obligations, and restore stale identifiers.

## Findings

### F-1 — Critical: no exclusive mutation owner or transactional seam

**Evidence:** the diagram connects the port directly to Canonical State (`ARCHITECTURE-SPINE.md:17-25`); AD-1 constrains only type ownership (`:39-43`); AD-6 requires validation before a proposal is persisted but does not assign persistence (`:69-73`); the seed gives broad ownership labels without a dependency rule (`:105-116`).

**Failure:** an application workflow and an adapter can each reasonably persist the same completed result. A retry after timeout can create two pending proposals or attach one provider result to the wrong Conversation revision. Nothing requires adapters to be unable to mutate Conversations, Change Proposals, Canonical State, or deletion records. “ProjectOS owns it” is not a single-writer rule.

**Required spine decision:** establish a provider-neutral dependency and mutation rule:

- adapters return normalized values/events and opaque provider-session handles but have no access to Canonical State, Conversation, Change Proposal, export, or deletion repositories;
- one ProjectOS application/domain transaction owns proposal persistence and every accepted-state mutation;
- each provider job has a durable ProjectOS `jobId`, Conversation ID, and expected canonical revision; completed/retried delivery is idempotent; and
- provider output can create only a pending proposal. Accept/edit/reject remains a separate user-authorized domain command.

If binding persistence intentionally belongs to a lifecycle coordinator rather than the normal workflow transaction, name that coordinator as the sole writer and prohibit both adapters and UI from writing bindings directly.

**Missing spike gate:** dependency inspection currently checks only that domain/persistence do not import Codex protocol types (`validation-spike.md:105`). Add the inverse check that adapters cannot import or invoke Canonical State/Conversation/proposal mutation repositories. Fault-inject duplicate completion, timeout-and-retry, concurrent turns, stale Conversation revision, and cancellation/completion races; assert one pending proposal and zero Canonical State mutation.

### F-2 — Critical: session cleanup is not crash-consistent

**Evidence:** AD-3 models bindings as replaceable (`ARCHITECTURE-SPINE.md:51-55`); AD-9 requires recording persisted bindings and cleaning them up (`:87-91`) but defines no transition protocol. The spike tests ordinary create/resume/delete and filesystem after-state (`validation-spike.md:82-90,109-115`) but not crashes between steps.

**Failure:** provider thread creation succeeds, then the app crashes before its ID is durably bound. The provider now retains a thread that ProjectOS cannot enumerate, so permanent deletion cannot invoke deletion “for every binding.” Replacing a current-row binding can similarly erase the only cleanup handle for an older session. A failure between local Project destruction and saving the cleanup receipt can make retry impossible.

**Required spine decision:** retain a durable lifecycle/cleanup obligation for every provider session until deletion is confirmed or already absent. A replaceable active pointer may exist, but it must not erase historical cleanup targets. Define a crash-recoverable state machine or outbox for at least `create-intent → created/bound → retired/delete-pending → confirmed/absent`, stable adapter identity, idempotent delete, and startup reconciliation. Define what happens when creation succeeds but its identifier cannot be made durable; if the protocol cannot make that window recoverable, the ownership claim and stop condition must say so explicitly.

**Missing spike gate:** kill the harness after each side effect in create, rebind, archive, Conversation delete, and Project delete. Restart and prove reconciliation, repeated-delete idempotency, preservation of all historical cleanup targets, and no false “provider cleanup complete.” Test a provider timeout where delete may have succeeded, then retry safely.

### F-3 — High: auth ownership is decided, auth isolation is not

**Evidence:** AD-4 owns the child process (`ARCHITECTURE-SPINE.md:57-61`) and AD-5 leaves tokens to Codex (`:63-67`). Neither fixes the runtime’s configuration/auth storage root, inherited environment, account-sharing model, or logout blast radius. AD-8’s “registers no tools or connectors” (`:81-85`) does not prove that an inherited Codex configuration cannot load them.

**Failure:** a compliant adapter can use the user’s default Codex state. ProjectOS may silently reuse the account signed in for unrelated CLI work; ProjectOS logout may sign that account out globally; user-configured MCP servers, skills, approvals, proxies, or environment variables may enter the child despite the adapter registering none. A second compliant adapter can isolate all of this. They have materially different privacy, containment, and account UX.

**Required spine decision:** choose and disclose shared or isolated runtime state. The safe default is a ProjectOS-dedicated runtime configuration/auth/data root plus an allowlisted child environment, with no inherited MCP/tool/skill configuration. Define account identity checks, account switch/logout semantics, concurrent app-instance ownership, and cleanup of the isolated runtime state. If shared Codex auth is intentional, explicitly bind the cross-application effects and require UX disclosure.

**Missing spike gate:** begin with a separately signed-in and customized Codex CLI profile. Prove whether ProjectOS can or cannot see/reuse it according to the decision; verify ProjectOS login/logout does not alter unrelated Codex state; inspect the actual child environment and loaded configuration; and test two app instances or provider profiles for account/process cross-talk.

### F-4 — High: normalized events are names, not a state machine

**Evidence:** AD-7 enumerates states (`ARCHITECTURE-SPINE.md:75-79`) but supplies no stable event identity or legal transitions. AD-11 requests normalized-error tests (`:99-103`) without defining the conformance oracle. The spike exercises cancellation, partial output, retry, and selected failures (`validation-spike.md:46-53,63-71`) but has no ordering assertions.

**Failure:** independent adapters can emit `interrupted → completed`, two terminal events, progress after terminal, or no terminal after a child restart. A UI may treat `rate limited` as retryable while a workflow interprets the same condition as `allowance exhausted`. Late notifications from a prior job can update the active job if correlation is not mandatory. Raw diagnostic fields can accidentally escape into logs or UI.

**Required spine decision:** define a provider-neutral job/event contract with stable `jobId`, provider-instance ID, monotonically interpretable ordering (sequence or explicit reducer semantics), exactly one terminal outcome, legal cancellation/completion race behavior, and late/duplicate event handling. Define normalized failure codes separately from job states, with retryability, optional retry/reset timing, user remedy, and sanitized diagnostic reference. Bind precedence for authentication, runtime, network, rate-limit, and allowance classification.

**Missing spike gate:** replay duplicated, missing, delayed, reordered, and cross-job notifications; race cancellation with completion and child death; assert deterministic final state and exactly one persisted result. Run the same event traces against every fake profile and the Codex adapter.

### F-5 — High: capability negotiation has no scope or semantics

**Evidence:** AD-2 lists capabilities and requires disabled/degraded states (`ARCHITECTURE-SPINE.md:45-49`) but does not define whether a claim belongs to an adapter, runtime version, account, selected model, session, or current health. The fake contract tests only one named absence—usage reporting (`validation-spike.md:92-107`).

**Failure:** a provider can advertise structured output because one model supports it while the selected local model does not. A cached provider-wide `persistentSessions=true` can remain enabled after an account or runtime change. “Degraded” can mean reject the job, request unstructured JSON and validate it, or silently omit proposal types; each is observable and affects trust.

**Required spine decision:** make capability claims typed, scoped, and evaluated at dispatch for the selected provider configuration. Distinguish supported, unsupported, temporarily unavailable, and unknown; define which ProjectOS job requirements are mandatory and which have an explicit user-visible degradation. Capability changes must invalidate or re-evaluate pending dispatch, never silently change execution locality, billing, or proposal guarantees.

**Missing spike gate:** use at least two structurally different fake profiles: (1) Codex-shaped and (2) local-model-shaped with no auth, account, usage, provider deletion, or persistent session and with configurable streaming/structured-output absence. Exercise capability changes after registry load and between session creation and dispatch. The current stop condition refers to “a second fake adapter” (`validation-spike.md:124`) even though the scope and matrix define only one (`:20,94`); make the second shape an explicit gate.

### F-6 — High: deletion has no authoritative outcome model

**Evidence:** AD-9 says cleanup status is recorded before “reporting completion” (`ARCHITECTURE-SPINE.md:87-91`) without distinguishing local erasure from provider cleanup. The PRD allows local deletion to continue with a residual-data warning and retry path, so the ambiguity is externally visible. The spike gate only forbids claiming complete cleanup while a known binding remains (`validation-spike.md:82-90`).

**Failure:** one unit can report “Project deleted” after local erasure and retain a cleanup job; another can retain a tombstoned Project until remote cleanup finishes. A third can store the retry record inside the Project and delete its own only means of retry. All can avoid claiming provider cleanup complete while giving incompatible local ownership and recoverability behavior.

**Required spine decision:** define separate, durable outcomes for local Project deletion and provider cleanup. Specify the sole location and retention rule for the minimum cleanup ledger after project content is erased, what identifiers it may retain, whether user cancellation/retry is possible, when local records become unrecoverable, and exactly which message may say “Project deletion complete” versus “provider cleanup complete.” Provider/adaptor removal must run the same cleanup contract for its bindings or explicitly transfer unresolved obligations.

**Missing spike gate:** test local deletion with provider offline, adapter removed/renamed, account switched, session already absent, and app restart before retry. Assert that no Project content remains after confirmed local erasure, the minimal cleanup receipt remains sufficient and sanitized, and each UI/API outcome reflects both dimensions.

### F-7 — High: export/restore identity and provider metadata policy are underbound

**Evidence:** AD-3 requires restored Conversations to work without original bindings (`ARCHITECTURE-SPINE.md:51-55`) and AD-5 excludes authentication material (`:63-67`), but neither says whether bindings/session IDs and sanitized diagnostics are forbidden from export. The spike requires an export “without exporting the binding” (`validation-spike.md:84-87`), which is a new architecture decision hidden in a test. No rule covers ID collisions or repeated restore.

**Failure:** an export can leak opaque provider identifiers even though it contains no token; a restore can accidentally reattach to or attempt deletion of a session owned by the source Project; preserving canonical IDs can collide when importing into an installation that already contains the Project, while remapping can break Provenance if not atomic and complete.

**Required spine decision:** explicitly exclude live Provider Session Bindings, provider session IDs, auth state, runtime caches, and unsanitized diagnostics from portable exports. Define whether safe provider configuration metadata is included. Bind export schema/version/integrity behavior, canonical-ID preservation versus deterministic remapping on collision, provenance/reference rewriting, and the rule that restore performs no provider call and cannot resurrect a session. New provider work after restore must create a new local cleanup obligation and new provider session.

**Missing spike gate:** inspect the archive for forbidden fields; restore with no runtime/account/network; restore twice; restore beside the source Project; inject canonical-ID collisions and unknown adapter metadata; migrate an older export; verify complete equivalence and no provider call or stale-session attachment.

### F-8 — Medium: containment proves an ordinary case, not the boundary

**Evidence:** the containment gate requires “ordinary ProjectOS generation” without command or file changes (`validation-spike.md:73-80`). It does not include hostile selected content, provider attempts to request tools, symlink/path escapes, inherited runtime configuration, or a read-only command attempt.

**Failure:** benign prompts pass while pasted Source Material containing instructions to inspect the filesystem or invoke a tool triggers exactly the coding-agent behavior AD-8 seeks to prevent. Detecting an attempt after unrelated content was read is not equivalent to preventing access.

**Required spike gate:** add adversarial prompt-injection fixtures, symlink/path traversal fixtures, preconfigured global MCP/tool/skill state, environment-secret canaries, and read/write/command attempts. Require prevention where the runtime supports prevention; otherwise require reliable detection before data or side effects escape, with a stop condition. Evidence must prove both no project-file mutation and no unrelated read/transmission.

### F-9 — Medium: the spike has no completeness pass criterion

**Evidence:** the structured-output gate sets 85% correctness and says omissions are measured separately (`validation-spike.md:55-71`), while the stop condition refers to “the correctness and completeness gate” (`:121`). There is no completeness threshold or qualitative stop rule in the spike itself.

**Failure:** a model can propose one correct fact out of ten material facts, score 100% correctness on what it proposed, and pass while omitting the project’s governing Decision and tasks. That is incompatible with the continuity thesis and with the stop condition’s wording.

**Required spike gate:** pre-annotate the material expected facts/Decisions/Open Questions/Tasks for each fixture, report precision and recall separately by artifact type, and define a minimum recall or explicit “no omission that changes current-state/re-entry meaning” criterion. Set a minimum denominator or add more fixtures before treating 85% as evidence.

## Required changes before implementation handoff

1. Add one decision for dependency direction, sole mutation ownership, durable job identity, revision preconditions, and idempotency.
2. Amend the binding/lifecycle decision to require a durable, crash-recoverable cleanup ledger that retains historical session obligations.
3. Decide whether runtime configuration/auth state is ProjectOS-isolated or shared, including environment/config/tool inheritance and logout effects.
4. Specify the normalized event reducer and failure taxonomy sufficiently for contract tests to have one oracle.
5. Specify capability scope, evaluation time, and allowed degradation per ProjectOS job.
6. Specify the two-dimensional deletion outcome and retention of sanitized cleanup receipts.
7. Move the spike’s binding-exclusion assumption into the spine and add export identity/collision/restore invariants.
8. Expand the spike with crash, race, hostile-input, structurally different fake-provider, and completeness gates.

## What may remain deferred

- Concrete database tables, module names, serialization library, actor/runtime framework, and UI copy.
- The first production local-model runtime and model-selection UX.
- Automatic provider fallback and cross-provider continuation of hidden provider context.
- Commercial runtime packaging, once the spike records the installed-runtime constraints.

Those choices do not need to be fixed to close the divergences above.

## Resolution addendum — 2026-07-31

**Re-review verdict: revise; no critical findings remain, three high findings remain.** The update materially resolves the original event/error, capability, runtime-isolation, hostile-input, crash-test, and deletion-outcome gaps. AD-12 and the expanded spike also establish the intended single-writer and idempotency model, but one older rule still conflicts with it.

| Prior finding | Resolution |
|---|---|
| F-1 mutation ownership | **Partially resolved; High remains.** AD-12 makes the job coordinator the sole proposal writer, but AD-6 still says the Codex adapter validates output “before creating persisted proposals.” Amend AD-6 so the adapter returns a parsed provider result and the `ProviderJobCoordinator` performs the ProjectOS-schema validation and persistence. The diagram’s `PORT --> STATE` edge should likewise terminate at the coordinator, not imply port mutation. |
| F-2 crash-safe sessions | **Resolved as an architecture invariant and spike gate.** AD-9 now requires durable lifecycle obligations, retained cleanup targets, idempotent transitions, and startup reconciliation; the spike fault-injects every transition. Whether App Server can pass the create-response crash window is now correctly a rejectable spike result rather than an unspecified implementation choice. |
| F-3 auth isolation | **Resolved.** AD-4, AD-5, and AD-13 bind a dedicated `CODEX_HOME`, keyring-only credential storage, scrubbed environment, no default-profile reuse, and multi-instance ownership; the spike verifies isolation against an independently configured profile. |
| F-4 event/error model | **Resolved.** AD-7 now binds correlation, ordering, terminal exclusivity, cancellation races, classification evidence, retry metadata, and diagnostic redaction; replay gates provide a conformance oracle. |
| F-5 capabilities | **Resolved.** AD-2 fixes scope, status semantics, dispatch-time evaluation, and degradation disclosure; the spike adds Codex-shaped and local-shaped fake profiles plus dynamic capability changes. |
| F-6 deletion outcomes | **Partially resolved; High remains.** Local erasure and provider cleanup are now separate durable outcomes, but `ProviderCleanupOutbox` retains only adapter ID and session ID while AD-13 permits isolated instance profiles and account switching. Two implementations can either issue deletion under the current account or retain/use the session’s originating runtime profile. Amend AD-9 to retain a stable non-secret provider-instance/profile ID and require cleanup under the originating profile, or require cleanup before that profile/account can be removed or switched. The account-switch spike needs that expected outcome. |
| F-7 export/restore | **Partially resolved; High remains.** Exclusions, offline restore, no reattachment, integrity, and relationship preservation are bound. However, “one deterministic preserve-or-remap” still leaves independent restore units free to choose opposite collision behavior, and the spike names no oracle. Select the policy: preserve IDs when collision-free; on any collision create new Project/entity IDs and atomically rewrite every relationship and Provenance reference, without modifying the existing Project. |
| F-8 containment | **Resolved.** AD-8 and the spike now cover inherited configuration, instruction sources, hostile selected content, path escapes, canaries, commands, tools, network, reads, and writes, with prevention rather than post-side-effect detection. |
| F-9 completeness gate | **Mostly resolved; Medium remains.** Precision/recall and a material-omission criterion now exist, but the “minimum evaluated-item denominator” is still chosen during execution rather than fixed in the ready spike. Record a numeric minimum before running fixtures so the gate cannot be tuned after results are seen. |

### Remaining high changes

1. Reword AD-6 and the diagram to agree with AD-12 that only `ProviderJobCoordinator` validates ProjectOS results for persistence and writes pending proposals.
2. Extend AD-9 cleanup receipts with stable originating provider-instance/profile identity and bind account/profile switch or removal behavior.
3. Choose the restore collision policy in AD-3 and make the Section 6 spike assert that exact outcome.

### Targeted recheck — AD-3, AD-6, and AD-9

**Pass; no critical or high findings remain in the rechecked scope. This supersedes the three remaining-high items above.**

- **AD-3 resolved:** every restore now creates a new Project copy, remaps all Project-owned IDs through one atomic restore map, preserves relationships and Provenance, and performs no provider action. Section 6 asserts the same outcome for offline, repeated, adjacent, collision, unknown-metadata, and older-schema restores.
- **AD-6 resolved:** the adapter parses and validates the provider result, returns the normalized ProjectOS result, and only `ProviderJobCoordinator` may persist a pending Change Proposal. Section 7 prohibits adapter access to domain repositories and verifies idempotent pending-proposal creation without Canonical State mutation.
- **AD-9 resolved:** cleanup receipts now retain ProjectOS provider-profile identity and a non-secret authentication-context fingerprint; logout/account switching attempts cleanup first and incomplete work becomes `reauthRequired` for the matching context. Sections 2 and 6 exercise account switching, later reauthentication, adapter changes, restart, and idempotent cleanup.
