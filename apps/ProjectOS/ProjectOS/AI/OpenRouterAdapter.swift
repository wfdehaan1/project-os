import Foundation

public struct OpenRouterConfiguration: Equatable, Sendable {
    public let id: UUID
    public let modelID: String
    public let upstreamProvider: String
    public let credentialAccount: String
    public let contextWindowTokens: Int?
    public let maximumOutputTokens: Int
    public let baseURL: URL
    public let requestTimeout: TimeInterval

    public init(
        id: UUID = UUID(),
        modelID: String,
        upstreamProvider: String,
        credentialAccount: String = "openrouter-api-key",
        contextWindowTokens: Int?,
        maximumOutputTokens: Int = 4_096,
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        requestTimeout: TimeInterval = 120
    ) throws {
        let model = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = upstreamProvider.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, model.lowercased() != "auto", !model.contains(",") else {
            throw AIProviderError.invalidConfiguration("Select one explicit stable OpenRouter model; auto and fallback model lists are not allowed.")
        }
        guard !route.isEmpty, !route.contains(",") else {
            throw AIProviderError.invalidConfiguration("Select one explicit OpenRouter upstream provider route.")
        }
        guard !credentialAccount.isEmpty, maximumOutputTokens > 0, requestTimeout > 0 else {
            throw AIProviderError.invalidConfiguration("OpenRouter credential, output, and timeout settings must be valid.")
        }
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https",
              components.host?.lowercased() == "openrouter.ai",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path == "/api/v1" else {
            throw AIProviderError.invalidConfiguration("OpenRouter credentials may only be sent directly to https://openrouter.ai/api/v1.")
        }
        self.id = id
        self.modelID = model
        self.upstreamProvider = route
        self.credentialAccount = credentialAccount
        self.contextWindowTokens = contextWindowTokens
        self.maximumOutputTokens = maximumOutputTokens
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
    }
}

struct OpenRouterMaxPrice: Encodable, Equatable {
    let prompt: Decimal
    let completion: Decimal
    let request: Decimal
}

public final class OpenRouterAdapter: AIProvider, @unchecked Sendable {
    public let descriptor: ProviderDescriptor

    private let configuration: OpenRouterConfiguration
    private let credentialStore: KeychainCredentialStore
    private let session: URLSession

