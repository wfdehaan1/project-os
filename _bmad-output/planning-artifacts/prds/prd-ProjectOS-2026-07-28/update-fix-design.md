# PRD Update Fix Design

## Purpose and guardrails

This design proposes exact requirement-level corrections for the seven findings in `validation-report.md`. It does not edit the PRD or addendum.

- The PRD changes stay at capability, observable-behavior, scope, and decision-gate level.
- The addendum changes carry measurement mechanics, sequencing detail, and historical rationale.
- Ollama, LM Studio, and MLX remain first-class local MVP targets; OpenRouter remains the sole optional external MVP target.
- The completed Codex App Server spike remains historical rejected evidence and never authorizes production Codex work.
- Epic 2 and Story 2.1 remain provider-free and may proceed only after the governing authority set passes readiness.
- Numeric thresholds proposed below are new product decisions, not facts derived from the approved sprint proposal. They should be logged as assumptions and approved before application.

## 1. Remove the stale Codex handoff

### Addendum §8 — replace `### Architecture` body

Replace the paragraph beginning `Architecture must establish invariants` with:

> Architecture follows the current [AI provider architecture spine](../../architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md): a provider-independent, generation-only capability boundary with Ollama, LM Studio, and MLX as first-class local MVP adapter targets and OpenRouter as the sole optional external target. It must preserve atomic accepted-state transitions, stable Artifact identity, version and supersession history, Provenance integrity, local persistence, export and restore, runtime/model-scoped capability negotiation, explicit boundary disclosure, ProjectOS-owned Conversation and Change Proposal schemas, normalized failures, no silent fallback, and capability-aware deletion. The completed Codex App Server spike and its architecture are historical rejected evidence only; they neither authorize production Codex work nor impose Codex process, authentication, protocol, containment, profile, or cleanup mechanics on replacement adapters.

### Addendum §8 — replace `### Epics and Implementation` body

Replace the paragraph beginning `Implementation sequencing should first prove` with:

> Epic 2 establishes the trusted local Project, Canonical State, Source Material, Artifact, relationship, history, Provenance, and offline foundations without requiring any configured inference adapter; Story 2.1 must not introduce or depend on provider implementation. Epic 3 then implements the shared provider contract and job coordination, qualifies adapter/runtime/model combinations through implementation acceptance tests, and builds the provider-backed Conversation-to-proposal loop. The governed-continuity experiment may begin when the cut line in PRD §7.1 is met. The validation build's complete provider scope still requires the approved Ollama, LM Studio, MLX, and optional OpenRouter targets to satisfy their applicable contract and integration criteria. No new authorization spike or Codex adapter validation is required or permitted by this sequence.

Why this is safe: it matches sprint-change §§3.1 and 5.3, architecture `AD-1` through `AD-13`, and the Epic 2/Epic 3 boundary in `epics.md`.

## 2. Add a thesis-linked provider cut line

### PRD §7.1 — add `#### Experiment Start and Provider-Scope Completion`

Add after the current in-scope list:

> The governed-semantic-continuity experiment may begin when the provider-free Epic 2 foundation is complete and at least one explicitly selected local adapter/runtime/model combination has been qualified under FR-14 and can complete the FR-3 through FR-6 Conversation-to-reviewed-proposal loop. OpenRouter does not satisfy this local experiment-start condition.
>
> Reaching this cut line qualifies only the recorded combination; it does not mark another adapter, runtime, model, or the four-adapter provider scope ready. The validation build's provider scope is complete only when Ollama, LM Studio, MLX, and OpenRouter each satisfy their applicable readiness criteria and the shared provider contract passes against deterministic fakes and all four production adapters.
>
> If the continue/rethink/stop gate rejects the governed-continuity thesis using a qualified local combination, implementation and qualification of additional adapters stops unless recorded evidence shows that the result was caused by that combination rather than the product thesis. Adapter breadth must not be used to postpone a negative thesis decision.

### Addendum §5.1 — add sequencing interpretation

Add:

