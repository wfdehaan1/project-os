---
title: ProjectOS Product Requirements Document
status: final
created: 2026-07-28
updated: 2026-08-12
---

# PRD: ProjectOS Validation Build

*ProjectOS is a working title.*

## 0. Document Purpose

**Purpose:** Test whether governed semantic project continuity makes returning to consequential, AI-assisted projects materially easier before committing to a commercial MVP.

**Audience:** The builder and downstream UX, architecture, epic, and implementation workflows. Functional requirements use stable, globally numbered IDs; remaining inferences are tagged `[ASSUMPTION]` and indexed in §10.

**Authority:** The current product brief and its addendum govern product definition; the approved 2026-08-09 Sprint Change Proposal governs the provider course correction; current architecture and epics govern implementation invariants and allocation; and market research is supporting evidence. `docs/ProjectWorkspace.md` is superseded and excluded.

## 1. Vision and Validation Thesis

ProjectOS is a local-first macOS workspace for people who use AI while pursuing complex, long-lived personal projects. AI chat is an effective working medium, but a weak authority for a project: research, governing decisions, rationale, unresolved questions, and tasks become fragmented across sessions and tools. Delegated AI research makes the gap sharper because findings and reasoning the user did not personally produce may remain trapped in a prior session rather than becoming durable project memory. After time away, the person must reread or reconstruct what is true before meaningful work can resume.

ProjectOS keeps conversation natural while turning consequential AI output into explicit, inspectable project state. AI may propose changes, but only accepted changes become canonical. The system distinguishes governing from superseded decisions, preserves rationale and provenance, and recommends a next action that can be explained from accepted state.

The validation thesis is narrow: after a meaningful absence, a person using ProjectOS can regain trustworthy context and resume meaningful real-world work faster and with less reconstruction than when relying on chat history, notes, and memory. Local storage, BYO AI, project containers, and generic “memory” are not sufficient differentiators; the test is governed semantic continuity.

### 1.1 Validation Commitment Boundary

The experiment starts only after the provider-free local foundation, minimum re-entry and outcome-recording surfaces, and one explicitly selected local Qualified Adapter Combination can complete the governed Conversation-to-proposal loop. That start qualifies only the recorded combination; all four approved adapter targets still require applicable readiness evidence before provider-scope completion. If a qualified local path disproves the continuity thesis, adapter breadth must not postpone the negative decision. §7.1 defines the complete cut line.

## 2. Target User and Jobs

### 2.1 Primary User

The validation build is for Wouter as the primary tester: an AI-experienced, self-directed macOS user managing one or two consequential projects over multiple weeks. The product remains cross-domain; the validation projects may be personal, commercial, creative, or technical.

### 2.2 Jobs To Be Done

- When working through a project with AI, preserve accepted decisions, rationale, research, unresolved questions, and tasks without maintaining a separate project-management system.
- When returning after time away, quickly understand the governing state, what changed, what remains unresolved, and why.
- When AI extracts or infers project state, remain in control of what becomes canonical.
- When a decision changes, preserve the superseded state and its rationale without confusing it with the current decision.
- When deciding what to do next, receive a useful recommendation grounded in accepted state rather than generic continuation of a chat.
- Keep canonical project data owned locally and portable.

### 2.3 Non-Users for the Validation Build

- Teams requiring collaboration, roles, permissions, assignments, or synchronized shared state.
- People seeking autonomous execution without reviewing consequential state changes.
- People requiring web, mobile, or multi-device access.
- People whose validation Mac cannot run any Qualified Adapter Combination locally and who do not choose to configure a qualified OpenRouter combination.

### 2.4 Key User Journeys

- **UJ-1. Wouter starts a consequential project and establishes trusted state.** Wouter creates a local Project and begins a Conversation or supplies selected existing Source Material. ProjectOS proposes typed Project State changes. Wouter accepts, edits, or rejects each Change Proposal. The accepted version becomes Canonical State, and Wouter can see its Rationale and Provenance.
- **UJ-2. Wouter changes a decision without losing why it changed.** During later work, evidence invalidates a Governing Decision. ProjectOS proposes a replacement and identifies the contradiction. Wouter reviews it, accepts the new Governing Decision, and can still inspect the Superseded Decision, its Rationale, and the Source Material behind both.
- **UJ-3. Wouter resumes after a meaningful absence.** After at least seven days away, Wouter opens the Project and sees a Re-entry View of Governing Decisions, recent Research, Open Questions, Tasks, and changes since the last session. He inspects supporting evidence where needed and follows or dismisses an explained Next Action. The journey succeeds when Meaningful Work resumes within five minutes.
- **UJ-4. Wouter verifies ownership and recoverability.** Wouter exports the Project, verifies that the export is human-inspectable, and reopens or restores it without losing Canonical State, version history, or Provenance.

