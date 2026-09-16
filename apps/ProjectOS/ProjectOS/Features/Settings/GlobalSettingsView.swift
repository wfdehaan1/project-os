import SwiftUI

/// Global settings in the macOS Settings window: appearance and theme, then the
/// inference provider.
///
/// The same sections back the Project Library's Settings page, so a preference
/// is defined once and reachable from either place.
struct GlobalSettingsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.step4) {
                AppearanceSettingsSection()
                InferenceSettingsSection()
            }
            .padding(Spacing.step5)
        }
        .background(theme.canvas)
        .navigationTitle("Settings")
    }
}
