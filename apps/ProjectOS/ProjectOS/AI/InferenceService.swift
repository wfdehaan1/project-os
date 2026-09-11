import Foundation
import ProjectOSCore

struct InferenceConfiguration: Sendable {
    let provider: ProviderChoice
    let ollamaURL: String
    let model: String
    let openRouterRoute: String
    let contextWindowTokens: Int?
    let maximumOutputTokens: Int
    let approvedSpendingCeilingUSD: Decimal?

    init(provider: ProviderChoice, ollamaURL: String, model: String, openRouterRoute: String) {
        self.provider = provider
        self.ollamaURL = ollamaURL
        self.model = model
        self.openRouterRoute = openRouterRoute
        let defaults = UserDefaults.standard
        let configuredWindow = defaults.integer(forKey: "providerContextWindowTokens")
        contextWindowTokens = configuredWindow > 0 ? configuredWindow : nil
        let configuredOutput = defaults.integer(forKey: "providerMaximumOutputTokens")
        maximumOutputTokens = configuredOutput > 0 ? configuredOutput : 4_096
        approvedSpendingCeilingUSD = defaults.string(forKey: "openRouterApprovedSpendingCeilingUSD").flatMap {
            Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
        }
    }
}

struct FrozenProjectContext: @unchecked Sendable {
    let projectID: UUID
    let projectRevision: Int
    let projectName: String
    let projectDescription: String?
    let sources: [SourceRecord]
    let artifacts: [ArtifactRecord]
    let messages: [MessageRecord]
    let provider: ProviderChoice
    let model: String
}

struct GeneratedProposal: Sendable {
    let id: UUID
    let kind: ArtifactKind
    let title: String
    let content: String
    let rationale: String?
    let decisionSubject: String?
    let proposedState: ArtifactState?
    let certainty: String?
    let limitations: String?
    let evidence: [EvidenceRecord]
    var operation: ProposalOperation = .create
    var targetID: UUID? = nil
    var expectedTargetRevision: Int? = nil
    var relationships: [TypedRelationship] = []
    var dependencyIDs: [UUID] = []
}

struct GeneratedProposalBatch: Sendable {
    let proposals: [GeneratedProposal]
    let usage: AIUsage?
    let completionMetadata: AICompletionMetadata?
}

enum AppInferenceEvent: Sendable {
    case text(String)
    case usage(AIUsage)
    case completed(AICompletionMetadata)
}

enum InferenceError: Error, Equatable {
    case invalidConfiguration(String)
    case contextChanged
    case malformedStructuredOutput
    case invalidEvidence
}

extension InferenceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message): message
        case .contextChanged: "Project context changed while generation was running. Regenerate explicitly from the current state."
        case .malformedStructuredOutput: "The provider returned an invalid proposal result. Accepted project state was not changed."
        case .invalidEvidence: "A proposed evidence quote did not exactly match the disclosed source version. No proposals were saved."
        }
    }
}

/// Compatibility facade used by the app shell. Provider implementations remain store-free.
final class InferenceService: @unchecked Sendable {
    private static let keychain = KeychainCredentialStore()
    private static let runtime = SharedInferenceRuntime()
    private let configuration: InferenceConfiguration
    private let configurationID = UUID()

    init(configuration: InferenceConfiguration) {
        self.configuration = configuration
    }

    func connectivityTest() async throws {
        let provider = try makeProvider()
        let health = await provider.checkConnectivity()
        guard health.isConnected else {
            throw AIProviderError.unavailable(health.recoveryAction ?? "The provider is unavailable. Retry explicitly.")
        }
        if health.selectedModelIsAvailable == false {
            throw AIProviderError.unavailable(health.recoveryAction ?? "The selected model is unavailable.")
        }
    }

