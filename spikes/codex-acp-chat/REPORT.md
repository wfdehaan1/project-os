# Native Codex chat experiment — 2026-09-16

## Result

**The interaction is viable.** The signed, sandboxed ProjectOS app connected to Codex, streamed native chat, displayed Codex's built-in search/page-open activity and clickable citations, validated a pending proposal, stopped a live stream, and restored the conversation after relaunch. No embedded terminal or SearXNG forwarding was needed.

This is a synthetic-data experiment on `feat/codex-spike`, not a production Codex provider release. A manually launched Node helper hosts the ACP adapter outside the app sandbox. Packaging that runtime and establishing effective tool/configuration isolation remain separate engineering work.

## Observed setup

- Pinned adapter: `@agentclientprotocol/codex-acp@1.12.0`, bundled Codex CLI `0.154.0`.
- Authentication: existing Codex-managed ChatGPT login; no new interactive login, credential copying, API key, or billing fallback.
- Returned model: `gpt-6-astra[high]`, visible as “6 Astra (high)” in the native picker.
- macOS 27.0 arm64; Xcode build uses the installed macOS 26.5 SDK.
- App Sandbox remains enabled. The app uses outbound loopback HTTP; the helper uses authenticated JSON RPC over stdio to the adapter.
- All prompts used a synthetic garden-office project. Production project stores were not opened by the isolated experiment launch.

## Evidence

| Check | Actual result | Artifact |
|---|---|---|
| ACP initialization and session creation | Passed with existing ChatGPT login | Live evidence adapter/model fields |
| Built-in research through relay | Actual Codex `webSearch` activity, answer and official citation | [live-search.json](evidence/live-search.json) |
| Native research | Streamed answer, completed web-search and page-open rows, clickable source | [native-search.png](evidence/native-search.png) |
| Generated proposal | Real JSON passed the production schema and exact-evidence validator | [live-proposal.json](evidence/live-proposal.json), unit test |
| Native pending proposal | Question displayed as validated/pending; no acceptance operation | [native-proposal.png](evidence/native-proposal.png) |
| Early relay cancellation | `stopReason: cancelled` after 1,674 ms, before text arrived | [live-cancel.json](evidence/live-cancel.json) |
| Native streaming cancellation | Stop retained 1,808 received characters, marked interrupted | [native-stop.png](evidence/native-stop.png), [saved summary](evidence/native-state-before-relaunch.json) |
| Helper process restart/resume | Same session recalled marker COPPER-417, 12 m² and EUR 15,000 without resending | [live-resume.json](evidence/live-resume.json) |
| Native app relaunch/resume | Six messages before and after, identical partial length, pending proposal restored; no replay duplication | [before](evidence/native-state-before-relaunch.json), [after](evidence/native-state-after-resume.json) |
| Context deselection | “Only your next message” alongside explicit retained synthetic-context disclosure | Direct native accessibility inspection |
| Start fresh | Empty new chat, contextWasSent false; six-message prior transcript and proposal archived | [native-fresh.json](evidence/native-fresh.json) |
| Harmless file/command probe | Codex refused, zero tool events, no marker file appeared | [live-probe.json](evidence/live-probe.json) |

Screenshots show the actual live native app, not fixture output. The relay live-driver checks ran earlier on the same day; the reviewed native build was exercised afterward.

## Deterministic verification

- **8/8 Node tests passed.** Covers fragmented Unicode, owned-session parameter stripping, authentication and Origin rejection, exact permission choices, cancellation/no overlapping turn, replay marking, denied filesystem/terminal methods, adapter death, environment sanitization, and recovery from event-history eviction.
- **7/7 native unit tests passed**, including the actual captured live proposal and fabricated-evidence rejection, context/history/fresh archive semantics, replay and late cancellation deltas, pending proposal restoration, corrupt-file preservation, pairing validation, and the OpenRouter SearXNG gate.
- Native build succeeded with the sandbox enabled. Final verification on 2026-09-17: [test summary](evidence/native-unit-tests.json). Result bundle: `/tmp/ProjectOSCodexDerivedData/Logs/Test/Test-ProjectOS-2026.09.17_07-07-18-+0200.xcresult`.
- **Automated XCUITest did not run:** its runner timed out while enabling automation mode. The UI test is retained as a deterministic fixture; this is an environment failure, not a passing UI result. Direct native interaction provided the separate live UI evidence above.
- No provider-backed calls are part of the deterministic tests.

## Review corrections

Independent adversarial and edge-case reviews identified lifecycle defects. Corrections preserve production environment observation, prevent independent experiment windows from overwriting state, establish a current event cursor on reconnect, enforce question/research proposal kinds, disconnect on terminal helper failure, preserve final available text on failed turns, prevent overwriting corrupt saved history, and restore validated pending proposals. Session registry writes now use separate atomic records so concurrent helpers do not overwrite a shared list. Startup failure cleans up the adapter; runtime directories reject symlinks. Tests cover the key persisted-state and cursor regressions.

## What remains unproven

1. **Complete tool containment.** ACP client-side filesystem/terminal requests are denied, but Codex native tools execute inside the runtime. The pinned adapter maps its “read-only” mode to a workspace-write sandbox preset. Runtime flags disable shell and several integrations; the refusal probe is observed behavior, not an adversarial security proof. An empty MCP list alone does not establish independence from the user's Codex configuration.
2. **Shipping runtime management.** Installation, app/helper lifecycle, signing, updates, account login/expiry and an appropriate distribution model need design. The experiment preserves the production sandbox instead of disabling it to launch arbitrary binaries.
3. **Full history reconciliation.** The app preserves its received transcript and suppresses ACP load replay. After a crash/disconnect, Codex may retain output the app missed; the preview discloses this. Tool activity is currently live-only and not reconstructed on relaunch. Archives are retained on disk without an archive browser.
4. **Production projects and other providers.** The experiment has no accepted-state mutation path. Native web citations are links, not stored evidence snapshots. A provider-neutral agent session abstraction, source capture, permission qualification and normal conversation integration remain future work.
5. **Personal usefulness.** A short synthetic workflow proves integration mechanics, not sustained day-to-day value.

## Recommendation

Proceed with a session-oriented agent integration for Codex and future agent providers, while retaining the current direct-inference path for local models. The UI should always distinguish new context from remembered agent history. Let each external agent own its tool loop; keep ProjectOS's proposal validator and acceptance transaction as the authority for project knowledge. Resolve runtime packaging and enforceable restrictions before exposing real project context.