    public init(
        configuration: OpenRouterConfiguration,
        credentialStore: KeychainCredentialStore,
        session: URLSession? = nil
    ) {
        self.configuration = configuration
        self.credentialStore = credentialStore
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = configuration.requestTimeout
            config.timeoutIntervalForResource = configuration.requestTimeout
            config.httpCookieStorage = nil
            config.urlCache = nil
            self.session = URLSession(configuration: config, delegate: RejectRedirectsDelegate(), delegateQueue: nil)
        }
        descriptor = ProviderDescriptor(
            id: .openRouter,
            displayName: "OpenRouter",
            modelID: configuration.modelID,
            configurationID: configuration.id,
            executionBoundary: .external,
            contextWindowTokens: configuration.contextWindowTokens,
            maximumOutputTokens: configuration.maximumOutputTokens,
            capabilities: ProviderCapabilities(streaming: true, structuredOutput: true, cancellation: true)
        )
    }

    public func checkConnectivity() async -> ProviderHealth {
        guard await credentialStore.containsCredential(account: configuration.credentialAccount) else {
            return ProviderHealth(isConnected: false, isConfigured: false, recoveryAction: "Add the OpenRouter key in Settings, then retry the explicit connection test.")
        }
        do {
            let credential = try await credentialStore.credential(account: configuration.credentialAccount)
            var request = URLRequest(url: configuration.baseURL.appendingPathComponent("key"))
            request.timeoutInterval = min(configuration.requestTimeout, 10)
            request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await session.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode else {
                return ProviderHealth(isConnected: false, isConfigured: true, recoveryAction: "Check the network connection and retry.")
            }
            if status == 401 || status == 403 {
                return ProviderHealth(isConnected: false, isConfigured: false, recoveryAction: "Replace the denied OpenRouter key in Settings.")
            }
            return ProviderHealth(isConnected: (200..<300).contains(status), isConfigured: true, recoveryAction: (200..<300).contains(status) ? nil : "OpenRouter is unavailable. Retry manually; no request was retried automatically.")
        } catch {
            return ProviderHealth(isConnected: false, isConfigured: true, recoveryAction: "Check the network connection and retry the explicit connection test.")
        }
    }

    public func events(for request: AIRequest) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        try ProviderRequestValidator.validate(request, against: descriptor)
        guard let ceiling = request.approvedSpendingCeilingUSD, ceiling > 0 else {
            throw AIProviderError.spendingApprovalRequired
        }
        let credential: String
        do { credential = try await credentialStore.credential(account: configuration.credentialAccount) }
        catch { throw AIProviderError.credentialUnavailable }

        let provider = OpenRouterRequest.Provider(
            order: [configuration.upstreamProvider],
            only: [configuration.upstreamProvider],
            allowFallbacks: false,
            requireParameters: true,
            dataCollection: "deny",
            maxPrice: Self.maxPrice(for: request, ceiling: ceiling)
        )
        let responseFormat = request.structuredOutput.map {
            OpenRouterRequest.ResponseFormat(
                type: "json_schema",
                jsonSchema: .init(name: $0.name, strict: true, schema: $0.schema)
            )
        }
        let body = OpenRouterRequest(
            model: configuration.modelID,
            messages: request.messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            stream: true,
            maxCompletionTokens: request.maximumOutputTokens,
            provider: provider,
            responseFormat: responseFormat
        )
        var urlRequest = URLRequest(url: configuration.baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("enabled", forHTTPHeaderField: "X-OpenRouter-Metadata")
        urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw AIProviderError.malformedStream }
        guard (200..<300).contains(http.statusCode) else { throw HTTPErrorMapper.map(status: http.statusCode) }
        guard response.url?.scheme == "https", response.url?.host?.lowercased() == "openrouter.ai" else {
            throw AIProviderError.invalidConfiguration("OpenRouter redirected outside its approved HTTPS host.")
        }

        return AsyncThrowingStream { continuation in
            let producer = Task {
                var lineBuffer = UTF8LineBuffer()
                var eventParser = SSEDataParser()
                var receivedDone = false
                var completionMetadata = AICompletionMetadata(
                    modelID: configuration.modelID,
                    upstreamProvider: nil
                )
                do {
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        if let line = try lineBuffer.append(byte),
                           let payload = eventParser.consume(line: line) {
                            receivedDone = try Self.consume(payload: payload, expectedModel: configuration.modelID, expectedProvider: configuration.upstreamProvider, metadata: &completionMetadata, continuation: continuation) || receivedDone
                        }
                    }
                    if let line = try lineBuffer.finish(),
                       let payload = eventParser.consume(line: line) {
                        receivedDone = try Self.consume(payload: payload, expectedModel: configuration.modelID, expectedProvider: configuration.upstreamProvider, metadata: &completionMetadata, continuation: continuation) || receivedDone
                    }
                    if let payload = eventParser.finish() {
                        receivedDone = try Self.consume(payload: payload, expectedModel: configuration.modelID, expectedProvider: configuration.upstreamProvider, metadata: &completionMetadata, continuation: continuation) || receivedDone
                    }
                    guard receivedDone else { throw AIProviderError.truncatedOutput }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in producer.cancel() }
        }
    }

    static func maxPrice(for request: AIRequest, ceiling: Decimal) -> OpenRouterMaxPrice {
        var promptUpperBound = request.messages.reduce(0) { $0 + $1.content.utf8.count + 16 }
        if let schema = request.structuredOutput, let encoded = try? JSONEncoder().encode(schema) { promptUpperBound += encoded.count }
        // Divide the approved per-request ceiling across prompt, completion,
        // and any endpoint's fixed per-request price. OpenRouter's max_price
        // rates are USD per million tokens.
        let share = ceiling / Decimal(3)
        let promptRate = share * Decimal(1_000_000) / Decimal(max(1, promptUpperBound))
        let completionRate = share * Decimal(1_000_000) / Decimal(max(1, request.maximumOutputTokens))
        return .init(prompt: promptRate, completion: completionRate, request: share)
    }

    private static func consume(
        payload: String,
        expectedModel: String,
        expectedProvider: String,
        metadata: inout AICompletionMetadata,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) throws -> Bool {
        if payload == "[DONE]" {
            guard metadata.modelID == expectedModel,
                  metadata.upstreamProvider?.caseInsensitiveCompare(expectedProvider) == .orderedSame else {
                throw AIProviderError.requestDoesNotMatchFrozenConfiguration
            }
            continuation.yield(.completed(metadata))
            return true
        }
        guard let data = payload.data(using: .utf8) else { throw AIProviderError.malformedStream }
        let chunk: OpenRouterChunk
        do { chunk = try JSONDecoder().decode(OpenRouterChunk.self, from: data) }
        catch { throw AIProviderError.malformedStream }
        if let error = chunk.error {
            throw AIProviderError.providerFailure(code: error.code?.safeString)
        }
        metadata = AICompletionMetadata(
            modelID: chunk.model ?? metadata.modelID,
            upstreamProvider: chunk.provider ?? metadata.upstreamProvider
        )
        if let router = chunk.openRouterMetadata {
            guard router.strategy == "direct", router.attempt == 1,
                  let selected = router.endpoints.available.first(where: { $0.selected }) else {
                throw AIProviderError.requestDoesNotMatchFrozenConfiguration
            }
            metadata = AICompletionMetadata(modelID: selected.model, upstreamProvider: selected.provider)
        }
        for choice in chunk.choices ?? [] {
            if let content = choice.delta?.content, !content.isEmpty {
                continuation.yield(.textDelta(content))
            }
        }
        if let usage = chunk.usage {
            continuation.yield(.usage(AIUsage(
                inputTokens: usage.promptTokens,
                outputTokens: usage.completionTokens,
                cost: usage.cost,
                currency: usage.cost == nil ? nil : "USD"
            )))
        }
        return false
    }
}

