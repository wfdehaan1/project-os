import Foundation

public struct ProjectState: Codable, Hashable, Sendable {
  public var project: Project
  public var artifacts: [Artifact]
  public var proposals: [Proposal]
  public var changes: [AcceptedChange]
  public var recommendations: [SavedRecommendation]

  public init(
    project: Project,
    artifacts: [Artifact] = [],
    proposals: [Proposal] = [],
    changes: [AcceptedChange] = [],
    recommendations: [SavedRecommendation] = []
  ) {
    self.project = project
    self.artifacts = artifacts
    self.proposals = proposals
    self.changes = changes
    self.recommendations = recommendations
  }
}

public struct ChangeApplicationResult: Equatable, Sendable {
  public var didChange: Bool
  public var change: AcceptedChange?

  public init(didChange: Bool, change: AcceptedChange?) {
    self.didChange = didChange
    self.change = change
  }
}

public enum ChangesEngineError: Error, Equatable, LocalizedError {
  case projectMismatch
  case staleProject(expected: Int, actual: Int)
  case unknownProposal(UUID)
  case proposalUnavailable(UUID)
  case dependencyUnavailable(UUID)
  case unknownArtifact(UUID)
  case staleArtifact(UUID, expected: Int, actual: Int)
  case invalidArtifactState(UUID)
  case invalidDecisionSubject(UUID)
  case invalidRelation(UUID)
  case crossProjectRelation(UUID)
  case duplicateGoverningDecision(String)
  case nothingToUndo

  public var errorDescription: String? {
    switch self {
    case .projectMismatch: "The change belongs to another project."
    case .staleProject(let expected, let actual):
      "Project revision changed (expected \(expected), found \(actual)). Review again."
    case .unknownProposal(let id): "Proposal \(id) does not exist."
    case .proposalUnavailable(let id): "Proposal \(id) is no longer pending."
    case .dependencyUnavailable(let id): "Dependency \(id) must be reviewed with this proposal."
    case .unknownArtifact(let id): "Artifact \(id) does not exist."
    case .staleArtifact(let id, let expected, let actual):
      "Artifact \(id) changed (expected \(expected), found \(actual))."
    case .invalidArtifactState(let id): "Artifact \(id) has an invalid state for its kind."
    case .invalidDecisionSubject(let id): "Decision \(id) needs a non-empty subject."
    case .invalidRelation(let id): "Relation \(id) has a missing or invalid endpoint."
    case .crossProjectRelation(let id): "Relation \(id) crosses project boundaries."
    case .duplicateGoverningDecision(let subject):
      "More than one governing decision would exist for \(subject)."
    case .nothingToUndo: "There is no latest accepted change to undo."
    }
  }
}

public enum ChangesEngine {
  public static func editProposal(
    id: UUID,
    edit: ProposalEdit,
    in state: inout ProjectState
  ) throws {
    guard let index = state.proposals.firstIndex(where: { $0.id == id }) else {
      throw ChangesEngineError.unknownProposal(id)
    }
    guard
      state.proposals[index].lifecycle == .pending || state.proposals[index].lifecycle == .deferred
    else {
      throw ChangesEngineError.proposalUnavailable(id)
    }
    state.proposals[index].userEdits.append(edit)
    state.proposals[index].lifecycle = .pending
    invalidateDependents(of: id, in: &state)
  }

  public static func deferProposal(id: UUID, in state: inout ProjectState) throws {
    try setReviewLifecycle(.deferred, id: id, in: &state)
  }

  public static func rejectProposal(id: UUID, in state: inout ProjectState) throws {
    try setReviewLifecycle(.rejected, id: id, in: &state)
    invalidateDependents(of: id, in: &state)
  }

  public static func restoreRejectedProposal(id: UUID, in state: inout ProjectState) throws {
    guard let index = state.proposals.firstIndex(where: { $0.id == id }) else {
      throw ChangesEngineError.unknownProposal(id)
    }
    guard state.proposals[index].lifecycle == .rejected else {
      throw ChangesEngineError.proposalUnavailable(id)
    }
    state.proposals[index].lifecycle = .pending
  }

