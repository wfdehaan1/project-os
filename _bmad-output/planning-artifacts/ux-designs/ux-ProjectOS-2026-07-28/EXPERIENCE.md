---
name: ProjectOS
status: draft
sources:
  - _bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md
  - _bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/addendum.md
  - _bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/brief.md
  - _bmad-output/planning-artifacts/research/market-projectos-market-opportunity-research-2026-07-27.md
  - _bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md
updated: 2026-07-31
---

# ProjectOS — Experience Spine

## Foundation

ProjectOS is a single-owner, local-first native macOS application for a commercial consumer MVP. Canonical project data, Conversations, proposals, Sources, history, settings, and exports live on the Mac. The MVP has no ProjectOS account, hosted project-content backend, collaboration, shared state, web/mobile client, or cross-device synchronization.

Native macOS conventions govern windows, menus, Settings, focus, undo/redo, text editing, Keychain, notifications, system appearance, Reduce Motion, Increase Contrast, and assistive technologies. The implementation toolkit—SwiftUI, AppKit, or a combination—is not decided here. [`DESIGN.md`](DESIGN.md) is the visual identity and shared component reference; this spine owns behavior, states, navigation, and flows.

The product contract is human-governed semantic continuity:

1. Conversation or selected Source Material supplies evidence and context.
2. The agent may generate typed Change Proposals.
3. Proposals persist separately from the transcript and never become Canonical State automatically.
4. Wouter explicitly accepts, edits and accepts, rejects, defers, or requests revision.
5. Accepted changes are atomic, versioned, related, and traceable to exact provenance when available.
6. Overview restores current understanding; Project Map explains relationships; Conversation continues the work.

Opening, browsing, selecting, filtering, searching, importing locally, or navigating never authorizes a provider request. Only an explicit provider action after a Context Preview authorizes work across the configured provider boundary. Provider setup, status, capabilities, and errors use one shared shell; each adapter supplies its own authentication, runtime, model, usage, and local-versus-external details.

The first adapter uses a ProjectOS-owned Codex App Server process. Codex owns ChatGPT browser authentication and token persistence; ProjectOS never asks for an API key or reads ChatGPT tokens. Eligible usage draws from the user's ChatGPT/Codex plan allowance. Additional cloud providers and local-model runtimes remain future adapters, and their addition must not change the core Conversation, proposal-review, Re-entry, or ownership journeys.

## Information Architecture

App open lands on Project Library. Entering a project lands on Overview. Inside a project, the persistent Project Sidebar groups Orientation (Overview, Project Map), Active work (Conversation, Topics, Tasks), and Accepted knowledge (Decisions, Research, Questions). Research contains **Research** and **Sources** subviews. Footer destinations are Offline status when applicable, Notification Center, Project Settings, and Global Settings. Global search/commands are available through Command Palette.

| Surface | Reached from | Purpose and primary content |
|---|---|---|
| First Run | First app launch | Skippable language/privacy orientation, optional AI Provider setup, readiness summary; then Project Library. The initial adapter detects Codex and offers Continue with ChatGPT. |
| Project Library | App open, All Projects, restored project completion | Project Card grid/list, New Project, Restore; cards contain Pile Cover and title only. |
| New Project | Project Library / `⇧⌘N` | Short project description, local creation, then guided kickoff offer or Overview. |
| Overview | Project Card, project switch, `⌘1` | Pile Cover, What's Up Next Card, project description, historical recap/accepted changes, relationships, affected work, related state, provenance. Normal re-entry surface. |
| Project Map | Project Sidebar / Pile Cover / `⌘2` | Accepted semantic graph plus structured outline, lenses, node/relationship selection, Artifact Inspector or Relationship Inspector, optional proposal layer, Context Preview. |
| Conversation | Project Sidebar / recommendation / grounded artifact action / `⌘3` | Conversation List, active Transcript, Composer, Context Preview before send, Proposal Rail and Proposal Inspector. |
| Topics | Project Sidebar / `⌘4` | Flat list of enduring work/inquiry areas; Topic detail through Artifact Inspector. |
| Tasks | Project Sidebar / `⌘5` | Concrete external actions and their blockers/effects; Task detail through Artifact Inspector. |
| Decisions | Project Sidebar / `⌘6` | Governing-first list with Superseded history on demand; Decision detail through Artifact Inspector. |
| Research | Project Sidebar / `⌘7` | Accepted Research and Sources subviews; Research detail through Artifact Inspector, raw material through Source Inspector. |
| Questions | Project Sidebar / `⌘8` | Open/in-exploration/awaiting-evidence first, resolved/dismissed history on demand; detail through Artifact Inspector. |
| Notification Center | Project Sidebar footer | Durable actionable/background events, deduplicated and deep-linked to exact context. |
| Project Settings | Project Sidebar footer | Identity, theme inheritance, working language, optional provider/model and notification overrides when supported, export/verify, restore, archive, delete. |
| Global Settings | Sidebar footer / `⌘,` | General, Appearance, AI Providers, Notifications, Accessibility and Keyboard, Data and Recovery, About. |
| Export and Verification | Project Settings | Scope preview, destination, atomic progress, completion actions, manifest verification. |
| Restore Preflight | Project Library | Read-only package inspection, compatibility/migration/corruption disclosure, new-copy default, atomic restore and verification. |
| Command Palette | `⌘K` | Search across projects and commands; navigate and start safe actions without bypassing review or confirmation. |

