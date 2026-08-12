---
name: ProjectOS
status: final
sources:
  - _bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/prd.md
  - _bmad-output/planning-artifacts/prds/prd-ProjectOS-2026-07-28/addendum.md
  - _bmad-output/planning-artifacts/briefs/brief-ProjectOS-2026-07-27/brief.md
  - _bmad-output/planning-artifacts/research/market-projectos-market-opportunity-research-2026-07-27.md
  - _bmad-output/planning-artifacts/architecture/architecture-ProjectOS-2026-07-31/ARCHITECTURE-SPINE.md
updated: 2026-08-09
---

# ProjectOS — Experience Spine

## Foundation

ProjectOS is a single-owner, local-first native macOS application for a commercial consumer MVP. Canonical project data, Conversations, proposals, Sources, history, settings, and exports live on the Mac. MVP has no ProjectOS account, hosted content backend, collaboration, shared state, web/mobile client, or cross-device sync.

Native macOS conventions govern windows, menus, Settings, focus, undo/redo, text editing, notifications, appearance, and accessibility. The implementation may use SwiftUI, AppKit, or both; this contract requires native behavior, not a specific toolkit. [`DESIGN.md`](DESIGN.md) owns visual identity and shared component tokens; this spine owns behavior, states, navigation, and flows.

The product contract is human-governed semantic continuity:

1. Conversation or selected Source Material supplies evidence and context.
2. The explicitly selected Ollama, LM Studio, MLX, or OpenRouter adapter may generate typed Change Proposals.
3. Proposals persist separately from the Transcript and never become Canonical State automatically.
4. Wouter explicitly accepts, edits and accepts, rejects, defers, or requests revision.
5. Accepted changes are atomic, versioned, related, and traceable to exact provenance when available.
6. Overview restores current understanding; Project Map explains relationships; Conversation continues the work.

Opening, browsing, selecting, filtering, searching, importing/extracting locally, or navigating never authorizes inference. Only an explicit action after Context Preview authorizes generation. The MVP is local-inference-first: Ollama, LM Studio, and MLX are first-class local choices, and OpenRouter is the only optional external adapter. The active adapter and model are explicit. ProjectOS never silently switches, retries through, or falls back to another runtime, provider, or model. OpenRouter requires a Keychain-backed API key; direct OpenAI, Anthropic, and Codex integrations do not appear in MVP UX.

## Information Architecture

App open lands on Project Library; entering a project lands on Overview. Project Sidebar groups Orientation (Overview, Project Map), Active work (Conversation, Topics, Tasks), and Accepted knowledge (Decisions, Research, Questions). Research contains Research and Sources. Footer destinations are persistent Offline status when applicable, Notification Center, Project Settings, and Global Settings. The shell has no avatar/account row, permanent Add Project action, horizontal artifact tabs, or standalone ProjectOS brand mark.

| Surface | Reached from | Purpose and primary content |
|---|---|---|
| First Run | First launch | Skippable language/privacy orientation, local-first Ollama/LM Studio detection, explicit MLX setup, optional OpenRouter setup, runtime/model selection, readiness; then Project Library. |
| [Project Library](mockups/project-library.html) | App open, All Projects, restore completion | Project Cards, New Project, Restore, and an app-level cleanup item only when a declared persistent provider session remains outstanding. Cards contain Pile Cover and title only. |
| New Project | Project Library / `⇧⌘N` | Short description, local creation, then guided Conversation, Import existing material, or Overview. |
| [Overview](mockups/overview.html) | Project Card, project switch, `⌘1` | Pile Cover, What's Up Next Card, read-only project description, accepted history/relationships/affected work/provenance. |
| [Project Map](mockups/project-map.html) | Sidebar / Overview Pile Cover / `⌘2` | Current graph or synchronized relationship outline, lenses, selection, Inspectors, history/proposal layers, Context Preview. |
| [Conversation](mockups/conversation-proposals.html) | Sidebar / recommendation / grounded action / `⌘3` | Conversation List, Transcript, Composer, Context Preview, Proposal Rail and Proposal Inspector. |
| Topics | Sidebar / `⌘4` | Flat enduring work/inquiry areas; detail through Artifact Inspector. |
| Tasks | Sidebar / `⌘5` | Concrete actions, blockers/effects; detail through Artifact Inspector. |
| Decisions | Sidebar / `⌘6` | Governing-first list; Superseded history on demand. |
| Research | Sidebar / `⌘7` | Accepted Research and Sources subviews; Artifact or Source Inspector. |
| Questions | Sidebar / `⌘8` | Open states first; Resolved/Dismissed history on demand. |
| Notification Center | Sidebar footer | Durable, grouped, actionable/background events with exact-context deep links. |
| Project Settings | Sidebar footer | Identity, read/write description, theme/language/notification inheritance, export/verify, archive/delete, and any declared provider-session cleanup status. |
| Global Settings | Sidebar footer / `⌘,` | General, Appearance, AI Providers, Notifications, Accessibility and Keyboard, Data and Recovery, About. AI Providers groups Ollama, LM Studio, MLX, and OpenRouter with explicit active runtime/model and readiness. |
| Export and Verification | Project Settings | Scope preview, atomic export, completion actions, manifest verification. |
| Restore Preflight | Project Library | Read-only inspection, compatibility/migration/corruption disclosure, new-copy restore and verification. |
| Return Outcome Record | UJ-3 completion prompt / Project Settings | Validation-only local record of elapsed return time, understanding, trust, Next Action usefulness, Meaningful Work, and optional notes; included in export. |
| Provider Cleanup | Project Library cleanup item / Global Settings → Data and Recovery | Conditional app-level list of content-free cleanup receipts only for adapters that declare and use persistent external sessions; explicit retry and confirmed/already-absent history. |
| Command Palette | `⌘K` | Search projects/commands and start safe actions without bypassing review. |
| Accessibility and Keyboard Help | Help menu / Global Settings | Accessible English/Dutch feature documentation, shortcuts, Project Map outline, system preferences, known limitations, feedback route. |

The four linked key-screen mockups illustrate the load-bearing Library, Overview, Conversation/proposal, and Project Map layouts. Project Map is further supported by the [semantic map concept](../../../../docs/mockups/project-overview/02-semantic-map.png) and [interaction companion](../../../../docs/mockups/project-overview/project-map-interactions.md); **Research/Sources** replaces the concept visual's obsolete “Evidence” type.

