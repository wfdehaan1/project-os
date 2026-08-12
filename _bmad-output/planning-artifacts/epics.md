---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/validation-spike.md
  - _bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md
---

# ProjectOS - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for ProjectOS, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: The user can create, name, close, and reopen a Project whose data and Canonical State persist locally on the Mac without a ProjectOS account or hosted ProjectOS service.

FR2: The user can supply explicitly selected pasted text as Source Material during setup or Conversation; the material retains a visible source label and provenance identity, and ProjectOS does not scan unrelated local data or bulk-import provider history.

FR3: The user can conduct an AI Provider Conversation using user-selected Project context, inspect the transmission scope before dispatch, and retain the Conversation as local context and Provenance.

FR4: ProjectOS can generate typed create or update Change Proposals for Topics, Research, Decisions, Open Questions, and Tasks from Conversation or Source Material, with type, proposed content, and supporting Provenance, while keeping proposals outside Canonical State.

FR5: The user can accept, edit before accepting, or reject every consequential Change Proposal; rejection leaves Canonical State unchanged, accepted edits store the approved content, and pending proposals remain visibly distinct from accepted Artifacts.

FR6: ProjectOS can identify a potential conflict between a proposal and an accepted Decision and require explicit resolution; accepting a replacement leaves exactly one Governing Decision for the subject and preserves the prior Decision as Superseded with its linkage.

FR7: The user can inspect and update stable-identity Topics, Research, Decisions, Open Questions, Tasks, and explicitly typed relationships among them, including support, advancement, and supersession relationships.

FR8: ProjectOS preserves accepted Rationale and available Provenance for consequential Artifacts and state transitions, supports navigation to exact Conversation or Source Material where available, and discloses missing provenance rather than inventing it.

FR9: ProjectOS records accepted Artifact versions and Decision supersession history so prior accepted state and transitions remain inspectable while current Canonical State is unmistakably primary.

FR10: The user can correct an Artifact or undo the most recent accepted state change without corrupting unrelated Project State; correction preserves prior accepted values and undo restores a coherent state that can be reversed or reapplied through a new accepted change.

FR11: The user can open a locally available Re-entry View showing current Governing Decisions, current Open Questions and Tasks, Research accepted since the last visit, and accepted Canonical State changes since that visit, with access to rationale, provenance, and history without rereading full Conversations.

FR12: ProjectOS can recommend an optional Next Action grounded in accepted Artifacts and relationships, explain what it advances or closes, disclose insufficient or contradictory evidence, and allow dismissal without changing Canonical State.

FR13: The user can locally record a Qualifying Return's elapsed time, understanding, trust, Next Action usefulness, whether Meaningful Work began within five minutes, and qualitative notes; the record is exportable.

FR14: The user can configure and validate Ollama, LM Studio, or MLX for local inference, or OpenRouter as an optional external adapter; runtime and model capabilities are explicit, the OpenRouter key is Keychain-backed, no adapter or model switch is silent, and local capabilities remain available when inference is unavailable.

FR15: Before inference, ProjectOS identifies the adapter, model, local-versus-external boundary, and selected scope; local previews state that Project content remains on the Mac, OpenRouter previews disclose external usage-based processing, and every operation requires explicit user initiation.

FR16: The user can atomically export a complete human-inspectable Project representation and reopen or restore it without losing Canonical State, Rationale, Provenance, relationships, or versions; exports exclude credentials, runtime state, and unsanitized logs, and failed export leaves the source unchanged.

FR17: The user can deliberately remove an Artifact from current Canonical State while retaining its transition history, and can permanently delete a local Project after an effects confirmation and export offer; local deletion, OpenRouter credential removal, local runtime/model data, and any declared provider-session cleanup report separate truthful outcomes.

FR18: ProjectOS can add or replace an AI Provider Adapter without changing the Canonical State model or core Conversation, proposal, re-entry, export, and deletion workflows; adapters advertise capabilities, contribute provider-specific settings through a shared surface, use replaceable session bindings, and never silently change accepted state.

### NonFunctional Requirements

NFR1: ProjectOS must never silently discard or corrupt accepted Canonical State; persistence or migration failure must be explicit and preserve the last known coherent state.

NFR2: Every accepted state transition must be atomic from the user's perspective: the complete transition becomes visible or Canonical State remains unchanged.

NFR3: Project data must remain recoverable through a verified export without requiring a ProjectOS-hosted service.

NFR4: AI-generated content must remain visibly distinguishable from user-accepted Canonical State throughout the application.

NFR5: ProjectOS must not fabricate Provenance, certainty, or the existence of accepted state.

NFR6: Model-quality limitations and failures must be explained in plain language and must never silently degrade Canonical State.

NFR7: Canonical project content must remain on the user's Mac; the validation build has no ProjectOS-hosted project-content backend.

NFR8: Provider secrets must never enter Project data, logs, diagnostics, exports, or ProjectOS-created backups; the OpenRouter API key must be stored in macOS Keychain and only a non-secret configuration and Keychain reference may be persisted.

NFR9: Only user-selected context required for an explicitly requested operation may enter inference; Ollama and LM Studio MVP endpoints must be loopback-only, MLX inference must remain on-device, and OpenRouter transmission must be explicit and externally disclosed.

NFR10: Browsing Canonical State, Rationale, Provenance, and the Re-entry View must remain available without network access.

NFR11: Current state must be the default presentation, with history and evidence available on demand without overwhelming the primary workflow.

NFR12: Product language must be calm, concise, inspectable, and honest about uncertainty, transmission, adapter and model identity, execution locality, OpenRouter cost, runtime/resource state, and failure.

NFR13: Domain workflows and persisted Canonical State must depend only on the provider-independent AI capability contract; provider protocol types, authentication, sessions, usage models, and errors must be confined to adapters and normalized at the boundary.

### Additional Requirements

