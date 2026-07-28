---
title: "ProjectOS Product Brief Addendum"
status: final
created: 2026-07-27
updated: 2026-07-28
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

“Bring your own AI access” was originally scoped as user-owned API access with separate provider billing, because ChatGPT and Claude consumer subscriptions do not include API usage ([OpenAI](https://help.openai.com/en/articles/8156019-how-can-i-move-my-chatgpt-subscription-to-the-api), [Anthropic](https://support.claude.com/en/articles/9876003-i-have-a-paid-claude-subscription-pro-max-team-or-enterprise-plans-why-do-i-have-to-pay-separately-to-use-the-claude-api-and-console)). This assumption is now outdated in both ecosystems; see **Provider Decision and Subscription-Based Access** below.

## Provider Decision and Subscription-Based Access (2026-07-28)

### Research: consumer-account access for third-party apps

Both major providers now offer paths beyond raw API keys, with very different stability profiles.

**Anthropic** churned its policy three times in six months. In February 2026 it explicitly banned subscription OAuth for all third-party products ([AlternativeTo](https://alternativeto.net/news/2026/2/anthropic-officially-bans-using-subscription-authentication-for-third-party-claude-use)); in April 2026 it tightened the prohibition against non-Anthropic agents; in May 2026 it reinstated third-party usage on the condition that apps authenticate through the Claude Agent SDK, alongside an announced separate monthly credit pool (Pro $20, Max 5x $100, Max 20x $200) billed at full API rates ([VentureBeat](https://venturebeat.com/technology/anthropic-reinstates-openclaw-and-third-party-agent-usage-on-claude-subscriptions-with-a-catch), [The Register](https://www.theregister.com/ai-ml/2026/05/14/anthropic-tosses-agents-into-the-api-billing-pool/5240748)); on June 15, 2026 that billing change was paused before taking effect, and third-party Agent SDK usage currently still draws from normal subscription limits ([Claude Help Center](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan), [Zed](https://zed.dev/blog/anthropic-subscription-changes)). A sanctioned path exists today, but the policy instability makes it unsuitable as a load-bearing assumption, and the Agent SDK's Node-based runtime complicates sandboxed Mac App Store distribution.

**OpenAI** offers "Sign in with ChatGPT": standard OAuth 2.0 through which a user's sign-in grants prepaid API credits ($5 or $50 depending on plan; Free, Plus, and Pro eligible), piloted in Codex CLI with an open developer interest form ([MediaNama](https://www.medianama.com/2025/06/223-openai-sign-in-with-chatgpt-third-party-apps/)). This is not subscription metering — it is an auto-provisioned API funnel. For onboarding it is exactly the right shape: no console visit, no key copy-paste, starter credits that cover a trial, and ordinary usage billing afterward.

### Decision: MVP supports OpenAI and local models via Ollama

The MVP ships two provider integrations behind one provider-neutral adapter boundary:

1. **OpenAI (cloud default).** API-key authentication with guided onboarding. "Sign in with ChatGPT" OAuth was evaluated and deliberately deferred (decided 2026-07-28): it would remove key-paste friction, but it requires developer-program acceptance and adds an external dependency the MVP does not need. It remains the natural post-MVP onboarding upgrade, and the onboarding flow should be designed so an OAuth path can be added without rework.
2. **Ollama (local option).** Local inference with no credentials, no usage charges, and no project content leaving the Mac. This strengthens the local-first and privacy positioning (AI-provider disclosure and consent obligations apply only to the cloud path), provides a zero-marginal-cost tier, and proves the provider-neutral adapter with a second, structurally different backend.

This supersedes the brief's earlier single-provider MVP constraint and its exclusion of local-model configuration. Anthropic is deferred, not rejected: the adapter boundary should keep a Claude integration cheap to add once its third-party access policy stabilizes.

**Accepted risks.** Local models materially trail frontier cloud models at structured extraction, which is the quality-critical step of the core loop; the extraction-correctness decision gate (≥85%) must be measured per backend, and if Ollama cannot meet it the product must set expectations honestly (for example, recommending the cloud path for extraction while allowing local chat) rather than silently degrading trust. Supporting two backends also widens MVP engineering scope — testing, prompt portability, and capability differences (context windows, structured output support) — which is the price of the privacy story and the adapter proof. Recommended and minimum Ollama models remain an open decision to be settled during development against the extraction gate.

Local-first operation reduces ProjectOS's data footprint but does not eliminate privacy or GDPR obligations. AI requests still disclose selected project content to the configured AI provider, and licensing, support, updates, or optional diagnostics may process personal data. The product must identify the AI provider that will receive the data and obtain permission before transmitting project content ([European Commission](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/application-gdpr_en), [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). A subscription may be introduced later if a managed service provides recurring value through synchronization, additional surfaces, sharing, or collaboration.
