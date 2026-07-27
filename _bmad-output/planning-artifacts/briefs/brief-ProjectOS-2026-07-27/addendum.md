---
title: "ProjectOS Product Brief Addendum"
status: final
created: 2026-07-27
updated: 2026-07-27
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

“Bring your own AI access” does not generally mean reusing a consumer subscription. ChatGPT and Claude consumer subscriptions do not include API usage, so the baseline is user-owned API access with separate provider billing ([OpenAI](https://help.openai.com/en/articles/8156019-how-can-i-move-my-chatgpt-subscription-to-the-api), [Anthropic](https://support.claude.com/en/articles/9876003-i-have-a-paid-claude-subscription-pro-max-team-or-enterprise-plans-why-do-i-have-to-pay-separately-to-use-the-claude-api-and-console)).

Local-first operation reduces ProjectOS's data footprint but does not eliminate privacy or GDPR obligations. AI requests still disclose selected project content to the configured AI provider, and licensing, support, updates, or optional diagnostics may process personal data. The product must identify the AI provider that will receive the data and obtain permission before transmitting project content ([European Commission](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/application-gdpr_en), [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). A subscription may be introduced later if a managed service provides recurring value through synchronization, additional surfaces, sharing, or collaboration.
