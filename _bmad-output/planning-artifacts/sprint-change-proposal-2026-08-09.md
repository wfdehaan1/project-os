---
title: Sprint Change Proposal - Local-First Multi-Runtime MVP
status: implemented
date: 2026-08-09
approved: 2026-08-09
implemented: 2026-08-09
project: ProjectOS
change_scope: major
review_mode: incremental
trigger: Epic 1 completed with a reject decision for the Codex App Server path
---

# Sprint Change Proposal: Local-First Multi-Runtime MVP

## 1. Issue Summary

Epic 1, **Prove a Safe AI Path—or Stop**, completed its intended evidence and decision process. Story 1.9 recorded `reject` for the Codex App Server production path. The completed work remains useful: it proved reusable provider-neutral contracts and established explicit safety, state-ownership, event, proposal-validation, and evidence boundaries. It did not authorize production Codex work.

The recorded residual blockers are:

- live Codex-managed authentication remained unproven;
- non-coding quality evidence remained fake-backed;
- preventive containment was unavailable; and
- live Codex provider-session cleanup remained unproven.

The planning authorities still describe Codex App Server and ChatGPT subscription access as the initial MVP provider path. They also defer local inference and API-key access. That direction now conflicts with the completed gate result and the owner's replacement decision.

The approved replacement direction is:

- local inference is the default MVP category;
- Ollama, LM Studio, and MLX are first-class local MVP adapters;
- OpenRouter is the only optional external/API-key adapter;
- direct OpenAI, Anthropic, and Codex integrations are excluded from the MVP;
- provider, runtime, and model selection are explicit, with no silent fallback; and
- the course correction changes planning and production architecture directly, without another feasibility spike.

There is also a status inconsistency: Story 1.9 contains a completed implementation and validated `reject`, while `sprint-status.yaml` still lists Story 1.9 as `backlog` and Epic 1 as `in-progress`.

## 2. Impact Analysis

### 2.1 Epic impact

| Epic | Impact | Required change |
|---|---|---|
| Epic 1 - Prove a Safe AI Path—or Stop | Completed with `reject`; historical contracts and evidence remain valid. | Mark Story 1.9 and Epic 1 `done`. Record that the rejection blocks Codex production work, while the approved replacement architecture authorizes a different path. |
| Epic 2 - Establish a Trusted Local Project | Product scope remains valid and does not require an operational provider. Story 1.9 currently blocks it textually. | Preserve scope. Remove the Codex dependency through the approved architecture revision and state that Epic 2 may proceed locally. |
| Epic 3 - Turn AI Conversation into Governed State | Provider setup, runtime, authentication, errors, Context Preview, and implementation notes are Codex-specific. | Rename and redefine as local-first, covering Ollama, LM Studio, MLX, and optional OpenRouter. Defer detailed story decomposition until Epic 2 has been decomposed. |
| Epic 4 - Return and Resume with Confidence | Mostly provider-neutral, but generated recap and continuation assume a single cloud provider. | Use the explicitly active adapter and preserve local saved orientation when inference is unavailable. |
| Epic 5 - Retain Full Ownership and Recoverability | Cleanup assumes persisted Codex sessions and a cleanup outbox. | Distinguish local Project deletion, OpenRouter credentials, user-managed local runtimes/models, ProjectOS-managed MLX data, and independent external retention. Require session cleanup only when an adapter uses persistent sessions. |

No new epic or spike is required. The sequence remains Epic 2, Epic 3, Epic 4, then Epic 5.

### 2.2 Story impact

- Stories 1.1 through 1.9 remain unchanged as completed historical contracts.
- Story 1.9 changes status from `backlog` to `done`; its `reject` result remains binding for Codex.
- No completed Epic 1 implementation is rolled back.
- Future Epic 3 stories must cover the four production adapters and shared contract, but are not authored ahead of Epic 2 under the existing sequential planning rule.

### 2.3 Artifact conflicts

| Artifact | Conflict |
|---|---|
| PRD and addendum | Target eligibility, glossary, FR-14/15/17/18, NFR-8/9/12, MVP scope, non-goals, and open questions encode Codex-first assumptions. |
| Architecture spine | Diagram and decisions AD-4, AD-5, AD-8, AD-9, AD-10, and AD-13 bind production to Codex process, authentication, containment, protocol, and profile semantics. |
| Epics and tracker | AR1-AR20 describe the spike rather than the replacement production architecture; future epic notes are Codex-specific; tracker status is stale. |
| UX spines | First Run, Settings, Context Preview, offline states, cleanup, key flows, components, and copy describe OpenAI/Codex as the sole MVP provider. |
| UX mockups | All four load-bearing mockups contain Codex/OpenAI-specific boundary text. |
| Product brief and addendum | Codex/ChatGPT-plan-first remains the product direction and local adapters remain deferred. |
| Reconciliation and review documents | The Codex reconciliation is presented as current; architecture and UX reviews validate superseded authorities. |
| Spike README and context | Correctly describe the rejected harness but do not yet point readers to the replacement production architecture. |

