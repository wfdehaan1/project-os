# Acceptance and qualification

Each scenario is a release obligation. Test fixtures prove contracts; live runs prove a particular runtime/build combination; personal use supplies usefulness evidence. Do not combine these into a single “all working” claim.

## Scenarios

| ID / capability | Given | When | Then | Evidence |
|---|---|---|---|---|
| AC-01 / CAP-1 | A Mac without a configured ProjectOS Codex runtime | Guided setup is followed | Runtime/account/qualification states and required install/login actions are distinct; routine use needs no terminal or repeated pairing | Signed-app live setup, including a second clean setup |
| AC-02 / CAP-1 | Missing/expired login, unsupported runtime, unavailable model or exhausted quota | User tries to send | The matching recovery action appears; draft/transcript survive; no key, account, model or billing fallback occurs | Fixtures for each error plus live managed login/reconnect |
| AC-03 / CAP-1/3 | An inherited Codex profile containing extra MCP, hooks, skills or tools; synthetic files outside the allowed roots | P0 attempts research and prohibited operations from the actual app/helper | Effective configuration and tool inventory match the policy; prohibited reads/writes/commands do not execute; native research still works | P0 configuration/artifact inspection and effects, not only refusals |
| AC-04 / CAP-2 | Two projects, multiple conversations/windows and one active turn | User navigates or changes defaults | Running output and completion persist only to the frozen destination; another window does not create a competing session owner | Coordinator/store fixtures and native UI |
| AC-05 / CAP-3 | Codex with Research enabled and no running SearXNG | User asks for current research | Genuine native search/page events and clickable citations appear; no SearXNG/MCP request is made | Live Codex plus denied/spied local research transport |
| AC-06 / CAP-3 | Codex with Research disabled, including a resumed session previously allowed to search | A prompt asks to browse | Search/page tools cannot execute; policy changes take effect or require a disclosed new session | Runtime qualification plus deterministic policy checks |
| AC-07 / CAP-3/8 | A conversation has research enabled, then selects local Ollama or OpenRouter | A new turn runs | Ollama alone may construct SearXNG tools; OpenRouter cannot, and its UI explains the restriction | Integration test with instrumented toolbox |
| AC-08 / CAP-3 | An allowed permission request, followed by an unknown/disallowed request | User allows once, rejects, stops or resumes later | Only the exact current allowed request can resolve; persistent, stale and disallowed approvals cannot execute | Request/response fixtures and live permission path when available |
| AC-09 / CAP-4 | Context was previously sent; its source is deselected | Preview and next message are opened | New context excludes it; retained-disclosure section still identifies the earlier transmission and never claims erasure | Manifest assertions and native UI |
| AC-10 / CAP-4 | Accepted project revision changed or a previously shared item was removed | User continues the agent session | Preview identifies stale disclosure and offers a visible update packet; context is not silently rewritten or hidden | Versioned fixture and native UI |
| AC-11 / CAP-4/6 | A populated agent session with an active transcript | User chooses Start fresh with a narrow packet | Prior transcript/activity remain; a new generation sends only the chosen packet and clearly disclaims remote-history deletion | Stored manifests/session IDs and live recall probe |
| AC-12 / CAP-2/6 | A response is streaming or awaiting permission | User presses Stop | Received text remains; permissions expire; late deltas/proposals are fenced; next turn waits for confirmed termination or explicit recovery | Deterministic races plus live partial-output cancellation |
| AC-13 / CAP-6 | App crashes after send but before acknowledgement, or helper dies during execution | App relaunches | Attempt is unknown/interrupted; prompt is not resent; recover/fresh choices reflect uncertainty | Fault-injection fixture and native restart |
| AC-14 / CAP-6 | Remote response completed after local disconnect | Session loads with replay | Stable identities reconcile missing items once; if identity/completeness is unavailable, session is visibly unreconciled and ambiguous continuation is blocked | Replay/failure fixtures; live supported resume |
| AC-15 / CAP-6 | Duplicate events, fragmented Unicode, large replay or an event-buffer overflow | Transport reconnects | No corrupted text or duplicate messages; durable cursor advances atomically or a visible sync failure preserves existing data | Transport/journal stress fixtures |
| AC-16 / CAP-6 | A locally saved session belongs to another account/project or incompatible runtime/policy | Resume is attempted | No attachment occurs; user gets an explicit new-session/recovery choice | Ownership and compatibility fixtures |
| AC-17 / CAP-5/6 | Pending proposals, activity and complete/cancelled messages are saved | App/helper restarts offline, then reconnects | Content and pending review survive; no duplicate extraction or accepted-state change occurs | Store restore and native app relaunch |
| AC-18 / CAP-6 | State is corrupt, disk writes fail or cancellation times out | Recovery/close runs | Original recoverable data is preserved; no empty overwrite or false completion; error explains required action | Persistence faults and process lifecycle tests |
| AC-19 / CAP-5 | Explicitly selected user sources and messages, with a frozen revision | User requests project updates | A tools-disabled isolated generation sees exactly that packet; valid output reaches the pending inbox; accepted revision stays unchanged | Captured request manifest plus production validator |
| AC-20 / CAP-5 | Invalid JSON, fabricated quote, unsupported target, changed revision, conditional preference or native citation without retained page text | Proposal output is validated | Invalid proposals are rejected; decisions retain the existing evidence/semantic requirements; no source snapshot is fabricated from a URL | Existing domain tests plus Codex output fixtures |
| AC-21 / CAP-7 | A project contains agent transcripts, activity and disclosure manifests | Export is restored as a new project | Content survives with remapped IDs; credentials/attachable handles are absent; restored sessions are detached and do not infer or call Codex | Archive schema/migration round trip and sensitive-field checks |
| AC-22 / CAP-7 | A turn or permission is pending | Project deletion completes and late events arrive | Local owned data stays deleted; late events cannot recreate it; external retention is disclosed separately | Deletion race and native ownership flow |
| AC-23 / CAP-8 | Existing Ollama/OpenRouter chat, proposal and offline ownership fixtures | Feature code is enabled | Direct providers retain explicit configuration/budget behavior; fake second agent needs no Codex-shaped consumer changes | Regression suite and contract tests |
| AC-24 / CAP-1–8 | Qualified runtime, explicit live-use authorization and one selected real project | User completes the SPEC success loop and returns later | Engineering evidence records setup/research/stop/resume/review; user reports context trust, corrections and usefulness separately | Signed native workflow and personal-use notes |