> The experiment-start cut line is a learning boundary, not an adapter hierarchy. It permits product-thesis validation with one qualified local combination while retaining all four approved targets for provider-scope completion. Selection remains explicit; no qualified adapter becomes an automatic fallback or preferred hidden default. Qualification proceeds through implementation acceptance criteria, not another feasibility or authorization spike.

Conflict check: this does not remove an approved adapter. It preserves the four-adapter completion obligation from sprint-change §5.4 and architecture `AD-13`, while preventing provider breadth from blocking or laundering the narrower continuity decision.

## 3. Distinguish adapter targets from qualified support

### PRD §2.3 — replace the last non-user bullet

Replace:

> People who cannot run a supported local model on the validation Mac and do not choose to configure the optional OpenRouter adapter.

With:

> People whose validation Mac cannot run any qualified local adapter/runtime/model combination and who do not choose to configure a qualified OpenRouter combination.

### PRD §3 — replace `AI Provider Adapter` definition

Replace:

> **AI Provider Adapter** — The replaceable implementation that translates the ProjectOS AI capability contract to one provider or runtime. The validation build supports Ollama, LM Studio, MLX, and OpenRouter adapters.

With:

> **AI Provider Adapter** — The replaceable implementation that translates the ProjectOS AI capability contract to one provider or runtime. Ollama, LM Studio, and MLX are committed first-class local MVP adapter targets; OpenRouter is the sole optional external MVP target. Support is declared only for a qualified adapter/runtime/model combination, not for an adapter name alone.

Add a glossary term:

> **Qualified Adapter Combination** — A specific adapter, runtime version where applicable, model and model format, macOS hardware class, and configuration that has recorded evidence for required capabilities, resource readiness, output quality and schema validity, boundary disclosure, cancellation, and applicable failure behavior. Qualification applies only to that recorded combination and its known degradations.

### PRD FR-14 — revise the capability statement and add readiness consequences

Replace the first sentence with:

> The user can configure and validate an Ollama, LM Studio, or MLX target for local inference, or explicitly configure the OpenRouter target as an external alternative. The user explicitly chooses the active adapter and model, and ProjectOS represents a combination as Ready only when that combination is qualified.

Add these consequences:

> - Adapter identity, discovery, installation, model presence, or a successful health request alone never marks a combination Ready or Supported.
> - Each Ready state is bound to the recorded adapter, runtime version where applicable, model and format, macOS hardware class, configuration, required capabilities, context and resource bounds, known degradations, and current qualification evidence.
> - A changed runtime version, model, model format, hardware class, configuration, or mandatory capability invalidates or re-evaluates readiness before dispatch; ProjectOS shows `Unknown`, `Unsupported`, or `Temporarily unavailable` when Ready is not justified.
> - Qualification includes representative quality and omission evidence, ProjectOS-owned schema validation, boundary disclosure, cancellation, and applicable failure normalization; it is implementation acceptance evidence and not a new product-authorization spike.

### PRD §7.1 — revise provider-scope wording

Replace `Conversation through explicitly selected Ollama, LM Studio, or MLX local inference, with OpenRouter available as an optional external alternative` with:

> Conversation through an explicitly selected Qualified Adapter Combination, with Ollama, LM Studio, and MLX as first-class local targets and OpenRouter as the sole optional external target.

Replace `reusable contract tests covering all four adapters` with:

> reusable contract tests covering deterministic fakes and all four adapter targets, plus adapter-specific qualification evidence before any combination is represented as Ready.

### Addendum §5.1 — revise target wording

Replace `are first-class local AI Provider Adapters for validation` with `are first-class local AI Provider Adapter targets for validation`, then add:

> Target status is a scope commitment, not a support claim. Supported and Ready apply only to a Qualified Adapter Combination. The compatibility record names the adapter, runtime version where applicable, model and format, macOS hardware class, context/resource bounds, known degradations, and the evidence date.

Conflict check: these edits project architecture `AD-2`, `AD-13`, and epic requirements `AR14`, `AR15`, and `AR18` into observable product language without importing implementation types into the PRD.

