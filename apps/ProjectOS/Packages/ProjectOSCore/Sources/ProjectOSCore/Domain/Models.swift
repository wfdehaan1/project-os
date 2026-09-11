import Foundation

public enum ArtifactKind: String, Codable, CaseIterable, Sendable {
  case topic
  case research
  case decision
  case openQuestion = "open_question"
  case task
}

public enum ArtifactState: String, Codable, CaseIterable, Sendable {
  case active
  case governing
  case superseded
  case open
  case resolved
  case dismissed
  case inProgress = "in_progress"
  case blocked
  case done
  case removed
}

public enum MessageRole: String, Codable, CaseIterable, Sendable {
  case system
  case user
  case assistant
}

public enum MessageCompletion: String, Codable, CaseIterable, Sendable {
  case complete
  case partial
  case failed
  case cancelled
}

public typealias State = ArtifactState
public typealias Completion = MessageCompletion

public enum ProposalLifecycle: String, Codable, CaseIterable, Sendable {
  case pending
  case deferred
  case accepted
  case editedAndAccepted = "edited_and_accepted"
  case rejected
  case invalidated
}

public enum RelationType: String, Codable, CaseIterable, Sendable {
  case supports
  case concerns
  case advances
  case blocks
  case supersedes
}

public enum ProposalOperation: String, Codable, CaseIterable, Sendable {
  case create
  case update
  case supersede
  case relate
}

public enum EvidenceSourceType: String, Codable, CaseIterable, Sendable {
  case source
  case message
}

public enum ChangeActor: String, Codable, CaseIterable, Sendable {
  case user
  case proposal
  case undo
}

public enum JobPurpose: String, Codable, CaseIterable, Sendable {
  case chat
  case proposals
  case nextAction = "next_action"
}

public enum JobStatus: String, Codable, CaseIterable, Sendable {
  case queued
  case running
  case completed
  case failed
  case cancelled
  case interrupted
}

public enum ContextSelectionKind: String, Codable, CaseIterable, Sendable {
  case projectDescription = "project_description"
  case source
  case message
  case artifact
}

public enum ProjectOutcome: String, Codable, CaseIterable, Sendable {
  case successfulCompletion = "successful_completion"
  case intentionalClosure = "intentional_closure"
  case abandoned
  case unresolved
}

public enum RecommendationOutcome: String, Codable, CaseIterable, Sendable {
  case followedRecommendation = "followed_recommendation"
  case differentAction = "different_action"
  case noAction = "no_action"
}

public struct Project: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var name: String
  public var description: String
  public var createdAt: Date
  public var updatedAt: Date
  public var revision: Int
  public var lastVisitBaseline: Int
  public var outcome: ProjectOutcome?

  public init(
    id: UUID = UUID(),
    name: String,
    description: String = "",
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    revision: Int = 0,
    lastVisitBaseline: Int = 0,
    outcome: ProjectOutcome? = nil
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.revision = revision
    self.lastVisitBaseline = lastVisitBaseline
    self.outcome = outcome
  }
}

public struct SourceDocument: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var label: String
  public var text: String
  public var version: Int
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    label: String,
    text: String,
    version: Int = 1,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.label = label
    self.text = text
    self.version = version
    self.createdAt = createdAt
  }
}

public struct Conversation: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var title: String
  public var draft: String
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    title: String = "New conversation",
    draft: String = "",
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.title = title
    self.draft = draft
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct Message: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var conversationID: UUID
  public var role: MessageRole
  public var text: String
  public var version: Int
  public var completion: MessageCompletion
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    conversationID: UUID,
    role: MessageRole,
    text: String,
    version: Int = 1,
    completion: MessageCompletion = .complete,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.conversationID = conversationID
    self.role = role
    self.text = text
    self.version = version
    self.completion = completion
    self.createdAt = createdAt
  }
}

public struct EvidenceReference: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var sourceType: EvidenceSourceType
  public var referenceID: UUID
  public var version: Int
  public var quote: String
  public var isAIAuthored: Bool

  public init(
    id: UUID = UUID(),
    sourceType: EvidenceSourceType,
    referenceID: UUID,
    version: Int,
    quote: String,
    isAIAuthored: Bool = false
  ) {
    self.id = id
    self.sourceType = sourceType
    self.referenceID = referenceID
    self.version = version
    self.quote = quote
    self.isAIAuthored = isAIAuthored
  }
}

