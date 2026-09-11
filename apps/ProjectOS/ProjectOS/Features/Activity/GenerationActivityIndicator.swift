import SwiftUI

/// The sidebar's account of the provider request: its current step at a
/// glance, and in a popover what every step means, which model is working, and
/// what context it was given.
///
/// It mirrors the Project Switcher at the top of the sidebar — title over a
/// caption, same padding and radius. A request in flight or just ended takes
/// the switcher's surface and boundary; at rest it sits flat on the sidebar and
/// names the model the next request would use, never claiming work that is not
/// happening.
struct GenerationActivityIndicator: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            HStack(spacing: Spacing.step2) {
                mark
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(headline)
                        .font(isActive ? TypeRole.label.weight(.semibold) : TypeRole.label)
                        .foregroundStyle(isActive ? theme.text : theme.muted)
                    Text(modelDescription)
                        .font(TypeRole.caption)
                        .foregroundStyle(theme.muted)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.step2)
            .padding(.vertical, Spacing.step2)
            .background(isActive ? theme.surface : .clear, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(theme.essentialBoundary.opacity(isActive ? 0.45 : 0), lineWidth: Stroke.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show what the model is doing")
        .popover(isPresented: $isShowingDetails, arrowEdge: .trailing) {
            GenerationActivityDetails { isShowingDetails = false }
        }
        .accessibilityIdentifier("sidebar.generation-activity")
        .accessibilityLabel("Model activity")
        .accessibilityValue("\(headline), \(modelDescription)")
    }

    private var isActive: Bool { environment.activity != nil }

    private var headline: String {
        environment.activity?.headline ?? "Model idle"
    }

    /// The model doing the work, or the one that would do it next.
    private var modelDescription: String {
        guard let activity = environment.activity else { return environment.activeModelDescription }
        return "\(activity.provider.rawValue) · \(activity.model)"
    }

    @ViewBuilder private var mark: some View {
        if let activity = environment.activity {
            ActivityMark(state: Self.overallState(of: activity))
        } else {
            Image(systemName: environment.runsLocally ? "desktopcomputer" : "network")
                .imageScale(.small)
                .foregroundStyle(theme.muted)
        }
    }

    private static func overallState(of activity: GenerationActivity) -> GenerationActivity.StepState {
        switch activity.outcome {
        case nil: .current
        case .completed: .done
        case .failed: .failed
        case .stopped: .stopped
        }
    }
}

/// The popover: every step of the request with the current one explained, then
/// the facts of who is doing the work on what.
private struct GenerationActivityDetails: View {
    let close: () -> Void

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step4) {
            if let activity = environment.activity {
                header(activity)
                timeline(activity)
                outcomeNote(activity)
                DecorativeDivider()
                facts(activity)
                actions(activity)
            } else {
                idle
            }
        }
        .padding(Spacing.step4)
        .frame(width: 340, alignment: .leading)
        .background(theme.surfaceRaised)
    }

    private func header(_ activity: GenerationActivity) -> some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            Text(activity.purpose.activityTitle)
                .font(TypeRole.heading)
                .foregroundStyle(theme.text)
            Text(activity.projectName)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
        }
    }

    private func timeline(_ activity: GenerationActivity) -> some View {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            ForEach(activity.steps, id: \.self) { step in
                let state = activity.state(of: step)
                HStack(alignment: .top, spacing: Spacing.step2) {
                    ActivityMark(state: state)
                        .frame(width: 16, height: 16)
                    VStack(alignment: .leading, spacing: Spacing.step1) {
                        Text(step.title(for: activity.purpose))
                            .font(state == .current ? TypeRole.label.weight(.semibold) : TypeRole.label)
                            .foregroundStyle(state == .pending || state == .skipped ? theme.muted : theme.text)
                        if state == .current || state == .failed {
                            Text(step.detail(for: activity.purpose, runsLocally: activity.runsLocally, route: activity.route))
                                .font(TypeRole.caption)
                                .foregroundStyle(theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(Self.spokenState(state))
            }
        }
    }

    @ViewBuilder private func outcomeNote(_ activity: GenerationActivity) -> some View {
        switch activity.outcome {
        case .failed(let message):
            DisclosureNote(text: message, systemImage: "exclamationmark.triangle")
        case .stopped:
            DisclosureNote(text: "Stopped before it finished. The provider may already have performed work or incurred cost.")
        case .completed, nil:
            EmptyView()
        }
    }

    private func facts(_ activity: GenerationActivity) -> some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.step3, verticalSpacing: Spacing.step2) {
            fact("Model", "\(activity.provider.rawValue) · \(activity.model)")
            fact("Runs", activity.runsLocally ? "On this Mac" : "Via OpenRouter" + (activity.route.map { " · \($0)" } ?? ""))
            fact("Context", activity.contextSummary)
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label)
                .font(TypeRole.caption)
                .foregroundStyle(theme.muted)
            Text(value)
                .font(TypeRole.caption)
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actions(_ activity: GenerationActivity) -> some View {
        HStack {
            Spacer()
            if activity.isRunning {
                Button {
                    environment.stopGeneration()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.posSecondary)
            } else {
                Button("Dismiss") {
                    environment.dismissActivity()
                    close()
                }
                .buttonStyle(.posSecondary)
            }
        }
    }

    private var idle: some View {
        VStack(alignment: .leading, spacing: Spacing.step2) {
            Text("No request running")
                .font(TypeRole.heading)
                .foregroundStyle(theme.text)
            DisclosureNote(
                text: environment.providerDisclosure,
                systemImage: environment.runsLocally ? "desktopcomputer" : "network"
            )
        }
    }

    private static func spokenState(_ state: GenerationActivity.StepState) -> String {
        switch state {
        case .done: "Done"
        case .current: "In progress"
        case .failed: "Failed"
        case .stopped: "Stopped"
        case .pending: "Not started"
        case .skipped: "Did not run"
        }
    }
}

/// A step's state as a shape as well as a colour. The running step uses the
/// system spinner, which already honours Reduce Motion.
private struct ActivityMark: View {
    let state: GenerationActivity.StepState

    @Environment(\.theme) private var theme

    var body: some View {
        switch state {
        case .current:
            ProgressView().controlSize(.mini)
        case .done:
            symbol("checkmark.circle.fill", theme.success)
        case .failed:
            symbol("exclamationmark.triangle.fill", theme.warning)
        case .stopped:
            symbol("stop.circle", theme.muted)
        case .pending:
            symbol("circle", theme.muted)
        case .skipped:
            symbol("circle.dashed", theme.muted)
        }
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .imageScale(.small)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
