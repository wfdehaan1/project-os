# ProjectOS Validation PRD Addendum

This addendum preserves supporting context, deferred product decisions, market evidence, and validation mechanics that should inform downstream work without expanding the validation PRD itself.

## 1. Authority and Inputs

Inputs, in descending authority:

1. The current working-tree [product brief](../../briefs/brief-ProjectOS-2026-07-27/brief.md) and [brief addendum](../../briefs/brief-ProjectOS-2026-07-27/addendum.md).
2. The approved [2026-08-09 Sprint Change Proposal](../../sprint-change-proposal-2026-08-09.md) for the current provider decision. The dated [Codex subscription-access reconciliation](reconcile-codex-subscription-access-2026-07-31.md) is historical and superseded.
3. User decisions recorded in the PRD run's `.memlog.md`.
4. [ProjectOS market-opportunity research](../../research/market-projectos-market-opportunity-research-2026-07-27.md) as supporting market evidence.
5. A focused 2026-07-28 competitive refresh performed during PRD Discovery.

`docs/ProjectWorkspace.md` is excluded because the current product brief supersedes it. Where market research assumes an older scope, the brief and memlog govern.

## 2. Validation Interpretation

The product brief describes a broader commercial MVP and originally positioned PRD work after concierge validation. The active user decision narrows this PRD to the personal validation build itself. This is not a reversal of the long-term direction; it is a smaller commitment boundary intended to generate evidence before broader implementation.

The validation build should be judged as an experiment:

- **Claim:** governed semantic continuity makes returning to consequential AI-assisted projects materially easier.
- **Comparison:** the user's incumbent combination of AI chat, notes, files, tasks, and memory.
- **Unit of evidence:** a Qualifying Return to a real Project after at least seven days.
- **Primary evidence:** time to Meaningful Work, trust in current state, correctness of proposed state, correction burden, and usefulness of Next Actions.
- **Disconfirming evidence:** high maintenance burden, repeated state correction, opaque recommendations, or no observable re-entry advantage.

PRD SM-1 and the Assumptions Index govern the minimum-three-return assumption. This is a product-investment gate, not statistically generalizable research. The first validation window may begin with one qualified local adapter/runtime/model combination; completing the broader provider scope still requires qualification of all four approved adapter targets.

## 3. Measurement Notes

### 3.1 Successful Re-entry

Start timing when the Project is opened. Stop when the user takes the first Meaningful Work action outside mere ProjectOS housekeeping. Record:

- elapsed time;
- whether current state was understood;
- whether any governing state proved wrong or missing;
- whether a Next Action was shown and useful;
- whether the suggested action, a different meaningful action, or no action followed;
- a short comparison with how the user would have resumed without ProjectOS.

When a validation Project reaches an outcome, record successful completion, intentional closure, abandonment, or an unresolved result. This supports later comparison between re-entry help and real project progress without turning project completion into a gate for every Qualifying Return.

Capture an observed incumbent baseline rather than relying only on hindsight. Before ProjectOS becomes the resumption tool for a validation Project, use the incumbent combination of AI chat, notes, files, tasks, and memory for a real return after at least seven days where feasible. Start and stop timing with the same rules, record which sources had to be reopened, and note any reconstruction or uncertainty. Capture at least one such incumbent-only return across the validation set. When no valid baseline opportunity exists, mark the comparison as hypothetical and do not treat it as equivalent evidence.

### 3.2 Material Correctness

Measure material facts and Decisions, not grammar or stylistic preference. A proposed item is correct when it faithfully represents Source Material and the user's intended meaning without changing scope, certainty, actor, status, or rationale. Track separately:

- accepted unchanged;
- accepted after a material correction;
- rejected as incorrect, duplicate, irrelevant, or unsupported.

The denominator is all material proposed facts and Decisions reviewed during validation. The target is at least 85% correct before material correction.

Correctness does not establish completeness. After each proposal-generating validation session, make a brief user-authored list of the material new or changed state that should survive the session, then compare it with the proposed set. Record each expected Decision, Open Question, Task, or Research item that was omitted, including whether the omission would impair current-state understanding or a later Qualifying Return. Keep omissions out of the correctness denominator so a small set of accurate proposals cannot hide important missing state.

