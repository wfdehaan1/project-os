import SwiftUI

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
        Form {
            Text("Return Outcome").font(.title2.bold())
            Stepper("Time to meaningful work: \(duration) min", value: $duration, in: 0...240)
            Toggle("Resumed within five minutes", isOn: $resumed)
            RatingRow(label: "Understanding", value: $understanding)
            RatingRow(label: "Trust", value: $trust)
            RatingRow(label: "Usefulness", value: $usefulness)
            Picker("Action", selection: $action) { ForEach(["Followed recommendation", "Different action", "No action"], id: \.self) { Text($0) } }
            Stepper("Review/correction effort: \(reviewMinutes) min", value: $reviewMinutes, in: 0...240)
            Picker("Project outcome", selection: $outcome) { ForEach(["Successful completion", "Intentional closure", "Abandonment", "Unresolved"], id: \.self) { Text($0) } }
            TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { save() }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 520)
    }

    private func save() {
        guard let projectID = environment.selectedProject?.id else { return }
        environment.saveOutcome(ReturnRecord(id: UUID(), projectID: projectID, durationMinutes: duration, understanding: understanding, trust: trust, usefulness: usefulness, resumedWithinFiveMinutes: resumed, actionOutcome: action, reviewMinutes: reviewMinutes, projectOutcome: outcome, notes: notes, createdAt: Date()))
    }
}

private struct RatingRow: View {
    let label: String
    @Binding var value: Int
    var body: some View { HStack { Text(label); Spacer(); Picker(label, selection: $value) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }.labelsHidden().pickerStyle(.segmented).frame(width: 220) } }
}
