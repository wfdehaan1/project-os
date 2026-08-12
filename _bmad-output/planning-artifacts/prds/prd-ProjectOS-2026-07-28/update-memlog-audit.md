# ProjectOS PRD Update — Memlog Audit

**Audit date:** 2026-08-12  
**Workspace:** `prd-ProjectOS-2026-07-28`  
**Scope:** Line-by-line comparison of `.memlog.md` with the current `prd.md`, `addendum.md`, `validation-report.md`, and approved `sprint-change-proposal-2026-08-09.md`.

## Audit verdict

The original PRD decisions and validation mechanics mostly round-trip into the current PRD package. The July 31 Codex-first override and its implementation record are now historical and superseded by the approved August 9 local-first multi-runtime course correction. The material audit gap is that `.memlog.md` stops on July 31: it does not record the August 9 override, the resulting PRD/addendum reconciliation, the approved provider sequencing and qualification rule, or the August 11 validation rejection.

The update must preserve append-only history. Do not alter or delete lines 6–26; append recovery entries that explicitly supersede the Codex direction.

## Line-by-line disposition

| Memlog line | Type | Gist | Disposition | Evidence / audit note |
|---:|---|---|---|---|
| 6 | decision | Brief/addendum govern; market research supports; `ProjectWorkspace.md` excluded | Captured in PRD | PRD §0 states the authority and exclusion; addendum §1 repeats the ordered input authority. |
| 7 | decision | Personal/solo validation before broader investment | Captured in PRD | PRD §§0–2 and §8 define the personal validation build and investment gate; addendum §2 explains the narrowed commitment boundary. |
| 8 | decision | Use Fast path and tag inferences | Superseded/set aside | Workflow-only drafting-mode choice. Its durable consequence remains in PRD §0 and §10, but the mode itself does not belong in the product artifact. |
| 9 | event | Completed source extraction and competitive refresh | Captured in addendum | Addendum §1 records the governing/source inputs and focused 2026-07-28 refresh; §4 preserves the extracted market constraints and comparables. |
| 10 | decision | One or two projects, four to six weeks, seven-day return, meaningful work within five minutes | Captured in PRD | PRD §2.1, UJ-3, §7.1, §8, and SM-1 carry each element. |
| 11 | decision | OpenAI first; defer Ollama and commercial/diagnostic/polish scope | Superseded/set aside | The provider clause was first superseded by line 23 and then by the approved 2026-08-09 course correction. The non-provider deferrals remain captured in PRD §7.2 and addendum §§6–7. |
| 12 | assumption | Three Qualifying Returns are enough for the personal gate | Captured in PRD | PRD SM-1 and §10 contain the inline assumption and index entry; addendum §2 explains its non-generalizable interpretation. |
| 13 | assumption | Seventy-percent useful Next Actions justify further investment | Captured in PRD | PRD SM-4 and §10 round-trip the assumption, owner, and revisit point. |
| 14 | event | First memlog audit found all content captured | Superseded/set aside | Historical workflow event. It was accurate for the then-current draft, but later lines and the unlogged August course correction mean it is not the current audit conclusion. |
| 15 | change | Reconciliation restored delegated-research loss, outcome-based Next Actions, omission measurement, baseline, deletion, provider cost, and commercial deferrals | Captured in PRD | PRD §§1, 4.4, 4.6, 7.2, and 8 plus addendum §§3 and 6 preserve these changes. |
| 16 | change | Narrow first Source Material slice to pasted text | Captured in PRD | PRD FR-2 excludes local-file parsing from the first slice; §9.2 question 5 defers file-format expansion. |
| 17 | event | Earlier reviewer gate had no critical/high findings | Superseded/set aside | Superseded by `validation-report.md`, which grades the current package Poor and rejects it until the addendum authority contradiction is removed. |
| 18 | decision | Open items non-blocking; maintenance threshold owned by Wouter | Captured in PRD | PRD §9 assigns owners/revisit points and question 3 carries the maintenance-burden decision. The historical blanket “non-blocking” verdict is no longer current because the August 11 validation found a separate phase blocker. |
| 19 | change | Both assumptions triaged with owner and revisit points | Captured in PRD | PRD SM-1, SM-4, and §10 contain both owners and revisit conditions. |
| 20 | event | Structural review completed | Superseded/set aside | Historical workflow evidence; no product requirement was introduced. Current validation supersedes this review as the active readiness assessment. |
| 21 | change | Prose review applied three clarity fixes | Superseded/set aside | Historical editorial event; its result is embodied in the PRD, but the event itself does not need a product-artifact representation. |
| 22 | event | PRD finalized | Captured in PRD | PRD frontmatter remains `status: final`; its current `updated` date is 2026-08-09. The August 11 report nevertheless rejects the package as a readiness input. |
| 23 | override | Replace OpenAI API access with Codex App Server and ChatGPT-plan access | Superseded/set aside | Explicitly superseded by the approved sprint change: local inference is default; Ollama, LM Studio, and MLX are local targets; OpenRouter is the sole optional external target; Codex is excluded. PRD §7.2 and addendum §§1 and 5 reflect the replacement. |
| 24 | decision | Provider-neutral boundary with Codex as initial adapter | Superseded/set aside | Provider-neutrality remains captured in PRD FR-18/NFR-13 and addendum §5.2. “Codex is the initial adapter” is superseded by the August 9 decision and Story 1.9 `reject`. |
| 25 | change | Applied Codex-specific provider-neutral requirements | Superseded/set aside | The current PRD/provider sections have been rewritten for Ollama, LM Studio, MLX, and OpenRouter. This line remains valid only as history of the July 31 revision. |
| 26 | event | July 31 terminology and whitespace checks passed | Superseded/set aside | Historical validation of the superseded Codex direction. Addendum §1 marks its reconciliation historical; the August 11 validation is current. |