### Artifact contracts

| Artifact | Canonical meaning | Required fields and states | Type-aware actions |
|---|---|---|---|
| Topic | Enduring area of inquiry/work; flat in MVP. | Title, purpose/scope, related artifacts/Conversations, provenance/history; Current/retired. | Grounded Conversation, inspect, edit, propose split/merge, retire without erasure. |
| Task | Concrete project-advancing action. | Title, outcome, why, actor, Open/In progress/Blocked/Done, relations, provenance/history, optional factual deadline/completion evidence. | Change status, add evidence, inspect blockers, grounded Conversation, edit/defer/dismiss. |
| Decision | Explicit governing commitment; never tentative. | Statement, Governing/Superseded, rationale, alternatives, implications, conditions/revisit trigger, effective date, actor, evidence, origins, relations, versions. | Inspect lineage/effects, compare, correct, replace, reconsider; withdrawal/replacement record required. |
| Research | Accepted evidence-backed synthesis, not raw Source Material. | Finding/scope, evidence links, interpretation, certainty, contradictions/limitations, date, relations, provenance/history; Current/Tentative/Contested/Superseded. | Inspect evidence, compare contradiction, grounded Conversation, correct/supersede. |
| Open Question | Decision-relevant answerable uncertainty. | Question, why, resolution criteria, impact/blocking relations, Open/In exploration/Awaiting evidence/Resolved/Dismissed, evidence/history, resulting Decision. | Grounded Conversation, answer directly, inspect blockers/evidence, evidence Task, dismiss. |
| Conversation | Working context and provenance, not Canonical State. | Local title, messages, scope, language, non-secret adapter/model metadata, proposal anchors, linked artifacts/proposals. | Resume after fresh preview, search/filter, follow-up, inspect resulting state. |
| Source Material | Original retained evidence distinct from Research. | Original, extraction, metadata, known/unknown language, extraction state, usage history, linked artifacts/Conversations. | Inspect, add to Context Preview, navigate passage, remove after effects disclosure. |

Direct user artifact changes become versioned Canonical State immediately with Undo where permitted. Removing an Artifact from current Canonical State is a deliberate accepted transition: its prior version and removal remain inspectable until the whole Project is permanently deleted. Agent changes always enter Proposal Rail. Directly answering an Open Question creates a linked Decision and preserves the Question as Resolved history; a conversational answer leaves it unresolved until its Decision proposal is accepted. Completing a Task invalidates state-bound return outputs but never silently resolves a Question or creates a Decision.

### Source intake matrix

| Input | MVP limit | Local extraction behavior |
|---|---|---|
| Pasted text | 250,000 characters | Retain exact pasted original; extract as text. |
| `.txt`, `.md` | 10 MB each | Retain original file; extract text locally. |
| Searchable/selectable-text `.pdf` | 50 MB or 500 pages, whichever is reached first | Retain original; extract text locally with page anchors. |
| Batch | 25 Sources | Preflight count/type/size before extraction; explain every rejected item. |
| Scanned PDF | Same PDF file limits | Retain original as **Needs OCR**; MVP performs no OCR and never claims extraction. |
| Encrypted PDF | Same PDF file limits | Retain original as **Needs password**; no extraction until a supported local unlock path succeeds. |

DOCX, RTF, HTML, images, archives, and structured chat-export importers are after MVP. Originals are always retained locally. Import/extraction alone never invokes inference and never creates Research or Canonical State.

## Voice and Tone

Microcopy is calm, concise, inspectable, and literal. Brand posture lives in `DESIGN.md.Brand & Style`.

| Do | Don't |
|---|---|
| “Saved on this Mac.” | “Secure forever.” |
| “Runs locally with MLX using Llama 3. Selected Project context stays on this Mac.” | “Ask AI” without adapter/model/scope disclosure. |
| “This sends 3 selected excerpts to OpenRouter using the selected model. External usage charges may apply.” | “Cloud model” without provider, scope, or billing disclosure. |
| “Network offline. Local inference remains available; OpenRouter is unavailable.” | “Connection error” for every boundary. |
| “Needs review” / “Accepted with edits” / “Superseded” | “Done” for semantically distinct states. |
| “Exact source moment unavailable. Opened the originating Conversation.” | Silently open an approximation. |
| “Needs OCR” / “Needs password” / “Unsupported format” | Present unextracted content as parsed. |
| “No matches.” / “No Decisions yet.” | Cheerleading, streaks, engagement nudges, or exclamation marks. |

English/Dutch keep the same hierarchy and shortcuts. UI locale is exposed through native localization/accessibility metadata. Known-language original excerpts, quotes, translations, and Transcript runs expose their language where the toolkit supports attributed-language runs; unknown language is never guessed. User-authored/original content is never silently translated or rewritten.

## Component Patterns

Visual specifications live in `DESIGN.md.Components`. These exact shared names are the reusable product vocabulary.

