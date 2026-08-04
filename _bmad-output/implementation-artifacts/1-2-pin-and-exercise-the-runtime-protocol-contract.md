---
baseline_commit: 13248b1e9ea280c3863148da02058d1c2ad3fe0c
---

# Story 1.2: Pin and Exercise the Runtime Protocol Contract

Status: done

<!-- Ultimate context engine analysis completed - comprehensive developer guide created. -->

## Story

As a ProjectOS builder,
I want App Server compatibility pinned to reproducible protocol evidence,
so that an installed Codex change cannot silently alter ProjectOS behavior.

## Acceptance Criteria

1. **Given** the isolated harness and discovered Codex binary from Story 1.1
   **When** the protocol-validation command runs
   **Then** it generates the supported protocol schemas from that exact binary and calculates stable schema digests
   **And** retains the version, digests, and generation command as evidence.

2. **Given** the generated protocol schemas
   **When** the Codex adapter defines its supported contract
   **Then** it enumerates only the documented RPC methods required by the spike
   **And** starts App Server with `experimentalApi: false`.

3. **Given** a runtime whose exact build, schema digest, or required method set differs from the supported manifest
   **When** compatibility is evaluated
   **Then** startup fails closed before any provider action
   **And** the failure identifies the detected build and the supported remediation without exposing local paths or sensitive data.

4. **Given** the exact supported runtime and matching protocol manifest
   **When** compatibility is evaluated
   **Then** only the enumerated RPC subset becomes available to the harness
   **And** unrecognized or non-enumerated methods remain unavailable.

5. **Given** fixtures for startup crash, malformed JSON, unexpected EOF, response timeout, and child termination
   **When** each fixture is replayed
   **Then** the supervisor reaches a deterministic normalized failure state and retains a sanitized diagnostic reference
   **And** it neither hangs indefinitely nor reports the runtime as ready.

6. **Given** a failed or terminated child process
   **When** an explicit restart is requested
   **Then** the harness starts a newly owned process, repeats compatibility and initialization checks, and does not reuse an uncertain transport state
   **And** only the new owned child can become ready.

7. **Given** two concurrent harness instances
   **When** both request App Server startup
   **Then** they either coordinate exclusive ownership of one ProjectOS profile or use fully isolated instance profiles
   **And** tests prove there is no crossing of processes, configuration, accounts, or session identifiers.

8. **Given** protocol evidence or a failure fixture contains JSON-RPC data
   **When** evidence is persisted
   **Then** tokens, account identifiers, Project content, prompts/results, and local paths are removed
   **And** the retained record remains sufficient to reproduce the compatibility result.

## Tasks / Subtasks

- [x] 1. Define and retain the exact supported protocol manifest (AC: 1, 2, 3, 4, 8)
  - [x] Add a committed, human-inspectable manifest under `spikes/codex-app-server-harness/protocol/` with a versioned manifest format, the exact spike build, platform/architecture, `binaryContentSha256`, stable schema-generation argv, digest algorithm, sorted schema inventory, per-file SHA-256 digests, separate JSON/TypeScript aggregate digests, required method sets, and currently enabled dispatch set.
  - [x] Treat locally observed `codex-cli 0.145.0` on Darwin arm64 as the initial spike candidate, not a semantic version range or production support policy. Produce the committed manifest only after generation from that exact resolved binary succeeds and repeated runs prove deterministic output.
  - [x] Generate both JSON Schema and TypeScript protocol artifacts from the owned executable snapshot with exact argument arrays `["app-server", "generate-json-schema", "--out", jsonDir]` and `["app-server", "generate-ts", "--out", tsDir]`, `shell: false`, the isolated Story 1.1 environment, bounded time/output, and no inherited terminal. Prohibit `--experimental`, `--prettier`, and `--strict-config`; do not use a private ChatGPT application-bundle binary. Parse and validate each JSON file before hashing it; retain generated TypeScript and hash its raw bytes without attempting JSON validation.
  - [x] Define the aggregate bytes exactly as UTF-8 `JSON.stringify({algorithm:"projectos-schema-tree-sha256-v1",files:[{path,sha256},...]})` with that key order, no pretty-print whitespace, normalized POSIX relative paths sorted by code point, and lowercase 64-character hex digests; SHA-256 those bytes. Reject control characters, backslashes, absolute/dot/dot-dot/non-normalized paths, and duplicate normalized paths. Absolute temporary paths, timestamps, archive metadata, and directory enumeration order must not affect the result.
  - [x] Validate the manifest and generated bundle before comparison. Reject missing/extra files, duplicate or traversing paths, symlinks, non-regular files, malformed JSON, oversized/unbounded output, unsupported manifest versions, and inconsistent per-file/aggregate digests.
  - [x] Keep exact generated schemas as permission-restricted run evidence; commit only the manifest, its schema, digest procedure, and documentation. Never silently rewrite the supported manifest during normal validation or startup.

- [x] 2. Add a fail-closed compatibility preflight before App Server spawn (AC: 1, 2, 3, 4)
  - [x] Reuse Story 1.1 executable discovery only to locate a candidate. Open that resolved regular executable without following a new symlink, copy its open-file bytes once into an exclusive `0500` file inside a dedicated executable-snapshot subdirectory of a newly created `0700` instance directory, hash the copied bytes, fsync/close, remove write permission from only that snapshot subdirectory, and run the authoritative version probe, both schema generators, and App Server from that same owned immutable snapshot. Keep the surrounding instance directory writable only as required for separately permissioned schema/evidence staging. The candidate's preliminary version result is not compatibility evidence.
  - [x] Detect source mutation during snapshot creation through open-file/stat checks; reject an incomplete, changed, non-regular, oversized, or hash-inconsistent snapshot. Add a fixture that atomically replaces the discovered executable after discovery and prove all later commands still use the owned snapshot or fail closed—never a mixture of old/new bytes.
  - [x] Compare exact build, platform/architecture, binary identity, manifest identity, schema inventory/digests, and required documented RPC set. A build mismatch may fail before generation; same-build fixtures must still exercise schema and method drift.
  - [x] Mint an adapter-private opaque compatibility capability only after every comparison passes. Its constructor/brand symbol must remain module-private and unexported, and `app-server-supervisor.ts` must runtime-check that the capability belongs to its exact attempt ID, binary-content SHA-256, and manifest digest before it can spawn App Server. Add an adapter-boundary test proving no exported or internal spawn path can bypass the compatibility validator. No account, thread, turn, model, network, or other provider request may be used to discover compatibility.
  - [x] Add ProjectOS-owned, stable failures for at least unsupported build, runtime snapshot failure, schema-generation timeout/failure, invalid manifest, schema mismatch, missing required method, unsupported dispatch, runtime termination during checking, and restart failure. Reuse the existing `isolation_failed` code for concurrent profile/process crossover and add `scope: "concurrent_instance"` only in the companion protocol diagnostic; do not create a duplicate isolation category that would invalidate Story 1.1 base evidence. Include safe detected/supported build and remediation metadata plus an opaque diagnostic reference; never include an executable path, output path, raw stderr, or vendor error string.
  - [x] Preserve `providerActionEnabled: false` and `canonicalStateOperationEnabled: false`. Story 1.2 establishes protocol compatibility only; do not report `authenticated`, `online`, `OpenAI ready`, `model ready`, or production readiness.
  - [x] Distinguish the full manifest-required spike method set from the Story 1.2 enabled dispatch set. Only `initialize` and `initialized` are sent in this story; later stories may add method-specific wrappers only for methods already in the manifest and only after their own gates pass.

