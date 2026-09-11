import SwiftUI

// Presentation mapping for domain types. It lives in the design system so the
// domain models stay free of SwiftUI, and so every surface that shows a record
// agrees on its symbol, wording, and tone.

extension ArtifactKind {
    var symbolName: String {
        switch self {
        case .topic: "circle.grid.2x2"
        case .research: "doc.text.magnifyingglass"
        case .decision: "checkmark.seal"
        case .openQuestion: "questionmark.circle"
        case .task: "checklist"
        }
    }

    /// The plural used for a sidebar destination or a filter segment.
    var pluralName: String {
        switch self {
        case .topic: "Topics"
        case .research: "Research"
        case .decision: "Decisions"
        case .openQuestion: "Questions"
        case .task: "Tasks"
        }
    }

    var tone: StatusBadge.Tone {
        switch self {
        case .decision: .accent
        case .openQuestion: .warning
        case .task: .neutral
        case .research, .topic: .muted
        }
    }
}

extension ArtifactState {
    var displayName: String {
        switch self {
        case .current: "Governing"
        case .open: "Open"
        case .inProgress: "In progress"
        case .blocked: "Blocked"
        case .done: "Done"
        case .resolved: "Resolved"
        case .dismissed: "Dismissed"
        case .superseded: "Superseded"
        case .removed: "Removed"
        }
    }

    /// A distinct shape per state, so status is never carried by colour alone.
    var symbolName: String {
        switch self {
        case .current: "checkmark.circle.fill"
        case .open: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .blocked: "exclamationmark.octagon"
        case .done: "checkmark.circle"
        case .resolved: "checkmark.diamond"
        case .dismissed: "minus.circle"
        case .superseded: "circle.dashed"
        case .removed: "trash.circle"
        }
    }

    var tone: StatusBadge.Tone {
        switch self {
        case .current, .done, .resolved: .success
        case .open, .inProgress: .warning
        case .blocked: .warning
        case .superseded, .dismissed, .removed: .muted
        }
    }

    /// States that represent live, unfinished work needing attention.
    static let unfinishedTaskStates: [ArtifactState] = [.open, .inProgress, .blocked]
}

extension ProposalLifecycle {
    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .accepted: "Accepted"
        case .rejected: "Rejected"
        case .deferred: "Deferred"
        case .invalidated: "Invalidated"
        }
    }

    var symbolName: String {
        switch self {
        case .pending: "tray"
        case .accepted: "checkmark.circle.fill"
        case .rejected: "xmark.circle"
        case .deferred: "clock"
        case .invalidated: "exclamationmark.triangle"
        }
    }

    var tone: StatusBadge.Tone {
        switch self {
        case .pending: .accent
        case .accepted: .success
        case .rejected, .deferred: .muted
        case .invalidated: .warning
        }
    }

    /// A proposal still awaiting the person's explicit decision.
    var isActionable: Bool { self == .pending || self == .deferred }
}

extension ProposalOperation {
    var displayName: String {
        switch self {
        case .create: "Add"
        case .update: "Update"
        case .supersede: "Replace"
        case .relate: "Relate"
        }
    }
}

extension MessageRole {
    var displayName: String {
        switch self {
        case .user: "You"
        case .assistant: "Assistant"
        }
    }
}

extension MessageCompletion {
    var displayName: String {
        switch self {
        case .complete: "Complete"
        case .partial: "Incomplete"
        case .failed: "Failed"
        case .cancelled: "Stopped"
        }
    }

    var symbolName: String {
        switch self {
        case .complete: "checkmark"
        case .partial: "ellipsis"
        case .failed: "exclamationmark.triangle"
        case .cancelled: "stop.circle"
        }
    }

    var tone: StatusBadge.Tone {
        switch self {
        case .complete: .muted
        case .partial, .cancelled: .warning
        case .failed: .warning
        }
    }
}

extension ProviderReadiness {
    var displayName: String {
        switch self {
        case .unavailable: "Unavailable"
        case .connected: "Connected"
        case .unverified: "Unverified"
        case .qualified: "Qualified"
        }
    }

    var symbolName: String {
        switch self {
        case .unavailable: "wifi.slash"
        case .connected: "link"
        case .unverified: "questionmark.circle"
        case .qualified: "checkmark.seal"
        }
    }

    var tone: StatusBadge.Tone {
        switch self {
        case .unavailable: .muted
        case .connected: .neutral
        case .unverified: .warning
        case .qualified: .success
        }
    }
}