| Component | Behavioral contract |
|---|---|
| Button | Primary, secondary, ghost, destructive, disabled. Disabled provider actions remain visible with persistent associated reason and an enabled setup/reconnect/Why unavailable route. |
| Status Badge | Names state in text and accessibility state. Counts only actionable proposals/blocked work/actionable unread notifications. Interactive only when explicitly a filter. |
| Project Sidebar | Resizable/collapsible; width per window. Pointer drag plus keyboard/menu step controls and Reset Width. Active destination, badges, Offline row, labels/tooltips survive collapse. |
| Project Switcher | Opens local project selection/New Project. Switching restores Overview locally and never invokes inference. |
| Project Card | Entire card opens Overview. One focus target; internal pile marks are not targets. |
| Pile Cover | Project Card use is passive; Overview exposes one action named “Open Project Map,” with localized composition as description/value. Legend and drawing share counts; internal marks/duplicate legend subtree are hidden from accessibility traversal. |
| What's Up Next Card | Needs recap, Current, Offline. Generate is explicit; Continue authorizes the grounded call by selection; Inspect is local; dismissal does not mutate Canonical State. Content drives height and stacks with Pile Cover when required. |
| Relational Briefing | Locally available orientation. Description is read-only; edit routes to Project Settings. Summaries link to accepted detail, provenance, or history. |
| Conversation List | Recency order, local search/Topic filter/editable title. Selection restores draft, scroll, and review position. |
| Transcript | Streams readable chunks; auto-scroll only near tail. Stop preserves Incomplete content. Exact provenance turns restore/focus when possible. |
| Composer | Persisted multiline draft; `⌘Return` sends, `⇧Return` newline, `Esc` preserves text. Send requires Context Preview. OpenRouter is unavailable offline without queueing; a ready local adapter may remain available. |
| Context Preview | Before every inference call: active Ollama, LM Studio, MLX, or OpenRouter adapter and model; local/external boundary; scope; one-hop Map context when relevant; Sources/excerpts; language; capability limits; and OpenRouter billing disclosure. Wouter can narrow/add explicit items. |
| Proposal Rail | Current-Conversation by default, project-wide pending optional. Persists independently and supports every proposal status/history. |
| Change Proposal Card | Type, operation, summary, source, set/dependency, status; opens Inspector and exact source turn; never bypasses effects review. |
| Proposal Inspector | Shared type-aware frame. Edit persists a draft; accept is explicit/atomic; compatible-set only when proven; rejection is recoverable; revise requires a new call. |
| Artifact Row | Opens Artifact Inspector; current state default, historical never styled as governing; direct changes follow artifact Undo/version rule. |
| Artifact Inspector | Current accepted information first, history on demand, provenance, relations, type-aware local/provider actions. |
| Relationship Inspector | Meaning, rationale, provenance, state, endpoints/effects, and local/provider actions; multi-selection scope remains visible. |
| Project Map | Canvas and outline synchronize lenses, filters, selection, multi-selection, Inspectors, and actions. Selection/filtering is local. Current graph is primary; historical/proposed layers are inspectable; no temporal animation or Overview graph preview. |
| Source Inspector | Original/extraction/metadata/language/usage/links and Complete/Partial/Failed/Needs OCR/Needs password. Removal explains effects and prior transmission. |
| Notification Center | Durable grouped items retain read/action state and exact-context deep links. Opening is local and never accepts/rejects. |
| Progress Indicator | Named phases; determinate only when measurable; Stop/Cancel when safe. Completion/failure replaces progress and leaves persistent result elsewhere. |
| Empty State | Explains why and offers shortest relevant action; never fabricates samples or requires AI for local creation. |
| Settings Row | Shows inherited global values and reset with Undo. Local unless explicitly testing a runtime/adapter, changing a Keychain credential, or opening System Settings. |
| Confirmation Sheet | Permanent deletion, governing Decision replacement/withdrawal, credential removal, shared MLX storage removal, and high-impact actions; names effects, recovery limits, safe cancel. Project deletion offers export first and distinguishes local deletion from credential, runtime/model data, and any declared session-cleanup outcomes. |
| Command Palette | `⌘K` searches projects/commands. Navigation complete; no direct proposal accept/reject or confirmation bypass. |
| Search Field | `⌘F` current surface; `⌘G`/`⇧⌘G` moves matches; announces scope/count; clearing restores prior selection where practical. |

The approved proposal-review anatomy is in the [Conversation and proposal review wireframe](wireframes/proposal-review.excalidraw); the [high-fidelity Conversation mockup](mockups/conversation-proposals.html) shows the same source-linked review rail in the selected visual system.

## State Patterns

### Global state model

| State | Treatment |
|---|---|
| Cold local load | Restore shell/selection first; layout-preserving local placeholders only. Failure identifies affected local store and preserves last coherent state. |
| Local adapter ready | Local actions remain available; inference still requires explicit preview/start with the selected runtime/model. |
| Local runtime/model unavailable | Preserve local work/drafts; distinguish missing, stopped, incompatible, unavailable model, model-format, and insufficient-resource states with a setup/retry path. |
| Network offline | Persistent Sidebar text/state. Local work and a ready Ollama, LM Studio, or MLX adapter remain available; OpenRouter remains visible but disabled. Nothing queues or reroutes. |
| Provider in progress/interrupted | Truthful phases and safe Stop; navigation preserves work. Partial output remains Incomplete and cannot become trusted Research/proposal. |
| OpenRouter configuration/credential/rate/quota/billing/service failure | Distinct diagnosis, retained draft/partial output, relevant setup/reset/retry. Never generic Offline, automatic credit purchase, or local fallback. |
| Canonical transaction pending/failed | Effects visible; no mutation until explicit atomic acceptance. Failure fully rolls back to last coherent state. |
| Focus | Visible native focus; no unexpected movement. Dynamic fallback: retained origin, next item, previous item, then relevant heading/empty state. |
| Permission denied | Local work remains; notification denial has route to System Settings and no repeated prompts. |
| Declared provider cleanup pending | Only adapters using persistent external sessions create cleanup receipts. Local Project deletion remains truthful while a content-free receipt exposes adapter context, residual-data disclosure, retry state, and completion without restoring Project content. |

Status is persistent where it changes capability, trust, or outcome: Offline, provider unavailability, Incomplete output, extraction failure, canonical result, export/restore result, and verification result remain in their affected surface/history. Transient banners or announcements supplement but never become the sole record.

### Surface coverage

