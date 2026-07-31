---
title: ProjectOS Product Requirements Document
status: final
created: 2026-07-28
updated: 2026-07-31
---

# PRD: ProjectOS Validation Build

*ProjectOS is a working title.*

## 0. Document Purpose

This PRD defines a personal, solo validation build of ProjectOS. It is intended for the builder and for downstream UX, architecture, epic, and implementation work. Its purpose is to test whether governed semantic project continuity makes returning to consequential, AI-assisted projects materially easier before committing to a commercial MVP. The current product brief and its addendum are the product-definition authority; the market research is supporting evidence. `docs/ProjectWorkspace.md` is superseded and is not an input. Functional requirements are grouped by capability and use stable, globally numbered IDs. Remaining inferences are tagged `[ASSUMPTION]` and indexed in §10.

## 1. Vision and Validation Thesis

ProjectOS is a local-first macOS workspace for people who use AI while pursuing complex, long-lived personal projects. AI chat is an effective working medium, but a weak authority for a project: research, governing decisions, rationale, unresolved questions, and tasks become fragmented across sessions and tools. Delegated AI research makes the gap sharper because findings and reasoning the user did not personally produce may remain trapped in a prior session rather than becoming durable project memory. After time away, the person must reread or reconstruct what is true before meaningful work can resume.

ProjectOS keeps conversation natural while turning consequential AI output into explicit, inspectable project state. AI may propose changes, but only accepted changes become canonical. The system distinguishes governing from superseded decisions, preserves rationale and provenance, and recommends a next action that can be explained from accepted state.

The validation thesis is narrow: after a meaningful absence, a person using ProjectOS can regain trustworthy context and resume meaningful real-world work faster and with less reconstruction than when relying on chat history, notes, and memory. Local storage, BYO AI, project containers, and generic “memory” are not sufficient differentiators; the test is governed semantic continuity.

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
- People without an eligible ChatGPT/Codex plan for the validation adapter. Future cloud or local adapters may widen eligibility after validation.

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
- **AI Provider Adapter** — The replaceable implementation that translates the ProjectOS AI capability contract to one provider or runtime. Codex App Server is the only adapter in the validation build.
- **Provider Capability** — A feature an adapter declares it can perform, such as structured output, streaming, persistent sessions, usage reporting, model selection, or local execution.
- **Provider Session Binding** — A replaceable link from a ProjectOS Conversation to provider-owned session state, such as a Codex thread ID. It is not the canonical Conversation identity.
- **Codex Runtime** — The locally running Codex App Server process used by the initial adapter. It owns its authentication lifecycle and communicates with OpenAI.
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
- The explanation identifies what meaningful part of the Project the recommendation is expected to advance or intentionally close.
- The user can dismiss the recommendation without modifying Canonical State.
- When evidence is insufficient or contradictory, ProjectOS states that uncertainty rather than presenting a confident recommendation.

#### FR-13: Record return outcomes

The user can record whether a Qualifying Return produced clear understanding, trust in the state, a useful Next Action, and Meaningful Work within five minutes.

**Consequences (testable):**

- The record captures elapsed time and brief qualitative notes.
- Validation records remain local and can be exported.

### 4.5 Provider, Privacy, and Portability

**Description:** ProjectOS accesses AI through a provider-independent capability boundary. The validation build supplies one Codex App Server adapter using ChatGPT subscription access. ProjectOS makes the active provider and execution boundary explicit, minimizes transmitted context, and keeps Canonical State locally owned and recoverable. Realizes UJ-1 and UJ-4.

#### FR-14: Configure and validate the AI Provider

The user can configure and validate the available AI Provider Adapter. For the validation build, ProjectOS detects a compatible Codex Runtime and starts a Codex-managed ChatGPT browser sign-in.

**Consequences (testable):**

- ProjectOS does not request an OpenAI API key or read, persist, log, or export ChatGPT access or refresh tokens; the Codex Runtime owns its authentication state.
- A cancelled, expired, or failed sign-in does not damage Project State and returns the user to the interrupted action when recovery succeeds.
- The interface distinguishes a missing or incompatible runtime, signed-out state, ineligible account or plan, network or provider failure, rate limit, and exhausted plan allowance.
- The user can inspect the signed-in account and plan plus the allowance windows, usage percentage, and reset times exposed by Codex. ProjectOS does not fabricate a weekly schedule when the runtime reports a different window.
- ProjectOS does not purchase API credits, prompt for automatic credit top-up, or silently fall back to usage-based API-key billing.
- Local project capabilities remain available when the provider is unavailable or the plan allowance is exhausted.