Completed Story 1.x specifications, spike evidence, market research, and the already-superseded `docs/ProjectWorkspace.md` remain historical and are not rewritten.

### 2.4 Technical impact

The production provider boundary expands to four adapters:

1. Ollama through a loopback-only local runtime connection.
2. LM Studio through a loopback-only local runtime connection.
3. MLX through native on-device inference.
4. OpenRouter as the sole external adapter, using a macOS Keychain-backed API key.

The provider-neutral domain contracts remain. The Codex-specific process supervisor, profile, authentication, containment, exact protocol manifest, and cleanup-outbox assumptions do not become production requirements.

The replacement architecture must support:

- runtime-and-model-scoped capability negotiation;
- explicit adapter and model activation;
- no silent runtime, provider, or model fallback;
- generation-only permissions with no tools or domain repository access;
- ProjectOS-owned Conversations and Context Preview selection;
- ProjectOS-owned Change Proposal schema validation;
- normalized local runtime/model/resource failures;
- normalized OpenRouter credential, network, rate, quota, billing, and service failures;
- truthful local-versus-external processing disclosure; and
- capability-aware session and deletion behavior.

## 3. Recommended Approach

### 3.1 Selected path

Use a hybrid of **MVP Review** and **Direct Adjustment**:

1. Close Epic 1 truthfully with its `reject` outcome.
2. Revise the governing PRD, architecture, epics, UX, brief, and supporting status documents.
3. Preserve completed spike contracts and evidence as historical records.
4. Allow Epic 2 to proceed under the replacement architecture.
5. Decompose Epic 2 before authoring detailed Epic 3 stories.
6. Implement the provider stack as production work with contract and integration acceptance tests, not another feasibility spike.

### 3.2 Alternatives considered

**Direct adjustment without an MVP review:** insufficient. The provider direction is embedded across every governing planning artifact and changes MVP eligibility, setup, security, privacy, billing, failure, and deletion behavior.

**Rollback Epic 1:** rejected. It would remove useful evidence and reusable provider-neutral contracts without simplifying the new provider stack enough to justify the loss.

**Another provider spike:** rejected by product direction. Compatibility, quality, and resource behavior become explicit implementation acceptance criteria rather than a separate authorization gate.

### 3.3 Effort, risk, and timeline impact

- **Change effort:** High. Multiple finalized authorities and mockups require coordinated revision.
- **Implementation risk:** High. The MVP now supports three structurally different local inference paths and one routed cloud provider.
- **Timeline impact:** Provider-related planning is reset. Epic 2 can proceed after the documentation correction, while Epic 3 requires later decomposition and a four-adapter implementation sequence.

Primary risks are local model quality variance, runtime/version compatibility, MLX packaging and memory limits, model availability and licensing, differing structured-output capabilities, OpenRouter routing/cost/retention disclosure, and expanded setup complexity.

Mitigations are explicit capability negotiation, runtime/model-scoped readiness, no fallback, one ProjectOS schema boundary, generation-only permissions, loopback enforcement, Keychain secret storage, contract tests, targeted adapter integration tests, and calm persistent unavailable reasons.

## 4. Detailed Change Proposals

### 4.1 PRD

**Current direction:** one Codex App Server adapter using ChatGPT subscription access; local models and API keys are deferred.

**Replacement direction:**

- Ollama, LM Studio, and MLX are first-class local MVP adapters.
- OpenRouter is the only optional external/API-key adapter.
- Direct OpenAI, Anthropic, and Codex integrations are outside MVP scope.
- ProjectOS detects available local runtimes and requires explicit active runtime/model selection.
- Ollama and LM Studio MVP endpoints are loopback-only.
- OpenRouter credentials live in macOS Keychain and never enter Project data, logs, diagnostics, or exports.
- Context Preview names the active adapter, model, locality/external boundary, selected context, and external billing where applicable.
- No runtime, provider, or model fallback occurs silently.
- Every completed result passes the ProjectOS-owned Change Proposal schema before it can become a pending proposal.
- Provider/model changes never alter accepted Canonical State.
- Local compatibility and quality are implementation acceptance criteria, not another spike.

Update target eligibility, glossary, FR-14/15/17/18, NFR-8/9/12, MVP scope, non-goals, success gates, and open questions consistently.

### 4.2 Architecture

Preserve AD-1 through AD-3 and the reusable parts of AD-6, AD-7, AD-11, and AD-12. Replace Codex-specific decisions with:

- a shared local-inference contract with Ollama, LM Studio, and MLX implementations;
- loopback-only server boundaries for Ollama and LM Studio;
- native on-device MLX inference;
- runtime-and-model-scoped capability claims;
- OpenRouter as the only external adapter;
- macOS Keychain-backed OpenRouter secret storage;
- explicit adapter/model selection and no fallback;
- generation-only permissions;
- ProjectOS-owned Conversations and schema validation;
- capability-aware cleanup; and
- reusable contract tests plus adapter-specific integration tests.

Mark `validation-spike.md` `complete-rejected`, record its outcome and blockers, retain its evidence, and state that the replacement architecture authorizes later work without claiming the Codex gate passed.

### 4.3 Epics and tracker

Change:

```yaml
epic-1: in-progress
1-9-prove-provider-neutrality-and-record-the-gate-decision: backlog
```

to:

```yaml
epic-1: done
1-9-prove-provider-neutrality-and-record-the-gate-decision: done
```

Replace spike-specific AR1-AR20 with production requirements for the approved four-adapter stack and shared invariants.

Rename Epic 3 to **Turn Local-First AI Conversation into Governed State** and cover:

- production provider registry and job coordinator;
- Ollama runtime/model setup;
- LM Studio runtime/model setup;
- MLX model loading and resource readiness;
- OpenRouter Keychain setup and routed-model selection;
- explicit provider/model selection;
- Context Preview;
- normalized Conversation execution;
- structured proposal validation and review; and
- cross-adapter contract and integration coverage.

Preserve Epic 2, make Epic 4 explicitly provider-neutral, and make Epic 5 cleanup capability-aware.

### 4.4 UX

Replace OpenAI/Codex-only setup with an **AI Providers** settings surface:

- Local: Ollama, LM Studio, MLX.
- Cloud: OpenRouter.
- Explicit active runtime/model and readiness state.
- Secure OpenRouter key setup.
- No automatic fallback control.

First Run presents local setup first, OpenRouter as optional, and Continue without AI. No installation, model download, API call, or provider switch occurs without explicit action.

Local Context Preview states that selected Project context stays on the Mac. OpenRouter Context Preview names OpenRouter, the selected model, external processing, selected transmission scope, and usage-based billing.

Replace the single offline/provider state with local runtime/model/resource states and separate OpenRouter configuration/network/rate/quota/billing/service states. Network offline disables OpenRouter work but does not disable a configured local adapter.

Update provider-related contracts in Composer, Context Preview, Settings Row, Status Badge, Progress Indicator, Empty State, and Confirmation Sheet. Update all four HTML mockups so the primary illustrated path is local and OpenRouter is the optional external alternative.

### 4.5 Supporting authorities and historical records

- Update the product brief and addendum to the approved provider stack.
- Update the PRD addendum.
- Mark the 2026-07-31 Codex subscription reconciliation historical and superseded while preserving its reasoning.
- Update product-brief and market-research reconciliation conclusions where they defer local/API support.
- Add an archived/rejected-production-path note to the spike README.
- Mark architecture reviews as historical reviews of superseded architecture.
- Mark the current UX validation report superseded pending review of the revised UX.
- Preserve Story 1.x specifications, harness code, retained evidence, market research, and the superseded seed document unchanged.

## 5. Implementation Handoff

### 5.1 Scope classification

**Major.** This is a fundamental MVP provider replan affecting product requirements, architecture, backlog, UX, security, privacy, failure handling, model/runtime setup, and deletion semantics.

### 5.2 Handoff recipients

| Role | Responsibility |
|---|---|
| Product Manager | Apply the approved provider hierarchy and MVP exclusions consistently to the PRD, brief, and addenda. Preserve the semantic-continuity validation thesis. |
| Solution Architect | Replace Codex-specific production decisions with the four-adapter architecture, define the MLX integration boundary, and preserve provider-neutral invariants. |
| UX Designer | Revise provider setup, Context Preview, states, copy, key flows, mockups, and validation status. Keep local execution primary and external processing explicit. |
| Product Owner / Developer | Correct tracker state, update epic requirements and implementation notes, then decompose Epic 2 before Epic 3. |
| Developer | Later implement only from approved stories, with adapter contract tests and targeted integration tests. No new spike or silent fallback. |

### 5.3 Sequencing

1. Approve this Sprint Change Proposal.
2. Apply governing PRD, architecture, epic, UX, brief, reconciliation, historical-status, and tracker edits.
3. Run cross-artifact terminology, scope, status, link, and whitespace validation.
4. Revalidate the revised PRD/architecture/UX authority set.
5. Decompose Epic 2 and begin the trusted local foundation.
6. Design Epic 3 stories only after Epic 2 planning/learning is available.