The [selected Overview](.working/design-direction-selected.html) establishes the split masthead and relational body; the [approved Project Sidebar](.working/sidebar-direction.html) replaces the obsolete horizontal tabs shown in that earlier Overview artifact. The governing Project Map behavior is illustrated by the [semantic map concept](../../../../docs/mockups/project-overview/02-semantic-map.png) and [interaction companion](../../../../docs/mockups/project-overview/project-map-interactions.md), with **Research/Sources** replacing the visual's obsolete “Evidence” type.

### Artifact contracts

| Artifact | Canonical meaning | Required fields and states | Type-aware actions |
|---|---|---|---|
| Topic | Enduring area of inquiry/work; not a task, folder, phase, lane, or PM container. Flat in MVP. | Title, purpose/scope, related artifacts/Conversations, provenance/history. Current or retired from current views. | Grounded Conversation, inspect related work, edit, propose split/merge, retire without erasing history. |
| Task | Concrete action outside accepted project knowledge required to advance work. | Title, expected outcome, why, actor (Wouter or agent-assisted), Open/In progress/Blocked/Done, blocking/affected relationships, related artifacts, provenance/history, optional factual deadline and completion evidence. | Change status, add evidence, inspect blockers/effects, grounded Conversation, edit/defer/dismiss. |
| Decision | One explicit governing commitment; never tentative. | Statement, Governing/Superseded, rationale, alternatives, implications, conditions/revisit trigger, effective date, actor, evidence, origins, relations, versions/supersession. | Inspect lineage/effects, compare versions, correct, replace, reconsider; removal requires withdrawal/replacement record. |
| Research | Accepted evidence-backed synthesis; not raw Source Material and not permanent truth. | Title, finding, scope, evidence deep-links, interpretation, plain-language certainty, contradictions/limitations, date, relations, provenance/history; Current/Tentative/Contested/Superseded. | Inspect evidence, compare contradiction, grounded Conversation, correct/supersede, inspect dependencies. |
| Open Question | Decision-relevant answerable uncertainty with a concrete consequence. | Question, why, resolution criteria, impact/blocking relations, Open/In exploration/Awaiting evidence/Resolved/Dismissed, evidence/origin/history, resulting Decision. | Grounded Conversation, answer directly, inspect blockers/evidence, create evidence Task, dismiss, open resulting Decision. |
| Conversation | Preserved working context and Provenance; not Canonical State. | Local editable title, messages, scope, language, provider metadata, proposal-generating anchors, linked artifacts/proposals. | Resume, search/filter, focused follow-up, inspect resulting artifacts/proposals. |
| Source Material | Original user-selected evidence retained locally; distinct from Research. | Original copy, extracted representation, source/import metadata, known language, extraction state, usage history, referring artifacts/Conversations. | Inspect original/extraction, add to Context Preview, navigate exact passage, remove after effect disclosure. |

Direct user artifact changes become versioned Canonical State immediately with Undo where the artifact contract permits it. Agent-created consequential changes always enter proposal review. Directly answering an Open Question creates a linked Decision and preserves the original question as Resolved history. A conversational answer leaves the question unresolved until its Decision proposal is accepted. Completing a Task invalidates state-bound recap/recommendation but never silently resolves a Question or creates a Decision.

## Voice and Tone

Microcopy is calm, concise, inspectable, and literal. Brand posture lives in `DESIGN.md.Brand & Style`.

| Do | Don't |
|---|---|
| “Saved on this Mac.” | “Secure forever.” |
| “This will send 3 selected excerpts through Codex to OpenAI.” | “Ask AI” with no provider or scope disclosure. |
| “Offline. Local inspection remains available; agent calls are unavailable.” | “Connection error” for every provider/offline condition. |
| “Needs review” / “Accepted with edits” / “Superseded” | “Done” for semantically different states. |
| “The recommendation is uncertain because two accepted findings conflict.” | Confident language unsupported by Canonical State. |
| “Exact source moment unavailable. Opened the originating Conversation.” | Silently opening an approximate location. |
| “No matches.” / “No Decisions yet.” | Cheerleading, exclamation marks, streaks, or engagement nudges. |
| “Codex plan usage: 28% used; resets Monday at 09:00.” | Assuming every provider has billing, credits, or a fixed weekly reset. |

English and Dutch use the same information hierarchy and shortcut bindings. Localized copy may reflow; it must not be shortened into ambiguity. User-authored and original Source/Conversation content is never silently translated or rewritten. Quotes stay in the original language; optional translation is labeled and uncertainty disclosed.

## Component Patterns

Visual specifications live in `DESIGN.md.Components`. These exact shared names must be used throughout the product.

