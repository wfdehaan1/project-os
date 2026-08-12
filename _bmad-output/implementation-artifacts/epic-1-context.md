# Epic 1 Context: Prove a Safe AI Path—or Stop

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Establish reproducible evidence that a ProjectOS-owned, isolated Codex App Server process can use an eligible ChatGPT subscription safely while preserving local ownership, preventive containment, truthful provider-session cleanup, trustworthy non-coding structured output, and a provider-neutral application boundary. The only valid outcomes are `proceed`, `proceed with constraints`, or `reject`; failure of any mandatory gate blocks production Codex-adapter work.

## Recorded Outcome

Epic 1 completed with `reject`. Live managed authentication remained unproven, quality remained fake-backed, preventive containment was unavailable, and live Codex cleanup remained unproven. Production Codex App Server work remains blocked.

The approved 2026-08-09 architecture revision authorizes a different MVP provider stack: Ollama, LM Studio, and MLX as first-class local adapters, with OpenRouter as the optional external adapter. This does not reopen, bypass, or relabel the Codex result. The Story 1.x contracts, harness, and evidence remain historical inputs.

## Stories

- Story 1.1: Establish the Isolated App Server Harness
- Story 1.2: Pin and Exercise the Runtime Protocol Contract
- Story 1.3: Prove Subscription Authentication Without Credential Ownership
- Story 1.4: Normalize Allowance, Failures, and Terminal Job Outcomes
- Story 1.5: Validate Structured Output for Representative Project Work
- Story 1.6: Prove Preventive Execution Containment
- Story 1.7: Prove Portable Conversation Ownership and Restore Separation
- Story 1.8: Prove Crash-Safe Provider Session Cleanup
- Story 1.9: Prove Provider Neutrality and Record the Gate Decision

## Requirements & Constraints

- This is a disposable macOS validation harness, not a product implementation. It must not add production UI, migrate Canonical State, package for the App Store, implement fallback providers or local models, or enable production provider actions.
- A compatible installed runtime must be discovered through supported executable lookup, run as a ProjectOS-owned child over stdio JSON-RPC, and be proven compatible before provider work is enabled. Evidence must capture the exact runtime build, generated schemas and stable digests, allowed method set, test results, and a final recommendation.
- Subscription access must use Codex-managed ChatGPT browser sign-in and the plan allowance reported by Codex. ProjectOS must not request, receive, read, log, persist, export, or expose access tokens, refresh tokens, API keys, authorization headers, account identifiers, plaintext credential files, API credits, automatic top-up, or a silent API-key fallback. Secure storage failure must fail closed.
- The harness must normalize account, plan, allowance, runtime, network, provider, cancellation, and terminal-job states using explicit signals rather than vendor wording. Diagnostics and retained transcripts must be sanitized, actionable, correlation-ID based, and sufficient to reproduce a result without retaining credentials, account identity, project content, prompts, results, raw provider payloads, or local paths.
- Representative project-work fixtures must prove structured proposal quality before adoption: correctness of at least 85 percent, a predeclared evaluation denominator, no material omission that changes governing state or re-entry meaning, and no pending proposal from partial or malformed output.
- Every normal and hostile generation must be prevented from accessing or changing unrelated data, issuing commands, invoking tools/connectors, searching the web, making unapproved transmissions, or requesting permissions. Detection after an effect is not sufficient.
- Local project truth remains available and provider-independent. AI output can create only a pending Change Proposal; it never mutates Canonical State without a separate explicit user decision. Local deletion and provider cleanup must be reported as distinct, truthful outcomes.

## Technical Decisions

- Use a narrow ProjectOS-owned AI capability port and registry. Workflows express jobs, status, structured results, streaming, cancellation, and cleanup in ProjectOS types; Codex protocol types, session semantics, authentication, usage, and error details remain inside the adapter. Capabilities are evaluated at dispatch and declared as supported, unsupported, temporarily unavailable, or unknown.
- Launch and supervise a dedicated `codex app-server` process with a permission-restricted ProjectOS `CODEX_HOME`, disposable working directory, scrubbed allowlisted environment, documented initialization handshake, and owned-process cleanup/restart. It must not read, modify, list, depend on, or log out the normal Codex profile. Concurrent instances must isolate profiles or coordinate ownership.
- Support only exact runtime builds recorded in a compatibility manifest. Generate protocol schemas from the same executable used for probing and spawn; verify digests and the enumerated RPC subset, start with `experimentalApi: false`, fail closed on any mismatch, and never reuse an uncertain transport after failure.
- Runtime-owned authentication starts managed `account/login/start` with ChatGPT mode, opens Codex's returned browser URL, and observes account notifications. Codex owns token persistence and refresh in the macOS keychain. Device-code login is an optional, version-gated recovery capability only. Authentication, logout, and account switching affect the ProjectOS profile alone.
- Normalize provider events through durable ProjectOS job IDs, provider-instance IDs, ordering information, and a shared reducer that yields one terminal result despite duplicate, late, reordered, cross-job, retry, cancellation, timeout, or process-death events. Adapters cannot access domain repositories; one job coordinator owns idempotent pending-proposal persistence and revision checks.
- Define the Change Proposal schema in ProjectOS. Pass it as per-turn structured output, then parse and revalidate the completed response before the coordinator may persist a pending proposal. Exercise only explicit Context Preview content.
- Apply a restrictive execution envelope to every thread and turn: an explicitly restricted read set containing only the disposable directory and recorded runtime-required roots, no writable roots, `approvalPolicy: never`, no inherited instructions, MCP servers, apps, plugins, skills, connectors, or dynamic tools, and an allowlisted `instructionSources` result. Adoption requires a stable tool-disable mechanism or external OS containment that prevents side effects before they occur.
- ProjectOS owns canonical Conversation IDs and transcripts. Provider thread IDs are replaceable adapter-keyed bindings, excluded from exports. Offline restore creates a new local Project with remapped ProjectOS IDs and no binding; later user-initiated AI work creates a fresh binding.
- Create a minimal, content-free cleanup obligation before each provider-session creation. Persist only adapter/profile identifiers, a non-secret authentication-context fingerprint, opaque session ID, lifecycle state, retries, and timestamps. Reconcile idempotently after crashes; retain a cleanup receipt after local deletion until the provider session is confirmed deleted or absent, with matching-context reauthentication and residual-data disclosure when necessary.
- Prove the contract with the Codex adapter, a Codex-shaped fake, and a local-shaped fake that lacks selected capabilities. Replacing adapters must not require changes to Conversation, Change Proposal, Re-entry, export, deletion, domain, or persistence code.

## Cross-Story Dependencies

- The isolated harness and exact protocol gate establish the process, profile, compatibility, and evidence boundary used by all later stories.
- Authentication and normalized runtime states underpin allowance testing, structured-output jobs, containment, session lifecycle, and the final decision; secure credential ownership is a hard stop condition.
- Structured-output quality, preventive containment, session cleanup, and fake-adapter proof are independent hard gates. Story 1.9 audits their evidence and may authorize Epic 2 only after all five stop conditions pass; runtime distribution, supported-version range, and local-model timing remain post-spike decisions.
