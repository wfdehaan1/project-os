import Foundation

public enum ProposalValidationError: Error, Equatable, LocalizedError {
  case malformedJSON
  case unsupportedSchemaVersion(Int)
  case staleContext(expected: Int, actual: Int)
  case unknownProperty(path: String, property: String)
  case duplicateProposalID(UUID)
  case invalidOperation(UUID)
  case missingTarget(UUID)
  case unexpectedTarget(UUID)
  case staleTarget(UUID)
  case invalidArtifactState(UUID)
  case missingDecisionSubject(UUID)
  case missingResearchQualification(UUID)
  case unresolvedDependency(UUID)
  case cyclicDependency(UUID)
  case invalidRelationship(UUID)
  case unselectedEvidence(UUID)
  case evidenceVersionMismatch(UUID)
  case quoteNotFound(UUID)
  case decisionWithoutUserEvidence(UUID)

  public var errorDescription: String? {
    switch self {
    case .malformedJSON: "The provider returned malformed or truncated proposal JSON."
    case .unsupportedSchemaVersion(let version):
      "Proposal schema version \(version) is not supported."
    case .staleContext(let expected, let actual):
      "Project context changed (generated at \(expected), now \(actual)). Regenerate proposals."
    case .unknownProperty(let path, let property):
      "Unknown proposal property \(property) at \(path)."
    case .duplicateProposalID(let id): "Proposal ID \(id) is duplicated."
    case .invalidOperation(let id): "Proposal \(id) has fields that do not match its operation."
    case .missingTarget(let id): "Proposal \(id) targets a missing artifact."
    case .unexpectedTarget(let id): "Create proposal \(id) must not target an artifact."
    case .staleTarget(let id): "Proposal \(id) targets an out-of-date artifact version."
    case .invalidArtifactState(let id):
      "Proposal \(id) uses an invalid state for its artifact kind."
    case .missingDecisionSubject(let id): "Decision proposal \(id) requires a stable subject."
    case .missingResearchQualification(let id):
      "Research proposal \(id) requires explicit certainty and limitations."
    case .unresolvedDependency(let id): "Proposal \(id) has an unresolved dependency."
    case .cyclicDependency(let id): "Proposal \(id) has a cyclic dependency."
    case .invalidRelationship(let id): "Proposal \(id) has an invalid relationship endpoint."
    case .unselectedEvidence(let id):
      "Evidence \(id) refers to material outside the frozen context."
    case .evidenceVersionMismatch(let id): "Evidence \(id) refers to a different retained version."
    case .quoteNotFound(let id):
      "Evidence quote \(id) is not an exact substring of the selected text."
    case .decisionWithoutUserEvidence(let id):
      "Decision proposal \(id) lacks user-authored evidence."
    }
  }
}

private struct WireProposalBatch: Decodable {
  var schemaVersion: Int
  var proposals: [WireProposal]
}

private struct WireProposal: Decodable {
  var temporaryID: UUID
  var operation: ProposalOperation
  var kind: ArtifactKind
  var targetID: UUID?
  var expectedTargetRevision: Int?
  var title: String
  var content: String
  var rationale: String?
  var decisionSubject: String?
  var state: ArtifactState?
  var certainty: String?
  var limitations: String?
  var evidence: [WireEvidence]
  var relationships: [WireRelation]
  var dependencyIDs: [UUID]
}

private struct WireEvidence: Decodable {
  var sourceType: EvidenceSourceType
  var referenceID: UUID
  var version: Int
  var quote: String
}

private struct WireRelation: Decodable {
  var type: RelationType
  var targetArtifactID: UUID?
  var targetProposalID: UUID?
}

public enum ProposalValidator {
  public static let schemaVersion = 1

