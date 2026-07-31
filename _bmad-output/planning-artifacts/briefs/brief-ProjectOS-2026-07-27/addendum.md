---
title: "ProjectOS Product Brief Addendum"
status: final
created: 2026-07-27
updated: 2026-07-31
---

# Product Brief Addendum

## Founding Evidence and Derived Need

### Garden office utility connection

A prefabricated garden office with a toilet must be connected to the main house through a buried channel carrying electricity, Ethernet, and sewer infrastructure. The office sits lower than the sewer connection at the house, creating a non-obvious drainage problem. The project requires research and decisions about unfamiliar topics, including electrical work, sewer systems, material selection, trench depth, and ways to overcome the height difference.

The work unfolds over time and across several AI conversations. Research findings and decisions become fragmented between those conversations. When work resumes, the user must reconstruct what was learned and decided before making progress. Delegating research to an agent compounds the problem: the user benefits from the research but is less likely to remember conclusions they did not personally derive.

### Used-car selection

The user prefers a particular second-hand car model, but it has many meaningful variants: model versions, engines, interiors, and other configurations. Several conversations help narrow the field to a shortlist, but the exact preferred variants and the reasoning behind them remain buried in chat history. The volume and specificity of the information make unaided recall unreliable when the purchase process resumes later.

### Cross-scenario pattern

Both are long-running projects involving unfamiliar information, comparison, and consequential decisions. The failure occurs at the boundary between sessions: useful AI work exists, but the current project state is neither explicit nor memorable, making the project difficult to resume. The user must rediscover prior research and reconstruct decisions before taking the next action.

### Re-entry outcome

When returning after time away, the user should quickly see the decisions that currently govern the project, enough background to understand each decision, the most recently completed research, and the tasks that remain open. Deeper rationale should be available on demand. This should restore understanding without requiring the user to reread prior conversations. Project-aware guidance should identify the next useful action and explain how unresolved questions, decisions, and dependencies support that recommendation.

## Product Decisions and Rationale

### Positioning alternative considered

A launch wedge focused on homeowners managing renovations or property projects was considered because those projects are long-running, unfamiliar, interdependent, and financially consequential. It was rejected as the defining product position because the intended value is deliberately cross-domain. Valid projects include, but are not limited to, home renovation, buying a car, starting a business, planning a holiday, building software, and researching a large purchase.

### MVP artifact decision: Research

Research is a first-class MVP artifact alongside Topics, Conversations, Decisions, Open Questions, and Tasks. The starting document included research throughout the lifecycle and examples but omitted it from the MVP artifact list. Making research durable prevents evidence from remaining trapped in conversations and allows findings and sources to remain connected to the decisions and unresolved questions they inform.

### Project identity and personalization

Each project should express a distinct identity or atmosphere. A laundry-room remodel should feel different from a car search or software build. The intended outcome is emotional ownership and a recognizable environment throughout the product experience, not customization for its own sake.

The MVP uses a lightweight identity layer with a hero image and coordinated accent theme. Arbitrary fonts, custom logos, and broader visual controls belong in a later theming system.

## Accepted Commercial and Deployment Direction

The MVP is a one-time-purchase, local-first macOS application in which the user brings their own AI access. Canonical project data remains on the Mac, and selected project content is sent directly to the supported AI provider rather than through a ProjectOS-hosted project-content backend. This creates a simple commercial model with no ProjectOS inference costs and a smaller data and operational footprint.

This decision overrides the earlier responsive desktop/mobile web MVP and managed-provider model. Multi-surface access remains a possible future direction but is not part of initial validation. The Mac App Store is the preferred launch channel because it handles payments, regional pricing, distribution, updates, and purchase restoration for one-time paid apps. Direct distribution is not the initial plan.