    func chat(context: FrozenProjectContext, userMessage: String) -> AsyncThrowingStream<AppInferenceEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let provider = try makeProvider()
                    var messages = [AIMessage(role: .system, content: PromptFactory.chatSystemPrompt)]
                    // Transcript turns are appended below with their original roles;
                    // do not also duplicate them inside the rendered context block.
                    messages.append(AIMessage(role: .user, content: render(context, includeMessages: false)))
                    messages.append(contentsOf: context.messages.map {
                        AIMessage(role: $0.role == .user ? .user : .assistant, content: $0.text)
                    })
                    if context.messages.last?.role != .user || context.messages.last?.text != userMessage {
                        messages.append(AIMessage(role: .user, content: userMessage))
                    }
                    let request = makeRequest(context: context, purpose: .chat, messages: messages)
                    let handle = try await Self.runtime.start(provider: provider, request: request)
                    for try await event in handle.events {
                        try Task.checkCancellation()
                        switch event {
                        case .textDelta(let text): continuation.yield(.text(text))
                        case .usage(let usage): continuation.yield(.usage(usage))
                        case .completed(let metadata): continuation.yield(.completed(metadata))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch let error as AIProviderError where error == .cancelled {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    func proposals(context: FrozenProjectContext) async throws -> GeneratedProposalBatch {
        let provider = try makeProvider()
        let schema = StructuredOutputSchema(name: "projectos_proposals", schema: try Self.proposalSchema())
        let messages = [
            AIMessage(role: .system, content: PromptFactory.proposalSystemPrompt),
            AIMessage(role: .user, content: render(context))
        ]
        let request = makeRequest(context: context, purpose: .proposals, messages: messages, schema: schema)
        let handle = try await Self.runtime.start(provider: provider, request: request)
        var output = ""
        var usage: AIUsage?
        var completionMetadata: AICompletionMetadata?
        for try await event in handle.events {
            try Task.checkCancellation()
            switch event {
            case .textDelta(let text): output.append(text)
            case .usage(let value): usage = value
            case .completed(let value): completionMetadata = value
            }
        }
        return GeneratedProposalBatch(proposals: try decodeProposals(output, context: context, jobID: request.id), usage: usage, completionMetadata: completionMetadata)
    }

    func nextAction(context: FrozenProjectContext) async throws -> NextActionSuggestion {
        let provider = try makeProvider()
        let registry = ProviderRegistry()
        await registry.register(provider)
        let coordinator = JobCoordinator(registry: registry)
        let expectedRevision = Int64(context.projectRevision)
        let service = NextActionService(coordinator: coordinator) { projectID in
            guard projectID == context.projectID else { throw InferenceError.contextChanged }
            return expectedRevision
        }
        let accepted = context.artifacts.filter { $0.state != .removed && $0.state != .superseded }.map {
            NextActionSupportingRecord(id: $0.id, version: Int64($0.version), kind: $0.kind.rawValue, title: $0.title, content: $0.content, rationale: $0.rationale)
        }
        return try await service.suggest(projectID: context.projectID, projectRevision: expectedRevision, provider: provider.descriptor, acceptedRecords: accepted, maximumOutputTokens: min(800, configuration.maximumOutputTokens), approvedSpendingCeilingUSD: configuration.approvedSpendingCeilingUSD)
    }

    private func makeProvider() throws -> any AIProvider {
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InferenceError.invalidConfiguration("Choose an explicit model in Settings.")
        }
        switch configuration.provider {
        case .ollama:
            guard let url = URL(string: configuration.ollamaURL) else {
                throw InferenceError.invalidConfiguration("The Ollama URL is invalid.")
            }
            let config = try OllamaConfiguration(
                id: configurationID,
                modelID: configuration.model,
                baseURL: url,
                contextWindowTokens: configuration.contextWindowTokens,
                maximumOutputTokens: configuration.maximumOutputTokens
            )
            return OllamaAdapter(configuration: config)
        case .openRouter:
            let config = try OpenRouterConfiguration(
                id: configurationID,
                modelID: configuration.model,
                upstreamProvider: configuration.openRouterRoute,
                contextWindowTokens: configuration.contextWindowTokens,
                maximumOutputTokens: configuration.maximumOutputTokens
            )
            return OpenRouterAdapter(configuration: config, credentialStore: Self.keychain)
        }
    }

    private func makeRequest(
        context: FrozenProjectContext,
        purpose: AIJobPurpose,
        messages: [AIMessage],
        schema: StructuredOutputSchema? = nil
    ) -> AIRequest {
        AIRequest(
            projectID: context.projectID,
            projectRevision: Int64(context.projectRevision),
            purpose: purpose,
            providerID: configuration.provider == .ollama ? .ollama : .openRouter,
            modelID: configuration.model,
            configurationID: configurationID,
            messages: messages,
            structuredOutput: schema,
            maximumOutputTokens: configuration.maximumOutputTokens,
            approvedSpendingCeilingUSD: configuration.approvedSpendingCeilingUSD
        )
    }

    private func render(_ context: FrozenProjectContext, includeMessages: Bool = true) -> String {
        var entries: [PromptContextEntry] = []
        if let description = context.projectDescription {
            entries.append(.init(kind: "project-description", id: context.projectID.uuidString, version: Int64(context.projectRevision), label: context.projectName, exactText: description))
        }
        entries.append(contentsOf: context.sources.map {
            .init(kind: "source", id: $0.id.uuidString, version: Int64($0.version), label: $0.label, exactText: $0.text)
        })
        entries.append(contentsOf: context.artifacts.map {
            .init(kind: "accepted-artifact", id: $0.id.uuidString, version: Int64($0.version), label: $0.title, status: $0.state.rawValue, exactText: $0.content)
        })
        if includeMessages {
            entries.append(contentsOf: context.messages.map {
                .init(kind: "message", id: $0.id.uuidString, version: 1, label: $0.role.rawValue, status: $0.completion.rawValue, exactText: $0.text)
            })
        }
        return PromptFactory.renderContext(entries)
    }

    private func decodeProposals(_ text: String, context: FrozenProjectContext, jobID: UUID) throws -> [GeneratedProposal] {
        guard let data = text.data(using: .utf8) else { throw InferenceError.malformedStructuredOutput }
        let descriptionSelections = context.projectDescription.map {
            [ProjectOSCore.ContextSelection(kind: .projectDescription, referenceID: context.projectID, version: context.projectRevision, label: context.projectName, text: $0)]
        } ?? []
        let selections = descriptionSelections
            + context.sources.map { ProjectOSCore.ContextSelection(kind: .source, referenceID: $0.id, version: $0.version, label: $0.label, text: $0.text) }
            + context.artifacts.map { ProjectOSCore.ContextSelection(kind: .artifact, referenceID: $0.id, version: $0.version, label: $0.title, text: $0.content, statusLabel: $0.state.rawValue) }
            + context.messages.map { ProjectOSCore.ContextSelection(kind: .message, referenceID: $0.id, version: 1, label: $0.role.rawValue, text: $0.text, statusLabel: $0.role == .assistant ? "AI-authored/unverified" : "user-authored") }
        let snapshot = ProjectOSCore.ContextSnapshot(projectID: context.projectID, projectRevision: context.projectRevision, providerID: context.provider.rawValue, modelID: context.model, configurationID: configurationID.uuidString, purpose: .proposals, selections: selections)
        let batch: ProjectOSCore.ProposalBatch
        do {
            batch = try ProjectOSCore.ProposalValidator.validate(data: data, projectID: context.projectID, jobID: jobID, context: snapshot, currentProjectRevision: context.projectRevision, currentArtifacts: context.artifacts.map(Self.coreArtifact))
        } catch let error as ProjectOSCore.ProposalValidationError {
            throw InferenceError.invalidConfiguration(error.localizedDescription)
        } catch {
            throw InferenceError.malformedStructuredOutput
        }
        return batch.proposals.map { proposal in
            GeneratedProposal(
                id: proposal.id,
                kind: Self.appKind(proposal.kind),
                title: proposal.title,
                content: proposal.content,
                rationale: proposal.rationale,
                decisionSubject: proposal.decisionSubject,
                proposedState: proposal.proposedState.map(Self.appState),
                certainty: proposal.certainty,
                limitations: proposal.limitations,
                evidence: proposal.evidence.map { EvidenceRecord(id: $0.id, sourceType: $0.sourceType.rawValue, sourceID: $0.referenceID, version: $0.version, quote: $0.quote, aiAuthored: $0.isAIAuthored) },
                operation: ProposalOperation(rawValue: proposal.operation.rawValue) ?? .create,
                targetID: proposal.targetID,
                expectedTargetRevision: proposal.expectedTargetRevision,
                relationships: proposal.relationships.map { TypedRelationship(id: $0.id, type: $0.type.rawValue, targetArtifactID: $0.targetArtifactID, targetProposalID: $0.targetProposalID) },
                dependencyIDs: proposal.dependencyIDs
            )
        }
    }

    private static func coreArtifact(_ artifact: ArtifactRecord) -> ProjectOSCore.Artifact {
        ProjectOSCore.Artifact(id: artifact.id, projectID: artifact.projectID, kind: coreKind(artifact.kind), title: artifact.title, content: artifact.content, state: coreState(artifact.state, kind: artifact.kind), rationale: artifact.rationale, evidence: artifact.evidence.map { ProjectOSCore.EvidenceReference(id: $0.id, sourceType: $0.sourceType == "message" ? .message : .source, referenceID: $0.sourceID, version: $0.version, quote: $0.quote, isAIAuthored: $0.aiAuthored) }, relations: artifact.relationships.compactMap { relation in
            guard let target = relation.targetArtifactID, let type = ProjectOSCore.RelationType(rawValue: relation.type) else { return nil }
            return ProjectOSCore.ArtifactRelation(id: relation.id, projectID: artifact.projectID, sourceArtifactID: artifact.id, targetArtifactID: target, type: type)
        }, decisionSubject: artifact.decisionSubject, version: artifact.version, updatedAt: artifact.updatedAt)
    }

    private static func coreKind(_ kind: ArtifactKind) -> ProjectOSCore.ArtifactKind {
        switch kind { case .topic: .topic; case .research: .research; case .decision: .decision; case .openQuestion: .openQuestion; case .task: .task }
    }

    private static func appKind(_ kind: ProjectOSCore.ArtifactKind) -> ArtifactKind {
        switch kind { case .topic: .topic; case .research: .research; case .decision: .decision; case .openQuestion: .openQuestion; case .task: .task }
    }

    private static func appState(_ state: ProjectOSCore.ArtifactState) -> ArtifactState {
        switch state {
        case .active, .governing: .current
        case .open: .open
        case .inProgress: .inProgress
        case .blocked: .blocked
        case .done: .done
        case .resolved: .resolved
        case .dismissed: .dismissed
        case .superseded: .superseded
        case .removed: .removed
        }
    }

    private static func coreState(_ state: ArtifactState, kind: ArtifactKind) -> ProjectOSCore.ArtifactState {
        switch state {
        case .current: kind == .decision ? .governing : .active
        case .open: .open
        case .inProgress: .inProgress
        case .blocked: .blocked
        case .done: .done
        case .resolved: .resolved
        case .dismissed: .dismissed
        case .superseded: .superseded
        case .removed: .removed
        }
    }

    private func decodeLegacyProposals(_ text: String, context: FrozenProjectContext) throws -> [GeneratedProposal] {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == Set(["schemaVersion", "proposals"]),
              root["schemaVersion"] as? Int == 1,
              let rawProposals = root["proposals"] as? [[String: Any]] else {
            throw InferenceError.malformedStructuredOutput
        }
        let allowedProposalKeys = Set(["id", "kind", "title", "content", "rationale", "decisionSubject", "evidence"])
        let allowedEvidenceKeys = Set(["sourceType", "sourceID", "version", "quote"])
        guard rawProposals.allSatisfy({ Set($0.keys) == allowedProposalKeys }),
              rawProposals.allSatisfy({ ($0["evidence"] as? [[String: Any]])?.allSatisfy { Set($0.keys) == allowedEvidenceKeys } == true }) else {
            throw InferenceError.malformedStructuredOutput
        }
        let wire: ProposalEnvelope
        do { wire = try JSONDecoder().decode(ProposalEnvelope.self, from: data) }
        catch { throw InferenceError.malformedStructuredOutput }
        guard Set(wire.proposals.map(\.id)).count == wire.proposals.count else {
            throw InferenceError.malformedStructuredOutput
        }

        let selected: [UUID: (version: Int, text: String, aiAuthored: Bool)] = Dictionary(uniqueKeysWithValues:
            context.sources.map { ($0.id, ($0.version, $0.text, false)) }
            + context.messages.map { ($0.id, (1, $0.text, $0.role == .assistant)) }
        )
        return try wire.proposals.map { proposal in
            guard let kind = ArtifactKind(rawValue: proposal.kind),
                  !proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !proposal.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw InferenceError.malformedStructuredOutput
            }
            let evidence = try proposal.evidence.map { item -> EvidenceRecord in
                guard let source = selected[item.sourceID],
                      source.version == item.version,
                      !item.quote.isEmpty,
                      source.text.range(of: item.quote) != nil else {
                    throw InferenceError.invalidEvidence
                }
                return EvidenceRecord(
                    id: UUID(),
                    sourceType: item.sourceType,
                    sourceID: item.sourceID,
                    version: item.version,
                    quote: item.quote,
                    aiAuthored: source.aiAuthored
                )
            }
            if kind == .decision, evidence.allSatisfy(\.aiAuthored) {
                throw InferenceError.invalidEvidence
            }
            return GeneratedProposal(
                id: proposal.id,
                kind: kind,
                title: proposal.title,
                content: proposal.content,
                rationale: proposal.rationale,
                decisionSubject: proposal.decisionSubject,
                proposedState: nil,
                certainty: nil,
                limitations: nil,
                evidence: evidence
            )
        }
    }
}

private actor SharedInferenceRuntime {
    private let registry: ProviderRegistry
    private let coordinator: JobCoordinator

    init() {
        let registry = ProviderRegistry()
        self.registry = registry
        coordinator = JobCoordinator(registry: registry)
    }

    func start(provider: any AIProvider, request: AIRequest) async throws -> AIJobHandle {
        await registry.register(provider)
        return try await coordinator.start(request)
    }
}

private struct ProposalEnvelope: Decodable {
    struct Proposal: Decodable {
        struct Evidence: Decodable {
            let sourceType: String
            let sourceID: UUID
            let version: Int
            let quote: String
        }
        let id: UUID
        let kind: String
        let title: String
        let content: String
        let rationale: String?
        let decisionSubject: String?
        let evidence: [Evidence]
    }
    let schemaVersion: Int
    let proposals: [Proposal]
}

private extension InferenceService {
    static func proposalSchema() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: ProjectOSCore.ProposalSchema.data())
    }

    static let legacyProposalSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object([
            "schemaVersion": .object(["type": .string("integer"), "const": .number(1)]),
            "proposals": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "properties": .object([
                        "id": .object(["type": .string("string"), "format": .string("uuid")]),
                        "kind": .object(["type": .string("string"), "enum": .array(ArtifactKind.allCases.map { .string($0.rawValue) })]),
                        "title": .object(["type": .string("string")]),
                        "content": .object(["type": .string("string")]),
                        "rationale": .object(["type": .array([.string("string"), .string("null")])]),
                        "decisionSubject": .object(["type": .array([.string("string"), .string("null")])]),
                        "evidence": .object([
                            "type": .string("array"),
                            "items": .object([
                                "type": .string("object"),
                                "additionalProperties": .bool(false),
                                "properties": .object([
                                    "sourceType": .object(["type": .string("string"), "enum": .array([.string("source"), .string("message")])]),
                                    "sourceID": .object(["type": .string("string"), "format": .string("uuid")]),
                                    "version": .object(["type": .string("integer"), "minimum": .number(1)]),
                                    "quote": .object(["type": .string("string")])
                                ]),
                                "required": .array([.string("sourceType"), .string("sourceID"), .string("version"), .string("quote")])
                            ])
                        ])
                    ]),
                    "required": .array([.string("id"), .string("kind"), .string("title"), .string("content"), .string("rationale"), .string("decisionSubject"), .string("evidence")])
                ])
            ])
        ]),
        "required": .array([.string("schemaVersion"), .string("proposals")])
    ])
}