| Surface | Required states |
|---|---|
| First Run | Fresh/skipped, EN/NL, Ollama/LM Studio absent/stopped/incompatible, MLX setup/model/resource states, OpenRouter unconfigured/key test/rate/quota/billing/service error, explicit adapter/model selection, ready with/without inference. |
| Project Library | Cold/empty/populated, search/no matches, unavailable/corrupt project, offline, restore running/succeeded/failed, app-level provider cleanup pending/failed. |
| New Project | Empty/valid description, create progress/failure, created start choices, offline. |
| Overview | Needs recap, generating, current pair, recap closed, revisit, dismissed/uncertain recommendation, offline with/without current pair, local read failure, masthead stacked. |
| Project Map | Empty/current, Focus, lens/no matches, node/relationship/multi-select, proposal/history layers, missing provenance, offline, outline, layout error, Conversation provenance node. |
| Conversation | Empty/restored/draft, sending/streaming/stopped/Incomplete, proposal ready, local runtime/model/resource failure, offline OpenRouter, OpenRouter credential/rate/quota/billing/service failure, anchor found/unavailable, search/no matches. |
| Topics | Empty/current/retired, selected, direct edit/Undo, proposed split/merge, offline/local failure. |
| Tasks | Empty, Open/In progress/Blocked/Done, deadline/reminder, completion/Undo, history, offline/local failure. |
| Decisions | Empty, Governing/Superseded, replacement/correction/withdrawal, missing provenance, offline/local failure. |
| Research | Empty, Current/Tentative/Contested/Superseded, contradiction, missing evidence/Needs review, Sources, offline/local failure. |
| Questions | Empty, Open/In exploration/Awaiting evidence/Resolved/Dismissed, blocking, direct answer, pending Decision proposal, offline/local failure. |
| Notification Center | Empty, actionable unread, informational read, grouped/evolving, adapter/model readiness, optional declared provider cleanup pending/failed/confirmed, deep-link fallback, offline, permission denied. |
| Project Settings | Inherited/override/reset/Undo, description edit, export, archive/delete, delete confirmation, local deletion complete, ProjectOS-managed MLX Project data removal, optional declared provider cleanup, offline. |
| Global Settings | Appearance/presets; Ollama/LM Studio runtime and model states; MLX model/resource/storage states; OpenRouter unconfigured/key-testing/ready/error/usage states; active adapter/model; notifications; system accessibility change; data warning; optional declared provider cleanup. |
| Export and Verification | Preview/conflict, progress/cancel/fail/complete, verify/Verified/mismatch/corrupt. |
| Restore Preflight | Reading/compatible/migration/corrupt/missing/conflict, cancel, atomic restore/rollback, unverified/Verified. |
| Return Outcome Record | Prompted/deferred, elapsed timer available/unavailable, unsaved draft, saved locally, export included, local save failure/retry, offline. |
| Provider Cleanup | Hidden when no adapter uses persistent sessions; otherwise empty, pending, retrying, failed, confirmed, already absent, offline, and startup reconciliation. |
| Command Palette | Closed/open/query/result/no matches/disabled-with-reason/focus restored. |
| Accessibility and Keyboard Help | EN/NL, keyboard-only, accessible document loaded/unavailable, external feedback route unavailable. |

### Generated return-point lifecycle

One explicit Generate recap action creates historical Recap and future What's up next against the same Canonical-State version. Closing Recap hides it for the visit only; it returns on a later visit while version still matches. Any canonical change invalidates both immediately. A matching saved pair remains readable offline; provider generation/continuation does not.

### Change Proposal lifecycle

Proposals from one response form a dependency-ordered set. Independent members can be reviewed separately; hard dependencies accept atomically. Accept compatible set appears only when proven and preceded by combined effects. Editing revalidates dependents; rejection blocks dependents without rejecting them. Accepted with edits preserves original/final/diff/timestamp/source/note/set/dependencies/resulting version. Every status links to the originating Conversation and exact generating moment where recoverable.

### Source intake lifecycle

Add Source is available from Research, Conversation context selection, setup, and relevant empty states. Preflight applies the committed matrix before any extraction. Import, retention, extraction, inspection, and errors are local. Complete/Partial/Failed/Needs OCR/Needs password never alter the original. After inspection, Wouter may explicitly choose Synthesize; Context Preview exposes selected Sources/excerpts, language, one-hop relationships if applicable, and the active adapter/model plus its local or external boundary. Generated Topics, Research, Questions, Decisions, Tasks, and relationships enter Proposal Rail.

### Project Map contract

- Default is current accepted state. Historical and Proposed are explicit layers; animated/time-comparison views and compact Overview graph preview are after MVP.
- Focus mode emphasizes selection and immediate neighbors. Provider Context Preview includes selection plus directly connected current accepted artifacts only. Historical/Proposed require explicit selection; two-hop items are never automatic. Large neighborhoods summarize with controls to narrow/add.
- Relationship states are **Current**, **Needs review**, **Historical**, **Proposed**. Age never weakens a relationship. Needs review requires superseded/retired endpoint, unavailable retained evidence, or explicit contradiction; it stays canonical until reviewed. Historical is explicitly superseded/removed. Proposed is isolated from accepted state.
- Conversations are provenance nodes, hidden by default and shown through Provenance lens or a linked artifact. Open is local. Resume requires fresh current-state Context Preview; Start follow-up creates a new linked Conversation grounded in the selected moment.
- The non-spatial equivalent is an expandable artifact outline in stable type-and-title order. Expanding shows Incoming and Outgoing groups; each relationship names meaning, other endpoint, and state. Canvas/outline synchronize lenses, filters, selection, multi-selection, Inspector, and actions.

## Interaction Primitives

### Keyboard model

All commands have visible menu/control equivalents and identical EN/NL bindings. No custom or unmodified/Vim sequences in MVP.

| Shortcut | Action |
|---|---|
| `⌘K` | Command Palette / global search |
| `⌘F`; `⌘G` / `⇧⌘G` | Current-surface search; next/previous match |
| `⌘,` | Global Settings |
| `⌘N`; `⇧⌘N` | New Conversation; New Project |
| `⌘1` … `⌘8` | Overview, Project Map, Conversation, Topics, Tasks, Decisions, Research, Questions |
| `⌘[` / `⌘]` | Back/forward local history |
| `⌥⌘S` | Toggle Project Sidebar |
| `⌘.` | Stop active safe-to-stop operation |
| `⌘Return`; `⇧Return` | Send; newline |
| `Esc` | Close top layer/restore focus; never discard draft |
| `⌘S` | Persist draft only; never accept proposal |
| `⌘+` / `⌘-` / `⌘0` | Project Map zoom in/out/fit |

Proposal review has no global accept/reject shortcut. Outline arrows navigate/expand; Return opens Inspector; Shift extends selection. Every canvas action has outline/menu/click/keyboard alternative.

### Pointer, drag, target, and focus

- Every custom target is at least 24×24 points or documents the exact WCAG target-spacing/exception used. Native controls retain platform sizing and enlarged hit regions when needed.
- Sidebar resize supports drag, keyboard/menu steps, and Reset Width. Every app-interpreted drag has click and keyboard alternatives. Map pan/zoom has controls/shortcuts; selection never requires dragging.
- Sheets, inspectors, rails, sticky regions, and stacked layouts reveal/scroll the focused control so it is never fully obscured.
- Closing/removing/filtering uses fallback: retained origin, next in set, previous, then section heading/empty state. Pane transformation preserves logical selection. Incoming content never takes focus.
- Hover may preview but never reveal the only action. Double-click is never required for core work.

### Motion and continuity

