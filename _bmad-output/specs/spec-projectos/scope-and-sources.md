# Scope, authority and repository handoff

## Current direction

The conversation on 2026-09-10 supplies the slice boundary: build something Wouter can use and feel, using local models and OpenRouter now; consider PCC later. External-chat handoff was rejected for friction. The latest instruction requests a spec for another agent and explicitly forbids starting implementation in this turn.

This is a personal-use vertical slice across the larger plan's Epics 2–5. It is not a new generic chat client and not a replacement car-shopping product. A car search and garden-office planning are useful test domains; neither introduces specialized features here.

Priority for this handoff: latest explicit user direction, then this spec's bounded scope and labelled defaults, then retained source requirements below. Broader artifacts remain unchanged. Their deferred features are not revoked, completed, or silently added to this slice. Do not mark an old epic done because this slice works. No prior Codex evidence authorizes reviving that adapter.

## Repository starting point

- At spec creation the Git working tree was clean on `main`; prior screening edits had been committed by the user.
- No product app or product build scaffold was found. `spikes/` contains experiment harnesses, not the product foundation. Create the app under `apps/ProjectOS/`; do not turn a spike into the application.
- Read `/Users/wouter/.codex/RTK.md`; shell commands are prefixed with `rtk`. Use `rtk proxy` for commands without an RTK wrapper. Recheck applicable repository instructions and Git status when implementation starts, and preserve unrelated work.
- No `project-context.md` or additional `AGENTS.md` was found in this checkout during discovery. Recheck rather than assuming that remains true.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` records the historical Epic 1 work only. It is not a complete executable plan for this slice. Track delivery against this spec and an implementation report; do not rewrite historical statuses.

## Source mapping and scope resolutions

Paths below are relative to this folder. These are selected requirements and lineage references, not adopted companions that import every older feature. All requirements needed to implement this slice are restated in the kernel and companions.

| Source | Retained | Explicit scope resolution |
|---|---|---|
| [PRD](../../planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md), FR-1–3 | Local projects, labelled pasted sources, integrated context-aware conversation: CAP-1/3. | Paste-only FR-2 controls this slice; local file and PDF intake from the broader UX are deferred. |
| PRD FR-4–10 | All five artifact kinds, proposals, controlled acceptance, relationships, provenance, version history, supersession, correction and undo: CAP-4/5. | Implement through lists and inspectors; graph canvas is not needed. |
| PRD FR-11–13 | Offline current-state re-entry, explained next action and local outcome records: CAP-6/8. | Recommendations are explicit, optional inference; no automatic recap on navigation. |
| PRD FR-14/18 | Capability-aware configuration, truthful qualification and provider independence: CAP-2/3/4. | Ollama plus OpenRouter deliver this slice; LM Studio/MLX and four-provider completion remain larger-plan work. |
| PRD FR-15–17 | Context disclosure, recoverable export, artifact removal and confirmed project deletion: CAP-3/5/7. | Stateless generation means no new provider-session cleanup subsystem. |
| PRD NFR-1–9/11/13 | Atomicity, ownership, uncertainty, local data, credential separation, context boundary, current-state priority and provider-neutral types. | No relaxation of integrity or secret handling to accelerate the prototype. |
| PRD NFR-10/12 | Offline local browsing and performance benchmark; concise truthful state/error messages. | Preserve the NFR-10 benchmark in acceptance. Full bilingual UI certification is deferred; Dutch content/evidence is mandatory. |
| PRD §8 and §9 | Personal-use re-entry, extraction correctness/completeness, guidance, effort and setup observations. | Do not block software handoff for a four-to-six-week study. Q1/Q2 are live-use prerequisites; commercial conclusions remain unproven. |
| [Brief](../../planning-artifacts/briefs/brief-ProjectOS-2026-07-27/brief.md) and [addendum](../../planning-artifacts/briefs/brief-ProjectOS-2026-07-27/addendum.md) | Cross-domain project continuity, user-owned truth and data, future one-time Mac sale without reselling inference. | No price, App Store release, provider subscription connection, or managed-service evolution is required here. |
| [Architecture](../../planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md), AD-1–13 | Owned provider port/types, explicit capabilities, conversation ownership, generation-only authority, validated output, explicit boundaries and application-owned lifecycle. | AD-4/6 adapter breadth is deferred as above; retain a small two-entry registry and only implemented capabilities. No framework for hypothetical providers. |
| [Experience](../../planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/EXPERIENCE.md) and [Design](../../planning-artifacts/ux-designs/ux-ProjectOS-2026-07-28/DESIGN.md) | Native behavior, Library → Overview, sidebar, conversation/proposal separation, evidence inspection, accessible state distinctions and restrained appearance. | Deferred: Pile Cover, map canvas, all theme presets, full notification center, full keyboard palette and localization. Do not import their full scope or file-intake matrix. |
| [Epics](../../planning-artifacts/epics.md) | Epics 2–5 describe foundation, governed conversation, re-entry and ownership. | Use the cross-layer sequence in this handoff, not completion of all work in each epic before exposing the loop. |
| [September exploration](../../planning-artifacts/product-direction-exploration-2026-09-02.md) | Integrated conversation, no inference middleman, few providers, no-model utility, retained project truth. | Its iOS-first, candidate, capture, matching and sync additions are not this slice. This does not claim those experiments are resolved. |

The latest request revisits the narrower Mac validation path. It does not authorize rewriting the governing brief, PRD, architecture, UX or epics. Log any later requested expansion explicitly rather than silently changing this handoff's boundary.

## Prior experiment evidence

The screening experiment's distinction between valid schema and true evidence informs the new proposal validator. Its listing fixtures, scores and prompts cannot prove project-state extraction quality. The historical Codex harness remains rejected/non-authorizing. No spike must pass before the native product shell and core loop can be implemented.

## Preservation audit

Every load-bearing claim selected above is mapped to a capability, invariant, acceptance check, runtime prerequisite, or explicit deferral. The source documents are not listed as fully absorbed `sources:` because their larger-scope content retains value for later work. Wrapper-only content excluded: workflow menus, historical reviewer prompts, previous implementation reports and diagram ceremony. Source decision history is retained in place.
