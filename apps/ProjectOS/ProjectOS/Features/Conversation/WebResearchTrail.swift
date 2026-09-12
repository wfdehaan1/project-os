import SwiftUI

/// What the model did on the web for one reply: every search it ran and every
/// page it read, each page with a way back to the original and a way to keep it.
///
/// Reading a page does not make it project material. Keeping it does, and only
/// then can a proposal quote it, which is why saving is a deliberate act here.
struct WebResearchTrail: View {
    let steps: [WebResearchStep]

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    @State private var isExpanded = true

    private var summary: String {
        let searches = steps.filter { $0.action == .search }.count
        let pages = steps.filter { $0.action == .read && $0.status == .done }.count
        let failures = steps.filter { $0.status == .failed }.count
        var parts: [String] = []
        if searches > 0 { parts.append("\(searches) search\(searches == 1 ? "" : "es")") }
        if pages > 0 { parts.append("\(pages) page\(pages == 1 ? "" : "s") read") }
        if failures > 0 { parts.append("\(failures) failed") }
        return parts.isEmpty ? "Web research" : "Web research · \(parts.joined(separator: " · "))"
    }

    var body: some View {
        SurfaceContainer(role: .tint, radius: Radius.md, padding: Spacing.step2) {
            VStack(alignment: .leading, spacing: Spacing.step2) {
                Button {
                    withAnimation(Motion.standard) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: Spacing.step2) {
                        Image(systemName: "globe")
                            .imageScale(.small)
                        Text(summary)
                            .font(TypeRole.caption.weight(.semibold))
                        Spacer(minLength: 0)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .imageScale(.small)
                    }
                    .foregroundStyle(theme.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(summary)

                if isExpanded {
                    VStack(alignment: .leading, spacing: Spacing.step2) {
                        ForEach(steps) { WebResearchStepRow(step: $0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }
}

/// One search or one page, with what it produced.
private struct WebResearchStepRow: View {
    let step: WebResearchStep

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.step2) {
            mark
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypeRole.caption.weight(.medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                Text(detail)
                    .font(TypeRole.caption)
                    .foregroundStyle(step.status == .failed ? theme.warning : theme.muted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.step2)
            if let page = step.page, step.status == .done {
                pageActions(page)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var mark: some View {
        switch step.status {
        case .running:
            ProgressView().controlSize(.mini)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.small)
                .foregroundStyle(theme.warning)
        case .done:
            Image(systemName: step.action == .search ? "magnifyingglass" : "doc.text")
                .imageScale(.small)
                .foregroundStyle(theme.muted)
        }
    }

    private var title: String {
        switch step.action {
        case .search:
            return step.subject.isEmpty ? "Search" : "Searched “\(step.subject)”"
        case .read:
            return step.page?.title ?? URL(string: step.subject)?.host ?? step.subject
        }
    }

    private var detail: String {
        if let failure = step.failure { return failure }
        switch (step.action, step.status) {
        case (.search, .running): return "Searching through SearXNG…"
        case (.read, .running): return "Reading the page…"
        case (.search, _):
            let count = step.results?.count ?? 0
            return count == 0 ? "No results" : "\(count) result\(count == 1 ? "" : "s")"
        case (.read, _):
            guard let page = step.page else { return step.subject }
            return "\(page.url.host ?? page.url.absoluteString) · \(page.text.count) characters kept"
        }
    }

    @ViewBuilder private func pageActions(_ page: WebPageSnapshot) -> some View {
        HStack(spacing: Spacing.step2) {
            Link(destination: page.url) {
                Label("Open", systemImage: "arrow.up.right.square")
            }
            .font(TypeRole.caption)
            .help(page.url.absoluteString)

            if environment.savedSource(for: page) != nil {
                StatusBadge(text: "Saved as source", symbol: "checkmark", tone: .success)
            } else {
                Button("Save as source") { environment.saveWebPageAsSource(page) }
                    .buttonStyle(.posGhost)
                    .help("Keep this page's text as a project source, so records can quote it.")
            }
        }
    }
}