### Disposition totals

- Captured in PRD: 10
- Captured in addendum: 1
- Superseded/set aside: 10
- Missing among existing lines: 0

“Missing” applies instead to post-July-31 decisions and events that never received memlog entries; those are listed next.

## Required append-only recovery entries

These four entries are already supported by approved/current artifacts and can be appended without reopening the product decision. Use the shared memlog script; do not hand-edit `.memlog.md`.

| Order | Type | Exact one-line text |
|---:|---|---|
| 1 | override | `The approved 2026-08-09 course correction supersedes the Codex-first direction in prior memlog entries: local inference is the default MVP category, Ollama, LM Studio, and MLX are first-class local adapter targets, OpenRouter is the only optional external adapter, and direct OpenAI, Anthropic, and Codex production integrations are excluded because Story 1.9 ended in reject.` |
| 2 | decision | `Preserve all four approved MVP adapter targets, but let provider-free Epic 2 establish the trusted local foundation before Epic 3 implements and qualifies the provider stack; each adapter/runtime/model combination must pass recorded compatibility, resource, quality, schema, boundary, and failure criteria before it is represented as supported, and no new provider spike or silent fallback is permitted.` |
| 3 | change | `Reconciled the PRD and addendum on 2026-08-09 for the local-first multi-runtime direction, including provider eligibility, FR-14 through FR-18, NFR-8 through NFR-13, scope, privacy, deletion, Context Preview, capability negotiation, qualification questions, and historical Codex status.` |
| 4 | event | `The 2026-08-11 PRD validation gate rejected the package as a readiness input because addendum section 8 still re-authorizes the superseded Codex production path; the PRD body otherwise remained substantive and well shaped, with additional bounded findings on provider cut lines, adapter qualification, completeness-gate semantics, setup burden, usability bounds, and deferred adapter wording.` |

## Update and open-item triage

### Source-authorized update work

These items do not need a new product choice because the approved sprint change already determines the answer.

| Item | Triage | Required treatment | Append after the edit |
|---|---|---|---|
| Addendum §8 directs Codex architecture and Codex-first implementation | Phase blocker; autofix from approved authority | Replace the Codex handoff with the approved sequence: Epic 2 proceeds without an operational provider; Epic 3 implements the shared contract and Ollama/LM Studio/MLX plus optional OpenRouter; Codex evidence remains historical and non-authorizing. | **change** — `Reconciled addendum section 8 with the approved provider direction: Epic 2 is provider-free, Epic 3 implements and qualifies Ollama, LM Studio, MLX, and optional OpenRouter through the shared contract, and Codex spike evidence remains historical and non-authorizing.` |
| PRD calls all four adapters “supported” before combinations are qualified | High; autofix from approved authority | Describe them as committed MVP adapter targets until runtime/model combinations pass the proposal's recorded acceptance criteria; reserve “supported” and “ready” for qualified combinations. | **change** — `Changed unqualified provider support claims to committed MVP adapter targets and reserved supported or ready status for adapter/runtime/model combinations that pass the approved compatibility, resource, quality, schema, boundary, and failure criteria.` |
| Addendum §6 says multiple cloud/local adapters are deferred | Medium; autofix from approved authority | Defer only adapters beyond Ollama, LM Studio, MLX, and OpenRouter, plus later commercial hardening; do not imply that the approved four-adapter MVP is deferred. | **change** — `Clarified the commercial deferral so it applies only to adapters beyond Ollama, LM Studio, MLX, and OpenRouter and to later commercial hardening, not to the approved four-adapter MVP scope.` |

### Owner decisions required before appending

The following reviewer findings are not fully decided by the existing source authority. Do not append these candidate entries until Wouter confirms the underlying choice.

| Item | Triage | Owner / resolution point | Candidate exact entry after approval |
|---|---|---|---|
| SM-3A has no continue/rethink/stop semantics | High; phase-blocking for a trustworthy validation gate | Wouter; resolve before the validation window begins | **decision** — `A material omission that would impair current-state understanding or a later Qualifying Return prevents a Continue decision and triggers Rethink even when SM-3 correctness passes; non-impairing omissions remain recorded as qualitative evidence.` |
| Provider/model setup burden is excluded from SM-0 | Medium; non-blocking only if separately measured | Wouter; resolve before the first real adapter setup used for validation | **decision** — `Keep SM-0 limited to time from Project creation to First Useful State, and add a separate provider-setup readiness counter-metric recording elapsed time, outside assistance, failures, retries, and abandonment because local-first setup burden must remain visible.` |
| NFR-10 through NFR-12 lack performance/content acceptance bounds | Medium; may be deferred with an explicit owner | Wouter/builder; resolve before downstream acceptance criteria are finalized | **decision** — `Defer concrete local-read responsiveness bounds and product-language review heuristics to UX and architecture, owned by the builder and due before implementation acceptance criteria are finalized; the PRD retains offline availability and calm, honest, inspectable language as governing outcomes.` |

## Audit conclusion

After the four recovery entries are appended, the memlog will truthfully record the governing August course correction and current reject verdict. The PRD update can then apply the three source-authorized fixes and append their change records. Finalization remains blocked until the stale Codex handoff is removed and Wouter resolves SM-3A gate semantics; the two medium findings may be resolved now or explicitly deferred with owner and revisit conditions.
