import Foundation

struct ProjectRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var summary: String
    var createdAt: Date
    var updatedAt: Date
    var revision: Int
    var previousVisitRevision: Int
}

struct SourceRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    var label: String
    var text: String
    var version: Int
    var createdAt: Date
    /// Set when the text was kept from a web page, so it can be traced back to
    /// it. Pasted sources have none.
    var origin: SourceOrigin? = nil
}

struct ConversationRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    /// The research item this conversation works on. Several conversations can
    /// share one; an ordinary conversation has none.
    var researchID: UUID? = nil
    /// An explicit choice about web research. Unset means the default for this
    /// kind of conversation still applies.
    var webResearch: Bool? = nil
}

extension ConversationRecord {
    /// Whether the model may search the web in this conversation. Research
    /// conversations are for finding things out, so they start with it on;
    /// every other conversation starts with it off.
    var usesWebResearch: Bool {
        webResearch ?? (researchID != nil)
    }
}

enum MessageRole: String, Codable { case user, assistant }
enum MessageCompletion: String, Codable { case complete, partial, failed, cancelled }

struct MessageRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    let conversationID: UUID
    var role: MessageRole
    var text: String
    var completion: MessageCompletion
    var createdAt: Date
    /// What the model did on the web while writing this reply, kept so the
    /// answer can still be traced to its pages afterwards.
    var research: [WebResearchStep]? = nil
}

enum ArtifactKind: String, CaseIterable, Codable, Identifiable {
    case topic = "Topic"
    case research = "Research"
    case decision = "Decision"
    case openQuestion = "Open Question"
    case task = "Task"
    var id: String { rawValue }
}

enum ArtifactState: String, Codable, CaseIterable {
    case current, open, inProgress, blocked, done, resolved, dismissed, superseded, removed
}

extension ArtifactKind {
    /// The status a new record of this kind starts in.
    var initialState: ArtifactState {
        switch self {
        case .openQuestion, .task, .research: .open
        case .topic, .decision: .current
        }
    }

    /// The statuses a record of this kind may have.
    var allowedStates: [ArtifactState] {
        switch self {
        case .topic: [.current, .removed]
        case .research: [.open, .inProgress, .done, .removed]
        case .decision: [.current, .superseded, .removed]
        case .openQuestion: [.open, .resolved, .dismissed, .removed]
        case .task: [.open, .inProgress, .blocked, .done, .removed]
        }
    }
}

struct EvidenceRecord: Codable, Hashable, Identifiable {
    let id: UUID
    var sourceType: String
    var sourceID: UUID
    var version: Int
    var quote: String
    var aiAuthored: Bool
}

struct EvidenceInspection: Identifiable {
    let id: UUID
    let label: String
    let version: Int
    let fullText: String
    let quote: String
    let aiAuthored: Bool
    /// The page this text was kept from, when it came from the web.
    var origin: SourceOrigin? = nil
}

struct ArtifactRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    var kind: ArtifactKind
    var title: String
    var content: String
    var state: ArtifactState
    var rationale: String?
    var decisionSubject: String?
    var certainty: String? = nil
    var limitations: String? = nil
    var evidence: [EvidenceRecord]
    var relationships: [TypedRelationship] = []
    var version: Int
    var updatedAt: Date
}

extension ArtifactRecord {
    /// Research used to share the topic's single "current" status. It now has
    /// its own lifecycle, and a record saved before that reads as Open.
    static func normalizedState(_ state: ArtifactState, kind: ArtifactKind) -> ArtifactState {
        kind == .research && state == .current ? .open : state
    }

