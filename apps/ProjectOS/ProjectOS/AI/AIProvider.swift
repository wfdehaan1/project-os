import Foundation

public enum ProviderID: String, Codable, CaseIterable, Sendable {
    case ollama
    case openRouter
}

public enum ProviderExecutionBoundary: String, Codable, Sendable {
    case local
    case external
}

public enum AIJobPurpose: String, Codable, Sendable {
    case chat
    case proposals
    case nextAction
}

public enum AIMessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public struct AIMessage: Codable, Equatable, Sendable {
    public let role: AIMessageRole
    public let content: String

    public init(role: AIMessageRole, content: String) {
        self.role = role
        self.content = content
    }
}

public indirect enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public struct StructuredOutputSchema: Codable, Equatable, Sendable {
    public let name: String
    public let schema: JSONValue

    public init(name: String, schema: JSONValue) {
        self.name = name
        self.schema = schema
    }
}

/// A frozen request. It deliberately contains no credential or store reference.
public struct AIRequest: Sendable {
    public let id: UUID
    public let projectID: UUID
    public let projectRevision: Int64
    public let purpose: AIJobPurpose
    public let providerID: ProviderID
    public let modelID: String
    public let configurationID: UUID
    public let messages: [AIMessage]
    public let structuredOutput: StructuredOutputSchema?
    public let maximumOutputTokens: Int
    public let approvedSpendingCeilingUSD: Decimal?

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        projectRevision: Int64,
        purpose: AIJobPurpose,
        providerID: ProviderID,
        modelID: String,
        configurationID: UUID,
        messages: [AIMessage],
        structuredOutput: StructuredOutputSchema? = nil,
        maximumOutputTokens: Int,
        approvedSpendingCeilingUSD: Decimal? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.projectRevision = projectRevision
        self.purpose = purpose
        self.providerID = providerID
        self.modelID = modelID
        self.configurationID = configurationID
        self.messages = messages
        self.structuredOutput = structuredOutput
        self.maximumOutputTokens = maximumOutputTokens
        self.approvedSpendingCeilingUSD = approvedSpendingCeilingUSD
    }
}

public struct AIUsage: Codable, Equatable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cost: Decimal?
    public let currency: String?

    public init(inputTokens: Int? = nil, outputTokens: Int? = nil, cost: Decimal? = nil, currency: String? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cost = cost
        self.currency = currency
    }
}

public struct AICompletionMetadata: Codable, Equatable, Sendable {
    public let modelID: String
    public let upstreamProvider: String?

    public init(modelID: String, upstreamProvider: String? = nil) {
        self.modelID = modelID
        self.upstreamProvider = upstreamProvider
    }
}

public enum AIStreamEvent: Equatable, Sendable {
    case textDelta(String)
    case usage(AIUsage)
    case completed(AICompletionMetadata)
}

public struct ProviderCapabilities: Codable, Equatable, Sendable {
    public let streaming: Bool
    public let structuredOutput: Bool
    public let cancellation: Bool

    public init(streaming: Bool, structuredOutput: Bool, cancellation: Bool) {
        self.streaming = streaming
        self.structuredOutput = structuredOutput
        self.cancellation = cancellation
    }
}

public enum AIProviderReadiness: String, Codable, Sendable {
    case unavailable
    case unverified
    case connected
    case qualified
}

public struct ProviderDescriptor: Codable, Equatable, Sendable {
    public let id: ProviderID
    public let displayName: String
    public let modelID: String
    public let configurationID: UUID
    public let executionBoundary: ProviderExecutionBoundary
    public let contextWindowTokens: Int?
    public let maximumOutputTokens: Int
    public let capabilities: ProviderCapabilities

    public init(
        id: ProviderID,
        displayName: String,
        modelID: String,
        configurationID: UUID,
        executionBoundary: ProviderExecutionBoundary,
        contextWindowTokens: Int?,
        maximumOutputTokens: Int,
        capabilities: ProviderCapabilities
    ) {
        self.id = id
        self.displayName = displayName
        self.modelID = modelID
        self.configurationID = configurationID
        self.executionBoundary = executionBoundary
        self.contextWindowTokens = contextWindowTokens
        self.maximumOutputTokens = maximumOutputTokens
        self.capabilities = capabilities
    }
}

