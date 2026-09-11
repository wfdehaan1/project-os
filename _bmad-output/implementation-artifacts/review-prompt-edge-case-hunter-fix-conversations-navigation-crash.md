# Edge Case Hunter review prompt

Invoke the `bmad-review-edge-case-hunter` skill on this diff:

```diff
diff --git a/apps/ProjectOS/ProjectOS.xcodeproj/project.pbxproj b/apps/ProjectOS/ProjectOS.xcodeproj/project.pbxproj
index 57edddb..2f7482f 100644
--- a/apps/ProjectOS/ProjectOS.xcodeproj/project.pbxproj
+++ b/apps/ProjectOS/ProjectOS.xcodeproj/project.pbxproj
@@ -332,6 +332,7 @@
 					"@executable_path/../Frameworks",
 				);
 				MARKETING_VERSION = 0.1;
+				ONLY_ACTIVE_ARCH = YES;
 				PRODUCT_BUNDLE_IDENTIFIER = com.wouter.ProjectOS;
 				PRODUCT_NAME = "$(TARGET_NAME)";
 				SWIFT_EMIT_LOC_STRINGS = YES;
@@ -355,6 +356,7 @@
 					"@executable_path/../Frameworks",
 				);
 				MARKETING_VERSION = 0.1;
+				ONLY_ACTIVE_ARCH = YES;
 				PRODUCT_BUNDLE_IDENTIFIER = com.wouter.ProjectOS;
 				PRODUCT_NAME = "$(TARGET_NAME)";
 				SWIFT_COMPILATION_MODE = wholemodule;
diff --git a/apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift b/apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift
index 0f44bb5..3e99473 100644
--- a/apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift
+++ b/apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift
@@ -4,67 +4,103 @@ struct ConversationView: View {
     @EnvironmentObject private var environment: AppEnvironment
     @State private var showContext = true
     @State private var showProjectUpdates = true
+    private let sideBySideRailMinimumWidth: CGFloat = 900
 
     var body: some View {
-        HSplitView {
-            ConversationListView()
-                .frame(minWidth: 170, idealWidth: 210, maxWidth: 260)
-            VStack(spacing: 0) {
-                HStack {
-                    VStack(alignment: .leading) {
-                        Text("Conversation").font(.title2.bold())
-                        Text(environment.generationStatus).font(.caption).foregroundStyle(.secondary)
-                    }
-                    Spacer()
-                    Button("Paste Source", systemImage: "doc.on.clipboard") { environment.showAddSource = true }
-                    Button("Project Updates", systemImage: "tray.full") { showProjectUpdates.toggle() }
-                }.padding()
-                Divider()
-
-                ScrollViewReader { proxy in
-                    ScrollView {
-                        LazyVStack(alignment: .leading, spacing: 14) {
-                            if environment.messages.isEmpty {
-                                ContentUnavailableView("Start with your project", systemImage: "bubble.left", description: Text("Select context below, then ask a question. Sending never applies project updates."))
-                            }
-                            ForEach(environment.messages) { message in
-                                MessageBubble(message: message).id(message.id)
-                            }
-                        }.padding()
+        GeometryReader { geometry in
+            let listWidth = min(210, max(170, geometry.size.width * 0.22))
+            let railWidth = min(340, max(280, geometry.size.width * 0.35))
+            let showsSideBySideRail = showProjectUpdates && geometry.size.width >= sideBySideRailMinimumWidth
+            let dividerWidth: CGFloat = showsSideBySideRail ? 2 : 1
+            let contentWidth = geometry.size.width - listWidth - dividerWidth - (showsSideBySideRail ? railWidth : 0)
+
+            ZStack(alignment: .topTrailing) {
+                HStack(spacing: 0) {
+                    ConversationListView()
+                        .frame(width: listWidth)
+                    Divider()
+                    conversationContent
+                        .frame(width: contentWidth)
+
+                    if showsSideBySideRail {
+                        Divider()
+                        projectUpdatesRail
+                            .frame(width: railWidth)
                     }
-                    .onChange(of: environment.messages.count) { _, _ in if let id = environment.messages.last?.id { proxy.scrollTo(id) } }
                 }
+                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
 
-                Divider()
-                DisclosureGroup(isExpanded: $showContext) {
-                    ContextPreviewView()
-                } label: {
-                    Label("Context Preview", systemImage: "scope")
-                        .font(.headline)
-                }.padding(.horizontal).padding(.top, 10)
-
-                TextEditor(text: $environment.draft)
-                    .frame(minHeight: 70, maxHeight: 130)
-                    .padding(8)
-                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
-                    .padding(.horizontal)
-                    .onChange(of: environment.draft) { _, _ in environment.saveDraft() }
-                    .onKeyPress(.return, phases: .down) { press in
-                        if press.modifiers.contains(.command) { environment.sendMessage(); return .handled }
-                        return .ignored
+                if showProjectUpdates && !showsSideBySideRail {
+                    projectUpdatesRail
+                        .frame(width: min(340, max(280, geometry.size.width - 80)))
+                        .shadow(color: .black.opacity(0.18), radius: 12, x: -4)
+                }
+            }
+        }
+    }
+
+    private var conversationContent: some View {
+        VStack(spacing: 0) {
+            HStack {
+                VStack(alignment: .leading) {
+                    Text("Conversation")
+                        .font(.title2.bold())
+                        .accessibilityIdentifier("conversation.workspace-heading")
+                    Text(environment.generationStatus).font(.caption).foregroundStyle(.secondary)
+                }
+                Spacer()
+                Button("Paste Source", systemImage: "doc.on.clipboard") { environment.showAddSource = true }
+                Button("Project Updates", systemImage: "tray.full") { showProjectUpdates.toggle() }
+                    .accessibilityIdentifier("conversation.toggle-project-updates")
+            }.padding()
+            Divider()
+
+            ScrollViewReader { proxy in
+                ScrollView {
+                    LazyVStack(alignment: .leading, spacing: 14) {
+                        if environment.messages.isEmpty {
+                            ContentUnavailableView("Start with your project", systemImage: "bubble.left", description: Text("Select context below, then ask a question. Sending never applies project updates."))
+                        }
+                        ForEach(environment.messages) { message in
+                            MessageBubble(message: message).id(message.id)
+                        }
                     }
-                HStack {
-                    Text("⌘↩ Send · AI proposes text only").font(.caption).foregroundStyle(.secondary)
-                    Spacer()
-                    if environment.isGenerating { Button("Stop", systemImage: "stop.fill") { environment.stopGeneration() } }
-                    Button("Send", systemImage: "arrow.up.circle.fill") { environment.sendMessage() }.buttonStyle(.borderedProminent).disabled(environment.isGenerating || environment.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
-                }.padding()
+                    .padding()
+                }
+                .onChange(of: environment.messages.count) { _, _ in if let id = environment.messages.last?.id { proxy.scrollTo(id) } }
             }
-            .frame(minWidth: 360)
+
+            Divider()
+            DisclosureGroup(isExpanded: $showContext) {
+                ContextPreviewView()
+            } label: {
+                Label("Context Preview", systemImage: "scope")
+                    .font(.headline)
+            }.padding(.horizontal).padding(.top, 10)
+
+            TextEditor(text: $environment.draft)
+                .frame(minHeight: 70, maxHeight: 130)
+                .padding(8)
+                .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
+                .padding(.horizontal)
+                .onChange(of: environment.draft) { _, _ in environment.saveDraft() }
+                .onKeyPress(.return, phases: .down) { press in
+                    if press.modifiers.contains(.command) { environment.sendMessage(); return .handled }
+                    return .ignored
+                }
+            HStack {
+                Text("⌘↩ Send · AI proposes text only").font(.caption).foregroundStyle(.secondary)
+                Spacer()
+                if environment.isGenerating { Button("Stop", systemImage: "stop.fill") { environment.stopGeneration() } }
+                Button("Send", systemImage: "arrow.up.circle.fill") { environment.sendMessage() }.buttonStyle(.borderedProminent).disabled(environment.isGenerating || environment.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
+            }.padding()
         }
-        .inspector(isPresented: $showProjectUpdates) {
-            ProposalRailView()
-                .inspectorColumnWidth(min: 280, ideal: 340, max: 440)
+        .frame(minWidth: 360)
+    }
+
+    private var projectUpdatesRail: some View {
+        ProposalRailView {
+            showProjectUpdates = false
         }
     }
 }
@@ -141,12 +177,20 @@ private struct ContextPreviewView: View {
 
 private struct ProposalRailView: View {
     @EnvironmentObject private var environment: AppEnvironment
+    let onClose: () -> Void
     var pending: [ProposalRecord] { environment.proposals.filter { $0.lifecycle == .pending || $0.lifecycle == .deferred } }
     var body: some View {
         VStack(alignment: .leading, spacing: 12) {
             HStack {
-                VStack(alignment: .leading) { Text("Project Updates").font(.headline); Text("Pending, never automatic truth").font(.caption).foregroundStyle(.secondary) }
+                VStack(alignment: .leading) {
+                    Text("Project Updates")
+                        .font(.headline)
+                        .accessibilityIdentifier("conversation.project-updates-heading")
+                    Text("Pending, never automatic truth").font(.caption).foregroundStyle(.secondary)
+                }
                 Spacer()
+                Button("Close Project Updates", systemImage: "xmark", action: onClose)
+                    .labelStyle(.iconOnly)
             }
             Button("Suggest Project Updates", systemImage: "sparkles") { environment.suggestUpdates() }
                 .buttonStyle(.borderedProminent).disabled(environment.isGenerating)
@@ -158,7 +202,10 @@ private struct ProposalRailView: View {
                     LazyVStack(spacing: 12) { ForEach(pending) { ProposalCard(proposal: $0) } }
                 }
             }
-        }.padding().background(.background.secondary)
+        }
+        .padding()
+        .frame(maxHeight: .infinity, alignment: .top)
+        .background(.background.secondary)
     }
 }
 
diff --git a/apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift b/apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift
index 95f4449..97f2f12 100644
--- a/apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift
+++ b/apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift
@@ -3,11 +3,59 @@ import XCTest
 @MainActor
 final class ProjectOSUITests: XCTestCase {
     func testLaunchesLibrary() {
-        let app = XCUIApplication()
-        app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
-        app.launch()
+        let app = launchApp()
         XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
         XCTAssertTrue(app.staticTexts["ProjectOS"].waitForExistence(timeout: 5), app.debugDescription)
         XCTAssertTrue(app.buttons["Create a new project"].exists, app.debugDescription)
     }
+
+    func testOpeningConversationsAndTogglingProjectUpdatesKeepsWorkspaceAlive() {
+        let app = launchApp()
+        let createProject = app.buttons["Create a new project"]
+        XCTAssertTrue(createProject.waitForExistence(timeout: 5), app.debugDescription)
+        createProject.click()
+
+        let projectName = "Conversation Navigation \(UUID().uuidString.prefix(8))"
+        let projectNameField = app.textFields["Project name"]
+        XCTAssertTrue(projectNameField.waitForExistence(timeout: 5), app.debugDescription)
+        projectNameField.click()
+        projectNameField.typeText(projectName)
+        let createSheet = app.sheets.firstMatch
+        XCTAssertTrue(createSheet.waitForExistence(timeout: 5), app.debugDescription)
+        createSheet.buttons["Create"].click()
+
+        let conversationSection = app.staticTexts["Conversation"].firstMatch
+        XCTAssertTrue(conversationSection.waitForExistence(timeout: 5), app.debugDescription)
+        conversationSection.click()
+
+        let workspace = app.staticTexts["conversation.workspace-heading"]
+        let projectUpdates = app.staticTexts["conversation.project-updates-heading"]
+        let toggleProjectUpdates = app.buttons["conversation.toggle-project-updates"]
+        XCTAssertTrue(workspace.waitForExistence(timeout: 5), app.debugDescription)
+        XCTAssertTrue(app.staticTexts["Conversations"].waitForExistence(timeout: 5), app.debugDescription)
+        XCTAssertTrue(app.staticTexts["Start with your project"].waitForExistence(timeout: 5), app.debugDescription)
+        XCTAssertTrue(app.descendants(matching: .any)["Context Preview"].waitForExistence(timeout: 5), app.debugDescription)
+        XCTAssertTrue(projectUpdates.waitForExistence(timeout: 5), app.debugDescription)
+        XCTAssertTrue(toggleProjectUpdates.exists, app.debugDescription)
+
+        let window = app.windows.firstMatch
+        let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 0.998, dy: 0.998))
+        let minimumWidthTarget = window.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.998))
+        bottomRight.press(forDuration: 0.1, thenDragTo: minimumWidthTarget)
+        XCTAssertLessThanOrEqual(window.frame.width, 850, app.debugDescription)
+        XCTAssertTrue(projectUpdates.waitForExistence(timeout: 5), app.debugDescription)
+
+        app.buttons["Close Project Updates"].click()
+        XCTAssertTrue(projectUpdates.waitForNonExistence(timeout: 5), app.debugDescription)
+        toggleProjectUpdates.click()
+        XCTAssertTrue(projectUpdates.waitForExistence(timeout: 5), app.debugDescription)
+        XCTAssertTrue(workspace.exists, app.debugDescription)
+    }
+
+    private func launchApp() -> XCUIApplication {
+        let app = XCUIApplication()
+        app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
+        app.launch()
+        return app
+    }
 }
diff --git a/apps/ProjectOS/docs/implementation-report.md b/apps/ProjectOS/docs/implementation-report.md
index 689e190..d816eec 100644
--- a/apps/ProjectOS/docs/implementation-report.md
+++ b/apps/ProjectOS/docs/implementation-report.md
@@ -11,7 +11,7 @@ This report separates implemented behavior, automated evidence, live verificatio
 
 - Native sandboxed SwiftUI macOS application and shared Xcode scheme under `apps/ProjectOS`.
 - SQLite local store with schema versioning and tested v1 migration, foreign keys, serialized writes, fail-closed reads, atomic accepted changes, injected rollback, revision checks, idempotent acceptance, dependency-set acceptance, explicit normalized decision supersession, typed relationships, historical removal with relation cleanup, and compensating undo that reopens proposal review.
-- Library, project rename/description, labelled exact-text paste intake (250,000-character limit), Overview, Conversation, Knowledge inspector/editor, a recoverable native project-updates inspector that preserves the conversation at narrow window sizes, project settings, and local return-outcome form.
+- Library, project rename/description, labelled exact-text paste intake (250,000-character limit), Overview, Conversation, Knowledge inspector/editor, an adaptive SwiftUI-owned Project Updates rail that remains recoverable without a nested AppKit split controller at narrow window sizes, project settings, and local return-outcome form.
 - A persisted conversation list with independently durable per-thread drafts; complete/partial/failed/cancelled messages; one active inference job per project; frozen visible context; explicit send/proposal/next-action requests; cancellation; interrupted-job recovery; stale structured-result rejection; and no inference on navigation.
 - A Swift package containing provider-neutral domain records, bounded context construction, the bundled strict proposal schema, semantic/evidence validation, and the accepted-change engine.
 - Real Ollama NDJSON and OpenRouter SSE adapters through `URLSession`, explicit provider/model/boundary descriptors, strict routing/no fallback, conservative context bounds, cancellation, redacted failures, usage when returned, and a Keychain-only OpenRouter credential.
@@ -56,7 +56,9 @@ Result: **passed**, 18 tests. These exercise relaunch persistence and project is
 rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedDataSigned -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES -only-testing:ProjectOSUITests test
 ```
 
