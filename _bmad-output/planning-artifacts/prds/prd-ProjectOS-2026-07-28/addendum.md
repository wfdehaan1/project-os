# ProjectOS Validation PRD Addendum

This addendum preserves supporting context, deferred product decisions, market evidence, and validation mechanics that should inform downstream work without expanding the validation PRD itself.

## 1. Authority and Inputs

Inputs, in descending authority:

1. The current working-tree [product brief](../../briefs/brief-ProjectOS-2026-07-27/brief.md) and [brief addendum](../../briefs/brief-ProjectOS-2026-07-27/addendum.md).
2. User decisions recorded in the PRD run's `.memlog.md`.
3. [ProjectOS market-opportunity research](../../research/market-projectos-market-opportunity-research-2026-07-27.md) as supporting market evidence.
4. A focused 2026-07-28 competitive refresh performed during PRD Discovery.

`docs/ProjectWorkspace.md` is excluded because the current product brief supersedes it. Where market research assumes an older scope, the brief and memlog govern.

## 2. Validation Interpretation

The product brief describes a broader commercial MVP and originally positions PRD work after concierge validation. The active user decision narrows this PRD to the personal validation build itself. This is not a reversal of the long-term direction; it is a smaller commitment boundary intended to generate evidence before broader implementation.

The validation build should be judged as an experiment:

- **Claim:** governed semantic continuity makes returning to consequential AI-assisted projects materially easier.
- **Comparison:** the user's incumbent combination of AI chat, notes, files, tasks, and memory.
- **Unit of evidence:** a Qualifying Return to a real Project after at least seven days.
- **Primary evidence:** time to Meaningful Work, trust in current state, correctness of proposed state, correction burden, and usefulness of Next Actions.
- **Disconfirming evidence:** high maintenance burden, repeated state correction, opaque recommendations, or no observable re-entry advantage.

`[ASSUMPTION — owner: Wouter; revisit before the validation window begins]` For this personal cycle, a minimum of three Qualifying Returns is adequate to decide whether to continue, rethink, or stop. This is a product-investment gate, not statistically generalizable research.

## 3. Measurement Notes

### 3.1 Successful Re-entry

Start timing when the Project is opened. Stop when the user takes the first Meaningful Work action outside mere ProjectOS housekeeping. Record:

- elapsed time;
- whether current state was understood;
- whether any governing state proved wrong or missing;
- whether a Next Action was shown and useful;
- what real-world action followed;
- a short comparison with how the user would have resumed without ProjectOS.

Capture an observed incumbent baseline rather than relying only on hindsight. Before ProjectOS becomes the resumption tool for a validation Project, use the incumbent combination of AI chat, notes, files, tasks, and memory for a real return after at least seven days where feasible. Start and stop timing with the same rules, record which sources had to be reopened, and note any reconstruction or uncertainty. Capture at least one such incumbent-only return across the validation set. When no valid baseline opportunity exists, mark the comparison as hypothetical and do not treat it as equivalent evidence.

### 3.2 Material Correctness

Measure material facts and Decisions, not grammar or stylistic preference. A proposed item is correct when it faithfully represents Source Material and the user's intended meaning without changing scope, certainty, actor, status, or rationale. Track separately:

- accepted unchanged;
- accepted after a material correction;
- rejected as incorrect, duplicate, irrelevant, or unsupported.

The denominator is all material proposed facts and Decisions reviewed during validation. The target is at least 85% correct before material correction.

Correctness does not establish completeness. After each proposal-generating validation session, make a brief user-authored list of the material new or changed state that should survive the session, then compare it with the proposed set. Record each expected Decision, Open Question, Task, or Research item that was omitted, including whether the omission would impair current-state understanding or a later Qualifying Return. Keep omissions out of the correctness denominator so a small set of accurate proposals cannot hide important missing state.

### 3.3 Maintenance Burden

Record time spent reviewing and correcting Change Proposals and any moments where the user manually updates Project State only to keep ProjectOS coherent. No fixed threshold is set yet; Wouter owns that decision and will resolve it before the first Qualifying Return. Recurring perception that maintaining the representation costs more than reconstructing context is disconfirming evidence.

## 4. Market-Derived Product Constraints

The repository market research supports a conditional go for focused validation, not a broad platform commitment. Evidence that people use AI for consequential projects is stronger than evidence that they will switch, pay, or prefer explicit governed state.

The direct incumbent is not one product. It is a familiar bundle of an AI assistant, notes, files, email, spreadsheets, and task tools. Existing AI project containers, local-first knowledge tools, and native macOS BYO-AI clients already provide combinations of local storage, memory, files, projects, and one-time pricing.

A current landscape refresh identified especially close comparables. These observations come from current official product pages; the adoption, reliability, and maturity of smaller entrants were not independently verified.

