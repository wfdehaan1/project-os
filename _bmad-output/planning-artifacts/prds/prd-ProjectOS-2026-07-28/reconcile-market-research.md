# Input Reconciliation: Market Opportunity Research

## Input

- **Source:** `../../research/market-projectos-market-opportunity-research-2026-07-27.md`
- **Compared with:** `prd.md` and `addendum.md`, updated through the approved 2026-08-09 local-AI-first course correction and subsequent PRD validation fixes.
- **Authority rule:** The current product brief, approved sprint change proposal, PRD run decisions, PRD, and addendum govern where the earlier market research recommends a broader concierge, commercial, or launch program.
- **Verdict:** Reconciled with two bounded residual gaps. The updated PRD package now preserves the research's problem-supported/solution-unvalidated posture, real-incumbent comparison, governed-state differentiation, trust controls, provider setup risk, and local ownership. Neither residual blocks Story 2.1 or the provider-free Epic 2 foundation; each must be resolved before the validation event it governs.

## Residual Gaps

### 1. The maintenance-burden decision threshold remains intentionally unresolved

**Research signal:** Flexible knowledge and project tools often turn setup and upkeep into work of their own. ProjectOS must reduce reconstruction without imposing disproportionate state-maintenance, review, and correction effort.

**Current coverage:** PRD SM-C1 records proposal-review and correction effort and makes repeated perception that maintenance costs more than reconstruction a stop-or-redesign signal. Addendum §3.3 specifies the time and manual-state work to record. PRD Open Question 3 assigns Wouter to resolve a threshold before the first Qualifying Return.

**Residual gap:** The evidence is captured, but the numeric or qualitative threshold that distinguishes acceptable burden from `rethink` is not yet decided. Without that decision, the continue gate can be interpreted after seeing the outcome.

**Required reconciliation:** Resolve and log the threshold before the first Qualifying Return, as already required by PRD §9.1. This is an owner decision, not a reason to add implementation scope or block Story 2.1.

### 2. OpenRouter cost legibility and spending control are not yet specified

**Research signal:** BYO-provider variable usage cost is a high adoption risk. The research recommends cost preview, separately visible provider usage, predictable charges, and spending controls so cost uncertainty does not suppress use or cause surprise spending.

**Current coverage:** FR-14 distinguishes OpenRouter credential, rate, quota, billing, and service failures. FR-15 and NFR-12 require the selected routed model, external processing, usage-based billing, and user-relevant cost effect to be disclosed before use. The addendum makes OpenRouter optional and not a prerequisite for the local-first experiment. PRD Open Question 4 requires supported OpenRouter models, usage visibility, and a cost ceiling to be decided before real validation use.

**Residual gap:** The package does not yet define the model allowlist, validation-cycle cost ceiling, pre-use cost expectation, cumulative usage view or provider-dashboard handoff, or behavior at the ceiling. Billing disclosure alone does not make likely or accumulated cost predictable.

**Required reconciliation:** Before OpenRouter is enabled for a real validation Project, resolve and record the supported routed models, cost ceiling, source of usage/cost information, pre-dispatch expectation, cumulative visibility, and ceiling behavior. Full commercial metering remains deferred. This gap does not block a qualified local adapter, the experiment-start cut line, Story 2.1, or Epic 2.

## Previously Reported Gaps Now Resolved

### Omission and completeness measurement

Resolved by PRD SM-3A and addendum §3.2. The user records expected material items before reviewing proposals; initial-set completeness is measured separately from correctness; manual repair remains an omission; critical omissions are defined; minimum evidence volume and an 85% threshold are explicit; and a governing-state or re-entry-critical omission forces `rethink` regardless of aggregate percentage.

### Observed incumbent baseline

Resolved by PRD SM-2 and addendum §3.1. At least one feasible incumbent-only Qualifying Return across the validation set uses the same timing rules and records sources reopened, reconstruction, and uncertainty. A hypothetical comparison is labeled separately and is not treated as equivalent evidence.

### Persistent-state removal and verified deletion

Resolved by FR-17. Artifact removal is an accepted, inspectable state transition; permanent Project deletion removes ProjectOS-managed Project history, Source Material, Conversations, validation records, and bindings; export is offered first; and local deletion truthfully distinguishes user-managed runtimes/models, MLX data, Keychain credentials, backups, exports, and independent external retention.

### Adapter targets versus supported combinations