| Component | Behavioral contract |
|---|---|
| Button | One component with primary, secondary, ghost, destructive, and disabled variants. Visible label or accessible name is required. Disabled provider actions stay visible with reason; canonical/destructive actions always retain normal confirmation/effect preview. |
| Status Badge | Names state in text and exposes it to assistive technology. Counts only actionable proposals/blocked work/unread actionable notifications. Never interactive unless the whole badge is explicitly a filter control. |
| Project Sidebar | Resizable/collapsible, width persisted per window. Active destination, badges, Offline row, footer settings, tooltips, and screen-reader labels survive collapse. Direct resize tracks pointer without animation. |
| Project Switcher | Opens local project selection and New Project. Switching is local, restores target Overview, and never contacts the provider. |
| Project Card | Entire card opens the project Overview. Keyboard focus covers the card once; internal Pile Cover marks are not separate targets. |
| Pile Cover | One accessible action on Overview (“Open Project Map”) and passive content inside Project Card. Legend and full-sentence accessibility label derive from the same counts as the drawing. Marks are non-interactive. |
| What's Up Next Card | Three primary states: Needs recap, Current, Offline. Generate is explicit; Continue starts a grounded Conversation automatically only after Wouter selects it. Inspect remains local. Dismiss does not mutate Canonical State. |
| Relational Briefing | Locally available orientation. Each summary/relationship links to relevant accepted detail, provenance, or history; it remains useful without AI. |
| Conversation List | Ordered by recent activity, searchable and filterable by Topic. Titles derive from first message and are editable locally. Rows indicate pending/blocked/deferred proposal state. Selection restores local draft, scroll, and review position. |
| Transcript | Streams readable chunks; auto-scroll only when near the bottom. Stop preserves partial content marked Incomplete. Provenance links restore exact turn and nearby context when possible. |
| Composer | Multiline draft persists locally. `⌘Return` sends; `⇧Return` inserts newline; `Esc` never destroys text. Sending requires visible scope/provider preview and is disabled offline without queuing. |
| Context Preview | Appears before every provider call with adapter/provider, local-versus-external execution, selected scope, included Sources/excerpts/artifacts, working language, and plan-allowance or cost disclosure when supported. Wouter may inspect and narrow eligible scope before explicit start. |
| Proposal Rail | Defaults to current Conversation proposals; offers project-wide pending view. Persists independent of transcript and supports Pending, Needs review, Blocked, Deferred, Accepted, Accepted with edits, Rejected, Superseded/history. |
| Change Proposal Card | Opens Proposal Inspector and navigates back to exact originating turn. Shows type, operation, summary, source, set/dependency, status. No card action bypasses effects review. |
| Proposal Inspector | Shared inspector across artifact types. Edit creates a persisted local draft. Accept is explicit and atomic; Accept compatible set appears only when proven non-conflicting. Reject is immediate/recoverable with optional reason; revise requires a new explicit agent call. |
| Artifact Row | Opens Artifact Inspector. Current state is default; history filters never make historical state look governing. User-authored direct changes use the artifact-specific canonical/Undo rule. |
| Artifact Inspector | Keeps current accepted information first, history on demand, exact provenance, related artifacts, and only type-meaningful actions. Provider actions are distinguishable before activation. |
| Relationship Inspector | Opens from a Project Map edge or relationship link. Explains meaning, rationale, provenance, state, affected artifacts, and local/provider actions. Multi-selection scope remains visible. |
| Project Map | Selecting/filtering is local and non-mutating. Supports current/unresolved/history/provenance/recent/Topic/pending lenses, Focus mode, stable layout, viewport restoration, multi-select, zoom/pan, and equivalent structured outline. |
| Source Inspector | Shows original, extraction, metadata, language, usage, references, and missing/partial state. Source removal first explains effects and cannot imply reversal of prior provider transmission. |
| Notification Center | Groups related events into evolving durable items, retains read/action state, and deep-links to exact context. Opening a notification is local; it never accepts/rejects a proposal. |
| Progress Indicator | Shows named phases. Determinate only for measurable work; otherwise restrained indeterminate. Long safe-to-stop work exposes Cancel/Stop. Completion/failure replaces progress in place. |
| Empty State | States why the surface is empty and offers the shortest relevant action. It never fabricates sample projects or requires AI when local creation is possible. |
| Settings Row | Shows inherited global values for project overrides and one-action reset with Undo. Changes are local unless the row explicitly tests provider connection or opens macOS permission settings. |
| Confirmation Sheet | Used for permanent deletion, direct governing Decision replacement/withdrawal, and other high-impact local actions. Names effects, exclusions, recovery/Undo limits, and safe cancel. |
| Command Palette | `⌘K` searches projects and commands. Keyboard selection and activation are complete. It may navigate to proposal review but never provides direct accept/reject or bypasses a Confirmation Sheet. |
| Search Field | `⌘F` searches current surface; standard `⌘G`/`⇧⌘G` moves matches. Scope and result count are announced; clearing search restores the prior selection where practical. |

The approved proposal-review anatomy is documented in the [Conversation and proposal review wireframe](.working/flow-proposal-review-2026-07-29.excalidraw).

## State Patterns

### Global state model