- [Keel](https://keel-app.dev/) overlaps with typed decisions, rationale, dependencies, provenance, local-first storage, Ollama, and confirmation of extracted changes, but is positioned toward programme and enterprise work.
- [BoltAI](https://boltai.com/pricing) overlaps with native macOS, local chats, BYO AI, Ollama, projects, and perpetual licensing.
- [DEVONthink](https://www.devontechnologies.com/apps/devonthink/security), [Fob](https://fob.sh/), [Kaisho](https://kaisho.dev/), [AnythingLLM](https://anythingllm.com/), and [Pieces](https://docs.pieces.app/) further weaken generic claims around local data, durable memory, or cross-session continuity.

Therefore, downstream work must preserve these differentiating contracts:

1. Source Material → Change Proposal → explicit accept/edit/reject → versioned Canonical State.
2. Governing versus Superseded Decisions with inspectable Rationale and Provenance.
3. Current-state-first re-entry after a meaningful gap.
4. Explained Next Actions grounded in accepted state.
5. Lower setup and maintenance burden than a configurable knowledge or project-management system.

Avoid positioning ProjectOS as merely “AI that remembers,” “chat with project files,” “everything in one place,” “local AI,” or a “second brain.”

## 5. Provider and Privacy Decisions

### 5.1 Validation Build

- OpenAI is the only AI Provider.
- The user supplies the API credential and pays OpenAI separately.
- Canonical project data remains on the Mac.
- Only user-selected context is transmitted for an initiated provider request.
- Provider identity, transmission scope, error state, and separate billing are explicit.
- The selected model and a best-effort request-level usage and cost estimate are inspectable; OpenAI billing remains authoritative and estimate limitations are explicit.
- There is no ProjectOS-hosted project-content backend or inference service.

Provider/model adapter design, storage format, and credential implementation belong to architecture. The PRD constrains their observable behavior and security properties.

### 5.2 Deferred Broader Direction

The current brief includes Ollama as the local AI Provider option. Ollama is deferred from the validation build so that provider variance and local-model setup do not obscure the semantic-continuity test. If the core loop succeeds, Ollama should be evaluated separately for:

- extraction correctness against the same 85% gate;
- honest degradation when a local model is insufficient;
- onboarding and model-selection burden;
- privacy value and real user demand.

Anthropic, ChatGPT account authentication, ProjectOS-hosted inference, and managed provider billing remain deferred.

Local-first reduces the ProjectOS data footprint but does not eliminate privacy or GDPR obligations. Selected content still leaves the Mac when sent to OpenAI, and future licensing, support, updates, or diagnostics may process personal data.

## 6. Deferred Commercial MVP Decisions

The following product-brief decisions remain preserved but do not belong in the validation build:

- native macOS distribution through the Mac App Store;
- one-time purchase rather than a subscription for the initial product;
- a working price hypothesis around $59.99, with $39.99 and $79.99 as test anchors;
- commercial onboarding, price-bearing activation, purchase, and conversion testing;
- support for OpenAI and Ollama behind a provider-neutral boundary;
- a restrained hero image and accent identity for emotional project ownership;
- possible paid major upgrades to support ongoing macOS/provider compatibility;
- a future managed subscription only if recurring hosted value such as synchronization, additional surfaces, sharing, or collaboration is later proven.

Commercial onboarding and the emotional project-ownership identity are explicit post-validation deferrals, not rejected directions. The market research does not establish willingness to pay. Price, conversion, repeat-project use, and tolerance of BYO-provider friction remain hypotheses for a later gate.

## 7. Deferred Scope and Rejected Expansion

- No collaboration, roles, permissions, assignments, shared Projects, or hosted synchronization.
- No web or mobile client.
- No bulk reconstruction from provider accounts or full account exports; lightweight user-selected import is sufficient.
- No autonomous consequential actions.
- No first-class Requirements, Risks, Files, Notes, Photos, Purchases, or Measurements in the validation build.
- No validation-cycle work on emotional project-ownership identity, hero imagery, or full visual customization.
- No narrowing of the overall product to renovation, software, or any single vertical. A narrow cohort may be used for testing without redefining the cross-domain product.

## 8. Downstream Handoff Notes

### UX

UX work should focus on the proposal-review interaction, clear distinction between pending and accepted state, contradiction/supersession resolution, current-state-first re-entry, evidence on demand, explicit provider boundaries, and a lightweight validation record. The experience should feel calm and conversational, not like maintaining a configurable PM system.

### Architecture

Architecture must establish invariants for atomic accepted-state transitions, stable Artifact identity, version, supersession and deletion history, permanent local Project deletion, Provenance integrity, local persistence, backup/export/restore, secure credentials, usage-cost estimation boundaries, and provider isolation. The canonical storage technology and provider-adapter mechanism are intentionally not specified here.

### Epics and Implementation

Implementation sequencing should prove the closed continuity loop before adding provider breadth, distribution, pricing, or visual identity. A vertical slice should cover Project creation, Conversation/Source Material, one or more Change Proposals, explicit review, Canonical State, Re-entry View, and verified persistence.
