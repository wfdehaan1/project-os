# Course-Correction Coherence Review

## Verdict

**Pass.** The updated PRD and addendum cleanly implement the approved local-AI-first course correction and are coherent with the current architecture spine, epics, sprint proposal, and tracker. No current handoff authorizes Codex production work; the completed Codex App Server path remains historical rejected evidence. The provider direction creates no course-correction blocker to decomposing Story 2.1 as part of provider-free Epic 2. This focused verdict does not resolve unrelated PRD open questions that are intentionally due before later validation events.

Severity counts: **0 critical, 0 high, 0 medium, 0 low**.

## Findings

No course-correction coherence findings.

## Positive controls

- **Codex remains rejected and non-authorizing.** PRD §7.2 excludes Codex App Server and ChatGPT subscription integration. Addendum §1 labels the earlier Codex reconciliation historical and superseded; §8 states that the spike and former architecture neither authorize production Codex work nor impose their mechanics on replacement adapters. The architecture spine records the Epic 1 `reject`, supersedes the former production direction, and preserves only explicitly adopted provider-neutral invariants.
- **Epic 2 and Story 2.1 are provider-free.** The PRD experiment cut line requires a usable provider-free Epic 2 foundation before provider-backed validation. Addendum §8 explicitly forbids Story 2.1 from introducing or depending on provider implementation. `epics.md` assigns only FR-1, FR-2, and FR-7 through FR-10 to Epic 2 and states that it requires no configured inference adapter.
- **Epic 3 owns production adapter work.** `epics.md` assigns FR-3 through FR-6 and FR-14, FR-15, and FR-18 to Epic 3, including provider registry, job coordination, Ollama, LM Studio, MLX, OpenRouter, Context Preview, normalized execution, schema validation, and cross-adapter coverage. The addendum preserves the same boundary and sequences Epic 3 only after Epic 2 decomposition and local-state contracts.
- **Targets are not support claims.** The PRD glossary identifies Ollama, LM Studio, MLX, and OpenRouter as committed targets and defines support only for a Qualified Adapter Combination. FR-14 prevents discovery, installation, model presence, health success, or adapter identity from marking a combination Ready; qualification is bound to recorded runtime/model/hardware/configuration evidence and known degradation.
- **One local path starts learning; four targets complete provider scope.** PRD §7.1 permits the continuity experiment only after one explicitly selected local Qualified Adapter Combination completes the governed Conversation-to-proposal loop; OpenRouter and deterministic fakes cannot satisfy that start condition. The same section requires Ollama, LM Studio, MLX, and OpenRouter plus the shared contract suite before complete provider-scope readiness, and stops adapter breadth from postponing a negative thesis decision.
- **No new authorization spike is introduced.** FR-14 calls qualification implementation acceptance evidence, FR-18 says fake-contract success cannot qualify production, the architecture spine treats compatibility and targeted integration tests as implementation acceptance rather than another pre-product spike, and addendum §8 explicitly prohibits a new authorization spike or Codex adapter validation.
- **Provider boundaries fail closed.** The PRD and architecture require explicit adapter/model selection, no silent fallback or resend, loopback-only Ollama and LM Studio endpoints, on-device MLX, explicit OpenRouter external processing and billing disclosure, Keychain-backed secrets, generation-only adapter authority, ProjectOS-owned Conversation and Change Proposal schemas, revalidation before persistence, explicit capability degradation, normalized failure states, and user review before Canonical State mutation.
- **Tracker status remains truthful.** `sprint-status.yaml` records Epic 1 and Stories 1.1–1.9 as `done`; it does not claim the rejected Codex gate passed or that Story 2.1 already exists or is implementation-ready. Story 2.1 status should be added through normal decomposition/story creation rather than inferred from the completed historical epic.