| State | Treatment |
|---|---|
| Cold local load | Restore shell and last local selection first; use layout-preserving placeholders only while local reads complete. Failure identifies the affected local store and preserves last coherent state. |
| Provider ready | Local actions available; provider actions become available but still require explicit initiation. The shared status surface names the active adapter and declared capabilities. |
| Provider not configured | All local capabilities remain. Invoking provider work opens the configured adapter's setup and returns to the interrupted action after success. |
| Provider runtime missing or incompatible | The provider action names the required runtime and recovery path. Installing or updating a runtime never sends Project content. |
| Provider signed out or authentication expired | The adapter-specific sign-in or reconnect action is available; drafts and Project State remain intact. |
| Offline | Persistent Sidebar status with text and accessible state. All locally computable actions remain; provider actions stay visible but disabled with explanation. Nothing is silently queued. |
| Provider request in progress | Truthful phases, streaming when applicable, Stop/Cancel when safe, optional background behavior. Navigation preserves work. |
| Provider interrupted | Partial output remains visibly Incomplete and cannot become trusted Research/Change Proposal. Explicit retry re-evaluates current context. |
| Authentication/rate/allowance/provider failure | Distinct plain-language diagnosis, retained draft/partial output, relevant setup, reset-time, or retry action. Never collapse into generic Offline wording or route to API-credit purchase. |
| Canonical transaction pending | Effects and dependencies visible; Canonical State unchanged until explicit atomic acceptance. |
| Canonical transaction failed | Entire transaction rolls back; last coherent state remains; error and safe retry/inspection are available. |
| Focus | Native visible focus, reading-order traversal, no unexpected focus movement. Inspector open/close restores focus to origin. |
| Permission denied | Local work remains. macOS notification denial is explained with a route to System Settings; no repeated prompts. |

### Surface coverage

| Surface | Required states |
|---|---|
| First Run | Fresh, skipped, language changed, provider runtime absent/incompatible, signed out, browser sign-in pending/cancelled/expired, device-code fallback when available, ineligible plan, connection testing, unavailable/rate/allowance error, ready with/without AI. No notification-permission prompt. |
| Project Library | Cold local load, empty, populated, search/no matches, project unavailable/corrupt, offline, restore running/succeeded/failed. |
| New Project | Empty description, valid description, local create progress/failure, created with kickoff offer, created without AI, offline. |
| Overview | Needs recap after create/change, generating, current persisted recap/recommendation, recap closed this visit, saved current return on revisit, dismissed recommendation, uncertain recommendation, offline with matching saved return, offline without current return, local read failure. |
| Project Map | Empty/lightly structured, current graph, Focus mode, lens/no matches, node selected, relationship selected, multi-select, proposal layer, historical/superseded, missing provenance, offline, structured outline, layout/update error. |
| Conversation | No Conversations, restored Conversation, draft-only, sending/streaming, stopped/incomplete, proposal generated, no provider, offline, runtime/authentication/rate/allowance/provider failure, unsupported capability, exact anchor found/unavailable, search/no matches. |
| Topics | Empty, current, retired/history filter, selected detail, direct edit/Undo, proposed split/merge, offline, local failure. |
| Tasks | Empty, Open/In progress/Blocked/Done, factual deadline with reminder off/on, completion/Undo, dismissed/history, offline, local failure. |
| Decisions | Empty, Governing, Superseded/history, replacement review, corrected version, withdrawal/removal confirmation, missing provenance, offline, local failure. |
| Research | Empty Research, Current/Tentative/Contested/Superseded, contradiction comparison, missing evidence/Needs review, Sources subview, offline, local failure. |
| Questions | Empty, Open/In exploration/Awaiting evidence/Resolved/Dismissed, Blocking/non-blocking, direct answer, awaiting Decision proposal acceptance, offline, local failure. |
| Notification Center | Empty, unread actionable, read informational, grouped/evolving, deep-link unavailable/fallback, offline, macOS permission denied. |
| Project Settings | Inherited values, explicit overrides, reset/Undo, export progress/result, archive, delete preflight/confirmed/failed, offline. |
| Global Settings | Follow macOS/Light/Dark, five presets, provider adapter absent/runtime missing/signed out/signing in/testing/limited/ready/error, account and plan, capability summary, allowance and reset when supported, notification permission unknown/allowed/denied, accessibility preferences changed, data-health warning. |
| Export and Verification | Preview, destination conflict, measurable/indeterminate progress, cancelled, failed/no valid partial, complete, verifying, Verified, mismatch/corrupt. |
| Restore Preflight | Reading, compatible, migration needed, corrupt/missing evidence, identity conflict, cancel, atomic restore, rollback, restored unverified, Verified. |
| Command Palette | Closed/open, query, result selected, no matches, disabled command with reason, focus restored. |

### Generated return-point lifecycle

One explicit **Generate recap** action creates two outputs against one exact Canonical-State version: a historical Recap and future-facing What's up next. Recap summarizes recent changes, work performed, and recent Decisions only. What's up next recommends an Open Question or concrete Task, gives concise reasoning, and links to detail. A generated pair persists locally for that project state.

Closing the Recap hides it for the current project visit only. On a later visit, it reappears when the Canonical-State version still matches. Any canonical change invalidates both outputs immediately; stale content is not shown. The Overview returns to Needs recap. Offline, a still-matching saved pair remains readable; an offline canonical change invalidates it until an online explicit regeneration.

### Change Proposal lifecycle

Proposals from one agent response form a named, dependency-ordered set. Independent proposals may be reviewed separately. Hard-dependent proposals are one atomic group. `Accept compatible set` is shown only when compatibility is proven and after a combined-effects summary. Editing revalidates dependents and can return them to Needs review. Rejecting a prerequisite marks dependents Blocked rather than rejecting them. Rejected proposals leave the active queue, support immediate Undo and later Return to pending, and retain optional structured/free-text reason. Deferred is not rejected.