  public static func accept(
    proposalIDs requestedIDs: Set<UUID>,
    in state: inout ProjectState,
    now: Date = Date()
  ) throws -> ChangeApplicationResult {
    guard !requestedIDs.isEmpty else {
      return ChangeApplicationResult(didChange: false, change: nil)
    }
    let proposalByID = Dictionary(uniqueKeysWithValues: state.proposals.map { ($0.id, $0) })
    let requested = try requestedIDs.map { id -> Proposal in
      guard let proposal = proposalByID[id] else { throw ChangesEngineError.unknownProposal(id) }
      return proposal
    }
    if requested.allSatisfy({ $0.lifecycle == .accepted || $0.lifecycle == .editedAndAccepted }) {
      return ChangeApplicationResult(didChange: false, change: nil)
    }

    var closure = requestedIDs
    var queue = Array(requestedIDs)
    while let id = queue.popLast() {
      guard let proposal = proposalByID[id] else { throw ChangesEngineError.unknownProposal(id) }
      for dependencyID in proposal.dependencyIDs where closure.insert(dependencyID).inserted {
        guard proposalByID[dependencyID] != nil else {
          throw ChangesEngineError.dependencyUnavailable(dependencyID)
        }
        queue.append(dependencyID)
      }
    }
    let selected = closure.compactMap { proposalByID[$0] }
    for proposal in selected {
      guard proposal.projectID == state.project.id else { throw ChangesEngineError.projectMismatch }
      let isAlreadyAccepted =
        proposal.lifecycle == .accepted || proposal.lifecycle == .editedAndAccepted
      guard isAlreadyAccepted || proposal.lifecycle == .pending || proposal.lifecycle == .deferred
      else {
        throw ChangesEngineError.proposalUnavailable(proposal.id)
      }
      if !isAlreadyAccepted, !canRevalidate(proposal, in: state) {
        throw ChangesEngineError.staleProject(
          expected: proposal.contextRevision, actual: state.project.revision)
      }
    }

    var candidate = state
    let beforeByID = Dictionary(uniqueKeysWithValues: candidate.artifacts.map { ($0.id, $0) })
    let ordered = topologicalOrder(
      selected.filter {
        $0.lifecycle == .pending || $0.lifecycle == .deferred
      })
    for proposal in ordered {
      try apply(proposal, to: &candidate, now: now)
    }
    try validate(candidate)

    let affectedIDs = Set(
      ordered.flatMap { proposal -> [UUID] in
        var ids = [
          proposal.operation == .create || proposal.operation == .supersede
            ? proposal.id : proposal.targetID
        ].compactMap { $0 }
        if proposal.operation == .supersede, let targetID = proposal.targetID {
          ids.append(targetID)
        }
        ids.append(contentsOf: proposal.relationships.compactMap(\.targetArtifactID))
        return ids
      })
    candidate.project.revision += 1
    candidate.project.updatedAt = now
    markRecommendationsStale(&candidate)
    let afterByID = Dictionary(uniqueKeysWithValues: candidate.artifacts.map { ($0.id, $0) })
    let change = AcceptedChange(
      projectID: candidate.project.id,
      revision: candidate.project.revision,
      actor: .proposal,
      before: affectedIDs.sorted(by: uuidSort).map {
        ArtifactChangeValue(artifact: beforeByID[$0], relations: beforeByID[$0]?.relations ?? [])
      },
      after: affectedIDs.sorted(by: uuidSort).map {
        ArtifactChangeValue(artifact: afterByID[$0], relations: afterByID[$0]?.relations ?? [])
      },
      rationale: ordered.compactMap(\.rationale).joined(separator: "\n\n").nilIfEmpty,
      evidence: ordered.flatMap(\.evidence),
      originatingProposalIDs: ordered.map(\.id),
      createdAt: now
    )
    candidate.changes.append(change)
    state = candidate
    return ChangeApplicationResult(didChange: true, change: change)
  }