public struct ArtifactRelation: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var sourceArtifactID: UUID
  public var targetArtifactID: UUID
  public var type: RelationType

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    sourceArtifactID: UUID,
    targetArtifactID: UUID,
    type: RelationType
  ) {
    self.id = id
    self.projectID = projectID
    self.sourceArtifactID = sourceArtifactID
    self.targetArtifactID = targetArtifactID
    self.type = type
  }
}

public struct ArtifactVersion: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var artifactID: UUID
  public var version: Int
  public var title: String
  public var content: String
  public var state: ArtifactState
  public var rationale: String?
  public var evidence: [EvidenceReference]
  public var actor: ChangeActor
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    artifactID: UUID,
    version: Int,
    title: String,
    content: String,
    state: ArtifactState,
    rationale: String? = nil,
    evidence: [EvidenceReference] = [],
    actor: ChangeActor,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.artifactID = artifactID
    self.version = version
    self.title = title
    self.content = content
    self.state = state
    self.rationale = rationale
    self.evidence = evidence
    self.actor = actor
    self.createdAt = createdAt
  }
}

public struct Artifact: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var kind: ArtifactKind
  public var title: String
  public var content: String
  public var state: ArtifactState
  public var rationale: String?
  public var evidence: [EvidenceReference]
  public var relations: [ArtifactRelation]
  public var versions: [ArtifactVersion]
  public var decisionSubject: String?
  public var certainty: String?
  public var limitations: String?
  public var supersedesArtifactID: UUID?
  public var version: Int
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    kind: ArtifactKind,
    title: String,
    content: String,
    state: ArtifactState? = nil,
    rationale: String? = nil,
    evidence: [EvidenceReference] = [],
    relations: [ArtifactRelation] = [],
    versions: [ArtifactVersion] = [],
    decisionSubject: String? = nil,
    certainty: String? = nil,
    limitations: String? = nil,
    supersedesArtifactID: UUID? = nil,
    version: Int = 1,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.kind = kind
    self.title = title
    self.content = content
    self.state = state ?? kind.defaultState
    self.rationale = rationale
    self.evidence = evidence
    self.relations = relations
    self.versions = versions
    self.decisionSubject = decisionSubject
    self.certainty = certainty
    self.limitations = limitations
    self.supersedesArtifactID = supersedesArtifactID
    self.version = version
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension ArtifactKind {
  public var defaultState: ArtifactState {
    switch self {
    case .topic, .research: .active
    case .decision: .governing
    case .openQuestion, .task: .open
    }
  }

  public func permits(_ state: ArtifactState) -> Bool {
    if state == .removed { return true }
    switch self {
    case .topic, .research:
      return state == .active
    case .decision:
      return state == .governing || state == .superseded
    case .openQuestion:
      return state == .open || state == .resolved || state == .dismissed
    case .task:
      return state == .open || state == .inProgress || state == .blocked || state == .done
    }
  }
}

public struct ProposalRelation: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var type: RelationType
  public var targetArtifactID: UUID?
  public var targetProposalID: UUID?

  public init(
    id: UUID = UUID(),
    type: RelationType,
    targetArtifactID: UUID? = nil,
    targetProposalID: UUID? = nil
  ) {
    self.id = id
    self.type = type
    self.targetArtifactID = targetArtifactID
    self.targetProposalID = targetProposalID
  }
}

public struct ProposalEdit: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var title: String
  public var content: String
  public var rationale: String?
  public var decisionSubject: String?
  public var proposedState: ArtifactState?
  public var certainty: String?
  public var limitations: String?
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    title: String,
    content: String,
    rationale: String? = nil,
    decisionSubject: String? = nil,
    proposedState: ArtifactState? = nil,
    certainty: String? = nil,
    limitations: String? = nil,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.content = content
    self.rationale = rationale
    self.decisionSubject = decisionSubject
    self.proposedState = proposedState
    self.certainty = certainty
    self.limitations = limitations
    self.createdAt = createdAt
  }
}

