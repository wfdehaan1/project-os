import SwiftUI

@main
struct ProjectOSApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .frame(minWidth: 820, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Project") { environment.showCreateProject = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            // Every destination shortcut also has a visible menu item, so the
            // keyboard is never the only way to reach a surface.
            CommandMenu("Go") {
                ForEach(Array(WorkspaceNavigation.shortcutDestinations.enumerated()), id: \.element.id) { index, destination in
                    Button(destination.title) { environment.show(destination) }
                        .keyboardShortcut(
                            KeyEquivalent(Character("\(index + 1)")),
                            modifiers: .command
                        )
                        .disabled(environment.selectedProject == nil)
                }
            }
        }

        Settings {
            GlobalSettingsView()
                .environmentObject(environment)
                .themedRoot(environment)
                .frame(width: 620, height: 560)
        }
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
