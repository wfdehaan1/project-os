import Foundation

public struct OllamaConfiguration: Equatable, Sendable {
    public let id: UUID
    public let modelID: String
    public let baseURL: URL
    public let contextWindowTokens: Int?
    public let maximumOutputTokens: Int
    public let requestTimeout: TimeInterval

    public init(
        id: UUID = UUID(),
        modelID: String,
        baseURL: URL = URL(string: "http://127.0.0.1:11434")!,
        contextWindowTokens: Int?,
        maximumOutputTokens: Int = 4_096,
        requestTimeout: TimeInterval = 120
    ) throws {
        try OllamaConfiguration.validate(baseURL: baseURL)
        let normalizedModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedModel.isEmpty else {
            throw AIProviderError.invalidConfiguration("Select an installed Ollama model.")
        }
        guard !Self.isCloudModel(normalizedModel) else {
            throw AIProviderError.invalidConfiguration("Cloud-backed Ollama models are outside the local execution boundary.")
        }
        guard maximumOutputTokens > 0, requestTimeout > 0 else {
            throw AIProviderError.invalidConfiguration("Ollama output and timeout limits must be positive.")
        }
        self.id = id
        self.modelID = normalizedModel
        self.baseURL = baseURL
        self.contextWindowTokens = contextWindowTokens
        self.maximumOutputTokens = maximumOutputTokens
        self.requestTimeout = requestTimeout
    }

    private static func validate(baseURL: URL) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "http",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let host = components.host,
              isNumericLoopback(host),
              let port = components.port,
              (1...65_535).contains(port) else {
            throw AIProviderError.invalidConfiguration("Ollama must use an explicit HTTP loopback IP and port, without credentials, path, query, or fragment.")
        }
    }

    private static func isNumericLoopback(_ host: String) -> Bool {
        if host == "::1" { return true }
        let pieces = host.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 4,
              pieces.allSatisfy({ UInt8($0) != nil }) else { return false }
        return pieces[0] == "127"
    }

    private static func isCloudModel(_ model: String) -> Bool {
        let value = model.lowercased()
        return value.hasSuffix(":cloud") || value.contains(":cloud-") || value.hasPrefix("cloud/")
    }
}

public final class OllamaAdapter: AIProvider, @unchecked Sendable {
    public let descriptor: ProviderDescriptor

    private let configuration: OllamaConfiguration
    private let session: URLSession

    public init(configuration: OllamaConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        descriptor = ProviderDescriptor(
            id: .ollama,
            displayName: "Ollama",
            modelID: configuration.modelID,
            configurationID: configuration.id,
            executionBoundary: .local,
            contextWindowTokens: configuration.contextWindowTokens,
            maximumOutputTokens: configuration.maximumOutputTokens,
            capabilities: ProviderCapabilities(streaming: true, structuredOutput: true, cancellation: true)
        )
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
    }

    public func checkConnectivity() async -> ProviderHealth {
        do {
            var request = URLRequest(url: configuration.baseURL.appendingPathComponent("api/tags"))
            request.timeoutInterval = min(configuration.requestTimeout, 10)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return ProviderHealth(isConnected: false, isConfigured: true, recoveryAction: "Start Ollama locally, then retry the connection test.")
            }
            let models = (try? JSONDecoder().decode(TagsResponse.self, from: data).models) ?? []
            let available = models.contains { $0.name == configuration.modelID || $0.model == configuration.modelID }
            return ProviderHealth(
                isConnected: true,
                isConfigured: true,
                selectedModelIsAvailable: available,
                recoveryAction: available ? nil : "Install or select this exact local model, then run an explicit capability test."
            )
        } catch {
            return ProviderHealth(isConnected: false, isConfigured: true, recoveryAction: "Start Ollama locally at the configured loopback address, then retry.")
        }
    }

    public func events(for request: AIRequest) async throws -> AsyncThrowingStream<AIStreamEvent, Error> {
        try ProviderRequestValidator.validate(request, against: descriptor)
        let body = OllamaRequest(
            model: configuration.modelID,
            messages: request.messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            stream: true,
            format: request.structuredOutput?.schema,
            options: .init(numPredict: request.maximumOutputTokens)
        )
        var urlRequest = URLRequest(url: configuration.baseURL.appendingPathComponent("api/chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw AIProviderError.malformedStream }
        guard (200..<300).contains(http.statusCode) else { throw HTTPErrorMapper.map(status: http.statusCode) }
        guard response.url?.host == configuration.baseURL.host,
              response.url?.port == configuration.baseURL.port else {
            throw AIProviderError.invalidConfiguration("Ollama redirected outside the configured loopback endpoint.")
        }

        return AsyncThrowingStream { continuation in
            let producer = Task {
                var lineBuffer = UTF8LineBuffer()
                var receivedCompletion = false
                do {
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        if let line = try lineBuffer.append(byte) {
                            receivedCompletion = try Self.consume(line: line, continuation: continuation) || receivedCompletion
                        }
                    }
                    if let line = try lineBuffer.finish() {
                        receivedCompletion = try Self.consume(line: line, continuation: continuation) || receivedCompletion
                    }
                    guard receivedCompletion else { throw AIProviderError.truncatedOutput }
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

    private static func consume(
        line: String,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) throws -> Bool {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let data = line.data(using: .utf8) else { throw AIProviderError.malformedStream }
        let chunk: OllamaChunk
        do { chunk = try JSONDecoder().decode(OllamaChunk.self, from: data) }
        catch { throw AIProviderError.malformedStream }
        if chunk.error != nil { throw AIProviderError.providerFailure(code: nil) }
        if let content = chunk.message?.content, !content.isEmpty {
            continuation.yield(.textDelta(content))
        }
        if chunk.done == true {
            if chunk.promptEvalCount != nil || chunk.evalCount != nil {
                continuation.yield(.usage(AIUsage(inputTokens: chunk.promptEvalCount, outputTokens: chunk.evalCount)))
            }
            continuation.yield(.completed(AICompletionMetadata(modelID: chunk.model ?? "unknown")))
            return true
        }
        return false
    }
}

private struct OllamaRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    struct Options: Encodable {
        let numPredict: Int
        enum CodingKeys: String, CodingKey { case numPredict = "num_predict" }
    }
    let model: String
    let messages: [Message]
    let stream: Bool
    let format: JSONValue?
    let options: Options
}

private struct OllamaChunk: Decodable {
    struct Message: Decodable { let content: String? }
    let model: String?
    let message: Message?
    let done: Bool?
    let error: String?
    let promptEvalCount: Int?
    let evalCount: Int?
    enum CodingKeys: String, CodingKey {
        case model, message, done, error
        case promptEvalCount = "prompt_eval_count"
        case evalCount = "eval_count"
    }
}

private struct TagsResponse: Decodable {
    struct Model: Decodable { let name: String?; let model: String? }
    let models: [Model]
}