- [x] 3. Enforce a deny-by-default adapter protocol boundary (AC: 2, 4, 8)
  - [x] Keep the supported method registry and all generated-schema mechanics inside `src/adapters/codex/`; public/core modules must not import Codex method names, generated types, schema-generator types, or raw JSON-RPC shapes.
  - [x] Separate client requests, client notifications, server notifications, and server requests in the manifest. Do not treat a method as callable merely because it exists in the generated stable schema.
  - [x] Avoid a generic public `send(method: string)` escape hatch. Use method-specific adapter operations plus a final internal allowlist check immediately before any JSONL write; reject unknown, future, experimental, and stable-but-unlisted methods before bytes reach the child.
  - [x] Keep `initialize.params.capabilities.experimentalApi` exactly `false` and record that structural fact in sanitized transcript evidence. Stable schema generation must omit `--experimental`.
  - [x] Explicitly exclude API-key, Bedrock, personal-access-token, credit/reset/nudge, `thread/shellCommand`, `command/exec*`, `process/*`, filesystem, MCP, plugin, app, connector, skill, dynamic-tool, realtime, experimental permission/history, and every other non-enumerated operation.
  - [x] Split inbound protocol metadata into required semantic notifications and recognized-but-forbidden requests/events. Forbidden methods remain unavailable and unanswered, but their exact schema presence is pinned and any occurrence fails the run with a sanitized side-effect/permission classification rather than a generic unknown-method result.
  - [x] The recognized-but-forbidden set must include every stable generated approval/tool/side-effect surface and at least: `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `item/permissions/requestApproval`, `item/tool/call`, `item/tool/requestUserInput`, `mcpServer/elicitation/request`, `applyPatchApproval`, `execCommandApproval`, `chatgptAuthTokens/refresh`, `attestation/generate`, `command/exec/outputDelta`, `process/outputDelta`, `process/exited`, `item/commandExecution/outputDelta`, `item/commandExecution/terminalInteraction`, `item/fileChange/outputDelta`, `item/fileChange/patchUpdated`, and `item/mcpToolCall/progress`. Confirm exact names/directions from the supported schemas; never answer a server request in Story 1.2.

- [x] 4. Make failure and explicit restart behavior generation-safe (AC: 5, 6)
  - [x] Preserve the bounded JSONL parser, one-time `initialize`/`initialized` ordering, matching request ID, duplicate-response rejection, maximum line size, separate bounded stderr handling, and exact child/process-group cleanup from Story 1.1.
  - [x] Add deterministic fixtures for generator/startup crash, malformed or oversized JSONL, unexpected method/ID, EOF, timeout, termination, request-before-initialize, and repeated initialize. Every path must end in one normalized terminal result, retain a sanitized diagnostic reference, and leave no owned child or schema-generator process.
  - [x] Represent each start/restart as a distinct attempt/generation with its own correlation, child/process group, compatibility result, JSONL connection, decoder buffer, request-ID namespace, listeners, timers, and pending-request registry.
  - [x] An explicit restart must first prove the old process group is fully gone, discard every old transport/compatibility object, then repeat discovery identity checks, manifest comparison, schema validation, spawn, and initialization. Do not use PID inequality alone because PIDs may be reused.
  - [x] Ignore or reject all late events from prior attempts; no stale response, EOF, exit, or timer may change the new attempt or make it compatible/initialized.
  - [x] Keep restart within the disposable validation harness. Do not introduce production retry policy, job idempotency, cancellation semantics, or provider-session resume; Stories 1.4 and 1.7 own those behaviors.
  - [x] Define test-overridable safety constants with production defaults: schema-generator timeout `5_000 ms`, generator shutdown step `500 ms`, maximum `1_024` generated files, `16 MiB` per schema file, `64 MiB` per JSON or TypeScript bundle, maximum runtime snapshot `512 MiB`, and at most one explicit restart per validation command. Keep the existing JSONL line limit and request/shutdown options; tests use smaller injected limits rather than long sleeps.

- [x] 5. Prove concurrent instances use fully isolated profiles (AC: 7)
  - [x] Select the accepted per-instance isolation strategy: reuse `createIsolatedRuntimeProfile()` so every concurrent attempt receives a unique `0700` runtime root, `CODEX_HOME`, SQLite home, disposable home/work/tmp directories, strict config, and owned process group.
  - [x] Run two fake-backed instances concurrently, not sequentially. Give each synthetic configuration/account/session marker values and assert stdout, configuration fingerprints, identifiers, pending requests, evidence, lifecycle events, and process ownership never cross instance boundaries.
  - [x] Prove both instances leave the synthetic normal profile and unrelated sentinel process unchanged and clean up only their own generator/App Server process groups on success, failure, and forced termination.
  - [x] Do not authenticate, read a real account, or create a real thread/session for this proof. Real account and provider-session isolation are exercised by Stories 1.3 and 1.7; Story 1.2 proves the profile/process/transport boundary with deterministic synthetic markers and absence of real account/thread calls.

- [x] 6. Add protocol-specific evidence without invalidating Story 1.1 evidence (AC: 1, 3, 5, 6, 7, 8)
  - [x] Preserve Story 1.1 `harness-run.schema.json` as the valid base v1 contract. Add a companion versioned protocol-validation evidence schema and atomically stage its files in the same private `.evidence/<run-id>/` run directory.
  - [x] Retain private exact generated JSON/TypeScript schema bundles, exact binary and isolated paths already required locally, per-attempt ownership data, and full manifest comparison inputs with `0700` directories and `0600` files. Reject attachment symlinks, traversal, non-regular files, and partial copies.
  - [x] Retain the actual resolved/snapshot executable paths and exact argv/output paths only in `0600` private evidence. Retain a shareable protocol summary with build string, platform/architecture, binary-content SHA-256, manifest ID/digest, digest-algorithm version, sorted relative schema filenames/digests, aggregate digests, approved method names, compatibility outcome, per-attempt lifecycle/shutdown result, opaque diagnostic reference, and logical argv using `$CODEX`, `$JSON_OUT`, and `$TS_OUT` placeholders plus the path-free reproduction command. Name the field `binaryContentSha256`; do not reuse Story 1.1's `executableFingerprint`, which identifies resolved path plus version and is not a location-independent binary identity.
  - [x] Persist only structural transcript entries such as attempt ID, monotonic sequence, direction, allowlisted method, request-ID class, and parse/outcome classification. Never write raw `params`, `result`, `error`, payload hashes, JSON-RPC lines, stderr, or absolute paths as the first step and attempt to clean them later.
  - [x] Exclude credentials, tokens, authorization headers, API keys, account identifiers, Project content, prompts/results, real normal-profile contents, environment values, raw payloads, raw stderr, and local paths from shareable evidence. Forbidden-value canaries must cover success and every partial-failure path.
  - [x] Evidence failure remains terminal and is reported only after all owned generator/App Server children are reaped. No partially written protocol record may be reported as compatible or passed.

- [x] 7. Add deterministic coverage, opt-in live validation, and reproduction documentation (AC: 1–8)
  - [x] Extend the fake runtime with deterministic stable schema generation, build/schema/method drift, generator crash/timeout/non-zero/malformed/missing/extra/oversized output, restart generations, late old-child messages, and concurrent-profile markers.
  - [x] Add focused tests for exact pass; different build before App Server spawn; same-build one-byte schema drift; missing required method; extra schema method remaining unavailable; tampered manifest; accidental experimental output; unknown/non-enumerated dispatch; and repeated deterministic generation.
  - [x] Preserve and extend the existing startup/EOF/malformed/timeout/termination/process-ownership tests. Make deadlines fixture-controlled and robust under the full parallel `node:test` suite; do not rely on long real sleeps or test order.
  - [x] Add an opt-in macOS live protocol-validation command that discovers the installed CLI, generates stable schemas, compares the committed manifest, initializes, shuts down, and records evidence without authentication or any account/thread/turn/provider call.
  - [x] Update `package.json`, CLI argument parsing, `README.md`, `protocol/README.md`, and `evidence/README.md` with exact offline/live commands, manifest refresh discipline, failure exit codes, evidence locations, and same-environment reproduction steps. Do not add runtime dependencies or change `package-lock.json` unless a justified package change actually requires it.
  - [x] Run `npm run typecheck`, the complete deterministic offline suite, the protocol contract tests, and the opt-in live protocol smoke on the supported macOS environment. Repeat the complete offline suite to expose timing flakes and retain the results.

### Review Findings

- [x] [Review][Patch] Bind the compatibility capability to the exact executable snapshot and protocol boundary [spikes/codex-app-server-harness/src/adapters/codex/protocol-contract.ts:314]
- [x] [Review][Patch] Pin inbound method direction and reject semantic notification names used as server requests [spikes/codex-app-server-harness/src/adapters/codex/jsonl-rpc-connection.ts:98]
- [x] [Review][Patch] Record outbound transcript entries only after the stream write succeeds [spikes/codex-app-server-harness/src/adapters/codex/jsonl-rpc-connection.ts:162]
- [x] [Review][Patch] Prove the authoritative version-probe process group is fully reaped before continuing or restarting [spikes/codex-app-server-harness/src/adapters/codex/runtime-compatibility.ts:209]
- [x] [Review][Patch] Give each restart generation its own correlation and diagnostic identity [spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts:118]
- [x] [Review][Patch] Retain per-attempt child and process-group ownership data in private protocol evidence [spikes/codex-app-server-harness/src/evidence/protocol-evidence-schema.ts:13]
- [x] [Review][Patch] Preserve each attempt's underlying normalized failure alongside the final restart failure [spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts:457]
- [x] [Review][Patch] Validate identifiers and diagnostic references for every attempt before publishing shareable evidence [spikes/codex-app-server-harness/src/evidence/protocol-evidence-sanitizer.ts:30]
- [x] [Review][Patch] Sanitize each attempt transcript against that attempt's own approved method set [spikes/codex-app-server-harness/src/evidence/protocol-evidence-sanitizer.ts:33]
- [x] [Review][Patch] Size the protocol attachment budget for both allowed attempts and both schema bundles [spikes/codex-app-server-harness/src/evidence/evidence-recorder.ts:23]
- [x] [Review][Patch] Verify copied schema attachment bytes against the recorded per-file and aggregate digests [spikes/codex-app-server-harness/src/evidence/evidence-recorder.ts:242]
- [x] [Review][Patch] Enforce generated-tree file and depth bounds during traversal rather than after recursion [spikes/codex-app-server-harness/src/adapters/codex/protocol-contract.ts:148]
- [x] [Review][Patch] Never substitute the preliminary discovery version for an authoritative compatibility build [spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts:418]
- [x] [Review][Patch] Reject unsafe or path-bearing supported build strings before they reach failures or CLI output [spikes/codex-app-server-harness/src/adapters/codex/protocol-contract.ts:203]
- [x] [Review][Patch] Runtime-validate transcript direction, request-ID class, and classification at the sanitizer boundary [spikes/codex-app-server-harness/src/evidence/protocol-evidence-sanitizer.ts:49]
- [x] [Review][Patch] Record a reproduction command that actually runs installed-runtime protocol validation [spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts:95]
- [x] [Review][Patch] Report generator nonzero, excessive-output, and cleanup failures as schema-generation failures [spikes/codex-app-server-harness/src/adapters/codex/runtime-compatibility.ts:118]
- [x] [Review][Patch] Include an opaque diagnostic reference on every supervisor failure returned to the caller [spikes/codex-app-server-harness/src/adapters/codex/app-server-supervisor.ts:141]

#### Review Chunk 2 — Evidence, Schemas, and Documentation

- [x] [Review][Patch] Reject false-pass and contradictory result, compatibility, and attempt states in the sanitized evidence schema [spikes/codex-app-server-harness/evidence/protocol-validation-run.schema.json:33]
- [x] [Review][Patch] Make the shareable evidence schema enforce the sanitizer's safe token, build, method, diagnostic, normalized-path, and bundle-size boundaries [spikes/codex-app-server-harness/evidence/protocol-validation-run.schema.json:31]
- [x] [Review][Patch] Pin attempt generations to `[1]` or `[1, 2]` and require restart failures to retain an underlying failure [spikes/codex-app-server-harness/evidence/protocol-validation-run.schema.json:105]
- [x] [Review][Patch] Make the manifest schema and runtime parser agree on exact object keys, safe build/platform/architecture values, and normalized paths [spikes/codex-app-server-harness/protocol/supported-runtime-manifest.schema.json:24]
- [x] [Review][Patch] Enforce the initialize/initialized and recognized-forbidden method relationships in the manifest contract [spikes/codex-app-server-harness/protocol/supported-runtime-manifest.schema.json:49]
- [x] [Review][Patch] Align manifest bundle cardinality, duplicate-path, and code-point-order validation across the schema, parser, and tests [spikes/codex-app-server-harness/protocol/supported-runtime-manifest.schema.json:90]
- [x] [Review][Patch] Make the focused protocol validation load and validate the committed manifest and both committed companion schemas instead of checking fixtures or file presence only [spikes/codex-app-server-harness/package.json:13]
- [x] [Review][Patch] Preserve `--restart` in retained reproduction commands whenever the recorded outcome used a restart attempt [spikes/codex-app-server-harness/evidence/protocol-validation-run.schema.json:128]
- [x] [Review][Patch] Redact unapproved method text before safe-method validation so an unsafe unknown method remains `$UNRECOGNIZED` instead of replacing the protocol failure with `evidence_write_failed` [spikes/codex-app-server-harness/src/evidence/protocol-evidence-sanitizer.ts:90]
- [x] [Review][Patch] Force deterministic offline test scripts to disable ambient live-smoke flags [spikes/codex-app-server-harness/package.json:11]
- [x] [Review][Patch] Correct installed-runtime reproduction and exit-code documentation so live validation is not described as deterministic and exit `2` means CLI usage failure only [spikes/codex-app-server-harness/evidence/README.md:16]
- [x] [Review][Patch] Document the combined protocol-live command and describe failed staging cleanup as best-effort without overstating publication atomicity [spikes/codex-app-server-harness/evidence/README.md:14]

#### Review Chunk 3 — Tests and Fixtures

- [x] [Review][Patch] Make the adapter-boundary test scan the complete source tree and prove no second App Server spawn path bypasses compatibility authorization [spikes/codex-app-server-harness/test/adapter-boundary.test.ts:38]
- [x] [Review][Patch] Exercise the real protocol CLI and live command, including safe stdout/stderr, exit codes `0`/`1`/`2`, default wiring, retained evidence, structural transcript, and explicit off-macOS failure instead of a successful skip [spikes/codex-app-server-harness/test/live-protocol-contract.smoke.test.ts:11]
- [x] [Review][Patch] Put the lifecycle tracker into `stopped` before asserting that stopped state cannot be revived [spikes/codex-app-server-harness/test/core-contract.test.ts:33]
- [x] [Review][Patch] Prove snapshot SHA-256 equals the copied bytes, reject same-inode mutation after open, and test exact and one-byte-over snapshot size bounds [spikes/codex-app-server-harness/test/executable-snapshot.test.ts:28]
- [x] [Review][Patch] Rework concurrent-instance fixtures to use contamination-sensitive per-profile markers around one shared runtime, real distinct evidence publication, and independent base/protocol/config/session/ownership assertions on success and forced failure [spikes/codex-app-server-harness/test/multi-instance.test.ts:10]
- [x] [Review][Patch] Independently probe the owned fake PID before accepting the supervisor's self-reported forced-cleanup result [spikes/codex-app-server-harness/test/process-ownership.test.ts:12]
- [x] [Review][Patch] Add a semantic-notification-only fixture that cannot become ready without a matching initialize response [spikes/codex-app-server-harness/test/jsonl-handshake.test.ts:215]
- [x] [Review][Patch] Prove forbidden server requests remain unanswered and give oversized, repeated-initialize, and wrong-ID failures the same diagnostic, disabled-action, bounded-shutdown, and process-reaping assertions as every other terminal fixture [spikes/codex-app-server-harness/test/jsonl-handshake.test.ts:237]
- [x] [Review][Patch] Cover initialized-notification write failure and successful callbacks after stream backpressure so both outbound transcript paths are callback-truthful [spikes/codex-app-server-harness/test/jsonl-handshake.test.ts:269]
- [x] [Review][Patch] Observe or inject late old-generation response, EOF, exit, and timer events on the channel under test and prove the old descendant is reaped before generation 2 can become ready [spikes/codex-app-server-harness/test/protocol-restart.test.ts:102]
- [x] [Review][Patch] Compile both committed schemas with a Draft 2020-12 validator and validate committed, produced, and negative contract instances instead of inspecting selected schema nodes [spikes/codex-app-server-harness/test/protocol-contract.test.ts:234]
- [x] [Review][Patch] Derive privacy canary coverage exhaustively from `FAILURE_CODES` and exercise real adapter failure writers, including omitted codes and the actual two-attempt restart shape [spikes/codex-app-server-harness/test/protocol-evidence.test.ts:224]
- [x] [Review][Patch] Spawn owned descendants in generator crash, timeout, and leader-exit failure fixtures and prove their groups are reaped while an unrelated sentinel survives [spikes/codex-app-server-harness/test/protocol-contract.test.ts:346]
- [x] [Review][Patch] Add exact-limit and limit-plus-one coverage for schema file bytes, cumulative bundle bytes, file count, and traversal depth [spikes/codex-app-server-harness/test/protocol-contract.test.ts:102]

#### Review Chunk 4 — Story and Sprint Artifacts

- [x] [Review][Patch] Revise the compatibility-state binding to specify the implemented one-shot, fail-closed result boundary without an observable intermediate `checking` status [_bmad-output/implementation-artifacts/1-2-pin-and-exercise-the-runtime-protocol-contract.md:189]
- [x] [Review][Patch] Add the required `scope: "concurrent_instance"` companion diagnostic when concurrent-profile isolation crossover is detected [spikes/codex-app-server-harness/src/evidence/protocol-evidence-schema.ts:13]
- [x] [Review][Patch] Replace the stale creation-era Story Completion Status and mislabeled 34-test “Final checks” with the current review state and retained validation evidence [_bmad-output/implementation-artifacts/1-2-pin-and-exercise-the-runtime-protocol-contract.md:386]
- [x] [Review][Patch] Include the changed story and sprint tracker in the story File List [_bmad-output/implementation-artifacts/1-2-pin-and-exercise-the-runtime-protocol-contract.md:451]
- [x] [Review][Patch] Correct the implementation-state table to attribute Story 1.2 companion evidence coverage to `test/protocol-evidence.test.ts` while preserving Story 1.1 base coverage in `test/evidence.test.ts` [_bmad-output/implementation-artifacts/1-2-pin-and-exercise-the-runtime-protocol-contract.md:229]

## Dev Notes

### Why This Story Exists

Epic 1 is an evidence gate, not feature delivery. Story 1.1 proved that ProjectOS can discover an installed Codex CLI, create an isolated profile, own an App Server child over stdio, complete initialization, retain safe evidence, and stop only its owned process group. Story 1.2 now prevents an installed runtime update or protocol drift from silently changing that boundary.

The Story 1.2 manifest is deliberately an exact **spike compatibility pin**. It is not a production supported-version range, bundling decision, update policy, or statement that Codex App Server is production-stable. Those decisions remain deferred until all Epic 1 gates pass. A plausible initialize response, matching version string alone, or stable-schema presence alone is insufficient.

[Source: `_bmad-output/planning-artifacts/epics.md#Story-12-Pin-and-Exercise-the-Runtime-Protocol-Contract`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#AD-10--Versioned-protocol-boundary-ADOPTED`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/validation-spike.md#1-Runtime-and-protocol`]