  public static func applyUserArtifact(
    _ desired: Artifact,
    expectedProjectRevision: Int,
    expectedArtifactRevision: Int?,
    rationale: String? = nil,
    in state: inout ProjectState,
    now: Date = Date()
  ) throws -> AcceptedChange {
    guard desired.projectID == state.project.id else { throw ChangesEngineError.projectMismatch }
    guard expectedProjectRevision == state.project.revision else {
      throw ChangesEngineError.staleProject(
        expected: expectedProjectRevision, actual: state.project.revision)
    }
    guard desired.kind.permits(desired.state) else {
      throw ChangesEngineError.invalidArtifactState(desired.id)
    }
    try validateResearchQualification(desired)

    var candidate = state
    let index = candidate.artifacts.firstIndex(where: { $0.id == desired.id })
    let before = index.map { candidate.artifacts[$0] }
    if let before, let expectedArtifactRevision, before.version != expectedArtifactRevision {
      throw ChangesEngineError.staleArtifact(
        desired.id, expected: expectedArtifactRevision, actual: before.version)
    }
    if before == nil, expectedArtifactRevision != nil {
      throw ChangesEngineError.unknownArtifact(desired.id)
    }
    var updated = desired
    updated.version = (before?.version ?? 0) + 1
    updated.updatedAt = now
    updated.versions = before?.versions ?? []
    updated.versions.append(versionSnapshot(of: updated, actor: .user, now: now))
    if let index {
      candidate.artifacts[index] = updated
    } else {
      candidate.artifacts.append(updated)
    }
    try validate(candidate)
    let change = finishUserChange(
      before: before, after: updated, rationale: rationale, state: &candidate, now: now)
    state = candidate
    return change
  }

  public static func removeArtifact(
    id: UUID,
    expectedProjectRevision: Int,
    expectedArtifactRevision: Int,
    rationale: String? = nil,
    in state: inout ProjectState,
    now: Date = Date()
  ) throws -> AcceptedChange {
    guard expectedProjectRevision == state.project.revision else {
      throw ChangesEngineError.staleProject(
        expected: expectedProjectRevision, actual: state.project.revision)
    }
    guard let index = state.artifacts.firstIndex(where: { $0.id == id }) else {
      throw ChangesEngineError.unknownArtifact(id)
    }
    let before = state.artifacts[index]
    guard before.version == expectedArtifactRevision else {
      throw ChangesEngineError.staleArtifact(
        id, expected: expectedArtifactRevision, actual: before.version)
    }
    var candidate = state
    let affectedIDs = Set(
      candidate.artifacts.compactMap { artifact in
        artifact.id == id
          || artifact.relations.contains(where: {
            $0.sourceArtifactID == id || $0.targetArtifactID == id
          }) ? artifact.id : nil
      })
    let beforeByID = Dictionary(uniqueKeysWithValues: candidate.artifacts.map { ($0.id, $0) })
    var removed = before
    removed.state = .removed
    removed.version += 1
    removed.updatedAt = now
    removed.relations.removeAll()
    removed.versions.append(versionSnapshot(of: removed, actor: .user, now: now))
    candidate.artifacts[index] = removed
    for relationIndex in candidate.artifacts.indices {
      candidate.artifacts[relationIndex].relations.removeAll {
        $0.sourceArtifactID == id || $0.targetArtifactID == id
      }
    }
    try validate(candidate)
    candidate.project.revision += 1
    candidate.project.updatedAt = now
    markRecommendationsStale(&candidate)
    let afterByID = Dictionary(uniqueKeysWithValues: candidate.artifacts.map { ($0.id, $0) })
    let change = AcceptedChange(
      projectID: candidate.project.id,
      revision: candidate.project.revision,
      actor: .user,
      before: affectedIDs.sorted(by: uuidSort).map {
        ArtifactChangeValue(artifact: beforeByID[$0], relations: beforeByID[$0]?.relations ?? [])
      },
      after: affectedIDs.sorted(by: uuidSort).map {
        ArtifactChangeValue(artifact: afterByID[$0], relations: afterByID[$0]?.relations ?? [])
      },
      rationale: rationale,
      evidence: removed.evidence,
      createdAt: now
    )
    candidate.changes.append(change)
    state = candidate
    return change
  }