Accepted with edits preserves agent original, accepted version, diff, timestamp, originating Conversation, optional correction note, proposal-set membership, dependencies, and resulting Canonical-State version. Every status retains a link to its originating Conversation and exact proposal-generating moment where recoverable.

### Source intake lifecycle

Add Source is available from Research, Conversation context selection, and relevant empty states. Paste, drag/drop of supported files, and macOS file selection create a durable local copy without provider contact. Intake previews title/type/size/retained content. Extraction reports truthful progress and Complete/Partial/Failed; original content remains available after extraction failure. Import alone never creates Research or Canonical State.

The exact MVP file-format list remains unresolved and must be settled before implementation stories claim specific parsers.

## Interaction Primitives

### Keyboard model

All commands have visible menu or control equivalents. Bindings are identical in English and Dutch; MVP does not support custom bindings or unmodified/Vim-style sequences.

| Shortcut | Action |
|---|---|
| `⌘K` | Open Command Palette / global project and command search |
| `⌘F` | Focus Search Field for current surface |
| `⌘G` / `⇧⌘G` | Next / previous current-surface match |
| `⌘,` | Global Settings |
| `⌘N` | New Conversation |
| `⇧⌘N` | New Project |
| `⌘1` … `⌘8` | Overview, Project Map, Conversation, Topics, Tasks, Decisions, Research, Questions |
| `⌘[` / `⌘]` | Back / forward in local navigation history |
| `⌥⌘S` | Toggle Project Sidebar |
| `⌘.` | Stop active provider or long-running operation when safe |
| `⌘Return` / `⇧Return` | Send / newline in Composer |
| `Esc` | Close top inspector/popover or return focus; never discard draft |
| `⌘S` | Persist a draft where relevant; never accept a proposal |
| `⌘+` / `⌘-` / `⌘0` | Project Map zoom in/out/fit |

Proposal review is fully keyboard operable but deliberately has no single-key/global accept or reject command. Project Map's structured outline uses arrows to navigate, Return to open Inspector, and Shift to extend selection. Equivalent function never requires freeform canvas manipulation.

### Pointer, selection, and focus

- Single click selects or opens according to the visible control; double-click is not required for core actions.
- Selection is local. Provider contact and Canonical State mutation always need a separate explicit action.
- Hover may preview but never expose the only route to an action.
- Closing an Inspector restores focus to its originating row/node/relationship/card.
- Multi-selection is deliberate and exposes a visible scope summary before comparison/synthesis.
- Standard macOS undo/redo applies to direct local changes and supported recoverable actions; proposal acceptance history is governed by explicit new accepted transitions, not hidden destructive rollback.

### Motion and continuity

Motion uses `{motion.quick}`, `{motion.standard}`, `{motion.deliberate}`, and `{motion.travel-min}`–`{motion.travel-max}` from `DESIGN.md`.

- Sidebar collapse preserves active location while labels fade; pointer resize is immediate.
- Surface navigation preserves shell, focus, and relevant scroll with restrained crossfade/directional shift.
- Overview masthead dimensions stay fixed while Needs recap, Current, and Offline contents crossfade.
- Transcript streams readable chunks and does not pull Wouter from an older scroll position.
- New Change Proposal Cards appear with subtle continuity from the source turn; Proposal Inspector expands from the selected card.
- Atomic acceptance animates as one transaction and briefly links affected artifacts without celebration.
- Project Map preserves spatial positions, emphasizes selected neighbors, anchors Inspector entry to selection, and avoids unnecessary re-layout.
- Provenance deep-links scroll and briefly emphasize without flashing.
- Theme changes crossfade semantic colors; import/export/restore replace progress in place with success or failure.
- Reduce Motion immediately replaces movement, scaling, and animated scrolling with immediate state changes or a short opacity transition.

## Offline, Notifications, and External Boundaries

### Offline capability rule

Every action computable entirely from local project state remains available. Every action requiring the configured AI Provider Adapter is unavailable when that adapter is not ready and is never silently queued.

| Available offline | Unavailable offline |
|---|---|
| Project/Library management; artifact, Source, Conversation, proposal and history browsing/search; Project Map and outline; local Source import/extraction; direct user-authored canonical changes and Undo; persisted proposal review; drafts; export/restore/verification; settings; local-operation notifications. | Agent send/continue; Recap/What's up next generation; proposal revision; AI synthesis; provider connection/model/account/allowance refresh; any action that requires an unavailable provider adapter. |

Drafts may be prepared offline. Reconnection never sends automatically: Wouter chooses Resume, receives a fresh Context Preview against current state, then explicitly starts. Mid-request network loss preserves partial output as Incomplete. Runtime, authentication, allowance, provider service, unsupported-capability, and network-offline errors use distinct language.

### Notification levels

1. **Inline only:** local save, proposal accept/reject, navigation/theme changes, online/offline transition, provider progress while Wouter is watching.
2. **Notification Center:** proposal sets ready after Wouter leaves, Blocked/Needs review proposals, long import/extraction/export/restore completion, retained-work provider failures, authentication/Source attention, approaching allowance limit or limit reached when reported by the adapter.
3. **macOS notification:** user-initiated background provider/import/export/restore work completes, fails, or needs input while ProjectOS is not frontmost.

