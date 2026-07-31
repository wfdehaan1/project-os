---
title: Post-MVP Feature Ideas — ProjectOS
date: 2026-07-28
status: captured
source: brainstorm session (brainstorm-post-mvp-features-2026-07-28)
---

# Post-MVP Feature Ideas

Candidate features for ProjectOS beyond the MVP, generated after the validation-build PRD was completed. None of these are commitments; this is downstream input for future PRD/spec work.

## Seed Idea: Project Graph Visualization of Artifacts

Visualize the project's Artifacts and their relationships (decisions, research, sources, provenance links) as an interactive graph — a visual lens on Canonical State.

**Variants:**
- **Ego graph / focus view** — one Artifact at the center with its immediate neighborhood.
- **Decision lineage view** — the chain of decisions and superseded predecessors behind a governing decision.
- **Delta-highlighted project map** — the full map with recent changes visually emphasized (re-entry aid).
- **Full graph** — the complete project map.

**Watchouts:**
- Hairball risk beyond ~50 nodes; needs filtering/clustering or view scoping.
- Layout stability: the map must not rearrange arbitrarily between sessions.
- Superseded state must stay visually subordinate to governing state.
- Must not become engagement-bait (counter-metric SM-C2) — it serves orientation, not dwell time.

## Ideas by Theme

### 1. Re-entry deepening
- Audio re-entry briefing: podcast-style what-changed recap before sitting down.
- Scheduled absence mode / pre-departure ritual: declare an absence; app prepares mothball summary, closing summary, and re-entry package (two log lines merged).
- Cross-project re-entry dashboard: one morning view of which project most needs attention.
- Weekly digest notification: accepted changes and aging open questions.
- Session handoff notes: auto-drafted, user-approved note-to-future-self at session end.
- Next Action queue with effort estimates: pick a 10-minute task vs a deep session.
- Focus mode: full-screen single Next Action, everything else hidden.
- Momentum view: gaps and streaks of meaningful work, framed gently per counter-metrics.
- Opt-in AI check-ins: drafted you-have-been-away state notifications.
- Printable project passport: one-page offline snapshot of governing state.

### 2. Trust instrumentation
- Trust check score: system self-reports how stale or contradictory Canonical State is.
- Provenance strength meter: per-Artifact evidence-quality indicator (multiple sources vs single chat claim).
- Stale-state detection: flags old research that governing decisions rely on; suggests re-verification.
- Background contradiction sweeps: conflicts flagged as proposals, never mutating state.
- Decision debt tracker: surfaces decisions with weak rationale or thin provenance.
- Decision review dates: optional revisit-by date; decisions resurface when due.
- Red-team mode: AI critiques a user-authored Decision against existing Research and Decisions.
- Argue with past self: before superseding a decision, replay the original rationale for rebuttal.
- Multi-provider arbitration: two models extract independently; divergence surfaced as uncertainty.
- Project health heuristics: aging open questions, blocked tasks, unresolved contradictions.

### 3. Graph / visual lenses
- Project graph visualization of Artifacts (seed idea, above).
- Time machine scrubber: view Canonical State as of any past date.
- Decision diff view: governing vs superseded side by side, changes highlighted.
- Confidence weather map: forecast-style visual of project areas by certainty and staleness.

### 4. Capture surface expansion
- Quick-capture inbox: menubar or share sheet into a project staging area.
- Web clipper: archives URL snapshots as durable Source Material.
- Voice conversation mode: spoken sessions transcribed with provenance preserved.
- Images, sketches, photos as first-class Source Material with AI descriptions for search.
- Structured decision-intake interview mode: AI interviews the user to elicit state.
- iOS companion: read-only Re-entry View plus quick capture.
- Direct artifact editing with AI as reviewer/linker instead of proposer.
- Project archaeology: bounded import of an old project's docs to reconstruct Canonical State.

### 5. Interop and openness
- MCP server exposing Canonical State: any external AI tool can use ProjectOS as its trusted memory backend.
- Markdown vault interop: continuous export/import bridge to Obsidian-style vaults.
- Shortcuts/automation hooks for local scripting against project data.
- Sync via user-owned storage (iCloud Drive/Syncthing): local-first, no hosted backend.
- Calendar integration: schedule re-entry sessions and task deadlines.
- Stakeholder brief generator: one-click external summary from Canonical State.
- Public build-log export: decision history as a shareable narrative.
- Project handoff export: another person can adopt and continue with full provenance.
- Ollama and local model providers as a privacy tier.

### 6. Governance scaled up
- Multiplayer continuity: invite a collaborator under the same governance model with role-based acceptance.
- Household mode: shared family projects (renovation, health) with per-person views.
- What-if branches: fork Canonical State to explore an alternative decision path, then merge or discard.
- Batch triage mode for Change Proposals: inbox-zero accept/edit/reject flow.
- Trust levels per Artifact type: auto-accept low-stakes types; Decisions always require review.
- Governed agent delegation: agents execute external tasks; every consequential outcome returns as a Change Proposal.
- Personal decision model: learns your decision style, flags deviations from your own patterns.

### Other / long-horizon
- Natural-language search over decisions and rationale ("why did I decide this").
- Semantic search across all projects, conversations, and provenance.
- One-click question research: scoped research pass on an Open Question, results filed as Change Proposals.
- Talk to your project: a persona grounded strictly in Canonical State.
- Shared reference library of reusable Research and Artifacts across projects.
- Template gallery: starting Artifact scaffolds per domain (renovation, book, startup, health).
- Short-lived project mode: 2-week sprint template with compressed lifecycle (event, talk, move).
- Lifelong knowledge estate: projects as chapters with a cross-project timeline of life decisions.
- Legacy mode: a project inheritable and legible to family (estate, health history) with provenance intact.
- Privacy-preserving federated patterns: opt-in anonymized insight ("people with similar decisions hit this problem").

## Strategic Threads

- **Platform thread:** the MCP server makes ProjectOS the governed memory backend other AI tools trust — it turns the moat (Canonical State) into a platform.
- **Near-term "evidence UI" synergy:** graph visualization + decision diff view + provenance strength meter form one coherent investment in making evidence and state legible.
