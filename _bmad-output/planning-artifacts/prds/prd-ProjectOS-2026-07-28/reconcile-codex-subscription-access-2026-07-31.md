---
title: Codex Subscription Access Reconciliation
status: current
created: 2026-07-31
updated: 2026-07-31
---

# Codex Subscription Access Reconciliation

## Change signal

ProjectOS will not use a user-supplied OpenAI API key in the active validation path. Its first AI Provider Adapter will use Codex App Server with Codex-managed ChatGPT authentication so eligible usage follows the user's ChatGPT/Codex plan allowance.

This does not make Codex the application architecture. ProjectOS retains a provider-independent capability boundary so later cloud providers and local models can be added without rewriting its domain workflows or Canonical State.

## Current official evidence

- [Codex authentication](https://developers.openai.com/codex/auth) documents two distinct paths: ChatGPT sign-in for subscription access and API-key sign-in for usage-based access.
- [Codex App Server](https://developers.openai.com/codex/app-server) is intended for rich product integrations and exposes authentication, account/plan state, allowance windows, streamed events, per-turn structured output, conversation lifecycle, and persisted-thread deletion.
- App Server's managed ChatGPT mode owns OAuth token persistence and refresh. ProjectOS can start the browser flow and observe completion without handling tokens itself.
- Rate-limit responses expose actual usage windows and reset timestamps. Product copy must not hard-code “weekly” when the active plan reports another window.

## Reconciled conflicts

| Earlier conclusion | Current decision | Resulting change |
|---|---|---|
| OpenAI requires a user-supplied API key and separate API billing. | Codex App Server uses managed ChatGPT sign-in and eligible subscription allowance. | Remove API-key, insufficient-credit, cost-estimate, and API-billing requirements from the active path. |
| ChatGPT sign-in only grants prepaid API credits. | That conclusion does not describe supported Codex subscription authentication. | Mark the 2026-07-28 provider decision superseded. |
| OpenAI and Ollama both ship in the MVP. | Codex is the first validation adapter; local and other providers follow proof of the core loop. | Keep the adapter boundary and defer second-provider implementation. |
| OpenAI is the provider shape throughout the app. | ProjectOS owns generic provider capabilities, errors, sessions, and settings; the Codex adapter translates them. | Add a provider contract, registry, capability negotiation, and fake-adapter contract tests. |
| Provider credentials live in ProjectOS Keychain handling. | Codex owns its authentication cache and refresh lifecycle. | ProjectOS must not read, log, export, or persist ChatGPT tokens. |
| Project deletion only removes ProjectOS local data. | App Server persists threads by default. | Delete bound Codex threads or disclose and retry incomplete provider-side cleanup. |

## Preserved decisions

- Canonical project data remains local and provider-independent.
- Only explicitly selected context crosses an AI Provider boundary.
- Browsing and local state changes never initiate provider work.
- AI-generated consequential changes remain proposals until the user accepts them.
- ProjectOS hosts neither inference nor provider billing.
- Local models remain an intended future provider category.

## Superseded historical reports

`reconcile-product-brief.md`, `reconcile-market-research.md`, and `review-rubric.md` remain historical snapshots of the 2026-07-28 PRD. They are not rewritten. Where they conflict on provider authentication, billing, credentials, cost visibility, or provider breadth, this reconciliation and the updated PRD govern.

## Remaining gates

The companion Codex App Server validation spike must resolve runtime discovery, version compatibility, non-coding output quality, plan eligibility, allowance reporting, restrictive sandbox behavior, Provider Session Binding persistence, complete thread deletion, and the commercial distribution strategy for the Codex runtime.