## 3. Glossary

- **Project** — A locally stored body of work with one owner, its Project State, Conversations, and Source Material.
- **Project State** — The structured set of Artifacts belonging to a Project.
- **Artifact** — A typed unit of Project State: Topic, Research, Decision, Open Question, or Task. Conversation is preserved context and Provenance but is not Canonical State.
- **Canonical State** — The current accepted and versioned Project State. Only user-approved changes enter Canonical State.
- **Conversation** — A sequence of messages between the user and an AI Provider within a Project.
- **Source Material** — User-selected text, notes, or documents supplied independently of an in-Project Conversation as evidence or context. Conversation is a separate Provenance source.
- **Change Proposal** — An AI-generated suggestion to create, update, relate, or supersede an Artifact. It is not Canonical State until accepted by the user.
- **Governing Decision** — The currently applicable accepted Decision for its subject.
- **Superseded Decision** — A previously accepted Decision that is no longer governing but remains inspectable.
- **Rationale** — The accepted explanation for an Artifact or state transition.
- **Provenance** — Inspectable links from an Artifact or Change Proposal to the Conversation or Source Material that supports it.
- **Re-entry View** — The current-state-first presentation used to resume a Project after an absence.
- **Next Action** — An optional recommendation grounded in Canonical State, with an inspectable explanation of how it would advance or intentionally close part of the Project.
- **AI Provider** — A cloud service or local runtime capable of supplying AI generation to ProjectOS.
- **AI Provider Adapter** — The replaceable implementation that translates the ProjectOS AI capability contract to one provider or runtime. Ollama, LM Studio, and MLX are committed first-class local MVP adapter targets; OpenRouter is the sole optional external MVP target. Support is declared only for a Qualified Adapter Combination, not for an adapter name alone.
- **Qualified Adapter Combination** — A specific adapter, runtime version where applicable, model and model format, macOS hardware class, and configuration with recorded evidence for required capabilities, resource readiness, output quality and schema validity, boundary disclosure, cancellation, and applicable failure behavior. Qualification applies only to that recorded combination and its known degradations.
- **Provider Capability** — A feature an adapter declares it can perform, such as structured output, streaming, persistent sessions, usage reporting, model selection, or local execution.
- **Provider Session Binding** — An optional replaceable link from a ProjectOS Conversation to provider-owned session state. It is never the canonical Conversation identity, and adapters that do not use persistent sessions do not create one.
- **Local Inference Runtime** — A runtime that performs model inference on the user's Mac. Ollama and LM Studio are loopback-only server runtimes in the validation build; MLX is a native on-device runtime.
- **OpenRouter Adapter** — The optional external adapter that sends explicitly selected context to OpenRouter using the user-selected routed model and a Keychain-backed API key.
- **First Useful State** — The first accepted Canonical State that correctly captures enough of the Project to support a real decision, question, task, or Next Action.
- **Qualifying Return** — Opening a Project after at least seven consecutive days without working in it.
- **Meaningful Work** — A real-world step that advances or intentionally closes part of the Project, rather than merely reorganizing ProjectOS content.

## 4. Features and Functional Requirements

### 4.1 Local Project Setup and Input

**Description:** The user can establish a Project without configuring a generic project-management schema. A Project may begin from a fresh Conversation or from a small, user-selected body of existing Source Material. Realizes UJ-1.

#### FR-1: Create and reopen a Project

The user can create, name, close, and reopen a Project whose data persists locally on the Mac.

**Consequences (testable):**

- Closing and reopening the application preserves the Project and its Canonical State.
- Project creation does not require an account with ProjectOS or a hosted ProjectOS service.

#### FR-2: Supply selected Source Material

The user can paste text as Source Material during initial setup or a later Conversation.

**Consequences (testable):**

- The user chooses which material enters the Project; ProjectOS does not scan unrelated local data.
- Pasted material retains a user-visible source label and enough source identity to support Provenance.
- Local-file selection and parsing are excluded from the first validation slice.
- Bulk provider-account import and automatic reconstruction of prior AI history are excluded.