  public static func validate(
    data: Data,
    projectID: UUID,
    jobID: UUID,
    context: ContextSnapshot,
    currentProjectRevision: Int,
    currentArtifacts: [Artifact]
  ) throws -> ProposalBatch {
    try rejectUnknownProperties(data)
    let wire: WireProposalBatch
    do {
      wire = try JSONDecoder().decode(WireProposalBatch.self, from: data)
    } catch {
      throw ProposalValidationError.malformedJSON
    }
    guard wire.schemaVersion == schemaVersion else {
      throw ProposalValidationError.unsupportedSchemaVersion(wire.schemaVersion)
    }
    guard context.projectID == projectID else {
      throw ProposalValidationError.malformedJSON
    }
    guard context.projectRevision == currentProjectRevision else {
      throw ProposalValidationError.staleContext(
        expected: context.projectRevision, actual: currentProjectRevision)
    }

    let proposalIDs = Set(wire.proposals.map(\.temporaryID))
    guard proposalIDs.count == wire.proposals.count else {
      let duplicate = Dictionary(grouping: wire.proposals, by: \.temporaryID)
        .first(where: { $0.value.count > 1 })!.key
      throw ProposalValidationError.duplicateProposalID(duplicate)
    }
    let artifactByID = Dictionary(uniqueKeysWithValues: currentArtifacts.map { ($0.id, $0) })
    let selectedEvidence: [(EvidenceSelectionKey, ContextSelection)] = context.selections.compactMap
    { selection in
      guard let type = evidenceType(for: selection.kind) else { return nil }
      return (EvidenceSelectionKey(type: type, id: selection.referenceID), selection)
    }
    let selectionByReference = Dictionary(uniqueKeysWithValues: selectedEvidence)

    var proposals: [Proposal] = []
    for item in wire.proposals {
      guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        artifactByID[item.temporaryID] == nil
      else { throw ProposalValidationError.invalidOperation(item.temporaryID) }
      try validateOperation(item, artifacts: artifactByID)
      if let targetID = item.targetID, artifactByID[targetID]?.projectID != projectID {
        throw ProposalValidationError.missingTarget(item.temporaryID)
      }
      if item.operation == .supersede,
        item.decisionSubject?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
      {
        throw ProposalValidationError.missingDecisionSubject(item.temporaryID)
      }
      if item.kind == .research,
        item.certainty?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
          || item.limitations?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
      {
        throw ProposalValidationError.missingResearchQualification(item.temporaryID)
      }
      if let state = item.state, !item.kind.permits(state) {
        throw ProposalValidationError.invalidArtifactState(item.temporaryID)
      }
      guard Set(item.dependencyIDs).isSubset(of: proposalIDs),
        Set(item.dependencyIDs).count == item.dependencyIDs.count,
        !item.dependencyIDs.contains(item.temporaryID)
      else {
        throw ProposalValidationError.unresolvedDependency(item.temporaryID)
      }

      var evidence: [EvidenceReference] = []
      for rawEvidence in item.evidence {
        let evidenceID = UUID()
        let key = EvidenceSelectionKey(type: rawEvidence.sourceType, id: rawEvidence.referenceID)
        guard let selected = selectionByReference[key] else {
          throw ProposalValidationError.unselectedEvidence(evidenceID)
        }
        guard selected.version == rawEvidence.version else {
          throw ProposalValidationError.evidenceVersionMismatch(evidenceID)
        }
        guard !rawEvidence.quote.isEmpty, selected.text.range(of: rawEvidence.quote) != nil else {
          throw ProposalValidationError.quoteNotFound(evidenceID)
        }
        evidence.append(
          EvidenceReference(
            id: evidenceID,
            sourceType: rawEvidence.sourceType,
            referenceID: rawEvidence.referenceID,
            version: rawEvidence.version,
            quote: rawEvidence.quote,
            isAIAuthored: selected.kind == .message
              && selected.statusLabel == "AI-authored/unverified"
          ))
      }
      if item.kind == .decision, evidence.isEmpty || evidence.allSatisfy(\.isAIAuthored) {
        throw ProposalValidationError.decisionWithoutUserEvidence(item.temporaryID)
      }

      var relations: [ProposalRelation] = []
      for relation in item.relationships {
        let hasArtifact = relation.targetArtifactID != nil
        let hasProposal = relation.targetProposalID != nil
        guard hasArtifact != hasProposal else {
          throw ProposalValidationError.invalidRelationship(item.temporaryID)
        }
        if let targetArtifactID = relation.targetArtifactID {
          guard artifactByID[targetArtifactID]?.projectID == projectID else {
            throw ProposalValidationError.invalidRelationship(item.temporaryID)
          }
        }
        if let targetProposalID = relation.targetProposalID {
          guard proposalIDs.contains(targetProposalID),
            targetProposalID != item.temporaryID,
            item.dependencyIDs.contains(targetProposalID)
          else {
            throw ProposalValidationError.invalidRelationship(item.temporaryID)
          }
        }
        relations.append(
          ProposalRelation(
            type: relation.type,
            targetArtifactID: relation.targetArtifactID,
            targetProposalID: relation.targetProposalID
          ))
      }

      proposals.append(
        Proposal(
          id: item.temporaryID,
          projectID: projectID,
          jobID: jobID,
          contextRevision: context.projectRevision,
          operation: item.operation,
          kind: item.kind,
          targetID: item.targetID,
          expectedTargetRevision: item.expectedTargetRevision,
          title: item.title,
          content: item.content,
          rationale: item.rationale,
          decisionSubject: item.decisionSubject,
          proposedState: item.state,
          certainty: item.certainty,
          limitations: item.limitations,
          evidence: evidence,
          relationships: relations,
          dependencyIDs: item.dependencyIDs
        ))
    }
    try rejectCycles(proposals)
    return ProposalBatch(schemaVersion: wire.schemaVersion, proposals: proposals)
  }

