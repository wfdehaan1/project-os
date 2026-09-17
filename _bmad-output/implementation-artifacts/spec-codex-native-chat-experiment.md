---
title: Codex native chat and research experiment
type: feature
created: 2026-09-16
status: done
baseline_commit: c394ad6b9649deb3afd631e90a543b5199e6a66a
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="User explicitly authorized the proposed experiment in this conversation">

## Intent

**Problem:** ProjectOS needs evidence that Codex can supply native chat and research while the application retains conversations and controls accepted knowledge. Previous experiments did not establish this complete interaction. The user approved executing the proposed experiment on their existing `feat/codex-spike` branch.

**Approach:** Add an isolated Codex Experiment window to the existing signed, sandboxed macOS app. Use synthetic garden-office context, a pinned Codex ACP adapter, and Codex's own built-in web search. Exercise streaming, stop, restart/resume, fresh sessions, and one locally validated proposal. Preserve existing project data and report actual evidence separately from deterministic checks.

## Boundaries & Constraints

**Always:** Keep the current branch. Keep the main app sandbox enabled. Only synthetic experiment context is sent during validation. Show agent/model, external execution, context added this turn, remembered session history, and native research activity. ProjectOS alone owns accepted-state mutations. Use existing Codex-managed ChatGPT authentication through the runtime; never read, copy, or log credentials. The experiment may create its own Codex sessions and consume the user's subscription as authorized by executing it. Use local-only, ephemeral authenticated IPC if the sandbox requires a separately launched runtime helper, and disclose that topology. Keep reproducible setup, version pinning, protocol tests, native screenshots, and an honest results report. SearXNG is exclusively for local Ollama; no SearXNG/MCP research forwarding to Codex.

**Ask First:** If new interactive account login is necessary, request the user's action. Do not switch to API billing or another provider. If a runtime restriction cannot be enforced, report that exact unsupported capability; do not label prompt instructions a security boundary.

**Never:** Apply experiment proposals to production projects, change normal Codex configuration, log raw authentication/protocol payloads containing credentials, perform destructive runtime probes, silently auto-approve arbitrary agent actions, or reclassify an unrun live check as passed. No terminal is required in the product UI. No automatic runtime installer in the app.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Chat and research | Explicit send, synthetic context, selected Codex model | Stream native chat; render actual Codex search/tool events | Preserve partial output and actionable error |
| Permission | Agent asks to act | Show actual offered choices scoped to current turn; disallowed file/command operations rejected | Stale/cancelled requests rejected |
| Context | Context selection changes on existing session | Preview distinguishes newly sent text from retained history | Fresh session needed to omit remembered history |
| Resume | App/helper restarted | Reattach same agent session and keep local transcript once | Unsupported/expired session offers explicit fresh start |
| Stop | Streaming or awaiting permission | Send ACP cancel, retain interrupted output, reject late changes | No automatic replay |
| Proposal | Explicit request for update over disclosed synthetic evidence | Validate actual ProjectOS schema and exact evidence; display pending only | Invalid JSON/evidence produces no pending proposal |
| Local research | OpenRouter selected with stored research preference | No SearXNG tool invocation; local-only disclosure | Existing local workflow remains available |

</frozen-after-approval>

## Code Map

- `apps/ProjectOS/ProjectOS/App/ProjectOSApp.swift` — native scenes/menu; add experiment entry.
- `apps/ProjectOS/ProjectOS/Experiments/Codex/` — new view, model, authenticated transport and persistence.
- `apps/ProjectOS/ProjectOS/AI/InferenceService.swift` — reference for proposal context conversion; avoid forcing ACP into stateless inference.
- `apps/ProjectOS/Packages/ProjectOSCore/Sources/ProjectOSCore/Proposals/ProposalValidator.swift` — reuse real proposal validator.
- `apps/ProjectOS/ProjectOS/App/AppEnvironment.swift` and `Features/Conversation/ConversationView.swift` — local-only research gate and disclosure.
- `spikes/codex-acp-chat/` — pinned npm runtime, helper, setup/live scripts, protocol tests and report.

## Tasks & Acceptance