- AR1 — The completed Codex App Server spike records `reject` and permanently blocks production Codex work under that architecture. The approved 2026-08-09 architecture revision authorizes a different production path without claiming that the Codex gate passed.
- AR2 — `AiProviderPort` and `ProviderRegistry` use ProjectOS-owned request/result/job/lifecycle types and dispatch-time capability claims (`supported`, `unsupported`, `temporarily unavailable`, `unknown`) scoped to the adapter instance, runtime version, model, and configuration.
- AR3 — Ollama, LM Studio, and MLX are first-class local MVP adapters. Discovery may suggest an available adapter, but the active runtime and model are always selected explicitly; no local adapter or model is a silent fallback for another.
- AR4 — Ollama and LM Studio MVP adapters accept supported loopback endpoints only. A non-loopback endpoint fails setup rather than being presented as local processing. ProjectOS does not silently install, start, stop, update, or download models through user-managed runtimes.
- AR5 — MLX runs through a native on-device adapter. Supported libraries, model formats, packaging, storage, minimum hardware, and resource readiness are production compatibility criteria resolved during implementation architecture, not another feasibility spike.
- AR6 — OpenRouter is the only MVP external adapter. Its API key is stored in macOS Keychain; ProjectOS persists only non-secret configuration and a Keychain reference outside Project data and excludes the secret from logs, diagnostics, exports, and ProjectOS-created backups.
- AR7 — Context Preview names the active adapter, model, local/external boundary, selected scope, language, and capability limitations. OpenRouter also discloses external processing and usage-based billing. No runtime, provider, model, retry, or resend fallback occurs silently.
- AR8 — ProjectOS owns canonical Conversation IDs and transcripts. Optional provider session IDs are replaceable adapter-keyed bindings used only when the adapter declares persistent sessions; exports exclude them and restore performs zero provider calls.
- AR9 — Structured proposal generation uses the ProjectOS-owned Change Proposal schema. Every completed result is parsed and revalidated inside ProjectOS, and only the Provider Job Coordinator may persist a pending proposal; partial, malformed, cancelled, or stale output never becomes a proposal or Canonical State.
- AR10 — Normalized events carry durable job ID, adapter-instance ID, attempt, and deterministic ordering. A shared reducer yields exactly one terminal result despite duplicate, late, reordered, cancellation-race, timeout, retry, or concurrent-turn traces.
- AR11 — Normalized errors distinguish local runtime, model, format, resource, and generation failures plus OpenRouter credential, network, rate, quota, billing, and service failures only when explicit evidence supports the category; unknown failures remain unknown and persisted diagnostics remain sanitized.
- AR12 — Every production adapter exposes generation only. ProjectOS supplies selected context as data and exposes no tools, commands, filesystem access, web search, MCP servers, connectors, apps, plugins, skills, or Canonical State, Conversation, Change Proposal, export, or deletion repositories.
- AR13 — The application-owned coordinator carries durable job, Conversation, attempt, and expected-revision identities; completion and proposal persistence are idempotent, and only explicit application transactions accept, edit, reject, correct, undo, or supersede Canonical State.
- AR14 — Adapter/model readiness and quality are implementation acceptance criteria. Representative cross-domain fixtures record per-artifact precision/recall, unsupported claims, provenance quality, correction effort, malformed-output rejection, and whether omissions change governing state or re-entry meaning.
- AR15 — One reusable behavioral contract suite passes against deterministic fakes and all four production adapters. Each adapter also has targeted integration tests for runtime/model compatibility, resources, streaming, cancellation, schema output, failure normalization, boundary disclosure, and no-fallback behavior.
- AR16 — Local Project deletion, OpenRouter credential removal, user-managed Ollama/LM Studio installations and models, ProjectOS-managed MLX caches/models, and independent external retention are separate truthful outcomes.
- AR17 — Provider cleanup obligations exist only when an adapter declares and uses persistent provider sessions. Local deletion can complete while a declared external cleanup obligation remains explicit and retryable; cleanup never requires restoring or resending Project content.
- AR18 — No production adapter, model, or capability may be marked ready from adapter identity alone. Supported versions, models, model formats, minimum hardware, context limits, and known degradations are recorded and evaluated at dispatch.

### UX Design Requirements

UX-DR1: Implement a native macOS application shell whose app-open destination is Project Library and project-entry destination is Overview, with the finalized sidebar hierarchy, footer destinations, native windows/menus/Settings/focus/undo/text/notification/accessibility behavior, and no account row, permanent Add Project control, horizontal artifact tabs, or standalone brand mark.

UX-DR2: Implement semantic design tokens for five curated presets—Studio Paper, Signal Slate, Quiet Grove, Fjord Air, and Aubergine Ledger—across Light, Dark, and explicit Increase Contrast branches; components resolve semantic roles only and never bind directly to preset literals.

UX-DR3: Enforce the committed contrast contract: normal text at least 4.5:1, qualifying large text and essential graphics/boundaries/selection/focus at least 3:1, decorative dividers never as the sole cue, and accessibility preference handling overriding theme identity.

UX-DR4: Use native San Francisco typography, SF Mono only for technical literals, the 4/8/12/16/24/32 spacing rhythm, and 6/8/10/14/full radii; Dutch expansion and supported system text enlargement must wrap/reflow without truncating essential labels, actions, statuses, provider disclosures, or canonical effects.

UX-DR5: Implement resizable native-macOS layouts rather than web breakpoints: persist sidebar width per window, support icon-only collapse, stack the Overview masthead when needed, transform Conversation list/rail into recoverable panes at narrow widths, and retain a reflowing Map outline/Inspector equivalent.

UX-DR6: Use deterministic motion constants of 140 ms for local feedback, 220 ms for navigation/pane continuity, and 300 ms for deliberate atomic transitions; prohibit decorative motion and animated token streaming, and honor Reduce Motion with immediate or opacity-only 140 ms updates.

UX-DR7: Build one reusable `Button` with primary, secondary, ghost, destructive, and disabled variants; disabled provider actions remain visible with a persistent reason and an enabled recovery/explanation route.

UX-DR8: Build a reusable `Status Badge` that exposes status text and accessibility state and distinguishes pending, accepted, blocked, superseded, offline, and current without color; counts include only actionable items.

UX-DR9: Build `Project Sidebar` and `Project Switcher` components with grouped hierarchy, active treatment, badges/offline state, collapse tooltips/accessibility names, pointer plus keyboard/menu resize/reset, local project switching, and no provider request on switch.

UX-DR10: Build `Project Card` as one focus target containing only project title and `Pile Cover`; opening goes to Overview and internal cover marks are not interactive.

UX-DR11: Build `Pile Cover` as a local, offline, deterministic vector renderer using stable, countable, non-color-only geometry for Governing/Superseded Decisions, unresolved Questions, actionable proposal sets, and ground; preserve placement through state/theme changes, support at least 40 Decision blocks via uniform scaling, and regenerate identically after restore.

