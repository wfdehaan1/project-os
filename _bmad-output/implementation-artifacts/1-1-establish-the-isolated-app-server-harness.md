---
baseline_commit: 40d16553e9ae5109e97b8bc607c28f3ce5385a61
---

# Story 1.1: Establish the Isolated App Server Harness

Status: done

<!-- Ultimate context engine analysis completed - comprehensive developer guide created. -->

## Story

As a ProjectOS builder,
I want a disposable provider-neutral harness that owns an isolated Codex App Server process,
so that all later viability tests run against a controlled and reproducible boundary.

## Acceptance Criteria

1. **Given** an installed Codex CLI discoverable through supported executable lookup
   **When** the harness starts a validation run
   **Then** it discovers the executable without reading a private ChatGPT application-bundle path
   **And** records the resolved executable and exact Codex version as evidence.

2. **Given** the discovered runtime
   **When** the harness starts `codex app-server`
   **Then** it communicates over stdio JSON-RPC and completes `initialize` followed by `initialized`
   **And** it terminates only the child process it owns.

3. **Given** the harness creates its runtime environment
   **When** the Codex child starts
   **Then** it receives a dedicated permission-restricted ProjectOS `CODEX_HOME`, a disposable working directory, and a scrubbed allowlisted environment
   **And** the effective paths and non-secret configuration are recorded for verification.

4. **Given** a separately configured normal Codex profile exists
   **When** the harness starts, initializes, and shuts down its child
   **Then** the normal profile's configuration, authentication, sessions, and processes remain unchanged
   **And** a before/after check records that isolation.

5. **Given** the thin `AiProviderPort` and Codex adapter boundary
   **When** the harness performs runtime health and lifecycle operations
   **Then** callers use ProjectOS-owned request, result, status, and lifecycle types
   **And** Codex protocol types remain confined to the adapter.

6. **Given** runtime discovery, initialization, or owned shutdown fails
   **When** the harness reports the result
   **Then** it produces a sanitized, actionable failure with a ProjectOS correlation identifier
   **And** no production provider action or Canonical State operation is enabled.

7. **Given** Story 1.1 scope
   **When** its implementation is reviewed
   **Then** it contains no production UI, Canonical State migration, App Store packaging, provider fallback, or local-model implementation
   **And** its retained evidence can be reproduced on the same supported macOS environment.

## Tasks / Subtasks

- [x] 1. Create the disposable harness workspace (AC: 7)
  - [x] Add `spikes/codex-app-server-harness/` as an isolated Node.js/TypeScript workspace; do not create a production app scaffold or select the future SwiftUI/AppKit architecture.
  - [x] Pin Node.js 24 LTS as the reproducible baseline, commit `package-lock.json`, and add scripts for `typecheck`, deterministic tests, opt-in live smoke, and a full validation run.
  - [x] Use ESM, strict TypeScript, Node's built-in test runner, and Node standard-library process/filesystem/crypto APIs. Avoid runtime/framework dependencies unless an AC cannot be met without one.
  - [x] Document prerequisites, the same-environment reproduction command, exit codes, evidence locations, and the boundary with Stories 1.2–1.9.

- [x] 2. Define the thin ProjectOS-owned provider lifecycle seam (AC: 5, 6)
  - [x] Define ProjectOS-owned runtime request, lifecycle phase, health result, failure code, remediation metadata, and correlation-ID types outside the Codex adapter.
  - [x] Model lifecycle explicitly: `undiscovered -> discovered -> starting -> initializing -> initialized -> stopping -> stopped`, with terminal `failed`; late process or transport events must not revive a failed/stopped run.
  - [x] Keep success limited to local runtime initialization/isolation. Do not name it authenticated, online, OpenAI-ready, model-ready, or production-ready.
  - [x] Keep all Codex wire request/response/notification shapes private to `src/adapters/codex/`; public port modules must not import them.
  - [x] Provide distinct stable failure codes for not found, non-executable, version probe failure, spawn failure, initialization rejection, malformed handshake response, initialization timeout, unexpected exit/EOF, shutdown timeout/failure, isolation failure, and evidence-write failure. Do not collapse these into `offline`, a Boolean, or raw `Error(String)` parsing.