Quick feedback uses 140 ms, navigation/pane continuity 220 ms, and deliberate accepted-state transitions 300 ms. Sidebar pointer resize is immediate. Overview content crossfades without fixing height; Transcript never pulls an older reading position; Proposal Cards relate visually to source turns; atomic acceptance appears as one transaction; Project Map preserves positions; provenance emphasis does not flash. Reduce Motion removes spatial movement/scaling/animated scrolling and uses immediate state changes or opacity-only 140 ms where continuity helps.

## Offline, Notifications, and External Boundaries

Every action computable from local state remains available. A configured local adapter may remain available without network access; OpenRouter-dependent work is unavailable offline and never silently queued or rerouted.

| Available offline | Unavailable offline |
|---|---|
| Project/library management including local deletion; all artifact/Source/Conversation/proposal/history browsing/search; Project Map/outline; local Source import/extraction; direct changes/Undo; proposal review; drafts; return-outcome recording; export/restore/verification; settings; local-operation notifications; Ollama, LM Studio, or MLX inference when the selected local runtime/model is ready. | OpenRouter send/continue; OpenRouter Recap/What's up next generation; OpenRouter proposal revision/synthesis; OpenRouter key/model/usage refresh; any external provider-session cleanup/retry. |

Reconnection of external generation work requires explicit Resume and fresh Context Preview. A declared provider cleanup retry is a separate lifecycle action and never resends Project content. Mid-request loss preserves Incomplete output. Network, runtime, model, resource, credential, rate, quota, billing, service, and capability errors remain distinct.

Notifications use three levels: inline routine feedback; durable Notification Center for actionable/background results; macOS notification only for user-initiated background work completing/failing/needing input while not frontmost. If a future adapter declares persistent external sessions, its pending cleanup uses one evolving app-level item and a content-free receipt; MVP adapters do not receive that UI by assumption. Events deduplicate. There are no engagement/inactivity/streak/promotion/automatic-recap notices. Permission is just-in-time; macOS Focus is authoritative.

## Theme, Language, Settings, and Ownership

Appearance precedence is macOS when Follow macOS → global preset → optional project identity preset → accessibility preferences. First use follows macOS with Studio Paper. Accessibility preferences always win and update live.

Interface language is global English/Dutch, defaulted from macOS. It localizes UI, menus, settings, notifications, dates/numbers/usage, and accessibility labels, never project content. Project working language defaults from UI language and governs future generation. Conversation can override; canonical proposals default to project language. Changes affect future generation only. Original text remains unchanged; translations are explicit, labeled, and reviewable.

Global Settings includes General, Appearance, AI Providers, Notifications, Accessibility and Keyboard, Data and Recovery, and About. AI Providers groups Ollama, LM Studio, MLX, and OpenRouter; shows explicit active adapter/model, runtime/model/resource capabilities, loopback state, secure OpenRouter setup, and no fallback control. Project Settings includes title, editable description, theme inheritance, working language, optional explicit adapter/model override, notification inheritance, export/verify, restore, archive/delete, and any declared cleanup status. No cover selector.

Export is atomic, offline, human-readable (README, Markdown, JSON, Sources, validation records, manifest/checksums) and excludes credentials/tokens/runtime caches/session bindings/unrelated globals. Restore preflights read-only and creates a new copy by default; migration/persistence is atomic with rollback; missing evidence is disclosed. Verification compares manifest and representative provenance.

Permanent Project deletion offers export first and confirms removal of local history, Sources, Conversations, validation records, and Project-scoped MLX caches. It does not uninstall Ollama or LM Studio, remove their shared models, remove the OpenRouter Keychain credential, delete shared MLX models/caches, or claim deletion of independent OpenRouter/routed-provider retention, backups, or user exports. Those are separate explicit storage, credential, or external-retention outcomes. A content-free cleanup receipt exists only when an adapter declares and uses a persistent external session; local deletion may complete while that obligation remains explicit and retryable without restoring or resending Project content.

## Accessibility Floor

Baseline: relevant EN 301 549 non-web software/documentation requirements, WCAG 2.2 AA outcomes translated to native macOS, and native accessibility interoperability. Legal applicability is separate.

### Shared accessibility-semantics matrix

Native controls/collections are default. Custom rendering exposes the listed delta through the macOS accessibility hierarchy. “24pt” means 24×24-point custom-target minimum unless a documented spacing/exception applies.