UX-DR12: Build `What's Up Next Card` for Needs recap, Current, and Offline states, with explicit generation/continuation, local inspection, dismiss-without-mutation, provider reason, intrinsic height, and stack behavior alongside `Pile Cover`.

UX-DR13: Build `Relational Briefing` as locally available, current-state-first orientation showing read-only description, accepted history, relationships, affected work, related state, and links to provenance/history; description editing routes to Project Settings.

UX-DR14: Build `Conversation List`, `Transcript`, and `Composer` as shared components supporting local titles/search/Topic filter, persisted selection/draft/scroll/review position, readable streaming and Incomplete output, provenance anchors, multiline drafts, `⌘Return` send, `⇧Return` newline, `Esc` preservation, and no offline queue.

UX-DR15: Build `Context Preview` before every inference call, naming the active Ollama, LM Studio, MLX, or OpenRouter adapter and model, local-versus-external boundary, exact selected scope, Sources/excerpts, working language, one-hop Map context when relevant, capability limitations, and OpenRouter usage-based billing; the user can narrow or add explicit items before starting.

UX-DR16: Build `Proposal Rail`, `Change Proposal Card`, and `Proposal Inspector` as a persistent region visually and semantically separate from Transcript and Canonical State, covering current/project-wide scope, artifact type/operation/source/set/dependency/status, exact-source navigation, proposed/original/effects/provenance/diff, edit drafts, accept, reject, defer, and revise.

UX-DR17: Implement the dependency-ordered Change Proposal lifecycle: independent review where allowed, atomic hard-dependency acceptance, combined-effects review before compatible-set acceptance, dependent revalidation after edit, blocked-but-not-rejected dependents after rejection, recoverable rejection, and full Accepted-with-edits audit data.

UX-DR18: Build `Artifact Row` and `Artifact Inspector` with current state first, historical state never styled as governing, shared type/title/status/content/rationale/relationships/provenance/history anatomy, and type-aware local/provider actions.

UX-DR19: Implement the finalized Artifact contracts and states for Topic, Task, Decision, Research, Open Question, Conversation, and Source Material, including required fields, lineage, type-aware actions, direct-edit version/Undo rules, linked Decision creation for direct question answers, and no implicit Decision/Question transitions from task completion.

UX-DR20: Build `Relationship Inspector` and `Project Map` with explicit relationship meaning, endpoints, rationale, provenance, effects, Current/Needs review/Historical/Proposed state, synchronized canvas and stable type-title outline, lenses, filters, selection/multi-selection, focus mode, and equivalent pointer/menu/keyboard actions.

UX-DR21: Limit automatic Map context to selected items plus directly connected current accepted artifacts; Historical/Proposed and larger scopes require explicit selection, two-hop context is never automatic, Conversation provenance nodes are hidden by default, and resuming provider work requires a fresh Context Preview.

UX-DR22: Build `Source Inspector` for original/extracted content, metadata, language, usage and links, with Complete/Partial/Failed/Needs OCR/Needs password states and effects disclosure before removal.

UX-DR23: Implement local Source intake with exact originals retained: pasted text up to 250,000 characters, `.txt`/`.md` up to 10 MB each, searchable PDFs up to 50 MB or 500 pages, and batches up to 25 Sources; preflight rejects unsupported/over-limit inputs before extraction, scanned/encrypted PDFs remain truthful Needs states, and import/extraction never invokes inference or creates Canonical State.

UX-DR24: Build `Notification Center` as a durable, grouped, deduplicated list with read/action state and exact-context deep links; use inline routine feedback, in-app durable outcomes, and macOS notifications only for user-initiated background work when not frontmost, with no engagement or automatic-recap notifications.

UX-DR25: Build `Progress Indicator` with truthful named phases, determinate values only when measurable, safe Stop/Cancel where applicable, and persistent in-surface/history completion or failure replacing progress.

UX-DR26: Build `Empty State` with a plain explanation, one primary action, at most one optional secondary action, no fabricated samples, and no AI requirement for local creation.

UX-DR27: Build `Settings Row` and `Confirmation Sheet` with native form semantics, inherited/reset/Undo disclosure, persistent reasons/errors, separated destructive rows, safe initial focus/cancel, explicit canonical/deletion effects, recovery limits, and export-first for Project deletion.

UX-DR28: Build `Command Palette` and `Search Field` with `⌘K` global commands/projects, `⌘F` current-surface search, `⌘G`/`⇧⌘G` navigation, scoped labels/counts, focus restoration, disabled reasons, and no bypass of proposal review or confirmation.

UX-DR29: Implement First Run as skippable language/privacy orientation with local-first Ollama/LM Studio detection, explicit MLX setup, optional OpenRouter Keychain setup, explicit runtime/model selection, Continue without AI, truthful readiness summary, and direct entry to an empty Project Library without a tour, sample data, theme prompt, or notification prompt.

UX-DR30: Implement Project Library and New Project flows with search/empty/corrupt/restore/cleanup states, Project Cards, Restore, short-description local creation, deterministic empty cover, and the choices Start guided Conversation, Import existing material, or Open Overview.

UX-DR31: Implement Overview's state-bound return lifecycle: one explicit generation produces historical Recap and future What's up next for the same Canonical-State version; closing Recap hides it only for the visit, canonical change invalidates both immediately, matching pairs remain offline-readable, and continuation performs only the specifically previewed grounded call.

UX-DR32: Implement distinct, persistent global and surface states for cold load, local runtime missing/stopped/incompatible, model unavailable/incompatible, insufficient local resources, local inference progress/failure, network offline with local inference available, OpenRouter unconfigured/invalid-key/rate/quota/billing/network/service failure, canonical transaction failure, permission denial, and declared provider cleanup; preserve local work and drafts and never silently queue or reroute inference.

UX-DR33: Keep every locally computable action available offline, including configured Ollama, LM Studio, or MLX inference when its runtime/model is ready; project/artifact/source/conversation/proposal/history browsing and search; Map/outline; local import/extraction; direct edits/Undo; proposal review; drafts; validation records; export/restore/verify; settings; and local deletion. OpenRouter actions remain visible but disabled with a reason and require a fresh preview after reconnect.

UX-DR34: Implement global/project settings precedence as Follow macOS appearance → global theme preset → optional project identity preset → live accessibility preferences; project overrides may change identity roles only and Reset to global removes the override.

