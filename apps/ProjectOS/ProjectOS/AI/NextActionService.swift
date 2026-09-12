import Foundation

public struct NextActionSupportingRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let version: Int64
    public let kind: String
    public let title: String
    public let content: String
    public let rationale: String?

    public init(id: UUID, version: Int64, kind: String, title: String, content: String, rationale: String? = nil) {
        self.id = id
        self.version = version
        self.kind = kind
        self.title = title
        self.content = content
        self.rationale = rationale
    }
}

public struct NextActionSuggestion: Codable, Equatable, Sendable {
    public let id: UUID
    public let projectID: UUID
    public let text: String
    public let supportingRecords: [NextActionSupportingReference]
    public let uncertainty: String?
    public let originatingRevision: Int64
    public let createdAt: Date
    public var isDismissed: Bool
    public var isStale: Bool
    public let usage: AIUsage?
    public let completionMetadata: AICompletionMetadata?
}

public struct NextActionSupportingReference: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let version: Int64
}

public enum NextActionError: Error, Equatable, Sendable {
    case malformedOutput
    case invalidSupportingReference
    case insufficientGrounding
    case staleContext(expected: Int64, actual: Int64)
}

public actor NextActionService {
    public typealias RevisionProvider = @Sendable (UUID) async throws -> Int64

    private let coordinator: JobCoordinator
    private let currentRevision: RevisionProvider

    public init(coordinator: JobCoordinator, currentRevision: @escaping RevisionProvider) {
        self.coordinator = coordinator
        self.currentRevision = currentRevision
    }

    public func suggest(
        projectID: UUID,
        projectRevision: Int64,
        provider: ProviderDescriptor,
        acceptedRecords: [NextActionSupportingRecord],
        maximumOutputTokens: Int = 800,
        approvedSpendingCeilingUSD: Decimal? = nil,
        progress: AIJobProgress? = nil
    ) async throws -> NextActionSuggestion {
        let context = acceptedRecords.map {
            PromptContextEntry(
                kind: $0.kind,
                id: $0.id.uuidString,
                version: $0.version,
                label: $0.title,
                status: "accepted-current",
                exactText: [$0.content, $0.rationale].compactMap { $0 }.joined(separator: "\nRationale: ")
            )
        }
        let request = AIRequest(
            projectID: projectID,
            projectRevision: projectRevision,
            purpose: .nextAction,
            providerID: provider.id,
            modelID: provider.modelID,
            configurationID: provider.configurationID,
            messages: [
                AIMessage(role: .system, content: PromptFactory.nextActionSystemPrompt),
                AIMessage(role: .user, content: PromptFactory.renderContext(context))
            ],
            structuredOutput: Self.schema,
            maximumOutputTokens: maximumOutputTokens,
            approvedSpendingCeilingUSD: approvedSpendingCeilingUSD
        )
        await progress?(.waiting)
        let handle = try await coordinator.start(request)
        var data = ""
        var usage: AIUsage?
        var completionMetadata: AICompletionMetadata?
        for try await event in handle.events {
            switch event {
            case .textDelta(let chunk):
                if data.isEmpty { await progress?(.receiving) }
                data.append(chunk)
            // A next action is offered no tools, so none can be asked for.
            case .toolCall: throw AIProviderError.malformedStream
            case .usage(let value): usage = value
            case .completed(let value): completionMetadata = value
            }
        }

        await progress?(.checking)
        let wire = try Self.decodeStrict(data)
        let available = Dictionary(uniqueKeysWithValues: acceptedRecords.map {
            (NextActionSupportingReference(id: $0.id, version: $0.version), $0)
        })
        guard Set(wire.supportingRecords).count == wire.supportingRecords.count,
              wire.supportingRecords.allSatisfy({ available[$0] != nil }) else {
            throw NextActionError.invalidSupportingReference
        }
        let trimmedText = wire.action.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUncertainty = wire.uncertainty?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw NextActionError.malformedOutput }
        guard !wire.supportingRecords.isEmpty || trimmedUncertainty?.isEmpty == false else {
            throw NextActionError.insufficientGrounding
        }
        let revision = try await currentRevision(projectID)
        guard revision == projectRevision else {
            throw NextActionError.staleContext(expected: projectRevision, actual: revision)
        }
        return NextActionSuggestion(
            id: UUID(),
            projectID: projectID,
            text: trimmedText,
            supportingRecords: wire.supportingRecords,
            uncertainty: trimmedUncertainty,
            originatingRevision: projectRevision,
            createdAt: Date(),
            isDismissed: false,
            isStale: false,
            usage: usage,
            completionMetadata: completionMetadata
        )
    }

    public func refreshedState(_ suggestion: NextActionSuggestion, currentProjectRevision: Int64) -> NextActionSuggestion {
        var result = suggestion
        result.isStale = suggestion.originatingRevision != currentProjectRevision
        return result
    }

    private struct Wire: Decodable {
        let action: String
        let supportingRecords: [NextActionSupportingReference]
        let uncertainty: String?
    }

    private static func decodeStrict(_ text: String) throws -> Wire {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["action", "supportingRecords", "uncertainty"]),
              let refs = object["supportingRecords"] as? [[String: Any]],
              refs.allSatisfy({ Set($0.keys) == Set(["id", "version"]) }) else {
            throw NextActionError.malformedOutput
        }
        do { return try JSONDecoder().decode(Wire.self, from: data) }
        catch { throw NextActionError.malformedOutput }
    }

    private static let schema = StructuredOutputSchema(
        name: "projectos_next_action",
        schema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object([
                "action": .object(["type": .string("string")]),
                "supportingRecords": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "additionalProperties": .bool(false),
                        "properties": .object([
                            "id": .object(["type": .string("string"), "format": .string("uuid")]),
                            "version": .object(["type": .string("integer"), "minimum": .number(1)])
                        ]),
                        "required": .array([.string("id"), .string("version")])
                    ])
                ]),
                "uncertainty": .object(["type": .array([.string("string"), .string("null")])])
            ]),
            "required": .array([.string("action"), .string("supportingRecords"), .string("uncertainty")])
        ])
    )
}
