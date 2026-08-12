# PRD Update Source Extract and Edit Map

## 1. Governing authority for this update

Apply sources by role rather than treating every file as equal:

1. The current product brief and brief addendum remain product-definition authority for the broader product.
2. The approved `sprint-change-proposal-2026-08-09.md` governs the provider course correction and its delivery sequence wherever an older artifact conflicts.
3. The updated PRD body governs the personal/solo validation experiment and its product requirements.
4. The current `ARCHITECTURE-SPINE.md` governs implementation invariants for the replacement provider boundary. It explicitly supersedes the Codex production direction.
5. `epics.md` governs allocation and sequencing of delivery scope: Epic 2 is provider-free; production provider work belongs to Epic 3.
6. `sprint-status.yaml` reports implementation state only. It confirms Epic 1 and Story 1.9 are `done`; it does not authorize a provider or create Story 2.1.
7. Story 1.x, the Codex spike, harness, and retained evidence are historical proof of a rejected path. Their provider-neutral invariants have authority only where re-adopted in the current architecture spine.

`docs/ProjectWorkspace.md` remains superseded and excluded.

## 2. Exact delivery sequence to preserve

1. Reconcile this PRD package, append the missing course-correction decisions to `.memlog.md`, refresh stale reconciliation conclusions, and revalidate the package.
2. Only after the critical PRD/addendum contradiction is removed and revalidation no longer rejects the package, decompose Epic 2 and create Story 2.1.
3. Story 2.1 is the first provider-free Epic 2 story. Its detailed scope is not yet authored and must be generated from the reconciled PRD, architecture, UX, and Epic 2 contract. It must not require a configured inference adapter, revive Codex work, or introduce production provider setup.
4. Epic 2 may begin under the replacement architecture without Ollama, LM Studio, MLX, or OpenRouter. It establishes local persistence, Projects, selected Source Material, typed Artifacts and relationships, accepted Rationale/Provenance, versions, correction/undo, and the local UI/accessibility foundation.
5. Decompose Epic 3 only after Epic 2 has been decomposed and its local-state contracts and early learning are available. Epic 2 need not be wholly complete before Epic 3 story design, but provider stories must consume—not redefine—its Project, Conversation, proposal, and Canonical State boundaries.
6. Epic 3 owns the provider registry/job coordinator, adapter/model setup, Context Preview, generation, structured proposal validation, proposal review, and the four target adapters. This is production implementation with contract and integration acceptance tests, not another authorization or feasibility spike.
7. Epic 4 supplies the re-entry and outcome-recording portion of the closed experiment loop. Epic 5 supplies the export/restore/deletion gates required to complete the PRD validation, but does not have to block the first experimental session.

Tracker consequence: leave `sprint-status.yaml` unchanged during this PRD update. When Story 2.1 is actually created, add `epic-2: in-progress` and its generated `2-1-...: ready-for-dev` entry through the story workflow.

## 3. Minimum gate for the continuity experiment

The four adapter names are **committed MVP adapter targets**, not four prerequisites for beginning the semantic-continuity experiment and not presently supported combinations.

The first real validation window may begin only when one closed path exists:

- the required Epic 2 local Project and governed-state foundation is usable;
- one explicitly selected **local** adapter/runtime/model combination has passed recorded compatibility, resource, generation-only boundary, ProjectOS-schema, quality/completeness, cancellation, and failure tests;
- project-grounded Conversation can produce a pending Change Proposal, explicit review can create accepted Canonical State, and AI cannot mutate Canonical State directly;
- the minimum Epic 4 Re-entry View and Return Outcome Record needed for a Qualifying Return are usable; and
- the validation projects and maintenance-burden rule have been selected before their stated revisit points.

A deterministic fake may prove contract shape but cannot qualify the real experiment. OpenRouter is optional and must never gate a local-first experiment. The other local adapters may be qualified after the first window starts. If adapter breadth threatens the four-to-six-week continuity test, pause additional adapter work rather than delaying the experiment.

Before any individual combination is called `supported` or `ready`, it must pass the same recorded readiness criteria. Before the broader four-adapter MVP can be called ready, all four targets must pass their applicable shared contract and targeted integration gates. Completion of the PRD validation still requires its integrity and recoverability gates, including export/restore; beginning the window does not waive them.

## 4. PRD edit map

### `prd.md`