  private static func validateOperation(_ proposal: WireProposal, artifacts: [UUID: Artifact])
    throws
  {
    switch proposal.operation {
    case .create:
      guard proposal.targetID == nil, proposal.expectedTargetRevision == nil else {
        throw ProposalValidationError.unexpectedTarget(proposal.temporaryID)
      }
    case .update, .supersede, .relate:
      guard let targetID = proposal.targetID, let expected = proposal.expectedTargetRevision else {
        throw ProposalValidationError.invalidOperation(proposal.temporaryID)
      }
      guard let target = artifacts[targetID] else {
        throw ProposalValidationError.missingTarget(proposal.temporaryID)
      }
      guard target.version == expected else {
        throw ProposalValidationError.staleTarget(proposal.temporaryID)
      }
      guard
        proposal.operation != .supersede || (proposal.kind == .decision && target.kind == .decision)
      else {
        throw ProposalValidationError.invalidOperation(proposal.temporaryID)
      }
      if proposal.operation == .supersede,
        let existingSubject = target.decisionSubject,
        normalized(existingSubject) != normalized(proposal.decisionSubject ?? "")
      {
        throw ProposalValidationError.invalidOperation(proposal.temporaryID)
      }
    }
  }

  private static func rejectCycles(_ proposals: [Proposal]) throws {
    let dependencies = Dictionary(
      uniqueKeysWithValues: proposals.map { ($0.id, Set($0.dependencyIDs)) })
    var visiting: Set<UUID> = []
    var visited: Set<UUID> = []
    func visit(_ id: UUID) throws {
      if visiting.contains(id) { throw ProposalValidationError.cyclicDependency(id) }
      if visited.contains(id) { return }
      visiting.insert(id)
      for dependency in dependencies[id, default: []] { try visit(dependency) }
      visiting.remove(id)
      visited.insert(id)
    }
    for proposal in proposals { try visit(proposal.id) }
  }

  private static func evidenceType(for kind: ContextSelectionKind) -> EvidenceSourceType? {
    switch kind {
    case .source: .source
    case .message: .message
    case .projectDescription, .artifact: nil
    }
  }

  private static func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  }

  private static func rejectUnknownProperties(_ data: Data) throws {
    guard
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let proposals = root["proposals"] as? [[String: Any]]
    else { throw ProposalValidationError.malformedJSON }
    try rejectUnknown(root, allowed: ["schemaVersion", "proposals"], path: "$")
    guard Set(["schemaVersion", "proposals"]).isSubset(of: root.keys) else {
      throw ProposalValidationError.malformedJSON
    }
    for (index, proposal) in proposals.enumerated() {
      let path = "$.proposals[\(index)]"
      try rejectUnknown(
        proposal,
        allowed: [
          "temporaryID", "operation", "kind", "targetID", "expectedTargetRevision", "title",
          "content",
          "rationale", "decisionSubject", "state", "certainty", "limitations", "evidence",
          "relationships", "dependencyIDs",
        ], path: path)
      guard
        Set([
          "temporaryID", "operation", "kind", "targetID", "expectedTargetRevision", "title",
          "content",
          "rationale", "decisionSubject", "state", "certainty", "limitations", "evidence",
          "relationships", "dependencyIDs",
        ]).isSubset(of: proposal.keys)
      else { throw ProposalValidationError.malformedJSON }
      for (evidenceIndex, evidence) in (proposal["evidence"] as? [[String: Any]] ?? []).enumerated()
      {
        try rejectUnknown(
          evidence, allowed: ["sourceType", "referenceID", "version", "quote"],
          path: "\(path).evidence[\(evidenceIndex)]")
        guard Set(["sourceType", "referenceID", "version", "quote"]).isSubset(of: evidence.keys)
        else {
          throw ProposalValidationError.malformedJSON
        }
      }
      for (relationIndex, relation) in (proposal["relationships"] as? [[String: Any]] ?? [])
        .enumerated()
      {
        try rejectUnknown(
          relation, allowed: ["type", "targetArtifactID", "targetProposalID"],
          path: "\(path).relationships[\(relationIndex)]")
        guard Set(["type", "targetArtifactID", "targetProposalID"]).isSubset(of: relation.keys)
        else {
          throw ProposalValidationError.malformedJSON
        }
      }
    }
  }

  private static func rejectUnknown(_ object: [String: Any], allowed: Set<String>, path: String)
    throws
  {
    if let property = Set(object.keys).subtracting(allowed).sorted().first {
      throw ProposalValidationError.unknownProperty(path: path, property: property)
    }
  }
}

private struct EvidenceSelectionKey: Hashable {
  var type: EvidenceSourceType
  var id: UUID
}
