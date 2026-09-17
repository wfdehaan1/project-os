---
id: SPEC-codex-agent-conversations
title: Codex agent conversations in ProjectOS
status: proposed
created: 2026-09-17
baseline_commit: 4ecf4b2
companions:
  - scope-and-evidence.md
  - experience.md
  - implementation-plan.md
  - acceptance.md
sources: []
---

# Codex agent conversations in ProjectOS

This kernel and its four companions are the implementation contract, derived from the decision log. This is a specification-only handoff. The plan is actionable from phase P0; real-project enablement depends on its runtime qualification gate.

## Why

ProjectOS should let Wouter discuss and research real projects using his Codex account inside the existing app, while keeping accepted project knowledge under his control. The native experiment proved that chat, built-in research, cancellation and resume work. This feature turns those mechanics into a durable conversation workflow, with truthful context disclosure, guided setup and reviewed project updates.

## Capabilities

- **CAP-1**
  - **intent:** Connect an owned Codex account and select a model with understandable setup and recovery.
  - **success:** Missing runtime, login, incompatible version and quota states are distinguished; the selected model is visible and no credential or billing fallback occurs.
- **CAP-2**
  - **intent:** Chat with Codex inside ordinary ProjectOS conversations.
  - **success:** Send, streaming, Stop, drafts and partial-response recovery work without a terminal; chat never changes accepted project knowledge.
- **CAP-3**
  - **intent:** Research through the selected provider's approved tools.
  - **success:** Codex uses its native search/page tools with visible activity and citations; SearXNG is used only by local Ollama; unsupported or disallowed actions cannot execute.
- **CAP-4**
  - **intent:** Inspect and control what context is shared.
  - **success:** The preview separates newly added context from earlier disclosure and retained agent history, labels outdated project context, and offers a fresh session without deleting the prior transcript.
- **CAP-5**
  - **intent:** Obtain reviewable project updates from explicitly selected evidence.
  - **success:** Production schema, exact-evidence and revision checks precede the proposal inbox; only existing application acceptance commands change accepted state.
- **CAP-6**
  - **intent:** Resume conversations reliably after leaving or encountering a failure.
  - **success:** Transcript, activity and pending reviews survive relaunch without duplicate messages or silent prompt replay; uncertain remote history is visible and blocks ambiguous continuation.
- **CAP-7**
  - **intent:** Retain ownership of agent conversation data.
  - **success:** Export/restore retain content without credentials or attachable provider session handles; deletion fences late events and distinguishes local removal from provider retention.
- **CAP-8**
  - **intent:** Keep existing local/direct providers usable while allowing later agent providers.
  - **success:** Ollama and OpenRouter retain their workflows, and a second fake agent implements the session contract without Codex-specific UI or domain logic.

## Constraints

- Personal-use native macOS with guided Codex setup, local app storage, existing Conversations and proposal-review surfaces. No ProjectOS account, inference proxy or resold credits.
- Keep the main app sandbox enabled. Before real context is enabled, qualify effective runtime restrictions and helper lifecycle; a mode label, prompt instruction or refusal is insufficient.
- Codex owns its tool loop. Do not forward SearXNG or ProjectOS MCP tools to it. This release permits research tools only; no shell, arbitrary local file access, accepted-store access, connectors or computer control.
- Codex manages account authentication. ProjectOS must not copy/parse its tokens, alter the user's ordinary Codex profile, or silently fall back to an API key, model, provider or retry.
- Each turn freezes its project/conversation/session generation, provider, model, context and research policy. Preserve partial results and apply deletion/cancellation fences before persistence or proposal creation.
- ProjectOS is the authority for accepted knowledge. Native citations are external links, not retained source snapshots or proof of source contents.
- Keep local browsing, edits, proposal review, export and deletion available without Codex. Preserve exact Unicode evidence and transactional changes.
- The scope companion resolves conflicts with the older MVP's provider/tool exclusions; it does not authorize unrelated historical roadmap work.

## Non-goals

- Coding-agent access to repositories, shell, arbitrary files, MCP/connectors, browser/computer control or autonomous accepted changes.
- A second real agent provider, migration of external Codex chat history, automatic source-page capture, or importing the synthetic experiment as a real project.
- App Store submission, commercial distribution, cloud sync, multi-user service or a generic plugin marketplace.
- A new chat window as the shipping workflow, permanent manual pairing, or forcing direct local inference into a stateful agent model.

## Success signal

After guided setup, Wouter can open a real project, choose Codex, inspect context, research with native tools, stop a response, return after app/helper restart, request a validated update and explicitly accept it through the existing inbox. The accepted project revision changes only on acceptance. Repeat the loop with research disabled and with Ollama/OpenRouter to prove the tool/provider boundaries. Record observed usefulness separately from engineering completion.

## Assumptions

- **A2:** Codex is the first agent backend; start from the proven ACP adapter, subject to P0 qualification.
- **A3:** Enabling Research grants the disclosed search/page-read policy for later turns until disabled; individual searches do not require redundant confirmation.
- **A4:** Switching backend after a conversation has begun creates an explicit continuation conversation; a supported model change can apply to the next turn in the existing agent session.

## Open Questions

- **Q2 — engineering gate:** Can the chosen pinned runtime enforce the research-only policy, isolate inherited configuration and support managed authentication from the sandboxed app's helper topology? P0 must answer with evidence before real-project enablement; it must not pretend the experiment already answered it.