### 4.2 Conversation and Controlled State Change

**Description:** Conversation remains the natural working medium. ProjectOS identifies consequential state changes and presents them as typed Change Proposals rather than silently mutating Canonical State. Realizes UJ-1 and UJ-2.

#### FR-3: Conduct a project-grounded Conversation

The user can conduct a Conversation with the AI Provider using user-selected Project context.

**Consequences (testable):**

- The user can inspect which Project context will be sent before initiating AI work.
- Conversation history remains available as context and Provenance.

#### FR-4: Generate typed Change Proposals

ProjectOS can propose creation or modification of Topics, Research, Decisions, Open Questions, and Tasks from Conversation or Source Material.

**Consequences (testable):**

- Each Change Proposal identifies its Artifact type, proposed content, and supporting Provenance.
- A Change Proposal remains distinct from Canonical State until reviewed.

#### FR-5: Review consequential changes

The user can accept, edit before accepting, or reject each Change Proposal.

**Consequences (testable):**

- Rejection leaves Canonical State unchanged.
- Editing records the user-approved content rather than the original AI text as Canonical State.
- The interface makes pending proposals visibly different from accepted Artifacts.

#### FR-6: Detect potential contradiction or supersession

When a Change Proposal conflicts with an accepted Decision, ProjectOS can identify the potential conflict and require the user to resolve whether the existing Decision remains Governing or becomes Superseded.

**Consequences (testable):**

- ProjectOS does not silently replace an accepted Decision.
- A replacement proposal explicitly identifies the accepted Decision it may supersede and the shared subject the user is resolving.
- Accepting a replacement leaves exactly one Governing Decision for the resolved subject while retaining the prior Decision as Superseded.

### 4.3 Governed Canonical State

**Description:** Canonical State is explicit, versioned, correctable, and inspectable. Current truth is presented first while history remains available as evidence. Realizes UJ-1, UJ-2, and UJ-4.

#### FR-7: Maintain typed Artifacts and relationships

The user can inspect and update Topics, Research, Decisions, Open Questions, and Tasks, including meaningful relationships among them.

**Consequences (testable):**

- Each Artifact has a stable identity independent of its current version.
- At minimum, a Decision can link to supporting Research, Open Questions, and Topics; a Task can link to the Decision, Open Question, or Topic it advances; and a replacement Decision can link to the Decision it supersedes.
- Relationship meaning remains explicit in the interface and export; an unlabeled generic link does not satisfy this requirement.

#### FR-8: Preserve Rationale and Provenance

ProjectOS preserves accepted Rationale and Provenance for consequential Artifacts and state transitions.

**Consequences (testable):**

- The user can navigate from an Artifact to supporting Conversation or Source Material.
- At minimum, accepting or superseding a Governing Decision preserves its Rationale and Provenance; other accepted Artifact changes preserve available Provenance.
- Missing or unavailable Provenance is disclosed rather than invented.

#### FR-9: Preserve versions and supersession history

ProjectOS records accepted changes to Artifacts and distinguishes Governing Decisions from Superseded Decisions.

**Consequences (testable):**

- The user can inspect a prior accepted version and the transition to the current version.
- Historical state cannot be mistaken for current Canonical State in the default presentation.

#### FR-10: Correct or undo an accepted change

The user can correct an Artifact or undo the most recent accepted state change without corrupting unrelated Project State.

**Consequences (testable):**

- Correction preserves an inspectable history of the prior accepted value.
- Undo restores a coherent prior state and can itself be reversed or reapplied through a new accepted change.

### 4.4 Re-entry and Guided Continuation

**Description:** ProjectOS optimizes for returning after an absence, not for maximizing time in the application. It presents accepted current state first, allows evidence to be expanded on demand, and recommends a Next Action only when it can explain the recommendation from Canonical State. Realizes UJ-3.

#### FR-11: Present a Re-entry View

The user can open a Re-entry View showing, at minimum, current Governing Decisions, current Open Questions and Tasks, Research accepted since the user's last visit, and accepted Canonical State changes since that visit.

**Consequences (testable):**

- Governing and Superseded Decisions are visually distinguishable.
- The minimum current-state and since-last-visit content remains available regardless of any additional ranking or condensation.
- The user can move from the summary to Rationale, Provenance, or version history without rereading the full Conversation.
- The view remains useful when no AI request can be made.

#### FR-12: Recommend an explained Next Action

