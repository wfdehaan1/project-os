---
title: Codex Subscription Access Reconciliation
status: historical-superseded-rejected
created: 2026-07-31
updated: 2026-08-12
superseded_by: _bmad-output/planning-artifacts/sprint-change-proposal-2026-08-09.md
---

# Codex Subscription Access Reconciliation

> **Historical rejected path — not current authority.** This document preserves the 2026-07-31 Codex subscription-access signal and evidence as decision history. Epic 1 later completed the Codex App Server path with `reject`. Nothing in this document authorizes production Codex work, weakens that rejection, or gates the separately approved local-first replacement path.

## Current authority

For current provider direction and downstream work, use these authorities:

1. The approved [2026-08-09 Sprint Change Proposal](../../sprint-change-proposal-2026-08-09.md) governs the provider course correction and makes the Codex rejection binding for the MVP.
2. The current [PRD](prd.md) and [PRD addendum](addendum.md) govern product requirements, qualification language, experiment-start criteria, metrics, scope, and deferrals.
3. The current [AI Provider Architecture Spine](../../architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md) governs production provider invariants and explicitly supersedes the Codex App Server production direction.

If this historical reconciliation conflicts with any current authority above, the current authority wins.

## Historical 2026-07-31 change signal

On 2026-07-31, the active proposal was to replace user-supplied OpenAI API-key setup with a first Codex App Server adapter using Codex-managed ChatGPT authentication, so eligible usage could follow the user's ChatGPT/Codex plan allowance. ProjectOS would retain a provider-independent capability boundary and provider-independent Canonical State.

That signal was a planning hypothesis, not proof that the production path was safe or authorized. The subsequent Epic 1 validation work was created to test the required Codex path and ended in `reject`.

## Historical 2026-07-31 evidence snapshot

The following evidence informed the July 31 hypothesis. It is preserved as a dated snapshot, not asserted as current product authority:

- [Codex authentication](https://developers.openai.com/codex/auth) described ChatGPT sign-in for subscription access separately from API-key sign-in for usage-based access.
- [Codex App Server](https://developers.openai.com/codex/app-server) described a product-integration surface with authentication, account and allowance state, streamed events, structured output, conversation lifecycle, and persisted-thread behavior.
- The documented managed ChatGPT mode suggested that Codex could own OAuth token persistence and refresh while an integrating application initiated browser sign-in and observed completion.
- Documented allowance responses suggested that UI copy should use reported usage windows and reset times rather than hard-code a weekly allowance model.

This evidence established that the proposed subscription-access mechanism was plausible enough to investigate. It did not prove live authentication, non-coding quality, preventive containment, or live provider-session cleanup, and it did not authorize production use.

## Final Codex gate decision

Epic 1 completed with a deterministic, evidence-bound `reject`. Four mandatory production gates failed or remained unproven:

| Stable gate result | What remained unproven or unavailable | Consequence |
|---|---|---|
| `live_auth_unproven` | Live Codex-managed ChatGPT authentication was not proven under the required credential-ownership, isolation, and evidence conditions. | Subscription authentication could not authorize production Codex use. |
| `live_quality_unproven` | Representative non-coding structured-output quality and completeness remained fake-backed rather than proven against an approved live Codex run. | Deterministic proposal/schema tests could not stand in for live product-quality evidence. |
| `containment_boundary_unavailable` | The required preventive execution-containment boundary was unavailable. | Live provider actions could not be run safely enough to obtain authorizing evidence. |
| `live_codex_cleanup_unproven` | Live Codex provider-session enumeration/deletion and crash-safe cleanup were not proven against an approved live contract. | Fake-backed cleanup behavior could not establish truthful provider-side deletion. |

Any failed mandatory gate reduces to `reject`. Passing protocol, allowance, conversation-ownership, provider-neutrality, deterministic fake, or audit-machinery checks does not offset one of these failures.

## Permanent production block

The `reject` is a permanent block on production Codex work within the current MVP and every downstream artifact governed by the current authority set:

- Do not implement, validate, enable, or represent Codex App Server, ChatGPT subscription access, direct OpenAI, or direct Anthropic as an MVP production adapter.
- Do not use deterministic fakes, historical protocol evidence, subscription-access documentation, or the retained harness to manufacture a later `proceed` decision.
- Do not add a Codex authorization spike, Codex-first vertical slice, or Codex-dependent story to the approved Epic 2–5 sequence.
- Preserve the harness, Story 1.x records, private/sanitized evidence, and spike contracts as historical rejected evidence only.
- Provider-neutral invariants learned during Epic 1 may be adopted by current architecture, but Codex process, authentication, protocol, containment, profile, and cleanup mechanics do not constrain replacement adapters.

Only a future explicit course correction outside the current MVP authority set could reconsider Codex. Historical evidence in this file cannot do so.

## Separately authorized replacement path

The approved 2026-08-09 course correction authorizes a different production path directly:

- local inference is the default MVP category;
- Ollama, LM Studio, and MLX are committed first-class local MVP adapter targets;
- OpenRouter is the sole optional external MVP target;
- direct OpenAI, Anthropic, and Codex production integrations are excluded;
- provider, runtime, and model selection are explicit, with no silent fallback;
- ProjectOS owns Canonical State, Conversations, Context Preview selection, Change Proposal schemas, and accepted-state mutation; and
- a specific adapter/runtime/model/hardware/configuration is represented as Ready only after its own recorded compatibility, capability, resource, quality, schema, boundary, cancellation, and failure evidence qualifies it.

This replacement path is not gated by the Codex rejection. It does not need the Codex gates to pass, does not inherit a requirement for another authorization spike, and does not claim that Codex was safe. Its adapters must satisfy the current PRD and architecture's implementation acceptance criteria on their own terms.

Epic 2 establishes the trusted local Project and Canonical State foundation without requiring a configured inference adapter. Epic 3 later implements the shared provider contract and qualifies the approved adapter targets. The governed-continuity experiment may begin at the current PRD §7.1 cut line with one Qualified Adapter Combination; completing the provider scope still requires the applicable evidence for all four targets.

## Historical conflict reconciliation

| 2026-07-31 conclusion | Current disposition |
|---|---|
| Codex-managed ChatGPT sign-in replaces user-supplied OpenAI API-key setup. | Historical and rejected for production. Current local targets require no ProjectOS cloud credential; optional OpenRouter uses a Keychain-backed API key. |
| Codex is the first validation adapter. | Superseded. Codex is outside MVP scope. Ollama, LM Studio, and MLX are local targets; OpenRouter is optional and external. |
| Local models follow proof of the Codex core loop. | Reversed by approved course correction. The local-first replacement is independently authorized and is not waiting on Codex. |
| Codex-managed tokens avoid ProjectOS credential ownership. | Historical mechanism only. Current secret handling is defined for OpenRouter; local runtimes follow their current adapter boundaries. |
| Persisted Codex threads require provider-side cleanup. | Historical Codex requirement only. Current cleanup is capability-aware and applies only when an adapter declares and uses persistent provider sessions. |
| Codex allowance windows and plan eligibility drive active UX. | Removed from current MVP. Current UX distinguishes local runtime/model/resource state from optional OpenRouter credential, network, quota, billing, and service state. |
| Provider-neutral domain contracts keep Canonical State independent of the adapter. | Preserved and adopted in the current PRD and architecture. |

## Preserved learning

The rejected path still produced reusable, non-authorizing learning:

- Canonical Project State and Conversation identity must remain ProjectOS-owned and provider-independent.
- Only explicitly selected context may enter a provider operation.
- Browsing, local mutation, import, export, restore, and navigation must never initiate inference.
- AI output can create only a pending Change Proposal; explicit user review governs Canonical State.
- Provider capabilities and readiness must be scoped to a concrete adapter/runtime/model/configuration, not inferred from an adapter name.
- Deterministic fakes are useful contract evidence but cannot qualify or authorize a production provider combination.
- Provider-side session cleanup is a declared capability obligation, not a universal product assumption.

These learnings survive because the current PRD and architecture adopt them explicitly—not because the Codex path passed.

## Downstream handling rule

Any source-extraction, architecture, UX, epic, story, or implementation workflow that encounters this file must label it **historical-superseded-rejected** and consult the current authority set before acting. A downstream artifact is inconsistent if it uses this reconciliation to introduce Codex setup, ChatGPT-plan access, Codex protocol types, Codex containment/profile mechanics, Codex cleanup, or Codex-first sequencing into production scope.
