import XCTest
@testable import ProjectOS

final class ProviderContractTests: XCTestCase {
    func testUTF8LineBufferReassemblesSplitUnicodeAndLines() throws {
        var buffer = UTF8LineBuffer()
        let bytes = Array("{\"text\":\"drainage € 🧵\"}\n".utf8)
        var line: String?
        for byte in bytes { if let completed = try buffer.append(byte) { line = completed } }
        XCTAssertEqual(line, "{\"text\":\"drainage € 🧵\"}")
        XCTAssertNil(try buffer.finish())
    }

    func testSSEParserCombinesDataLinesAndFlushesFinalEvent() {
        var parser = SSEDataParser()
        XCTAssertNil(parser.consume(line: ": keepalive"))
        XCTAssertNil(parser.consume(line: "data: {\"first\":"))
        XCTAssertNil(parser.consume(line: "data: true}"))
        XCTAssertEqual(parser.consume(line: ""), "{\"first\":\ntrue}")
        XCTAssertNil(parser.consume(line: "data: [DONE]"))
        XCTAssertEqual(parser.finish(), "[DONE]")
    }

    func testOllamaRejectsRemoteCredentialAndCloudBackedConfiguration() {
        XCTAssertThrowsError(try OllamaConfiguration(modelID: "local", baseURL: URL(string: "https://example.com:11434")!, contextWindowTokens: 8_192))
        XCTAssertThrowsError(try OllamaConfiguration(modelID: "local", baseURL: URL(string: "http://user:secret@127.0.0.1:11434")!, contextWindowTokens: 8_192))
        XCTAssertThrowsError(try OllamaConfiguration(modelID: "model:cloud", contextWindowTokens: 8_192))
        XCTAssertThrowsError(try OllamaConfiguration(modelID: "gpt-oss:120b-cloud", contextWindowTokens: 8_192))
        XCTAssertNoThrow(try OllamaConfiguration(modelID: "local", baseURL: URL(string: "http://127.0.0.2:11434")!, contextWindowTokens: 8_192))
    }

    func testOllamaGenerationIsBoundedBySilenceNotDuration() throws {
        let ollama = try OllamaConfiguration(modelID: "gemma4:12b", contextWindowTokens: 8_192)
        let session = OllamaAdapter.generationSessionConfiguration(idleTimeout: ollama.requestTimeout)
        XCTAssertGreaterThanOrEqual(session.timeoutIntervalForRequest, 300)
        // Proposal generation on a local 12B model ran past a two-minute total cap.
        XCTAssertGreaterThanOrEqual(session.timeoutIntervalForResource, 60 * 60)
    }

    func testOllamaLengthStopIsReportedAsOutputLimit() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OllamaLengthStopStub.self]
        let ollama = try OllamaConfiguration(modelID: "gemma4:12b", contextWindowTokens: 8_192)
        let adapter = OllamaAdapter(configuration: ollama, session: URLSession(configuration: configuration))
        let request = AIRequest(projectID: UUID(), projectRevision: 0, purpose: .proposals, providerID: .ollama, modelID: "gemma4:12b", configurationID: ollama.id, messages: [AIMessage(role: .user, content: "test")], structuredOutput: StructuredOutputSchema(name: "test", schema: .object(["type": .string("object")])), maximumOutputTokens: 100, approvedSpendingCeilingUSD: nil)

        do {
            for try await _ in try await adapter.events(for: request) {}
            XCTFail("Output cut off at num_predict must not be treated as complete.")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .outputLimitReached)
        }
    }

    func testOllamaModelLookupListsOnlyLocalModels() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OllamaTagsStub.self]
        let models = try await OllamaAdapter.installedModels(
            at: URL(string: "http://127.0.0.1:11434")!,
            session: URLSession(configuration: configuration)
        )
        XCTAssertEqual(models, ["llama3.2:latest", "qwen3:8b"])
    }

    func testOllamaModelLookupRejectsNonLoopbackURL() async {
        do {
            _ = try await OllamaAdapter.installedModels(at: URL(string: "http://example.com:11434")!)
            XCTFail("A non-loopback Ollama URL must be rejected before any request.")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .invalidConfiguration("Ollama must use an explicit HTTP loopback IP and port, without credentials, path, query, or fragment."))
        }
    }

    func testOpenRouterRequiresStableModelAndPinnedRoute() {
        XCTAssertThrowsError(try OpenRouterConfiguration(modelID: "auto", upstreamProvider: "provider", contextWindowTokens: 16_384))
        XCTAssertThrowsError(try OpenRouterConfiguration(modelID: "model-a,model-b", upstreamProvider: "provider", contextWindowTokens: 16_384))
        XCTAssertThrowsError(try OpenRouterConfiguration(modelID: "model-a", upstreamProvider: "one,two", contextWindowTokens: 16_384))
        XCTAssertNoThrow(try OpenRouterConfiguration(modelID: "vendor/model", upstreamProvider: "upstream", contextWindowTokens: 16_384))
    }

    func testOpenRouterPriceFilterBoundsConfiguredRequest() {
        let request = AIRequest(projectID: UUID(), projectRevision: 0, purpose: .chat, providerID: .openRouter, modelID: "vendor/model", configurationID: UUID(), messages: [AIMessage(role: .user, content: "test")], maximumOutputTokens: 1_000, approvedSpendingCeilingUSD: Decimal(string: "0.03"))
        let ceiling = Decimal(string: "0.03")!
        let price = OpenRouterAdapter.maxPrice(for: request, ceiling: ceiling)
        let promptUpperBound = Decimal("test".utf8.count + 16)
        let worstPromptCost = price.prompt * promptUpperBound / Decimal(1_000_000)
        let worstCompletionCost = price.completion * Decimal(request.maximumOutputTokens) / Decimal(1_000_000)
        XCTAssertLessThanOrEqual(worstPromptCost + worstCompletionCost + price.request, ceiling)
    }

    func testFailureMappingAndSecretRedaction() {
        XCTAssertEqual(HTTPErrorMapper.map(status: 402), .billingRejected)
        XCTAssertEqual(HTTPErrorMapper.map(status: 429), .rateLimited)
        XCTAssertEqual(HTTPErrorMapper.map(status: 503), .httpStatus(503))
        let secret = "sk-or-v1-private-value"
        let redacted = SecretRedactor.redact("Authorization: Bearer \(secret); api_key=\(secret)", additionalSecrets: [secret])
        XCTAssertFalse(redacted.contains(secret))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }
}

/// Answers `/api/tags` with two local models, a duplicate, and two cloud-backed
/// ones — one flagged only by name, one only by `remote_host`.
private final class OllamaTagsStub: URLProtocol {
    static let body = Data(#"""
    {"models":[
      {"name":"qwen3:8b","model":"qwen3:8b"},
      {"name":"llama3.2:latest","model":"llama3.2:latest"},
      {"name":"qwen3:8b","model":"qwen3:8b"},
      {"name":"gpt-oss:120b-cloud","model":"gpt-oss:120b-cloud"},
      {"name":"remote-only","model":"remote-only","remote_host":"https://ollama.com:443"}
    ]}
    """#.utf8)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: request.url?.path == "/api/tags" ? 200 : 404, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Streams half a JSON answer, then the `done_reason: length` stop Ollama sends
/// when it reaches `num_predict`.
private final class OllamaLengthStopStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"""
        {"model":"gemma4:12b","message":{"content":"{\"schemaVer"},"done":false}
        {"model":"gemma4:12b","message":{"content":""},"done":true,"done_reason":"length","eval_count":100}

        """#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