UX-DR35: Localize the complete UI, menus, settings, notifications, dates/numbers/usage, help, and accessibility metadata in English and Dutch with identical shortcuts; keep original/user content unchanged, expose known language, never guess unknown language, and make translations explicit and reviewable.

UX-DR36: Implement atomic offline human-readable export (README, Markdown, JSON, Sources, validation records, manifest/checksums), read-only restore preflight, new-copy restore with atomic migration/rollback, and verification of manifest plus representative provenance; disclose corruption, conflicts, or missing evidence.

UX-DR37: Implement permanent Project deletion, OpenRouter credential removal, user-managed Ollama/LM Studio runtime and model storage, ProjectOS-managed MLX data, and any declared provider-session cleanup as separate UX outcomes. Cleanup receipts are required only for adapters using persistent external sessions and never retain Project title/content.

UX-DR38: Implement Return Outcome Record as an explicit native local form with elapsed time, understanding, trust, Next Action usefulness, Meaningful Work, optional notes, draft preservation, offline parity, export inclusion, associated validation errors, and no automatic focus theft or ticking live region.

UX-DR39: Meet relevant EN 301 549 non-web software/documentation requirements and WCAG 2.2 AA outcomes for native macOS using native controls/collections by default and a complete macOS accessibility hierarchy for custom components.

UX-DR40: Enforce the shared accessibility semantics for every named component—name/value/state/description, grouping/relationships/actions, keyboard/focus/fallback, bounded announcements, and target/drag alternatives—with custom targets at least 24×24 points unless a documented WCAG exception applies.

UX-DR41: Implement the finalized keyboard model with visible menu/control equivalents and identical EN/NL bindings, no Vim/unmodified custom sequences, no global proposal accept/reject shortcut, and canvas parity through outline/menu/click/keyboard controls.

UX-DR42: Preserve logical focus and selection through pane changes, close/remove/filter actions, incoming content, and failures; use retained-origin → next → previous → heading/empty-state fallback, reveal obscured focused controls, never require hover/double-click/drag for core work, and never let incoming content take focus.

UX-DR43: Honor Increase Contrast, Differentiate Without Color, Reduce Transparency, Reduce Motion, Invert Colors, and system text/focus preferences live without restart or loss of focus, selection, meaning, or Canonical State; test all five themes in Light/Dark with the required accessibility combinations.

UX-DR44: Use bounded accessibility announcements: never announce tokens or every percentage; announce provider start, meaningful phase changes, completion/failure, Incomplete output, proposal readiness, and Online/Offline boundaries once; interrupt speech only for immediate data-loss, privacy, or safety consequences.

UX-DR45: Validate release accessibility with Full Keyboard Access, VoiceOver, Voice Control, Switch Control, supported text sizes, EN/NL, online/offline/provider failures, automated contrast/hierarchy/target/localization regressions, and manual assistive-technology, reflow, focus-obscuring, and error-prevention checks; provide accessible English/Dutch keyboard and accessibility help.

UX-DR46: Keep microcopy calm, concise, literal, and inspectable; always distinguish accepted, proposed, historical, incomplete, offline, disabled-with-reason, extraction-needs, and provider-boundary states without relying on color, position, animation, or transient notices alone.

### FR Coverage Map

FR1: Epic 2 - Create and persist local Projects without a hosted account.
FR2: Epic 2 - Bring explicitly selected Source Material into a local Project with provenance.
FR3: Epic 3 - Conduct provider Conversations using previewed, user-selected Project context.
FR4: Epic 3 - Generate typed Change Proposals that remain outside Canonical State.
FR5: Epic 3 - Accept, edit and accept, or reject consequential proposals explicitly.
FR6: Epic 3 - Resolve Decision conflicts and supersession without silent replacement.
FR7: Epic 2 - Maintain typed Artifacts and explicitly meaningful relationships.
FR8: Epic 2 - Preserve and navigate accepted Rationale and Provenance.
FR9: Epic 2 - Preserve versions and distinguish Governing from Superseded state.
FR10: Epic 2 - Correct or undo accepted changes without corrupting unrelated state.
FR11: Epic 4 - Present a locally available current-state-first Re-entry View.
FR12: Epic 4 - Recommend and explain an optional Next Action from Canonical State.
FR13: Epic 4 - Record local, exportable outcomes for Qualifying Returns.
FR14: Epic 3 - Configure and validate Ollama, LM Studio, MLX, or OpenRouter under the approved replacement architecture.
FR15: Epic 3 - Disclose adapter/model identity, local or external execution, selected scope, and OpenRouter billing before dispatch.
FR16: Epic 5 - Export, verify, and restore a complete human-inspectable Project.
FR17: Epic 5 - Remove Artifacts and permanently delete Projects with truthful credential, runtime/model-data, and capability-aware provider cleanup outcomes.
FR18: Epic 3 - Keep provider implementations replaceable behind the ProjectOS capability contract.

## Epic List

### Epic 1: Prove a Safe AI Path—or Stop

Wouter obtains reproducible evidence that Codex App Server can safely support ProjectOS through ChatGPT subscription access without compromising containment, cleanup, quality, or provider neutrality. The outcome is `proceed`, `proceed with constraints`, or `reject`; failure of any stop condition halts the Codex path before production implementation.

**FRs covered:** None directly. This completed historical epic gates only the rejected Codex App Server path.

**Implementation notes:** Completed with `reject`. Its original spike requirements and evidence remain preserved in the Story 1.x contracts and harness. The 2026-08-09 architecture revision authorizes a different local-first production path without claiming that this gate passed.

### Epic 2: Establish a Trusted Local Project

Wouter can create, reopen, and work in a native local Project; bring in selected Source Material; maintain typed Artifacts and explicit relationships; and inspect, correct, version, or undo accepted state with rationale and provenance.

**FRs covered:** FR1, FR2, FR7, FR8, FR9, FR10.

**Implementation notes:** Establishes the local persistence model, Project Library, project shell, source intake, Canonical State, artifact contracts, history, inspectors, Map/outline foundations, offline behavior, themes, localization, and accessibility baseline. It may proceed under the approved replacement architecture and requires no configured inference adapter.

### Epic 3: Turn Local-First AI Conversation into Governed State

Wouter can explicitly select Ollama, LM Studio, or MLX for local inference, optionally select OpenRouter for external inference, preview the exact runtime/model and boundary, conduct grounded Conversations, and review typed AI proposals without allowing AI to mutate Canonical State automatically. Conflicts and supersession remain explicit and provider mechanics remain replaceable.