| Component | Native semantics; name/value/state/description | Grouping and available actions | Keyboard/focus and fallback | Announcement | Target/drag alternative |
|---|---|---|---|---|---|
| Button | Native button; visible label names it; disabled reason in description; pressed/busy state when applicable. | Group with reason/setup route; press action. | Tab/Space/Return; returns to origin or documented fallback. | Result announced only when not otherwise evident; persistent result remains. | 24pt; no drag. |
| Status Badge | Static text/status or toggle only when filter; state/value is full label/count. | Group with labeled subject; filter action only when interactive. | Skipped when static; filter follows button behavior. | State transition once. | 24pt if interactive; no drag. |
| Project Sidebar | Native outline/sidebar; destination name/current/badge/offline state. | Groups expose headings; select destination, collapse, resize steps/reset. | Reading-order arrows/Tab; collapse keeps active destination; fallback group heading. | Destination/offline changes once. | 24pt controls; drag resize has step/reset. |
| Project Switcher | Pop-up/menu button; project name/theme in value/description. | Menu of projects plus New Project. | Space/Return opens; Esc returns. | Project change once. | 24pt; no drag. |
| Project Card | One button/link; project title name, concise pile composition description. | Card children merged; open project. | Tab/Return; fallback grid neighbor/empty heading. | None on focus beyond name/value. | 24pt whole card; no drag. |
| Pile Cover | Overview: one button named Open Project Map, composition description/value. Card: merged into card description. | Internal marks and duplicate legend hidden; press on Overview. | Tab/Return; focus returns to cover after Map back. | Composition changes are not unsolicited; status elsewhere announces canonical change. | Whole cover target; no internal drag/targets. |
| What's Up Next Card | Group/region named What's up next; status, recommendation, provider reason are descriptions. | Contains ordinary Buttons/links; relationships label recommendation target. | Reading order; action fallback card heading. | Generation complete/fail/current invalidated once. | Child targets 24pt; no drag. |
| Relational Briefing | Labeled region with headings/lists/links; description marked read-only. | Sections related to project/history/provenance; open-detail actions. | Standard reading/link order; fallback section heading. | No unsolicited summary reading. | Links 24pt or exception spacing; no drag. |
| Conversation List | Native list; row name/title, proposal state/count, selected state. | Topic filter/search labels list; select/rename actions. | Arrows/Tab; fallback next/previous/list heading. | Selection not redundantly announced; new actionable state once. | Rows 24pt; no reorder drag. |
| Transcript | Native scrollable text/list; speaker/time/language/incomplete/proposal anchor. | Messages grouped by speaker/turn; open provenance, copy, navigate. | Reading order; incoming content never takes focus. | Follows bounded policy below; never tokens. | Actions 24pt; text selection native. |
| Composer | Native multiline text area; scope/provider/disabled reason described. | Labeled by Conversation; send/newline/stop actions. | `⌘Return`, `⇧Return`, Esc preserves; fallback Composer. | Send start once; failure/incomplete once. | Send 24pt; no drag. |
| Context Preview | Sheet/group; adapter, model, locality/external boundary, scope, excerpts, language, capability limits, and OpenRouter billing as labeled values. | Source/artifact relationships; add/remove/inspect/start/cancel. | Initial focus heading; close returns invoking action. | No auto-read; start once after action. | Controls 24pt; inclusion has click/keyboard alternative. |
| Proposal Rail | Landmark/split group with scope and proposal counts. | Contains list/cards; switch current/project-wide scope. | Pane entry/exit explicit; fallback rail heading. | Proposal-set readiness once. | Split resize if present gets steps/reset; cards 24pt. |
| Change Proposal Card | List row/button; type/operation/summary/source/set/status. | Related to source turn and set; open/navigate actions. | Arrows/Return; fallback next/previous/set heading. | Status change once, separately from focus. | Whole card 24pt; no drag. |
| Proposal Inspector | Inspector/sheet; title/status/proposed/original/effects/dependencies/diff. | Relationships programmatic; edit/accept/reject/defer/revise. | Initial heading; close/origin fallback; no mutation shortcut. | Acceptance/rejection/failure once; persistent audit. | Controls 24pt; no drag. |
| Artifact Row | Native list row; type/title/state/context. | Related artifact/history links; open/select. | Arrows/Return; fallback neighbor/heading. | Direct state change once. | Row 24pt; no reorder drag. |
| Artifact Inspector | Inspector; type/title/state/content/rationale/provenance/history. | Relationships exposed; local/provider actions distinguished. | Heading first; close returns origin/fallback. | Loaded silently; changes once. | Controls 24pt; no drag. |
| Relationship Inspector | Inspector; meaning/endpoints/state/rationale/provenance. | Incoming/outgoing/endpoints related; inspect/discuss/correct. | Heading first; return origin/fallback. | State change once. | Controls 24pt; no drag. |
| Project Map | Canvas is custom group; selected node/edge exposes type/title/state/meaning; outline is canonical AT route. | Canvas/outline/lenses/Inspector synchronized; select, extend, inspect, zoom, focus. | Outline stable type-title order; arrows/Return/Shift; fallback neighbor/group heading. | Lens/selection count once; no position chatter. | All controls 24pt; pan/zoom/select have buttons/shortcuts/outline. |
| Source Inspector | Inspector; title/type/size/language/extraction state/usage. | Original/extraction/passages/referrers; inspect/add/remove actions. | Heading first; close origin/fallback. | Extraction phase bounded; complete/fail/Needs state once. | Controls 24pt; drop has picker/paste alternatives. |
| Notification Center | Native list; item title/state/time/deep-link availability. | Group evolving events; mark read/open context. | Arrows/Return; fallback neighbor/empty heading. | System notification policy only; opening does not repeat. | Rows 24pt; no drag. |
| Progress Indicator | Native progress indicator/status; phase/value only if determinate. | Labeled by operation; Stop/Cancel related. | Not focusable unless control; focus stays on work. | Bounded phase/completion policy. | Controls 24pt; no drag. |
| Empty State | Labeled group/heading with explanation. | Primary/secondary actions grouped. | Focus first available action or heading. | Appears as surface status once. | Actions 24pt; no drag. |
| Settings Row | Native form row/control; label/value/inherited/override or cleanup state. | Description/error/help associated; change/reset or cleanup retry action. | Standard form order; fallback row/section heading. | Change/result once if not visible; cleanup status remains persistent. | Controls 24pt; sliders also keyboard steps/reset. |
| Confirmation Sheet | Native alert/sheet; action/effects/recovery description. | Destructive/default/cancel relationships. | Initial safe option; Esc cancel; returns origin/fallback. | Opening title only; local deletion and provider cleanup outcomes announced separately. | Controls 24pt; no drag. |
| Command Palette | Native search dialog/list; query/result count/selected/disabled reason. | Search field labels results; activate/navigate/help. | `⌘K`, arrows, Return, Esc origin. | Result count coalesced; no per-keystroke flood. | Rows/actions 24pt; no drag. |
| Search Field | Native search field; scope, query, result count. | Labels target result region; clear/next/previous. | `⌘F`, `⌘G`, `⇧⌘G`, Esc/clear restores selection. | Count coalesced after query pause. | Controls 24pt; no drag. |

### Return Outcome Record semantics

Return Outcome Record is a native labeled form/group, not a custom chart or timed interruption. Its accessible name is **Return outcome**. The read-only elapsed-time value is associated with its label; understanding, trust, Next Action usefulness, and Meaningful Work use individually labeled native controls with exposed values/states; optional notes use a labeled multiline field. Required-field and local-save errors are associated with the affected control and summarized at the form heading.

Initial focus lands on the heading only after Wouter explicitly opens the record; an automatic prompt never steals focus from Conversation. Tab order follows the visual field order, Save is last, Cancel/Defer preserves any draft, and close returns to the invoking control or the UJ-3 Conversation heading. Elapsed time is announced on entry and Save, never as a ticking live region. Save success/failure is announced once and remains visible; offline behavior is identical because the record is local. Native targets, enlargement, English/Dutch labels, VoiceOver/Voice Control/Switch Control, and deterministic fallback follow the shared accessibility floor.

Provider Cleanup appears only for an adapter that declares and uses persistent external sessions. It is a native app-level list/form composed from Settings Row and Button behavior. Each receipt is named from its adapter and deletion timestamp and exposes non-secret adapter context, lifecycle state, last attempt, retry count, residual-data warning, and retry action without retaining Project content or title. Focus never targets the deleted Project or a removed sidebar item; closing or resolving a receipt returns to the next receipt, previous receipt, then Provider Cleanup heading/empty state.

