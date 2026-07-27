---
title: "Product Brief: ProjectOS"
status: final
created: 2026-07-27
updated: 2026-07-27
---

# Product Brief: ProjectOS

_Working name._

## Executive Summary

ProjectOS is a local-first macOS application for AI-experienced individuals managing complex, long-running projects. It solves the continuity failure of AI chat: useful research, decisions, questions, and tasks accumulate across conversations, but the user must reconstruct the project's current state whenever work resumes.

ProjectOS turns conversations into user-reviewed updates to an explicit, versioned project model. It preserves governing decisions and their rationale, keeps research and open work connected, and recommends the next useful action from project state. The MVP is sold once through the Mac App Store and stores canonical project data on the user's Mac. Users configure access to the supported AI provider and pay the provider's usage charges directly.

## Open Decisions

- Final product name; ProjectOS remains a placeholder.
- Initial AI provider and supported authentication or credential path.
- One-time Mac App Store launch price.
- Quantitative beta thresholds for continuity, trust, project progress, successful resolution, and paid conversion.

## Customer and Problem

The first customer is a self-directed, AI-experienced Mac user who is comfortable configuring provider access. The user manages a complex personal, commercial, or technical project involving unfamiliar research, consequential decisions, and follow-through across multiple AI sessions. The user owns the outcome and wants reliable continuity without designing or maintaining a project-management system.

Chat organizes work by session rather than maintaining an explicit project state. When the user returns, governing decisions, their rationale, unresolved questions, and remaining tasks are fragmented across conversations. The user must reread threads, repeat research, or rely on incomplete memory before progressing. Delegating research to an AI agent can deepen the problem: the work is faster, but conclusions the user did not personally derive are less likely to be remembered.

AI therefore improves individual sessions without reliably preserving continuity across the project.

## The Solution

ProjectOS is a local-first macOS application where conversation remains the natural way to explore, research, and plan. The AI proposes typed changes to topics, research, decisions, open questions, and tasks. The user accepts or rejects each proposed change; accepted changes update the versioned artifact state, which is the project's current source of truth. Conversations remain inspectable history and provenance but are never authoritative.

When the user returns, ProjectOS presents governing decisions, concise rationale with expandable evidence, recent research, unresolved questions, and open tasks. It recommends the next useful action and explains how relationships and dependencies in the current project state support that recommendation. A hero image and constrained theme give each project a distinct identity.

## What Makes This Different

Unlike configurable workspaces or chat products with opaque memory, ProjectOS provides an opinionated model of connected project concepts. Its differentiation thesis is semantic project continuity: governing and superseded decisions remain distinct, rationale and provenance remain inspectable, and blockers and downstream effects drive explainable guidance. The user controls project truth. The language model remains replaceable and is not the source of differentiation. Semantic project continuity is an advantage to validate, not a proven moat.

## MVP Scope

The MVP validates one loop: start a new project, work with AI, review proposed changes to structured knowledge, and resume later from an understandable current state with explainable guidance.

It includes:

- A local-first macOS application with no ProjectOS-hosted project-content backend.
- One supported AI provider integration. The user supplies access credentials and pays the provider's usage charges; the project model remains provider-neutral.
- Topics, Conversations, Research, Decisions, Open Questions, and Tasks as the core artifacts.
- AI-proposed changes with explicit acceptance or rejection; no autonomous changes to project truth.
- Versioned state with rationale, provenance, relationships, and decision supersession.
- Re-entry through governing decisions, recent research, unresolved questions, open tasks, and a recommended next action with an explanation.
- Lightweight project identity through a hero image and constrained visual theme.

It explicitly excludes:

- Importing or reconstructing projects from existing AI conversations.
- Shared projects, collaboration, assignments, roles, and permissions.
- Web or mobile applications and cross-device synchronization.
- Additional user-selectable AI providers or local-model configuration.
- ProjectOS-hosted AI inference, provider billing, or cloud storage of project content.
- Requirements, Risks, Purchases, Measurements, Files, Photos, and Notes as first-class artifact types.
- Arbitrary typography, custom logos, or a full theme editor.

## Business Model and Evolution

The initial product is distributed through the Mac App Store as a one-time purchase. Users supply credentials for the supported AI provider and pay its usage charges separately, so ProjectOS does not carry variable inference costs.

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
| Commercial signal | Target users pay once for the local application and accept separate provider usage costs. |

Quantitative thresholds should be established before a limited beta, once expected project duration and launch pricing are defined.