**FRs covered:** FR3, FR4, FR5, FR6, FR14, FR15, FR18.

**Implementation notes:** Builds the production provider registry and job coordinator; Ollama and LM Studio loopback setup; native MLX setup and resource readiness; Keychain-backed OpenRouter setup and routed-model selection; explicit provider/model selection; Context Preview; normalized jobs/events/errors; structured proposals; dependency-aware review; and cross-adapter contract/integration coverage. Detailed stories remain deferred until Epic 2 has been decomposed.

### Epic 4: Return and Resume with Confidence

After time away, Wouter can reconstruct the governing state locally, inspect what changed and why, receive an explained Next Action, continue through explicitly grounded AI work, and record whether ProjectOS enabled Meaningful Work within five minutes.

**FRs covered:** FR11, FR12, FR13.

**Implementation notes:** Includes Overview, Pile Cover, Relational Briefing, version-bound Recap/What's Up Next lifecycle, offline saved orientation, explicit use of the active adapter/model for generated continuation, Return Outcome Record, and the validation metrics needed for the continue/rethink/stop product decision.

### Epic 5: Retain Full Ownership and Recoverability

Wouter can export, verify, restore, remove, and permanently delete Project data without silent loss or misleading cleanup claims. Local deletion, OpenRouter credential removal, local runtime/model storage, ProjectOS-managed MLX data, and any declared provider-session cleanup remain distinct outcomes.

**FRs covered:** FR16, FR17.

**Implementation notes:** Includes atomic human-readable export, checksums and verification, new-copy restore with ID remapping, Artifact removal history, export-first deletion, explicit OpenRouter credential removal, truthful local runtime/model storage behavior, ProjectOS-managed MLX data removal, and crash-safe receipts only for adapters that declare persistent external sessions.

## Epic 1: Prove a Safe AI Path—or Stop

Wouter obtains reproducible evidence that Codex App Server can safely support ProjectOS through ChatGPT subscription access without compromising containment, cleanup, quality, or provider neutrality. The outcome is `proceed`, `proceed with constraints`, or `reject`; failure of any stop condition halts the Codex path before production implementation.

**Recorded outcome (2026-08-09): `reject`; Epic complete.** Stories 1.1–1.9 and their acceptance criteria are preserved as the historical contract. The approved replacement architecture authorizes Ollama, LM Studio, MLX, and OpenRouter production planning without reopening or bypassing this Codex result.

### Story 1.1: Establish the Isolated App Server Harness

As a ProjectOS builder,
I want a disposable provider-neutral harness that owns an isolated Codex App Server process,
So that all later viability tests run against a controlled and reproducible boundary.

**Acceptance Criteria:**

**Given** an installed Codex CLI discoverable through supported executable lookup
**When** the harness starts a validation run
**Then** it discovers the executable without reading a private ChatGPT application-bundle path
**And** records the resolved executable and exact Codex version as evidence.

**Given** the discovered runtime
**When** the harness starts `codex app-server`
**Then** it communicates over stdio JSON-RPC and completes `initialize` followed by `initialized`
**And** it terminates only the child process it owns.

**Given** the harness creates its runtime environment
**When** the Codex child starts
**Then** it receives a dedicated permission-restricted ProjectOS `CODEX_HOME`, a disposable working directory, and a scrubbed allowlisted environment
**And** the effective paths and non-secret configuration are recorded for verification.

**Given** a separately configured normal Codex profile exists
**When** the harness starts, initializes, and shuts down its child
**Then** the normal profile's configuration, authentication, sessions, and processes remain unchanged
**And** a before/after check records that isolation.

**Given** the thin `AiProviderPort` and Codex adapter boundary
**When** the harness performs runtime health and lifecycle operations
**Then** callers use ProjectOS-owned request, result, status, and lifecycle types
**And** Codex protocol types remain confined to the adapter.

**Given** runtime discovery, initialization, or owned shutdown fails
**When** the harness reports the result
**Then** it produces a sanitized, actionable failure with a ProjectOS correlation identifier
**And** no production provider action or Canonical State operation is enabled.

**Given** Story 1.1 scope
**When** its implementation is reviewed
**Then** it contains no production UI, Canonical State migration, App Store packaging, provider fallback, or local-model implementation
**And** its retained evidence can be reproduced on the same supported macOS environment.

### Story 1.2: Pin and Exercise the Runtime Protocol Contract

As a ProjectOS builder,
I want App Server compatibility pinned to reproducible protocol evidence,
So that an installed Codex change cannot silently alter ProjectOS behavior.

**Acceptance Criteria:**

**Given** the isolated harness and discovered Codex binary from Story 1.1
**When** the protocol-validation command runs
**Then** it generates the supported protocol schemas from that exact binary and calculates stable schema digests
**And** retains the version, digests, and generation command as evidence.

**Given** the generated protocol schemas
**When** the Codex adapter defines its supported contract
**Then** it enumerates only the documented RPC methods required by the spike
**And** starts App Server with `experimentalApi: false`.

**Given** a runtime whose exact build, schema digest, or required method set differs from the supported manifest
**When** compatibility is evaluated
**Then** startup fails closed before any provider action
**And** the failure identifies the detected build and the supported remediation without exposing local paths or sensitive data.

**Given** the exact supported runtime and matching protocol manifest
**When** compatibility is evaluated
**Then** only the enumerated RPC subset becomes available to the harness
**And** unrecognized or non-enumerated methods remain unavailable.

**Given** fixtures for startup crash, malformed JSON, unexpected EOF, response timeout, and child termination
**When** each fixture is replayed
**Then** the supervisor reaches a deterministic normalized failure state and retains a sanitized diagnostic reference
**And** it neither hangs indefinitely nor reports the runtime as ready.

**Given** a failed or terminated child process
**When** an explicit restart is requested
**Then** the harness starts a newly owned process, repeats compatibility and initialization checks, and does not reuse an uncertain transport state
**And** only the new owned child can become ready.

**Given** two concurrent harness instances
**When** both request App Server startup
**Then** they either coordinate exclusive ownership of one ProjectOS profile or use fully isolated instance profiles
**And** tests prove there is no crossing of processes, configuration, accounts, or session identifiers.

