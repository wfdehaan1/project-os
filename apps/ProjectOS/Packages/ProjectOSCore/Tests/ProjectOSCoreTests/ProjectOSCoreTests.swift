import Foundation
import Testing

@testable import ProjectOSCore

@Suite("Frozen context")
struct ContextBuilderTests {
  @Test("freezes exact Unicode and excludes incomplete transcript")
  func exactUnicodeAndCompletion() throws {
    let project = Project(name: "Studio", description: "Een rustige werkplek")
    let source = SourceDocument(
      projectID: project.id,
      label: "Budgetnotitie",
      text: "Budget: €12.000 — inclusief isolatie."
    )
    let conversationID = UUID()
    let partial = Message(
      projectID: project.id,
      conversationID: conversationID,
      role: .assistant,
      text: "Half antwoord",
      completion: .partial
    )

    let snapshot = try ContextBuilder.freeze(
      project: project,
      sources: [source],
      messages: [],
      artifacts: [],
      selection: ContextSelectionRequest(sourceIDs: [source.id]),
      providerID: "ollama",
      modelID: "local-model",
      configurationID: "default",
      purpose: .chat,
      maximumCharacters: 1_000
    )
    #expect(snapshot.selections.contains(where: { $0.text == source.text }))

    #expect(throws: ContextBuilderError.incompleteMessage(partial.id)) {
      try ContextBuilder.freeze(
        project: project,
        sources: [],
        messages: [partial],
        artifacts: [],
        selection: ContextSelectionRequest(
          includeProjectDescription: false, messageIDs: [partial.id]),
        providerID: "ollama",
        modelID: "local-model",
        configurationID: "default",
        purpose: .chat,
        maximumCharacters: 1_000
      )
    }
  }

  @Test("unknown and exceeded bounds fail closed")
  func bounds() throws {
    let project = Project(name: "P", description: "123456")
    let request = ContextSelectionRequest()
    #expect(throws: ContextBuilderError.unknownBound) {
      try ContextBuilder.freeze(
        project: project,
        sources: [], messages: [], artifacts: [], selection: request,
        providerID: "ollama", modelID: "m", configurationID: "c", purpose: .chat,
        maximumCharacters: nil
      )
    }
    #expect(throws: ContextBuilderError.self) {
      try ContextBuilder.freeze(
        project: project,
        sources: [], messages: [], artifacts: [], selection: request,
        providerID: "ollama", modelID: "m", configurationID: "c", purpose: .chat,
        maximumCharacters: 2
      )
    }
  }
}