ProjectOS can recommend a Next Action grounded in Canonical State and explain the accepted Artifacts and relationships supporting it.

**Consequences (testable):**

- The user can inspect why the Next Action was recommended.
- The explanation identifies which meaningful part of the Project the recommendation is expected to advance or intentionally close.
- The user can dismiss the recommendation without modifying Canonical State.
- When evidence is insufficient or contradictory, ProjectOS states that uncertainty rather than presenting a confident recommendation.

#### FR-13: Record return outcomes

The user can record whether a Qualifying Return produced clear understanding, trust in the state, a useful Next Action, and Meaningful Work within five minutes.

**Consequences (testable):**

- The record captures elapsed time and brief qualitative notes.
- The record distinguishes whether a shown Next Action led to that action, a different meaningful action, or no action.
- When the Project reaches an outcome, the user can record successful completion, intentional closure, abandonment, or an unresolved result without rewriting prior return records.
- Validation records remain local and can be exported.

### 4.5 Provider, Privacy, and Portability

**Description:** ProjectOS accesses AI through a provider-independent capability boundary. Local inference is the default category: Ollama, LM Studio, and MLX are first-class local adapters. OpenRouter is the only optional external adapter. ProjectOS makes the active runtime, model, and execution boundary explicit, minimizes transmitted context, and keeps Canonical State locally owned and recoverable. Realizes UJ-1 and UJ-4.

#### FR-14: Configure and validate the AI Provider

The user can configure and validate an Ollama, LM Studio, or MLX target for local inference, or explicitly configure the OpenRouter target as an external alternative. The user explicitly chooses the active adapter and model, and ProjectOS represents a combination as Ready only when that combination is qualified.

**Consequences (testable):**

- ProjectOS detects Ollama and LM Studio runtimes on supported loopback endpoints and validates the selected runtime, model availability, and required capabilities before generation.
- ProjectOS validates MLX model availability, compatibility, and resource readiness before generation.
- Ollama and LM Studio endpoints outside the local loopback boundary are rejected in the validation build rather than represented as local.
- The OpenRouter API key is stored in macOS Keychain. ProjectOS stores only non-secret configuration and a Keychain reference outside Project data; the key is excluded from logs, diagnostics, exports, and ProjectOS-created backups.
- The interface distinguishes missing or stopped local runtimes, unavailable or incompatible models, insufficient local resources, malformed output, OpenRouter configuration or credential failure, network failure, rate or quota limits, billing restrictions, and upstream service failure.
- Adapter capabilities are scoped to the active runtime and model. Unsupported structured output, streaming, cancellation, context, or resource requirements remain explicit.
- Adapter identity, discovery, installation, model presence, or a successful health request alone never marks a combination Ready or Supported.
- Each Ready state is bound to the recorded adapter, runtime version where applicable, model and format, macOS hardware class, configuration, required capabilities, context and resource bounds, known degradations, and current qualification evidence.
- A changed runtime version, model, model format, hardware class, configuration, or mandatory capability invalidates or re-evaluates readiness before dispatch; ProjectOS shows `Unknown`, `Unsupported`, or `Temporarily unavailable` when Ready is not justified.
- Qualification includes representative quality and omission evidence, ProjectOS-owned schema validation, boundary disclosure, cancellation, and applicable failure normalization; it is implementation acceptance evidence and not a new product-authorization spike.
- ProjectOS never silently switches among Ollama, LM Studio, MLX, OpenRouter, or models. Any switch is an explicit user action and does not automatically resend, retry, or reinterpret prior work.
- Completed provider output must pass the ProjectOS-owned Change Proposal schema before it can become a pending proposal.
- Local Project capabilities remain available when inference is unavailable. Configured local inference may remain available when the network is offline.

#### FR-15: Disclose external transmission

Before sending Project content through an AI Provider Adapter, ProjectOS identifies the provider and whether processing is local or external, shows or summarizes the selected transmission scope, and requires user initiation.

**Consequences (testable):**

- No Project content is transmitted merely by opening or browsing a Project.
- Local-only actions remain distinguishable from actions that invoke a local model runtime or contact an external provider.
- ProjectOS does not claim that local-first operation eliminates all privacy obligations.
- A local Context Preview names Ollama, LM Studio, or MLX plus the selected model and states that the selected Project context remains on the Mac for inference.
- An OpenRouter Context Preview names OpenRouter and the selected routed model, states that processing is external and usage-based charges may apply, and shows the selected transmission scope before initiation.
- Runtime installation or model acquisition is a separate explicit operation and never authorizes Project content transmission or generation.