    /// Decoding is the one path every stored, archived, and historical record
    /// takes, so legacy research is normalised here rather than in each reader.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(ArtifactKind.self, forKey: .kind)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            projectID: try container.decode(UUID.self, forKey: .projectID),
            kind: kind,
            title: try container.decode(String.self, forKey: .title),
            content: try container.decode(String.self, forKey: .content),
            state: Self.normalizedState(try container.decode(ArtifactState.self, forKey: .state), kind: kind),
            rationale: try container.decodeIfPresent(String.self, forKey: .rationale),
            decisionSubject: try container.decodeIfPresent(String.self, forKey: .decisionSubject),
            certainty: try container.decodeIfPresent(String.self, forKey: .certainty),
            limitations: try container.decodeIfPresent(String.self, forKey: .limitations),
            evidence: try container.decode([EvidenceRecord].self, forKey: .evidence),
            relationships: try container.decodeIfPresent([TypedRelationship].self, forKey: .relationships) ?? [],
            version: try container.decode(Int.self, forKey: .version),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }
}

enum ProposalOperation: String, Codable { case create, update, supersede, relate }

struct TypedRelationship: Identifiable, Codable, Hashable {
    let id: UUID
    var type: String
    var targetArtifactID: UUID?
    var targetProposalID: UUID?
}

enum ProposalLifecycle: String, Codable { case pending, accepted, rejected, deferred, invalidated }

struct ProposalRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    var originatingRevision: Int
    var operation: ProposalOperation = .create
    var targetID: UUID? = nil
    var expectedTargetRevision: Int? = nil
    var kind: ArtifactKind
    var title: String
    var content: String
    var rationale: String?
    var decisionSubject: String?
    var proposedState: ArtifactState? = nil
    var certainty: String? = nil
    var limitations: String? = nil
    var evidence: [EvidenceRecord]
    var relationships: [TypedRelationship] = []
    var dependencyIDs: [UUID] = []
    var lifecycle: ProposalLifecycle
    var createdAt: Date
    var acceptedTitle: String? = nil
    var acceptedContent: String? = nil
    var acceptedArtifactID: UUID? = nil
}

struct ChangeRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    var revision: Int
    var transactionID: UUID = UUID()
    var summary: String
    var beforeArtifact: ArtifactRecord?
    var afterArtifact: ArtifactRecord?
    var createdAt: Date
    var undone: Bool
    var actor: String? = nil
    var originatingProposalID: UUID? = nil
}

struct ReturnRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    var durationMinutes: Int
    var understanding: Int
    var trust: Int
    var usefulness: Int
    var resumedWithinFiveMinutes: Bool
    var actionOutcome: String
    var reviewMinutes: Int
    var projectOutcome: String
    var notes: String
    var createdAt: Date
}

struct ContextSelection: Codable, Hashable {
    var includeDescription = true
    var sourceIDs: Set<UUID> = []
    var artifactIDs: Set<UUID> = []
    var messageCount = 20
}

struct RecommendationSupport: Codable, Hashable, Identifiable {
    var id: UUID
    var version: Int
}

struct RecommendationRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let projectID: UUID
    var text: String
    var supportingRecords: [RecommendationSupport]
    var uncertainty: String?
    var originatingRevision: Int
    var createdAt: Date
    var isDismissed: Bool
}

enum ProviderChoice: String, CaseIterable, Identifiable {
    case ollama = "Ollama"
    case openRouter = "OpenRouter"
    var id: String { rawValue }
}

enum ProviderReadiness: String { case unavailable, connected, unverified, qualified }

enum InferenceJobStatus: String, Codable { case running, completed, failed, cancelled, interrupted }

struct InferenceJobRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let contextID: UUID
    let projectID: UUID
    let sourceRevision: Int
    let provider: String
    let model: String
    var configuredUpstreamRoute: String? = nil
    let purpose: String
    let sourceIDs: [UUID]
    let artifactIDs: [UUID]
    let messageIDs: [UUID]
    let createdAt: Date
    var status: InferenceJobStatus
    var inputTokens: Int? = nil
    var outputTokens: Int? = nil
    var cost: Decimal? = nil
    var currency: String? = nil
    var actualModel: String? = nil
    var actualUpstreamProvider: String? = nil
}
