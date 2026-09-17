# Codex native chat experiment

A SwiftUI chat inside the sandboxed ProjectOS app, backed by Codex through ACP. Codex owns the model/tool loop and uses its built-in web search. ProjectOS keeps a local transcript and validates suggested changes as pending proposals. The experiment sends synthetic garden-office data only.

See [REPORT.md](REPORT.md) for actual live results, screenshots, review fixes, and shipping limitations.

## Run

Requirements: macOS/Xcode matching the ProjectOS target, Node 22+, and an existing Codex-managed ChatGPT login. This uses that account; it does not switch to API billing. The pinned adapter is `@agentclientprotocol/codex-acp@1.12.0`; `package-lock.json` pins its runtime dependencies. Observed bundled Codex CLI: `0.154.0`.

From this directory:

```sh
npm ci
npm start
```

Leave the helper running. Copy its ephemeral `PORT:TOKEN` pairing code. Do not save the code in source control or screenshots. It grants access to this local helper, expires when it stops, and is not a provider credential.

Build from the repository root:

```sh
rtk xcodebuild -project apps/ProjectOS/ProjectOS.xcodeproj -scheme ProjectOS \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/ProjectOSCodexDerivedData \
  -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages \
  -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES build
rtk proxy open -n /tmp/ProjectOSCodexDerivedData/Build/Products/Debug/ProjectOS.app --args --codex-experiment
```

The explicit launch bypasses production environment/store initialization. Normal ProjectOS also has **File → Codex Experiment**. Paste the code, Connect, check the visible model, and Send. **Suggest project update** asks for one question/research proposal and validates it using the production schema and exact synthetic evidence. There is no Apply action.

**Stop** sends ACP cancellation and preserves the received partial answer. **Resume** attaches the saved session after app/helper restart. **Start fresh** archives the local transcript and opens a new agent session. Deselecting new context does not remove earlier agent history. A reconnect after missed events can leave remote history ahead of the local transcript; this is disclosed in the preview.

The helper must run outside the application sandbox. It accepts only authenticated loopback HTTP, rejects browser Origin requests, then speaks JSONL over the adapter's stdio. No terminal is embedded in the app. The app's existing sandbox entitlements remain enabled. Manual helper launch/pairing is experimental setup, not the intended shipping UX.

## State and diagnostics

- `.runtime/` is ignored and owner-only. It holds the synthetic working directory and experiment-owned session registry. Keep it to resume after helper restart.
- The app saves `ProjectOS/CodexExperiment/state.json` beneath its sandbox's Application Support directory, with archives beside it. Pairing secrets stay in memory.
- Pending proposal JSON is saved and revalidated on restoration. Tool activity is displayed live; this experiment does not reconstruct its activity list after app restart.
- Adapter stderr is not forwarded. Errors never trigger automatic prompt replay, model fallback, or API authentication.
- If state is unreadable, automatic writes are disabled to preserve the original. Move the damaged experiment file aside deliberately and restart the app before reconnecting.
- New interactive login, account switching, expired login recovery, and distribution packaging have not been qualified. If not signed in, use Codex's own login flow separately and restart the helper.
- Stop the helper with Ctrl-C when finished. The app's Disconnect cancels an active turn but leaves the separately launched helper running.

## Checks

```sh
npm test
```

From the repository root, use the build arguments above with `test -only-testing:ProjectOSTests/CodexExperimentTests`. The UI fixture is available using `--codex-experiment --codex-experiment-fixture`; it is visibly labeled and never calls Codex. The XCUITest is `ProjectOSUITests/CodexExperimentUITests`.

The explicit live driver consumes subscription usage and is excluded from `npm test`. Start a helper with `node relay.mjs --pairing-file /tmp/unique-private-pairing-file`, then run:

```sh
node live-check.mjs /tmp/unique-private-pairing-file search
node live-check.mjs /tmp/unique-private-pairing-file proposal
node live-check.mjs /tmp/unique-private-pairing-file cancel
node live-check.mjs /tmp/unique-private-pairing-file probe
# Restart helper with another private pairing file, preserving .runtime, then:
node live-check.mjs /tmp/new-private-pairing-file resume
```

The default private session handle is `/tmp/projectos-codex-live-state.json`; a third argument overrides it. Evidence JSON contains synthetic content, tool summaries, and outcomes, not pairing tokens or session IDs. The `probe` asks for a harmless marker inside the synthetic workspace; its refusal demonstrates observed behavior only.

## Boundaries

No SearXNG or ProjectOS MCP tools are supplied to Codex. The normal conversation's SearXNG toggle is now gated to local Ollama, even if an old OpenRouter conversation has research enabled.

The relay rejects client filesystem/terminal methods, file/command permission requests, API-key authentication, arbitrary session IDs, and permission-mode escalation. Runtime configuration disables shell and other non-research features, with instructions restricting use to chat/research. **This is not complete OS containment:** the pinned adapter's `read-only` mode uses a workspace-write sandbox preset internally, native tools execute in Codex, and the user's normal Codex profile still participates in authentication/session storage. Do not connect production project data until runtime/configuration isolation has been designed and verified.