#### FR-16: Export and recover a Project

The user can export a complete, human-inspectable representation of the Project and reopen or restore it without losing Canonical State, Rationale, Provenance, relationships, or version history.

**Consequences (testable):**

- Export excludes provider credentials, authentication tokens, runtime caches, and unsanitized provider logs.
- A validation check can compare restored Project State with the source Project.
- Export failure leaves the source Project unchanged.

### 4.6 Deliberate Deletion

**Description:** Local ownership includes an explicit way to remove ProjectOS-managed content without confusing deletion with supersession or ordinary editing. Supports the ownership and control established in UJ-4.

#### FR-17: Delete an Artifact or Project deliberately

The user can remove an Artifact from current Canonical State and can permanently delete an entire local Project through explicit user actions.

**Consequences (testable):**

- Removing an Artifact is an accepted state transition: it disappears from current Canonical State, while its prior version and the deletion transition remain inspectable until the Project itself is permanently deleted.
- Permanently deleting a Project requires confirmation that explains the effect and offers export first; completion removes the Project, its history, Source Material, Conversations, validation records, and any Provider Session Bindings managed for that Project.
- Project deletion does not uninstall Ollama or LM Studio, remove their shared models, remove independently retained runtime data, delete the OpenRouter account or Keychain credential, or claim to delete data retained independently by OpenRouter, a routed model provider, macOS backups, or user-created exports.
- ProjectOS-managed MLX Project caches are deleted with the Project; shared MLX models or caches require a separate, explicit storage-management action.
- Provider-side session cleanup is required only when an adapter declares and uses persistent provider sessions. Local deletion may complete truthfully while a declared external cleanup obligation remains visible and retryable.
- Provider-side session cleanup is a lifecycle operation and does not send new Project content for generation.

### 4.7 Provider Independence

**Description:** Ollama, LM Studio, MLX, and OpenRouter must share one provider boundary without making any runtime or routed model the shape of ProjectOS.

#### FR-18: Keep AI providers replaceable

ProjectOS can add an AI Provider Adapter without changing its Canonical State model or core Conversation, Change Proposal, Re-entry, export, and deletion workflows.

**Consequences (testable):**

- Deterministic fake providers can execute the provider contract in automated tests without importing Ollama, LM Studio, MLX, or OpenRouter types into ProjectOS domain modules.
- Passing the shared contract against a deterministic fake is necessary contract evidence but cannot qualify a production adapter/runtime/model combination.
- ProjectOS Conversations retain provider-neutral identities; provider session identifiers are stored as replaceable Provider Session Bindings.
- Adapters advertise capabilities, and the product disables or explains unsupported functions instead of assuming every provider supports structured output, persistent sessions, model selection, usage reporting, or local execution.
- Provider-specific account, runtime, model, and usage settings are contributed through the shared provider settings surface rather than hard-coded across product screens.
- Switching or removing an adapter never silently changes accepted Canonical State.

## 5. Cross-Cutting Non-Functional Requirements

### 5.1 Integrity and Recoverability

- **NFR-1:** ProjectOS must never silently discard or corrupt accepted Canonical State. Any detected persistence or migration failure must be explicit and must preserve the last known coherent state.
- **NFR-2:** Every accepted state transition must be atomic from the user's perspective: either the complete transition is visible or Canonical State remains unchanged.
- **NFR-3:** Project data must remain recoverable through a verified export without requiring a ProjectOS-hosted service.

### 5.2 Trust and Explainability

- **NFR-4:** AI-generated content must remain visibly distinguishable from user-accepted Canonical State throughout the application.
- **NFR-5:** ProjectOS must not fabricate Provenance, certainty, or the existence of accepted state.
- **NFR-6:** Model-quality limitations and failures must be described in plain language and must not silently degrade Canonical State.

### 5.3 Privacy and Security

- **NFR-7:** Canonical project content must remain stored on the user's Mac; the validation build has no ProjectOS-hosted project-content backend.
- **NFR-8:** Provider secrets must never enter Project data, logs, diagnostics, exports, or ProjectOS-created backups. The OpenRouter API key must be stored in macOS Keychain; ProjectOS may retain only non-secret provider configuration and a Keychain reference.
- **NFR-9:** Only user-selected context required for a requested provider operation may cross the configured provider boundary. Ollama and LM Studio validation-build endpoints must be loopback-only, MLX inference must remain on-device, and OpenRouter transmission must be explicit and externally disclosed.

