import SwiftUI

/// The return outcome record: how well re-entry actually worked.
struct OutcomeFormView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var duration = 5
    @State private var understanding = 3
    @State private var trust = 3
    @State private var usefulness = 3
    @State private var resumed = false
    @State private var action = "Different action"
    @State private var reviewMinutes = 0
    @State private var outcome = "Unresolved"
    @State private var notes = ""

    var body: some View {
        SheetScaffold(
            title: "Return outcome",
            subtitle: "Recorded locally. It is evidence about the product, not about the project.",
            confirmTitle: "Save",
            confirm: { save() },
            cancel: { dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.step3) {
                    SettingsRow(label: "Time to meaningful work") {
                        Stepper("\(duration) min", value: $duration, in: 0 ... 240)
                    }
                    SettingsRow(label: "Resumed within five minutes") {
                        Toggle("", isOn: $resumed).toggleStyle(.checkbox).labelsHidden()
                    }
                    RatingRow(label: "Understanding", value: $understanding)
                    RatingRow(label: "Trust", value: $trust)
                    RatingRow(label: "Usefulness", value: $usefulness)
                    SettingsRow(label: "Action taken") {
                        Picker("", selection: $action) {
                            ForEach(["Followed recommendation", "Different action", "No action"], id: \.self) {
                                Text($0)
                            }
                        }
                        .labelsHidden()
                    }
                    SettingsRow(label: "Review and correction effort") {
                        Stepper("\(reviewMinutes) min", value: $reviewMinutes, in: 0 ... 240)
                    }
                    SettingsRow(label: "Project outcome") {
                        Picker("", selection: $outcome) {
                            ForEach(
                                ["Successful completion", "Intentional closure", "Abandonment", "Unresolved"],
                                id: \.self
                            ) { Text($0) }
                        }
                        .labelsHidden()
                    }
                    FormTextField(label: "Notes", text: $notes, lineLimit: 3 ... 6)
                }
            }
            .frame(maxHeight: 420)
        }
        .frame(width: 560)
    }

    private func save() {
        guard let projectID = environment.selectedProject?.id else { return }
        environment.saveOutcome(
            ReturnRecord(
                id: UUID(),
                projectID: projectID,
                durationMinutes: duration,
                understanding: understanding,
                trust: trust,
                usefulness: usefulness,
                resumedWithinFiveMinutes: resumed,
                actionOutcome: action,
                reviewMinutes: reviewMinutes,
                projectOutcome: outcome,
                notes: notes,
                createdAt: Date()
            )
        )
    }
}

private struct RatingRow: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        SettingsRow(label: label) {
            Picker(label, selection: $value) {
                ForEach(1 ... 5, id: \.self) { Text("\($0)").tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }
}