macOS notifications may deep-link but never accept/reject Canonical State. Events are deduplicated into evolving items. There are no engagement reminders, inactivity nudges, streaks, promotions, or automatic recap nudges. Permission is requested just in time, when Wouter first starts work that could usefully finish in the background. Global categories inherit into projects; projects may override or mute. macOS Focus and system settings remain authoritative.

### Theme and localization inheritance

Appearance precedence is: macOS preference when Follow macOS → global appearance and base preset → optional project identity-token preset → accessibility requirements. Theme changes never alter motion behavior. First use follows macOS and uses Studio Paper without asking.

Interface language is global English or Dutch, derived from macOS when supported and otherwise English. It controls ProjectOS UI, menus, Settings, notifications, system copy, dates, numbers, provider usage or allowance values, and accessibility labels—not project content. Each project has English/Dutch working language, defaulted from interface language at creation. It controls future agent responses, recaps, recommendations, proposals, and generated artifact titles/descriptions and appears in Context Preview.

Conversation may explicitly override the working language. Canonical proposals default to project language unless review makes another choice explicit. Changing project language affects future generation only. Translation of accepted content is explicit, reviewable, and preserves original text.

## Settings and Ownership

| Surface | Groups and invariants |
|---|---|
| Global Settings | General (language, launch, default location); Appearance (Follow macOS/Light/Dark, default preset, motion preference subject to system); AI Providers (adapter selection, setup, runtime status, account/plan, capabilities, default model when supported, connection test, allowance/reset or provider cost when supported); Notifications; Accessibility and Keyboard; Data and Recovery; About. The Codex adapter contributes Continue with ChatGPT, runtime compatibility, plan allowance, and sign-out with provider-session cleanup disclosure; a local adapter may contribute model/runtime controls without an account section. |
| Project Settings | Title, description, theme/global inheritance, working language, optional provider/model override when supported, notification inheritance/overrides/mute, export/verify, restore, archive, delete. No cover selector: Pile Cover is automatic. |

These cannot vary by project: canonical approval, explicit provider initiation and disclosure, provider-authentication isolation, accessibility floor, interface language, shared component behavior, keyboard operability, offline honesty, provenance/audit, and human-inspectable export format.

Export produces a normal folder or ZIP containing README, Markdown artifacts/Conversations, structured JSON for exact restoration, retained original Sources/extractions, project identity/theme/settings, relationships/rationale/provenance/history, proposals, and a checksum/schema/count/time manifest. It excludes provider credentials and tokens, runtime caches and unsanitized logs, active Provider Session Bindings, and unrelated global settings. It writes to a temporary location and publishes atomically. Cancel/failure leaves source unchanged and no partial output valid.

Restore begins in Project Library, performs read-only preflight, previews identity/date/version/counts/corruption/migrations/conflicts, and creates a new project copy by default. Migration/persistence is atomic with full rollback. Missing evidence is disclosed, never reconstructed. Verification compares the restored project with the manifest and deep-links representative Decisions, Sources, and Conversation provenance. Restored Conversations receive new provider bindings when AI work resumes. Deletion offers export first, invokes adapter cleanup for bound provider sessions, reports incomplete cleanup honestly, and never claims to delete exports, backups, macOS copies, or independently retained provider data.

## Accessibility Floor

Product baseline: relevant EN 301 549 software requirements, WCAG 2.2 Level AA, and native macOS accessibility behavior. This is a product conformance target; legal applicability is separate.

- Full keyboard access for every control, surface, proposal action, Inspector, Project Map function, and recovery flow; no keyboard trap.
- VoiceOver names role, title, state, artifact type, relationship meaning, actionable count, Online/Offline boundary, and provider action. Dynamic changes are announced without interrupting reading unnecessarily.
- Focus order follows visual/reading order, survives sidebar collapse and reflow, and returns to the invoking element after dismissal.
- Visible focus meets the contrast target in `DESIGN.md`; hover never carries exclusive information.
- Meaning never relies on color, sound, position, or motion alone. Status uses text plus icon/shape/line style where needed.
- Native text scaling/accessibility sizes and Dutch expansion must not truncate essential labels, state, provider disclosure, or canonical effects. Content may reflow and secondary rails may stack.
- Reduce Motion, Increase Contrast, and relevant system settings override theme/motion preferences immediately.
- Project Map provides an equivalent structured outline/relationship list with the same understanding and actions; canvas zoom/pan cannot trap focus or assistive technology.
- Pile Cover supplies a localized legend and full-sentence accessibility label computed from its actual governing/superseded Decision, unresolved Question, and actionable proposal-set counts. Internal marks are not focus targets.
- Streaming/progress avoids rapid announcements; named phase changes are announced. No flashing. Attention animation is limited to one at a time.
- Errors identify the failed boundary and recovery action in text. Destructive and canonical confirmation explains effects before activation.
- Accessibility is acceptance criteria for reusable components and every state, not a later audit overlay.

## Responsive & Platform

ProjectOS is native macOS only in MVP. “Responsive” means adapting within resizable desktop windows and accessibility text sizes, not creating web/mobile breakpoints.