public struct Proposal: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var jobID: UUID
  public var contextRevision: Int
  public var operation: ProposalOperation
  public var kind: ArtifactKind
  public var targetID: UUID?
  public var expectedTargetRevision: Int?
  public var title: String
  public var content: String
  public var rationale: String?
  public var decisionSubject: String?
  public var proposedState: ArtifactState?
  public var certainty: String?
  public var limitations: String?
  public var evidence: [EvidenceReference]
  public var relationships: [ProposalRelation]
  public var dependencyIDs: [UUID]
  public var lifecycle: ProposalLifecycle
  public var userEdits: [ProposalEdit]
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    jobID: UUID,
    contextRevision: Int,
    operation: ProposalOperation,
    kind: ArtifactKind,
    targetID: UUID? = nil,
    expectedTargetRevision: Int? = nil,
    title: String,
    content: String,
    rationale: String? = nil,
    decisionSubject: String? = nil,
    proposedState: ArtifactState? = nil,
    certainty: String? = nil,
    limitations: String? = nil,
    evidence: [EvidenceReference] = [],
    relationships: [ProposalRelation] = [],
    dependencyIDs: [UUID] = [],
    lifecycle: ProposalLifecycle = .pending,
    userEdits: [ProposalEdit] = [],
    createdAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.jobID = jobID
    self.contextRevision = contextRevision
    self.operation = operation
    self.kind = kind
    self.targetID = targetID
    self.expectedTargetRevision = expectedTargetRevision
    self.title = title
    self.content = content
    self.rationale = rationale
    self.decisionSubject = decisionSubject
    self.proposedState = proposedState
    self.certainty = certainty
    self.limitations = limitations
    self.evidence = evidence
    self.relationships = relationships
    self.dependencyIDs = dependencyIDs
    self.lifecycle = lifecycle
    self.userEdits = userEdits
    self.createdAt = createdAt
  }
}

public struct ProposalBatch: Codable, Hashable, Sendable {
  public var schemaVersion: Int
  public var proposals: [Proposal]

  public init(schemaVersion: Int = 1, proposals: [Proposal]) {
    self.schemaVersion = schemaVersion
    self.proposals = proposals
  }
}

public struct ArtifactChangeValue: Codable, Hashable, Sendable {
  public var artifact: Artifact?
  public var relations: [ArtifactRelation]

  public init(artifact: Artifact?, relations: [ArtifactRelation] = []) {
    self.artifact = artifact
    self.relations = relations
  }
}

public struct AcceptedChange: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var revision: Int
  public var transactionID: UUID
  public var actor: ChangeActor
  public var before: [ArtifactChangeValue]
  public var after: [ArtifactChangeValue]
  public var rationale: String?
  public var evidence: [EvidenceReference]
  public var originatingProposalIDs: [UUID]
  public var undoOfTransactionID: UUID?
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    revision: Int,
    transactionID: UUID = UUID(),
    actor: ChangeActor,
    before: [ArtifactChangeValue],
    after: [ArtifactChangeValue],
    rationale: String? = nil,
    evidence: [EvidenceReference] = [],
    originatingProposalIDs: [UUID] = [],
    undoOfTransactionID: UUID? = nil,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.revision = revision
    self.transactionID = transactionID
    self.actor = actor
    self.before = before
    self.after = after
    self.rationale = rationale
    self.evidence = evidence
    self.originatingProposalIDs = originatingProposalIDs
    self.undoOfTransactionID = undoOfTransactionID
    self.createdAt = createdAt
  }
}

public struct ContextSelection: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var kind: ContextSelectionKind
  public var referenceID: UUID
  public var version: Int
  public var label: String
  public var text: String
  public var statusLabel: String?

  public init(
    id: UUID = UUID(),
    kind: ContextSelectionKind,
    referenceID: UUID,
    version: Int,
    label: String,
    text: String,
    statusLabel: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.referenceID = referenceID
    self.version = version
    self.label = label
    self.text = text
    self.statusLabel = statusLabel
  }
}

