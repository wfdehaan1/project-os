---
title: Codex App Server Provider Validation Spike
status: ready
created: 2026-07-31
updated: 2026-07-31
depends_on: ARCHITECTURE-SPINE.md
---

# Codex App Server Provider Validation Spike

## Objective

Determine whether Codex App Server is a safe and viable first ProjectOS AI Provider Adapter while proving that the provider abstraction remains usable by future cloud and local adapters.

The spike is complete only when it produces reproducible evidence. A successful browser login or one plausible response is insufficient.

## Scope

- A disposable macOS harness using an installed Codex CLI and a ProjectOS-owned App Server process over stdio.
- A thin `AiProviderPort`, Codex adapter, and deterministic fake adapter.
- No production UI, Canonical State migration, App Store packaging, provider fallback, or local-model implementation.

## Test matrix

### 1. Runtime and protocol

- Discover the installed `codex` executable without reading a private ChatGPT application bundle path.
- Start `codex app-server`, complete `initialize` / `initialized`, and shut down only the owned child process.
- Record the exact Codex version and generate protocol schemas from that binary.
- Record generated-schema digests and the enumerated RPC subset; prove exact-build acceptance and different-build failure with an actionable message.
- Capture startup crash, malformed JSON, unexpected EOF, timeout, and restart behavior.
- Record the effective ProjectOS Codex state/configuration root and prove login, logout, thread creation, and deletion leave an independently configured normal Codex profile unchanged.
- Start two harness instances and prove they coordinate one profile safely or use isolated profiles without crossing accounts, sessions, or process ownership.

**Gate:** no provider action is enabled until runtime and protocol compatibility are known.

### 2. ChatGPT authentication and entitlement

- Read signed-out account state.
- Start managed browser login, open the returned URL, and observe successful completion.
- Verify a personal Pro account reports ChatGPT auth and its plan type.
- Exercise cancelled login, expired login, and logout. When the supported runtime and account expose device-code login, exercise it as an optional recovery path; otherwise record it as unsupported without failing the primary browser-login gate.
- With active and cleanup-pending sessions, exercise logout and account switching; verify cleanup is attempted first and any residual obligation becomes `reauthRequired` for the matching non-secret authentication context.
- Verify ProjectOS receives no access or refresh token and writes none to logs or fixtures.
- Verify the ProjectOS-scoped Codex configuration forces ChatGPT login, stores credentials in the macOS keyring, and does not create a plaintext `auth.json` fallback.
- Confirm no OpenAI API key is configured or requested by the harness.

**Gate:** the adapter can establish and end a subscription-authenticated session without ProjectOS handling credentials or API credits.

### 3. Allowance and failure states

- Read all returned rate-limit buckets, used percentages, window durations, reset timestamps, and reached-limit classification.
- Confirm UI-facing values derive from the response and do not hard-code a weekly period.
- Exercise rate limiting, exhausted allowance, network loss, upstream failure, authentication expiry, and successful retry.
- Verify allowance exhaustion pauses provider work while local ProjectOS behavior remains available.
- Replay duplicate, delayed, reordered, cross-job, cancellation-race, and child-death traces and verify the shared reducer always produces one deterministic terminal state.
- Verify persisted diagnostics contain only allowlisted normalized codes, runtime version, timestamps, and ProjectOS correlation IDs.

**Gate:** normalized states distinguish authentication, runtime, network, rate, allowance, and provider failures only when explicit signals support the distinction; unknown failures stay unknown. No path offers credit purchase or silent API-key fallback, and diagnostic records contain no credentials, account IDs, Project content, prompts/results, or local paths.

### 4. ProjectOS jobs and structured output

Run at least three representative inputs:

1. Garden-office utility research with conflicting constraints and a proposed Decision, Research item, Open Question, and Task.
2. Used-car variant comparison with a governing preference, alternatives, evidence, and unresolved question.
3. A technical project conversation with a superseding Decision and dependency effects.

Before execution, annotate each fixture with the expected material Facts, Decisions, Open Questions, Tasks, and Research. Establish a minimum evaluated-item denominator. For each input:

- supply only an explicit Context Preview payload;
- request the ProjectOS Change Proposal schema through per-turn structured output;
- validate the result again inside ProjectOS;
- record precision and recall separately by artifact type, unsupported claims, provenance quality, and correction effort; and
- exercise streaming, cancellation, partial output, and retry.