- [x] 3. Implement supported executable discovery and version evidence (AC: 1, 6)
  - [x] Search the invoking environment's ordered `PATH` without a shell, resolve candidates to absolute real paths, require a regular executable, and reject private `.app/Contents/...` bundle candidates.
  - [x] Spawn the resolved absolute executable with an argument array and `shell: false`; never use `which` through a shell, private ChatGPT bundle probing, a hard-coded Homebrew path, or global daemon discovery.
  - [x] Run a bounded `codex --version` probe and record the exact returned build string. Do not hard-code the locally observed `codex-cli 0.145.0` as the supported version; Story 1.2 owns compatibility pinning and schema digests.
  - [x] Make discovery injectable so deterministic tests use fake executables rather than the developer's real Codex installation.

- [x] 4. Create and verify the isolated runtime environment (AC: 3, 4, 6)
  - [x] Create a unique per-run runtime root, `CODEX_HOME`, `CODEX_SQLITE_HOME`, disposable `HOME`, working directory, and temporary directory with unpredictable names, directory mode `0700`, no symlink traversal, and sensitive files mode `0600`.
  - [x] Ensure `CODEX_HOME` exists before spawn. Write a minimal strict configuration that forces ChatGPT authentication, macOS keyring credential storage, and disabled analytics, with no provider/tool entries in the isolated profile; actual login is Story 1.3 and proof against system-managed inherited capabilities is Story 1.6.
  - [x] Build the child environment from an explicit allowlist. Set isolated `HOME`, `CODEX_HOME`, `CODEX_SQLITE_HOME`, `TMPDIR`, deterministic locale values, and a minimal system `PATH`; pass certificate configuration only through an explicit harness option. Do not copy the parent environment wholesale.
  - [x] Exclude API/access tokens, provider keys, `SSH_AUTH_SOCK`, proxy variables by default, MCP/app/plugin/skill variables, and unrelated secret-bearing values. Record allowed variable names and safe fingerprints, never secret values.
  - [x] Start from a synthetic separately configured normal-profile fixture with sentinel files and an unrelated sentinel process. Compare hashes/metadata and liveness before and after; never copy, parse, or fixture a real token store.
  - [x] Fail closed if an isolated root falls back to the real home/profile, permissions cannot be enforced, strict configuration is rejected, or the isolation comparison changes.

- [x] 5. Implement owned App Server transport and supervision (AC: 2, 5, 6)
  - [x] Spawn the resolved executable as `codex app-server --stdio --strict-config` with piped stdin/stdout/stderr and no daemon, proxy, WebSocket listener, shell, or inherited terminal.
  - [x] Implement newline-delimited JSON-RPC framing on stdout only. Keep stderr separate and memory-bounded; do not treat stderr as protocol or persist it raw.
  - [x] Send one `initialize` request with ProjectOS client metadata and `capabilities.experimentalApi: false`, wait for the matching response under a bounded timeout, validate the response shape, then send the `initialized` notification. Do not start a thread, turn, authentication, network, model, or provider action.
  - [x] Retain the exact child handle/PID as the ownership authority. On every success/failure/abort/evidence-write path, close stdin, wait briefly, send `SIGTERM` only to the recorded child (or a verified newly created process group owned by it), then `SIGKILL` only after a bounded timeout. Never use `pkill`, `killall`, daemon-wide shutdown, PID lookup by name, or the user's normal Codex process list as a termination target.
  - [x] Distinguish clean exit, graceful termination, forced termination, unexpected exit, and shutdown failure in ProjectOS-owned results and evidence.

- [x] 6. Retain reproducible evidence without leaking diagnostics (AC: 1, 3, 4, 6, 7)
  - [x] Define a versioned evidence schema and write atomically into a harness-local ignored `.evidence/<run-id>/` directory so partial runs remain inspectable.
  - [x] Store controlled local evidence (mode `0600`) containing the exact resolved executable path and effective isolated paths required by the AC. Keep these paths out of failure diagnostics and shareable output.
  - [x] Produce a separate sanitized summary with correlation ID, timestamps, harness/tool/runtime versions, safe configuration fingerprints, lifecycle phases, handshake outcome, shutdown outcome, isolation comparison, and reproduction command.
  - [x] Never persist credentials, account identifiers, environment values, authorization headers, real normal-profile contents, raw protocol payloads, raw stderr, Project content, prompts/results, or unrelated local paths.
  - [x] Make evidence failure itself terminal and still attempt owned child cleanup; do not report a validation pass if required evidence was not retained.