-Result: **passed**, 1 UI test from a fresh signed derived-data path. The launch argument now explicitly disables saved window state, and the test verifies a native window, Library title, and accessible project-creation action. During hardening, a cached signed build surfaced a newer-schema alert; the clean rebuild was inspected and opened Library plus the native creation sheet without that alert. An earlier manual native smoke walkthrough created `Garden Office Smoke Test`, opened Overview and Project Settings, saved exact synthetic text as a labelled source, and verified the Conversation context preview and separate proposal controls. No inference request was sent.
+Result: **passed**, 2 UI tests from the signed derived-data path. The launch test verifies a native window, Library title, and accessible project-creation action. The Conversation regression creates and opens a local project, enters Conversations, verifies the empty state and context controls, resizes the window to at most 850 points, then hides and reopens Project Updates without invoking inference.
+
+Before this fix, selecting Conversation reproducibly terminated the app with an uncaught AppKit `NSGenericException` after excessive Update Constraints passes; the backtrace ran through `SwiftUI.SplitViewChildController.didUpdateMinSize`. Replacing the inner `HSplitView` alone did not resolve it because the nested `.inspector` still introduced a second AppKit split-controller boundary inside the workspace `NavigationSplitView`. The Conversation screen now uses explicit geometry-based SwiftUI layout: the review rail is side-by-side when space allows and overlays with its own close control at narrow widths. Manual navigation and repeated rail toggling also remained responsive in the corrected build.
 
 ## Provider setup
