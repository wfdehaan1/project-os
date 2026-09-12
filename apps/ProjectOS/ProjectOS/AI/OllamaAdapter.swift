import Foundation

public struct OllamaConfiguration: Equatable, Sendable {
    public let id: UUID
    public let modelID: String
    public let baseURL: URL
    public let contextWindowTokens: Int?
    public let maximumOutputTokens: Int
    /// Longest silence tolerated while waiting for the next byte — covers model
    /// load and prompt evaluation before the first token. It does not bound the
    /// whole generation: a local model may stream for many minutes, and Stop
    /// cancels it explicitly.
    public let requestTimeout: TimeInterval

    public init(
        id: UUID = UUID(),
        modelID: String,
        baseURL: URL = URL(string: "http://127.0.0.1:11434")!,
        contextWindowTokens: Int?,
        maximumOutputTokens: Int = 4_096,
        requestTimeout: TimeInterval = 300
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

    static func validate(baseURL: URL) throws {
        guard LoopbackEndpoint.isValid(baseURL) else {
            throw AIProviderError.invalidConfiguration("Ollama must use an explicit HTTP loopback IP and port, without credentials, path, query, or fragment.")
        }
    }

    static func isCloudModel(_ model: String) -> Bool {
        let value = model.lowercased()
        // Ollama names cloud-backed tags `name:cloud` or `name:size-cloud`.
        return value.hasSuffix(":cloud") || value.hasSuffix("-cloud") || value.contains(":cloud-") || value.hasPrefix("cloud/")
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
            capabilities: ProviderCapabilities(streaming: true, structuredOutput: true, cancellation: true, toolCalling: true)
        )
        self.session = session ?? Self.makeSession(Self.generationSessionConfiguration(idleTimeout: configuration.requestTimeout))
    }

    /// Generation is bounded by silence, not duration: a 12B model producing
    /// structured proposals routinely streams past two minutes, and a total cap
    /// cut those off mid-answer.
    static func generationSessionConfiguration(idleTimeout: TimeInterval) -> URLSessionConfiguration {
        sessionConfiguration(idleTimeout: idleTimeout, totalTimeout: 24 * 60 * 60)
    }

