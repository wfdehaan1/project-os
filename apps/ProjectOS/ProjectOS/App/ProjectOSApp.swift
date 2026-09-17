import SwiftUI
import Combine

@main
struct ProjectOSApp: App {
    @StateObject private var owner: AppEnvironmentOwner
    private var environment: AppEnvironment? { owner.environment }
    @Environment(\.openWindow) private var openWindow
    private static let experimentOnly = ProcessInfo.processInfo.arguments.contains("--codex-experiment")

    init() {
        // The experiment launch path never initializes the production environment or store.
        _owner = StateObject(wrappedValue: AppEnvironmentOwner(isolated: Self.experimentOnly))
    }

    var body: some Scene {
        Window("ProjectOS", id: "projectos-main") {
            if Self.experimentOnly {
                CodexExperimentView()
            } else if let environment {
                RootView()
                    .environmentObject(environment)
                    .frame(minWidth: 820, minHeight: 600)
            }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Project") { environment?.showCreateProject = true }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(environment == nil)
                Button("Codex Experiment") { openWindow(id: Self.experimentOnly ? "projectos-main" : "codex-experiment") }
            }
            // Every destination shortcut also has a visible menu item, so the
            // keyboard is never the only way to reach a surface.
            CommandMenu("Go") {
                ForEach(Array(WorkspaceNavigation.shortcutDestinations.enumerated()), id: \.element.id) { index, destination in
                    Button(destination.title) { environment?.show(destination) }
                        .keyboardShortcut(
                            KeyEquivalent(Character("\(index + 1)")),
                            modifiers: .command
                        )
                        .disabled(environment?.selectedProject == nil)
                }
            }
        }

        Settings {
            if let environment {
                GlobalSettingsView()
                    .environmentObject(environment)
                    .themedRoot(environment)
                    .frame(width: 620, height: 560)
            }
        }
        Window("Codex Experiment", id: "codex-experiment") {
            CodexExperimentView()
        }
        .defaultSize(width: 1080, height: 780)
        .commandsRemoved()
    }
}

@MainActor
private final class AppEnvironmentOwner: ObservableObject {
    let environment: AppEnvironment?
    private var observation: AnyCancellable?

    init(isolated: Bool) {
        environment = isolated ? nil : AppEnvironment()
        observation = environment?.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
}

private struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if environment.selectedProject == nil {
                LibraryView()
            } else {
                ProjectWorkspaceView()
            }
        }
        .themedRoot(environment)
        .task { environment.start() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { environment.completeVisit() } }
        .alert("ProjectOS", isPresented: Binding(
            get: { environment.alertMessage != nil },
            set: { if !$0 { environment.alertMessage = nil } }
        )) {
            Button("OK") { environment.alertMessage = nil }
        } message: {
            Text(environment.alertMessage ?? "")
        }
    }
}

private extension View {
    /// Applies the person's chosen appearance and theme preset to a scene root.
    func themedRoot(_ environment: AppEnvironment) -> some View {
        ThemedRoot(preset: environment.themePreset, appearance: environment.appearance) { self }
    }
}