public struct ContextSnapshot: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var projectRevision: Int
  public var providerID: String
  public var modelID: String
  public var configurationID: String
  public var purpose: JobPurpose
  public var selections: [ContextSelection]
  public var estimatedCharacters: Int
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    projectRevision: Int,
    providerID: String,
    modelID: String,
    configurationID: String,
    purpose: JobPurpose,
    selections: [ContextSelection],
    estimatedCharacters: Int? = nil,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.projectRevision = projectRevision
    self.providerID = providerID
    self.modelID = modelID
    self.configurationID = configurationID
    self.purpose = purpose
    self.selections = selections
    self.estimatedCharacters = estimatedCharacters ?? selections.reduce(0) { $0 + $1.text.count }
    self.createdAt = createdAt
  }
}

public struct UsageRecord: Codable, Hashable, Sendable {
  public var inputTokens: Int?
  public var outputTokens: Int?
  public var cost: Decimal?
  public var currency: String?

  public init(
    inputTokens: Int? = nil, outputTokens: Int? = nil, cost: Decimal? = nil, currency: String? = nil
  ) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.cost = cost
    self.currency = currency
  }
}

public struct InferenceJob: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var attemptID: UUID
  public var projectID: UUID
  public var context: ContextSnapshot
  public var status: JobStatus
  public var usage: UsageRecord?
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    attemptID: UUID = UUID(),
    projectID: UUID,
    context: ContextSnapshot,
    status: JobStatus = .queued,
    usage: UsageRecord? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.attemptID = attemptID
    self.projectID = projectID
    self.context = context
    self.status = status
    self.usage = usage
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct VersionedArtifactReference: Codable, Hashable, Sendable {
  public var artifactID: UUID
  public var version: Int

  public init(artifactID: UUID, version: Int) {
    self.artifactID = artifactID
    self.version = version
  }
}

public struct SavedRecommendation: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var text: String
  public var supportingArtifacts: [VersionedArtifactReference]
  public var uncertainty: String?
  public var originatingRevision: Int
  public var createdAt: Date
  public var isDismissed: Bool
  public var isStale: Bool

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    text: String,
    supportingArtifacts: [VersionedArtifactReference],
    uncertainty: String? = nil,
    originatingRevision: Int,
    createdAt: Date = Date(),
    isDismissed: Bool = false,
    isStale: Bool = false
  ) {
    self.id = id
    self.projectID = projectID
    self.text = text
    self.supportingArtifacts = supportingArtifacts
    self.uncertainty = uncertainty
    self.originatingRevision = originatingRevision
    self.createdAt = createdAt
    self.isDismissed = isDismissed
    self.isStale = isStale
  }
}

public struct ReturnRecord: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var projectID: UUID
  public var visitBaseline: Int
  public var elapsedSeconds: Int
  public var understandingRating: Int
  public var trustRating: Int
  public var usefulnessRating: Int
  public var resumedWithinFiveMinutes: Bool
  public var recommendationOutcome: RecommendationOutcome
  public var reviewCorrectionSeconds: Int
  public var outcome: ProjectOutcome?
  public var notes: String
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    projectID: UUID,
    visitBaseline: Int,
    elapsedSeconds: Int,
    understandingRating: Int,
    trustRating: Int,
    usefulnessRating: Int,
    resumedWithinFiveMinutes: Bool,
    recommendationOutcome: RecommendationOutcome,
    reviewCorrectionSeconds: Int,
    outcome: ProjectOutcome? = nil,
    notes: String = "",
    createdAt: Date = Date()
  ) {
    self.id = id
    self.projectID = projectID
    self.visitBaseline = visitBaseline
    self.elapsedSeconds = elapsedSeconds
    self.understandingRating = understandingRating
    self.trustRating = trustRating
    self.usefulnessRating = usefulnessRating
    self.resumedWithinFiveMinutes = resumedWithinFiveMinutes
    self.recommendationOutcome = recommendationOutcome
    self.reviewCorrectionSeconds = reviewCorrectionSeconds
    self.outcome = outcome
    self.notes = notes
    self.createdAt = createdAt
  }
}