Before reviewing proposals, the user records the expected material items without looking at the generated set. After comparison, each absent item is classified as: (a) material but non-critical, or (b) critical because its absence would leave a Governing Decision wrong, an accepted contradiction unresolved, or a Re-entry View materially misleading. The completeness denominator is all expected material items; the numerator is those represented in the initial proposal set without an additional prompt. Manual repair does not convert an omission into a hit. Record session count, item count, completeness percentage, critical-omission count, active Qualified Adapter Combination, and whether the evidence volume is sufficient for a gate decision.

### 3.3 Maintenance Burden

Record time spent reviewing and correcting Change Proposals and any moments where the user manually updates Project State only to keep ProjectOS coherent. No fixed threshold is set yet; Wouter owns that decision and will resolve it before the first Qualifying Return. Recurring perception that maintaining the representation costs more than reconstructing context is disconfirming evidence.

### 3.4 Usability Acceptance

- **Measure:** NFR-10 on the supported validation Mac against a deterministic reference Project after indexing. Run thirty attempts for each named action and report p50 and p95.
- **Exclude:** Initial import and index construction.
- **Include:** Ordinary application startup and cache misses unless reported separately.
- **Copy suite:** English and Dutch local-ready, local-unavailable, OpenRouter-external, offline, malformed-output, rejected-proposal, and failed-Canonical-State-transition cases.
- **Fail when:** A primary message omits the user-relevant effect or next action, implies unearned certainty, hides external processing or cost, or exposes only an unexplained provider code.

### 3.5 Adapter Setup Burden

- **Start:** When the user begins the ProjectOS or runtime setup instructions.
- **Pause:** Only for unattended download or model-transfer time, recorded separately.
- **Stop:** When ProjectOS truthfully reports Ready or the attempt is abandoned.
- **Record:** Adapter, runtime version, model and format, hardware class, active and waiting time, attempt count, documentation, assistance, blocking failures, source-code or undocumented configuration edits, and final outcome.
- **Interpret:** Vendor installation instructions are not outside assistance; bespoke troubleshooting or another person's intervention is. Evidence applies only to that combination and does not authorize fallback or another target.

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
5. Lower setup and maintenance burden than a configurable knowledge or project-management system, measured separately through PRD SM-C4 and SM-C1.

Avoid positioning ProjectOS as merely “AI that remembers,” “chat with project files,” “everything in one place,” “local AI,” or a “second brain.”

## 5. Provider and Privacy Decisions

### 5.1 Validation Build

- Ollama, LM Studio, and MLX are first-class local AI Provider Adapter targets for validation.
- OpenRouter is the only optional external adapter. Direct OpenAI, Anthropic, and Codex adapters are outside validation scope.
- Ollama and LM Studio use supported loopback-only endpoints. MLX runs through native on-device inference.
- The user explicitly selects the active adapter and model. ProjectOS never silently switches, retries through, or falls back to another runtime, provider, or model.
- The OpenRouter API key is stored in macOS Keychain. Project data retains no provider secret, and the key is excluded from logs, diagnostics, exports, and ProjectOS-created backups.
- Canonical project data remains on the Mac.
- Only user-selected context enters an explicitly initiated inference operation.
- Adapter/model identity, external-versus-local execution, transmission scope, runtime/model/resource state, and OpenRouter billing state are explicit.
- Local Context Preview states that Project content remains on the Mac. OpenRouter Context Preview discloses external processing, selected scope, routed model, and usage-based billing.
- There is no ProjectOS-hosted project-content backend or inference service.

Target status is a scope commitment, not a support claim. Supported and Ready apply only to a Qualified Adapter Combination. Its compatibility record names the adapter, runtime version where applicable, model and format, macOS hardware class, context and resource bounds, known degradations, and evidence date.