## 4. Give SM-3A explicit decision semantics

### PRD §8.1 — replace SM-3A

Replace the current SM-3A with:

> - **SM-3A: Material completeness.** Across at least three proposal-generating validation sessions containing at least twenty user-identified material new or changed items in total, at least 85% of those items appear in the initial Change Proposal set without an additional prompt, and zero omitted items would leave a Governing Decision wrong, an accepted contradiction unresolved, or a Re-entry View materially misleading. An omitted item is measured separately from correctness even if the user later adds it manually. Fewer than three sessions or twenty expected items is insufficient evidence, not a pass. Validates FR-4 and FR-13. `[ASSUMPTION — owner: Wouter; revisit before the first proposal-generating validation session: three sessions, twenty expected items, and 85% completeness are adequate for this personal validation cycle.]`

### PRD §8.4 — make the gate explicit

Replace `when SM-0 through SM-4 are met` with:

> when SM-0, SM-1, SM-2, SM-3, SM-3A, and SM-4 are each met

Add to the rethink condition:

> Any omission that leaves a Governing Decision wrong, an accepted contradiction unresolved, or a Re-entry View materially misleading forces `rethink` even if the aggregate completeness percentage passes. Recurrence of the same critical omission class after one redesign cycle stops the current extraction approach.

### PRD §10 — add the new assumption

Add:

> - §8.1, SM-3A — Three proposal-generating sessions, twenty expected material items, and 85% completeness provide adequate personal-validation evidence; zero governing-state or re-entry-critical omissions is mandatory. Owner: Wouter; revisit before the first proposal-generating validation session.

### Addendum §3.2 — add classification mechanics

Add:

> Before reviewing proposals, the user records the expected material items without looking at the generated set. After comparison, each absent item is classified as: (a) material but non-critical, or (b) critical because its absence would leave a Governing Decision wrong, an accepted contradiction unresolved, or a Re-entry View materially misleading. The completeness denominator is all expected material items; the numerator is those represented in the initial proposal set without an additional prompt. Manual repair does not convert an omission into a hit. Record session count, item count, completeness percentage, critical-omission count, active Qualified Adapter Combination, and whether the evidence volume is sufficient for a gate decision.

## 5. Bound the usability NFRs

### PRD NFR-10 — replace

Replace NFR-10 with:

> - **NFR-10:** Browsing locally stored Canonical State, Rationale, Provenance, and the Re-entry View must remain available without network access. On the supported validation Mac, with a Project containing up to 1,000 Artifacts, 5,000 explicit relationships, and 10,000 locally stored Conversation messages, opening an already indexed Re-entry View completes within 2 seconds and opening an Artifact, its current relationships, or its version history completes within 500 milliseconds at the 95th percentile across 30 measured attempts. `[ASSUMPTION — owner: Wouter; revisit before performance acceptance testing: these corpus and latency bounds represent the validation workload.]`

### PRD NFR-12 — replace

Replace NFR-12 with:

> - **NFR-12:** Product-generated language must be calm, concise, inspectable, and honest about uncertainty, data transmission, provider and model identity, execution locality, OpenRouter cost when applicable, runtime/resource state, and failure. In the representative English and Dutch state suite, every privacy-, provider-, failure-, and Canonical-State message states what happened or will happen, the transmission/cost/Canonical-State effect that matters, and the available next action; it uses no unsupported certainty or unexplained provider error code, and keeps the primary message to at most three short sentences with detail available on demand.

### PRD §10 — add the performance assumption

Add:

> - §5.4, NFR-10 — A 1,000-Artifact, 5,000-relationship, 10,000-message Project and the proposed p95 latency targets represent the personal validation workload. Owner: Wouter; revisit before performance acceptance testing.

### Addendum — add a `### 3.4 Usability Acceptance` subsection

Add:

> Measure NFR-10 on the supported validation Mac against a deterministic reference Project at the stated bounds after indexing is complete. Run thirty attempts for each named action and report p50 and p95; exclude initial import/index construction but do not exclude ordinary application startup or cache misses unless separately reported. The English/Dutch NFR-12 suite covers local-ready, local-unavailable, OpenRouter-external, offline, malformed-output, rejected-proposal, and failed-Canonical-State-transition cases. A copy pass fails when any primary message omits the user-relevant effect or next action, implies unearned certainty, hides external processing or cost, or exposes only an unexplained provider code.

## 6. Measure setup burden separately from first value

### PRD §8.3 — add SM-C4

Add:

> - **SM-C4: Adapter setup burden.** For every attempted adapter/runtime/model combination, record active setup time, attempts, outside assistance, blocking failures, and abandonment separately from SM-0. At least one local combination must reach Ready on the validation Mac within 30 minutes of active setup, using ProjectOS plus the runtime's standard installation and configuration path and without source-code or undocumented configuration edits, before the governed-continuity experiment begins. Failure blocks experiment start and triggers a setup rethink; OpenRouter does not satisfy this local gate. A remaining target that exceeds the bound stays unqualified and blocks complete provider-scope readiness, but does not erase valid continuity evidence from another qualified local combination. `[ASSUMPTION — owner: Wouter; revisit before the first adapter setup attempt: 30 active minutes is an acceptable setup bound for this validation build.]`

### PRD §10 — add the setup assumption

Add:

> - §8.3, SM-C4 — One local Qualified Adapter Combination must reach Ready within 30 active setup minutes through documented setup without source-code or undocumented configuration edits. Owner: Wouter; revisit before the first adapter setup attempt.

### Addendum — add `### 3.5 Adapter Setup Burden`

Add:

> Start active setup timing when the user begins the ProjectOS or runtime setup instructions and pause only for unattended download or model-transfer time, which is recorded separately. Stop when ProjectOS truthfully reports Ready or the attempt is abandoned. Record adapter, runtime version, model and format, hardware class, active time, waiting time, attempt count, documentation used, person or tool providing assistance, every blocking failure, any source-code or undocumented configuration edit, and final outcome. Ordinary use of vendor installation instructions is not outside assistance; bespoke troubleshooting or another person's intervention is. Setup evidence is scoped to that combination and does not authorize fallback or another target.

## 7. Correct the deferred-adapter wording

### Addendum §6 — replace one bullet

Replace:

> support for multiple cloud and local AI adapters behind the provider-independent boundary;

With:

> additional cloud or local AI adapters beyond the approved Ollama, LM Studio, MLX, and OpenRouter targets, plus commercial-scale compatibility maintenance, support operations, and broader provider/model coverage;

This preserves the active four-adapter validation scope while deferring only future breadth and commercial hardening.

## Application order and verification

Apply the edits in this order so later text relies on already-defined terms:

1. Replace addendum §8's stale Codex handoff.
2. Add `Qualified Adapter Combination` and revise target-versus-support wording.
3. Add the experiment cut line.
4. Add SM-3A gate semantics and measurement mechanics.
5. Replace NFR-10/NFR-12 and add usability measurement mechanics.
6. Add SM-C4 and setup mechanics.
7. Correct the deferred-adapter bullet.
8. Log each accepted threshold and course-correction decision through `memlog.py`; update PRD `updated` date without changing `status` until validation passes.

Verification after application:

- Search current PRD/addendum handoff text for operational `Codex`, `ChatGPT`, and `App Server`; every remaining occurrence must be explicitly historical, rejected, excluded, or deferred.
- Confirm FR IDs remain FR-1 through FR-18 and NFR IDs remain NFR-1 through NFR-13.
- Confirm every inline `[ASSUMPTION]` appears once in §10 and each §10 entry points to live inline text.
- Confirm the four adapter targets, local-first category, explicit selection, no fallback, Keychain secret handling, Context Preview, and provider-free Epic 2 remain consistent with the sprint proposal, architecture spine, and epics.
- Confirm one local qualified combination starts the experiment, while all four approved targets remain required for complete provider-scope readiness.
- Re-run PRD validation before treating the package as Story 2.1 readiness input.