diff --git a/_bmad-output/implementation-artifacts/spec-fix-conversations-navigation-crash.md b/_bmad-output/implementation-artifacts/spec-fix-conversations-navigation-crash.md
new file mode 100644
index 0000000..639d67f
--- /dev/null
+++ b/_bmad-output/implementation-artifacts/spec-fix-conversations-navigation-crash.md
@@ -0,0 +1,74 @@
+---
+title: 'Fix Conversations navigation crash'
+type: 'bugfix'
+created: '2026-09-11'
+status: 'in-review'
+baseline_commit: '81214c54dc90ff65dfc5b846b8d8256f7322f8d5'
+review_loop_iteration: 0
+context:
+  - '{project-root}/_bmad-output/specs/spec-projectos/SPEC.md'
+  - '{project-root}/_bmad-output/specs/spec-projectos/acceptance.md'
+---
+
+<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">
+
+## Intent
+
+**Problem:** Opening a project and selecting Conversations terminates ProjectOS with an AppKit `NSGenericException` after repeated window constraint-update passes. This blocks the MVP's integrated conversation loop even though the app builds and the Library and Overview remain usable.
+
+**Approach:** Remove the unstable nested split/inspector layout interaction from the Conversation workspace while retaining the conversation list, transcript/composer, and user-toggleable Project Updates rail. Add an end-to-end regression that enters Conversations through the real project UI and proves the workspace and proposal controls remain usable.
+
+## Boundaries & Constraints
+
+**Always:** Preserve the user's current `ConversationView.swift` `HStack`/divider edit as the working baseline; keep Project Updates explicit, visible on entry, and independently hideable/reopenable; retain local-only navigation with no inference call; keep the conversation list, draft editor, context preview, and proposal actions available; support the app's 820-point minimum window without an AppKit constraint-update loop; report runtime evidence separately from build/test evidence.
+
+**Ask First:** Any redesign that removes side-by-side proposal review, changes the app-wide navigation model, changes persisted conversation/project data, or broadens the minimum window size.
+
+**Never:** Revert unrelated dirty work in the Xcode project; delete or migrate user data; mask the exception with exception handling; trigger AI/provider traffic during navigation or automated verification; claim provider qualification or personal usefulness from this fix.
+
+## I/O & Edge-Case Matrix
+
+| Scenario | Input / State | Expected Output / Behavior | Error Handling |
+|----------|--------------|---------------------------|----------------|
+| Enter conversation | An opened local project at the default 1180-point window | Conversations renders with thread list, transcript/composer, context preview, and visible Project Updates rail | No exception, hang, or repeated view-update warnings |
+| Toggle updates | Conversation workspace with the Project Updates rail visible | The rail hides and reopens while conversation content remains usable | Repeated toggles do not create a constraint loop |
+| Narrow window | Conversation workspace at the app's 820-point minimum width | Core conversation actions and a recoverable Project Updates control remain reachable | Layout may adapt, but must not clip the only reopen control or crash |
+| Empty project | A newly created project with its initial empty conversation | Empty-state conversation and proposal UI render without inference | No data mutation beyond normal initial-conversation creation |
+
+</frozen-after-approval>
+
+## Code Map
+
+- `apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift` -- failing workspace; current uncommitted `HStack` edit removes the inner `HSplitView`, while the remaining `.inspector` still exercises SwiftUI's AppKit split controller.
+- `apps/ProjectOS/ProjectOS/Features/Library/ProjectWorkspaceView.swift` -- outer `NavigationSplitView` and route that constructs `ConversationView`.
+- `apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift` -- native UI regression coverage; currently checks launch only.
+- `apps/ProjectOS/docs/implementation-report.md` -- verification ledger that currently overstates the Conversation smoke coverage relative to the reproduced crash.
+
+## Tasks & Acceptance
+
+**Execution:**
+- [x] `apps/ProjectOS/ProjectOS/Features/Conversation/ConversationView.swift` -- replace the remaining crash-prone inspector/split-controller composition with a stable adaptive rail presentation, preserving the existing conversation behavior and explicit toggle.
+- [x] `apps/ProjectOS/ProjectOSUITests/ProjectOSUITests.swift` -- add a deterministic project-to-Conversations navigation regression, including rail hide/reopen and observable workspace assertions without provider calls.
+- [x] `apps/ProjectOS/docs/implementation-report.md` -- record the reproduced exception, fix, and exact new build/UI-test/manual results without rewriting unrelated verification claims.
+
+**Acceptance Criteria:**
+- Given a project is open, when Conversations is selected, then the process remains alive and the thread list, conversation empty state or transcript, context preview, composer, and Project Updates controls are present.
+- Given the Conversations screen is open, when Project Updates is hidden and reopened, then both states render without a constraint-update exception and the conversation remains accessible.
+- Given the window is resized to its supported minimum, when the user enters Conversations and recovers the Project Updates rail, then the essential actions remain reachable without a crash.
+- Given the navigation regression runs, when it creates/opens a local project and enters Conversations, then it sends no inference request and fails if the target workspace disappears.
+
+## Spec Change Log
+
+## Design Notes
+
+The failure was reproduced on the current working tree after the inner `HSplitView` had already been replaced. Xcode stopped on an uncaught `NSGenericException`: the window exceeded its allowed Update Constraints passes; the stack points through `SwiftUI.SplitViewChildController.didUpdateMinSize`. The remaining `.inspector` is therefore the next unstable split-controller boundary inside the outer `NavigationSplitView`. Prefer a SwiftUI-owned adaptive composition that does not create another AppKit split controller; preserve access at narrow widths rather than merely changing the rail's default visibility.
+
+## Verification
+
+**Commands:**
+- `rtk swift test --package-path Packages/ProjectOSCore` (from `apps/ProjectOS`) -- expected: all core tests pass.
+- `rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedData -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES build` (from `apps/ProjectOS`) -- expected: `BUILD SUCCEEDED`.
+- `rtk xcodebuild -project ProjectOS.xcodeproj -scheme ProjectOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ProjectOSDerivedDataSigned -clonedSourcePackagesDirPath /tmp/ProjectOSSourcePackages -packageCachePath /tmp/ProjectOSPackageCache ONLY_ACTIVE_ARCH=YES -only-testing:ProjectOSUITests test` (from `apps/ProjectOS`) -- expected: launch and Conversations regression tests pass with no provider setup.
+
+**Manual checks (if no CLI):**
+- Open a project, select Conversations, toggle Project Updates twice, resize to 820 points, and confirm Xcode records neither the Update Constraints exception nor repeated "Publishing changes from within view updates" warnings.
```
