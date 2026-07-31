# Accessibility Reviewer Gate — ProjectOS

## Overall verdict

**Strong; closed for commit.** The current `DESIGN.md` and `EXPERIENCE.md` are sufficient as the downstream UX contract for a commercial consumer native macOS MVP against the declared relevant EN 301 549 non-web-software/documentation requirements, WCAG 2.2 Level AA outcomes translated to native macOS, and native accessibility interoperability. The Return Outcome Record and permanent-deletion/provider-cleanup additions preserve the existing keyboard, assistive-technology, localization, large-text, contrast, motion, notification, offline, and error-handling baseline.

This is a contract review, not a product conformance claim. Implementation must still pass the release test matrix before ProjectOS claims the baseline (`EXPERIENCE.md:326-337`).

## Scope and evidence

Reviewed:

- Current `DESIGN.md` and `EXPERIENCE.md` as the governing peer contracts.
- `.memlog.md`, including the commercial-MVP override, the established accessibility resolutions, and the latest Return Outcome/deletion lifecycle changes (`.memlog.md:20-22`, `.memlog.md:234-246`).
- Sources named in both spines: PRD, addendum, product brief, market research, and architecture spine (`DESIGN.md:5-10`; `EXPERIENCE.md:4-9`).
- All current `imports/`, `mockups/`, `wireframes/`, and `.working/` artifacts. They remain subordinate to the spines (`DESIGN.md:522`; `EXPERIENCE.md:343-351`).