#### FR-15: Disclose external transmission

Before sending Project content through an AI Provider Adapter, ProjectOS identifies the provider and whether processing is local or external, shows or summarizes the selected transmission scope, and requires user initiation.

**Consequences (testable):**

- No Project content is transmitted merely by opening or browsing a Project.
- Local-only actions remain distinguishable from actions that contact an external provider or local model runtime.
- ProjectOS does not claim that local-first operation eliminates all privacy obligations.
- The initial Codex adapter discloses that the selected context is sent through the local Codex Runtime to OpenAI and may consume the user's shared Codex plan allowance.

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
- Permanently deleting a Project requires confirmation that explains the effect and offers export first; completion removes the Project, its history, Source Material, Conversations, validation records, Provider Session Bindings, and provider-side session data managed by the active adapter.
- The Codex adapter must confirm successful deletion of each associated persisted Codex thread before ProjectOS reports provider-side cleanup complete. If cleanup cannot complete, local deletion may continue only with a clear residual-data warning and a retry path.
- Project deletion does not remove account-level provider authentication or claim to delete data retained independently by OpenAI, macOS backups, or user-created exports.
- Provider-side session cleanup is a lifecycle operation and does not send new Project content for generation.

### 4.7 Provider Independence

**Description:** The initial Codex integration must prove the provider boundary without making Codex the shape of ProjectOS. This preserves the intended path to additional cloud providers and local models.

#### FR-18: Keep AI providers replaceable

ProjectOS can add an AI Provider Adapter without changing its Canonical State model or core Conversation, Change Proposal, Re-entry, export, and deletion workflows.

**Consequences (testable):**

- A fake provider can execute the provider contract in automated tests without importing Codex protocol types into ProjectOS domain modules.
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
- **NFR-8:** Provider authentication must remain owned by the adapter or its runtime. ProjectOS must not read, log, export, or store provider access or refresh tokens in Project data. The initial Codex adapter must use Codex-managed authentication and macOS-appropriate secure storage.
- **NFR-9:** Only user-selected context required for a requested provider operation may cross the configured provider boundary. Cloud adapters may transmit it externally; local adapters must not make an external transmission unless they declare and disclose that capability.

### 5.4 Usability and Responsiveness

- **NFR-10:** Browsing locally stored Canonical State, Rationale, Provenance, and the Re-entry View must remain available without network access.
- **NFR-11:** Current state must be the default presentation; history and evidence must be available on demand without overwhelming the primary workflow.
- **NFR-12:** Product-generated language must be calm, concise, inspectable, and honest about uncertainty, data transmission, provider identity, plan allowance or provider cost when applicable, runtime state, and failure.
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
- Conversation through the Codex App Server adapter using Codex-managed ChatGPT sign-in and an eligible ChatGPT plan allowance.
- A provider-independent capability contract, adapter registry, normalized events and errors, and contract tests using the Codex adapter plus a fake provider.
- Topics, Research, Decisions, Open Questions, and Tasks as typed Artifacts.
- User-reviewed Change Proposals with accept, edit, and reject.
- Rationale, Provenance, relationships, version history, and decision supersession.
- Re-entry View and explained Next Action.
- Local validation records for Qualifying Returns.
- Human-inspectable export and verified reopen or restore.
- Explicit Artifact removal and permanent local Project deletion.

### 7.2 Out of Scope for the Validation Build

- Additional AI Provider Adapters, including local models. A local adapter remains part of the broader product direction but follows proof of the continuity loop.
- Direct OpenAI API-key setup, API-credit billing, automatic credit purchase, or a hidden API-key fallback.
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