### Binding Implementation Decisions

- Initial candidate: `codex-cli 0.145.0`, official tag `rust-v0.145.0`, Darwin arm64, observed locally on 2026-08-01. The implementation must generate and verify the committed spike manifest rather than trusting this observation or silently substituting a newer runtime.
- Compatibility order: discover candidate -> copy once from an open descriptor to an owned immutable executable snapshot -> calculate `binaryContentSha256` -> probe/generate from the snapshot -> validate inventory/digests/methods -> mint an attempt/binary/manifest-bound opaque capability -> spawn App Server from the same snapshot -> initialize with `experimentalApi: false`.
- Profile strategy: fully isolated per-instance profiles. Do not add shared-profile locking in this story.
- Evidence strategy: retain exact generated schema files privately; commit the supported manifest/digest contract; add a companion protocol evidence schema without invalidating Story 1.1 base evidence.
- Dispatch strategy: deny by default and method-specific. Schema availability never grants dispatch authority.
- Readiness language: `protocol compatible` and `runtime initialized` are separate evidence states. Neither means authenticated, online, model-ready, contained, or production-ready.
- Compatibility operation ownership: keep compatibility validation as a one-shot, fail-closed adapter operation scoped to one attempt. Its snapshotting, generation, validation, and authorization phases remain procedural and adapter-private; Story 1.2 does not expose an intermediate progress subscription or `checking` state. `AiProviderPort` returns only the terminal provider-neutral `compatibilityStatus` (`compatible` on success or `incompatible` on a normalized failure), attempt ID, manifest ID, digest summary, and safe diagnostic reference; compose this with, and do not mutate or overload, Story 1.1's per-child lifecycle.

