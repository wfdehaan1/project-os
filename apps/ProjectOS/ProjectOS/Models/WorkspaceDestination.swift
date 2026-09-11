import Foundation

/// A destination inside an open project.
///
/// Artifact kinds are one case with a payload rather than five cases, because
/// they all resolve to the same ledger surface with a different filter. Adding
/// an artifact kind therefore adds a sidebar row and nothing else.
enum WorkspaceDestination: Hashable, Identifiable {
    case overview
    case conversation
    /// The state ledger. `nil` shows every accepted record.
    case ledger(ArtifactKind?)
    case proposals
    case changeLog
    case sources
    case settings

    var id: String {
        switch self {
        case .overview: "overview"
        case .conversation: "conversation"
        case .ledger(let kind): "ledger.\(kind?.rawValue ?? "all")"
        case .proposals: "proposals"
        case .changeLog: "changeLog"
        case .sources: "sources"
        case .settings: "settings"
        }
    }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .conversation: "Conversation"
        case .ledger(let kind): kind?.pluralName ?? "All records"
        case .proposals: "Proposals"
        case .changeLog: "Change log"
        case .sources: "Sources"
        case .settings: "Project Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "house"
        case .conversation: "bubble.left.and.bubble.right"
        case .ledger(let kind): kind?.symbolName ?? "square.stack.3d.up"
        case .proposals: "sparkles"
        case .changeLog: "clock.arrow.circlepath"
        case .sources: "doc.on.doc"
        case .settings: "gearshape"
        }
    }
}

/// One labelled run of sidebar rows.
struct SidebarGroup: Identifiable {
    let id: String
    let title: String?
    let destinations: [WorkspaceDestination]
}

/// The sidebar's structure, in one place.
///
/// The grouping follows the design spine: where you are, what you are working
/// on, what the project has accepted, and the record behind it.
enum WorkspaceNavigation {
    static let groups: [SidebarGroup] = [
        SidebarGroup(id: "orientation", title: nil, destinations: [.overview]),
        SidebarGroup(
            id: "active-work",
            title: "Active work",
            destinations: [.conversation, .proposals, .ledger(.task)]
        ),
        SidebarGroup(
            id: "accepted-knowledge",
            title: "Accepted knowledge",
            destinations: [
                .ledger(.decision),
                .ledger(.research),
                .ledger(.openQuestion),
                .ledger(.topic),
            ]
        ),
        SidebarGroup(
            id: "record",
            title: "Record",
            destinations: [.changeLog, .sources, .settings]
        ),
    ]
}
