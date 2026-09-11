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
        XCTAssertNoThrow(try OllamaConfiguration(modelID: "local", baseURL: URL(string: "http://127.0.0.2:11434")!, contextWindowTokens: 8_192))
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
