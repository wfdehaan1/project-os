# Implementation contract and delivery order

This is a specification of future files and behavior. Paths in the work table are to be created by the implementing agent, not files that already exist.

## Stack and boundaries

Default to Swift 6.2, macOS 26, SwiftUI with AppKit where native window/menu/file-panel behavior requires it. Produce a normal `.app` through an Xcode project with a shared scheme. Local build/run must not require App Store membership or PCC entitlements. Paid distribution/signing is later work.

Enable App Sandbox with appropriate outbound-network and user-selected export/restore access. Store app data in its own container. Validate local signing and Keychain behavior on the intended Mac; do not require broad filesystem access, embed a shell installer, or make paid membership necessary for the personal build.

Put pure domain types, context construction and validation in a local Swift package, and the native UI and platform integrations in the app target. Use SQLite through the system `SQLite3` library behind a store interface, with one serialized writer, transactions and explicit schema versioning. Keep provider secrets in Security.framework Keychain, outside the project database. No application backend or external database service is needed.

Use Foundation `URLSession` for the two adapters. Domain jobs are `chat`, `proposals`, and `nextAction`. They receive owned value types and return owned events/results; neither adapter receives the store. Expose a small provider registry with identity, model/configuration, execution boundary, context/output bounds, streaming/structured-output/cancellation capability and qualified/unverified/unavailable status. Connectivity and configuration checks alone cannot set qualified status.

## Minimum records and invariants

| Record | Required content |
|---|---|
| Project | Stable UUID, name/description, timestamps, monotonic accepted-state revision, last-visit baseline, optional outcome. |
| Source / message | Stable UUID, project/conversation identity, immutable version and exact original Unicode text, role or source label, timestamp. Completed assistant messages are distinguishable from partial/failed/cancelled output. |
| Artifact | Stable UUID, kind, title/content, state, rationale, evidence, typed relations, versions; optional decision subject and supersession links. |
| Proposal | ID, originating project/job/context revision, operation and typed payload, expected target revision, evidence and dependencies, lifecycle and user edits. |
| Accepted change | Monotonic revision, transaction ID, actor, before/after values including relations, accepted rationale/evidence, originating proposal if any. |
| Context/job | Immutable selected references and texts, provider/model/configuration, source project revision, job/attempt IDs, purpose, status and available usage; no credentials. |
| Saved recommendation | Text, supporting accepted artifact IDs/versions, uncertainty, originating state revision, timestamp, dismissed/stale state. |
| Return record | Visit baseline, elapsed time, understanding/trust/usefulness ratings, meaningful-work outcome, review/correction effort, notes. |

Support Topic; Research (with explicit certainty/limitations); Decision (governing/superseded with subject, rationale and lineage); Open Question (open/resolved/dismissed); Task (open/in-progress/blocked/done). Removal is a historical transition, not erasure of an individual artifact's history. A user may author/correct records directly with the same history/undo rules, without pretending the edit came from AI.

Relationships name meaning: `supports`, `concerns`, `advances`, `blocks`, `supersedes`. At minimum link decisions to research/questions/topics, tasks to decisions/questions/topics, and replacement decisions to prior decisions. Reject missing, cross-project or invalid endpoints; do not silently drop relationships.

Every accepted mutation uses expected revisions and one transaction for artifact versions, relation changes, proposal status, history and project revision. Stale targets/dependencies require explicit rebase and renewed review; unrelated intervening changes can proceed only after deterministic dependency revalidation. Repeated acceptance is idempotent. Undo appends a compensating transaction for the latest accepted change, including related statuses and supersession state; it does not delete history. A failed commit leaves the last coherent state visible and reports that saving failed.

Only one active inference job per project. Navigation keeps work bound to its originating project, not the currently visible one. Provider/model changes cannot alter an in-flight job. Cancellation closes transport and ignores later events; do not promise that the remote provider stopped computing or charging. On restart mark unfinished jobs interrupted and offer an explicit retry, never automatic replay.