| Target | Required edit |
|---|---|
| Frontmatter | Set `updated` to the actual update date after the update is approved and applied. Preserve `status: final` only after revalidation succeeds; use draft/update-in-progress semantics while unresolved if the workflow requires an intermediate state. |
| §0 Document Purpose | Add the approved Sprint Change Proposal as the provider-course-correction authority and distinguish current architecture/epics as downstream implementation authorities. |
| §2.3 Non-Users | Replace language that assumes a “supported local model” already exists with eligibility based on a subsequently qualified adapter/runtime/model combination. |
| §3 `AI Provider Adapter` and local-runtime definitions | Replace “supports” with “committed target” or “may be represented as supported only after qualification.” Keep all four target names and current locality boundaries. |
| §4.5 description and FR-14 | Rename/reword configuration as configuration **and qualification** of target combinations. Add a consequence that adapter identity or deterministic fakes cannot confer readiness; compatibility, resources, schema, quality/completeness, boundary, cancellation, and failure criteria must be recorded for the exact adapter/runtime/model/configuration before `supported` or `ready` is shown. |
| §4.7 FR-18 | Preserve the provider-neutral contract. Clarify that shared fake-contract proof is necessary but insufficient for production-adapter readiness. |
| §5.4 NFR-10–NFR-12 | Add observable validation bounds for local read responsiveness and a compact acceptance heuristic for calm/concise/honest copy. No numeric latency bound exists in the sources; the owner must approve one rather than have the update invent it. |
| §7.1 In Scope | Call Ollama, LM Studio, MLX, and OpenRouter committed MVP targets until qualified. Add the one-qualified-local-path experiment cut line and state that the remaining targets do not block the first validation window. |
| §8.1 after SM-0 | Add a separate adapter/model setup counter-metric: elapsed setup time, assistance, failures/retries, and abandonment, recorded per combination. Keep SM-0 focused on the continuity loop. Builder-oriented setup may be recorded separately but cannot support a commercial activation claim. |
| §8.1 SM-3A | Give omissions gate semantics. A consequential omission that changes governing state, dependency effects, or re-entry meaning blocks the next Qualifying Return until corrected and triggers rethink; repeated non-severe omissions that impair understanding also trigger rethink. Continue requires no unresolved severe omission and no repeated impairing omission. |
| §8.4 Continue/Rethink/Stop | State the start cut line separately from the final product gate: one qualified local path can start the experiment; four-adapter qualification is a broader MVP readiness obligation. Make SM-3A an explicit qualifier/override to the “SM-0 through SM-4” continue rule. |
| §9 Open Questions | Preserve existing owner decisions. Clarify that local compatibility/quality and OpenRouter policy are readiness decisions for their respective combinations, not blockers for Story 2.1. Add/assign the local-read latency and copy-review acceptance bounds if they are not resolved directly. |
| §10 Assumptions Index | Keep the three-return and 70% assumptions. Add any owner-approved interim readiness or usability bounds only if they remain assumptions after discussion. |

### `addendum.md`

| Target | Required edit |
|---|---|
| §2 Validation Interpretation | Replace the duplicated three-return assumption with a cross-reference to PRD SM-1/§10. Add the start-versus-completion distinction for the continuity window. |
| §4 Market-Derived Constraints | Preserve setup and maintenance burden as separate risks; link setup burden to the new adapter/model counter-metric. |
| §5.1 Validation Build | Call the four adapters committed targets until their exact combinations qualify. State that one qualified local path is sufficient to begin the continuity experiment and that OpenRouter is not a prerequisite. |
| §6 Deferred Commercial MVP Decisions | Replace “support for multiple cloud and local AI adapters” with “additional adapters beyond Ollama, LM Studio, MLX, and OpenRouter, plus commercial hardening beyond the validation criteria.” |
| §8 Architecture | Remove “The current Codex mechanism is specified...” Replace it with the current architecture spine as the replacement authority. Mark Codex architecture/spike/Story 1.x as rejected historical evidence and non-authorizing except for invariants explicitly adopted by the current spine. |
| §8 Epics and Implementation | Delete the fake -> Codex -> continuity sequence. Insert the exact sequence in §2 of this extract: provider-free Epic 2/Story 2.1 first; Epic 3 production adapter work after Epic 2 decomposition/learning; one qualified local path starts the continuity experiment; no new spike; remaining adapter targets qualify independently. |

### `.memlog.md`

Do not rewrite existing entries. Append through `memlog.py`, in order:

1. `override` — approved 2026-08-09 replacement of the rejected Codex production path with Ollama, LM Studio, and MLX as local targets plus optional OpenRouter; cite the reject and approved proposal in the gist.
2. `decision` — Epic 2 and Story 2.1 are provider-free; Epic 3 owns production adapters; no new provider authorization spike.
3. `decision` — one qualified local adapter/runtime/model path is sufficient to begin the continuity experiment; all four remain MVP targets and require individual readiness evidence before being called supported.
4. `change` — PRD/addendum and reconciliation refresh applied, including SM-3A semantics and setup-burden evidence.
5. `event` — append the revalidation outcome only after it actually completes.