- [x] 7. Add deterministic contract tests and an opt-in live macOS smoke test (AC: 1–7)
  - [x] Test discovery success plus missing, non-executable, broken-symlink, private-app-bundle rejection, version timeout, non-zero exit, and malformed version output.
  - [x] Use a fake executable fixture to test strict `initialize`/`initialized` ordering, matching response ID, JSONL framing, malformed response, EOF, timeout, spawn failure, and unexpected child exit without network/account access.
  - [x] Test unique runtime roots, `0700`/`0600` permissions, symlink rejection, exact environment allowlisting, secret-variable exclusion, no real-profile fallback, unchanged normal-profile sentinels, and unrelated-process liveness.
  - [x] Test every termination path, including initialization timeout, parse failure, assertion failure, evidence-write failure, and forced termination; prove only the owned child/process group is affected and no child remains.
  - [x] Add a dependency-boundary test proving public provider modules import no Codex protocol types and the adapter has no Canonical State, Conversation, proposal, export, or deletion repository access.
  - [x] Validate evidence schema completeness and forbidden-value absence for successful and partial/failed runs.
  - [x] Keep default CI/tests deterministic and offline. Gate the real installed-CLI smoke test behind an explicit command; it may discover and initialize only, never authenticate or start a provider turn.

## Dev Notes

### Why This Story Exists

Epic 1 is an evidence gate, not product feature delivery. It must decide whether Codex App Server can become a safe first adapter before production implementation absorbs Codex assumptions. Story 1.1 creates the controlled process/profile/transport boundary used by every later spike story. A plausible response, successful login, or UI demonstration is not success here.

