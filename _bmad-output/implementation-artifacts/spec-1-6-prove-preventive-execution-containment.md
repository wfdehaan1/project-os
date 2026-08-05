---
title: 'Story 1.6: Prove Preventive Execution Containment'
type: 'feature'
created: '2026-08-05'
baseline_revision: 'f387ec17f2ff3afd304662012e74e0a0d291508c'
final_revision: '9b5f180'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '/Users/wouter/Projects/Personal/ProjectOS/_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: []
---

<intent-contract>

## Intent

**Problem:** The harness isolates its Codex profile and rejects live structured-output validation, but isolation plus post-hoc protocol event rejection does not prevent an App Server from reading unrelated data, using built-in tools, or causing side effects. Story 1.5 may not dispatch a real provider turn until this hard gate is proven.

**Approach:** Add a narrow, one-run containment-validation path that can mint an opaque attestation only after exact compatibility, a restrictive per-thread/per-turn envelope, and a stable tool-disable mechanism or externally verified macOS containment boundary have prevented hostile fixture effects. Keep the existing structured-output path denied unless it receives that current attestation.

## Boundaries & Constraints

**Always:** Reuse the immutable executable snapshot, isolated profile, sole App Server supervisor, exact manifest/schema compatibility, `experimentalApi: false`, and default-deny RPC model. The effective job envelope must declare an explicit disposable/runtime-required read set, zero writable roots, `approvalPolicy: never`, no inherited instructions/tools/MCP/apps/plugins/skills/connectors, and an allowlisted `instructionSources` result. Evidence must compare pre/post canaries and retain only structural IDs, digests, counts, configuration fingerprints, instruction-source records, and stop conditions; it must not retain paths, secrets, prompts, project content, raw payloads, URLs, or account identity.

**Block If:** The pinned runtime cannot expose a structurally parseable containment thread/turn contract, or no stable runtime disable mechanism or verifiable external OS containment boundary can prevent filesystem, command, web, connector, tool, and permission effects *before* they occur. Detection or cleanup after an effect is not a pass.

**Never:** Add generic RPC dispatch, a reusable chat/agent transport, writable project roots, production UI, Canonical State mutation, API-key/credential ownership, dynamic provider capabilities, or a claim that fake-only tests prove live-provider containment. Do not loosen the existing structured-output precondition merely to execute a live probe.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Contained ordinary probe | Exact compatible snapshot, allowed fixture, verified boundary | One attestation bound to run, snapshot/manifest, and attempt; allowed-root read only | Reject if effective envelope or instruction sources differ |
| Hostile probe | Injection, traversal/symlink, inherited config/MCP, secret-env, file/web/command/connector/permission fixture | No unrelated access, transmission, mutation, or capability effect; sanitized zero-effect evidence | Fail closed; record a structural containment stop condition |
| Missing/changed proof | Boundary unavailable, evidence write fails, attestation forged/reused/cross-attempt, unexpected event | No thread/turn or structured validation dispatch; adapter remains `reject` | Destroy owned child and retain no raw/private content outside private evidence |

</intent-contract>

## Code Map

- `spikes/codex-app-server-harness/src/core/{ai-provider-port,preventive-execution-containment}.ts` -- ProjectOS-owned validation request/result, opaque per-attempt attestation, and safe reject outcome; no Codex wire types cross the port.
- `spikes/codex-app-server-harness/src/adapters/codex/{runtime-profile,app-server-supervisor,runtime-compatibility,protocol-contract,jsonl-rpc-connection,codex-app-server-adapter}.ts` -- compose the external/stable preventive boundary before owned spawn; mint a containment-only compatibility capability; validate exact thread/turn request and notification shapes; bind the attestation to exact runtime facts.
- `spikes/codex-app-server-harness/src/evidence/{containment-evidence-schema,containment-evidence-recorder}.ts` and `evidence/containment-validation-run.schema.json` -- atomic private/sanitized containment evidence with strict allowlists and no sensitive values.
- `spikes/codex-app-server-harness/protocol/supported-runtime-manifest.json` -- bounded containment request/notification contract while preserving default `initialize`/`initialized` dispatch.
- `spikes/codex-app-server-harness/test/{preventive-execution-containment,protocol-contract,runtime-profile,app-server-supervisor,codex-app-server-adapter,adapter-boundary,cli,workspace}.test.ts` and fake runtime/fixture files -- deterministic hostile-effect, request-shape, isolation, attestation, evidence, and regression proof.
- `spikes/codex-app-server-harness/{package.json,README.md,evidence/README.md}` -- focused offline commands, explicit opt-in live probe, boundary limitations, and truthful reject/proceed evidence.

## Tasks & Acceptance