Normative reference points checked: [WCAG 2.2](https://www.w3.org/TR/WCAG22/), [EN 301 549 V3.2.1](https://www.etsi.org/deliver/etsi_en/301500_301599/301549/03.02.01_60/en_301549v030201p.pdf), and Apple's native accessibility preference and assistive-technology guidance.

## Findings by severity

### Critical (0)

None. **Fix required:** none.

### High (0)

None. **Fix required:** none.

### Medium (0)

None. **Fix required:** none.

### Low (0)

None. **Fix required:** none.

## Latest lifecycle revalidation

### Return Outcome Record — strong

- The surface is named in IA, state coverage, UJ-3, offline capability, export scope, and failure recovery (`EXPERIENCE.md:54`, `EXPERIENCE.md:179`, `EXPERIENCE.md:245`, `EXPERIENCE.md:389-394`).
- It is a native labeled form/group rather than a custom visualization. Elapsed time is a labeled read-only value; understanding, trust, Next Action usefulness, and Meaningful Work use individually labeled native controls with exposed values/states; notes are a labeled multiline field; control and form-level errors are programmatically associated (`EXPERIENCE.md:301-303`).
- Focus moves only after explicit open, follows visual field order, preserves drafts on Cancel/Defer, and returns deterministically. The elapsed value is announced on entry and Save rather than ticking; success/failure announces once and remains visible (`EXPERIENCE.md:305`).
- Offline behavior is identical because recording is local. Native target sizing, enlargement, English/Dutch labels, VoiceOver, Voice Control, Switch Control, and fallback inherit the shared floor (`EXPERIENCE.md:305`).

### Permanent deletion and provider cleanup — strong

- Confirmation separates local deletion from provider cleanup, names deleted local content and excluded provider retention/backups/exports, offers export first, and keeps safe cancel (`EXPERIENCE.md:133`, `EXPERIENCE.md:425-435`).
- Local deletion and provider cleanup are separate durable outcomes. Cleanup is idempotent, retains only a content-free application-owned receipt, never resends Project content, discloses possible residual provider-side data, and supports matching-context reauthentication and retry (`EXPERIENCE.md:155`, `EXPERIENCE.md:261`).
- After deletion, the receipt survives on an app-level Provider Cleanup surface reachable from Project Library and Global Settings → Data and Recovery; no deleted-Project surface is its only route (`EXPERIENCE.md:39`, `EXPERIENCE.md:51`, `EXPERIENCE.md:55`, `EXPERIENCE.md:257-261`).
- Project Library, Global Settings, Notification Center, Project Settings-before-deletion, and Provider Cleanup each have explicit applicable states and deep-link behavior (`EXPERIENCE.md:164`, `EXPERIENCE.md:174-180`, `EXPERIENCE.md:249`).
- Provider Cleanup is a native app-level list/form built from Settings Row and Button behavior. Receipt names/states/actions are exposed without retaining Project content/title; focus never targets the removed Project/sidebar item and resolves through next, previous, heading, then empty state (`EXPERIENCE.md:296-307`).
- Offline local deletion remains available, while provider cleanup/retry is explicitly unavailable offline and never queued; generation reconnect and cleanup retry remain separate lifecycles (`EXPERIENCE.md:241-249`).

### Corrected Pile Cover examples — strong

- The primary Overview example's accessible description and visible legend both match ten governing Decisions, one superseded Decision, two unresolved Questions, and three proposal sets (`mockups/overview.html:160-170`).
- Needs recap and Offline alternates now expose the exact rendered composition—five governing Decisions, zero superseded Decisions, one unresolved Question, and one proposal set—in both the single action's accessible description and visible count legend (`mockups/overview.html:197-207`).
- Project Library card descriptions match their rendered countable marks, and internal SVGs remain hidden so each card stays one target (`mockups/project-library.html:117-139`).
- Promoted `mockups/overview.html` and `.working/key-overview.html` are byte-identical. The governing one-target Pile semantics remain unchanged (`EXPERIENCE.md:113-114`, `EXPERIENCE.md:277-278`; `DESIGN.md:581`, `DESIGN.md:596`, `DESIGN.md:625-635`).

## Established accessibility coverage retained

### Visual perception, contrast, and enlargement — strong

The token contract separates decorative dividers from load-bearing boundaries, selection, focus, graph edges/nodes, and pile marks (`DESIGN.md:538-547`). It commits 4.5:1 normal-text, 3:1 qualifying large-text/non-text, and stronger Increase Contrast outcomes (`DESIGN.md:549`). All five presets provide Light, Dark, and explicit Increase Contrast branches. Text, Dutch expansion, and supported macOS enlargement reflow without essential truncation (`DESIGN.md:553-567`; `EXPERIENCE.md:339-341`).

### Native semantics and assistive technology — strong

Native macOS behavior is authoritative and toolkit-independent (`EXPERIENCE.md:15-19`). Native controls/collections are the default, and the shared semantics matrix specifies role/name/value/state, grouping, actions, keyboard/focus fallback, announcement, target size, and drag alternatives across the reusable vocabulary (`EXPERIENCE.md:267-299`). The release matrix explicitly covers VoiceOver, Voice Control, Switch Control, Full Keyboard Access, and automated/manual regression (`EXPERIENCE.md:326-335`).

### Keyboard, focus, pointer, and motor access — strong

The shortcut model has visible menu/control equivalents and stable EN/NL bindings, with no dangerous global accept/reject shortcut (`EXPERIENCE.md:204-223`). Custom targets are 24×24 points or use a documented exception; every app-interpreted drag has click and keyboard alternatives; focused controls remain revealed; removal/filtering/pane changes use deterministic fallback; hover and double-click are never required (`EXPERIENCE.md:225-231`).

### Localization, language, and large text — strong

UI locale is exposed through native localization/accessibility metadata; known-language content uses attributed-language runs where supported; unknown language is not guessed (`EXPERIENCE.md:101`). English/Dutch localizes UI, notifications, dates/numbers/allowance, and accessibility labels without rewriting project content (`EXPERIENCE.md:251-257`). Responsive behavior yields to intrinsic content, localization, and accessibility sizes (`EXPERIENCE.md:339-341`).

### Motion and announcements — strong

Motion is deterministic and purposeful, with no bounce, shake, flashing emphasis, parallax, automatic Map travel, or animated token streaming (`DESIGN.md:524-530`; `EXPERIENCE.md:233-235`). Reduce Motion removes spatial movement, scaling, and animated scrolling (`EXPERIENCE.md:313-324`). Announcements are bounded, queued, non-focus-stealing, and distinguish routine updates from immediate data-loss/privacy/safety consequences (`EXPERIENCE.md:309-311`).

### Graph, Map, and notifications — strong

Project Map has a synchronized expandable outline with stable type-and-title ordering, named relationship direction/state, the same Inspectors/actions as the canvas, and complete keyboard alternatives (`EXPERIENCE.md:196-202`, `EXPERIENCE.md:291`). Notifications remain durable where actionable, restrained at OS level, deep-link without mutating or retrying, deduplicate, and honor macOS Focus (`EXPERIENCE.md:249`).

## Release checks retained

No spine or supporting-artifact edit is required. Before implementation claims the baseline:

1. Mechanically test every preset across Light/Dark, Increase Contrast, and Differentiate Without Color, including text, focus, disabled state, graph, pile, selection, and native destructive/error colors (`DESIGN.md:532-551`; `EXPERIENCE.md:313-335`).
2. Run keyboard-only core journeys with Full Keyboard Access, including Return Outcome Record and local deletion through provider-cleanup retry/reauthentication (`EXPERIENCE.md:204-231`, `EXPERIENCE.md:326-335`).
3. Inspect the native accessibility hierarchy and complete the same journeys with VoiceOver, Voice Control, and Switch Control; verify bounded announcements and deterministic focus after save, deletion, cleanup failure, and retry (`EXPERIENCE.md:267-335`).
4. Test every surface at the supported minimum window and maximum supported enlargement in English and Dutch (`DESIGN.md:553-567`; `EXPERIENCE.md:339-341`).
5. Exercise online/offline/runtime/authentication/allowance/service transitions and provider-cleanup pending/failed/reauthentication/confirmed states without silent queueing, hidden reasons, focus theft, or transient-only results (`EXPERIENCE.md:139-180`, `EXPERIENCE.md:237-261`, `EXPERIENCE.md:301-311`).

## Reviewer result

- **Verdict:** strong; closed for commit
- **Critical:** 0
- **High:** 0
- **Medium:** 0
- **Low:** 0
- **Required fixes:** none
