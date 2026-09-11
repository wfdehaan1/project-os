---
id: SPEC-projectos
title: ProjectOS personal-use macOS MVP
status: done
created: 2026-09-10
baseline_commit: 37bf2083b4d1d9b1f4b98e6445caf2767c1ec481
companions:
  - scope-and-sources.md
  - implementation.md
  - acceptance.md
sources: []
---

# ProjectOS personal-use macOS MVP

This spec and its three companions are the implementation handoff. Read all four before writing code. This contract is derived from the spec workspace's decision log and the scoped source material identified in `scope-and-sources.md`. No application implementation was performed while creating it.

## Why

Wouter has experienced losing decisions and rationale across AI conversations. He needs a usable application to discover whether ProjectOS makes real projects easier to continue. Build one complete native Mac experience: create a project, work through integrated conversation, review useful updates, leave, and return to trustworthy current context. The goal is personal use on one or two real projects, without waiting for Apple PCC, commercial distribution, or more stand-alone model experiments.

## Capabilities

- **CAP-1**
  - **intent:** Create and reopen locally owned projects with labelled source material.
  - **success:** Projects, descriptions, and exact pasted text survive relaunch; creation and browsing work without AI setup or a network connection.
- **CAP-2**
  - **intent:** Explicitly configure and choose local Ollama or external OpenRouter inference.
  - **success:** Both adapters complete the live workflow when their prerequisites are supplied; settings distinguish connectivity from tested model capability and quality, and disclose locality, model, and external billing.
- **CAP-3**
  - **intent:** Converse inside a project using inspectable project context.
  - **success:** A user can inspect and narrow context, send, read a streaming response, stop it, and resume later without losing drafts, transcript, or project identity.
- **CAP-4**
  - **intent:** Obtain proposed project updates from selected conversations and source material.
  - **success:** Explicit generation produces reviewable Topics, Research, Decisions, Open Questions, and Tasks; malformed output or invalid evidence cannot enter the proposal inbox or accepted state.
- **CAP-5**
  - **intent:** Control current project knowledge while retaining why it changed.
  - **success:** Accept, edit-and-accept, reject, direct correction, decision supersession, typed linking, artifact removal, and latest-change undo preserve coherent state, provenance, and inspectable history.
- **CAP-6**
  - **intent:** Return to current decisions and open work without rereading conversations.
  - **success:** Offline Overview shows governing decisions, open questions/tasks, recent research and changes; an optional generated next action identifies its accepted supporting records and becomes visibly stale after relevant state changes.
- **CAP-7**
  - **intent:** Recover and deliberately remove locally owned project data.
  - **success:** A human-readable export restores as a separate copy with equivalent state, relationships, evidence and history; confirmed deletion removes app-managed project content without claiming external-provider deletion.
- **CAP-8**
  - **intent:** Try the complete application on real projects and record whether it helps.
  - **success:** The handoff includes a launchable Mac app, repeatable build instructions, separate automated/live verification results, and a local return-outcome form capturing time, understanding, trust, usefulness and review effort.

## Constraints

- Native macOS, single owner, local persistent data; no ProjectOS account, hosted project service, inference proxy, or credit system.
- Conversation happens inside ProjectOS. Pasting research is supported; routine transfer to and from another chatbot is not the core workflow.
- Ollama and OpenRouter are the two required adapters for this slice. The adapter boundary and saved project format must permit a later provider without rewriting domain workflows.
- AI only generates text and proposed data. Only application commands apply accepted mutations. No provider tools, shell access, autonomous browsing, connectors, or domain-store access.
- Current accepted knowledge, pending AI suggestions, and superseded history remain distinct. Model output is not automatically project truth.
- Each inference action uses a frozen, visible context/provider/model selection. No silent truncation, retry, model/provider fallback, hidden inference, or automatic paid extraction after chat.
- Ollama means verified on-Mac inference, not merely a loopback address that could proxy to the cloud. OpenRouter secrets live only in Keychain; project data and exports contain no credentials.
- Commit accepted changes atomically; preserve exact evidence, revisions, and decision lineage; reject stale and duplicate writes and cancelled/deleted-project completions.
- Saving, browsing, editing, proposal review, export, restore and deletion work without inference. Failure must preserve the last coherent local state.
- The implementation and acceptance companions define paths, contracts, delivery order and proof obligations. Existing larger plans are scoped references, not additional prerequisites for this slice.

## Non-goals

- Apple PCC/Foundation Models integration, entitlements, LM Studio, native MLX, additional APIs, subscription authentication, or MCP companion integration.
- iOS, synchronization, CloudKit, browser/share extensions, listing capture, fuzzy matching, automatic criteria screening, or domain-specific candidate artifacts.
- App Store submission, payments, licensing, customer onboarding, marketing, or proving commercial demand.
- File/PDF/OCR import, provider account imports, embeddings/vector search, automatic context summarization, project-map canvas, theme editor, full notification center, or full localization.
- Completing all existing epics or qualifying the entire four-adapter provider plan.

## Success signal

With real inference, Wouter imports material, converses, accepts decisions and open work, changes a decision without erasing its rationale, then returns after seven days and resumes meaningful work from Overview. Record whether re-entry takes at most five minutes and requires less reconstruction than his previous workflow. Engineering completion supplies the working loop; usefulness remains an observation from actual use, not a claim an agent can make on Wouter's behalf.

## Assumptions