private struct OpenRouterRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    struct Provider: Encodable {
        let order: [String]
        let only: [String]
        let allowFallbacks: Bool
        let requireParameters: Bool
        let dataCollection: String
        let maxPrice: OpenRouterMaxPrice
        enum CodingKeys: String, CodingKey {
            case order, only
            case allowFallbacks = "allow_fallbacks"
            case requireParameters = "require_parameters"
            case dataCollection = "data_collection"
            case maxPrice = "max_price"
        }
    }
    struct ResponseFormat: Encodable {
        struct Schema: Encodable { let name: String; let strict: Bool; let schema: JSONValue }
        let type: String
        let jsonSchema: Schema
        enum CodingKeys: String, CodingKey { case type; case jsonSchema = "json_schema" }
    }
    let model: String
    let messages: [Message]
    let stream: Bool
    let maxCompletionTokens: Int
    let provider: Provider
    let responseFormat: ResponseFormat?
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, provider
        case maxCompletionTokens = "max_completion_tokens"
        case responseFormat = "response_format"
    }
}

private struct OpenRouterChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta?
    }
    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let cost: Decimal?
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case cost
        }
    }
    struct ProviderError: Decodable { let code: JSONValue? }
    struct RouterMetadata: Decodable {
        struct Endpoints: Decodable {
            struct Endpoint: Decodable {
                let provider: String
                let model: String
                let selected: Bool
            }
            let available: [Endpoint]
        }
        let strategy: String
        let attempt: Int
        let endpoints: Endpoints
    }
    let model: String?
    let provider: String?
    let choices: [Choice]?
    let usage: Usage?
    let openRouterMetadata: RouterMetadata?
    enum CodingKeys: String, CodingKey {
        case model, provider, choices, usage, error
        case openRouterMetadata = "openrouter_metadata"
    }
    let error: ProviderError?
}

private extension JSONValue {
    var safeString: String? {
        switch self {
        case .string(let value):
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
            guard value.count <= 64, value.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
            return value
        case .number(let value): return String(value)
        default: return nil
        }
    }
}