@Suite("Proposal validation")
struct ProposalValidatorTests {
  @Test("bundled proposal schema is available and valid JSON")
  func bundledSchema() throws {
    let data = try ProposalSchema.data()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["type"] as? String == "object")
  }

  @Test("accepts exact repeated Unicode quote and rejects unknown properties")
  func exactQuoteAndStrictKeys() throws {
    let project = Project(name: "Garden")
    let source = SourceDocument(
      projectID: project.id,
      label: "Notes",
      text: "Drainage blijft open. Budget €12.000. Drainage blijft open."
    )
    let context = try ContextBuilder.freeze(
      project: project,
      sources: [source], messages: [], artifacts: [],
      selection: ContextSelectionRequest(includeProjectDescription: false, sourceIDs: [source.id]),
      providerID: "ollama", modelID: "m", configurationID: "c", purpose: .proposals,
      maximumCharacters: 2_000
    )
    let proposalID = UUID()
    let object = proposalObject(
      proposalID: proposalID,
      kind: "decision",
      subject: "drainage",
      evidence: [
        [
          "sourceType": "source",
          "referenceID": source.id.uuidString,
          "version": 1,
          "quote": "Drainage blijft open.",
        ]
      ]
    )
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let batch = try ProposalValidator.validate(
      data: data,
      projectID: project.id,
      jobID: UUID(),
      context: context,
      currentProjectRevision: project.revision,
      currentArtifacts: []
    )
    #expect(batch.proposals.first?.evidence.first?.quote == "Drainage blijft open.")

    var invalid = object
    invalid["unexpected"] = true
    let invalidData = try JSONSerialization.data(withJSONObject: invalid)
    #expect(throws: ProposalValidationError.self) {
      try ProposalValidator.validate(
        data: invalidData,
        projectID: project.id,
        jobID: UUID(),
        context: context,
        currentProjectRevision: project.revision,
        currentArtifacts: []
      )
    }
  }

  @Test("does not treat assistant-only evidence as a user decision")
  func assistantEvidenceIsUnverified() throws {
    let project = Project(name: "Garden")
    let conversationID = UUID()
    let message = Message(
      projectID: project.id,
      conversationID: conversationID,
      role: .assistant,
      text: "You have decided to use fibre."
    )
    let context = try ContextBuilder.freeze(
      project: project,
      sources: [], messages: [message], artifacts: [],
      selection: ContextSelectionRequest(
        includeProjectDescription: false, messageIDs: [message.id]),
      providerID: "openrouter", modelID: "model", configurationID: "pinned", purpose: .proposals,
      maximumCharacters: 2_000
    )
    let object = proposalObject(
      proposalID: UUID(),
      kind: "decision",
      subject: "network cable",
      evidence: [
        [
          "sourceType": "message",
          "referenceID": message.id.uuidString,
          "version": 1,
          "quote": message.text,
        ]
      ]
    )
    let data = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: ProposalValidationError.self) {
      try ProposalValidator.validate(
        data: data,
        projectID: project.id,
        jobID: UUID(),
        context: context,
        currentProjectRevision: project.revision,
        currentArtifacts: []
      )
    }
  }

  @Test("stale structured results do not publish")
  func staleContext() throws {
    let project = Project(name: "P")
    let context = ContextSnapshot(
      projectID: project.id,
      projectRevision: 0,
      providerID: "ollama",
      modelID: "m",
      configurationID: "c",
      purpose: .proposals,
      selections: []
    )
    let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "proposals": []])
    #expect(throws: ProposalValidationError.staleContext(expected: 0, actual: 1)) {
      try ProposalValidator.validate(
        data: data,
        projectID: project.id,
        jobID: UUID(),
        context: context,
        currentProjectRevision: 1,
        currentArtifacts: []
      )
    }
  }

  private func proposalObject(
    proposalID: UUID,
    kind: String,
    subject: String?,
    evidence: [[String: Any]]
  ) -> [String: Any] {
    [
      "schemaVersion": 1,
      "proposals": [
        [
          "temporaryID": proposalID.uuidString,
          "operation": "create",
          "kind": kind,
          "targetID": NSNull(),
          "expectedTargetRevision": NSNull(),
          "title": "A consequential update",
          "content": "Keep the exact commitment.",
          "rationale": "Recorded for continuity",
          "decisionSubject": subject ?? NSNull(),
          "state": NSNull(),
          "certainty": NSNull(),
          "limitations": NSNull(),
          "evidence": evidence,
          "relationships": [],
          "dependencyIDs": [],
        ]
      ],
    ]
  }
}

@Suite("Accepted changes")
struct ChangesEngineTests {
  @Test("accepts dependency closure atomically and is idempotent")
  func dependenciesAndIdempotency() throws {
    let project = Project(name: "Garden")
    let jobID = UUID()
    let researchID = UUID()
    let decisionID = UUID()
    let research = Proposal(
      id: researchID,
      projectID: project.id,
      jobID: jobID,
      contextRevision: 0,
      operation: .create,
      kind: .research,
      title: "Electrical isolation",
      content: "Fibre is electrically isolated.",
      certainty: "high for the stated property",
      limitations: "installation conditions not assessed"
    )
    let decision = Proposal(
      id: decisionID,
      projectID: project.id,
      jobID: jobID,
      contextRevision: 0,
      operation: .create,
      kind: .decision,
      title: "Use fibre",
      content: "Use fibre between buildings.",
      decisionSubject: "network medium",
      relationships: [ProposalRelation(type: .supports, targetProposalID: researchID)],
      dependencyIDs: [researchID]
    )
    var state = ProjectState(project: project, proposals: [research, decision])

    let result = try ChangesEngine.accept(proposalIDs: [decisionID], in: &state)
    #expect(result.didChange)
    #expect(state.project.revision == 1)
    #expect(state.artifacts.count == 2)
    #expect(
      state.artifacts.first(where: { $0.id == decisionID })?.relations.first?.targetArtifactID
        == researchID)
    #expect(state.proposals.allSatisfy { $0.lifecycle == .accepted })

