---
title: 'Story 1.3: Prove Subscription Authentication Without Credential Ownership'
type: 'feature'
created: '2026-08-04'
baseline_revision: '9d31f3026aed058b3ea91a255828a7deb6891a3f'
final_revision: '68e1e69'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: []
---

<intent-contract>

## Intent

**Problem:** The validation harness proves an isolated, protocol-compatible Codex App Server but deliberately stops after initialization. It cannot yet determine whether a ChatGPT Pro subscription can authenticate within a ProjectOS-owned profile while Codex exclusively owns credentials.

**Approach:** Add a narrow, manifest-pinned authentication-validation operation that runs inside the existing owned App Server lifecycle. Normalize only safe account and login outcomes, retain structural auth evidence, and prove credential non-ownership with deterministic fakes plus an explicit opt-in macOS browser-login command.

## Boundaries & Constraints

**Always:** Run authentication only after immutable-snapshot compatibility succeeds; use `experimentalApi: false`; keep the sole supervisor spawn/process-group authority; permit only an explicit authentication allowlist (`account/read`, managed ChatGPT login start/cancel/logout, and required notifications); require exact generated-schema validation; preserve normal-profile isolation; reap every owned child before returning; and sanitize all logs, JSONL transcripts, evidence, CLI output, and failure details.

**Block If:** The pinned runtime requires ProjectOS to construct, receive, persist, export, log, or inspect access/refresh tokens, API keys, API credits, authorization headers, account identifiers, browser-login URLs, login IDs, device codes, or plaintext credentials; secure keychain storage cannot be made fail-closed; the required authentication schema/notifications cannot be safely normalized; or a credential-leak/isolation test fails.

**Never:** Add generic RPC dispatch, account/token refresh handling, API-key/credit setup or fallback, production UI, provider turns, allowance normalization, containment, session lifecycle, Canonical State work, or a claim that initialization or deterministic tests prove live subscription authentication.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Signed out | Compatible isolated runtime | Normalized `signed_out`; no opener or credential state | Actionable sign-in route only |
| Managed browser success | `account/login/start` with exactly `{ type: "chatgpt" }` and matching completion/update notifications | Normalized ChatGPT authenticated state and plan category; expected-Pro check; opener receives URL ephemerally | Timeout/mismatch is normalized and child is reaped |
| Cancelled, expired, failed | Matching Codex login completion | Distinct normalized retryable outcome; interrupted validation can resume | Never retain raw provider error |
| Device-code capability | Advertised or absent from validated schema/runtime | Safe capability result; absent is `unsupported` | Never expose code or verification URL |
| Secure storage unavailable | Login attempt with keyring failure | Fail-closed normalized outcome; no plaintext `auth.json` | Mark stop condition in evidence |
| Logout and audit | Authenticated ProjectOS profile with normal-profile fixture | ProjectOS profile returns signed out; normal profile unchanged; leak audit retained | Any contamination/credential finding rejects result |

</intent-contract>

## Code Map

- `spikes/codex-app-server-harness/src/core/ai-provider-port.ts` -- ProjectOS-owned authentication request, capability, state, and result types.
- `spikes/codex-app-server-harness/src/core/failures.ts` -- stable sanitized authentication and credential-ownership failure categories.
- `spikes/codex-app-server-harness/src/adapters/codex/{protocol-contract.ts,jsonl-rpc-connection.ts,app-server-supervisor.ts,codex-app-server-adapter.ts}` -- exact allowlist, correlated auth sequence, single owned lifecycle, and normalization boundary.
- `spikes/codex-app-server-harness/src/adapters/codex/runtime-profile.ts` -- ProjectOS-profile-only storage/configuration audit while preserving normal-profile sentinel checks.
- `spikes/codex-app-server-harness/src/evidence/` and `spikes/codex-app-server-harness/evidence/` -- versioned authentication evidence schema, sanitizer, atomic retention, and documentation.
- `spikes/codex-app-server-harness/protocol/supported-runtime-manifest.json` -- exact authentication method/notification contract; token-refresh paths remain forbidden.
- `spikes/codex-app-server-harness/test/` -- fake runtime traces, transport, profile, evidence, CLI, boundary, and opt-in live validation coverage.

