# Implementation plan

Read SPEC.md and all companions first. Paths below are repository-relative; new paths are proposed seams, not assertions that files already exist. The sequence is a feature plan, not permission to implement during the specification turn.

## Architecture and reuse

Retain `AIProvider`/`InferenceService` for Ollama and OpenRouter. Add a separate app-owned `AgentSessionProvider` contract for create/load session, model selection, policy, prompt, interrupt, permission response and normalized events. ACP details belong in `CodexACPAdapter`, not `ConversationView`, domain models or the proposal validator. A fake second adapter proves the boundary without adding a framework or another real provider.

Use the experiment's protocol tests, restrictions, proposal-validation evidence and UI lessons. Do not copy its global relay cursor, `state.json`, static synthetic IDs, manual pairing or full replay suppression into production. The domain store is never passed to the runtime or exposed as a tool.

An application-owned `AgentConversationCoordinator` actor owns each session and attempt. All windows subscribe to that owner. It participates in the existing one-active-job-per-project and deletion-fence rules. Do not run a competing independent lifecycle beside `AppEnvironment`'s current generation state.

Normalized events cover message deltas, tool start/update/end, permission requested/resolved, model identity, usage when supplied, compaction/history uncertainty, completion and terminal failure. Include app attempt/session generation and a durable event identity. Preserve opaque provider IDs inside the adapter/store binding; never use them as the sole project ownership check.

### Data contract

| Record | Required data and invariant |
|---|---|
| Conversation backend binding | Direct/agent kind, provider, configuration identity; absent for migrated conversations until explicitly chosen; defaults cannot overwrite it |
| Agent session generation | App UUID, project/conversation IDs, opaque remote handle, non-secret account identity, model, runtime/adapter versions, policy digest, sync state, start/end; one owner and one current generation |
| Turn/attempt | App turn and attempt IDs, remote turn mapping when available, purpose, source revision, effective model/policy, status and terminal reason; distinguish unsent, sent and unknown outcomes |
| Disclosure manifest | Exact text/versions transmitted for the turn, selected IDs, purpose and destination; immutable and inspectable; includes app-added instructions/schema separately from user evidence |
| Agent activity journal | Stable item/event mapping, sequence, safe display payload, permission decision and completion state; transcript update and applied cursor commit atomically |
| Generation job | Links proposal output to its isolated session, reviewed evidence packet and project revision; normal inbox retains pending proposals |

Local database v3 remains readable. Use the next available migration version at implementation time, with additive tables/optional decoded fields. Enforce project/conversation ownership on every session lookup and write, not only foreign-key presence. Do not infer old message providers from current settings. Persist permission decisions but never revive an unanswered permission grant after restart.

Bound in-memory queues and RPC payloads. Durable journaling, explicit backpressure or a visible synchronization failure must prevent silent event loss. Persist enough to reconcile a response that finished after the UI disconnected; do not store hidden reasoning or secrets as a substitute for a normalized journal.

### Lifecycle invariants

- Freeze destination and policy before sending. Persist the outgoing attempt before crossing the runtime boundary. A crash between send and acknowledgement produces an unknown state, never an automatic resend.
- Apply events only to the matching project, conversation, session generation and attempt. Terminal states invalidate permission decisions and later deltas. Cancellation can retain already received text while excluding late project proposals.
- Stop requests interrupt the agent and wait for terminal acknowledgement; on bounded timeout, stop the owned runtime and mark execution uncertain. Reject new work on that session until recovery establishes a terminal state or the user starts fresh.
- Resume checks ownership, account, version and effective policy. Reconcile stable remote turn/item identities into existing app messages transactionally. If the adapter cannot establish identity/completeness, mark unreconciled and offer an explicit fresh session; do not append raw replay or quietly drop it.
- Model and research policy changes happen between turns. Start a new session when enforcement cannot change safely on an existing session. Never reuse a session across projects/accounts or for an imported archive.
- A fresh generation preserves local transcript and disclosure history; its initial remote context is only the visible selected packet. Compaction is not deletion, and current-state updates are not erasure of historical disclosure.

## P0 — qualify the runtime boundary

**First task; required before real-project enablement.** Synthetic-only qualification can be implemented independently of the feature UI.