### 5.4 Usability and Responsiveness

- **NFR-10:** Browsing locally stored Canonical State, Rationale, Provenance, and the Re-entry View must remain available without network access. On the supported validation Mac, with a Project containing up to 1,000 Artifacts, 5,000 explicit relationships, and 10,000 locally stored Conversation messages, opening an already indexed Re-entry View completes within 2 seconds and opening an Artifact, its current relationships, or its version history completes within 500 milliseconds at the 95th percentile across 30 measured attempts. `[ASSUMPTION — owner: Wouter; revisit before performance acceptance testing: this corpus, the two-second and 500-millisecond p95 bounds, and the 30-attempt sample are appropriate for personal validation.]`
- **NFR-11:** Current state must be the default presentation. History and evidence remain collapsed or secondary until requested; historical items never share the same affordances or visual priority as current Governing Decisions.
- **NFR-12:** Product-generated language must be calm, concise, inspectable, and honest about uncertainty, data transmission, provider and model identity, execution locality, OpenRouter cost when applicable, runtime/resource state, and failure. In the representative English and Dutch state suite, every message about privacy, providers, failures, or Canonical State states what happened or will happen, any relevant effect on transmission, cost, or Canonical State, and the available next action. It does not express unsupported certainty or expose only an unexplained provider error code. The primary message contains at most three sentences, with detail available on demand. `[ASSUMPTION — owner: Wouter; revisit before copy acceptance testing: this bilingual state suite and three-sentence primary-message limit are adequate for the validation build.]`

### 5.5 Provider Independence

- **NFR-13:** ProjectOS domain workflows and persisted Canonical State must depend only on the provider-independent AI capability contract. Provider-specific protocol types, authentication, sessions, usage models, and errors must be confined to adapters and normalized at the boundary.

## 6. Non-Goals

- Building a configurable project-management system or requiring routine manual artifact maintenance.
- Replacing the user's existing files, notes, email, task tools, or AI services wholesale.
- Autonomous execution of consequential project actions.
- Claiming differentiation from generic AI memory, local storage, BYO AI, or project containers alone.
- Proving commercial pricing, acquisition, retention, or multi-user demand in this validation cycle.

## 7. Validation Build Scope

### 7.1 In Scope

- Local-first macOS application for one owner.
- One or two real, cross-domain Projects used over four to six weeks.
- Fresh Project creation and lightweight pasted-text input.
- Conversation through an explicitly selected Qualified Adapter Combination, with Ollama, LM Studio, and MLX as first-class local targets and OpenRouter as the sole optional external target.
- A provider-independent capability contract, adapter registry, normalized events and errors, and reusable contract tests covering deterministic fakes and all four adapter targets, plus adapter-specific qualification evidence before any combination is represented as Ready.
- Explicit runtime/model setup, capability validation, local-versus-external Context Preview, loopback enforcement for Ollama and LM Studio, and Keychain-backed OpenRouter setup.
- Topics, Research, Decisions, Open Questions, and Tasks as typed Artifacts.
- User-reviewed Change Proposals with accept, edit, and reject.
- Rationale, Provenance, relationships, version history, and decision supersession.
- Re-entry View and explained Next Action.
- Local validation records for Qualifying Returns.
- Human-inspectable export and verified reopen or restore.
- Explicit Artifact removal and permanent local Project deletion.

#### Experiment Start and Provider-Scope Completion

The governed-semantic-continuity experiment may begin when the provider-free Epic 2 foundation is usable, the minimum Epic 4 Re-entry View and Return Outcome Record are usable, and at least one explicitly selected local Qualified Adapter Combination can complete the FR-3 through FR-6 Conversation-to-reviewed-proposal loop. OpenRouter and deterministic fakes do not satisfy this local experiment-start condition.

Reaching this cut line qualifies only the recorded combination; it does not mark another adapter, runtime, model, or the four-adapter provider scope Ready. The validation build's provider scope is complete only when Ollama, LM Studio, MLX, and OpenRouter each satisfy their applicable readiness criteria and the shared provider contract passes against deterministic fakes and all four production adapters.

If evidence from a qualified local combination causes the continue, rethink, or stop gate to reject the governed-continuity thesis, implementation and qualification of additional adapters stop unless recorded evidence shows that the combination, rather than the product thesis, caused the result. Adapter breadth must not postpone a negative thesis decision.