### Announcement policy

Never announce streaming tokens or every percentage. Announce provider start once; meaningful phase changes at bounded cadence; completion, failure, Incomplete output, proposal-set readiness, and Online/Offline boundary once. Routine updates queue behind current speech; interrupt only for immediate data-loss, privacy, or safety consequences. Incoming/background content never moves focus. If Wouter reads above Transcript tail, announce “New content available” once and let him choose when to move.

### macOS accessibility preference matrix

| Preference | Live behavior and precedence |
|---|---|
| Increase Contrast | Switch every load-bearing role to the explicit `-contrast` token branch; strengthen native boundaries; theme cannot override. |
| Differentiate Without Color | Add/retain text, icon, shape, hatch, dash, and line-style distinctions across statuses, Map, pile, selection. |
| Reduce Transparency | Replace translucent/material surfaces with opaque semantic surfaces without changing hierarchy. |
| Reduce Motion | Immediate state replacement or opacity-only 140 ms; no movement, scaling, animated scrolling, or automatic Map travel. |
| Invert Colors | Prefer native semantic rendering and exclude compatible user content only where platform behavior requires; custom Map/pile remains perceivable. |
| System text/enlargement and focus preferences | Reflow/wrap/stack without essential truncation; preserve focus/selection and use native focus/cursor behavior. |

Changes apply without restart and preserve focus, selection, meaning, and Canonical State. Every preset is tested Light/Dark with Increase Contrast and Differentiate Without Color.

### Release accessibility test matrix

| Mode | Required coverage |
|---|---|
| Full Keyboard Access | Complete First Run, both project-start paths, recap/continue, proposal review, Map journeys, export/restore, settings, offline recovery, delete. |
| VoiceOver | Hierarchy, reading, names/values/states/actions, focus fallback, announcements, language runs, Map outline parity, Pile single-target behavior. |
| Voice Control | Control names/actions available without hover or pointer precision. |
| Switch Control | Traversal/actions for every custom component and recovery path. |
| Visual/accessibility combinations | Five themes × Light/Dark × Increase Contrast/Differentiate Without Color; Reduce Transparency/Motion; supported text sizes; EN/NL; online/offline/provider errors. |
| Automation plus manual | Automated token contrast, accessibility hierarchy identifiers/roles, target sizing, localization and regression checks; manual AT, reflow, focus-obscuring, cognitive/error-prevention checks. |

Accessibility and Keyboard Help is keyboard/VoiceOver accessible in English/Dutch and documents shortcuts, Map outline, preferences, notifications, known limitations, and an accessibility feedback route.

## Responsive & Platform

MVP is native macOS only. Responsive means resizable windows and accessibility sizes, not web/mobile breakpoints. Comfortable width shows Sidebar + split masthead, three-region Conversation, and Map/outline + Inspector. When intrinsic content no longer fits, masthead stacks, secondary rails become recoverable panes, labels wrap, and cards grow. The implementation's minimum window is the smallest size at which the content-driven single-column layout retains every essential action/status/provider disclosure; no mockup pixel width overrides this rule. Canvas may remain two-dimensional; outline/inspectors reflow.

## Inspiration & Anti-patterns

- The supplied [Overview reference](imports/overview-referenced.html) contributed substantial identity on the left, focused action on the right, narrative content, and compact context. Profile sidebar, inline description editing, horizontal tabs, manual cover, schedule rail, and generic “while away” duplication were rejected or relocated.
- The [theme comparison](.working/color-themes-1.html) established Studio Paper, Signal Slate, Quiet Grove, Fjord Air, and Aubergine Ledger as separate curated Light/Dark presets; final semantic and Increase Contrast tokens live in `DESIGN.md`.
- [Reference-derived directions](.working/design-directions-2.html) selected Reference Focused masthead plus Reference Relational content. [Earlier directions](.working/design-directions-1.html) established density range.
- [Overview](.working/design-direction-selected.html) and [Sidebar](.working/sidebar-direction.html) studies remain composition/state references only; this spine supersedes their continuity-line cover, avatar/account, permanent Add Project, horizontal tabs, and brand mark.
- [Pile Cover handoff](imports/pile-cover-handoff.md) governs the local data-bound cover, with later decisions replacing duration width, milestone, photo, actor-weight, per-mark interaction, and extra-placement ideas.
- [Proposal wireframe](wireframes/proposal-review.excalidraw) governs proposal behavior; [Map companion](../../../../docs/mockups/project-overview/project-map-interactions.md) governs relationships subject to the resolved current spine.
- Rejected: generic AI memory/chat-with-files opacity, configurable PM workspace, engagement/gamification, autonomous canonical mutation, arbitrary themes/fonts/logos/covers, and decorative motion.

## Key Flows

### UJ-1. Wouter starts a consequential project and establishes trusted state.

1. Wouter creates a local Project from a short description.
2. The start surface offers **Start guided Conversation** (primary), **Import existing material** (secondary), and **Open Overview** (quiet link).
3. He chooses guided Conversation; Context Preview names the explicitly active local adapter/model, description, empty Canonical State, working language, and local boundary; he explicitly starts.
4. The agent uses known context and asks focused goal/scope questions without repetition.
5. A named proposal set contains proposed Topics; later work may propose other artifacts/relationships.
6. Wouter inspects effects/dependencies/provenance and accepts, edits and accepts, rejects, or defers.
7. **Climax:** accepted Topics become versioned Canonical State with rationale/provenance, while proposal history links to the generating turn.

Failure/recovery: missing setup returns to the interrupted action after success. Offline/provider failure preserves project/draft and never queues. Acceptance failure rolls back atomically.

### Source Material path within UJ-1 — Wouter establishes trusted state from existing work.