## Tasks & Acceptance

**Execution:**
- [x] `src/core/ai-provider-port.ts` and `src/core/failures.ts` -- define ProjectOS-owned auth validation inputs/results and explicit safe failure/remediation categories; no wire or credential types cross the boundary.
- [x] `protocol/supported-runtime-manifest.json`, `src/adapters/codex/protocol-contract.ts`, and protocol tests -- pin the minimal auth request/notification subset from the same generated schema, reject all generic, token, tool, and future dispatch, and preserve `experimentalApi: false`.
- [x] `src/adapters/codex/jsonl-rpc-connection.ts`, `app-server-supervisor.ts`, and `codex-app-server-adapter.ts` -- perform correlated `account/read`, managed login, notification observation, cancellation, refreshed account check, and logout only as a post-initialize callback on the compatibility-authorized child; use bounded timeouts and final owned cleanup.
- [x] `src/adapters/codex/runtime-profile.ts` -- verify forced ChatGPT/keyring configuration, scrubbed environment, ProjectOS-profile no-plaintext audit, and unchanged synthetic normal profile without reading any credential contents.
- [x] `src/evidence/authentication-evidence-schema.ts`, `src/evidence/authentication-evidence-sanitizer.ts`, `src/evidence/authentication-evidence-recorder.ts`, `evidence/authentication-validation-run.schema.json`, and `src/cli.ts` -- retain atomic structural authentication evidence and a `reject` stop condition; add a separately opt-in macOS browser-login command that does not print or persist sensitive values.
- [x] `test/fixtures/fake-codex-runtime.ts`, `test/authentication.test.ts`, `test/jsonl-handshake.test.ts`, `test/runtime-profile.test.ts`, `test/evidence.test.ts`, `test/protocol-evidence.test.ts`, `test/cli.test.ts`, `test/adapter-boundary.test.ts`, `test/live-authentication.smoke.test.ts`, `package.json`, `README.md`, and `evidence/README.md` -- cover every matrix row, secret canaries across all retained outputs, no second spawn path, and clear offline versus interactive live validation commands.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` and this spec -- record implementation/review progress, result evidence, changed-file list, and any reject condition truthfully.

**Acceptance Criteria:**
- Given a compatible signed-out isolated runtime, when authentication validation reads account state, then it reports normalized signed-out state without an API-key request or ProjectOS credential record.
- Given a signed-out runtime, when managed ChatGPT login is requested, then only the exact managed request is emitted, the returned URL is opened ephemerally, matching notifications are observed, and no token reaches ProjectOS.
- Given a successful validation-account login, when account state is refreshed, then it records managed ChatGPT authentication and the Codex-exposed plan category including the expected Pro check while evidence excludes account identifiers.
- Given cancellation, expiry, failure, or secure-storage unavailability, when Codex reports it, then the result is distinct, actionable, fail-closed where required, leaves no plaintext fallback, and retains no raw provider error.
- Given device-code support is present or absent, when recovery capability is evaluated, then it is safely recorded or `unsupported` without weakening browser-login validation or exposing recovery secrets.
- Given an authenticated ProjectOS profile, when logout completes, then only that profile is signed out and the separately configured normal profile is unchanged.
- Given any auth trace or retained artifact, when leak and ownership audits run, then no credential/account canary, raw payload, path, or plaintext credential file survives; a violation marks the adapter path `reject` and blocks downstream production work.

## Spec Change Log

- 2026-08-04: Implemented the manifest-pinned, explicit authentication validation mode. The default transport remains init-only; auth reuses the one compatibility-authorized App Server child and has no generic dispatch.

## Review Triage Log

### 2026-08-04 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 10 (high 9, medium 1)
- defer: 0
- reject: 2
- addressed_findings:
  - `[high]` `[patch]` Reject normalized non-success auth outcomes in CLI and evidence; do not represent failed subscription proof as `proceed`.
  - `[high]` `[patch]` Reject an already authenticated disposable profile without logout, browser-proof, or mutation; validate malformed auth responses and bound all login buffers.
  - `[high]` `[patch]` Fail closed for unsafe evidence roots/run IDs and unexpected isolated-profile files, while retaining metadata-only credential auditing.
  - `[high]` `[patch]` Require the exact generated and pinned login schema to prove device-code support before enabling it.
  - `[medium]` `[patch]` Replace the no-op live test/reproduction claim with an explicitly opt-in managed-login validation command and evidence assertions.
  - `[high]` `[patch]` Preserve the supervisor's established distinction between protocol failures and post-initialize assertion failures.

## Design Notes

Keep the current init-only transport as the default protocol-validation surface. Authentication is a separate explicit session mode bound to the same private compatibility capability; a broad `send(method)` API would make future RPC surfaces accidentally callable. Browser URLs, login IDs, device codes, and account fields are transient adapter inputs only and are reduced to normalized state before crossing any persistence, logging, or public-port boundary.

## Verification

**Commands:**
- `npm run typecheck` -- expected: strict TypeScript passes.
- `npm test` -- expected: deterministic authentication, leak, isolation, and existing harness suites pass without a live account.
- `npm run validate:protocol` -- expected: manifest/boundary contract stays fail-closed.
- `npm run test:auth:live` (new, opt-in) -- expected: interactive managed ChatGPT login/logout proof records only sanitized evidence; it must never be part of default tests.

## Auto Run Result

Status: review

Completed task evidence:

- `src/core/ai-provider-port.ts` and `src/core/failures.ts` expose only normalized credential-free authentication state, result, failure, and remediation types.
- The manifest and protocol boundary pin only `account/read`, managed `account/login/start`, `account/login/cancel`, `account/logout`, and the two account notifications. The ordinary protocol boundary remains `initialize`/`initialized` only.
- Authentication runs only in the supervisor post-initialize callback on the compatibility capability's sole owned spawn; managed URLs are transient callbacks and structural transcripts retain no payloads.
- Profile configuration forces ChatGPT/keyring, audits metadata-only for plaintext credential files, and compares the synthetic normal profile before/after.
- Atomic `authentication-summary.json` evidence is sanitized and schema-versioned. `auth-validate --interactive` is a separately opt-in macOS command; default tests do not invoke it.
- Device-code recovery is unavailable unless the compatible manifest explicitly pins it; a pinned fake trace exercises the recovery mode while excluding its URL/code from evidence. Deterministic cancelled, expired, failed, and secure-storage-unavailable traces return distinct retryable normalized outcomes, cancel the owned login attempt, and retain only structural evidence.
- Deterministic coverage: `npm run typecheck`; `npm test`; and `npm run validate:protocol` (results recorded after final run). No interactive or live login was run.

### Final review outcome

- Summary: Added credential-free, manifest-pinned managed ChatGPT authentication validation within the existing compatibility-authorized App Server child. The default protocol dispatch remains init-only.
- Files changed: Core port/failures define normalized auth outcomes; Codex adapter, supervisor, JSONL transport, profile, and runtime-compatibility modules enforce the narrow auth sequence; manifest/schema pin the permitted surface; dedicated authentication evidence code atomically retains sanitized results; CLI, package scripts, and READMEs expose an explicit opt-in live command; fake runtime and harness tests prove positive, reject, malformed, isolation, evidence, and device-code boundaries.
- Review: 10 patches applied, 0 deferred, 2 rejected as outside this story's synthetic-profile/verified-runtime boundary.
- Follow-up review recommendation: true. The final review changed high-consequence authentication, credential-ownership, evidence, and process-failure behavior.
- Verification: `npm test` passed (125 passed, 3 expected opt-in skips); `npm run validate:protocol` passed (94 passed); `git diff --check` passed.
- Residual risk: The managed browser-login/keychain proof remains deliberately unrun in this unattended session and must be performed only through the explicit opt-in macOS command with an eligible validation subscription.