public struct ProviderHealth: Equatable, Sendable {
    public let isConnected: Bool
    public let isConfigured: Bool
    public let selectedModelIsAvailable: Bool?
    public let recoveryAction: String?

    public init(isConnected: Bool, isConfigured: Bool, selectedModelIsAvailable: Bool? = nil, recoveryAction: String? = nil) {
        self.isConnected = isConnected
        self.isConfigured = isConfigured
        self.selectedModelIsAvailable = selectedModelIsAvailable
        self.recoveryAction = recoveryAction
    }
}

public enum AIProviderError: Error, Equatable, Sendable {
    case invalidConfiguration(String)
    case unavailable(String)
    case credentialUnavailable
    case requestDoesNotMatchFrozenConfiguration
    case contextBoundUnknown
    case contextLimitExceeded(estimated: Int, limit: Int)
    case spendingApprovalRequired
    case httpStatus(Int)
    case rateLimited
    case billingRejected
    case unsupportedStructuredOutput
    case malformedStream
    case truncatedOutput
    case outputLimitReached
    case providerFailure(code: String?)
    case cancelled
}

extension AIProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let detail): detail
        case .unavailable(let action): action
        case .credentialUnavailable: "The OpenRouter credential is unavailable. Add it in Settings and retry."
        case .requestDoesNotMatchFrozenConfiguration: "The request does not match its frozen provider, model, or configuration. Create a new request."
        case .contextBoundUnknown: "The selected model's context bound is unknown. Configure a verified bound before sending."
        case .contextLimitExceeded(let estimated, let limit): "The selected context may require up to \(estimated) tokens, above the configured \(limit)-token window. Narrow the context."
        case .spendingApprovalRequired: "Approve a positive OpenRouter spending ceiling before making this external request."
        case .httpStatus(let status): "The provider returned HTTP \(status)."
        case .rateLimited: "The provider rate-limited this request. Retry manually later."
        case .billingRejected: "The provider rejected this request for billing or credit reasons. Review the provider account before retrying."
        case .unsupportedStructuredOutput: "The selected route does not support the required structured output parameters."
        case .malformedStream: "The provider returned a malformed stream. Partial output was retained."
        case .truncatedOutput: "The provider stream ended before a completion marker. Partial output was retained."
        case .outputLimitReached: "The model reached the maximum output tokens before finishing, so its answer is incomplete. Raise the limit in Settings or narrow the context, then retry."
        case .providerFailure(let code): "The provider reported an in-stream error\(code.map { " (\($0))" } ?? "")."
        case .cancelled: "Generation was stopped. The provider may already have performed work or incurred cost."
        }
    }
}

public protocol AIProvider: Sendable {
    var descriptor: ProviderDescriptor { get }
    func checkConnectivity() async -> ProviderHealth
    func events(for request: AIRequest) async throws -> AsyncThrowingStream<AIStreamEvent, Error>
}

enum ProviderRequestValidator {
    static func validate(_ request: AIRequest, against descriptor: ProviderDescriptor) throws {
        guard request.providerID == descriptor.id,
              request.modelID == descriptor.modelID,
              request.configurationID == descriptor.configurationID else {
            throw AIProviderError.requestDoesNotMatchFrozenConfiguration
        }
        guard !request.messages.isEmpty, request.maximumOutputTokens > 0 else {
            throw AIProviderError.invalidConfiguration("A request needs at least one message and a positive output budget.")
        }
        guard request.maximumOutputTokens <= descriptor.maximumOutputTokens else {
            throw AIProviderError.invalidConfiguration("The output budget exceeds the configured model limit.")
        }
        guard let contextLimit = descriptor.contextWindowTokens else {
            throw AIProviderError.contextBoundUnknown
        }

        // One UTF-8 byte per token is intentionally conservative and includes prompt framing.
        var upperBound = request.messages.reduce(0) { $0 + $1.content.utf8.count + 16 }
        if let schema = request.structuredOutput,
           let encoded = try? JSONEncoder().encode(schema) {
            upperBound += encoded.count
        }
        upperBound += request.maximumOutputTokens
        guard upperBound <= contextLimit else {
            throw AIProviderError.contextLimitExceeded(estimated: upperBound, limit: contextLimit)
        }
    }
}