### 7.2 Out of Scope for the Validation Build

- Codex App Server or ChatGPT subscription integration.
- Direct OpenAI, Anthropic, or other provider API integrations.
- Local runtimes beyond Ollama, LM Studio, and MLX; remote Ollama or LM Studio endpoints.
- Automatic runtime, provider, or model fallback; automatic credit purchase or top-up.
- Mac App Store submission, payment, pricing tests, trial mechanics, and commercial licensing.
- Collaboration, sharing, roles, permissions, assignments, hosted synchronization, and multi-device use.
- Web and mobile applications.
- ProjectOS-hosted inference, AI billing, or project-content storage.
- Bulk provider-account import or reconstruction from complete AI exports.
- Autonomous tools or externally consequential actions.
- First-class Requirements, Risks, Files, Notes, Photos, Purchases, or Measurements.
- Emotional project-ownership identity, hero-image generation, extensive theming, and non-essential visual polish. These are post-validation deferrals, not rejected product direction.
- Commercial onboarding, activation, purchase, and conversion flows. Validation setup may remain builder-oriented.
- Optional diagnostics, analytics, support operations, and marketing instrumentation.

## 8. Success Metrics and Decision Gate

The validation window lasts four to six weeks across one or two real Projects. Commercial metrics from the product brief are intentionally deferred; they are not evidence that the continuity thesis works.

### 8.1 Primary Metrics

- **SM-0: Fast first value.** Each validation Project reaches a First Useful State without outside assistance within 15 minutes of Project creation, excluding initial runtime, model, or OpenRouter setup. Validates FR-1 through FR-5.
- **SM-1: Successful re-entry.** At least 80% of Qualifying Returns, across a minimum of three recorded returns, lead to Meaningful Work within five minutes. `[ASSUMPTION — owner: Wouter; revisit before the validation window begins: Three Qualifying Returns provide enough signal for this personal validation cycle.]` Validates FR-11, FR-12, and FR-13.
- **SM-2: Materially easier continuity.** After each Qualifying Return, the user rates understanding of current state and ease of continuation at least 4/5, and compares the result with the observed incumbent baseline where one is available; a hypothetical comparison is recorded separately and is not treated as equivalent evidence. Validates FR-11 and FR-13.
- **SM-3: Trustworthy extraction.** At least 85% of material facts and Decisions in Change Proposals are correct before user correction, measured against Source Material and the user's intended meaning and recorded for the active adapter/model. Validates FR-4 through FR-6.
- **SM-3A: Material completeness.** Across at least three proposal-generating validation sessions containing at least twenty user-identified material new or changed items in total, at least 85% of those items appear in the initial Change Proposal set without an additional prompt, and zero omitted items would leave a Governing Decision wrong, an accepted contradiction unresolved, or a Re-entry View materially misleading. An omitted item is measured separately from correctness even if the user later adds it manually. Fewer than three sessions or twenty expected items is insufficient evidence, not a pass. Validates FR-4 and FR-13. `[ASSUMPTION — owner: Wouter; revisit before the first proposal-generating validation session: three sessions, twenty expected items, 85% completeness, and zero governing-state or re-entry-critical omissions are adequate gates for this personal validation cycle.]`
- **SM-4: Useful guidance.** At least 70% of presented Next Actions during recorded validation episodes are judged relevant, actionable, and likely to advance or intentionally close a meaningful part of the Project, whether followed or dismissed. Each episode records whether the recommendation produced the suggested action, a different meaningful action, or no action; this outcome link is evidence, not an acceptance-rate target. `[ASSUMPTION — owner: Wouter; revisit before evaluating the first Next Action: A 70% usefulness threshold is sufficient to continue investing in guided continuation.]` Validates FR-12 and FR-13.

### 8.2 Integrity Gates

- **SM-5: No severe state failure.** Zero severe silent corruption, unrecoverable loss, or silent replacement of accepted Canonical State. Any occurrence stops validation until resolved. Validates FR-5 through FR-10, FR-17, and NFR-1 through NFR-3.
- **SM-6: Recoverable ownership.** Every planned export-and-reopen test restores equivalent Canonical State, Rationale, Provenance, relationships, and version history. Validates FR-16.

### 8.3 Counter-Metrics

