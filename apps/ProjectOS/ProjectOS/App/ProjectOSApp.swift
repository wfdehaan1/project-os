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
        }

        Settings {
            GlobalSettingsView()
                .environmentObject(environment)
                .frame(width: 560, height: 440)
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
