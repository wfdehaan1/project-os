# Current OpenAI platform review

> **Historical review.** This review applies to the superseded 2026-07-31 Codex App Server architecture. Epic 1 later recorded `reject`; it does not validate the 2026-08-09 Ollama / LM Studio / MLX / OpenRouter architecture.

**Review lens:** Codex/OpenAI platform correctness, current support status, and version binding.

**Reviewed:** `ARCHITECTURE-SPINE.md` and `validation-spike.md` as present on 2026-07-31. Deliverables were not edited.

**Authority used:** the fresh official manual at `/private/tmp/openai-docs-cache/codex-manual.md`, principally Authentication lines 10483-10724 and Codex App Server lines 26527-28751. As an environment observation, the installed `codex-cli 0.145.0` was also queried with `codex app-server --help`.

## Verdict

**Proceed with constraints; not ready to finalize as a production architecture contract.** The essential App Server claims are current: stdio JSON-RPC, initialize/initialized, managed ChatGPT login, plan reporting, rate-limit reporting, persistent/resumable threads, per-turn `outputSchema`, streaming/cancellation, and `thread/delete` are documented. Four load-bearing gaps remain: containment is stronger in the spine than the platform contract supports; the Codex home/config/auth boundary is unspecified; AD-10 promises a version range that does not exist in either artifact; and several normalized failure states are more precise than the documented protocol signals.

## Findings

### High — AD-8 overstates execution containment

**Affected:** spine lines 81-85; spike lines 73-80 and stop condition line 122.

The official protocol supports read-only/restricted-read sandbox policies, but it does not document a stable switch that removes Codex's built-in command, file, or web tools from a normal turn. Command and file-change items are first-class App Server events, and approval policy governs approval prompting rather than proving that no command will execute. A read-only sandbox can still permit read commands. `dynamicTools` only controls client-defined tools and is experimental; omitting it does not disable built-in tools. The protocol even exposes `thread/shellCommand`, which runs outside the sandbox, although ProjectOS can and should never call it.

Evidence:

- A turn may emit command, file-change, MCP, and web-search items: manual 27797-27809.
- Command/file approvals are conditional on settings, not a no-execution guarantee: manual 27849-27881.
- Restricted read roots are supported, but full read access is the default when access is omitted: manual 27430-27465.
- `dynamicTools` is experimental and separate from built-in tools: manual 27056-27058 and 27916-27928.
- `thread/shellCommand` is explicitly outside the sandbox: manual 27355-27365.

**Required correction:** phrase AD-8 as a validation-dependent containment target, not a platform guarantee. The spike should test a concrete envelope: an empty disposable `cwd`, an explicit `readOnly` policy with restricted readable roots, no writable roots, no optional capabilities, `experimentalApi: false`, no MCP/app/plugin configuration, and fail-fast handling for any `commandExecution`, `fileChange`, `mcpToolCall`, `dynamicToolCall`, `webSearch`, or permission request. If the product requirement is prevention rather than detection, validate an outer macOS process sandbox/Seatbelt boundary; App Server settings alone do not establish it. Keep the existing stop condition.

### High — process ownership does not imply state, credential, or configuration isolation

**Affected:** spine lines 57-67, 81-91; spike lines 19, 27-44, 73-90.

Starting a ProjectOS-owned child process does not isolate its Codex state. By default, Codex credentials and configuration live under the user's Codex home, and CLI/IDE login state is shared. Logging out through a process using the shared home can sign the user out of their ordinary Codex CLI/extension session. User/system configuration can also enable MCP servers, apps, plugins, hooks, instruction files, or provider settings that contradict the claimed restrictive envelope. `thread/start` returns `instructionSources`, which is the protocol's direct evidence of loaded instructions and must be checked.

Evidence:

- CLI and extension share cached login details; logging out from either requires sign-in again: manual 10630-10636.
- Credentials are stored in `CODEX_HOME` or the OS credential store and may be plaintext `auth.json`: manual 10638-10656.
- `forced_login_method = "chatgpt"` exists and mismatched credentials cause logout: manual 10658-10670.
- Thread responses expose loaded `instructionSources`: manual 27022-27025.
- An enabled required MCP server can affect thread startup: manual 27056-27058.

