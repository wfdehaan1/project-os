---
title: ProjectOS AI Provider Architecture Spine Rubric Review
reviewer: BMad good-spine rubric walker
date: 2026-07-31
artifact: ../ARCHITECTURE-SPINE.md
companion: ../validation-spike.md
verdict: pass-after-resolution
status: historical-superseded
---

# Rubric Review

> This review applies to the superseded 2026-07-31 Codex App Server architecture. It is preserved as historical evidence and does not validate the 2026-08-09 replacement architecture.

## Gate verdict

**Changes required — 0 critical, 3 high, 2 medium findings.** The spine has a strong provider-neutral paradigm, good canonical-state ownership, and unusually concrete Codex lifecycle and contract-test decisions. It passes the mechanical linter and covers most PRD provider capabilities. It does not yet pass the semantic gate because runtime state/credential isolation, effective filesystem containment, and durable retry ownership after local Project deletion remain choices that two implementers could make incompatibly.

## Deterministic pass

Command:

```text
uv --cache-dir /tmp/projectos-uv-cache run .agents/skills/bmad-architecture/scripts/lint_spine.py --workspace _bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31
```

Result: `ok: true`, 0 findings. There are no placeholders, duplicate AD IDs, missing Binds/Prevents/Rule fields, or mechanically detectable version-pin failures.

## Findings

### H1 — Codex runtime profile and credential-store ownership are not fixed

**Evidence:** AD-4 owns the child process but says nothing about the Codex configuration, authentication, log, and session state roots used by that process. AD-5 says Codex owns tokens but does not bind the runtime to macOS secure storage. AD-9 assumes ProjectOS can account for its persisted sessions. The PRD's NFR-8 additionally requires the initial adapter to use macOS-appropriate secure storage.

Current Codex authentication documentation says cached credentials may live in `auth.json` under `CODEX_HOME` (default `~/.codex`) or the OS credential store, and that local Codex surfaces can share cached login state. App Server also persists thread logs and loads configuration that can affect runtime behavior. Owning a process is therefore not the same as owning or isolating its state.

**Divergence:** one implementation can reuse the user's default Codex home and keyring identity, making ProjectOS logout/config/session behavior interact with the user's CLI or IDE; another can use a ProjectOS-specific profile and a separate login. A third can silently fall back to plaintext token storage. Those choices produce incompatible privacy, deletion, support, and account UX.

**Disposition: discuss, then amend the spine.** Add an invariant that explicitly selects the runtime profile/state boundary for the validation adapter. It should at minimum bind:

- whether ProjectOS uses an isolated Codex state/config root or intentionally shares any account state;
- macOS keychain/keyring storage, with a defined fail-closed or disclosed fallback policy rather than accidental plaintext `auth.json` storage;
- how ProjectOS prevents its logout, config, and thread management from mutating unrelated Codex clients or sessions; and
- which minimal non-secret runtime metadata ProjectOS owns for recovery and cleanup.

Add spike evidence showing the effective state/config root and credential-store mode, plus before/after proof that unrelated Codex sessions and login state are unchanged by ProjectOS lifecycle operations.

