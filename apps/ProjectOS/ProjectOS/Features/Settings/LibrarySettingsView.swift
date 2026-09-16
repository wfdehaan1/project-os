import SwiftUI

/// The Project Library's Settings page.
///
/// Everything here is global: it applies to every project, which is why it is
/// reachable without opening one. The same sections appear in the macOS
/// Settings window, so neither place owns a preference the other lacks.
struct LibrarySettingsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            SurfaceHeader(title: "Settings", titleIdentifier: "library.settings-heading", status: {
                LocalStorageStatus(detail: "Applies to every project")
            })
            DecorativeDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.step4) {
                    AppearanceSettingsSection()
                    InferenceSettingsSection()
                }
                .padding(Spacing.step5)
                .frame(maxWidth: Spacing.readableWidth, alignment: .leading)
            }
        }
        .background(theme.canvas)
        .navigationTitle("Settings")
    }
}
