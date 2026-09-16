import Foundation

/// A destination in the Project Library — the window shown when no project is
/// open.
///
/// The library has its own small navigation because Settings is global: it
/// belongs to the app rather than to any one project, so it has to be reachable
/// without first opening a project.
enum LibraryDestination: String, CaseIterable, Hashable, Identifiable {
    case projects
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: "Projects"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .projects: "square.stack.3d.up"
        case .settings: "gearshape"
        }
    }
}