Story 1.1 directly implements the initial parts of AR1–AR5 and supports the provider-neutrality requirements in FR18/NFR13. It does not directly deliver an end-user FR. [Source: `_bmad-output/planning-artifacts/epics.md#Epic-1-Prove-a-Safe-AI-Path—or-Stop`] [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md#47-Provider-Independence`]

### Scope Boundaries

Implement only executable discovery, exact version capture, isolated runtime/profile construction, stdio initialization, owned shutdown, thin ProjectOS-owned lifecycle types, sanitized correlated failures, evidence, and tests.

Do **not** implement:

- production UI, First Run, Settings, status badges, localization, accessibility surfaces, or native app shell;
- any Project, Conversation, Canonical State, Change Proposal, export, restore, or deletion persistence;
- generated protocol schemas/digests, supported-build manifest, full RPC enumeration, restart matrix, or two-instance coordination (Story 1.2);
- managed login/logout, token/keyring proof, plan/account state, or credential leak audit (Story 1.3);
- allowance/error taxonomy beyond Story 1.1 lifecycle failures, job-event reduction, cancellation races, or retry idempotency (Story 1.4);
- provider turns, structured output, representative fixtures, quality scoring, or proposal persistence (Story 1.5);
- hostile-input or preventive filesystem/tool/network containment proof (Story 1.6); Story 1.1 profile/environment isolation must not be described as full containment;
- Provider Session Bindings, export/restore identity, cleanup outbox, thread deletion, or provider-neutrality gate decision (Stories 1.7–1.9);
- API-key setup, API credits, provider fallback, Ollama/local models, Mac App Store packaging, commercial runtime distribution, pricing, or collaboration.

[Source: `_bmad-output/planning-artifacts/epics.md#Story-11-Establish-the-Isolated-App-Server-Harness`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/validation-spike.md#Scope`] [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/addendum.md#7-Deferred-Scope-and-Rejected-Expansion`]

### Architecture Compliance

- Follow Ports and Adapters with capability negotiation. For this story, build only the thin lifecycle/health port and concrete Codex adapter; full registry/capability proof remains later.
- ProjectOS owns request/result/status/lifecycle types. Codex authentication, threads, JSON-RPC shapes, runtime paths, and errors must not leak into domain-facing modules.
- Start and supervise a ProjectOS-owned `codex app-server` child over stdio. Do not couple to ChatGPT desktop processes, app bundles, undocumented ports, or daemon/global state.
- Use a ProjectOS-scoped `CODEX_HOME` and dedicated state/config/environment boundary. Default-profile non-interference is an executable test, not an assumption.
- A lifecycle failure is fail-closed. No provider action, model call, or Canonical State mutation exists in this harness.
- Raw payloads remain memory-only. Persist only allowlisted evidence/diagnostic fields. Required exact paths belong in permission-restricted local evidence, not sanitized diagnostics.
- The adapter cannot access domain repositories. Application-owned mutation/idempotency from AD-12 remains structurally possible later but is not implemented here.

[Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#Paradigm`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#AD-1--Domain-facing-AI-port-ADOPTED`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#AD-4--Initial-Codex-process-boundary-ADOPTED`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#AD-7--Normalized-event-and-error-model-ADOPTED`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#AD-13--Isolated-Codex-runtime-profile-ADOPTED`]

### Story-Level Implementation Stack Decision

No brownfield implementation or starter stack exists, and the architecture deliberately does not select the production language. Use a standalone **Node.js 24 LTS + TypeScript** spike workspace because:

- the official App Server quickstart uses Node.js/TypeScript child-process and readline primitives;
- the CLI can generate TypeScript/JSON schemas in Story 1.2;
- the harness is disposable and cannot bind the future native SwiftUI/AppKit product stack;
- Node's standard library covers process supervision, JSONL, temporary directories, permissions, hashing, UUIDs, and tests without framework dependencies.

Baseline:

- Pin Node.js `24.18.1` (current LTS on 2026-07-31) for reproducibility. Node 24.12+ has stable built-in TypeScript type stripping.
- Use TypeScript `~7.0.2` for `tsc --noEmit`; use only erasable TypeScript syntax at runtime. If TypeScript 7 tooling incompatibility appears, pin `@typescript/typescript6 ~6.0.2` and record the deviation—do not silently broaden dependencies.
- Use `@types/node` major 24, npm, ESM (`"type": "module"`), mandatory `.ts` import extensions, and `node:test`/`node:assert`.
- Recommended compiler options: `strict`, `noEmit`, `target: esnext`, `module: nodenext`, `rewriteRelativeImportExtensions`, `allowImportingTsExtensions`, `erasableSyntaxOnly`, `verbatimModuleSyntax`, `noUncheckedIndexedAccess`, and `exactOptionalPropertyTypes`.
- Do not add `tsx`, a JSON-RPC framework, a process manager, a CLI framework, a logging framework, a schema library, or a test framework unless the implementation proves a concrete need that standard APIs cannot meet.

This is a story-level spike choice, not an inherited production architecture decision. [Source: `https://learn.chatgpt.com/docs/app-server#app-server-quickstart`] [Source: `https://nodejs.org/en/about/previous-releases`] [Source: `https://nodejs.org/api/typescript.html`] [Source: `https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/`]

### File Structure Requirements

All implementation files are new; no existing application file is marked UPDATE.

```text
spikes/codex-app-server-harness/
  .gitignore
  README.md
  package.json
  package-lock.json
  tsconfig.json
  src/
    core/
      ai-provider-port.ts
      lifecycle.ts
      failures.ts
    adapters/
      codex/
        protocol.ts
        executable-discovery.ts
        runtime-profile.ts
        jsonl-rpc-connection.ts
        app-server-supervisor.ts
        codex-app-server-adapter.ts
    evidence/
      evidence-schema.ts
      evidence-recorder.ts
      sanitizer.ts
    cli.ts
  test/
    fixtures/
      fake-codex-runtime.ts
    executable-discovery.test.ts
    runtime-profile.test.ts
    jsonl-handshake.test.ts
    process-ownership.test.ts
    adapter-boundary.test.ts
    evidence.test.ts
    live-macos.smoke.test.ts
  evidence/
    README.md
    harness-run.schema.json
```

- `.evidence/` is local, permission-restricted, retained run output and must be ignored by the harness-local `.gitignore`.
- `evidence/README.md` and the evidence schema are committed contracts; do not commit real local run evidence or credentials.
- Keep port/core modules free of `codex` imports. Keep protocol parsing and raw runtime data inside `adapters/codex`.
- Do not modify `_bmad-output` planning artifacts, architecture documents, UX documents, or superseded `docs/ProjectWorkspace.md` during implementation.
- Root `.gitignore` already covers `node_modules`, `dist`, logs, `.env`, and local files. Update it only if an actually generated disposable path is not covered; prefer the harness-local ignore file.

### Existing Files and Behaviors to Preserve

There is no application code to update. The repository currently contains planning artifacts, BMad tooling, and mockups only. Preserve:

- the user's normal Codex profile, auth state, configuration, sessions, processes, extensions, and unrelated files;
- all current planning/UX/architecture artifacts and user-owned untracked sprint/epic files;
- local-first operation and the rule that lifecycle inspection alone never transmits Project content;
- provider-neutral public types despite a concrete Codex adapter;
- an unambiguous separation between local runtime initialization and later authentication/model/provider readiness;
- truthful partial/failed evidence—never report readiness or completion after an evidence, isolation, initialization, or shutdown failure.

The only likely existing file that could need implementation-time adjustment is root `.gitignore`; no change is expected with the proposed layout. [Source: `.gitignore`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-rubric.md#Good-spine-checklist`]

### Runtime Discovery and Process Guardrails

- `PATH` lookup must be deterministic, shell-free, and injectable. The first executable regular-file candidate wins after `realpath` and private-bundle rejection.
- Record both the candidate and resolved path only in controlled local evidence. Sanitized summaries may include filename, digest/fingerprint, and version but no unrelated absolute paths.
- Treat the locally observed `codex-cli 0.145.0` and `/opt/homebrew/bin/codex` only as environment observations. Never hard-code either; the dev run must capture current values.
- Explicitly select stdio (`--stdio`) even though it is the current default. JSON-RPC messages are newline-delimited JSON with the `jsonrpc` header omitted on the wire.
- `initialize` is once per connection, must precede every other method, and must be followed by `initialized`. Pre-initialization or repeated initialization errors are protocol facts; the richer compatibility/fault suite belongs to Story 1.2.
- There is no documented App Server shutdown RPC. Shutdown is owned process management: close transport, bounded wait, `SIGTERM`, bounded wait, and owned-child `SIGKILL` fallback.
- Always clean up on error/finally paths. Transport EOF is evidence, not proof that every owned process is gone.

[Source: `https://learn.chatgpt.com/docs/app-server#protocol`] [Source: `https://learn.chatgpt.com/docs/app-server#initialization`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-current-platform.md#Medium--graceful-server-shutdown-is-not-a-documented-RPC-contract`]

### Isolation and Privacy Guardrails

- `CODEX_HOME` roots Codex config, auth, logs, sessions, skills, and package state and must already exist. Never leave it unset or point it at `~/.codex`.
- Use `cli_auth_credentials_store = "keyring"`, not `auto`, because `auto` may fall back to plaintext `auth.json`. Use `forced_login_method = "chatgpt"`; do not configure an API-key path.
- Story 1.1 proves profile/environment separation only. Story 1.3 proves actual login, keyring behavior, token non-ownership, and logout isolation.
- Story 1.1 does not prove preventive agent containment. A dedicated `CODEX_HOME`, disposable cwd, and scrubbed environment are necessary but insufficient for the Story 1.6 gate.
- The future UI needs stable codes and safe remediation metadata. Do not embed vendor strings or English display copy into domain-facing error contracts.
- Exact local paths explicitly required by AC1/AC3 are evidence fields, not persisted diagnostics. Keep the evidence store private and the shareable summary sanitized.

[Source: `https://learn.chatgpt.com/docs/config-file/environment-variables#core-locations`] [Source: `https://learn.chatgpt.com/docs/auth#credential-storage`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#AD-5--Runtime-owned-authentication-ADOPTED`] [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md#State-Patterns`]

### Testing Requirements

The default test suite must be deterministic, offline, account-free, and safe to run beside an active normal Codex session. Use fake executables and temporary synthetic profiles. The live macOS smoke is opt-in and still performs only version capture plus initialize/initialized/shutdown.

| Area | Required proof |
|---|---|
| Discovery | PATH ordering; absolute realpath; X_OK; missing/non-executable/broken symlink/private bundle; bounded version probe |
| Transport | JSONL framing; matching IDs; initialize before initialized; no thread/turn/provider request |
| Lifecycle | deterministic phases; timeout/EOF/exit/shutdown outcomes; late events cannot revive terminal state |
| Ownership | every failure path reaps only the recorded child/process group; unrelated process remains alive |
| Isolation | unique 0700 roots; 0600 files; no symlink escape; strict config; allowlisted environment; no real-profile fallback |
| Non-interference | synthetic normal-profile hashes/metadata and sentinel process unchanged before/after |
| Boundary | no Codex protocol import in public/core modules; adapter has no domain repository access |
| Privacy | local versus sanitized evidence separation; forbidden secret/account/content/raw/path fields absent |
| Reproduction | one documented command produces evidence on the same supported macOS environment |

Tests must assert negative behavior, not merely the happy path. A smoke that prints an initialize response is insufficient.

### UX-Relevant Constraints Without UI Work

- Use named truthful phases; never fabricate percentages.
- Preserve distinct machine-readable discovery, initialization, exit, shutdown, and isolation outcomes so later UI can localize and expose accessible remedies.
- Do not call runtime initialization `OpenAI ready`, `authenticated`, or `online`.
- Never collapse local runtime errors into generic `Offline` or `Connection error`.
- Keep local capabilities conceptually available while provider work is disabled; this harness must not contain a path that queues or performs provider work.

[Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md#Voice-and-Tone`] [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md#Global-state-model`] [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/DESIGN.md#Components`]

### Previous Story Intelligence

There is no previous story. Story 1.1 is the first implementation unit in Epic 1, and no implementation artifact or application code exists to inherit.

### Git Intelligence Summary

- `40d1655 Refine project workspace implementation` is UX/documentation-only and establishes no harness code convention.
- `d65d867 docs: adopt provider-independent Codex integration` introduced the final architecture spine, validation spike, reviews, and reconciled provider direction; its final review addenda report no remaining critical/high findings.
- `351f0f5 docs: finalize ProjectOS validation PRD` established the final validation scope. Later 2026-07-31 provider reconciliation overrides older API-key/Ollama assumptions.
- Do not infer a production stack from the repository history; it contains documentation only.

### Latest Technical Information (verified 2026-07-31)

- Official Codex guidance describes App Server as the deep-integration surface, with default stdio transport using newline-delimited JSON and a mandatory `initialize` then `initialized` handshake.
- App Server schema generation is exact-version-specific; generation/digests are deliberately deferred to Story 1.2.
- `CODEX_HOME` controls config, auth, logs, sessions, skills, and package state and must exist before startup.
- The installed environment currently reports `codex-cli 0.145.0`; `codex app-server` and its schema generators still label themselves experimental. Record the runtime actually discovered during implementation rather than treating this observation as compatibility policy.
- Node.js 24 is LTS; Node 24.12+ supports stable built-in TypeScript type stripping. Node does not type-check or honor `tsconfig.json` at runtime, so keep `tsc --noEmit` as an explicit gate.
- TypeScript 7.0 is current but has a new native compiler and no programmatic API in 7.0. This harness needs only the CLI; keep a recorded TypeScript 6 fallback rather than adopting tooling that depends on the compiler API.

[Source: `https://learn.chatgpt.com/docs/app-server`] [Source: `https://learn.chatgpt.com/docs/config-file/environment-variables`] [Source: `https://nodejs.org/en/about/previous-releases`] [Source: `https://nodejs.org/api/typescript.html`] [Source: `https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/`]

### Project Context Reference

- No `project-context.md` file exists in the repository.
- Governing source order is the final product brief/addendum, current Codex subscription reconciliation, final PRD/addendum, final architecture spine/spike, then final UX spines. `docs/ProjectWorkspace.md` is explicitly superseded and must not drive implementation.
- The broader product is local-first, one owner, provider-neutral at the domain boundary, and human-governed; the validation build has no ProjectOS-hosted project-content backend.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story-11-Establish-the-Isolated-App-Server-Harness`]
- [Source: `_bmad-output/planning-artifacts/epics.md#Epic-1-Prove-a-Safe-AI-Path—or-Stop`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/validation-spike.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-current-platform.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-adversarial.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-rubric.md`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md#47-Provider-Independence`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/addendum.md#5-Provider-and-Privacy-Decisions`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/reconcile-codex-subscription-access-2026-07-31.md`]
- [Source: `_bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/brief.md`]
- [Source: `_bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/addendum.md#Provider-Independent-AI-Direction-2026-07-31`]
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md`]
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/DESIGN.md`]
- [OpenAI Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [OpenAI Codex environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables)
- [OpenAI Codex authentication](https://learn.chatgpt.com/docs/auth)
- [Node.js releases](https://nodejs.org/en/about/previous-releases)
- [Node.js TypeScript support](https://nodejs.org/api/typescript.html)
- [TypeScript 7.0 announcement](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/)

## Dev Agent Record

### Agent Model Used

OpenAI Codex (GPT-5)

### Debug Log References

- 2026-07-31: RED `workspace pins the disposable harness contract` failed on the absent workspace contract; GREEN passed after adding the pinned ESM/TypeScript workspace and documentation.
- 2026-07-31: RED core contract tests failed on missing lifecycle/failure modules; GREEN passed with explicit terminal lifecycle semantics and all twelve stable failure codes.
- 2026-07-31: RED discovery tests failed on the absent adapter; GREEN covered ordered PATH lookup, realpath/X_OK, private-bundle and broken-link rejection, and bounded version failure modes. The macOS `/var` test expectation was corrected to assert the required realpath (`/private/var`).
- 2026-07-31: RED runtime-profile tests failed on the absent isolation module; GREEN passed for unique restricted roots/config, exact allowlisting, secret exclusion/fingerprinting, synthetic-profile metadata/digest stability, unrelated-process liveness, and fail-closed symlink/profile fallback.
- 2026-07-31: RED App Server tests failed on the absent supervisor; GREEN passed for strict argv/stdio, JSONL ordering and matching response validation, rejection/malformed/EOF/timeout/exit/spawn mapping, bounded stderr fingerprints, and owned process-group cleanup. Slow-start fake-runtime deadlines were made deterministic and pre-listener EOF/exit races were closed.
- 2026-07-31: RED evidence tests failed on missing recorder/adapter modules; GREEN passed for schema-v1 private/sanitized separation, `0600` atomic JSON writes, truthful partial failures, forbidden-field/path exclusion, and evidence-failure reporting only after owned-child cleanup.
- 2026-07-31: RED final contract coverage exposed the missing CLI, post-handshake assertion cleanup, and forced-termination timing; GREEN passed after adding the CLI, an explicit assertion seam, stable fake-runtime timing, adapter boundary checks, schema-complete pre-discovery failure evidence, and the gated live macOS smoke.

### Implementation Plan

- Build the standalone ESM/TypeScript harness in story task order with offline `node:test` coverage driving each boundary.
- Keep ProjectOS-owned lifecycle and failure contracts in `src/core`, all Codex wire types private to `src/adapters/codex`, and evidence split into private and sanitized forms.
- Use injectable discovery/spawn/time/filesystem seams so deterministic tests never require an account, network, or the developer's live Codex profile.
- Finish with full offline tests, typecheck, a boundary scan, and an opt-in live smoke validation run.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story prepared for implementation; no production code has been written by create-story.
- Task 1: Created the isolated Node.js 24.18.1/TypeScript workspace with deterministic, live-smoke, typecheck, and full-validation scripts; documented reproduction, evidence, exit codes, and scope boundaries. Workspace contract test passes.
- Task 2: Added provider-neutral request/result/lifecycle/remediation contracts and fail-closed correlated failures. Core contract tests pass, including late-event terminal-state protection.
- Task 3: Implemented shell-free injectable discovery and bounded exact version capture. Seven offline tests pass after covering all specified discovery/version negative cases.
- Task 4: Added isolated per-run paths, strict ChatGPT/keyring/no-analytics configuration, scrubbed child environments, and synthetic normal-profile snapshot comparison. Eleven offline tests pass.
- Task 5: Added private Codex protocol shapes, JSONL handshake transport, and exact-child/process-group supervision with clean/graceful/forced outcomes. Nineteen offline tests pass.
- Task 6: Added the versioned evidence contract, sanitizer, atomic recorder, and end-to-end adapter orchestration. Twenty-three offline tests pass; an evidence-write failure cannot produce a pass and leaves no owned Codex child running.
- Task 7: Added comprehensive discovery, isolation, handshake, lifecycle, termination, privacy, evidence, and dependency-boundary tests plus a gated installed-CLI macOS smoke. `npm run validate:full` passes: TypeScript strict typecheck, 28 deterministic offline tests with one expected live-smoke skip, then one enabled live smoke against `codex-cli 0.145.0`.
- Definition of Done: all seven tasks and all ACs are satisfied; the live summary records `initialized`, `clean_exit`, and `unchanged`, with private/summary evidence modes verified as `0600` and run-directory mode `0700`. No production UI, provider action, authentication, thread/turn, model call, Canonical State mutation, fallback, packaging, or local-model work was added.

### File List

- `_bmad-output/implementation-artifacts/1-1-establish-the-isolated-app-server-harness.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `spikes/codex-app-server-harness/.gitignore`
- `spikes/codex-app-server-harness/.nvmrc`
- `spikes/codex-app-server-harness/README.md`
- `spikes/codex-app-server-harness/package-lock.json`
- `spikes/codex-app-server-harness/package.json`
- `spikes/codex-app-server-harness/src/cli.ts`
- `spikes/codex-app-server-harness/src/core/ai-provider-port.ts`
- `spikes/codex-app-server-harness/src/core/failures.ts`
- `spikes/codex-app-server-harness/src/core/lifecycle.ts`
- `spikes/codex-app-server-harness/src/adapters/codex/executable-discovery.ts`
- `spikes/codex-app-server-harness/src/adapters/codex/app-server-supervisor.ts`
- `spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts`
- `spikes/codex-app-server-harness/src/adapters/codex/jsonl-rpc-connection.ts`
- `spikes/codex-app-server-harness/src/adapters/codex/protocol.ts`
- `spikes/codex-app-server-harness/src/adapters/codex/runtime-profile.ts`
- `spikes/codex-app-server-harness/src/evidence/evidence-recorder.ts`
- `spikes/codex-app-server-harness/src/evidence/evidence-schema.ts`
- `spikes/codex-app-server-harness/src/evidence/sanitizer.ts`
- `spikes/codex-app-server-harness/evidence/README.md`
- `spikes/codex-app-server-harness/evidence/harness-run.schema.json`
- `spikes/codex-app-server-harness/test/core-contract.test.ts`
- `spikes/codex-app-server-harness/test/adapter-boundary.test.ts`
- `spikes/codex-app-server-harness/test/evidence.test.ts`
- `spikes/codex-app-server-harness/test/executable-discovery.test.ts`
- `spikes/codex-app-server-harness/test/fixtures/fake-codex-runtime.ts`
- `spikes/codex-app-server-harness/test/jsonl-handshake.test.ts`
- `spikes/codex-app-server-harness/test/live-macos.smoke.test.ts`
- `spikes/codex-app-server-harness/test/process-ownership.test.ts`
- `spikes/codex-app-server-harness/test/runtime-profile.test.ts`
- `spikes/codex-app-server-harness/test/workspace.test.ts`
- `spikes/codex-app-server-harness/tsconfig.json`

## Change Log

- 2026-07-31: Implemented Story 1.1 disposable Codex App Server harness, provider-neutral lifecycle seam, isolated runtime/profile, owned stdio supervision, sanitized evidence contract, deterministic contract suite, CLI, and opt-in live macOS smoke; moved story to review.

### Review Findings

- [x] [Review][Patch] Record the strict runtime configuration in private evidence [spikes/codex-app-server-harness/src/evidence/evidence-schema.ts:7]
- [x] [Review][Patch] Send `initialized` at most once per successful handshake [spikes/codex-app-server-harness/src/adapters/codex/jsonl-rpc-connection.ts:57]
- [x] [Review][Patch] Emit the distinct shutdown-timeout failure code [spikes/codex-app-server-harness/src/adapters/codex/app-server-supervisor.ts:94]
- [x] [Review][Patch] Do not retain passed evidence after a partial evidence-write failure [spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts:161]
- [x] [Review][Patch] Retain both executable candidate and resolved paths in private evidence [spikes/codex-app-server-harness/src/adapters/codex/executable-discovery.ts:8]
- [x] [Review][Patch] Preserve the harness Node interpreter in the scrubbed runtime PATH [spikes/codex-app-server-harness/src/adapters/codex/runtime-profile.ts:91]
- [x] [Review][Patch] Report incomplete isolation comparisons truthfully [spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts:124]
- [x] [Review][Patch] Reap the owned process group after a clean leader exit [spikes/codex-app-server-harness/src/adapters/codex/app-server-supervisor.ts:160]
- [x] [Review][Patch] Restrict executable discovery to a basename searched through PATH [spikes/codex-app-server-harness/src/adapters/codex/executable-discovery.ts:30]
- [x] [Review][Patch] Prevent caller-selected evidence roots from mutating a normal profile [spikes/codex-app-server-harness/src/evidence/evidence-recorder.ts:67]
- [x] [Review][Patch] Finalize the stderr fingerprint only after the stream closes [spikes/codex-app-server-harness/src/adapters/codex/app-server-supervisor.ts:67]
- [x] [Review][Patch] Include directory metadata in normal-profile snapshots [spikes/codex-app-server-harness/src/adapters/codex/runtime-profile.ts:133]
- [x] [Review][Patch] Reject internally contradictory passed evidence records [spikes/codex-app-server-harness/src/evidence/evidence-recorder.ts:45]