**Given** protocol evidence or a failure fixture contains JSON-RPC data
**When** evidence is persisted
**Then** tokens, account identifiers, Project content, prompts/results, and local paths are removed
**And** the retained record remains sufficient to reproduce the compatibility result.

### Story 1.3: Prove Subscription Authentication Without Credential Ownership

As a ProjectOS builder,
I want Codex to establish and own ChatGPT subscription authentication,
So that ProjectOS can use an eligible plan without handling tokens, API keys, or usage-based credits.

**Acceptance Criteria:**

**Given** the supported isolated runtime is signed out
**When** the harness reads account state
**Then** it reports a normalized signed-out state without requesting an API key
**And** no provider credential appears in ProjectOS-owned state.

**Given** a signed-out supported runtime
**When** the harness invokes managed `account/login/start` with `type: chatgpt`
**Then** it receives and opens the Codex-provided browser-login URL and observes account notifications until completion
**And** ProjectOS never receives the resulting access or refresh token.

**Given** successful login with the validation account
**When** account state is refreshed
**Then** the harness records ChatGPT authentication and the plan type exposed by Codex, including confirmation of the expected personal Pro validation account
**And** persisted evidence removes account identifiers.

**Given** login is cancelled, expires, or fails
**When** Codex reports the outcome
**Then** the harness returns a distinct normalized state with an actionable retry path
**And** the interrupted validation action can be resumed without recreating unrelated state.

**Given** the supported runtime exposes device-code login
**When** optional recovery capability is evaluated
**Then** the harness exercises and records it without exposing credentials
**And** absence of that capability is recorded as unsupported without failing browser-login validation.

**Given** the ProjectOS-scoped Codex configuration
**When** login state is persisted by Codex
**Then** configuration forces ChatGPT login and macOS keyring credential storage
**And** no plaintext `auth.json` fallback, OpenAI API key, or ProjectOS-owned token record exists.

**Given** secure credential storage is unavailable
**When** login is attempted
**Then** authentication fails closed with a sanitized actionable result
**And** no plaintext credential fallback is created.

**Given** an authenticated validation session
**When** logout is requested
**Then** Codex ends authentication for the ProjectOS profile only and reports signed-out state
**And** the independently configured normal Codex profile remains unchanged.

**Given** logs, fixtures, environment snapshots, and sanitized JSON-RPC transcripts from the authentication run
**When** the credential-leak audit runs
**Then** it finds no access token, refresh token, API key, authorization header, account identifier, or plaintext credential file
**And** the audit result is retained as spike evidence.

**Given** subscription authentication cannot be established without ProjectOS handling tokens, API keys, or API credits
**When** Story 1.3 concludes
**Then** the Codex adapter path is marked `reject` and later production stories are blocked
**And** the failure evidence records which stop condition was triggered.

### Story 1.4: Normalize Allowance, Failures, and Terminal Job Outcomes

As a ProjectOS builder,
I want provider usage, failures, events, and cancellation reduced to deterministic ProjectOS-owned states,
So that future product surfaces never depend on Codex strings or ambiguous event timing.

**Acceptance Criteria:**

**Given** an authenticated runtime exposes rate-limit information
**When** the harness reads allowance state
**Then** it normalizes every returned bucket, used percentage, window duration, reset timestamp, and reached-limit classification
**And** retains the provider-reported window rather than hard-coding a weekly schedule.

**Given** rate limiting, exhausted allowance, network loss, upstream failure, authentication expiry, runtime failure, and successful retry fixtures
**When** each fixture is executed
**Then** the adapter returns the corresponding normalized category only when explicit provider signals support it
**And** unsupported distinctions remain `providerFailed` or `unknown` rather than being inferred from message text.

**Given** plan allowance is exhausted
**When** capability and readiness are evaluated
**Then** provider work becomes temporarily unavailable with the reported reset information and remedy
**And** the normalized state continues to declare local ProjectOS behavior as available.

**Given** a provider job emits events
**When** the adapter normalizes them
**Then** every event carries a durable ProjectOS job ID, provider-instance ID, and deterministic ordering information
**And** the event model contains no Codex-specific type outside the adapter.

**Given** duplicate, delayed, reordered, cross-job, and post-terminal event traces
**When** the shared reducer replays each trace
**Then** it produces exactly one deterministic terminal outcome for the intended job
**And** late or unrelated events cannot alter that outcome.

**Given** cancellation is requested while generation is active
**When** cancellation acknowledgement, normal completion, provider failure, timeout, or child death races with that request
**Then** cancellation remains a request until acknowledged or superseded by a terminal result
**And** the reducer still yields exactly one deterministic terminal outcome.

**Given** timeout followed by retry or duplicate completion
**When** both attempts produce events
**Then** idempotency prevents more than one accepted terminal result for the durable job
**And** the trace records which attempt became authoritative.

**Given** a normalized error is persisted
**When** diagnostic serialization runs
**Then** it stores only allowlisted normalized codes, runtime version, timestamps, and ProjectOS correlation identifiers
**And** excludes credentials, account identifiers, Project content, prompts/results, raw provider payloads, and local paths.

**Given** any failure or allowance state
**When** user-remedy metadata is produced
**Then** it never offers API-credit purchase, automatic top-up, or silent API-key fallback
**And** its wording distinguishes authentication, runtime, network, rate, allowance, provider, and unknown states where evidence permits.

### Story 1.5: Validate Structured Output for Representative Project Work

As a ProjectOS builder,
I want Codex evaluated against representative non-coding ProjectOS jobs and the ProjectOS proposal schema,
So that adapter adoption depends on trustworthy project-state extraction rather than a plausible demonstration.

**Acceptance Criteria:**

**Given** the three required validation domains
**When** fixtures are prepared
**Then** they cover garden-office utility research with conflicting constraints, used-car variant comparison, and a technical project with a superseding Decision and dependency effects
**And** each fixture contains enough material to exercise Decisions, Research, Open Questions, Tasks, relationships, and provenance.

**Given** each representative fixture
**When** its expected-answer record is finalized before provider execution
**Then** material Facts, Decisions, Open Questions, Tasks, Research, relationships, and expected governing effects are annotated
**And** a minimum evaluated-item denominator is declared before results are observed.

**Given** an annotated fixture is ready
**When** the harness initiates the provider job
**Then** it supplies only the explicit Context Preview payload and requests the ProjectOS Change Proposal schema through per-turn structured output
**And** no unrelated Project or filesystem context is included.

