---
title: 'Fix Conversations navigation crash'
type: 'bugfix'
created: '2026-09-11'
status: 'in-review'
baseline_commit: '81214c54dc90ff65dfc5b846b8d8256f7322f8d5'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-projectos/SPEC.md'
  - '{project-root}/_bmad-output/specs/spec-projectos/acceptance.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Opening a project and selecting Conversations terminates ProjectOS with an AppKit `NSGenericException` after repeated window constraint-update passes. This blocks the MVP's integrated conversation loop even though the app builds and the Library and Overview remain usable.

**Approach:** Remove the unstable nested split/inspector layout interaction from the Conversation workspace while retaining the conversation list, transcript/composer, and user-toggleable Project Updates rail. Add an end-to-end regression that enters Conversations through the real project UI and proves the workspace and proposal controls remain usable.

## Boundaries & Constraints

**Always:** Preserve the user's current `ConversationView.swift` `HStack`/divider edit as the working baseline; keep Project Updates explicit, visible on entry, and independently hideable/reopenable; retain local-only navigation with no inference call; keep the conversation list, draft editor, context preview, and proposal actions available; support the app's 820-point minimum window without an AppKit constraint-update loop; report runtime evidence separately from build/test evidence.

**Ask First:** Any redesign that removes side-by-side proposal review, changes the app-wide navigation model, changes persisted conversation/project data, or broadens the minimum window size.

**Never:** Revert unrelated dirty work in the Xcode project; delete or migrate user data; mask the exception with exception handling; trigger AI/provider traffic during navigation or automated verification; claim provider qualification or personal usefulness from this fix.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Enter conversation | An opened local project at the default 1180-point window | Conversations renders with thread list, transcript/composer, context preview, and visible Project Updates rail | No exception, hang, or repeated view-update warnings |
| Toggle updates | Conversation workspace with the Project Updates rail visible | The rail hides and reopens while conversation content remains usable | Repeated toggles do not create a constraint loop |
| Narrow window | Conversation workspace at the app's 820-point minimum width | Core conversation actions and a recoverable Project Updates control remain reachable | Layout may adapt, but must not clip the only reopen control or crash |
| Empty project | A newly created project with its initial empty conversation | Empty-state conversation and proposal UI render without inference | No data mutation beyond normal initial-conversation creation |

</frozen-after-approval>

## Code Map

- `apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift` -- failing workspace; current uncommitted `HStack` edit removes the inner `HSplitView`, while the remaining `.inspector` still exercises SwiftUI's AppKit split controller.
- `apps/ProjectOS/ProjectOS/Features/Library/ProjectWorkspaceView.swift` -- outer `NavigationSplitView` and route that constructs `ConversationView`.
- `apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift` -- native UI regression coverage; currently checks launch only.
- `apps/ProjectOS/docs/implementation-report.md` -- verification ledger that currently overstates the Conversation smoke coverage relative to the reproduced crash.

## Tasks & Acceptance

**Execution:**
- [x] `apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift` -- replace the remaining crash-prone inspector/split-controller composition with a stable adaptive rail presentation, preserving the existing conversation behavior and explicit toggle.
- [x] `apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift` -- add a deterministic project-to-Conversations navigation regression, including rail hide/reopen and observable workspace assertions without provider calls.
- [x] `apps/ProjectOS/docs/implementation-report.md` -- record the reproduced exception, fix, and exact new build/UI-test/manual results without rewriting unrelated verification claims.

**Acceptance Criteria:**
- Given a project is open, when Conversations is selected, then the process remains alive and the thread list, conversation empty state or transcript, context preview, composer, and Project Updates controls are present.
- Given the Conversations screen is open, when Project Updates is hidden and reopened, then both states render without a constraint-update exception and the conversation remains accessible.
- Given the window is resized to its supported minimum, when the user enters Conversations and recovers the Project Updates rail, then the essential actions remain reachable without a crash.
- Given the navigation regression runs, when it creates/opens a local project and enters Conversations, then it sends no inference request and fails if the target workspace disappears.

## Spec Change Log

## Design Notes

The failure was reproduced on the current working tree after the inner `HSplitView` had already been replaced. Xcode stopped on an uncaught `NSGenericException`: the window exceeded its allowed Update Constraints passes; the stack points through `SwiftUI.SplitViewChildController.didUpdateMinSize`. The remaining `.inspector` is therefore the next unstable split-controller boundary inside the outer `NavigationSplitView`. Prefer a SwiftUI-owned adaptive composition that does not create another AppKit split controller; preserve access at narrow widths rather than merely changing the rail's default visibility.

## Verification

**Commands:**
- `rtk swift test --package-path Packages/ProjectOSCore` (from `apps/ProjectOS`) -- expected: all core tests pass.
- `rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedData -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES build` (from `apps/ProjectOS`) -- expected: `BUILD SUCCEEDED`.
- `rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedDataSigned -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES -only-testing:ProjectOSUITests test` (from `apps/ProjectOS`) -- expected: launch and Conversations regression tests pass with no provider setup.

**Manual checks (if no CLI):**
- Open a project, select Conversations, toggle Project Updates twice, resize to 820 points, and confirm Xcode records neither the Update Constraints exception nor repeated "Publishing changes from within view updates" warnings.
