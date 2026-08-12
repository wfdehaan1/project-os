# Input Reconciliation: Product Brief and Addendum

## Inputs

- **Product-definition authority:** `_bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/brief.md`
- **Qualitative and decision-history authority:** `_bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/addendum.md`
- **Compared with:** `prd.md` and `addendum.md` in this PRD workspace, updated 2026-08-12
- **Provider-course-correction authority:** `_bmad-output/planning-artifacts/sprint-change-proposal-2026-08-09.md`

## Reconciliation Verdict

**Substantively aligned for the personal validation slice, with three deliberate post-validation deferrals that must remain visible downstream.** The updated PRD preserves the brief's defining product contract: AI conversation is working context rather than authority; accepted typed changes create versioned Canonical State; Governing and Superseded Decisions remain distinct; Rationale, Provenance, relationships, and Research remain inspectable; re-entry is current-state-first; and Next Actions are explained from accepted state.

The two documents intentionally operate at different commitment levels. The brief remains authority for the broader commercial MVP: Mac App Store distribution, one-time pricing, paste-or-drop mid-project activation, guided onboarding, project identity, and market validation. The PRD is a smaller personal experiment for Wouter, one or two Projects, and a four-to-six-week governed-continuity decision. Its success can justify further product investment; it cannot prove switching, willingness to pay, commercial onboarding, price, or generalizable demand. The brief's concierge and price-bearing gates therefore remain future commercial evidence, not hidden requirements of this validation build.

## Current Gaps and Preserved Deferrals

### 1. Mid-project input is deliberately narrower than the commercial brief

**Brief intent:** Most target customers arrive with existing material. The commercial MVP permits pasted or dropped conversations, notes, and documents so First Useful State tests the real switching and activation problem rather than only blank-slate use.

**Current PRD state:** FR-2 and §7.1 deliberately limit the first validation slice to user-selected pasted text. File selection and parsing are deferred to Open Question 5; bulk provider-account reconstruction remains excluded in both documents.

**Downstream preservation:** This is a coherent experiment cut, not an accidental omission. It proves the continuity loop with controlled input but does not validate the brief's broader mid-project drop/import activation promise. File formats should be selected only after pasted-text continuity works, and the broader MVP must still test First Useful State from representative dropped material.

### 2. Project atmosphere and emotional ownership remain untested qualitative intent

**Brief intent:** Each Project should feel recognizably its own—a renovation, car search, or software build should carry a distinct atmosphere that supports orientation and emotional ownership, not customization for its own sake.

**Current PRD state:** The validation build explicitly defers hero imagery, project-ownership identity, extensive theming, and non-essential polish. The addendum preserves a restrained hero image and accent identity as a post-validation direction, and the UX handoff preserves a calm, conversational, low-maintenance feel.

**Downstream preservation:** Do not add visual-production scope to this experiment. Preserve the richer qualitative requirement for the commercial UX: recognizable Project atmosphere across the experience, with constrained identity serving attachment and orientation rather than decorative customization.

### 3. Commercial onboarding remains deferred even though validation setup burden is now measured

**Brief intent:** Guided runtime/model readiness, explicit selection, secure OpenRouter setup, local-versus-external disclosure, cost disclosure, and plain-language recovery are launch requirements rather than polish. The broader audience cannot be assumed to tolerate bespoke runtime or API troubleshooting.

**Current PRD state:** The earlier setup-measurement gap is resolved for the personal experiment. FR-14 defines Qualified Adapter Combinations and readiness evidence; FR-15 defines boundary disclosure; NFR-12 defines plain-language acceptance; SM-C4 records setup time, assistance, failures, abandonment, and a 30-active-minute local gate. OpenRouter model support, usage visibility, and cost ceiling remain an owned Open Question. Commercial onboarding, activation, purchase, and conversion flows remain explicitly out of validation scope.

**Downstream preservation:** Treat SM-C4 as builder-validation evidence, not proof of commercial onboarding. Before launch, validate guided setup with target users, cost comprehension for OpenRouter, recovery without bespoke intervention, and price-bearing activation. The local-first course correction does not weaken this commercial promise.

## Reconciled Decisions — No Longer Open Findings

### Successful-resolution and Next Action outcome evidence are captured

FR-13 records whether a shown Next Action led to that action, a different meaningful action, or no action. SM-4 treats this linkage as evidence rather than an acceptance-rate target. The Return Outcome Record also distinguishes eventual successful completion, intentional closure, abandonment, and unresolved outcomes without turning project completion into a gate for every Qualifying Return. These brief intents are now represented in the personal validation record.

### Delegated-research rationale is restored

PRD §1 now explicitly states that delegated findings and reasoning the user did not personally produce can remain trapped and make later reconstruction harder. Research is a first-class Artifact, and the Re-entry View exposes concise current state with Rationale and evidence on demand. Downstream UX should continue to restore comprehension, not merely retrieve stored facts, but the rationale is no longer missing from the product story.

### The provider course correction is coherent

The updated PRD and addendum correctly implement the approved 2026-08-09 direction:

- Ollama, LM Studio, and MLX are committed first-class local MVP adapter targets.
- OpenRouter is the sole optional external target.
- Codex App Server, ChatGPT subscription integration, and direct OpenAI or Anthropic production adapters are excluded.
- Adapter names are not support claims; only an evidence-bound Qualified Adapter Combination may be shown as Ready or Supported.
- One qualified local combination may begin the continuity experiment; all four targets must satisfy applicable criteria before provider-scope completion.
- Selection is explicit and no locality, provider, runtime, or model fallback is silent.

This qualification language refines rather than contradicts the brief's first-class-target decision. The completed Codex work remains rejected historical evidence and does not authorize current production sequencing.

### Setup and maintenance burden are now distinct

SM-C1 records ongoing proposal-review and correction burden. SM-C4 and addendum §3.5 separately measure initial adapter/runtime/model setup burden. The two risks can no longer hide inside the fifteen-minute First Useful State measure. A maintenance-burden threshold remains an owned pre-return decision, while the local setup gate is explicit.

### Core commercial direction is preserved without entering validation scope

The PRD addendum retains one-time Mac App Store purchase, the $59.99 working hypothesis with $39.99 and $79.99 anchors, commercial onboarding, price-bearing activation, constrained project identity, and potential paid major upgrades. Collaboration, synchronization, multi-surface access, and managed recurring value remain later evolution rather than implied validation requirements.

## Coverage Confirmed

- Cross-domain positioning is intact; renovation remains evidence and a possible cohort, not the product definition.
- The source-to-truth loop is intact: selected material or Conversation → typed proposal → explicit accept/edit/reject → versioned Canonical State.
- Conversation remains inspectable Provenance and is never Canonical State.
- Research, Decisions, Open Questions, Tasks, Topics, Rationale, relationships, versions, and supersession retain their intended roles.
- Re-entry exposes current governing state first, with deeper rationale and evidence on demand.
- Local ownership, explicit external transmission, Keychain-backed OpenRouter credentials, human-inspectable export/restore, deliberate deletion, and zero silent state corruption remain observable trust contracts.
- Generic “AI memory,” local storage, project containers, or provider choice are not presented as the differentiation thesis.
- Commercial metrics and broader-market claims are explicitly excluded from the personal validation verdict.

## Final Judgment

The product brief and addendum are adequately represented for PRD finalization. The three items above are explicit commercial or qualitative deferrals; none requires reopening the personal validation slice's provider scope, adding file parsing now, or implementing commercial identity and onboarding before the governed-continuity experiment. They must remain visible in later UX, commercial-MVP, and validation planning so a successful solo continuity test is not mistaken for fulfillment of the broader brief.