**Gate:** correctness is at least 85%, no omission changes governing current state or re-entry meaning, the predeclared minimum denominator is met, and malformed output never becomes a Change Proposal.

### 5. Execution containment

- Use a dedicated disposable working directory and the most restrictive supported sandbox/read policy.
- Register no dynamic tools, MCP servers, connectors, or skills.
- Detect any command execution, file change, filesystem discovery beyond supplied context, or unrelated network/tool request.
- Verify no test changes project files or reads unrelated project content.
- Retain the effective sandbox configuration and returned `instructionSources`; prove allowed-root reads succeed, outside-root reads fail, and non-empty user-level Codex configuration cannot affect a ProjectOS job.
- Add prompt-injection, symlink/path traversal, inherited MCP/tool configuration, environment-secret canary, filesystem-read, filesystem-write, web-search, and command-attempt fixtures.

**Gate:** ordinary and hostile-input ProjectOS generation succeeds with zero unrelated read, transmission, mutation, command, file-change, web-search, connector, or permission activity. Detection after access or side effects fails the gate.

### 6. Conversation and provider-session lifecycle

- Map one ProjectOS Conversation to one Codex thread binding.
- Resume after process restart while keeping ProjectOS as the canonical transcript owner.
- Export and restore a Conversation without exporting the binding; create a new binding on resumed AI work.
- Delete a Conversation binding and a Project containing multiple bindings using documented provider deletion.
- Verify persisted Codex rollout files and metadata are removed or report cleanup incomplete with a retry path.
- Kill and restart the harness after every create-intent, bind, rebind, archive, local-delete, and provider-delete side effect; startup reconciliation must retain every cleanup target.
- Retry cleanup after local Project content and ordinary bindings are gone, while offline, after adapter removal or rename, after account switching, and when the provider session is already absent.
- Inspect exports for bindings, provider session IDs, credentials, runtime caches, and diagnostics; restore offline, twice, beside the source Project, with ID collisions, unknown adapter metadata, and an older schema. Every restore must create a new Project copy and atomically remap all Project-owned IDs while preserving relationships and Provenance; restore makes zero provider calls.

**Gate:** local deletion and provider cleanup report separate truthful outcomes. A minimal outbox receipt enables idempotent retry without retaining Project content; no known session is forgotten or falsely reported clean. Export and restore preserve equivalent Canonical State without provider state.

### 7. Provider abstraction proof

Run the same contract suite against the Codex adapter, a Codex-shaped fake, and a local-shaped fake with no authentication, usage reporting, persistent sessions, or provider deletion and configurable absence of streaming or structured output. Cover:

- health and capabilities;
- generation and streaming;
- cancellation;
- structured results;
- unsupported usage reporting;
- authentication-required and runtime-unavailable states;
- session create/resume/delete; and
- cleanup failure.

Also replay duplicate completion, timeout/retry, concurrent turns, stale Canonical-State revisions, and cancellation/completion races. Change adapter capabilities after registry load and re-resolve dispatch.

Inspect dependencies to confirm ProjectOS domain and persistence modules import no Codex protocol types.

**Gate:** replacing the registry entry with either fake requires no change to Conversation, Change Proposal, Re-entry, export, or deletion workflows. Race and retry fixtures create at most one pending proposal, never mutate Canonical State, and capability changes never silently change locality, billing, privacy, or output guarantees. Dependency checks prove adapters cannot invoke domain repositories.

## Evidence to retain

- Exact Codex version and generated protocol schemas.
- Sanitized JSON-RPC transcripts with tokens, account identifiers, project content, and local paths removed.
- Contract-test output and failure fixtures.
- Quality scoring sheets for all representative inputs.
- Filesystem before/after evidence for containment and thread deletion.
- A short recommendation: proceed, proceed with constraints, or reject the Codex adapter.

## Stop conditions

- Subscription-authenticated usage cannot be established without ProjectOS handling tokens or API credits.
- Codex cannot perform the representative non-coding jobs at the correctness and completeness gate.
- The adapter cannot prevent unintended filesystem access, mutation, command effects, tool use, or external transmission before they occur; detection alone is insufficient.
- Persisted provider sessions cannot be enumerated and deleted consistently.
- A second fake adapter exposes Codex assumptions in ProjectOS domain workflows that require structural rewrites.

## Post-spike decisions

Only after the gates pass should architecture decide whether the commercial application requires an installed Codex runtime or bundles a pinned one, which runtime versions are supported, and when to implement the first local-model adapter.
