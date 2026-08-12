---
title: "Product Brief: ProjectOS"
status: final
created: 2026-07-27
updated: 2026-08-09
---

# Product Brief: ProjectOS

_Working name._

## Executive Summary

ProjectOS is a local-first macOS application for AI-experienced individuals managing complex, long-running projects. It solves the continuity failure of AI chat: useful research, decisions, questions, and tasks accumulate across conversations, but the user must reconstruct the project's current state whenever work resumes.

ProjectOS turns conversations into user-reviewed updates to an explicit, versioned project model. It preserves governing decisions and their rationale, keeps research and open work connected, and recommends the next useful action from project state. The MVP is sold once through the Mac App Store and stores canonical project data on the user's Mac. AI capabilities sit behind a provider-independent boundary. Ollama, LM Studio, and MLX are first-class local MVP adapters; OpenRouter is the only optional external adapter. The active runtime and model are explicit, and ProjectOS never silently falls back across locality, provider, or model boundaries.

## Open Decisions

- Final product name; ProjectOS remains a placeholder.
- Which Ollama, LM Studio, and MLX versions, model formats, minimum models, and macOS hardware meet production compatibility, resource, and extraction-quality criteria.
- Which OpenRouter models are supported and what usage-visibility and cost ceiling apply to validation.
- One-time Mac App Store launch price. The market research recommends testing $39.99 / $59.99 / $79.99 with $59.99 as the starting hypothesis.

## Customer and Problem

The first customer is a self-directed, AI-experienced Mac user who can run a supported local model or explicitly configure optional OpenRouter access. The user manages a complex personal, commercial, or technical project involving unfamiliar research, consequential decisions, and follow-through across multiple AI sessions. The user owns the outcome and wants reliable continuity without designing or maintaining a project-management system.

Chat organizes work by session rather than maintaining an explicit project state. When the user returns, governing decisions, their rationale, unresolved questions, and remaining tasks are fragmented across conversations. The user must reread threads, repeat research, or rely on incomplete memory before progressing. Delegating research to an AI agent can deepen the problem: the work is faster, but conclusions the user did not personally derive are less likely to be remembered.

AI therefore improves individual sessions without reliably preserving continuity across the project.

## The Solution

ProjectOS is a local-first macOS application where conversation remains the natural way to explore, research, and plan. The AI proposes typed changes to topics, research, decisions, open questions, and tasks. The user accepts or rejects each proposed change; accepted changes update the versioned artifact state, which is the project's current source of truth. Conversations remain inspectable history and provenance but are never authoritative.

When the user returns, ProjectOS presents governing decisions, concise rationale with expandable evidence, recent research, unresolved questions, and open tasks. It recommends the next useful action and explains how relationships and dependencies in the current project state support that recommendation. A hero image and constrained theme give each project a distinct identity.

## What Makes This Different

Unlike configurable workspaces or chat products with opaque memory, ProjectOS provides an opinionated model of connected project concepts. Its differentiation thesis is semantic project continuity: governing and superseded decisions remain distinct, rationale and provenance remain inspectable, and blockers and downstream effects drive explainable guidance. The user controls project truth. The language model remains replaceable and is not the source of differentiation. Semantic project continuity is an advantage to validate, not a proven moat.

## MVP Scope

The MVP validates one loop: start a project — from scratch or from existing material the user brings in — work with AI, review proposed changes to structured knowledge, and resume later from an understandable current state with explainable guidance.

It includes:

- A local-first macOS application with no ProjectOS-hosted project-content backend.
- A provider-independent AI boundary with Ollama, LM Studio, and MLX as first-class local adapters and OpenRouter as the only optional external adapter. Guided onboarding—runtime/model readiness, explicit selection, Keychain-backed OpenRouter setup, local/external disclosure, cost disclosure, and plain-language recovery—is a launch requirement, not polish.
- A capability-aware adapter contract that keeps runtime/model mechanics out of Conversation, Change Proposal, Re-entry, export, and deletion workflows and prohibits silent provider, runtime, or model fallback.
- Lightweight import of existing project material: the user can paste or drop existing conversations, notes, and documents into a project's first session, and the AI proposes an initial structured state from them. Most target users arrive mid-project; a blank-slate-only start would test a weaker version of the continuity hypothesis and undermine the first-useful-state activation moment.
- Topics, Conversations, Research, Decisions, Open Questions, and Tasks as the core artifacts.
- AI-proposed changes with explicit acceptance or rejection; no autonomous changes to project truth.
- Versioned state with rationale, provenance, relationships, and decision supersession.
- Re-entry through governing decisions, recent research, unresolved questions, open tasks, and a recommended next action with an explanation.
- Lightweight project identity through a hero image and constrained visual theme.