**Required correction:** decide and document the runtime state boundary before calling AD-5/AD-8 enforceable. The spike should launch with a dedicated, permission-restricted Codex home/config directory, explicit credential-store choice, a scrubbed environment, strict known configuration, and ChatGPT-only authentication. It must prove that login/logout does not mutate the user's normal Codex session, that no inherited provider/API key is selected, that `instructionSources` is empty or exactly allowlisted, and that no user/global MCP, app, plugin, hook, skill, or instruction configuration becomes model-visible. If macOS Keychain entries are shared despite a dedicated home, that is a separate stop-or-design decision.

### High — AD-10 is internally unmet and the current CLI surface is still version-sensitive

**Affected:** spine lines 93-97 and Deferred line 125; spike lines 27-33, 109-116, 126-128.

AD-10 says the adapter has an explicit supported-version range, but neither artifact names a minimum, maximum, exact tested version, protocol-schema digest, or stable/experimental method set. The spike then defers deciding supported versions until after it passes, so the adopted rule and the planned evidence disagree. The manual explicitly says generated schemas are specific to the Codex version that generated them.

The locally installed `codex-cli 0.145.0` reports `codex app-server` as `[experimental]`; its `generate-ts` and `generate-json-schema` subcommands are also labelled `[experimental]`. The official manual presents App Server as the rich-client interface and distinguishes stable from experimental fields, but it does not provide a semantic protocol version or compatibility promise.

Evidence:

- Generated TypeScript/JSON schemas match one exact Codex version: manual 26638-26643.
- Some methods/fields require explicit `experimentalApi`; omitting it stays on the stable surface: manual 26774-26779.
- Permission profiles, dynamic tools, paginated history, and some listing APIs are beta/experimental: manual 27027-27037, 27056-27058, and 27158-27160.
- Environment observation: `codex --version` returned `codex-cli 0.145.0`; `codex app-server --help` labelled the command and schema generators experimental.

**Required correction:** change AD-10 from a presently satisfied property to the rule the spike must establish, or bind the initial adapter to one exact tested Codex version. Retain a generated-schema hash, declare `experimentalApi: false` unless a separately enumerated feature requires it, and list the exact RPC methods and fields on which ProjectOS depends. Compatibility must be proven by an initialize/auth/thread/turn/delete smoke suite, not inferred from a numeric range alone. Commercial bundling/update policy remains correctly deferred.

### High — the normalized failure taxonomy exceeds documented signal fidelity

**Affected:** spine lines 75-79; spike lines 46-53.

The protocol documents `UsageLimitExceeded`, connection/stream failures, `Unauthorized`, `SandboxError`, and generic server errors. The account endpoint adds arbitrary rate-limit buckets and a provider-classified `rateLimitReachedType`. It does not promise that ProjectOS can always distinguish "rate limited" from "allowance exhausted," nor that authentication expiry, network loss, and upstream failure are mutually exclusive in every error. `HttpConnectionFailed` can represent upstream 4xx or 5xx responses, so its name alone is not a network-offline signal.

Evidence:

- Documented common errors: manual 27833-27847.
- Rate-limit fields are optional/provider-returned and `rateLimitReachedType` is the available server classification: manual 28687-28751.

**Required correction:** define a lossless normalized envelope such as `category`, `retryability`, `providerCode`, `httpStatus`, and optional `limitState`, with `unknown/provider-failed` as a valid result. Make the separate "rate limited" and "allowance exhausted" states conditional on an explicit provider signal. Add fixtures proving the mapping for the exact supported binary.

### Medium — device-code login is documented but still beta

**Affected:** spike line 40.

App Server documents `type: "chatgptDeviceCode"`, `verificationUrl`, and `userCode`, but the general Codex authentication manual labels device-code authentication beta and says availability can depend on personal/workspace settings.