At structured-job completion, compare its source project revision with current accepted state. If it changed, do not publish pending proposals or a fresh next action; disclose that the context changed and require explicit regeneration. Preserve any completed conversation text separately. This check is additional to revision/dependency checks when accepting a previously generated proposal.

## Interaction and context

App open → Library; project open → Overview. Provide Overview, Conversation, Knowledge (filter by the five kinds), and Project Settings in a restrained native sidebar. Knowledge inspector exposes current content, rationale, evidence, typed relations and history. Global Settings contains provider configuration. Native keyboard focus, selectable/copyable text, accessible labels, status text beyond color, system light/dark appearance and a resizable window are required. Do not ship a terminal-only harness or a screenshot/mock UI as the MVP.

Conversation has a conversation list, transcript/composer and a proposal rail or recoverable inspector at narrow widths. Drafts persist. `Command-Return` sends; Stop remains available during generation. Provider failures retain the user's draft or sent message and partial answer, with a clear retry action. Pending proposals do not prevent continued conversation.

Each composer contains a visible, expandable Context Preview naming provider/model, local/external boundary, selected description/artifacts/sources/message range and estimated size. Selection can be reused, but refresh the preview against current versions before each explicit send; do not create a mandatory modal every turn. Newly accepted project state is visibly available for inclusion. Pending proposals and superseded decisions are excluded by default; deliberate inclusion labels their status.

Freeze context when the user initiates a job. Use selected accepted artifact versions, exact source excerpts and a visible complete-message range. Source material is untrusted quoted data, never application instructions. Preserve pasted text up to the inherited 250,000-character intake limit; large stored sources need not all enter a prompt. Enforce the chosen model's documented/configured window including instructions, schema and output budget. Use a verified tokenizer when available or a documented conservative upper bound; do not silently discard older messages, sources or governing decisions. If the bound is unknown or exceeded, explain and require narrowing/configuration before dispatch. No embeddings or automatic summarization subsystem.

Three separately authorized actions:

1. **Send:** one streaming conversational request. Preserve completed text and its origin; no automatic second extraction request.
2. **Suggest project updates:** one structured request over the selected sources/complete messages and accepted-state references. Show the resulting small set of consequential proposals beside the conversation. An empty set is valid; do not force tasks or decisions from casual discussion. Enable this from imported material as well as conversation.
3. **Suggest next action:** one structured request grounded in accepted state, with an explanation and valid supporting IDs. No automatic call when Overview opens. Insufficient or contradictory evidence yields uncertainty, not invented guidance.

Reject unknown response properties, invalid enums, malformed JSON, truncated output, unresolved IDs and failed provenance validation before creating pending proposals. Chat content can remain visible even if a later explicit proposal request fails. No hidden repair-model calls. The user can retry or narrow context explicitly.

## Proposal and evidence contract

Define and version the schema in `Resources/proposal.schema.json`; parse the same domain contract for both adapters. Top-level fields: `schemaVersion` and `proposals`. Each proposal contains a unique temporary ID, `operation` (`create`, `update`, `supersede`, `relate`), artifact `kind`, nullable target ID and expected target revision, title/content, nullable rationale/decision subject, evidence references, typed relationships and dependency IDs. New references may use temporary proposal IDs. Each field's nullability, allowed type and operation requirements must be explicit in the schema and semantic validator.

Evidence carries source type, source/message ID, version and exact quoted text. Resolve only against the frozen sent context. Verify the quote as an exact substring without joining unrelated spans, stripping markup, translation or whitespace normalization; highlight the matching span. Multiple identical occurrences may resolve to the first exact occurrence within that referenced excerpt. Generated offsets must not be trusted. IDs/references to unselected material are invalid.

A valid quote proves the text exists, not that a claim follows from it. Mark evidence originating in an assistant message as AI-authored/unverified; model speculation must not be presented as a user commitment. Decision proposals need an explicit user commitment in context or a clear request for the user's decision; do not invent commitment. Unsupported claims remain questions/uncertainty or require explicit user-authored correction. Source edits preserve versions so historical evidence remains navigable.

