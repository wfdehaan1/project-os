import XCTest
@testable import ProjectOS

/// Both adapters have to turn their own wire shape into one tool call the app
/// can run, and say plainly when a model cannot do tools at all.
final class ProviderToolCallTests: XCTestCase {
    func testOllamaReportsAToolCallAsOneCompleteCall() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OllamaToolCallStub.self]
        let ollama = try OllamaConfiguration(modelID: "qwen3:8b", contextWindowTokens: 8_192)
        let adapter = OllamaAdapter(configuration: ollama, session: URLSession(configuration: configuration))

        var calls: [AIToolCall] = []
        for try await event in try await adapter.events(for: request(for: ollama)) {
            if case .toolCall(let call) = event { calls.append(call) }
        }

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.name, "web_search")
        XCTAssertEqual(
            WebResearchToolbox.arguments(of: try XCTUnwrap(calls.first))["query"],
            "drainage rules",
            "Ollama sends arguments as an object; the app keeps them as the JSON text a tool reads."
        )
    }

    func testOllamaSaysWhenTheChosenModelCannotUseTools() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OllamaNoToolSupportStub.self]
        let ollama = try OllamaConfiguration(modelID: "gemma3:12b", contextWindowTokens: 8_192)
        let adapter = OllamaAdapter(configuration: ollama, session: URLSession(configuration: configuration))

        do {
            _ = try await adapter.events(for: request(for: ollama))
            XCTFail("A model without tool support must be named as the problem.")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .toolsUnsupported)
        }
    }

    func testOpenRouterAssemblesToolCallsStreamedInFragments() throws {
        var assembler = OpenRouterToolCallAssembler()
        XCTAssertTrue(assembler.isEmpty)

        for fragment in try fragments(#"""
        [{"index":0,"id":"call_abc","function":{"name":"web_search","arguments":"{\"que"}},
         {"index":0,"function":{"arguments":"ry\":\"drainage\"}"}},
         {"index":1,"id":"call_def","function":{"name":"read_page","arguments":"{}"}}]
        """#) {
            assembler.add(fragment)
        }

        let calls = try assembler.finish()
        XCTAssertEqual(calls.map(\.id), ["call_abc", "call_def"])
        XCTAssertEqual(calls.first?.name, "web_search")
        XCTAssertEqual(calls.first?.arguments, "{\"query\":\"drainage\"}")
        XCTAssertEqual(calls.last?.arguments, "{}")
    }

    func testOpenRouterRejectsAToolCallThatNeverNamedItsTool() throws {
        var assembler = OpenRouterToolCallAssembler()
        for fragment in try fragments(#"[{"index":0,"function":{"arguments":"{}"}}]"#) {
            assembler.add(fragment)
        }

        XCTAssertThrowsError(try assembler.finish())
    }

    func testRequestWithToolsIsRefusedForATransportThatCannotOfferThem() {
        let descriptor = ProviderDescriptor(
            id: .ollama,
            displayName: "Ollama",
            modelID: "local",
            configurationID: UUID(),
            executionBoundary: .local,
            contextWindowTokens: 8_192,
            maximumOutputTokens: 1_000,
            capabilities: ProviderCapabilities(streaming: true, structuredOutput: true, cancellation: true, toolCalling: false)
        )
        let withTools = AIRequest(projectID: UUID(), projectRevision: 1, purpose: .chat, providerID: .ollama, modelID: "local", configurationID: descriptor.configurationID, messages: [AIMessage(role: .user, content: "hi")], tools: WebResearchToolbox.definitions, maximumOutputTokens: 1_000)

        XCTAssertThrowsError(try ProviderRequestValidator.validate(withTools, against: descriptor)) { error in
            XCTAssertEqual(error as? AIProviderError, .toolsUnsupported)
        }
    }

    func testToolDefinitionsAndCallsCountTowardsTheContextBound() {
        let plain = AIRequest(projectID: UUID(), projectRevision: 1, purpose: .chat, providerID: .ollama, modelID: "local", configurationID: UUID(), messages: [AIMessage(role: .user, content: "hi")], maximumOutputTokens: 100)
        let withTools = AIRequest(projectID: UUID(), projectRevision: 1, purpose: .chat, providerID: .ollama, modelID: "local", configurationID: UUID(), messages: [AIMessage(role: .user, content: "hi")], tools: WebResearchToolbox.definitions, maximumOutputTokens: 100)

        XCTAssertGreaterThan(
            ProviderRequestValidator.promptUpperBound(of: withTools),
            ProviderRequestValidator.promptUpperBound(of: plain)
        )
    }

    // MARK: - Helpers

    private func request(for ollama: OllamaConfiguration) -> AIRequest {
        AIRequest(
            projectID: UUID(),
            projectRevision: 1,
            purpose: .chat,
            providerID: .ollama,
            modelID: ollama.modelID,
            configurationID: ollama.id,
            messages: [AIMessage(role: .user, content: "What are the drainage rules?")],
            tools: WebResearchToolbox.definitions,
            maximumOutputTokens: 500
        )
    }

    private func fragments(_ json: String) throws -> [OpenRouterToolCallAssembler.Fragment] {
        try JSONDecoder().decode([OpenRouterToolCallAssembler.Fragment].self, from: Data(json.utf8))
    }
}

private final class OllamaToolCallStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"""
        {"model":"qwen3:8b","message":{"content":"","tool_calls":[{"function":{"name":"web_search","arguments":{"query":"drainage rules"}}}]},"done":false}
        {"model":"qwen3:8b","message":{"content":""},"done":true,"eval_count":12}

        """#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class OllamaNoToolSupportStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"error":"registry.ollama.ai/library/gemma3:12b does not support tools"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