**Given** Codex returns a completed structured result
**When** the adapter processes it
**Then** it parses the provider response, validates it again against the ProjectOS-owned schema, and returns a normalized result
**And** only the harness coordinator may record it as a pending validation proposal.

**Given** a completed fixture result
**When** quality scoring runs
**Then** it records precision and recall separately for each artifact type, unsupported claims, provenance quality, governing-state omissions, and user correction effort
**And** retains the scored expected-versus-actual evidence without exposing unsanitized Project content outside the controlled evidence set.

**Given** streaming, cancellation, partial output, malformed output, and retry variants
**When** each is exercised
**Then** partial or malformed content never becomes a pending Change Proposal
**And** retries remain idempotent and cannot create duplicate proposals.

**Given** all required fixture results meet the predeclared denominator
**When** the quality gate is evaluated
**Then** correctness is at least 85 percent
**And** no omission changes governing current state, dependency effects, or re-entry meaning.

**Given** the correctness, completeness, denominator, or malformed-output gate fails
**When** Story 1.5 concludes
**Then** the Codex adapter path is marked `reject` and later production stories are blocked
**And** the evidence identifies the failed metric and the non-coding-job stop condition.

### Story 1.6: Prove Preventive Execution Containment

As a ProjectOS builder,
I want every Codex validation job confined before any unintended action can occur,
So that selected Project content cannot turn the provider adapter into an uncontrolled coding agent.

**Acceptance Criteria:**

**Given** a ProjectOS validation job
**When** its Codex thread and turn are created
**Then** readable roots contain only the disposable working directory and explicitly recorded runtime-required platform roots, with no Project, home, or unrelated root readable and no writable roots
**And** the job uses `approvalPolicy: never` and `experimentalApi: false`.

**Given** the isolated runtime profile
**When** a job starts
**Then** no dynamic tools, MCP servers, connectors, apps, plugins, skills, or user instructions are registered or inherited
**And** returned `instructionSources` match an explicit allowlist.

**Given** a clean allowed-root file and canaries outside the allowed roots
**When** containment probes execute
**Then** the allowed-root read succeeds and every outside-root read, write, traversal, or symlink escape is prevented before data access or mutation
**And** filesystem evidence proves the canaries and unrelated files remain untouched.

**Given** non-empty user-level Codex configuration containing instructions or tool configuration
**When** the ProjectOS-scoped job runs
**Then** the configuration cannot affect the job, its instruction sources, or its capabilities
**And** the independently configured normal profile remains unchanged.

**Given** prompt-injection, symlink/path-traversal, inherited MCP/tool configuration, environment-secret canary, filesystem-read, filesystem-write, web-search, command-attempt, connector, and permission-request fixtures
**When** each hostile input is processed
**Then** ProjectOS generation either completes safely or fails closed without unrelated read, transmission, mutation, command, file-change, web-search, connector, tool, or permission activity
**And** no fixture can broaden the explicitly supplied Context Preview.

**Given** App Server still exposes built-in command, filesystem, or web capabilities despite its internal sandbox controls
**When** the containment design is evaluated
**Then** a documented stable disable mechanism or an external OS containment boundary prevents every unintended action before it occurs
**And** detection or cleanup after access or side effects does not count as a pass.

**Given** ordinary and hostile-input generation runs complete
**When** before/after filesystem, process, environment-canary, network/tool-event, and sanitized transcript evidence is compared
**Then** it proves zero unrelated access, transmission, mutation, command, file-change, web-search, connector, or permission effects
**And** retains the effective sandbox configuration and instruction-source evidence.

**Given** any fixture produces unintended access, transmission, mutation, command, file-change, web-search, connector, tool, or permission activity, or prevention cannot be demonstrated
**When** Story 1.6 concludes
**Then** the Codex adapter path is marked `reject` and later production stories are blocked
**And** the evidence records the containment stop condition without treating detection alone as mitigation.

### Story 1.7: Prove Portable Conversation Ownership and Restore Separation

As a ProjectOS builder,
I want ProjectOS Conversations to remain canonical while provider sessions stay replaceable and non-portable,
So that restart, export, restore, and future provider changes cannot transfer ownership of project history to Codex.

**Acceptance Criteria:**

**Given** a new validation Conversation
**When** provider work first creates a Codex thread
**Then** ProjectOS assigns the canonical Conversation identifier and stores the Codex thread identifier only as an adapter-keyed Provider Session Binding
**And** the binding cannot become the Conversation's canonical identity.

**Given** an established Conversation and binding
**When** the owned App Server process restarts
**Then** the adapter can resume the bound provider session while ProjectOS remains the canonical transcript owner
**And** missing or stale provider state cannot delete or rewrite the local Conversation.

**Given** a Project export containing a bound Conversation
**When** export serialization and leak checks run
**Then** the package excludes Provider Session Bindings, provider session identifiers, credentials, authentication state, runtime caches, and unsanitized diagnostics
**And** includes the canonical local Conversation and its accepted provenance relationships.

**Given** an exported Project
**When** it is restored offline
**Then** restore performs zero provider calls and creates a new local Project copy
**And** restored Conversations have no provider binding until the user later initiates new AI work.

**Given** AI work is explicitly initiated from a restored Conversation
**When** its fresh Context Preview is approved
**Then** the adapter creates a new provider-session binding rather than reattaching the exported session
**And** the restored canonical Conversation identity remains ProjectOS-owned.

**Given** restore is performed twice, beside the source Project, or with colliding Project-owned identifiers
**When** each restore commits
**Then** every restore creates a distinct Project copy and atomically remaps all Project-owned IDs through one restore map
**And** relationships, versions, Source links, and Provenance remain internally coherent.

**Given** an export contains recognized import-provenance IDs, unknown adapter metadata, or an older supported schema
**When** restore preflight and migration run
**Then** original IDs remain import-provenance metadata only, provider metadata cannot trigger provider work, and supported migration is atomic
**And** unsupported or corrupt input fails without partially creating a Project.

**Given** the source and restored Projects
**When** equivalence verification runs
**Then** Canonical State, accepted history, relationships, Rationale, Provenance, and local Conversation content are equivalent after ID remapping
**And** provider bindings and provider-owned state are correctly absent from the restored copy.

### Story 1.8: Prove Crash-Safe Provider Session Cleanup

As a ProjectOS builder,
I want every provider session tracked and deleted through a crash-safe lifecycle obligation,
So that local ownership is not contradicted by forgotten Codex threads or false cleanup claims.