    let duplicate = try ChangesEngine.accept(proposalIDs: [decisionID], in: &state)
    #expect(!duplicate.didChange)
    #expect(state.project.revision == 1)
  }

  @Test("supersession has one governing decision and undo restores lineage")
  func supersessionAndUndo() throws {
    let project = Project(name: "Garden")
    let prior = Artifact(
      projectID: project.id,
      kind: .decision,
      title: "Use copper",
      content: "Use copper Ethernet.",
      decisionSubject: "network medium"
    )
    let replacementID = UUID()
    let proposal = Proposal(
      id: replacementID,
      projectID: project.id,
      jobID: UUID(),
      contextRevision: 0,
      operation: .supersede,
      kind: .decision,
      targetID: prior.id,
      expectedTargetRevision: 1,
      title: "Use fibre",
      content: "Use fibre for electrical isolation.",
      decisionSubject: "network medium"
    )
    var state = ProjectState(project: project, artifacts: [prior], proposals: [proposal])

    _ = try ChangesEngine.accept(proposalIDs: [proposal.id], in: &state)
    #expect(state.artifacts.filter { $0.state == .governing }.map(\.id) == [replacementID])
    #expect(state.artifacts.first(where: { $0.id == prior.id })?.state == .superseded)

    let undo = try ChangesEngine.undoLatest(in: &state)
    #expect(undo.actor == .undo)
    #expect(state.project.revision == 2)
    #expect(state.artifacts.count == 1)
    #expect(state.artifacts.first?.id == prior.id)
    #expect(state.artifacts.first?.state == .governing)
    #expect(state.proposals.first?.lifecycle == .pending)
    #expect(state.changes.count == 2)
  }

  @Test("an already accepted dependency can be deterministically revalidated")
  func acceptedDependencyRevalidation() throws {
    let project = Project(name: "P")
    let topic = Proposal(
      projectID: project.id, jobID: UUID(), contextRevision: 0,
      operation: .create, kind: .topic, title: "Scope", content: "MVP"
    )
    let task = Proposal(
      projectID: project.id, jobID: UUID(), contextRevision: 0,
      operation: .create, kind: .task, title: "Ship", content: "Ship MVP",
      relationships: [ProposalRelation(type: .concerns, targetProposalID: topic.id)],
      dependencyIDs: [topic.id]
    )
    var state = ProjectState(project: project, proposals: [topic, task])
    _ = try ChangesEngine.accept(proposalIDs: [topic.id], in: &state)
    _ = try ChangesEngine.accept(proposalIDs: [task.id], in: &state)
    #expect(state.project.revision == 2)
    #expect(
      state.artifacts.first(where: { $0.id == task.id })?.relations.first?.targetArtifactID
        == topic.id)
  }

  @Test("stale acceptance leaves state unchanged")
  func staleAcceptance() throws {
    var project = Project(name: "P")
    project.revision = 2
    let proposal = Proposal(
      projectID: project.id,
      jobID: UUID(),
      contextRevision: 1,
      operation: .create,
      kind: .task,
      title: "Old task",
      content: "Generated from old context"
    )
    var state = ProjectState(project: project, proposals: [proposal])
    let original = state
    #expect(throws: ChangesEngineError.staleProject(expected: 1, actual: 2)) {
      try ChangesEngine.accept(proposalIDs: [proposal.id], in: &state)
    }
    #expect(state == original)
  }

  @Test("removal and undo preserve inbound relations")
  func removalUndo() throws {
    let project = Project(name: "P")
    let topic = Artifact(projectID: project.id, kind: .topic, title: "Scope", content: "MVP scope")
    var task = Artifact(projectID: project.id, kind: .task, title: "Build", content: "Build MVP")
    task.relations = [
      ArtifactRelation(
        projectID: project.id,
        sourceArtifactID: task.id,
        targetArtifactID: topic.id,
        type: .concerns
      )
    ]
    var state = ProjectState(project: project, artifacts: [topic, task])
    _ = try ChangesEngine.removeArtifact(
      id: topic.id,
      expectedProjectRevision: 0,
      expectedArtifactRevision: 1,
      in: &state
    )
    #expect(state.artifacts.first(where: { $0.id == topic.id })?.state == .removed)
    #expect(state.artifacts.first(where: { $0.id == task.id })?.relations.isEmpty == true)
    _ = try ChangesEngine.undoLatest(in: &state)
    #expect(state.artifacts.first(where: { $0.id == topic.id })?.state == .active)
    #expect(state.artifacts.first(where: { $0.id == task.id })?.relations.count == 1)
  }

  @Test("editing or rejecting a dependency invalidates dependents")
  func dependentReviewInvalidation() throws {
    let project = Project(name: "P")
    let dependency = Proposal(
      projectID: project.id, jobID: UUID(), contextRevision: 0,
      operation: .create, kind: .topic, title: "Topic", content: "Scope"
    )
    let dependent = Proposal(
      projectID: project.id, jobID: UUID(), contextRevision: 0,
      operation: .create, kind: .task, title: "Task", content: "Do work",
      dependencyIDs: [dependency.id]
    )
    var state = ProjectState(project: project, proposals: [dependency, dependent])
    try ChangesEngine.rejectProposal(id: dependency.id, in: &state)
    #expect(state.proposals.first(where: { $0.id == dependency.id })?.lifecycle == .rejected)
    #expect(state.proposals.first(where: { $0.id == dependent.id })?.lifecycle == .invalidated)
    try ChangesEngine.restoreRejectedProposal(id: dependency.id, in: &state)
    #expect(state.proposals.first(where: { $0.id == dependency.id })?.lifecycle == .pending)
  }
}