- **SM-C1: Maintenance burden.** Do not improve re-entry metrics by requiring the user to manually recreate the Project in structured fields. Record proposal-review and correction effort; repeated perception that ProjectOS adds more maintenance than it removes is a stop-or-redesign signal.
- **SM-C2: Artifact or engagement volume.** Do not optimize the number of Artifacts, Conversations, AI calls, sessions, or time spent in ProjectOS. Meaningful Work and successful resolution matter more.
- **SM-C3: Blind acceptance.** Do not optimize Change Proposal acceptance rate at the expense of scrutiny, correction, or trust.
- **SM-C4: Adapter setup burden.** For every attempted adapter/runtime/model combination, record active setup time, attempts, outside assistance, blocking failures, and abandonment separately from SM-0. At least one local combination must reach Ready on the validation Mac within 30 minutes of active setup, using ProjectOS plus the runtime's standard installation and configuration path and without source-code or undocumented configuration edits, before the governed-continuity experiment begins. Failure blocks experiment start and triggers a setup rethink; OpenRouter does not satisfy this local gate. A remaining target that exceeds the bound stays unqualified and blocks complete provider-scope readiness, but does not erase valid continuity evidence from another qualified local combination. `[ASSUMPTION — owner: Wouter; revisit before the first adapter setup attempt: 30 active minutes is an acceptable setup bound for this validation build.]`

### 8.4 Continue, Rethink, or Stop

- **Continue toward a broader MVP** when SM-0, SM-1, SM-2, SM-3, SM-3A, and SM-4 are each met, integrity gates hold, and the user would choose ProjectOS for another consequential Project.
- **Rethink the interaction or state model** when value appears but state maintenance, correction burden, unexplained guidance, or material omissions prevent reliable re-entry. Any omission that leaves a Governing Decision wrong, an accepted contradiction unresolved, or a Re-entry View materially misleading forces `rethink` even if the aggregate completeness percentage passes. Recurrence of the same critical omission class after one redesign cycle stops the current extraction approach.
- **Stop the current concept** when Qualifying Returns are no better than rereading chat and notes, or when trustworthy Canonical State cannot be maintained without disproportionate manual work.

## 9. Open Questions

### 9.1 Before the Relevant Validation Step

1. Which one or two real Projects will constitute the validation set? **Owner:** builder. **Resolve:** before the four-to-six-week validation window starts.
2. Which Ollama, LM Studio, and MLX versions, model formats, minimum models, and macOS hardware meet the implementation compatibility, resource, and quality criteria? **Owner:** builder. **Resolve:** during production adapter implementation before each adapter/model combination is marked ready.
3. What maintenance-burden threshold triggers a rethink rather than continued validation? **Owner:** Wouter. **Resolve:** before the first Qualifying Return; until then, record burden without treating it as a fixed pass/fail threshold.
4. Which OpenRouter models are supported for validation, and what usage-visibility and cost ceiling apply? **Owner:** builder. **Resolve:** before OpenRouter is enabled for a real validation Project.

### 9.2 After Core Validation

5. Which local file formats should extend pasted-text Source Material input? **Owner:** builder. **Revisit:** only after the pasted-text continuity loop works.
6. Does the broader product keep the ProjectOS name? **Owner:** builder. **Revisit:** before commercial identity work begins.

## 10. Assumptions Index

- §8.1, SM-1 — Three Qualifying Returns provide enough signal for a personal validation cycle. Owner: Wouter; revisit before the validation window begins.
- §8.1, SM-4 — A 70% useful-Next-Action threshold is sufficient to justify further investment. Owner: Wouter; revisit before evaluating the first Next Action.
- §8.1, SM-3A — Three proposal-generating sessions, twenty expected material items, 85% completeness, and zero governing-state or re-entry-critical omissions are adequate gates for personal validation. Owner: Wouter; revisit before the first proposal-generating validation session.
- §5.4, NFR-10 — A 1,000-Artifact, 5,000-relationship, 10,000-message corpus, a two-second p95 for an indexed Re-entry View, a 500-millisecond p95 for Artifact, relationship, or history reads, and a 30-attempt sample are appropriate for personal validation. Owner: Wouter; revisit before performance acceptance testing.
- §5.4, NFR-12 — The representative English and Dutch state suite and a three-sentence primary-message limit are adequate for the validation build. Owner: Wouter; revisit before copy acceptance testing.
- §8.3, SM-C4 — One local Qualified Adapter Combination must reach Ready within 30 active setup minutes through documented setup without source-code or undocumented configuration edits. Owner: Wouter; revisit before the first adapter setup attempt.