### 5.4 Success criteria

- No governing artifact presents Codex App Server, ChatGPT subscription access, direct OpenAI, or direct Anthropic APIs as the MVP path.
- Every governing artifact names Ollama, LM Studio, and MLX as first-class local MVP adapters and OpenRouter as the sole optional external adapter.
- Local inference is the default category; adapter and model choice remain explicit.
- No artifact permits silent provider/runtime/model fallback.
- OpenRouter secret handling is Keychain-backed and excluded from Project data and exports.
- Context Preview and failure behavior distinguish local execution from external OpenRouter processing.
- Epic 1 and Story 1.9 are `done`, with `reject` preserved for Codex.
- Epic 2 is unblocked through the explicit replacement architecture.
- Historical spike evidence remains intact and clearly labeled.
- Revised UX validation is not claimed until performed.

## 6. Checklist Record

### Section 1 - Understand the Trigger and Context

- [x] 1.1 Triggering story identified: Story 1.9.
- [x] 1.2 Core problem categorized: failed approach requiring a strategic MVP pivot.
- [x] 1.3 Evidence recorded: deterministic `reject` and four residual blockers.

### Section 2 - Epic Impact Assessment

- [x] 2.1 Epic 1 evaluated as complete with `reject`.
- [x] 2.2 Epic-level changes specified.
- [x] 2.3 All future epics reviewed.
- [x] 2.4 No new epic required.
- [x] 2.5 Existing epic order retained.

### Section 3 - Artifact Conflict and Impact Analysis

- [x] 3.1 PRD conflicts identified.
- [x] 3.2 Architecture conflicts identified.
- [x] 3.3 UX conflicts identified.
- [x] 3.4 Supporting artifacts and historical records identified.

### Section 4 - Path Forward Evaluation

- [x] 4.1 Direct adjustment viable only within a broader MVP review.
- [N/A] 4.2 Rollback rejected as unjustified.
- [x] 4.3 MVP review required.
- [x] 4.4 Hybrid MVP review plus direct adjustment selected.

### Section 5 - Sprint Change Proposal Components

- [x] 5.1 Issue summary created.
- [x] 5.2 Epic and artifact impacts documented.
- [x] 5.3 Recommended path and alternatives documented.
- [x] 5.4 MVP impact, sequencing, and action plan defined.
- [x] 5.5 Major-scope handoff plan established.

### Section 6 - Final Review and Handoff

- [x] 6.1 Applicable checklist sections addressed.
- [x] 6.2 Proposal reviewed for accuracy and approved.
- [x] 6.3 Explicit implementation approval obtained on 2026-08-09.
- [x] 6.4 Sprint tracker updated: Epic 1 and Story 1.9 are `done` with the reject outcome preserved.
- [x] 6.5 Approved document changes implemented and final handoff prepared.

## 7. Incremental Review Record

- PRD provider direction: approved, then revised and approved for Ollama / LM Studio / MLX / OpenRouter.
- Architecture direction: approved, then revised and approved for Ollama / LM Studio / MLX / OpenRouter.
- Epic and tracker direction: revised and approved for the four-adapter stack.
- UX direction: approved.
- Supporting authority and historical-record direction: approved.

## 8. Implementation Record

Implemented on 2026-08-09 after explicit approval:

- Reconciled the PRD, architecture spine, epics, product brief, PRD addendum, UX specifications, and representative mockups around four MVP adapters: Ollama, LM Studio, MLX, and OpenRouter.
- Defined Ollama, LM Studio, and MLX as first-class local adapters and OpenRouter as the sole optional API-key adapter for the MVP.
- Removed direct OpenAI, Anthropic, ChatGPT, Claude, and Codex production adapters from current MVP scope while retaining the completed Codex spike as rejected historical evidence.
- Updated Epic 1 and Story 1.9 to `done`; authorized Epic 2 under the replacement provider-neutral architecture without adding another spike.
- Marked superseded reconciliation and validation artifacts as historical so they cannot be mistaken for current implementation authority.

Validation completed:

- Markdown whitespace validation passed with `git diff --check`.
- Sprint status YAML parsed successfully and records Epic 1 and Story 1.9 as `done`.
- Current PRD, architecture, epic, brief, and UX authorities contain the approved four-adapter direction.
- Requirement inventories remain contiguous: FR1-FR18, AR1-AR18, and UX-DR1-UX-DR46.
- Local links in the changed governing authorities resolve to existing files.
- Current authorities and mockups contain no stale operational Codex, direct OpenAI, direct Anthropic, or automatic-fallback direction.

Handoff: revalidate the reconciled PRD, architecture, and UX authorities, then decompose Epic 2 into implementation-ready stories. No new provider spike is required by this proposal.