The currently observed resolved binary SHA-256 is `1da3f4e0e96028b8a771814293c3033dafd1971f943f6c7e79b0897fe705f590`. Treat it as an environment observation to reproduce during implementation, not as accepted evidence copied from this story file. Any mismatch must trigger deliberate investigation rather than an automatic manifest refresh.

### Required Protocol Surface

The committed manifest must separate the full documented method set required by Stories 1.1–1.8 from the methods enabled in Story 1.2. Confirm every name against the exact stable schema generated by the supported binary before committing the manifest.

| Direction | Required spike methods | Story 1.2 behavior |
|---|---|---|
| Required outbound client request | `initialize`; `model/list`; `account/read`; `account/login/start`; `account/login/cancel`; `account/logout`; `account/rateLimits/read`; `thread/start`; `thread/resume`; `thread/read`; `thread/list`; `thread/archive`; `thread/delete`; `turn/start`; `turn/interrupt` | Only `initialize` is implemented/sent. Later methods are manifest-required but unavailable until their owning story adds a constrained wrapper. `model/list` is pinned for the later model/config-scoped capability and representative-quality gates. `thread/archive` is pinned for the validation spike's archive lifecycle fixture, while Story 1.8 owns provider deletion. |
| Client notification | `initialized` | Implemented/sent once after the matching successful initialize response. |
| Required inbound semantic notification | `error`; `warning`; `configWarning`; `account/updated`; `account/login/completed`; `account/rateLimits/updated`; `thread/started`; `thread/status/changed`; `thread/archived`; `thread/deleted`; `turn/started`; `turn/completed`; `item/started`; `item/completed`; `item/agentMessage/delta` | Schema presence is validated. Story 1.2 records only structural classifications needed for deterministic transport safety; later stories own semantic normalization. |
| Recognized-but-forbidden inbound request/event | The exact stable approval, tool, permission, command, process, filesystem-change, MCP, auth-token-refresh, attestation, and other side-effect surfaces enumerated in Task 3. | Present in the manifest for detection/evidence only. Any occurrence fails the validation run; no request is answered and no method becomes a capability. |
| Other inbound or outbound method | None | Unrecognized/non-enumerated methods fail closed before dispatch or semantic handling. |