    private static func sessionConfiguration(idleTimeout: TimeInterval, totalTimeout: TimeInterval) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = idleTimeout
        config.timeoutIntervalForResource = totalTimeout
        config.httpCookieStorage = nil
        config.urlCache = nil
        return config
    }

    private static func makeSession(_ config: URLSessionConfiguration) -> URLSession {
        URLSession(configuration: config, delegate: RejectRedirectsDelegate(), delegateQueue: nil)
    }

    /// Lists the models installed in the Ollama at `baseURL`, for an explicit
    /// lookup in Settings. Cloud-backed models are left out because they are
    /// outside the local execution boundary.
    public static func installedModels(at baseURL: URL, session: URLSession? = nil) async throws -> [String] {
        try OllamaConfiguration.validate(baseURL: baseURL)
        let activeSession = session ?? makeSession(sessionConfiguration(idleTimeout: 10, totalTimeout: 10))
        defer { if session == nil { activeSession.finishTasksAndInvalidate() } }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await activeSession.data(from: baseURL.appendingPathComponent("api/tags")) }
        catch { throw AIProviderError.unavailable("Start Ollama locally at the configured loopback address, then retry.") }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIProviderError.unavailable("Start Ollama locally, then retry the model lookup.")
        }
        guard let tags = try? JSONDecoder().decode(TagsResponse.self, from: data) else {
            throw AIProviderError.malformedStream
        }
        let names = tags.models
            .filter { $0.remoteHost == nil }
            .compactMap { $0.name ?? $0.model }
            .filter { !OllamaConfiguration.isCloudModel($0) }
        return Set(names).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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
            messages: request.messages.map(OllamaRequest.Message.init),
            stream: true,
            format: request.structuredOutput?.schema,
            options: .init(numPredict: request.maximumOutputTokens, numCtx: configuration.contextWindowTokens),
            tools: request.tools.isEmpty ? nil : request.tools.map(OllamaRequest.Tool.init)
        )
        var urlRequest = URLRequest(url: configuration.baseURL.appendingPathComponent("api/chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw AIProviderError.malformedStream }
        guard (200..<300).contains(http.statusCode) else {
            if !request.tools.isEmpty, http.statusCode == 400, await Self.reportsMissingToolSupport(bytes) {
                throw AIProviderError.toolsUnsupported
            }
            throw HTTPErrorMapper.map(status: http.statusCode)
        }
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

    /// Ollama rejects tools for a model without tool support with a 400 whose
    /// error names it; any other 400 keeps its plain status.
    private static func reportsMissingToolSupport(_ bytes: URLSession.AsyncBytes) async -> Bool {
        var body = Data()
        do {
            for try await byte in bytes {
                body.append(byte)
                if body.count >= 4_096 { break }
            }
        } catch { return false }
        return String(decoding: body, as: UTF8.self).lowercased().contains("does not support tools")
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
        // Ollama sends each tool call whole, in the chunk that makes it.
        for call in chunk.message?.toolCalls ?? [] {
            guard let name = call.function.name, !name.isEmpty else { throw AIProviderError.malformedStream }
            let arguments = call.function.arguments
                .flatMap { try? JSONEncoder().encode($0) }
                .map { String(decoding: $0, as: UTF8.self) } ?? "{}"
            continuation.yield(.toolCall(AIToolCall(id: call.id ?? "call_\(UUID().uuidString)", name: name, arguments: arguments)))
        }
        if chunk.done == true {
            // Ollama reports a normal-looking completion when it stops at
            // `num_predict`; the text is cut mid-answer, so never pass it on as
            // complete.
            if chunk.doneReason == "length" { throw AIProviderError.outputLimitReached }
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
    struct Message: Encodable {
        struct ToolCall: Encodable {
            struct Function: Encodable { let name: String; let arguments: JSONValue }
            let function: Function
        }
        let role: String
        let content: String
        let toolCalls: [ToolCall]?
        let toolName: String?
        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
            case toolName = "tool_name"
        }

        init(_ message: AIMessage) {
            role = message.role.rawValue
            content = message.content
            // Ollama takes arguments as an object, not the text the model wrote.
            toolCalls = message.toolCalls.isEmpty ? nil : message.toolCalls.map { call in
                let arguments = (try? JSONDecoder().decode(JSONValue.self, from: Data(call.arguments.utf8))) ?? .object([:])
                return ToolCall(function: .init(name: call.name, arguments: arguments))
            }
            toolName = message.toolName
        }
    }
    struct Tool: Encodable {
        struct Function: Encodable { let name: String; let description: String; let parameters: JSONValue }
        let type = "function"
        let function: Function

        init(_ tool: AIToolDefinition) {
            function = Function(name: tool.name, description: tool.description, parameters: tool.parameters)
        }
    }
    struct Options: Encodable {
        let numPredict: Int
        /// Without this Ollama uses its own default window and silently
        /// truncates prompts that the configured bound allowed.
        let numCtx: Int?
        enum CodingKeys: String, CodingKey {
            case numPredict = "num_predict"
            case numCtx = "num_ctx"
        }
    }
    let model: String
    let messages: [Message]
    let stream: Bool
    let format: JSONValue?
    let options: Options
    let tools: [Tool]?
}

private struct OllamaChunk: Decodable {
    struct Message: Decodable {
        struct ToolCall: Decodable {
            struct Function: Decodable { let name: String?; let arguments: JSONValue? }
            let id: String?
            let function: Function
        }
        let content: String?
        let toolCalls: [ToolCall]?
        enum CodingKeys: String, CodingKey {
            case content
            case toolCalls = "tool_calls"
        }
    }
    let model: String?
    let message: Message?
    let done: Bool?
    let doneReason: String?
    let error: String?
    let promptEvalCount: Int?
    let evalCount: Int?
    enum CodingKeys: String, CodingKey {
        case model, message, done, error
        case doneReason = "done_reason"
        case promptEvalCount = "prompt_eval_count"
        case evalCount = "eval_count"
    }
}

private struct TagsResponse: Decodable {
    struct Model: Decodable {
        let name: String?
        let model: String?
        let remoteHost: String?
        enum CodingKeys: String, CodingKey {
            case name, model
            case remoteHost = "remote_host"
        }
    }
    let models: [Model]
}