**Work:** Extend `spikes/codex-acp-chat/` qualification fixtures and create `apps/ProjectOS/docs/codex-runtime-decision.md` when implementation begins. Record selected adapter/runtime versions, effective configuration, launch/IPC topology, auth flow, allowed native tools, sandbox roots and known unsupported controls. Begin with ACP `1.12.0` / observed Codex `0.154.0`; do not assume those are permanently current or qualified.

**Prove from the signed sandboxed app:**

1. A user-approved setup can establish and subsequently launch/reconnect a managed helper without disabling the app sandbox or requiring a terminal every session. Evaluate a supported helper/login-item arrangement; do not assume a bundled XPC service escapes inherited sandbox restrictions.
2. Codex-managed authentication works with the selected profile arrangement. Account refresh/expiry is detectable without ProjectOS reading/copying credentials. Isolate inherited config, hooks, skills, plugins and MCP while preserving auth through supported mechanisms; never copy `auth.json` as a shortcut. If shared authentication cannot be isolated safely, use a dedicated runtime-owned profile and a fresh Codex-managed login.
3. Model tools can search/read remote pages when enabled and cannot run shell, read arbitrary home/project-store files or write accepted state. Distinguish model tool access from the runtime's internal need for its own auth/session files. Test attempted operations, effective policies and filesystem effects; one model refusal is insufficient.
4. Research disabled is enforced on both new and resumed turns. Built-in search remains available under the qualified restrictions when enabled.
5. Runtime/account mismatch, unsupported versions and missing controls produce an unavailable state, not automatic configuration weakening.

**Exit:** A recorded, repeatable supported configuration and launcher choice. If ACP cannot carry the necessary controls, compare a narrow adapter patch with a direct supported Codex integration **behind the same interface**; document the chosen change and rerun the same gate. If none qualifies, continue mock-backed work but keep real data disabled and report the precise blocker. This is the plan's main technical uncertainty.

## P1 — session contracts and persistence

**Depends on:** feature contracts; can run with fixtures while P0 is unresolved.

**Files:** new `AI/Agents/AgentSessionProvider.swift`, `AgentConversationCoordinator.swift`, `Models/AgentConversationRecords.swift`; existing `Models/AppModels.swift`, `Persistence/Migrations.swift`, `ProjectStore.swift`, `AI/JobCoordinator.swift` or the app's actual shared job owner. Add focused tests under `ProjectOSTests/`.

**Deliver:** normalized capability/events, backend binding, session generations, durable turn/activity/disclosure records and restoration of interrupted jobs. Keep direct inference interfaces intact. Include a fake agent without Codex JSON in its consumer. Define protocol generation and compatibility handling; unsupported fields must not become fake capabilities.

**Exit:** migration preserves a v3 fixture, two projects cannot share a remote session, two windows do not own competing transports, replay is idempotent and unknown outcomes cannot resend automatically.

## P2 — guided setup and managed helper

**Depends on:** P0 selection and P1 contracts.

**Files:** new `AI/Agents/CodexACPAdapter.swift`, `CodexRuntimeManager.swift`; helper target/package under `apps/ProjectOS/CodexRuntime/` if P0 selects one; `Features/Settings/InferenceSettingsSection.swift`, `App/ProjectOSApp.swift`, entitlement/project changes only as justified by P0.

**Deliver:** explicit install/locate, compatibility check, account status/login handoff, model discovery, reconnect and uninstall/disable helper behavior. Runtime launch uses fixed validated binaries/arguments and a sanitized environment. If loopback IPC remains, authenticate it, reject redirects/browser Origins, bind only locally, rotate credentials and store any durable pairing secret in Keychain. Prefer supported process identity checks where the selected topology provides them. Never log credentials.

**Exit:** a second clean setup follows the in-app flow; after restart chat needs no terminal/pairing paste. Incompatible runtime, quota and login expiry retain local data and show the correct recovery action. Bundling/updates must pin and requalify the adapter/runtime combination rather than executing floating `npx latest` on launch.

## P3 — ordinary conversation, context and research

**Depends on:** P1; live acceptance depends on P2.