“Bring your own AI access” was originally scoped as user-owned API access with separate provider billing, because ordinary API use remains separate from consumer subscriptions ([OpenAI](https://help.openai.com/en/articles/8156019-how-can-i-move-my-chatgpt-subscription-to-the-api), [Anthropic](https://support.claude.com/en/articles/9876003-i-have-a-paid-claude-subscription-pro-max-team-or-enterprise-plans-why-do-i-have-to-pay-separately-to-use-the-claude-api-and-console)). That conclusion did not account for Codex's supported subscription-authenticated App Server path; see **Provider-Independent AI Direction** below.

## Superseded Provider Decision (2026-07-28)

The 2026-07-28 decision selected direct OpenAI API-key authentication plus Ollama in the MVP. Its research incorrectly generalized ordinary third-party API access to Codex's supported product surface and concluded that ChatGPT sign-in could not consume a subscription allowance. It also committed the MVP to two integrations before the core continuity loop was validated.

The decision history remains in `.memlog.md`, but the requirements and product direction below supersede it.

## Provider-Independent AI Direction (2026-07-31)

### Initial adapter: Codex App Server

The validation build uses Codex App Server as its first AI Provider Adapter. OpenAI documents App Server as the interface for rich clients that need authentication, conversation history, approvals, and streamed agent events. Its account surface can start a Codex-managed ChatGPT browser login, report the signed-in plan, and expose rate-limit windows and reset times. Codex documentation distinguishes [ChatGPT sign-in for subscription access from API-key sign-in for usage-based access](https://developers.openai.com/codex/auth) and documents the required [App Server protocol and account endpoints](https://developers.openai.com/codex/app-server).

ProjectOS therefore does not ask for an OpenAI API key in the active MVP path, buy API credits, or manage ChatGPT tokens. It asks the App Server to begin login, opens the returned authorization URL, and reacts to completion, account, plan, and allowance events. Usage consumes the user's eligible ChatGPT/Codex allowance. The UI reports the allowance windows and reset times returned by Codex rather than assuming a fixed weekly schedule.

For validation, ProjectOS may require a compatible installed Codex CLI and start its own `codex app-server` child process over the default stdio transport. Whether a commercial Mac App Store build can rely on an installed runtime or must bundle and update a pinned runtime remains a distribution and architecture decision.

### Durable provider boundary

Codex is the first adapter, not ProjectOS's AI architecture. ProjectOS owns a narrow capability-oriented contract for the jobs it needs: project-grounded generation, structured Change Proposals, streaming, cancellation, availability, usage or limit reporting when supported, and provider-session lifecycle. Provider-specific protocols and concepts remain inside adapters.

The boundary has these product-level invariants:

- Canonical State, Conversations, Change Proposals, Rationale, and Provenance use ProjectOS-owned types.
- A Codex thread ID or another provider session identifier is a replaceable binding, never the canonical Conversation identity.
- Adapters advertise capabilities instead of forcing every provider into an OpenAI-shaped lowest common denominator.
- Authentication, model discovery, runtime lifecycle, structured-output mechanics, usage reporting, and provider-side deletion remain adapter responsibilities.
- Shared provider setup, status, error, and Context Preview surfaces host adapter-specific controls without spreading them through the product.
- Adding a cloud or local provider requires an adapter, settings contribution, and contract tests—not changes to the semantic-continuity workflow.

Local models remain an intended future provider category. Ollama is a candidate adapter, not a permanently selected runtime. The first local adapter must be evaluated against the same extraction-correctness and completeness gates as Codex and must disclose capabilities or quality limitations honestly. Direct OpenAI API-key access may also return later as a separate adapter, but it is not the validation default or a hidden fallback.

### Accepted risks and privacy boundary

Codex is optimized as a coding agent, so ProjectOS must validate non-coding, cross-domain extraction and recommendation quality before treating the integration as product-ready. App Server also persists provider-side thread logs by default; Project deletion must delete the corresponding Codex threads or use an explicitly isolated non-persistent strategy. Runtime version compatibility, schema generation, sandbox restrictions, token ownership, and Mac App Store redistribution require a focused architecture decision and validation spike.

Local-first operation reduces ProjectOS's data footprint but does not eliminate privacy or GDPR obligations. A cloud adapter still receives selected project content. Before transmission, ProjectOS must identify the configured provider, state whether processing is local or external, show the selected scope, and obtain explicit initiation ([European Commission](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/application-gdpr_en), [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). A subscription may be introduced later only if a managed service provides recurring value through synchronization, additional surfaces, sharing, or collaboration.