**Execution:**
- [x] `spikes/codex-app-server-harness/src/core/{ai-provider-port,preventive-execution-containment}.ts` -- define immutable, non-forgeable containment validation outcomes and a one-run attestation that cannot enable arbitrary provider dispatch.
- [x] `spikes/codex-app-server-harness/src/adapters/codex/{runtime-profile,app-server-supervisor}.ts` -- construct and verify the restrictive external or stable-disable execution envelope before spawn, with allowed-root inventory, zero writable roots, scrubbed environment, inherited-configuration exclusion, owned process cleanup, and pre/post canaries.
- [x] `spikes/codex-app-server-harness/src/adapters/codex/{protocol-contract,runtime-compatibility,jsonl-rpc-connection,codex-app-server-adapter}.ts` and `spikes/codex-app-server-harness/protocol/supported-runtime-manifest.json` -- add containment-only typed thread/turn wrappers; require `approvalPolicy: never`, `experimentalApi: false`, Context Preview-only input, and exact allowed instruction sources; gate structured validation on a current matching attestation.
- [x] `spikes/codex-app-server-harness/src/evidence/{containment-evidence-schema,containment-evidence-recorder}.ts`, `spikes/codex-app-server-harness/evidence/containment-validation-run.schema.json`, and `spikes/codex-app-server-harness/evidence/README.md` -- atomically record strict sanitized proof and `reject` stop conditions; fail closed on any recorder/schema failure.
- [x] `spikes/codex-app-server-harness/test/fixtures/`, `spikes/codex-app-server-harness/test/preventive-execution-containment.test.ts`, and existing focused protocol/profile/adapter/CLI/workspace tests -- model allowed read plus all hostile fixture classes; prove prevention before effects, no context broadening, attestation non-reuse, normal-profile invariance, and no generic dispatch.
- [x] `spikes/codex-app-server-harness/{package.json,README.md}` and `_bmad-output/implementation-artifacts/sprint-status.yaml` -- add offline containment validation and an explicitly opt-in live command; record only the actually demonstrated gate outcome.

**Acceptance Criteria:**
- Given a compatible validation job, when its thread and turn are created, then its effective envelope has only the disposable/runtime-required readable roots, no writable roots, `approvalPolicy: never`, and `experimentalApi: false`.
- Given a job starts from a profile with user instructions or tool configuration, when containment configuration is applied, then dynamic tools, MCP, connectors, apps, plugins, skills, and inherited instructions cannot affect it and returned instruction sources equal the explicit allowlist.
- Given an allowed-root file and outside-root canaries, when ordinary, traversal, and symlink probes run, then only the allowed read succeeds and independently captured filesystem evidence proves no outside data access or mutation.
- Given every named hostile fixture, when processed, then it either completes safely or fails closed before filesystem, secret, web, command, connector, tool, or permission effects and cannot broaden the Context Preview.
- Given App Server exposes a built-in capability, when the control design is evaluated, then a stable disable mechanism or external OS boundary prevents its effect before it occurs; detecting an event later is insufficient.
- Given containment evidence is missing, malformed, contradictory, or reports an effect, when the run concludes, then the adapter records `reject`, does not mint/use an attestation, and later production work remains blocked.

## Spec Change Log

## Review Triage Log

### 2026-08-05 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 5 (high 4, medium 1)
- defer: 0
- reject: 0
- addressed_findings:
  - `[high]` `[patch]` Removed the publicly callable attestation minting path so a caller cannot self-assert a verified containment boundary.
  - `[high]` `[patch]` Made `proceed` evidence require a verified boundary, bound fingerprints, the exact instruction source, an observed allowed read, zero hostile effects, and no stop condition.
  - `[high]` `[patch]` Rejected extra own properties on containment thread/turn wrappers so they cannot silently widen into a generic transport.
  - `[high]` `[patch]` Removed the profile-derived structural envelope helper because its writable directories were not independently enforced as read-only containment.
  - `[medium]` `[patch]` Rejected sparse stop-condition arrays so serialized evidence cannot contain schema-invalid holes.

## Design Notes

Containment must be a separately minted capability rather than a boolean supplied by a caller. The minting proof binds the exact executable snapshot, manifest digest, attempt/run identity, effective envelope, and zero-effect observations; each use consumes it. This keeps Story 1.5's narrowly typed structured-output route from becoming a backdoor generic turn transport.

## Verification

**Commands:**
- `npm run typecheck` -- expected: strict TypeScript passes.
- `npm run validate:protocol` -- expected: exact manifest/schema and default-deny dispatch remain intact.
- `npm run test:containment` -- expected: deterministic envelope, hostile fixture, evidence, and attestation tests pass without a live provider process.
- `npm run validate:containment` -- expected: typecheck plus the focused offline containment suite pass.
- `npm run test:structured-output` -- expected: Story 1.5 remains fake-backed unless a verified current attestation is present.
- `npm test` -- expected: full offline harness regression passes and live probes remain opt-in/skipped.
- `git diff --check` -- expected: no whitespace errors.

## Auto Run Result

Status: done

Story 1.6 adds a strict containment gate, but its truthful outcome is `reject`: the harness has no independently verifiable pre-side-effect macOS or stable runtime boundary. The adapter therefore records `containment_boundary_unavailable` and returns nonzero before executable discovery, child spawn, thread, turn, or provider action. This prevents unsafe execution; it is not evidence that live provider containment has been proven.

Implemented areas:

- ProjectOS-owned containment request/result and opaque attestation contracts, with no public minting path.
- Manifest-pinned typed containment wrapper checks, exact request fields, immutable fail-closed defaults, and a nonzero CLI rejection.
- Atomic, private, sanitized containment evidence and JSON Schema with result-dependent success invariants.
- Hostile-class pre-dispatch tests, documentation, focused scripts, and the Epic 1 tracker.

Review: 5 review-driven patches applied (4 high, 1 medium); 0 deferred; 0 rejected. Follow-up review recommendation: true, because the independent review hardened several linked proof-boundary and evidence-invariant paths.

Validation completed on 2026-08-05:

- `npm run typecheck` — passed.
- `npm run validate:protocol` — passed (98 tests).
- `npm run validate:containment` — passed (16 tests).
- `npm run test:structured-output` — passed (17 tests).
- `npm test` — passed (146 tests; 4 explicit live tests skipped).
- `git diff --check` — passed.

Residual risk: a real allowance of runtime tools or an operating-system containment profile has not been verified. The capability cannot be minted and all containment probes remain reject-before-discovery until that proof exists; live provider containment is intentionally unproven.