| Window condition | Behavior |
|---|---|
| Comfortable width | Project Sidebar + primary content; Overview split masthead; Conversation list/transcript/rail; Project Map canvas/outline + Inspector. |
| Narrow window | Sidebar may collapse; secondary Overview rail stacks; Conversation List or Proposal Rail becomes a recoverable pane/Inspector; no loss of status or approval effects. |
| Large text / Dutch expansion | Controls and cards grow vertically; labels wrap; rails stack earlier; essential copy does not ellipsize. |
| Full screen / multiple windows | Width persists per window; each window restores its project, destination, selection, and local draft independently where practical. |

No mobile capture, touch-specific interaction, hosted sync, or embedded provider-authentication implementation is specified for MVP. macOS menus expose shortcuts; provider adapters or runtimes own their credentials and use macOS-appropriate secure storage; Notification Center and Focus govern system notifications; Finder integration supports Reveal/Open export actions.

## Inspiration & Anti-patterns

- **Lifted from the supplied [Overview reference](imports/overview-referenced.html):** substantial project identity/cover on the left, a focused action region on the right, quiet metadata, narrative primary content, and compact contextual rail. The profile-heavy sidebar, horizontal tabs, manual cover action, and generic “while away” duplication were not adopted.
- **Selected from [reference-derived directions](.working/design-directions-2.html):** Reference Focused masthead + Reference Relational primary content. Reference Baseline was too duplicative; Reference Dense over-emphasized scanning/ledger behavior.
- **Earlier comparison record:** [Quiet Ledger, Operational Desk, Guided Focus, and Context Atlas](.working/design-directions-1.html) established the density and continuity range. The chosen direction retains editorial calm and relational context without becoming graph-first or PM-like.
- **Governing key-screen studies:** [selected Overview states](.working/design-direction-selected.html) and [Project Sidebar states](.working/sidebar-direction.html). Their later memlog overrides—Pile Cover, no horizontal tabs, no avatar/permanent Add Project—govern.
- **Governing cover concept:** [Pile Cover handoff](imports/pile-cover-handoff.md), reconciled by later decisions to omit milestone capstones, custom/user photos, per-mark interaction, and any decorative or AI-generated cover path.
- **Governing proposal behavior:** [proposal-review wireframe](.working/flow-proposal-review-2026-07-29.excalidraw).
- **Governing relationship behavior:** [Project Map interaction companion](../../../../docs/mockups/project-overview/project-map-interactions.md) and [semantic map concept](../../../../docs/mockups/project-overview/02-semantic-map.png), corrected to canonical vocabulary and MVP inclusion.
- **Rejected — generic AI memory/chat-with-files positioning:** ProjectOS exposes accepted truth, lineage, uncertainty, and explicit approval rather than an opaque memory layer.
- **Rejected — configurable PM workspace:** no Kanban lanes, arbitrary schemas, priority matrices, assignee/team controls, percentages, nested Topics, or routine manual administration.
- **Rejected — engagement design:** no streaks, inactivity reminders, celebratory effects, badge inflation, automatic recap nudges, or optimization for time in app/message count.
- **Rejected — autonomous consequential mutation:** agent output remains proposed until explicit review; graph/notification/command shortcuts never bypass governance.
- **Rejected — theme/cover novelty:** no arbitrary color editor, fonts, logos, subject imagery, AI image generation, cover picker, random physics, or project-specific visual grammar.

## Key Flows

### UJ-1. Wouter starts a consequential project and establishes trusted state.

1. Wouter opens Project Library and selects New Project, then writes a short project description.
2. ProjectOS creates the project locally and offers a guided kickoff Conversation or direct entry to Overview.
3. Wouter chooses kickoff. Context Preview names Codex and OpenAI, the new-project description, empty Canonical State, project working language, and shared plan-allowance use; he explicitly starts.
4. The agent uses known context and asks focused goal/scope questions without asking Wouter to repeat the description.
5. The response creates a named proposal set containing one or more proposed Topics; later Conversations or imported Source Material may produce Research, Decisions, Open Questions, Tasks, and relationship changes.
6. Wouter opens each Change Proposal Card, inspects value, effects, dependencies, and exact source turn, then accepts, edits and accepts, rejects, or defers.
7. **Climax:** accepted Topics and any other reviewed changes appear as versioned Canonical State with rationale/provenance; the proposal history still links to the generating Conversation.

Failure/recovery: if OpenAI is not configured, setup opens and returns to the kickoff action. Offline or provider failure preserves the project and draft, makes send unavailable, and never queues it. If acceptance fails, the atomic transaction rolls back and the last coherent state remains.

### UJ-2. Wouter changes a decision without losing why it changed.

1. Wouter opens new Research or a Project Map relationship that contradicts a Governing Decision.
2. He starts a grounded Conversation after Context Preview includes the governing Decision, contrary evidence, rationale, provenance, relevant changes, and affected dependencies.
3. The agent creates a dependency-ordered replacement proposal set and explicitly identifies the Decision it may supersede.
4. Wouter opens Proposal Inspector, compares old/new rationale, alternatives, evidence, effects, and dependents; he may edit, causing affected dependents to return to Needs review.
5. He explicitly accepts the valid atomic group.
6. **Climax:** exactly one new Governing Decision is visible; the prior Decision remains Superseded in place, fully inspectable with its rationale, evidence, source turn, supersession reason, and links to the replacement.

