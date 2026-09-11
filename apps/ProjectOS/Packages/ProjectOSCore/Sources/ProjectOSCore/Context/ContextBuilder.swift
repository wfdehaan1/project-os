import Foundation

public struct ContextSelectionRequest: Hashable, Sendable {
  public var includeProjectDescription: Bool
  public var sourceIDs: Set<UUID>
  public var messageIDs: Set<UUID>
  public var artifactIDs: Set<UUID>
  public var includeNonCurrentArtifacts: Bool

  public init(
    includeProjectDescription: Bool = true,
    sourceIDs: Set<UUID> = [],
    messageIDs: Set<UUID> = [],
    artifactIDs: Set<UUID> = [],
    includeNonCurrentArtifacts: Bool = false
  ) {
    self.includeProjectDescription = includeProjectDescription
    self.sourceIDs = sourceIDs
    self.messageIDs = messageIDs
    self.artifactIDs = artifactIDs
    self.includeNonCurrentArtifacts = includeNonCurrentArtifacts
  }
}

public enum ContextBuilderError: Error, Equatable, LocalizedError {
  case emptyProvider
  case emptyModel
  case unknownBound
  case exceededBound(estimatedCharacters: Int, maximumCharacters: Int)
  case missingReference(UUID)
  case crossProjectReference(UUID)
  case incompleteMessage(UUID)
  case nonCurrentArtifact(UUID)
  case intakeLimitExceeded(UUID)

  public var errorDescription: String? {
    switch self {
    case .emptyProvider: "Choose a provider before sending."
    case .emptyModel: "Choose a model before sending."
    case .unknownBound: "Configure a verified context bound before sending."
    case .exceededBound(let estimated, let maximum):
      "Selected context is \(estimated) characters, above the configured \(maximum)-character bound. Narrow the selection."
    case .missingReference(let id):
      "Selected context reference \(id) no longer exists. Refresh the preview."
    case .crossProjectReference(let id): "Context reference \(id) belongs to another project."
    case .incompleteMessage(let id): "Message \(id) is incomplete and cannot enter frozen context."
    case .nonCurrentArtifact(let id):
      "Artifact \(id) is not current. Include non-current knowledge explicitly."
    case .intakeLimitExceeded(let id): "Source \(id) exceeds the 250,000-character intake limit."
    }
  }
}

public enum ContextBuilder {
  public static let maximumSourceCharacters = 250_000

  public static func freeze(
    project: Project,
    sources: [SourceDocument],
    messages: [Message],
    artifacts: [Artifact],
    selection: ContextSelectionRequest,
    providerID: String,
    modelID: String,
    configurationID: String,
    purpose: JobPurpose,
    maximumCharacters: Int?
  ) throws -> ContextSnapshot {
    guard !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ContextBuilderError.emptyProvider
    }
    guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ContextBuilderError.emptyModel
    }
    guard let maximumCharacters, maximumCharacters > 0 else {
      throw ContextBuilderError.unknownBound
    }

    let sourceByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
    let messageByID = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
    let artifactByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
    var frozen: [ContextSelection] = []

    if selection.includeProjectDescription, !project.description.isEmpty {
      frozen.append(
        ContextSelection(
          kind: .projectDescription,
          referenceID: project.id,
          version: project.revision,
          label: "Project description",
          text: project.description,
          statusLabel: "accepted"
        ))
    }

    for id in selection.sourceIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let source = sourceByID[id] else { throw ContextBuilderError.missingReference(id) }
      guard source.projectID == project.id else {
        throw ContextBuilderError.crossProjectReference(id)
      }
      guard source.text.count <= maximumSourceCharacters else {
        throw ContextBuilderError.intakeLimitExceeded(id)
      }
      frozen.append(
        ContextSelection(
          kind: .source,
          referenceID: source.id,
          version: source.version,
          label: source.label,
          text: source.text
        ))
    }

    for id in selection.messageIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let message = messageByID[id] else { throw ContextBuilderError.missingReference(id) }
      guard message.projectID == project.id else {
        throw ContextBuilderError.crossProjectReference(id)
      }
      guard message.completion == .complete else { throw ContextBuilderError.incompleteMessage(id) }
      frozen.append(
        ContextSelection(
          kind: .message,
          referenceID: message.id,
          version: message.version,
          label: message.role.rawValue.capitalized,
          text: message.text,
          statusLabel: message.role == .assistant ? "AI-authored/unverified" : "user-authored"
        ))
    }

    for id in selection.artifactIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let artifact = artifactByID[id] else { throw ContextBuilderError.missingReference(id) }
      guard artifact.projectID == project.id else {
        throw ContextBuilderError.crossProjectReference(id)
      }
      let isCurrent = artifact.state != .removed && artifact.state != .superseded
      guard isCurrent || selection.includeNonCurrentArtifacts else {
        throw ContextBuilderError.nonCurrentArtifact(id)
      }
      frozen.append(
        ContextSelection(
          kind: .artifact,
          referenceID: artifact.id,
          version: artifact.version,
          label: artifact.title,
          text: artifact.content,
          statusLabel: artifact.state.rawValue
        ))
    }

    let estimated = frozen.reduce(0) { partial, item in
      partial + item.label.count + item.text.count + (item.statusLabel?.count ?? 0) + 16
    }
    guard estimated <= maximumCharacters else {
      throw ContextBuilderError.exceededBound(
        estimatedCharacters: estimated,
        maximumCharacters: maximumCharacters
      )
    }

    return ContextSnapshot(
      projectID: project.id,
      projectRevision: project.revision,
      providerID: providerID,
      modelID: modelID,
      configurationID: configurationID,
      purpose: purpose,
      selections: frozen,
      estimatedCharacters: estimated
    )
  }
}