It explicitly excludes:

- Automated bulk reconstruction of projects from AI-provider conversation exports or account integrations. Import in the MVP is limited to user-supplied pasted or dropped material.
- Shared projects, collaboration, assignments, roles, and permissions.
- Web or mobile applications and cross-device synchronization.
- Provider adapters beyond Ollama, LM Studio, MLX, and OpenRouter; remote Ollama/LM Studio endpoints are also excluded.
- Codex App Server, ChatGPT subscription integration, direct OpenAI or Anthropic APIs, automatic credit purchase/top-up, and automatic provider or model fallback.
- ProjectOS-hosted AI inference, provider billing, or cloud storage of project content.
- Requirements, Risks, Purchases, Measurements, Files, Photos, and Notes as first-class artifact types.
- Arbitrary typography, custom logos, or a full theme editor.

## Business Model and Evolution

The initial product is distributed through the Mac App Store as a one-time purchase. Users bring their own local runtimes/models or optional OpenRouter access. ProjectOS neither resells inference nor carries variable model-usage costs.

If the MVP proves that explicit project state helps individuals make progress and complete complex work, ProjectOS evolves into a managed, multi-surface service. The service removes provider configuration, broadens access, and can fund recurring capabilities such as synchronization, sharing, and collaboration.

Over time, the persistent project model becomes an operating system for complex projects: an inspectable body of knowledge that outlives individual conversations and model providers. New artifact types and collaborative capabilities can extend that foundation without changing the principle that users control project truth.

## Success Criteria

The north-star outcome is meaningful project progress followed by successful resolution—not conversation volume, generated artifacts, or habitual engagement.

| Criterion | Evidence |
| --- | --- |
| Meaningful progress | The project reduces uncertainty or advances execution through a resolved question, accepted or revised decision, cleared blocker, or completed real-world task. |
| Successful resolution | The user confirms that the intended outcome was achieved. Intentional abandonment is tracked separately. |
| Continuity | After time away, the user understands governing decisions, unresolved work, and the next useful action without rereading conversations. |
| Trust | Accepted AI proposals preserve accurate project state with limited correction, and users can inspect rationale and provenance. |
| Guided action | Explainable recommendations change project state or lead to completed real-world tasks instead of producing more suggestions. |
| Commercial signal | Target users pay once for the local application and accept configuring a supported local runtime/model or optional OpenRouter access. |

### Quantitative Decision Gates

The following thresholds are adopted from the market research (2026-07-28). They are management gates, not external benchmarks; failure on re-entry or price-bearing conversion stops expansion even if users enjoy the AI interaction.

| Gate | Initial threshold |
| --- | ---: |
| First useful state reached without assistance | At least 70% of testers within 15 minutes |
| Users reporting materially easier re-entry than their current workflow | At least 60% |
| Materially correct accepted decisions and project facts before manual correction | At least 85% |
| Price-bearing conversion among successfully activated trial users at $59.99 | At least 25% |
| Users successfully exporting and reopening their project data | At least 95% |
| Severe silent state corruption or unrecoverable data loss | 0 |
| Users starting or importing another project within 90 days | Observe first; set threshold from actual project cadence |

### Validation Sequencing

Concierge validation (Phase 1 of the market-entry plan: 20–25 AI-using people with active, high-stakes projects, real material imported, corrections measured, a 7–14 day gap retest, and a price-bearing ask) precedes or runs in parallel with MVP development. It requires no application build and de-risks the three lowest-confidence hypotheses — switching, willingness to pay, and explicit state beating conversational memory — before serious build investment. The PRD should be written after concierge results are in.