## 5. Stale reconciliation claims to refresh

### `reconcile-market-research.md`

- Lines 12–20 claim omission measurement is absent. Current SM-3A and addendum §3.2 already add the measurement. Replace the finding with the remaining issue: SM-3A lacks decision-gate semantics.
- Lines 22–30 claim no observed incumbent baseline exists. Current SM-2 and addendum §3.1 already require at least one observed baseline where feasible and distinguish hypothetical evidence. Mark this reconciled.
- Lines 32–40 claim Project/Artifact deletion is absent. Current FR-17 specifies Artifact removal, permanent local Project deletion, retention boundaries, and capability-aware provider cleanup. Mark this reconciled.
- Lines 42–50 remain materially current for OpenRouter: billing disclosure exists, but model policy, usage visibility, and the spending ceiling remain open. Extend it to distinguish setup burden from usage cost.
- Line 58 overstates all four adapters as already in validation support. Change to committed MVP targets whose combinations require readiness evidence.
- Line 62 says paste/file input is present. The validation slice supports pasted text only; file formats are intentionally post-core-validation.
- Line 72 says low setup and maintenance burden are measured. Maintenance is recorded, but initial runtime/model/OpenRouter setup is excluded from SM-0 and currently unmeasured. Refresh after adding the setup counter-metric.
- Lines 77–79 still conclude there are four gaps. Replace with the current residual set after edits: SM-3A gate semantics, setup burden, and unresolved OpenRouter cost visibility; baseline and deletion are closed.

### `reconcile-product-brief.md`

- Line 16 says there are no unresolved scope conflicts. Until addendum §§6 and 8 are fixed, that is false. After the fix, state that the provider sequence conflict was reconciled by the 2026-08-09 proposal and this update.
- Line 19 describes provider variance as already managed. Rephrase all four as committed targets awaiting combination-specific qualification.
- Lines 41–47 say delegated-research memory loss dropped out of the product story. Current PRD §1 explicitly explains that delegated findings/reasoning may remain trapped and make re-entry harder. Mark the mechanism covered; retain “restore comprehension, not merely retrieve facts” as a UX handoff emphasis if desired.
- Lines 57–63 say commercial onboarding is only partially preserved even while acknowledging the addendum preserves it. Refresh this to the actual residual: launch intent is preserved, while validation lacks a setup-burden measure and OpenRouter usage/cost evidence remains unresolved.
- Line 71 groups selected-file input with pasted text as covered. Clarify the intentional override: pasted text is the validation input; dropped/parsed files are deferred.
- Lines 82–84 still say all five gaps need finalization. Recount after refresh. Successful-resolution evidence, recommendation-to-outcome linkage, and richer deferred project-atmosphere intent remain valid preservation items; delegated-research rationale is covered and onboarding requires narrower measurement clarification.

### `reconcile-codex-subscription-access-2026-07-31.md`

Keep the file historical, but remove present-tense ambiguity:

- Lines 13–35 should be labeled explicitly “historical 2026-07-31 change signal/evidence/reconciliation,” not current direction.
- Line 44 (“Local models remain an intended future provider category”) is historical only; current authority makes three local adapters committed MVP targets.
- Lines 46–48 incorrectly say this reconciliation governs conflicts. Replace that with the approved Sprint Change Proposal, current PRD, and current architecture spine as governing; the three older reconciliation/review files are historical inputs to refresh.
- Lines 50–52 call Codex gates remaining. The spike is complete with `reject`. Replace with the recorded four failed/unproven gates and state that they permanently block production Codex work but do not gate the explicitly authorized replacement path.

## 6. Validation and handoff checks after update

- No current PRD/addendum handoff authorizes Codex, direct OpenAI, or direct Anthropic production work.
- Current provider language distinguishes `target`, `qualified combination`, and `supported/ready`.
- Epic 2 and Story 2.1 are explicitly provider-free; Epic 3 owns all production adapter work.
- One qualified local path starts the continuity window; OpenRouter and the remaining local targets do not block it.
- SM-3A has explicit override semantics; setup burden is recorded separately from SM-0.
- `.memlog.md` contains the 2026-08-09 override and current sequencing decisions.
- Reconciliation conclusions match current PRD/addendum content and no longer report baseline/deletion/omission measurement as absent.
- Re-run the PRD reviewer gate. Only after a non-reject verdict should Story 2.1 be generated.