Surface a proposed replacement with the prior decision and shared subject. Acceptance atomically supersedes the prior decision and creates the new governing one; exactly one governing decision remains for that resolved subject. Model conflict detection is advisory and fallible; the review UI must also let the user mark a proposal as replacing an existing decision. Do not claim semantic conflict detection is deterministic or exhaustive.

Independent proposals can be accepted individually. References to other new proposals create a dependency set: review its combined effects and accept atomically, or leave it blocked until dependencies exist. Editing/rejecting dependencies invalidates the dependent review. No unrestricted Accept All. Rejection is recoverable and never changes accepted state.

## Providers and live readiness

**Ollama:** default to `http://127.0.0.1:11434`; allow a configured loopback IP/port only, reject credentials in URLs and remote/redirected destinations. Use `/api/chat`, parse newline-delimited streaming events, and use schema-constrained output for structured jobs. Validate the selected model actually executes locally: loopback is not proof because a runtime can proxy cloud models. Exclude cloud-backed models; verify offline inference in qualification. Do not install/start/stop runtimes or download models implicitly. Runtime absence has setup instructions and a retry, while local project features remain usable. [Chat API](https://docs.ollama.com/api/chat), [Structured output](https://docs.ollama.com/capabilities/structured-outputs).

**OpenRouter:** direct HTTPS with the user's Keychain credential; explicit stable model selection and a recorded upstream routing target. For reproducible validation pin the selected route, disable provider fallback and require supported parameters. No `auto` model, fallback model list, or hidden provider switch. Use strict JSON-schema output for structured jobs, but always validate locally. Correctly parse SSE events, including a provider error after a successful HTTP response. Show returned usage/cost only when available; unknown is not zero. Keys, authorization headers and raw diagnostic bodies must be redacted. [Structured output](https://openrouter.ai/docs/guides/features/structured-outputs), [Routing controls](https://openrouter.ai/docs/guides/routing/provider-selection).

API references were checked on 2026-09-10. The implementing agent must verify version-specific request/response details when implementing; no live credentials or spend were used to write this spec. Keep provider tests deterministic by default. A live test is explicit, uses only disclosed selected context and an approved spending ceiling, and records actual model/runtime/hardware/configuration, capabilities, limitations, latency, schema/evidence quality and cancellation/failure results. Never inspect unrelated credential files to enable it.

Allow an explicitly initiated test of a configured but unqualified model using disclosed synthetic input; otherwise qualification would be circular. The UI distinguishes connected, unverified, qualified and unavailable. A successful health check cannot certify quality; changing model/version/configuration invalidates the matching qualification. Both adapters must be implemented, even if the user has supplied only one runtime/account for live verification.

## Overview, recovery and outcomes

Overview is built from stored accepted state, not a mandatory model call. Include current governing decisions, unresolved questions, open tasks, research and accepted changes since the previous visit, plus direct links to supporting evidence/history. Capture the previous-visit baseline at entry and keep it fixed for that visit; record visit completion without clearing the just-opened change list. Mark saved recommendations stale whenever their accepted-state revision changes. Dismissal changes only recommendation state.

Export a directory using a staging location and atomic completion: human-readable `README.md` and `project.md`, versioned `project.json`, and a manifest with file checksums. Include original sources, complete/incomplete transcript distinctions, accepted versions, relations, proposal history, context records and return outcomes; omit secrets and runtime caches. Restore validates schema version, checksums and referential integrity before any destination is created. Restore as a new project with a new root identity and consistently remapped references; retain original identities as import metadata where needed. Never overwrite the existing project. Unknown future schema/corruption leaves stores unchanged.

Confirmed permanent project deletion offers export, cancels jobs, removes its app-managed rows/content and prevents late completion from recreating them. A separate setting removes the OpenRouter credential. Explain that project deletion does not remove exports, system backups, shared local models or data independently retained by external providers. Do not claim secure forensic erasure or remote account deletion.

Provide a small optional local form for return duration, understanding/trust/usefulness (1–5), whether work resumed within five minutes, followed recommendation/different action/no action, review/correction time and notes. Allow recording successful completion, intentional closure, abandonment or unresolved outcome. No telemetry backend or automatic engagement prompts.

## Ordered work packages

Paths are repository-relative. Each row ends with a runnable or testable increment; finish the complete loop before expanding scope.

| Order | Files to create | Work and exit condition |
|---|---|---|
| 1 | `apps/ProjectOS/ProjectOS.xcodeproj/`, `ProjectOS/App/ProjectOSApp.swift`, `ProjectOS/App/AppEnvironment.swift`, `ProjectOS/Info.plist`, `ProjectOS/ProjectOS.entitlements`, `Packages/ProjectOSCore/Package.swift` under the app directory | Create shared `ProjectOS` scheme, app/package/test targets and composition root; document local signing/build defaults. Launch a real native window. |
| 2 | `Packages/ProjectOSCore/Sources/ProjectOSCore/Domain/`, `ProjectOS/Persistence/ProjectStore.swift`, `ProjectOS/Persistence/Migrations.swift`, `ProjectOS/Features/Library/`, `ProjectOS/Features/Sources/` | Implement records, transactional store, local projects and labelled paste intake. Relaunch preserves data; simulate save failure. |
| 3 | `Packages/ProjectOSCore/Sources/ProjectOSCore/Context/`, `ProjectOS/AI/AIProvider.swift`, `ProjectOS/AI/ProviderRegistry.swift`, `ProjectOS/AI/JobCoordinator.swift`, `ProjectOS/AI/OllamaAdapter.swift`, `ProjectOS/AI/OpenRouterAdapter.swift`, `ProjectOS/Security/KeychainCredentialStore.swift`, `ProjectOS/Features/Settings/` | Implement context snapshots/bounds, real transport adapters and explicit settings; deterministic contract/failure tests pass. |
| 4 | `ProjectOS/Features/Conversation/`, `ProjectOS/AI/Prompts/`, `Packages/ProjectOSCore/Sources/ProjectOSCore/Proposals/`, `Packages/ProjectOSCore/Sources/ProjectOSCore/Resources/proposal.schema.json` | Stream chat, preserve drafts, stop safely, then explicitly request and validate proposals from conversation or pasted material. |
| 5 | `ProjectOS/Features/Proposals/`, `ProjectOS/Features/Knowledge/`, `Packages/ProjectOSCore/Sources/ProjectOSCore/Changes/` | Review/edit/reject, atomic dependency sets, typed relations, correction/removal, supersession and undo; evidence opens exact retained text. |
| 6 | `ProjectOS/Features/Overview/`, `ProjectOS/AI/NextActionService.swift`, `ProjectOS/Features/Outcomes/` | Offline current state and fixed visit baseline; explicit revision-bound guidance and local return records. |
| 7 | `ProjectOS/Ownership/ProjectArchive.swift`, `ProjectOS/Ownership/ProjectDeletion.swift`, `ProjectOS/Features/Settings/ProjectSettingsView.swift` | Export/verify/new-copy restore and deliberate deletion pass normal and failure cases. |
| 8 | `Packages/ProjectOSCore/Tests/ProjectOSCoreTests/`, `ProjectOSTests/`, `ProjectOSUITests/`, `README.md`, `docs/implementation-report.md` under `apps/ProjectOS/` | Complete acceptance checks, build/launch and real-provider walkthroughs where authorized; document setup, exact commands, screenshots, known limits, test evidence and missing live prerequisites. |

All paths in rows 2–7 are relative to `apps/ProjectOS/`. Directory entries permit cohesive per-type files instead of a giant source file. Use this order as one cohesive product deliverable; do not stop after scaffolding or deliver only fake responses. If a live prerequisite is unavailable, finish independently testable work and report that specific verification gap.