## Proposal integrity detail

At least one real Codex-generated proposal must pass the **actual production validator**, not a parallel schema-only check. Include negative fixtures where an exact quote is attributed to the wrong source/version, where assistant-authored text is misrepresented as user evidence, and where valid JSON promotes a conditional preference into a decision. All five existing artifact kinds and the existing acceptance/revision/undo rules remain applicable.

An accepted proposal must be traceable to its visible generation manifest and user review. Turn completion, resume, preview opening and research completion must leave accepted revision unchanged. Cancelled/deleted-project generations must never leave newly reviewable proposals behind.

## Runtime qualification record

For each live result retain date, app build, OS, adapter/runtime versions, effective model, approved policy, normalized tool events, expected/actual outcome and exact limitation. Exclude credentials, hidden reasoning and raw account-sensitive protocol logs. Use synthetic canary files for prohibited-access probes; do not inspect unrelated personal files to prove isolation.

P0 must separately verify internal runtime storage/auth access and model tool access. “App sandbox enabled,” “read-only mode,” “empty MCP servers” and “the model refused” are supporting observations, not sufficient evidence of the feature's enforcement requirement.

## Verification order and release gate

1. Contract, migration, journal, permission, proposal and archive tests with fakes. No network/subscription use in deterministic tests.
2. Signed native UI fixture checks: provider setup states, context sections, readable activity, cancellation, inbox and keyboard/accessibility navigation. Exercise narrow windows and the existing Conversations layout regression.
3. Explicit synthetic live qualification from the real app, including account setup, Research on/off, native tools, partial cancellation and app/helper restart.
4. Authorized real-project success loop and later user assessment. A test harness cannot pronounce the feature personally useful.

Record automated UI environment failures as unrun/blocked rather than passed. Direct native verification is acceptable evidence for this personal-use release when documented separately. P0 enforcement, data integrity, cancel/delete fencing and honest context disclosure cannot be waived by a passing build or a favorable manual demo.

Engineering handoff is complete only when P0–P6 exit criteria and all applicable scenarios have evidence. Any unavailable provider capability is disabled with a specific reason. No default exposure of real project context while the runtime gate is unresolved.