**Execution:**
- [x] `spikes/codex-acp-chat/` — pin adapter; implement authenticated loopback ACP relay with bounded queues, process ownership, timeouts, synthetic live runner and tests. Do not expose an unauthenticated listener.
- [x] `apps/ProjectOS/ProjectOS/Experiments/Codex/` — implement chat, native activity/permissions, explicit model selection, proposal validation and isolated durable transcript/session state.
- [x] `apps/ProjectOS/ProjectOS/App/ProjectOSApp.swift` — expose experiment window without touching real projects.
- [x] `apps/ProjectOS/ProjectOS/App/AppEnvironment.swift` and research UI — make SearXNG local-only and explain it.
- [x] `apps/ProjectOS/ProjectOSTests/` and `ProjectOSUITests/` — verify lifecycle/context/proposal invariants and real native UI with deterministic transport fixtures.
- [x] `spikes/codex-acp-chat/README.md` and `REPORT.md` — document reproducible launch, topology, exact live/deterministic evidence, observed restriction gaps and recommendation.

**Acceptance Criteria:**
- Given the sandboxed ProjectOS app, when the experiment opens, then a usable native chat appears without access to production project data.
- Given Codex is selected, when research executes, then evidence includes a genuine Codex built-in search event and no SearXNG request.
- Given a valid generated proposal, when it is displayed, then the production validator has accepted its schema/evidence and accepted project state remains unchanged.
- Given live prerequisites or containment fail, when the report is delivered, then the exact failed check and evidence are recorded separately from passed checks.

## Spec Change Log

## Design Notes

One external agent owns its tool loop. ACP carries chat/session events; the helper may bridge authenticated localhost HTTP to the adapter's stdio without implementing its own agent or web-search tool. The runtime helper is an explicit experiment launch component outside the app sandbox, not proof of distributable in-app runtime management. Local transcript is canonical for display; session replay is handled separately to avoid duplicate messages. Native Codex citations are links, not retained SearXNG source snapshots. Proposal evidence initially refers to exact synthetic user/context text.

## Verification

- Targeted `node --test` relay tests: framing, auth, cancellation, replay and failure handling.
- Xcode build and targeted app/UI tests using `/tmp/ProjectOSCodexDerivedData` and isolated experiment state.
- Explicit synthetic live workflow through the pinned runtime: auth, chat/search, proposal, stop, resume, fresh context, capability probes.
- Inspect the actual sandboxed native window and retain screenshot evidence. Build success alone is insufficient.

## Results and Review

Completed on 2026-09-17. Live native chat/search, pending proposal, partial cancellation, app resume and fresh-session archive checks passed. Eight relay tests and seven native unit tests pass. XCUITest could not initialize macOS automation; direct native interaction is reported separately. See [experiment report](../../spikes/codex-acp-chat/REPORT.md) and [launch instructions](../../spikes/codex-acp-chat/README.md).

Independent Blind Hunter and Edge Case Hunter reviews completed. Lifecycle, persistence, cursor, window ownership and proposal-kind findings were triaged as implementation patches and fixed. Follow-up patches reject dead cursor handshakes and remove the extra scene's implicit menu command. Missing remote output reconciliation is explicitly disclosed rather than claiming local completeness. No intent changes or sprint story mapping.

## Suggested Review Order

- Start with the measured result and remaining runtime boundary.
  [REPORT.md:3](../../spikes/codex-acp-chat/REPORT.md#L3)

- Inspect authenticated IPC and the restricted ACP surface.
  [relay.mjs:175](../../spikes/codex-acp-chat/relay.mjs#L175)

- Check runtime flags separately from claimed containment.
  [relay.mjs:199](../../spikes/codex-acp-chat/relay.mjs#L199)

- Trace resume, streaming, cancellation and saved history.
  [CodexExperimentModel.swift:104](../../apps/ProjectOS/ProjectOS/Experiments/Codex/CodexExperimentModel.swift#L104)

- Verify proposals remain pending and require exact evidence.
  [CodexExperimentModel.swift:318](../../apps/ProjectOS/ProjectOS/Experiments/Codex/CodexExperimentModel.swift#L318)

- Review new-context and retained-history presentation.
  [CodexExperimentView.swift:3](../../apps/ProjectOS/ProjectOS/Experiments/Codex/CodexExperimentView.swift#L3)

- Check local-only SearXNG gating.
  [AppEnvironment+Presentation.swift:173](../../apps/ProjectOS/ProjectOS/App/AppEnvironment+Presentation.swift#L173)

- Inspect deterministic coverage and captured live proposal validation.
  [CodexExperimentTests.swift:1](../../apps/ProjectOS/ProjectOSTests/CodexExperimentTests.swift#L1)

- Check transport regression tests and reproducible setup.
  [relay.test.mjs:1](../../spikes/codex-acp-chat/test/relay.test.mjs#L1)