The experiment-start cut line is a learning boundary, not an adapter hierarchy. It permits product-thesis validation with one qualified local combination while retaining all four approved targets for provider-scope completion. OpenRouter is not a prerequisite for the local-first experiment. Selection remains explicit; no qualified adapter becomes an automatic fallback or a hidden preferred default. Qualification proceeds through implementation acceptance criteria, not another feasibility or authorization spike.

Provider/model adapter design, storage format, runtime isolation, compatibility criteria, MLX packaging, and optional Provider Session Binding implementation belong to architecture. The PRD constrains their observable behavior and security properties.

### 5.2 Provider-Independent Contract

ProjectOS owns a narrow, capability-oriented provider contract for its product jobs rather than a generic copy of any vendor API. The contract covers:

- provider discovery, configuration, health, and capability reporting;
- project-grounded generation with streaming and cancellation;
- structured Change Proposal output with ProjectOS-owned schemas;
- normalized completion, interruption, local runtime/model/resource, OpenRouter credential, network, rate, quota, billing, and service errors;
- adapter/model, usage, context-limit, and resource information where supported;
- optional provider-session lifecycle only when an adapter declares persistent sessions; and
- explicit local-versus-external execution disclosure.

The Ollama, LM Studio, MLX, and OpenRouter adapters translate this contract through their own runtime/model mechanisms. Capability negotiation prevents the contract from collapsing to any runtime or routed-model assumptions or a lowest common denominator.

ProjectOS owns canonical Conversation identity and history. Provider thread or session identifiers are replaceable bindings. Export and restore must remain useful without access to the original provider session, and switching providers must not rewrite accepted Canonical State.

### 5.3 Deferred Broader Direction

Remote Ollama or LM Studio endpoints, local runtimes beyond Ollama/LM Studio/MLX, direct provider APIs, Codex App Server, automatic model routing/fallback, ProjectOS-hosted inference, and managed provider billing remain deferred.

Local-first reduces the ProjectOS data footprint but does not eliminate privacy or GDPR obligations. OpenRouter receives selected Project content only after explicit preview and initiation; independent OpenRouter or routed-provider retention is disclosed rather than represented as locally controlled.

## 6. Deferred Commercial MVP Decisions

The following product-brief decisions remain preserved but do not belong in the validation build:

- native macOS distribution through the Mac App Store;
- one-time purchase rather than a subscription for the initial product;
- a working price hypothesis around $59.99, with $39.99 and $79.99 as test anchors;
- commercial onboarding, price-bearing activation, purchase, and conversion testing;
- additional cloud or local AI adapters beyond the approved Ollama, LM Studio, MLX, and OpenRouter targets, plus commercial-scale compatibility maintenance, support operations, and broader provider/model coverage;
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

Architecture follows the current [AI provider architecture spine](../../architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md): a provider-independent, generation-only capability boundary with Ollama, LM Studio, and MLX as first-class local MVP adapter targets and OpenRouter as the sole optional external target. It must preserve atomic accepted-state transitions, stable Artifact identity, version and supersession history, Provenance integrity, local persistence, export and restore, runtime/model-scoped capability negotiation, explicit boundary disclosure, ProjectOS-owned Conversation and Change Proposal schemas, normalized failures, no silent fallback, and capability-aware deletion. The completed Codex App Server spike and its architecture are historical rejected evidence only; they neither authorize production Codex work nor impose Codex process, authentication, protocol, containment, profile, or cleanup mechanics on replacement adapters.

### Epics and Implementation

Epic 2 establishes the trusted local Project, Canonical State, Source Material, Artifact, relationship, history, Provenance, and offline foundations without requiring any configured inference adapter; Story 2.1 must not introduce or depend on provider implementation. After Epic 2 has been decomposed and its local-state contracts are available, Epic 3 implements the shared provider contract and job coordination, qualifies adapter/runtime/model combinations through implementation acceptance tests, and builds the provider-backed Conversation-to-proposal loop. The governed-continuity experiment may begin when the cut line in PRD §7.1 is met. The validation build's complete provider scope still requires all four approved targets—Ollama, LM Studio, MLX, and the optional external OpenRouter target—to satisfy their applicable contract and integration criteria. No new authorization spike or Codex adapter validation is required or permitted by this sequence.