Failure/recovery: rejecting the replacement leaves Canonical State unchanged and blocks hard dependents without rejecting them. A failed transaction rolls back in full. Reconsidering a Superseded Decision later creates another proposed governing version; it never toggles history back to current.

### UJ-3. Wouter resumes after a meaningful absence.

1. Wouter opens an existing Project Card after time away; ProjectOS lands on Overview without contacting OpenAI.
2. Pile Cover and Relational Briefing provide local orientation. If a persisted recap/recommendation matches Canonical State, it is immediately available; otherwise What's Up Next Card says Needs recap.
3. When needed, Wouter explicitly selects Generate recap after Context Preview; ProjectOS creates historical Recap and future What's up next against the same state version.
4. Wouter inspects recent accepted history, governing state, unanswered Questions, affected Tasks, rationale, and provenance without rereading the full Transcript.
5. He inspects or dismisses the explained recommendation. If he selects Continue work, ProjectOS transitions to Conversation and automatically starts the specifically grounded agent call authorized by that selection.
6. **Climax:** the Conversation opens on the recommended Open Question or Task with recap/recommendation context already present, and Wouter begins Meaningful Work without rebuilding the project mental model.

Failure/recovery: offline with a matching saved return point keeps orientation and inspection available while Continue is disabled. Without a current recap, local Canonical State still supports re-entry. Conflicting evidence yields an explicitly uncertain recommendation. Any canonical change invalidates the saved pair immediately.

### UJ-4. Wouter verifies ownership and recoverability.

1. Wouter opens Project Settings and selects Export.
2. Export preview lists included project data, excluded credentials/global data, destination, human-readable structure, and sensitive-storage warning.
3. He starts the atomic export and, on completion, chooses Reveal in Finder, Open README, and Verify export.
4. Project Library → Restore reads the package without mutation and previews identity, date, schema/version, counts, migrations, missing/corrupt content, and conflicts; new project copy is the default.
5. Wouter confirms. ProjectOS restores atomically, then compares manifest/checksums/counts/relationships and representative provenance.
6. **Climax:** the restored Overview matches Canonical State/history/provenance and the manifest comparison reads Verified, proving ownership without a hosted service.

Failure/recovery: export cancel/failure leaves the source unchanged and no partial package valid. Restore corruption or migration failure blocks commit or rolls back completely. Missing evidence is disclosed, never fabricated. Verification mismatch deep-links the discrepancy.

### Key Flow — First launch (Wouter)

1. Wouter opens ProjectOS for the first time; interface language follows supported macOS English/Dutch or falls back to English.
2. A short, skippable privacy orientation states: project data is local; no ProjectOS account is required; selected context reaches the configured provider only after explicit action; an eligible provider account or runtime may be required for AI.
3. ProjectOS checks for a compatible Codex Runtime. Wouter selects Continue with ChatGPT, completes the Codex-managed browser flow, and returns to ProjectOS. ProjectOS displays the resulting account, plan, and allowance status but never receives or displays tokens; Continue without AI remains available.
4. Readiness summarizes language, local-first storage, provider/runtime status, Follow macOS, and Studio Paper.
5. **Climax:** empty Project Library opens with Create your first project; Wouter is ready without an account, tour, sample project, theme decision, notification prompt, or workspace setup.

Failure/recovery: missing or incompatible runtime, cancelled or expired browser sign-in, optional device-code recovery when the runtime supports it, ineligible plan, unavailable service, rate limit, and exhausted allowance have distinct remedies. None offers API-credit purchase or automatic API-key fallback. Skipping AI leaves local creation/import/browse/edit/export/restore fully usable; a future provider action returns to setup and then to the interrupted action.

### Key Flow — Create a Project (Wouter)

1. From Project Library or `⇧⌘N`, Wouter selects New Project.
2. He enters a short description of what he wants to do.
3. ProjectOS creates the local project and its deterministic bare-ground Pile Cover.
4. The success surface prominently offers guided kickoff Conversation and secondarily Open Overview.
5. **Climax:** Wouter chooses kickoff and sees a Context Preview already grounded in the description and new-project state; he does not need to reconstruct or repeat the starting context.

Failure/recovery: a local creation failure preserves the description and explains storage recovery. Offline creation succeeds locally; kickoff is visibly unavailable until Wouter reconnects and explicitly resumes. Choosing Overview does not call the provider.

## Open items for Finalize

- Define the exact supported MVP Source file formats and extraction limits before implementation claims them.
- Resolve Project Map's compact-preview promotion threshold, default context neighborhood, stale/weak relationship representation, time comparison, and Conversation-node resume/follow-up/provenance distinctions.
- Replace obsolete continuity-line cover imagery in selected key-screen HTML with the governing Pile Cover before promotion.
- Validate the shared provider setup shell with the Codex adapter's runtime detection, ChatGPT browser and device-code flows, account/plan state, capability disclosure, allowance/reset state, sign-out, and provider-session cleanup; confirm that a fake or local adapter can contribute different fields without changing the core journey.
- Validate all five light/dark theme contrast pairs, native focus/destructive mappings, Dutch large-text reflow, VoiceOver order, and Project Map outline equivalence during the opt-in reviewer gate or implementation acceptance work.