Evidence: manual 10693-10711 and 28575-28616.

**Required correction:** keep device-code as an optional compatibility test, not a release gate or guaranteed fallback. Browser login is the stable MVP path unless the pinned runtime and target account prove device-code availability.

### Medium — "without API credits" is too broad

**Affected:** spike gate line 44 and failure-state gate line 53.

The authentication distinction is correct: ChatGPT sign-in provides subscription access, whereas API-key sign-in uses Platform usage-based billing. However, the App Server account surface can report ChatGPT workspace credits and earned rate-limit-reset credits. Therefore "without API credits" should mean "without an OpenAI Platform API key or Platform usage-based billing," not that no credit concept can appear in ChatGPT account state.

Evidence: manual 10489-10503, 10560-10575, and 28687-28751.

**Required correction:** use the precise Platform billing wording. The product may still choose not to expose purchase/reset actions.

### Medium — cleanup and enumeration need exact local scope

**Affected:** spine lines 87-91 and Deferred line 129; spike lines 82-90, 123.

`thread/delete` is real and stronger than a best-effort file delete: it removes active or archived thread rollout files and associated metadata, deletes spawned descendants, and treats missing files as already deleted. This supports the cleanup design. It does not claim deletion of OpenAI service retention, which the spine correctly disclaims.

The remaining gap is discovery. `thread/list` defaults to interactive source kinds (`cli` and `vscode`) when `sourceKinds` is omitted, so ProjectOS-created App Server threads may be absent from a naïve enumeration. The canonical binding ledger should remain the primary cleanup source; orphan recovery must explicitly include `sourceKinds: ["appServer"]` and both active and archived listings, or otherwise tag and recover only ProjectOS-owned threads.

Evidence: manual 26976-26992, 27187-27216, and 27320-27331.

**Required correction:** specify ledger-first deletion, explicit App Server source filtering for orphan scans, and a collision-safe ownership marker. Do not delete threads merely because they share a `cwd`.

### Medium — graceful server shutdown is not a documented RPC contract

**Affected:** spine line 61; spike lines 28 and 31.

The manual shows spawning `codex app-server` as a child over stdio but documents no App Server shutdown request. Terminating the owned child is an application process-management decision, not a supported protocol lifecycle guarantee. Background processes can also exist for a thread.

Evidence: manual 26645-26699 and experimental background-terminal APIs at 27368-27404.

**Required correction:** the spike should record EOF/SIGTERM behavior, child/process-group cleanup, timeout, forced termination, and whether a crashed/restarted server leaves subprocesses. Phrase the spine rule as supervising the process tree ProjectOS launched, not merely the parent PID.

### Low — current-platform citations are unversioned and use an older URL family

**Affected:** spine lines 118-121.

The claims are substantively current, but the supplied fresh manual identifies the official sources as `https://learn.chatgpt.com/docs/auth` and `https://learn.chatgpt.com/docs/app-server`, while the spine links the older `developers.openai.com/codex/...` URLs. More importantly, neither citation records a retrieval date or tested CLI version.

**Required correction:** cite the current source URLs, add `verified: 2026-07-31`, and bind factual platform claims to the tested Codex version/schema digest produced by the spike.

## Verified claim inventory