Resolved by the `Qualified Adapter Combination` glossary term, FR-14 readiness consequences, and the addendum's target-status clarification. Ollama, LM Studio, MLX, and OpenRouter are scope targets; adapter identity, discovery, installation, model presence, or fake-contract success cannot mark a production combination Ready or Supported. Readiness is evidence-bound to the recorded runtime/model/hardware/configuration combination and known degradations.

### Provider setup burden

Resolved by SM-C4 and addendum §3.5. Setup time, waiting time, attempts, assistance, failures, undocumented edits, abandonment, and final readiness are recorded per combination. One local combination must reach Ready within the assumed 30-active-minute bound before the continuity experiment starts; OpenRouter and deterministic fakes cannot satisfy that gate.

### Pasted-text and file scope

Corrected: the first validation slice supports explicitly selected **pasted text**, not general file import. FR-2 retains a visible source label and provenance identity, excludes unrelated-data scanning and bulk provider-history reconstruction, and explicitly defers local-file selection and parsing. PRD Open Question 5 revisits file formats only after the pasted-text continuity loop works. This is a deliberate experiment cut, not an unacknowledged gap, although it narrows how representative real source intake can be in the first slice.

### Provider breadth and sequencing

Resolved by PRD §7.1 and addendum §5.1/§8. The continuity experiment can begin with one qualified local combination after the provider-free foundation and minimum re-entry/measurement surfaces are usable. All four approved targets remain required for complete provider-scope readiness. Adapter breadth cannot postpone a negative thesis decision, and the rejected Codex spike remains historical and non-authorizing.

## Intentionally Deferred, Not Residual Gaps

| Market-research recommendation or risk | Current reconciliation |
| --- | --- |
| Recruit a broader cohort, emphasize active renovators, run price-bearing asks, and follow with a private beta | Superseded for this PRD by the approved personal/solo validation build. The package avoids generalizable demand claims and retains cross-domain positioning. |
| Validate $39.99 / $59.99 / $79.99, trial mechanics, purchase conversion, App Store packaging, refunds, reviews, and acquisition | Explicitly deferred until governed continuity is proven. The $59.99 working hypothesis remains supporting commercial context, not a validation-build success metric. |
| General local-file import, provider-account migration, integrations, and automatic history reconstruction | Intentionally narrowed to user-selected pasted text in the first slice. Broader input and migration remain later product questions. |
| Mobile capture, hosted sync, sharing, collaboration, professional participation, and portfolio-scale coordination | Outside the single-owner Mac validation boundary. |
| Additional Artifact types such as Requirements, Risks, Files, Notes, Photos, Purchases, and Measurements | Explicitly excluded to keep the experiment focused on governed continuity using Topics, Research, Decisions, Open Questions, and Tasks. |
| Hero imagery, price-bearing onboarding, commercial activation, and full visual identity | Explicit post-validation deferrals, not rejected directions. |
| Additional providers beyond Ollama, LM Studio, MLX, and OpenRouter; commercial-scale compatibility and support operations | Deferred beyond the approved validation targets. Current target status is not presented as support without qualification evidence. |

## Material Research Preserved Correctly

- The opportunity remains **problem-supported and solution-unvalidated**; the package authorizes focused learning, not a broad platform or commercial claim.
- The incumbent is the user's familiar bundle of AI chat, notes, files, tasks, email, spreadsheets, and memory, and the validation includes an observed-baseline method rather than relying only on a blank control or hindsight.
- Differentiation remains governed semantic continuity: selected Source Material or Conversation → typed Change Proposal → explicit accept/edit/reject → versioned Canonical State → current-state-first re-entry → explained Next Action.
- Accuracy and completeness are measured separately; critical omissions, provenance failures, silent state corruption, correction burden, and misleading re-entry have explicit rethink or stop consequences.
- Local ownership is backed by bounded transmission, no ProjectOS-hosted content backend, explicit external processing, Keychain-backed secrets, human-inspectable export, verified recovery, and truthful deletion semantics.
- Local-AI targets are separated from evidence-qualified support, setup burden is measured independently from first value, and neither OpenRouter nor a deterministic fake can satisfy the local experiment-start gate.
- Generic claims about “AI memory,” local storage, BYO AI, project containers, or an all-in-one workspace remain rejected as differentiators.

## Final Reconciliation Judgment

The updated PRD and addendum now absorb the market research's load-bearing experiment and trust constraints without expanding the personal validation build. Only two current decisions remain open: the acceptable ongoing maintenance burden before a Qualifying Return, and the optional OpenRouter model/cost/usage policy before external validation use. All earlier reconciliation claims that omission measurement, an observed baseline, deletion, setup measurement, or support qualification were absent are stale and removed.