- A1: Ollama is the first local runtime, following the immediately preceding MVP proposal; other local runtimes are later work.
- A2: SwiftUI with selective AppKit, Swift 6.2, macOS 26, and transactional SQLite are implementation defaults for this native slice. They do not require Apple AI access.
- A3: English interface copy is sufficient initially; English and Dutch project content and Unicode evidence must work correctly.
- A4: Separate Send from Suggest project updates initially; use inline context disclosure and no automatic extraction call. Assess this interaction's review friction during personal use.

## Open Questions

- Q1: Before live qualification, Wouter supplies/selects the installed local runtime/model and intended Mac, and chooses the OpenRouter model/routing target, credential and test spending ceiling. These are runtime inputs, not reasons to delay implementing the interfaces or deterministic tests.
- Q2: Before judging the first real return, Wouter defines what review/correction burden feels excessive. Until then, record effort and comments without inventing a pass threshold.

## Suggested Review Order

**Composition and workflow**

- Start here for project ownership, frozen context, jobs, and user-authorized mutations.
  [`AppEnvironment.swift:6`](../../../apps/ProjectOS/ProjectOS/App/AppEnvironment.swift#L6)

- The native scene, settings window, visit completion, and app-level commands compose the shell.
  [`ProjectOSApp.swift:4`](../../../apps/ProjectOS/ProjectOS/App/ProjectOSApp.swift#L4)

**Domain and integrity**

- Provider-neutral records define durable knowledge, proposal, context, history, and recommendation semantics.
  [`Models.swift:1`](../../../apps/ProjectOS/Packages/ProjectOSCore/Sources/ProjectOSCore/Domain/Models.swift#L1)

- Context freezing preserves exact selected versions and fails closed on unknown or exceeded bounds.
  [`ContextBuilder.swift:54`](../../../apps/ProjectOS/Packages/ProjectOSCore/Sources/ProjectOSCore/Context/ContextBuilder.swift#L54)

- Strict schema and semantic validation stop malformed, stale, unsupported, or ungrounded proposals.
  [`ProposalValidator.swift:93`](../../../apps/ProjectOS/Packages/ProjectOSCore/Sources/ProjectOSCore/Proposals/ProposalValidator.swift#L93)

- Accepted changes enforce dependency closure, supersession, idempotency, removal integrity, and compensating undo.
  [`ChangesEngine.swift:72`](../../../apps/ProjectOS/Packages/ProjectOSCore/Sources/ProjectOSCore/Changes/ChangesEngine.swift#L72)

**Persistence and ownership**

- The production SQLite path mirrors domain invariants through serialized atomic transactions.
  [`ProjectStore.swift:237`](../../../apps/ProjectOS/ProjectOS/Persistence/ProjectStore.swift#L237)

- Explicit migrations preserve databases created by earlier development builds.
  [`Migrations.swift:4`](../../../apps/ProjectOS/ProjectOS/Persistence/Migrations.swift#L4)

- Export snapshots are serialized, complete, human-readable, checksummed, and identity-remapped on restore.
  [`ProjectStore+Archive.swift:3`](../../../apps/ProjectOS/ProjectOS/Persistence/ProjectStore+Archive.swift#L3)

- Archive validation and deletion fencing preserve coherent state across recovery and removal.
  [`ProjectArchive.swift:227`](../../../apps/ProjectOS/ProjectOS/Ownership/ProjectArchive.swift#L227)

**Inference boundaries**

- One facade constructs disclosed requests and preserves validated structured results plus returned telemetry.
  [`InferenceService.swift:90`](../../../apps/ProjectOS/ProjectOS/AI/InferenceService.swift#L90)

- Ollama stays loopback-only with NDJSON streaming and no runtime management or fallback.
  [`OllamaAdapter.swift:68`](../../../apps/ProjectOS/ProjectOS/AI/OllamaAdapter.swift#L68)

- OpenRouter pins routing, caps price, redacts secrets, and audits returned route and usage.
  [`OpenRouterAdapter.swift:61`](../../../apps/ProjectOS/ProjectOS/AI/OpenRouterAdapter.swift#L61)

**Native experience**

- Conversation threads, per-thread drafts, context selection, streaming, evidence, and review share one workspace.
  [`ConversationView.swift:3`](../../../apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift#L3)

- Accepted knowledge exposes correction, state, evidence, relations, removal, and history without inference.
  [`KnowledgeView.swift:3`](../../../apps/ProjectOS/ProjectOS/Features/Knowledge/KnowledgeView.swift#L3)

- Overview reconstructs governing state, return changes, and revision-bound next-action guidance offline.
  [`OverviewView.swift:3`](../../../apps/ProjectOS/ProjectOS/Features/Overview/OverviewView.swift#L3)

**Proof and handoff**

- Core tests exercise context, validation, dependencies, supersession, removal, staleness, and undo.
  [`ProjectOSCoreTests.swift:6`](../../../apps/ProjectOS/Packages/ProjectOSCore/Tests/ProjectOSCoreTests/ProjectOSCoreTests.swift#L6)

- App tests cover persistence, migrations, archives, conversations, failure atomicity, and provider contracts.
  [`ProjectStoreTests.swift:5`](../../../apps/ProjectOS/ProjectOSTests/ProjectStoreTests.swift#L5)

- Verification results separate deterministic, native launch, live-provider, performance, and usefulness evidence.
  [`implementation-report.md:1`](../../../apps/ProjectOS/docs/implementation-report.md#L1)