- **SM-0: Fast first value.** Each validation Project reaches a First Useful State without outside assistance within 15 minutes of Project creation, excluding initial provider runtime and sign-in setup. Validates FR-1 through FR-5.
- **SM-1: Successful re-entry.** At least 80% of Qualifying Returns, across a minimum of three recorded returns, lead to Meaningful Work within five minutes. `[ASSUMPTION — owner: Wouter; revisit before the validation window begins: Three Qualifying Returns provide enough signal for this personal validation cycle.]` Validates FR-11, FR-12, and FR-13.
- **SM-2: Materially easier continuity.** After each Qualifying Return, the user rates understanding of current state and ease of continuation at least 4/5, and compares the result with the observed incumbent baseline where one is available; a hypothetical comparison is recorded separately and is not treated as equivalent evidence. Validates FR-11 and FR-13.
- **SM-3: Trustworthy extraction.** At least 85% of material facts and Decisions in Change Proposals are correct before user correction, measured against Source Material and the user's intended meaning. Validates FR-4 through FR-6.
- **SM-3A: Material completeness.** After each proposal-generating validation session, the user compares the proposals with the material new or changed state they expected to preserve and records omitted Decisions, Open Questions, Tasks, or Research separately from incorrect proposals. Repeated omissions that impair current-state understanding or re-entry are a redesign signal. Validates FR-4 and FR-13.
- **SM-4: Useful guidance.** At least 70% of presented Next Actions during recorded validation episodes are judged relevant, actionable, and likely to advance or intentionally close a meaningful part of the Project, whether followed or dismissed. `[ASSUMPTION — owner: Wouter; revisit before evaluating the first Next Action: A 70% usefulness threshold is sufficient to continue investing in guided continuation.]` Validates FR-12.

### 8.2 Integrity Gates

- **SM-5: No severe state failure.** Zero severe silent corruption, unrecoverable loss, or silent replacement of accepted Canonical State. Any occurrence stops validation until resolved. Validates FR-5 through FR-10, FR-17, and NFR-1 through NFR-3.
- **SM-6: Recoverable ownership.** Every planned export-and-reopen test restores equivalent Canonical State, Rationale, Provenance, relationships, and version history. Validates FR-16.

### 8.3 Counter-Metrics

- **SM-C1: Maintenance burden.** Do not improve re-entry metrics by requiring the user to manually recreate the Project in structured fields. Record proposal-review and correction effort; repeated perception that ProjectOS adds more maintenance than it removes is a stop-or-redesign signal.
- **SM-C2: Artifact or engagement volume.** Do not optimize the number of Artifacts, Conversations, AI calls, sessions, or time spent in ProjectOS. Meaningful Work and successful resolution matter more.
- **SM-C3: Blind acceptance.** Do not optimize Change Proposal acceptance rate at the expense of scrutiny, correction, or trust.

### 8.4 Continue, Rethink, or Stop

- **Continue toward a broader MVP** when SM-0 through SM-4 are met, integrity gates hold, and the user would choose ProjectOS for another consequential Project.
- **Rethink the interaction or state model** when value appears but state maintenance, correction burden, or unexplained guidance prevents reliable re-entry.
- **Stop the current concept** when Qualifying Returns are no better than rereading chat and notes, or when trustworthy Canonical State cannot be maintained without disproportionate manual work.

## 9. Open Questions

### 9.1 Before the Relevant Validation Step

1. Which one or two real Projects will constitute the validation set? **Owner:** builder. **Resolve:** before the four-to-six-week validation window starts.
2. Which Codex Runtime versions and plan-available models meet the validation quality and compatibility gates? **Owner:** builder. **Resolve:** during the Codex App Server validation spike and before implementation is pinned to a runtime version.
3. What maintenance-burden threshold triggers a rethink rather than continued validation? **Owner:** Wouter. **Resolve:** before the first Qualifying Return; until then, record burden without treating it as a fixed pass/fail threshold.

### 9.2 After Core Validation

4. Which local file formats should extend pasted-text Source Material input? **Owner:** builder. **Revisit:** only after the pasted-text continuity loop works.
5. Which local runtime should become the first local-model adapter, and when should it be introduced to test privacy, quality, and local-inference demand? **Owner:** builder. **Revisit:** at the continue/rethink/stop gate.
6. Does the broader product keep the ProjectOS name? **Owner:** builder. **Revisit:** before commercial identity work begins.

## 10. Assumptions Index

- §8.1, SM-1 — Three Qualifying Returns provide enough signal for a personal validation cycle. Owner: Wouter; revisit before the validation window begins.
- §8.1, SM-4 — A 70% useful-Next-Action threshold is sufficient to justify further investment. Owner: Wouter; revisit before evaluating the first Next Action.