Sources: [Codex authentication and credential storage](https://developers.openai.com/codex/auth), [Codex App Server](https://developers.openai.com/codex/app-server).

### H2 — AD-8 does not define an enforceable effective read boundary

**Evidence:** AD-8 requires “the most restrictive supported sandbox and approval policy,” a controlled working directory, and no unnecessary tools. The spike repeats that language and detects commands, changes, discovery, or unrelated requests. Neither artifact fixes the concrete effective-access invariant or proves inherited Codex configuration and instruction sources are absent.

Current App Server documentation makes this consequential: a `readOnly` sandbox has full read access by default unless explicit restricted roots are supplied; `workspaceWrite` likewise defaults to full read access. `thread/start` and `thread/resume` also report loaded `instructionSources`, and configured MCP servers can be loaded independently of the client registering dynamic tools.

**Divergence:** one implementation can call a sandbox “read-only” while still allowing reads across the user's filesystem; another can restrict reads to the disposable directory and platform minimums. Both satisfy the present wording but only one satisfies the stated prevention and PRD context-minimization contract.

**Disposition: autofix in the spine.** Make AD-8 enforceable by requiring an explicit restricted read-access object whose allowed roots are enumerated, an explicit no-approval policy for product jobs, and effective disabling/isolation of inherited MCP, app, plugin, skill, and instruction configuration. Require the adapter to inspect returned `instructionSources` and fail closed on anything outside an allowlist. Keep command/file-change events as failed assertions, but do not use event detection as the primary containment control.

Extend the spike to retain the exact effective thread/sandbox configuration, returned instruction sources, and positive/negative read probes for inside and outside the allowed roots. Include a test with non-empty user-level Codex configuration to prove it cannot leak tools or instructions into ProjectOS jobs.

Source: [App Server sandbox read access and thread initialization](https://developers.openai.com/codex/app-server).

### H3 — Cleanup-incomplete retry state has no durable owner after local Project deletion

**Evidence:** AD-9 says cleanup status is recorded before reporting completion, but it does not distinguish local deletion completion from provider-cleanup completion or say where a retry record survives. The PRD's FR-17 allows local deletion to continue with a residual-data warning and retry path, while also requiring Project data and Provider Session Bindings to be removed. The spike expects cleanup-incomplete plus retry but only proves this in a disposable harness.

**Divergence:** an implementation can block all local deletion until every provider responds; another can delete the Project and accidentally delete the only thread IDs needed for retry; another can retain the whole Project as a tombstone. These differ materially in privacy, ownership, and eventual cleanup.

**Disposition: discuss, then amend the spine.** Decide the deletion protocol and durable owner of a minimal cleanup outbox/tombstone. The rule should separate “local Project data deleted” from “provider cleanup complete,” retain only the adapter/session identifiers and retry metadata necessary for cleanup, define when that record is removed, and prevent a cleanup retry from resending Project content. The spike should prove restart-safe retry after the local Project payload and ordinary bindings are gone.

### M1 — Raw provider diagnostics have no data-governance rule

**Evidence:** AD-7 leaves raw provider details in adapter diagnostics, while the seed promises sanitized adapter metadata and the spike retains sanitized JSON-RPC transcripts. No decision fixes whether raw payloads may be persisted, how they are redacted, how long they live, or whether a user can export or delete them.

**Divergence:** adapters can log full prompts, account identifiers, local paths, and provider error bodies differently, undermining the same privacy boundary the port otherwise normalizes.

**Disposition: autofix or defer explicitly.** Prefer an invariant that raw protocol data is memory-only by default; persisted diagnostics are allowlist-sanitized, bounded in retention, excluded from Project exports, and never contain credentials, account identifiers, selected Project content, or local paths. Add redaction contract tests for normal and malformed/error transcripts. If production diagnostics are outside validation scope, put them under Deferred with the safe validation default fixed.

### M2 — Device-code fallback is in the ready spike but outside AD-5's adopted authentication rule

**Evidence:** AD-5 adopts only managed `account/login/start` with `type: chatgpt`. The spike requires a device-code fallback. Current App Server documentation exposes `type: chatgptDeviceCode`, while the authentication guide describes device-code login as beta and notes that user or workspace enablement may be required.

**Divergence:** the spike can fail because an optional/beta fallback is unavailable even though the adopted browser flow works, or an implementer can add a second login mode without a governing decision or compatibility rule.

**Disposition: choose one.** Either remove device-code fallback from the required validation matrix and defer it, or amend AD-5 and AD-10 so managed device-code login is an optional, version/capability-gated recovery path that never handles tokens and never blocks acceptance of the primary browser flow when unavailable.

Sources: [Codex App Server account login](https://developers.openai.com/codex/app-server), [Codex authentication](https://developers.openai.com/codex/auth).

## Good-spine checklist

| Checklist item | Result | Assessment |
|---|---|---|
| Fixes the real divergence points for the level below and misses none | **Partial** | Provider-neutral jobs, capabilities, sessions, schemas, errors, process ownership, version compatibility, and contract proof are fixed. Runtime profile/state isolation, effective read containment, and post-deletion cleanup ownership remain material divergence points. |
| Every AD Rule is enforceable and prevents its stated divergence | **Partial** | AD-1 through AD-7 and AD-10 through AD-11 are generally testable. AD-8's “most restrictive” wording is not an exact access policy; AD-9 lacks a restart-safe cleanup-state owner. |
| Nothing under Deferred can let two units diverge | **Pass** | Runtime distribution, local adapter implementation, cross-provider hidden context, routing/fallback, and root-thread ephemerality have explicit boundaries and revisit conditions. The no-silent-fallback rule is appropriately retained. |
| Named technology is verified current | **Pass with bounded version decision** | Official docs currently support stdio JSON-RPC, initialize/initialized, managed ChatGPT and device-code login, account/rate-limit state, per-turn `outputSchema`, restrictive read-access inputs, persistent threads, and `thread/delete`. No Codex binary version is pinned yet; AD-10 and the spike correctly make that a pre-provider-work gate. |
| Ratifies rather than contradicts a brownfield codebase | **N/A** | No implementation code was presented as an existing architectural authority for this slice. |
| Covers the driving spec's capabilities | **Partial** | The provider-independence, canonical Conversation, ChatGPT allowance, structured proposal, normalized-error, export/restore, and cleanup requirements land. NFR-8's secure credential storage and FR-17's residual cleanup retry need explicit architecture ownership. |
| Does not weaken an inherited parent spine | **N/A** | No parent architecture spine is identified. The listed inherited product invariants are preserved. |
| Every owned dimension is decided, deferred, or open | **Partial** | Provider API, process, protocol, auth, state authority, session lifecycle, testing, and distribution are covered. Operational diagnostics and the runtime state/config envelope are silent or underspecified. |

## Validation-spike consistency

The spike is substantially consistent with the spine and correctly tests the fake-adapter proof, protocol/version gate, managed subscription authentication, allowance normalization, structured-output validation, containment, canonical Conversation ownership, export/restore without bindings, and provider-session deletion.

Required reconciliation before calling the spike `ready`:

1. Add runtime profile, credential-store, shared-client side-effect, and unrelated-session isolation evidence for H1.
2. Replace “most restrictive” with exact effective-access assertions and inherited-configuration probes for H2.
3. Prove restart-safe provider cleanup retry after local Project payload removal for H3.
4. Add redaction/retention assertions for M1.
5. Resolve whether device code is required, optional, or deferred for M2.

## Positive observations

- The named Ports and Adapters paradigm plus capability negotiation carries the future-provider intent without turning the port into a vendor-shaped API.
- AD-3 and the fake-adapter requirement make provider independence observable rather than aspirational.
- AD-6 validates structured output twice and keeps provider-native result shapes outside Canonical State.
- AD-10 makes protocol drift fail closed before authentication or provider work.
- Deferred items are disciplined: they preserve future local/cloud adapters without expanding the validation slice.

## Recommended gate action

Amend the spine for H1-H3, reconcile the spike, and rerun the rubric gate. M1 is a clear safe-default fix. M2 can be resolved by a small scope choice. No rewrite of the provider abstraction is indicated.

## Resolution addendum — 2026-07-31

**Updated verdict: pass — 0 critical or high findings remain.** The deterministic linter still reports 0 findings.

- **H1 resolved:** AD-4, AD-5, and AD-13 now fix the isolated `CODEX_HOME`, scrubbed configuration/environment, macOS keyring, fail-closed storage, shared-client isolation, and concurrent-instance ownership. Spike §§1–2 prove those properties.
- **H2 resolved:** AD-8 now fixes restricted readable roots, zero writable roots, `approvalPolicy: never`, disabled inherited extensions, instruction-source allowlisting, hostile-input containment, and fail-before-side-effect behavior. Spike §5 tests the effective envelope.
- **H3 resolved:** AD-9 and `ProviderCleanupOutbox` now own crash-safe lifecycle receipts, separate local/provider completion states, idempotent reconciliation, and content-free retry after Project erasure. Spike §6 exercises every relevant crash and retry boundary.
- **M1 resolved:** AD-7 makes raw payloads memory-only and strictly allowlists persisted diagnostic fields; spike §3 verifies the exclusion contract.
- **M2 resolved:** AD-5 makes device-code login optional and capability/version gated; spike §2 records unsupported availability without failing the primary browser-login gate.

No prior finding remains open. The revised spike is consistent with the revised spine for all five items.