  public static func undoLatest(in state: inout ProjectState, now: Date = Date()) throws
    -> AcceptedChange
  {
    let undoneTransactions = Set(state.changes.compactMap(\.undoOfTransactionID))
    guard
      let original = state.changes.last(where: {
        $0.actor != .undo && !undoneTransactions.contains($0.transactionID)
      })
    else {
      throw ChangesEngineError.nothingToUndo
    }
    var candidate = state
    let currentByID = Dictionary(uniqueKeysWithValues: candidate.artifacts.map { ($0.id, $0) })
    let affectedIDs = Set((original.before + original.after).compactMap { $0.artifact?.id })
    let beforeUndo = affectedIDs.sorted(by: uuidSort).map {
      ArtifactChangeValue(artifact: currentByID[$0], relations: currentByID[$0]?.relations ?? [])
    }

    for snapshot in original.before {
      guard let artifact = snapshot.artifact else { continue }
      if let index = candidate.artifacts.firstIndex(where: { $0.id == artifact.id }) {
        candidate.artifacts[index] = artifact
      } else {
        candidate.artifacts.append(artifact)
      }
    }
    let originalCreatedIDs = Set(original.after.compactMap(\.artifact?.id)).subtracting(
      original.before.compactMap(\.artifact?.id))
    candidate.artifacts.removeAll { originalCreatedIDs.contains($0.id) }
    if original.actor == .proposal {
      for index in candidate.proposals.indices
      where original.originatingProposalIDs.contains(candidate.proposals[index].id) {
        candidate.proposals[index].lifecycle = .pending
      }
    }
    try validate(candidate)
    candidate.project.revision += 1
    candidate.project.updatedAt = now
    markRecommendationsStale(&candidate)
    let restoredByID = Dictionary(uniqueKeysWithValues: candidate.artifacts.map { ($0.id, $0) })
    let undo = AcceptedChange(
      projectID: candidate.project.id,
      revision: candidate.project.revision,
      actor: .undo,
      before: beforeUndo,
      after: affectedIDs.sorted(by: uuidSort).map {
        ArtifactChangeValue(
          artifact: restoredByID[$0], relations: restoredByID[$0]?.relations ?? [])
      },
      rationale: "Undo accepted change at revision \(original.revision)",
      evidence: original.evidence,
      originatingProposalIDs: original.originatingProposalIDs,
      undoOfTransactionID: original.transactionID,
      createdAt: now
    )
    candidate.changes.append(undo)
    state = candidate
    return undo
  }

  private static func apply(_ proposal: Proposal, to state: inout ProjectState, now: Date) throws {
    let edit = proposal.userEdits.last
    let title = edit?.title ?? proposal.title
    let content = edit?.content ?? proposal.content
    let rationale = edit?.rationale ?? proposal.rationale
    let subject = edit?.decisionSubject ?? proposal.decisionSubject
    let certainty = edit?.certainty ?? proposal.certainty
    let limitations = edit?.limitations ?? proposal.limitations

    switch proposal.operation {
    case .create:
      let artifact = Artifact(
        id: proposal.id,
        projectID: state.project.id,
        kind: proposal.kind,
        title: title,
        content: content,
        state: proposal.proposedState,
        rationale: rationale,
        evidence: proposal.evidence,
        decisionSubject: subject,
        certainty: certainty,
        limitations: limitations,
        createdAt: now,
        updatedAt: now
      )
      state.artifacts.append(withInitialVersion(artifact, actor: .proposal, now: now))
    case .update, .relate:
      guard let targetID = proposal.targetID,
        let index = state.artifacts.firstIndex(where: { $0.id == targetID })
      else {
        throw ChangesEngineError.unknownArtifact(proposal.targetID ?? proposal.id)
      }
      guard state.artifacts[index].version == proposal.expectedTargetRevision else {
        throw ChangesEngineError.staleArtifact(
          targetID, expected: proposal.expectedTargetRevision ?? -1,
          actual: state.artifacts[index].version)
      }
      if proposal.operation == .update {
        state.artifacts[index].title = title
        state.artifacts[index].content = content
        state.artifacts[index].rationale = rationale
        state.artifacts[index].decisionSubject = subject
        state.artifacts[index].certainty = certainty
        state.artifacts[index].limitations = limitations
        state.artifacts[index].evidence = proposal.evidence
        if let proposedState = proposal.proposedState {
          state.artifacts[index].state = proposedState
        }
      }
      state.artifacts[index].version += 1
      state.artifacts[index].updatedAt = now
      state.artifacts[index].versions.append(
        versionSnapshot(of: state.artifacts[index], actor: .proposal, now: now))
    case .supersede:
      guard let targetID = proposal.targetID,
        let oldIndex = state.artifacts.firstIndex(where: { $0.id == targetID })
      else {
        throw ChangesEngineError.unknownArtifact(proposal.targetID ?? proposal.id)
      }
      guard state.artifacts[oldIndex].version == proposal.expectedTargetRevision else {
        throw ChangesEngineError.staleArtifact(
          targetID, expected: proposal.expectedTargetRevision ?? -1,
          actual: state.artifacts[oldIndex].version)
      }
      state.artifacts[oldIndex].state = .superseded
      state.artifacts[oldIndex].decisionSubject = subject
      state.artifacts[oldIndex].version += 1
      state.artifacts[oldIndex].updatedAt = now
      state.artifacts[oldIndex].versions.append(
        versionSnapshot(of: state.artifacts[oldIndex], actor: .proposal, now: now))
      let replacement = Artifact(
        id: proposal.id,
        projectID: state.project.id,
        kind: .decision,
        title: title,
        content: content,
        state: .governing,
        rationale: rationale,
        evidence: proposal.evidence,
        decisionSubject: subject,
        certainty: certainty,
        limitations: limitations,
        supersedesArtifactID: targetID,
        createdAt: now,
        updatedAt: now
      )
      state.artifacts.append(withInitialVersion(replacement, actor: .proposal, now: now))
    }

    guard
      let sourceID = proposal.operation == .update || proposal.operation == .relate
        ? proposal.targetID : proposal.id
    else {
      throw ChangesEngineError.unknownArtifact(proposal.id)
    }
    guard let sourceIndex = state.artifacts.firstIndex(where: { $0.id == sourceID }) else {
      throw ChangesEngineError.unknownArtifact(sourceID)
    }
    for relation in proposal.relationships {
      let targetID = relation.targetArtifactID ?? relation.targetProposalID!
      let artifactRelation = ArtifactRelation(
        projectID: state.project.id,
        sourceArtifactID: sourceID,
        targetArtifactID: targetID,
        type: relation.type
      )
      if !state.artifacts[sourceIndex].relations.contains(where: {
        $0.sourceArtifactID == sourceID && $0.targetArtifactID == targetID
          && $0.type == relation.type
      }) {
        state.artifacts[sourceIndex].relations.append(artifactRelation)
      }
    }
    if proposal.operation == .supersede, let oldID = proposal.targetID {
      state.artifacts[sourceIndex].relations.append(
        ArtifactRelation(
          projectID: state.project.id,
          sourceArtifactID: sourceID,
          targetArtifactID: oldID,
          type: .supersedes
        ))
    }
    if let proposalIndex = state.proposals.firstIndex(where: { $0.id == proposal.id }) {
      state.proposals[proposalIndex].lifecycle =
        proposal.userEdits.isEmpty ? .accepted : .editedAndAccepted
    }
  }