**Files:** `App/AppEnvironment.swift`, `AppEnvironment+Presentation.swift`, existing provider configuration/selection types, `Features/Conversation/ConversationView.swift`; proposed `AgentContextPreview.swift` and `AgentActivityView.swift` only where useful.

**Deliver:** backend-bound conversations, streaming and Stop, model selection, continued-conversation transfer preview, Research policy, durable activity/citations and the two-section context preview. Reuse the existing geometry-owned layout and draft storage. Make direct stateless bounds and agent retained-history disclosure separate concepts.

**Exit:** two project conversations stay isolated through navigation and restart; Codex never constructs `WebResearchToolbox`; stale OpenRouter research flags cannot invoke SearXNG; fresh generations do not inherit excluded context. No silent backend switch for unsupported actions such as Overview guidance.

## P4 — evidence-bounded proposal generation

**Depends on:** P1–P3.

**Files:** new `AI/Agents/AgentProposalService.swift`; reuse `AI/InferenceService.swift` conversion seams, `ProjectOSCore/Proposals/ProposalValidator.swift`, existing proposal inbox and `ProjectStore.acceptProposal`/domain change engine.

**Deliver:** explicit proposal request from a frozen, visible evidence packet in an isolated generation session with tools disabled. This bounds provenance independently of the long-running chat. Validate strict schema, permitted artifact states, exact contiguous quotes, revisions, dependencies and decision semantics before saving to the normal pending inbox. No assistant-text parsing on ordinary chat completion. Dispose of/close generation runtime state where supported; disclose provider history retention otherwise.

**Exit:** all existing artifact kinds remain available; fabricated page quotes, invalid JSON, stale targets, cancelled attempts and deleted projects cannot create pending/accepted changes. Acceptance uses the existing atomic transaction and remains a separate user action.

## P5 — crash recovery, export, deletion and cleanup

**Depends on:** P1–P4.

**Files:** `Persistence/ProjectStore+Archive.swift`, `Ownership/ProjectArchive.swift`, deletion fencing, session coordinator and runtime manager; archive/migration fixtures and tests.

**Deliver:** deterministic resume reconciliation, corrupt-data preservation, owned process cleanup, pending-review restoration and readable history offline. Export safe transcript/activity/disclosure and requested model provenance. Exclude credentials, account identifiers, machine paths that expose secrets, and live attachable handles. Restore remaps project/conversation/session-generation IDs and marks provider bindings detached; no inference or remote attachment occurs during restore.

Deletion first fences and cancels active work, then atomically removes app-managed project/session/activity records. A helper-side session cannot resurrect local rows. Remove project-specific helper data when ownership is known; never delete the user's general Codex history/configuration. Provider-side deletion is capability-dependent and cannot be implied by local success.

**Exit:** AC-12–18 and AC-21–22 pass; app/helper crash and deletion races cannot duplicate turns, lose acknowledged local content or attach a restored project to an old remote conversation.

## P6 — integrated qualification and personal-use handoff

**Depends on:** all phases, including P0 evidence.

**Files:** app/core tests as relevant, `ProjectOSUITests/`, `apps/ProjectOS/docs/codex-integration-report.md` and setup instructions. Preserve original experiment evidence.

**Deliver:** all acceptance scenarios with exact adapter/runtime/model and build identity, separately labeled deterministic, live and personal-use results. Test the real signed app's setup/login/permissions/restart path; a relay CLI run alone is insufficient. If XCUITest remains unavailable, record the environment failure and use documented direct native verification without claiming an automated pass.

Use a user-selected real project only after P0 and explicit live-use authorization. Record setup steps, latency, recovery behavior, context understanding, proposal corrections and return usefulness; do not declare usefulness on Wouter's behalf.

**Exit:** the SPEC success loop is demonstrated; known limitations are surfaced in-product and in the report. Only then enable the production Codex entry by default and remove the experiment from the normal menu. Retain its fixtures/evidence as regression material.

## Suggested work units

Create one implementation task per phase, splitting P1 into persistence and lifecycle only if useful. P1 mock work may proceed while P0 is investigated; all real-data tests wait for P0. P3 and P4 must land behind the qualified-provider gate. P5 is required for the first usable release, not a later polish task. No calendar estimate is asserted until P0 resolves the helper and enforcement path.