1. After local project creation, Wouter chooses **Import existing material** instead of guided Conversation.
2. He pastes text or selects/drops supported `.txt`, `.md`, or searchable `.pdf` files; preflight shows count/type/size and rejects unsupported/over-limit items before extraction.
3. ProjectOS retains every accepted original locally and extracts without invoking inference. Source Inspector shows Complete, Partial, Failed, Needs OCR, or Needs password truthfully.
4. Wouter reviews originals/extraction, known-language metadata, and exact passages. He selects only the material to synthesize.
5. He chooses Synthesize. Context Preview names the active adapter/model, selected Sources/excerpts, working language, and local or external boundary; he adjusts scope and explicitly starts.
6. The response creates a dependency-ordered proposal set of relevant Topics, Research, Questions, Decisions, Tasks, and relationships. None is canonical yet.
7. Wouter compares proposals with exact Source passages and accepts, edits and accepts, rejects, or defers each valid group.
8. **Climax:** Overview and Project Map show the first accepted structured state with exact Source and Conversation provenance; originals remain inspectable on this Mac.

Failure/recovery: unsupported/oversize input remains unimported with reason; scanned/encrypted PDF is retained in Needs state; extraction failure retains original; offline import/review works but Synthesize is disabled with reason; interrupted synthesis remains Incomplete and retry uses fresh preview.

### UJ-2. Wouter changes a decision without losing why it changed.

1. Wouter opens Research or a Map relationship contradicting a Governing Decision.
2. After Context Preview, he starts a grounded Conversation containing the Decision, contrary evidence, rationale, provenance, and directly connected current artifacts.
3. The active adapter proposes a dependency-ordered replacement set.
4. Wouter compares old/new rationale, evidence, effects, and dependents; edits revalidate dependents.
5. He explicitly accepts the valid atomic group.
6. **Climax:** one new Governing Decision appears; the prior Decision remains Superseded in place with full lineage and replacement link.

Failure/recovery: rejection leaves Canonical State unchanged and blocks hard dependents without rejecting them; transaction failure fully rolls back; later reconsideration creates a new proposal, never toggles history.

### UJ-3. Wouter resumes after a meaningful absence.

1. Wouter opens a Project Card; Overview loads locally without invoking inference.
2. Pile Cover and Relational Briefing orient him. A matching saved pair appears; otherwise What's Up Next says Needs recap.
3. If needed, he explicitly generates after Context Preview; historical Recap and future recommendation bind to one version.
4. He inspects accepted history, unanswered Questions, affected Tasks, relationships, and provenance.
5. Continue work transitions to Conversation and performs the specifically grounded call authorized by that selection.
6. Conversation opens on the recommended Question/Task with current context, so Wouter resumes meaningful work without rebuilding the mental model.
7. The validation-only Return Outcome Record captures elapsed time and lets him record clear understanding, trust, Next Action usefulness, whether Meaningful Work began within five minutes, and an optional note.
8. **Climax:** Wouter saves the local, exportable outcome record after reaching meaningful work; measurement does not interrupt or invoke inference.

Failure/recovery: matching saved orientation and outcome recording remain available offline; provider continuation is disabled with reason. Any canonical change invalidates the pair immediately; conflicts produce an uncertain recommendation. A record-save failure preserves the draft and elapsed-time evidence locally for retry.

### UJ-4. Wouter verifies ownership and recoverability.

1. Wouter previews Export in Project Settings.
2. He starts atomic export, then Reveal in Finder/Open README/Verify.
3. Project Library Restore reads the package without mutation and previews identity/schema/counts/migrations/corruption/conflicts.
4. He restores as a new copy; ProjectOS verifies manifest/checksums/relationships/provenance.
5. **Climax:** restored Overview matches Canonical State/history/provenance and reads Verified.

Failure/recovery: cancel/failure leaves no valid partial; restore corruption blocks commit or rolls back; missing evidence is disclosed; mismatch deep-links discrepancy.

### Key Flow — First launch (Wouter)

1. Wouter opens ProjectOS; UI follows supported macOS English/Dutch, otherwise English.
2. Skippable privacy orientation states local storage, local inference by default, and explicit OpenRouter transmission only when selected.
3. ProjectOS detects Ollama and LM Studio, offers explicit MLX setup, offers optional OpenRouter Keychain setup, and lets Wouter select an active runtime/model; Continue without AI remains.
4. Readiness summarizes language, local storage, selected adapter/model, locality, capability state, Follow macOS, and Studio Paper.
5. **Climax:** empty Project Library opens with Create your first project, without tour/sample/theme/notification prompts.

Failure/recovery: runtime, model, resource, OpenRouter credential, network, rate, quota, billing, and service states have distinct remedies; local use remains available and later inference returns to setup.

### Key Flow — Create a Project (Wouter)

1. From Project Library or `⇧⌘N`, Wouter selects New Project and enters a short description.
2. ProjectOS creates the local project and deterministic bare-ground Pile Cover.
3. It offers Start guided Conversation, Import existing material, and Open Overview.
4. **Climax:** whichever start path Wouter chooses already knows the description and new-project state; he never reconstructs or repeats it.

Failure/recovery: creation failure preserves description and explains storage recovery. Offline creation/import/Overview work; guided provider work is disabled until explicit reconnect/resume.

### Key Flow — Permanently delete a Project (Wouter)

1. Wouter opens Project Settings and chooses **Delete Project**.
2. Confirmation Sheet names the Project content/history/Sources/Conversations/validation records that will be removed, explains that provider retention, backups, and user exports are separate, and offers **Export first**.
3. After export or an explicit skip, Wouter confirms permanent local deletion with the destructive action.
4. ProjectOS atomically removes the local Project, Project-scoped MLX cache data, and ordinary optional provider bindings, then shows **Project deleted** independently from credential, shared-model, and external-retention status.
5. The result states that Ollama/LM Studio installations and shared models, the OpenRouter Keychain credential, shared MLX models/caches, backups, exports, and independent OpenRouter/routed-provider retention were not removed.
6. If an adapter declared and used persistent external sessions, its idempotent cleanup proceeds without sending Project content; pending work retains only an app-level content-free receipt with explicit retry.
7. **Climax:** Project Library no longer contains the Project, while every remaining credential, runtime/model-data, or declared cleanup outcome is represented truthfully rather than implied complete.

Failure/recovery: cancel leaves all state unchanged. A local transaction failure rolls back deletion. If declared cleanup exists, crash/startup resumes it idempotently and preserves the receipt until confirmed/already absent; local deletion is never reversed or falsely blocked by cleanup failure.

## Deferred after MVP

- Remote Ollama/LM Studio endpoints, other local runtimes, direct provider APIs, Codex App Server, and automatic model/provider fallback.
- Animated/time-comparison Project Map and compact Overview graph preview.
- OCR and Source formats outside the committed matrix.
- Pile Cover share/print rendering.