  private static func setReviewLifecycle(
    _ lifecycle: ProposalLifecycle,
    id: UUID,
    in state: inout ProjectState
  ) throws {
    guard let index = state.proposals.firstIndex(where: { $0.id == id }) else {
      throw ChangesEngineError.unknownProposal(id)
    }
    guard
      state.proposals[index].lifecycle == .pending || state.proposals[index].lifecycle == .deferred
    else {
      throw ChangesEngineError.proposalUnavailable(id)
    }
    state.proposals[index].lifecycle = lifecycle
  }

  private static func invalidateDependents(of id: UUID, in state: inout ProjectState) {
    var invalidated: Set<UUID> = [id]
    var changed = true
    while changed {
      changed = false
      for proposal in state.proposals
      where
        (proposal.lifecycle == .pending || proposal.lifecycle == .deferred)
        && !invalidated.contains(proposal.id)
        && !Set(proposal.dependencyIDs).isDisjoint(with: invalidated)
      {
        invalidated.insert(proposal.id)
        changed = true
      }
    }
    for index in state.proposals.indices
    where invalidated.contains(state.proposals[index].id) && state.proposals[index].id != id {
      state.proposals[index].lifecycle = .invalidated
    }
  }

  private static func validate(_ state: ProjectState) throws {
    let artifacts = Dictionary(uniqueKeysWithValues: state.artifacts.map { ($0.id, $0) })
    for artifact in state.artifacts {
      guard artifact.projectID == state.project.id else { throw ChangesEngineError.projectMismatch }
      guard artifact.kind.permits(artifact.state) else {
        throw ChangesEngineError.invalidArtifactState(artifact.id)
      }
      try validateResearchQualification(artifact)
      for relation in artifact.relations {
        guard relation.projectID == state.project.id else {
          throw ChangesEngineError.crossProjectRelation(relation.id)
        }
        guard relation.sourceArtifactID == artifact.id,
          let target = artifacts[relation.targetArtifactID],
          target.projectID == state.project.id,
          target.state != .removed,
          relation.targetArtifactID != artifact.id
        else { throw ChangesEngineError.invalidRelation(relation.id) }
      }
    }
    let governing = Dictionary(
      grouping: state.artifacts.filter {
        $0.kind == .decision && $0.state == .governing && $0.decisionSubject != nil
      },
      by: {
        $0.decisionSubject!.folding(
          options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      })
    if let duplicate = governing.first(where: { $0.value.count > 1 }) {
      throw ChangesEngineError.duplicateGoverningDecision(duplicate.key)
    }
  }

  private static func topologicalOrder(_ proposals: [Proposal]) -> [Proposal] {
    let byID = Dictionary(uniqueKeysWithValues: proposals.map { ($0.id, $0) })
    var visited: Set<UUID> = []
    var ordered: [Proposal] = []
    func visit(_ proposal: Proposal) {
      guard visited.insert(proposal.id).inserted else { return }
      for dependencyID in proposal.dependencyIDs.sorted(by: uuidSort) {
        if let dependency = byID[dependencyID] { visit(dependency) }
      }
      ordered.append(proposal)
    }
    for proposal in proposals.sorted(by: { uuidSort($0.id, $1.id) }) { visit(proposal) }
    return ordered
  }

  private static func canRevalidate(_ proposal: Proposal, in state: ProjectState) -> Bool {
    if proposal.contextRevision == state.project.revision { return true }
    guard proposal.contextRevision < state.project.revision else { return false }
    let allowedInterveningProposalIDs = Set(proposal.dependencyIDs)
    let intervening = state.changes.filter { $0.revision > proposal.contextRevision }
    let expectedRevisions = Array((proposal.contextRevision + 1)...state.project.revision)
    guard intervening.map(\.revision).sorted() == expectedRevisions else { return false }
    guard
      intervening.allSatisfy({ change in
        !change.originatingProposalIDs.isEmpty
          && Set(change.originatingProposalIDs).isSubset(of: allowedInterveningProposalIDs)
      })
    else { return false }
    if let targetID = proposal.targetID,
      let expectedTargetRevision = proposal.expectedTargetRevision
    {
      return state.artifacts.first(where: { $0.id == targetID })?.version == expectedTargetRevision
    }
    return true
  }

  private static func validateResearchQualification(_ artifact: Artifact) throws {
    guard artifact.kind == .research else { return }
    guard artifact.certainty?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
      artifact.limitations?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    else { throw ChangesEngineError.invalidArtifactState(artifact.id) }
  }

  private static func withInitialVersion(_ artifact: Artifact, actor: ChangeActor, now: Date)
    -> Artifact
  {
    var artifact = artifact
    artifact.versions.append(versionSnapshot(of: artifact, actor: actor, now: now))
    return artifact
  }

  private static func versionSnapshot(of artifact: Artifact, actor: ChangeActor, now: Date)
    -> ArtifactVersion
  {
    ArtifactVersion(
      artifactID: artifact.id,
      version: artifact.version,
      title: artifact.title,
      content: artifact.content,
      state: artifact.state,
      rationale: artifact.rationale,
      evidence: artifact.evidence,
      actor: actor,
      createdAt: now
    )
  }

  private static func finishUserChange(
    before: Artifact?,
    after: Artifact,
    rationale: String?,
    state: inout ProjectState,
    now: Date
  ) -> AcceptedChange {
    state.project.revision += 1
    state.project.updatedAt = now
    markRecommendationsStale(&state)
    let change = AcceptedChange(
      projectID: state.project.id,
      revision: state.project.revision,
      actor: .user,
      before: [ArtifactChangeValue(artifact: before, relations: before?.relations ?? [])],
      after: [ArtifactChangeValue(artifact: after, relations: after.relations)],
      rationale: rationale,
      evidence: after.evidence,
      createdAt: now
    )
    state.changes.append(change)
    return change
  }

  private static func markRecommendationsStale(_ state: inout ProjectState) {
    for index in state.recommendations.indices
    where state.recommendations[index].originatingRevision != state.project.revision {
      state.recommendations[index].isStale = true
    }
  }

  private static func uuidSort(_ lhs: UUID, _ rhs: UUID) -> Bool {
    lhs.uuidString < rhs.uuidString
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
