# PRD Quality Review — ProjectOS Validation Build

## Overall verdict

This is a focused, unusually coherent solo-validation PRD: it states a falsifiable continuity thesis, preserves user control as the product invariant, names what the validation build gives up, and ties the core capabilities to practical success and stop criteria. It is ready to feed downstream work after a small finalization pass; the remaining risk is not strategic sprawl but a handful of product-semantic boundaries and validation rules that UX, architecture, or stories could otherwise interpret differently.

## Decision-readiness — adequate

The PRD makes consequential choices explicit. It chooses a personal validation build before a commercial MVP (§0), governed state rather than autonomous mutation (§1 and FR-4–FR-6), OpenAI-only rather than provider breadth (§7.2), and a local-only canonical store rather than hosted convenience (FR-14–FR-16). The “Continue, Rethink, or Stop” gate (§8.4) also acknowledges failure states instead of presenting validation as a ceremonial step.

The one weak point is that the most important counterweight to the positive metrics—maintenance burden—has no repeatable interpretation. The addendum explicitly says “No fixed threshold is set” (§3.3), while the PRD relies on “repeated perception” and “disproportionate manual work” (SM-C1 and §8.4). Subjective judgment is appropriate for a solo test, but without a decision convention the builder can rationalize the same observations either way.

### Findings

- **medium** Make the maintenance-burden gate repeatable (§8.3 SM-C1; §8.4; addendum §3.3) — “Repeated perception” and “disproportionate manual work” do not say how the recorded review/correction time changes a continue/rethink/stop decision. *Fix:* define a lightweight decision convention using the already-recorded review/correction time and qualitative comparison—for example, when maintenance burden is considered recurring and which gate it overrides—without pretending the personal sample is statistically precise.

## Substance over theater — strong

The content is earned by the experiment. The single named user changes scope; the four compact journeys exercise materially different contracts; the differentiation claim explicitly rejects generic “memory,” local storage, and BYO AI (§1); and the NFRs are tailored to canonical-state integrity, provenance, provider boundaries, and recoverability rather than copied scalability furniture. The addendum carries market context and deferred commercial detail without bloating the requirements document.

## Strategic coherence — strong

The thesis in §1—“governed semantic continuity”—drives the full capability arc: selected input, proposed state, explicit review, versioned canonical state, re-entry, and explained continuation. The metrics measure that arc rather than generic activity: first useful state, time to meaningful work, material correctness, useful guidance, integrity, and recovery (§8). SM-C1 through SM-C3 explicitly protect against optimizing artifact volume, engagement, or blind acceptance, and the out-of-scope provider and commercialization work keeps the validation build from becoming a disguised launch MVP.

## Done-ness clarity — adequate

The “Consequences (testable)” pattern gives every FR at least one observable result, and the integrity requirements are especially crisp: accepted transitions are atomic, silent replacement is forbidden, and export failure leaves the source unchanged. That is substantially stronger than a typical early PRD. Three remaining boundaries are product semantics rather than implementation choices, so leaving them open would cause downstream artifacts to define different versions of “done.”

### Findings

- **medium** Bound the validation import surface (§4.1 FR-2; §9 question 3) — FR-2 promises “supported local files,” but no minimum validation set is named, leaving the first implementation slice and its acceptance tests indeterminate. *Fix:* select the smallest required file-format set for this cycle, or explicitly scope FR-2 to paste-only for the first vertical slice and make file import a named later checkpoint.
- **medium** Define the minimum decision and relationship semantics (§4.2 FR-6; §4.3 FR-7–FR-8) — “resolved subject,” “meaningful relationships,” and “consequential Artifacts and state transitions” determine whether the system can enforce exactly one Governing Decision, yet none has a validation-build boundary. *Fix:* state the minimum semantic rules the product must expose—how a replacement identifies the decision it supersedes, which relationship intents must exist, and which accepted changes require Rationale—while leaving storage representation to architecture.
- **medium** Make Re-entry View selection observable (§4.4 FR-11; §5.4 NFR-11) — “recent accepted Research,” “material state changes,” and evidence “without overwhelming the primary workflow” allow materially different implementations to pass. *Fix:* define a minimum default content rule for a Qualifying Return, such as current governing/unresolved state plus accepted changes since the last visit, and treat additional ranking or condensation as UX discretion.

## Scope honesty — adequate

Scope is unusually candid for a validation PRD. §6 and §7.2 explicitly exclude commercial proof, collaboration, platform breadth, hosted services, autonomous actions, broader artifact types, and visual polish. The two inferred thresholds are tagged inline and round-trip through §10, while the addendum preserves rather than smuggles broader product decisions into the build.

The open-question list is honest but not triaged. Questions 1–4 affect validation setup, architecture, implementation, or measurement; questions 5–6 belong after core validation. As written, a downstream reader cannot tell which must be answered before starting, which may be resolved by a spike, and which are deliberately deferred.

### Findings

- **medium** Classify the open questions by decision horizon (§9) — “Which one or two real Projects,” model/cost, file formats, and material-fact evidence sit beside post-validation Ollama and naming questions with no owner or revisit condition. *Fix:* resolve any phase-blockers now; for the rest, record an owner and a concrete revisit trigger such as before architecture sign-off, before the first vertical slice, or after the validation gate.

## Downstream usability — adequate

The document is source-extractable: FR, UJ, NFR, and SM identifiers are unique; journeys have a named protagonist; capability descriptions map journeys to requirements; metrics cite the FRs they validate; and the glossary defines the governing nouns used across UX and architecture. The addendum then gives each downstream discipline a concise handoff without selecting storage or adapter mechanisms for it.

The only notable terminology ambiguity is the provenance-source model. “Source Material” includes “Conversation content” (§3), while Provenance and FR-8 repeatedly distinguish “Conversation or Source Material.” This is minor in prose but can split the architecture and UX into incompatible source taxonomies.

### Findings

- **low** Resolve Conversation versus Source Material taxonomy (§3 Glossary; FR-4 and FR-8) — Source Material is defined to include “Conversation content,” but requirements also use “Conversation or Source Material” as mutually distinct inputs. *Fix:* either define Conversation as a distinct Provenance source alongside imported Source Material, or state clearly that Conversation content is a subtype and use that hierarchy consistently.

## Shape fit — strong

The shape fits both the stakes and the handoff role. It is more rigorous than a hobby note because it feeds UX, architecture, epics, and implementation, but it avoids launch-grade persona, acquisition, pricing, compliance, and operations sections that would be theater for a solo experiment. Four brief journeys are justified because proposal review, supersession, re-entry, and recovery are distinct experience contracts; the addendum absorbs evidence, mechanisms, and deferred commercial context that do not belong in the PRD spine.

## Mechanical notes

- FR-1 through FR-16, UJ-1 through UJ-4, and NFR-1 through NFR-12 are contiguous and unique. SM-0 through SM-6 plus SM-C1 through SM-C3 are unique and use an understandable counter-metric namespace.
- All explicit PRD cross-references resolve. Capability-to-UJ references and metric-to-FR/NFR references are internally consistent.
- Both inline PRD assumptions round-trip through §10. The addendum repeats the three-return assumption using the standalone tag form `` `[ASSUMPTION]` `` without a separate addendum location in the index; this is harmless duplication but worth normalizing during polish.
- Every UJ has the named protagonist Wouter and carries the relevant context inline.
- The required sections fit a solo validation build that is intended to feed downstream definition work. Frontmatter remains `status: draft`, which is expected until the Finalize close step.