**Acceptance Criteria:**

**Given** a provider job is about to create a Codex thread
**When** session creation begins
**Then** a durable cleanup obligation is recorded before the provider-side creation effect
**And** a crash between intent and binding can be reconciled without forgetting the possible session.

**Given** an active or retired Provider Session Binding
**When** lifecycle state is persisted
**Then** the content-free cleanup record contains only adapter ID, ProjectOS provider-profile ID, non-secret authentication-context fingerprint, opaque provider-session ID, lifecycle state, retry count, and timestamps
**And** contains no Project title, content, prompt, result, transcript, Source, or credential.

**Given** lifecycle transitions through create intent, bound, retired, delete pending, reauthentication required, confirmed, or absent
**When** the process crashes before or after each external and local side effect
**Then** startup reconciliation resumes idempotently from the durable state
**And** no known cleanup target is forgotten or falsely marked complete.

**Given** one Conversation binding or a Project with multiple bindings
**When** provider cleanup is requested
**Then** the adapter uses the documented provider deletion operation for every managed session
**And** verifies associated persisted Codex rollout files and metadata are removed or records cleanup as incomplete.

**Given** local Project deletion proceeds while provider cleanup is unavailable or fails
**When** the local transaction commits
**Then** Project content and ordinary bindings are removed while the minimal cleanup receipt remains
**And** `Project deleted` and `provider cleanup complete` are reported as separate truthful outcomes.

**Given** cleanup is pending after local Project content is gone
**When** retry occurs while offline, after adapter removal or rename, after account switching, after process restart, or when the session is already absent
**Then** the obligation remains recoverable and idempotent, with `absent` treated as a truthful successful terminal result
**And** no retry requires restoring or resending Project content.

**Given** logout or account switching is requested with active or cleanup-pending sessions
**When** the authentication context changes
**Then** cleanup is attempted first for the matching context
**And** incomplete obligations transition to reauthentication required with residual-data disclosure and a later matching-context retry path.

**Given** provider deletion succeeds, reports already absent, or fails
**When** the cleanup state is recorded
**Then** confirmed or absent receipts retain a minimal audit outcome and failed receipts retain actionable retry state
**And** ProjectOS does not claim to delete independent provider retention, backups, or user-created exports.

**Given** cleanup fixtures and filesystem evidence
**When** the lifecycle audit runs
**Then** every created session is accounted for through confirmed, absent, or an explicit pending obligation
**And** the evidence shows cleanup never initiated generation or transmitted new Project content.

**Given** persisted provider sessions cannot be enumerated and deleted consistently or a known session can be forgotten across a crash
**When** Story 1.8 concludes
**Then** the Codex adapter path is marked `reject` and later production stories are blocked
**And** the provider-session cleanup stop condition is recorded in the spike evidence.

### Story 1.9: Prove Provider Neutrality and Record the Gate Decision

As a ProjectOS builder,
I want the same ProjectOS provider contract proven against structurally different adapters and all spike evidence audited,
So that I can make a binding evidence-based decision to proceed, constrain, or reject the Codex path.

**Acceptance Criteria:**

**Given** the ProjectOS `AiProviderPort` and `ProviderRegistry`
**When** an adapter reports capabilities
**Then** every claim is scoped to the active adapter instance, runtime version, account, and selected model or configuration and is one of `supported`, `unsupported`, `temporarily unavailable`, or `unknown`
**And** mandatory capabilities and explicit user-visible degradations are resolved again at dispatch.

**Given** a Codex adapter, a Codex-shaped deterministic fake, and a local-shaped deterministic fake with no authentication, usage reporting, persistent sessions, or provider deletion and configurable absence of streaming or structured output
**When** the reusable contract suite runs
**Then** all applicable adapters exercise health/capabilities, generation, streaming, cancellation, structured results, unsupported usage reporting, authentication/runtime states, session lifecycle, and cleanup failure
**And** unsupported capabilities produce declared degradations without silently changing locality, billing, privacy, or output guarantees.

**Given** the active registry entry is replaced by either fake adapter
**When** the same contract-level workflows run
**Then** Conversation, Change Proposal, Re-entry, export, and deletion workflow code requires no change
**And** provider session details remain replaceable adapter-owned bindings.

**Given** adapter capabilities change after registry load
**When** a new job is dispatched
**Then** capability resolution uses the current claims rather than cached assumptions
**And** a now-unsupported mandatory capability blocks dispatch with an explicit degradation.

**Given** duplicate completion, timeout/retry, concurrent turns, stale Canonical-State revisions, and cancellation/completion race fixtures
**When** the shared contract suite replays them
**Then** each durable job creates at most one pending proposal and never mutates Canonical State
**And** stale output cannot persist against a newer Project revision.

**Given** adapter and domain dependencies
**When** static dependency checks and test doubles are inspected
**Then** ProjectOS domain and persistence modules import no Codex protocol types
**And** adapters cannot invoke Canonical State, Conversation, Change Proposal, export, or deletion repositories.

**Given** evidence from Stories 1.1 through 1.8
**When** the spike evidence audit runs
**Then** it includes the exact Codex version and generated schemas, schema digests, sanitized JSON-RPC transcripts, contract-test output and failure fixtures, quality score sheets, filesystem before/after evidence, and every triggered or passed gate
**And** all retained evidence passes the credential, account-identifier, Project-content, prompt/result, and local-path sanitation rules.

**Given** any stop condition from authentication, non-coding quality/completeness, preventive containment, provider-session deletion, or provider neutrality has failed
**When** the final recommendation is produced
**Then** it records `reject`, identifies the failed evidence, and blocks production Codex-adapter work
**And** later local ProjectOS work may proceed only through an explicitly revised architecture decision rather than silently bypassing the gate.

**Given** every mandatory gate passes but material operating constraints remain
**When** the final recommendation is produced
**Then** it records `proceed with constraints` and names each enforceable constraint and required follow-up
**And** no constraint weakens privacy, containment, cleanup truthfulness, Canonical State ownership, or provider neutrality.

**Given** every mandatory gate passes without an unresolved blocking constraint
**When** the final recommendation is produced
**Then** it records `proceed` and authorizes Epic 2 implementation
**And** installed-versus-bundled runtime distribution, supported versions, and local-model timing remain deferred to explicit post-spike architecture decisions.