This list is the minimum full-spike compatibility surface derived from current stories. It does not make raw variants safe: later wrappers must still hard-code ChatGPT-only authentication, provider-neutral results, structured output, containment settings, and cleanup ownership. `account/login/start` must never expose API-key/Bedrock/PAT variants; `turn/start` must never bypass the later execution-containment gate.

The supported stable schema contains many operations that ProjectOS does not need and must not expose. In particular, do not call `thread/shellCommand`; the exact-tag documentation describes it as unsandboxed/full-access. Do not expose command/process/filesystem, credit/reset/nudge, MCP, plugin, app, skill, connector, dynamic-tool, or generic raw dispatch paths.

[Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/validation-spike.md#Test-matrix`] [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-current-platform.md#High--AD-10-is-internally-unmet-and-the-current-CLI-surface-is-still-version-sensitive`] [Source: `https://github.com/openai/codex/blob/rust-v0.145.0/codex-rs/app-server/README.md`]

### Current Implementation State and Required Preservation

Story 1.2 extends the existing harness; it must not replace it with a framework or a second process/JSON-RPC stack.

| UPDATE file | Current state | Story 1.2 change | Preserve |
|---|---|---|---|
| `spikes/codex-app-server-harness/package.json` | Pinned Node/TypeScript workspace with typecheck, offline tests, live handshake, and full validation. | Add explicit protocol validation/live protocol commands. | Node `24.18.1`, TypeScript `~7.0.2`, ESM, existing scripts, no unjustified dependency. |
| `spikes/codex-app-server-harness/README.md` | Story 1.1 discovery/isolation/handshake contract and reproduction. | Document exact compatibility pin, protocol commands/evidence, restart, and concurrent instances. | No auth/thread/turn/provider action and existing exit/evidence semantics. |
| `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` | ProjectOS-owned one-shot runtime request/result and disabled production actions. | Add provider-neutral compatibility/attempt result metadata only where a caller needs it. | No Codex names/types or production readiness claim. |
| `spikes/codex-app-server-harness/src/core/failures.ts` | Twelve stable Story 1.1 failure codes and safe remediation. | Add snapshot/compatibility/generation/manifest/method/restart codes and safe build/diagnostic metadata; reuse `isolation_failed` for concurrent-instance crossover. | Correlation, no raw strings/paths, fail-closed flags. |
| `spikes/codex-app-server-harness/src/adapters/codex/jsonl-rpc-connection.ts` | Bounded initialize handshake, matching IDs, duplicate rejection, single `initialized`. | Add structural transcript sink and final deny-by-default dispatch guard. | JSONL framing, memory bounds, raw payloads never persisted. |
| `spikes/codex-app-server-harness/src/adapters/codex/app-server-supervisor.ts` | Owns one process group and bounded cleanup/stderr lifecycle. | Require validated compatibility; expose attempt identity/diagnostic reference; permit fresh repeated attempts. | Close -> wait -> TERM -> KILL, descendant reaping, no name-based termination. |
| `spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts` | Orchestrates discovery, isolated profile, initialization, isolation comparison, evidence. | Insert compatibility before spawn and coordinate fresh explicit restart attempts plus protocol evidence. | Synthetic normal-profile/sentinel proof, evidence failure only after cleanup, no domain repositories. |
| `spikes/codex-app-server-harness/src/cli.ts` | Strict optional `--path` parsing and `0/1/2` exits. | Add explicit protocol validation and bounded restart command/options. | Safe stdout, no path-bearing failure output. |
| `spikes/codex-app-server-harness/src/evidence/evidence-recorder.ts` | Atomic `0700/0600` private/base summary staging. | Atomically attach exact schemas, protocol summary/transcript, and restart evidence. | Base v1 validity, no false pass after partial write. |
| `spikes/codex-app-server-harness/evidence/README.md` | Story 1.1 private/shareable evidence rules. | Add protocol artifacts, digest procedure, transcript rules, and reproduction. | Existing forbidden-data and path separation. |
| `spikes/codex-app-server-harness/test/adapter-boundary.test.ts` | Scans current core/adapter imports and forbidden repository/action names. | Include every new protocol/evidence module and generated-type leak pattern. | Existing inverse dependency and no-production-action checks. |
| `spikes/codex-app-server-harness/test/core-contract.test.ts` | Exact Story 1.1 lifecycle/failure-code contract. | Add provider-neutral compatibility fields, new codes, and isolation-code reuse assertions. | Existing terminal lifecycle remains unchanged. |
| `spikes/codex-app-server-harness/test/evidence.test.ts` | Base atomicity/mode/sanitization and truthful partial-failure tests. | Preserve the Story 1.1 base evidence regression boundary; companion protocol assertions belong in the dedicated protocol suite. | Story 1.1 base v1 evidence remains valid. |
| `spikes/codex-app-server-harness/test/protocol-evidence.test.ts` | Story 1.2 companion evidence, sanitizer, committed-schema, attachment, failure-canary, and adapter-writer coverage. | Cover composite attachment failure, private/shareable argv path canaries, restart shape, every normalized failure, and concurrent-instance scope. | Raw paths/payloads remain private and base v1 evidence remains unchanged. |
| `spikes/codex-app-server-harness/test/fixtures/fake-codex-runtime.ts` | Version/handshake/process failure fixture. | Add snapshot identity, deterministic generator, restart, late-message, and concurrent-marker behaviors. | Existing startup/EOF/malformed/TERM behaviors. |
| `spikes/codex-app-server-harness/test/jsonl-handshake.test.ts` | Direct strict handshake and deterministic transport failures. | Supply validated compatibility and assert structural transcript plus forbidden/unknown method handling. | Exact initialize shape and one `initialized`. |
| `spikes/codex-app-server-harness/test/process-ownership.test.ts` | Exact process-group, assertion, and descendant cleanup. | Cover snapshot/generator/restart attempt cleanup before a new child is eligible. | Unrelated processes remain alive. |
| `spikes/codex-app-server-harness/test/workspace.test.ts` | Workspace pins, files, and scripts. | Require manifest/protocol evidence/live protocol commands and files. | Existing Node/TypeScript pins. |

Keep these files unchanged unless the implementation first records a concrete need in the Dev Agent Record: `src/adapters/codex/executable-discovery.ts`, `src/adapters/codex/runtime-profile.ts`, `src/adapters/codex/protocol.ts`, `src/core/lifecycle.ts`, `src/evidence/evidence-schema.ts`, `src/evidence/sanitizer.ts`, `evidence/harness-run.schema.json`, `test/executable-discovery.test.ts`, `test/runtime-profile.test.ts`, and `test/live-macos.smoke.test.ts`. Reuse their already-correct discovery, per-run isolation, handshake shapes, per-child lifecycle, base evidence contract, and Story 1.1 live smoke.

### Expected New Files

```text
spikes/codex-app-server-harness/
  protocol/
    README.md
    supported-runtime-manifest.json
    supported-runtime-manifest.schema.json
  src/adapters/codex/
    executable-snapshot.ts
    protocol-contract.ts
    protocol-schema-generator.ts
  src/evidence/
    protocol-evidence-schema.ts
    protocol-evidence-sanitizer.ts
  evidence/
    protocol-validation-run.schema.json
  test/
    protocol-contract.test.ts
    protocol-restart.test.ts
    multi-instance.test.ts
    protocol-evidence.test.ts
    live-protocol-contract.smoke.test.ts
    fixtures/fake-protocol-schema-bundle.ts
```

This is the expected NEW map. If implementation evidence requires a different name or split, update the story's Dev Agent Record/File List and preserve the same ownership before claiming the task complete. Do not place generated Codex types in `src/core`, expose them through `AiProviderPort`, or create production application directories.

### Architecture Compliance

- AD-4: keep one ProjectOS-owned stdio child/process group per attempt; schema generation is also an exact owned subprocess lifecycle.
- AD-7: expose stable ProjectOS failure categories and opaque diagnostic references; raw payloads remain memory-only and Story 1.4 owns the full provider job/error model.
- AD-8: an RPC allowlist plus `experimentalApi: false` is not preventive execution containment. Do not claim the Story 1.6 gate passes.
- AD-10: accept only the exact spike build and generated stable schema contract; no version range, automatic repin, or method inference.
- AD-11: keep deterministic fake-backed contract tests and an explicit real-runtime smoke.
- AD-13: use unique isolated profiles for concurrent instances; never read, lock, mutate, log out, or delete from the user's default Codex profile.

[Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md#Architecture-decisions`]

### Library and Framework Requirements

- Keep Node.js `24.18.1`, npm lockfile v3, ESM, strict erasable TypeScript, TypeScript `~7.0.2`, and `@types/node` `24.10.12`.
- Use Node standard library modules already in the workspace: `node:child_process`, `node:fs/promises`, `node:crypto`, `node:path`, `node:os`, streams/decoders, and `node:test`.
- Do not add a JSON-RPC framework, hashing package, CLI parser, process manager, test framework, canonical-JSON package, or production app framework. Runtime validation remains manual and narrow; review chunk 3 permits Ajv only as a development dependency that independently compiles and exercises the committed Draft 2020-12 schemas.
- Generated TypeScript schemas are retained as evidence/input only; do not let their full vendor surface become the adapter API.

### Testing Requirements

Default validation remains deterministic, offline, account-free, and safe beside an active normal Codex session. Every live test stays opt-in and must perform only local discovery, schema generation, compatibility comparison, initialize/initialized, and owned shutdown.

| Area | Required proof |
|---|---|
| Manifest | Valid exact manifest passes; absent, malformed, unsupported version, tampered, inconsistent, traversal/symlink, extra/missing file fails before App Server spawn. |
| Exact runtime | Different build/binary fails; same build with schema drift or missing method independently fails. Executable identity cannot change between check and spawn. |
| Digest | Repeated generation yields identical per-file and aggregate SHA-256; temporary absolute paths/order do not affect digest; one-byte change does. |
| Method boundary | Required direction-specific set exists; only initialize/initialized dispatch now; unknown, experimental, and stable-but-unlisted methods fail before write. |
| Transport | Startup crash, malformed/oversized JSON, wrong/duplicate ID, unexpected method, EOF, timeout, termination, pre-init request, repeated init are bounded and deterministic. |
| Restart | Old process group/transport/timers/listeners/buffers/IDs are discarded; compatibility reruns; late old events cannot make the new attempt ready. |
| Concurrency | Two simultaneous runs have distinct roots/config/env/process groups/correlations and no synthetic account/session/stdout/pending-request crossover. |
| Ownership | Generator and App Server failure paths stop only their owned process groups; descendants are reaped; unrelated sentinel remains alive. |
| Evidence | Exact schemas retained privately; sanitized summary/transcript is reproducible and contains no canary credential/account/content/prompt/result/raw/path value. |
| Boundary | Public/core modules import no Codex/generated types; adapter has no domain repositories or production provider action path. |
| Reproduction | One documented offline command passes twice; one explicit macOS live command records exact supported-runtime evidence without provider work. |

During story creation on 2026-08-01, the first `npm run validate` attempt produced one transient happy-path handshake timeout/failure while 33 tests passed and one live smoke was skipped. The focused test and a complete rerun then passed with 34 tests and one expected skip. Treat this as a test-determinism warning: new timing/process fixtures must be robust under the complete parallel suite, and final evidence must come from repeated full-suite passes rather than a targeted pass alone.

### Previous Story Intelligence

Story 1.1 is complete and reviewed. Build on its code rather than reimplementing discovery, JSONL, process ownership, isolation, or base evidence.

- The current harness is a standalone Node.js/TypeScript spike under `spikes/codex-app-server-harness/`; there is still no production app stack to infer.
- `discoverCodexExecutable()` already performs ordered shell-free PATH lookup, realpath/X_OK checks, private app-bundle rejection, bounded exact version capture, and injection for fakes.
- `createIsolatedRuntimeProfile()` already creates unique restricted profiles and a strict ChatGPT/keyring/no-analytics config with an allowlisted environment. This directly supports the selected concurrent-instance strategy.
- `JsonlRpcConnection` already enforces JSONL framing, matching initialize ID, bounded line size, one `initialized`, EOF/exit/timeout failures, and memory-only raw messages.
- `superviseCodexAppServer()` already owns a detached process group, bounds stderr hashing, closes input, waits, sends TERM then KILL, reaps descendants, and never kills by name.
- `CodexAppServerAdapter` already keeps provider/Canonical State actions disabled, verifies a synthetic normal profile and unrelated process, and writes evidence only after supervision ends.
- Story 1.1 review patches are regression contracts: strict config in private evidence; one `initialized`; distinct shutdown timeout; no passed partial evidence; candidate plus resolved private paths; Node interpreter retained in PATH; truthful incomplete isolation; process-group reap after leader exit; basename-only discovery; evidence root cannot target normal profile; stderr fingerprint after close; directory metadata in snapshots; contradictory passed evidence rejected.

### Git Intelligence Summary

- `13248b1 Codex app server provider runtime and protocol` is the complete Story 1.1 implementation and the only runtime/code convention. Story 1.2 baseline is the full commit `13248b1e9ea280c3863148da02058d1c2ad3fe0c`.
- `40d1655 Refine project workspace implementation` is UX/documentation-only and establishes no harness code pattern.
- `d65d867 docs: adopt provider-independent Codex integration` is the governing architecture/provider decision package.
- `351f0f5 docs: finalize ProjectOS validation PRD` and `63f34fa docs: update planning docs with research findings and provider decision` establish validation scope but no competing implementation stack.
- The worktree was clean when this story was created. Preserve unrelated future user changes if the implementation begins from a dirty tree.

### Latest Technical Information (verified 2026-08-01)

- Official App Server documentation defines stdio as newline-delimited JSON with the normal JSON-RPC `jsonrpc` field omitted, requires exactly one `initialize` followed by `initialized`, and describes generated schemas as specific to the exact Codex version used.
- Stable-only schema generation is the default for `generate-json-schema` and `generate-ts`; passing `--experimental` adds methods/fields without a backwards-compatibility guarantee. Runtime `experimentalApi` is negotiated once at initialization and remains `false` for ProjectOS.
- The local CLI reports `codex-cli 0.145.0`; `codex app-server`, `generate-json-schema`, and `generate-ts` remain labelled experimental. There is no documented semantic protocol-version range to substitute for exact schema evidence.
- Official `rust-v0.145.0` documentation includes stable methods outside ProjectOS scope. Stable does not mean authorized: the adapter must independently restrict dispatch and variants.
- A server-compatible schema is not proof of safe command/filesystem/tool containment. Story 1.6 remains the mandatory preventive effects gate.

[Source: `https://learn.chatgpt.com/docs/app-server`] [Source: `https://github.com/openai/codex/blob/rust-v0.145.0/codex-rs/app-server/README.md`] [Source: `https://github.com/openai/codex/releases/tag/rust-v0.145.0`]

### UX-Relevant Constraints Without UI Work

Story 1.2 creates no production UI, localization, focus behavior, or accessibility surface. Its normalized outcomes must nevertheless preserve later UX truthfulness:

- runtime absent and runtime incompatible are distinct;
- compatibility checking, protocol compatible, initialization, stopped, and failed are named phases, never fabricated percentages;
- local ProjectOS behavior remains available while provider work stays disabled;
- failure metadata supplies a persistent install/update/retry/inspect-evidence route and never collapses into generic `Offline`, `Connection error`, or `Something went wrong`;
- no result claims a provider call queued, resumed, authenticated, or became ready;
- diagnostic and remediation strings carry no local path, credential, account identifier, Project content, prompt, or result.

[Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md#Voice-and-Tone`] [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md#State-Patterns`] [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/DESIGN.md#Components`]

### Scope Boundaries

Do **not** implement:

- production UI, First Run, Settings, status badges, localization, accessibility surfaces, Canonical State, persistence, migration, or native app shell;
- actual account reads, browser/device login, logout, tokens, keyring audit, plan state, or API-key/credit path (Story 1.3);
- allowance normalization, provider job events/reducer, cancellation races, retry idempotency, or full error taxonomy (Story 1.4);
- real thread/turn creation, model generation, structured output, representative fixtures, proposal persistence, or quality scoring (Story 1.5);
- hostile-input filesystem/network/command/tool prevention or a claim of execution containment (Story 1.6);
- Conversation bindings, resume semantics, export/restore identity, or provider-session ownership (Story 1.7);
- cleanup outbox, real thread enumeration/deletion, reauthentication, or crash-safe provider cleanup (Story 1.8);
- provider registry, local-shaped adapter, final gate audit, or `proceed`/`reject` recommendation (Story 1.9);
- production supported-version range, installed-versus-bundled distribution, automatic Codex updates, provider fallback, local model, App Store packaging, billing, or collaboration.

### Project Context Reference

- No `project-context.md` file exists in the repository.
- Governing authority is the current product brief/addendum, the 2026-07-31 Codex subscription-access reconciliation, final PRD/addendum, final architecture spine/spike, and final UX spines. Historical PRD review/reconciliation files must not reintroduce the superseded API-key/OpenAI-plus-Ollama validation direction.
- `docs/ProjectWorkspace.md` is superseded and must not drive provider implementation.
- The broader product remains solo, local-first, provider-neutral at the domain boundary, and explicitly human-governed; Story 1.2 is only the second unit of the disposable adapter validation gate.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story-12-Pin-and-Exercise-the-Runtime-Protocol-Contract`]
- [Source: `_bmad-output/planning-artifacts/epics.md#Epic-1-Prove-a-Safe-AI-Path—or-Stop`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/validation-spike.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-current-platform.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-adversarial.md`]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/reviews/review-rubric.md`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md#47-Provider-Independence`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/addendum.md#5-Provider-and-Privacy-Decisions`]
- [Source: `_bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/reconcile-codex-subscription-access-2026-07-31.md`]
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md`]
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/DESIGN.md`]
- [Source: `_bmad-output/implementation-artifacts/1-1-establish-the-isolated-app-server-harness.md`]
- [OpenAI Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [OpenAI Codex App Server at exact supported candidate tag](https://github.com/openai/codex/blob/rust-v0.145.0/codex-rs/app-server/README.md)
- [OpenAI Codex 0.145.0 release](https://github.com/openai/codex/releases/tag/rust-v0.145.0)

## Story Completion Status

- Status set to `done` after all four code-review chunks were resolved.
- All eight acceptance criteria are implemented with checked tasks and reviewed regression coverage.
- Exact Node 24.18.1 validation passed: focused protocol suite 93/93, complete deterministic offline suite 109/109 with two expected opt-in live skips, and installed-runtime protocol smoke 1/1 against `codex-cli 0.145.0`.
- Compatibility remains a one-shot, fail-closed adapter operation; the port exposes terminal provider-neutral results without an unused intermediate progress contract.
- Concurrent-profile crossover retains the base `isolation_failed` category and adds `scope: "concurrent_instance"` only to private/shareable companion protocol attempt evidence.
- No production feature, provider action, authentication, thread/turn, Canonical State operation, or production-readiness claim was added.
- The generated protocol manifest remained excluded from code review and was not edited during review.

## Dev Agent Record

### Agent Model Used

OpenAI Codex (GPT-5)

### Implementation Plan

- Build the exact manifest and schema-tree digest primitives first, including stable JSON canonicalization for generator map-order noise and raw-byte TypeScript hashing.
- Add immutable executable snapshotting, exact-build/schema/method compatibility validation, and an attempt-bound opaque capability required by the App Server supervisor.
- Enforce the initialize/initialized-only protocol boundary with structural transcripts, normalized failures, fresh restart generations, and isolated concurrent profiles.
- Extend atomic evidence with private protocol attachments and sanitized companion summaries, then expose deterministic offline and opt-in live protocol commands.

### Debug Log References

- Task 1 RED: `node --test --experimental-strip-types test/protocol-contract.test.ts` failed with `ERR_MODULE_NOT_FOUND` before protocol modules existed.
- Task 1 determinism investigation: repeated exact generation changed only object-key order in `codex_app_server_protocol.v2.schemas.json`; JSON digests now canonicalize parsed object keys while TypeScript remains raw-byte hashed. Repeated JSON and TypeScript aggregate digests then matched.
- Task 1 validation: focused protocol suite 7/7 passed; typecheck passed; full offline suite 41 passed with one expected live skip.
- Task 2 RED: executable snapshot tests initially failed with a missing module; the forged-capability supervisor test then proved the pre-existing spawn path accepted an unvalidated object before the runtime gate was added.
- Task 2 validation: snapshot, compatibility, supervisor, adapter-boundary, and adapter integration tests passed; full offline suite 52 passed with one expected live skip.
- Task 3 RED: the dispatch-policy test failed until a direction-aware boundary existed; inbound forbidden/unknown fixtures then exercised the byte-write guard and unanswered server-request behavior.
- Task 3 validation: protocol boundary and structural-transcript tests passed; full offline suite 57 passed with one expected live skip.
- Task 4 RED: explicit restart initially remained a single failed attempt, and repeated-generation failure surfaced the original handshake code instead of `restart_failed`.
- Task 4 validation: generator crash/timeout, transport boundary failures, and restart-generation tests passed; typecheck passed; full offline suite 65 passed with one expected live skip.
- Task 5 RED: concurrent marker assertions initially failed because the fake runtime did not retain instance-scoped markers/environment observations.
- Task 5 validation: simultaneous success/success and success/forced-termination isolation tests passed; full offline suite 67 passed with one expected live skip.
- Task 6 RED: protocol evidence tests initially failed because no companion evidence modules or composite writer contract existed.
- Task 6 validation: companion schema, private/sanitized records, structural transcript, exact schema attachments, failure canaries, modes, and unsafe-attachment rejection passed; full offline suite 72 passed with one expected live skip.
- Task 6 concrete base-v1 need: Story 1.2 failure codes are outside the frozen `harness-run.schema.json` enum, so `src/evidence/sanitizer.ts` now omits only those new codes from the optional base summary field while private and companion protocol evidence retain the exact failure.
- Task 7 RED: CLI/workspace tests failed until the explicit protocol command and scripts existed; the first exact Node 24.18.1 protocol-suite run then exposed a baseline schema-generator fixture timeout under full parallel load.
- Task 7 validation: fixture-controlled success deadlines removed the timing weakness; exact Node 24.18.1 typecheck and focused protocol suite passed 68/68, the macOS live exact-runtime smoke passed 1/1 against `codex-cli 0.145.0`, and two final complete offline passes each passed 85 tests with two expected opt-in live skips.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story prepared for implementation; create-story changed only this story artifact and sprint tracking.
- Task 1 complete: retained an exact `codex-cli 0.145.0` Darwin arm64 manifest from a private snapshot with 273 JSON and 617 TypeScript files, stable aggregate digests, direction-specific required/forbidden methods, schema validation, and documented refresh discipline.
- Task 2 complete: App Server can launch only from an immutable open-file snapshot after exact build/binary/schema/method validation mints a private attempt-bound capability; mismatch results are fail-closed, sanitized, and keep provider/Canonical State actions disabled.
- Task 3 complete: only method-specific `initialize`/`initialized` writes pass the final allowlist, `experimentalApi: false` is structurally recorded, semantic notifications remain non-ready metadata, and forbidden/unknown inbound methods fail without a response or raw payload persistence.
- Task 4 complete: one explicit restart now creates a wholly fresh attempt after verified cleanup, reruns discovery/snapshot/compatibility/initialization, isolates late events by construction, and normalizes a failed second generation as `restart_failed`.
- Task 5 complete: overlapping instances use distinct profiles, attempts, environment fingerprints, synthetic markers, evidence, transports, and owned process groups; forced termination of one leaves the neighbor and both synthetic normal profiles unchanged.
- Task 6 complete: base v1 evidence remains unchanged while an atomically published companion record retains exact private comparison inputs and schemas, exposes only reproducible structural/shareable fields, redacts unknown method text, and treats any unsafe or partial attachment write as terminal after owned-child cleanup.
- Task 7 complete: fake-backed drift/generator/restart/late-event coverage, generator-descendant ownership, an explicit bounded-restart CLI, offline/live scripts, exact reproduction documentation, and a real installed-runtime smoke now exercise the committed protocol contract without authentication or provider work.
- Review chunk 1 complete: all 18 runtime/adapter findings were patched and regression-tested; the exact Node 24.18.1 validation passed 94 tests with two expected opt-in live skips, and the installed-runtime protocol smoke passed 1/1. The story remains in progress until the remaining review chunks are completed; the generated protocol manifest remains excluded from review.
- Review chunk 2 complete: all 12 evidence/schema/documentation findings were patched. The focused protocol suite passed 82/82, two exact Node 24.18.1 offline validations each passed 98 tests with two expected live skips (including one hostile ambient-live-flags run), and the installed-runtime protocol smoke passed 1/1. The committed manifest was parsed by the contract test but remained excluded from review and was not edited.
- Review chunk 3 complete: all 14 test/fixture findings were patched. The source boundary now scans every TypeScript module; CLI `0`/`1`/`2`, retained live evidence, snapshot mutation/bounds, shared-runtime concurrency, unanswered requests, callback truth, restart cleanup, exhaustive failure privacy, descendant reaping, exact resource limits, and Draft 2020-12 schema behavior are independently exercised. The focused protocol suite passed 92/92, two exact Node 24.18.1 offline validations each passed 108 tests with two expected live skips, and the installed-runtime CLI smoke passed 1/1. The story remains in progress until the final BMad artifact/tracker review chunk is completed; the generated protocol manifest remained excluded and was not edited.
- Review chunk 4 complete: the story now documents the chosen one-shot compatibility boundary, companion diagnostics scope real concurrent-instance crossover without leaking into provider failures, current implementation/test ownership is accurate, and the story/tracker audit trail is complete. Exact Node 24.18.1 typecheck and focused protocol validation passed 93/93; the complete deterministic offline suite passed 109/109 with two expected live skips; and the installed-runtime protocol smoke passed 1/1. The first live invocation used a narrowed `PATH` that omitted `/opt/homebrew/bin/codex`, failed safely as `runtime_not_found`, and passed after restoring the installed-runtime directory. The generated protocol manifest remained excluded and was not edited.

### Change Log

- 2026-08-01: Implemented the exact `codex-cli 0.145.0` runtime/protocol pin, immutable snapshot compatibility gate, deny-by-default transport boundary, explicit fresh restart, concurrent isolation, atomic companion evidence, deterministic drift/failure coverage, and opt-in live validation. Story advanced to review.
- 2026-08-04: Applied all 18 patches from code-review chunk 1, added focused regression coverage, and returned the story to in-progress pending review of the remaining chunks. The generated protocol manifest was excluded as requested.
- 2026-08-04: Applied all 12 patches from code-review chunk 2, aligned committed schemas with runtime validation, made restart evidence reproducible, hardened offline commands, corrected documentation, and retained in-progress status for the remaining review chunks.
- 2026-08-04: Applied all 14 patches from code-review chunk 3, strengthened deterministic test/fixture evidence, added dev-only Draft 2020-12 validation, and retained in-progress status for the final artifact/tracker review chunk. The generated protocol manifest remained excluded.
- 2026-08-04: Resolved the final review decision in favor of the implemented one-shot compatibility boundary, applied all five chunk 4 patches, added concurrent-instance companion diagnostic coverage, and advanced the synchronized story/tracker status to done. The generated protocol manifest remained excluded and unchanged.

### File List

- _bmad-output/implementation-artifacts/1-2-pin-and-exercise-the-runtime-protocol-contract.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- spikes/codex-app-server-harness/README.md
- spikes/codex-app-server-harness/package.json
- spikes/codex-app-server-harness/package-lock.json
- spikes/codex-app-server-harness/src/cli.ts
- spikes/codex-app-server-harness/protocol/README.md
- spikes/codex-app-server-harness/protocol/supported-runtime-manifest.json
- spikes/codex-app-server-harness/protocol/supported-runtime-manifest.schema.json
- spikes/codex-app-server-harness/src/adapters/codex/protocol-contract.ts
- spikes/codex-app-server-harness/src/adapters/codex/protocol-schema-generator.ts
- spikes/codex-app-server-harness/src/adapters/codex/app-server-supervisor.ts
- spikes/codex-app-server-harness/src/adapters/codex/jsonl-rpc-connection.ts
- spikes/codex-app-server-harness/src/adapters/codex/codex-app-server-adapter.ts
- spikes/codex-app-server-harness/src/adapters/codex/executable-snapshot.ts
- spikes/codex-app-server-harness/src/adapters/codex/runtime-compatibility.ts
- spikes/codex-app-server-harness/src/core/ai-provider-port.ts
- spikes/codex-app-server-harness/src/core/failures.ts
- spikes/codex-app-server-harness/src/evidence/evidence-recorder.ts
- spikes/codex-app-server-harness/src/evidence/sanitizer.ts
- spikes/codex-app-server-harness/src/evidence/protocol-evidence-schema.ts
- spikes/codex-app-server-harness/src/evidence/protocol-evidence-sanitizer.ts
- spikes/codex-app-server-harness/evidence/protocol-validation-run.schema.json
- spikes/codex-app-server-harness/evidence/README.md
- spikes/codex-app-server-harness/test/adapter-boundary.test.ts
- spikes/codex-app-server-harness/test/cli.test.ts
- spikes/codex-app-server-harness/test/core-contract.test.ts
- spikes/codex-app-server-harness/test/executable-snapshot.test.ts
- spikes/codex-app-server-harness/test/fixtures/fake-codex-runtime.ts
- spikes/codex-app-server-harness/test/fixtures/fake-compatibility-capability.ts
- spikes/codex-app-server-harness/test/jsonl-handshake.test.ts
- spikes/codex-app-server-harness/test/process-ownership.test.ts
- spikes/codex-app-server-harness/test/protocol-restart.test.ts
- spikes/codex-app-server-harness/test/multi-instance.test.ts
- spikes/codex-app-server-harness/test/fixtures/fake-runtime-manifest.ts
- spikes/codex-app-server-harness/test/runtime-compatibility.test.ts
- spikes/codex-app-server-harness/test/fixtures/fake-protocol-schema-bundle.ts
- spikes/codex-app-server-harness/test/protocol-contract.test.ts
- spikes/codex-app-server-harness/test/protocol-evidence.test.ts
- spikes/codex-app-server-harness/test/live-protocol-contract.smoke.test.ts
- spikes/codex-app-server-harness/test/workspace.test.ts
