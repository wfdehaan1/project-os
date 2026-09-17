# Conversation experience

## Entry and setup

Codex appears alongside existing choices in a new conversation's provider selector. Display “Codex · ChatGPT account · External” and the selected model; direct inference and agent execution need not be explained as implementation terms in ordinary chat.

Selecting an unavailable Codex opens **Settings → AI → Codex**. The setup card reports separate runtime, account and qualification states, with a single next action: Set up runtime, Sign in with Codex, Reconnect, or Review compatibility. A successful connectivity check must not imply the runtime is qualified for real data.

Guided setup locates a supported installation or offers the bounded installation/helper action described by P0. Show what will be installed or launched before it happens. Login uses Codex's own browser/device flow; ProjectOS never asks the user to paste access tokens. Once set up, ordinary app launch reconnects or offers a clear Start Codex action. No terminal session or recurring PORT:TOKEN paste is required for routine use.

Offline projects, prior messages and pending reviews remain readable. Model lists come from the qualified runtime; an unavailable saved model disables Send until an explicit replacement is selected. Quota exhaustion preserves the draft and partial answer without buying credits or switching billing paths.

## Provider and conversation identity

- Before the first send, provider and model may be changed freely; nothing is transferred automatically.
- After sending, the conversation has a saved backend binding. Global settings establish defaults for new conversations, not silent changes to existing ones.
- Switching backend creates a **Continue with…** conversation. Preview the messages/context to be transferred; send only on explicit confirmation. The old conversation remains intact. No remote session is shared across projects, restored copies or accounts.
- A supported model change within Codex applies only to the next turn, after the current turn finishes. Display the effective model on the turn if it differs from the requested one; unexpected substitution is a failure requiring user action.
- Existing conversations initially have no historical backend claim. Their next send requires a visible provider selection that establishes the binding; never backfill old message attribution from current settings.

## Research and permissions

| Choice | Research behavior | UI |
|---|---|---|
| Local Ollama | Existing SearXNG search/read path when enabled | “Web research · SearXNG on this Mac” |
| OpenRouter | Existing direct chat and proposals; no SearXNG forwarding | Research unavailable for this backend in this release |
| Codex | Qualified native search and page-read tools only | “Research · Codex built-in tools” |
| Future agent | Only capabilities actually qualified | Unsupported actions are disabled with a reason |

Research is an explicit conversation policy, frozen at Send. Enabling it permits search/page reads until disabled; queries leave the device. Default it off for new ordinary conversations, matching the existing research-conversation default only when clearly disclosed. Disabling it controls future tool use, not facts already in history. If the runtime cannot enforce a changed policy on resume, create a new session with an explicit context packet.

Show concise activity such as Searching, Reading page, Awaiting permission, Completed or Interrupted beneath the related answer. Persist display-safe activity and citations, not hidden chain of thought, credentials or entire raw protocol logs. Render safe HTTP(S) citation links as external sources. Never label a link as a retained source snapshot.

When Codex actually requests permission, show its operation and offered supported choices. Allow-once is scoped to that exact pending request/turn; reject and Stop are always available. Hide persistent grants. Expired choices do nothing. Requests outside the research policy are denied automatically with a visible explanation, not offered as a way to bypass policy. This applies to native tools as well as ACP client callbacks.

## Context preview

For Codex, use two sections:

1. **Added with this message:** draft; selected source/artifact versions and exact text; any deliberately transferred prior messages. Show material excluded by the user's selection and the destination account/model. ProjectOS reuses the existing frozen-context builder and never silently trims it.
2. **Previously shared in this session:** earlier submitted turns and context manifests, last shared project revision, and current synchronization status. This is a record of disclosure, not a promise to know exactly what remains in the model's active context window. Show provider-reported compaction separately when available; otherwise label exact runtime context unknown.

Deselection copy: “This stops adding it to new messages. Codex may still remember earlier messages.” Stale context copy identifies the last shared revision and offers a reviewed current-state packet. Removed/superseded items may still exist remotely; do not imply local edits retract them.

**Start fresh** archives the current session generation and keeps the conversation transcript visible behind a session divider. It previews new context and starts an empty remote session; earlier messages are not resent unless selected. State explicitly that this does not delete old provider history.

For Ollama/OpenRouter, keep the stateless full-request preview and context-budget checks. Do not apply a misleading “last N messages is the entire context” control to an existing agent session. Retain readable, accessible controls at normal and narrow window widths; do not reintroduce the nested inspector layout that previously crashed Conversations.

## Send, Stop and resume

One active turn per project, consistent with the existing job policy. Multiple windows observe a single session owner. Switching conversations changes presentation, not the frozen destination of a running turn.

States: Ready → Preparing → Running / Awaiting permission → Stopping → Completed, Cancelled, Failed or Interrupted. Stop preserves already received output, invalidates permission requests and bars another turn until termination is confirmed or the owned runtime is stopped. A local timeout is not proof that provider execution ended.

On relaunch, show saved messages immediately. Reattach only the exact owned session with compatible account/runtime/policy. Reconcile remote items without sending the prompt again. If execution or history is uncertain, show “Connection interrupted; Codex may have continued” and offer Recover or Start fresh. Do not silently discard unknown replay, duplicate a message or resume with an incomplete history presented as complete.

## Suggested project updates

Keep **Suggest project updates** separate from Send. Preview the selected evidence and project revision, then run a bounded proposal job with research tools disabled. Use an isolated generation session so the selectable evidence packet is the actual input; hidden conversational history must not become undisclosed evidence.

Use the existing five artifact kinds and inbox actions. The experiment's one-question limit is not inherited. Invalid output creates no pending proposal and exposes a useful validation error; retry is explicit. A native citation can remain part of an AI-authored message but cannot masquerade as quoted external-page evidence. Conditional preferences cannot become committed decisions merely because the JSON is valid.

Accept/edit-and-accept/reject, revision conflicts and undo remain the established ProjectOS workflow. A pending proposal never changes accepted state on its own.
