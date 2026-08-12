# PRD Validation Orientation

## Validation posture and stakes

This is a critique-only validation of the current working-tree PRD authority, not a request to revise it. The PRD is deliberately a **personal, solo validation build** for Wouter: one owner, one or two consequential projects, four to six weeks, and a minimum of three returns after at least seven days away. Its decision is whether governed semantic continuity makes re-entry materially easier before further product investment. It is not launch-grade proof of switching, willingness to pay, general market demand, or repeat-project economics.

The approved 2026-08-09 course correction materially increases implementation scope without changing that validation thesis: Ollama, LM Studio, and MLX are first-class local adapters; OpenRouter is the sole optional external adapter; direct Codex, OpenAI, and Anthropic production paths are excluded; and no further provider feasibility spike is authorized.

## Governing inputs and authority

Use these inputs in this order:

1. The current working-tree [product brief](../../briefs/brief-ProjectOS-2026-07-27/brief.md) and [brief addendum](../../briefs/brief-ProjectOS-2026-07-27/addendum.md), both updated 2026-08-09, for the product definition and broader commercial-MVP direction.
2. The approved [2026-08-09 Sprint Change Proposal](../../sprint-change-proposal-2026-08-09.md) wherever provider direction or post-reject sequencing is at issue.
3. The PRD run's [.memlog.md](.memlog.md) for decisions made during the original PRD run, subject to the audit-trail caveat below.
4. The [market-opportunity research](../../research/market-projectos-market-opportunity-research-2026-07-27.md) as supporting evidence, not product authority.
5. Existing reconciliation files as historical analysis aids, not as self-proving current validation results.

`docs/ProjectWorkspace.md` is superseded and must not be used as a PRD input.

## Key decisions the PRD is meant to preserve

- The differentiating contract is: selected Source Material or Conversation -> typed Change Proposal -> explicit accept/edit/reject -> versioned Canonical State -> current-state-first re-entry -> explained Next Action.
- Conversation is working context and provenance, never project authority. Governing and Superseded Decisions, accepted rationale, provenance, relationships, and version history remain inspectable.
- Canonical project data stays on the Mac; ProjectOS has no hosted project-content backend. Export/restore and deliberate deletion are trust gates.
- The provider boundary is ProjectOS-owned and capability-oriented. Adapter/model selection is explicit, local versus external execution is disclosed, and silent fallback is prohibited.
- The validation experiment measures First Useful State, return to Meaningful Work within five minutes, understanding/trust, proposal correctness and omissions, useful guidance, maintenance burden, and zero severe state failure.
- Commercial distribution, pricing, payment, collaboration, sync, multi-surface access, broad artifact types, and visual identity remain post-validation deferrals, not rejected product directions.

## Unresolved assumptions and open items

Before the relevant validation step, the owner still must resolve:

- which one or two projects constitute the validation set;
- the supported Ollama, LM Studio, and MLX version/model/hardware compatibility and quality matrix;
- the maintenance-burden threshold that triggers rethink;
- supported OpenRouter models, usage visibility, and cost ceiling; and
- whether three Qualifying Returns and a 70% useful-Next-Action threshold are adequate personal investment gates.

File formats beyond pasted text and the final product name are explicitly post-core-validation questions.

## Authority conflicts, omissions, and validation cautions

1. **The PRD addendum retains operational Codex handoff text that conflicts with its own governing provider section.** Addendum section 8 says the "current Codex mechanism" is the architecture authority and instructs implementation to validate the Codex adapter end to end. The approved proposal and current PRD instead exclude Codex and require Ollama, LM Studio, MLX, and optional OpenRouter. Treat those two section-8 sentences as stale, not implementation authority.

2. **The canonical PRD audit trail does not record the 2026-08-09 course correction.** `.memlog.md` ends with the 2026-07-31 Codex override and validation event; it contains no local-first four-adapter override, no approval record, and no corresponding reconciliation event. This makes the memlog inconsistent with the updated `prd.md`, `addendum.md`, brief, and approved Sprint Change Proposal.

3. **The existing input-reconciliation files are partly stale and cannot be accepted as current findings verbatim.** `reconcile-market-research.md` still says omission measurement, an observed incumbent baseline, and deletion semantics are missing even though current PRD SM-3A, SM-2/addendum section 3.1, and FR-17 now cover them. `reconcile-product-brief.md` likewise describes several items as needing reconciliation even where the current PRD or addendum now preserves them, including delegated-research memory loss and provider-onboarding/cost intent. Cost visibility remains only partially resolved because the OpenRouter ceiling and evidence mechanism are still open.

4. **The personal validation override is coherent but must constrain claims.** The brief and market research call for concierge and price-bearing evidence before broad product investment; the PRD intentionally substitutes a solo product-thesis experiment. Passing this PRD can support a continue/rethink/stop decision on semantic continuity, but cannot validate switching, willingness to pay, a $59.99 price, or generalizable demand.

5. **The four-adapter scope lacks an explicit cross-adapter evidence gate.** SM-3 records correctness for the active adapter/model and the open questions defer compatibility/quality matrices to implementation, but the continue gate does not state which adapter/model combinations must satisfy correctness, completeness, and Next Action quality before all four can be represented as supported MVP adapters. The validation report should distinguish product-thesis evidence from adapter-specific release evidence.

Two deliberate source conflicts are already explained and should not be reported as defects: the validation slice narrows the brief's paste-or-drop import to pasted text, and it defers the brief's commercial/identity work. The broader directions remain preserved in the addendum.