| Artifact claim | Result | Official evidence / caveat |
|---|---|---|
| ChatGPT sign-in is subscription access; API key is usage-based Platform access | Verified | Manual 10489-10503 and 10560-10575 |
| App Server is intended for deep integration in a product | Verified | Manual 26527-26534 |
| Default stdio transport uses newline-delimited JSON-RPC messages | Verified | Manual 26565-26577 |
| Client must send `initialize`, then `initialized` | Verified | Manual 26645-26651 and 26710-26723 |
| Protocol schemas can be generated from the CLI | Verified, version-specific | Manual 26638-26643; current CLI help labels generators experimental |
| Managed browser login returns a URL and Codex owns token persistence/refresh | Verified | Manual 28388-28404 and 28525-28573 |
| ProjectOS need not receive ChatGPT access/refresh tokens in managed mode | Verified | Managed `chatgpt` mode is distinct from experimental host-token mode; manual 28390-28395 and 28618-28670 |
| Plan type can be read/observed | Verified, optional when available | Manual 28388-28404 and 28466-28484 |
| Device-code login exists | Verified, beta | Manual 10693-10711 and 28575-28616 |
| ChatGPT rate-limit buckets expose percentage, duration, reset, and reached classification | Verified, fields may be absent | Manual 28687-28751 |
| Per-turn `outputSchema` exists | Verified | Manual 27418-27426 and 27468-27493 |
| Streaming and cancellation are available | Verified | Manual 26710-26717 and 27781-27831 |
| Persistent root threads can resume across process restart | Verified at protocol level | `thread/start` returns `ephemeral: false`; `thread/resume` continues stored IDs: manual 26994-27054 |
| Non-persistent root `thread/start` is documented | Not verified | Only ephemeral `thread/fork` is documented: manual 27100-27140; current deferral is correct |
| `thread/delete` removes persisted rollout files and metadata | Verified | Manual 27320-27331 |
| `thread/delete` proves deletion from all OpenAI retention/backups | Not supported | The method contract is local thread rollout/metadata deletion; the spine correctly disclaims independent retention |
| App Server can prevent all command/file activity through turn settings | Not verified | Sandbox limits access; no documented stable disable switch for built-in tools |
| Runtime can be shut down gracefully by RPC | Not verified | No shutdown RPC is documented |
| A stable protocol range can be inferred from generated schemas | Not supported | Schemas are exact-version outputs; no semantic compatibility contract is stated |

## Recommended disposition

Do not reject Codex App Server as the initial adapter. The official surface supports the proposed port/adapter proof and most of the spike. Before finalizing the spine, make containment explicitly conditional, define a dedicated Codex state/config/auth boundary, bind the first adapter to one tested binary/schema set, and weaken error normalization to what the protocol can actually distinguish. The validation spike should remain a stop/go gate for commercial adoption rather than evidence that these four properties are already settled.

## Resolution addendum — revised artifacts

**Re-review verdict:** all four prior high findings are resolved in the architecture contract. No critical or high finding remains. Execution containment is correctly represented as a validation-blocking product-fit uncertainty rather than a documented App Server guarantee.

- **Runtime-home isolation — resolved by contract and gate.** AD-4/AD-5 now bind a ProjectOS-scoped `CODEX_HOME`, forced ChatGPT authentication, keyring storage, and fail-closed secure storage. AD-13 adds a dedicated state/configuration root, scrubbed environment, default-profile non-interference, and concurrent-instance ownership. Spike lines 32-45 require proof that the normal Codex profile and plaintext credential storage remain untouched. Keychain namespace behavior is not guaranteed by the manual, but it is now correctly treated as evidence the spike must produce.
- **AD-10 version binding — resolved.** The rule now binds exact validated Codex builds, generated-schema digests, an enumerated documented RPC subset, `experimentalApi: false`, and fail-closed mismatch behavior. This matches the manual's exact-version schema contract and appropriately avoids claiming semantic range compatibility.
- **AD-7 error fidelity — resolved.** The new envelope preserves optional provider code, HTTP status, and limit/reset state; specific categories require explicit signals and otherwise fall back to `providerFailed` or `unknown`. Spike lines 51-58 test that rule.
- **AD-8 containment — resolved by explicit rejection gate.** AD-8 now states that App Server controls are only defense in depth, does not claim they disable built-in command or web tools, requires a documented stable disable mechanism or an external OS containment boundary, and rejects the adapter if prevention cannot be demonstrated. Spike gate line 87 requires zero unrelated access, transmission, mutation, or tool activity and rejects detection after access or side effects. Stop condition line 134 now matches that rule by requiring prevention before occurrence and explicitly declaring detection insufficient. Whether Codex passes remains an empirical spike result, not an unresolved architecture or platform-claim defect.
