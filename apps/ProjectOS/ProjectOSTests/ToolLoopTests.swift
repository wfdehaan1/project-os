import XCTest
@testable import ProjectOS

/// A reply that uses tools is several provider requests, not one. These pin how
/// results travel back to the model, and that a turn always ends in an answer
/// rather than running on.
final class ToolLoopTests: XCTestCase {
    func testToolResultGoesBackToTheModelWhichThenAnswers() async throws {
        let call = AIToolCall(id: "call_1", name: "web_search", arguments: "{\"query\":\"drainage\"}")
        let script = Script(rounds: [
            [.toolCall(call), .completed(AICompletionMetadata(modelID: "local"))],
            [.textDelta("Rainwater stays on the plot."), .completed(AICompletionMetadata(modelID: "local"))]
        ])
        let recorder = Recorder()

        try await ToolLoop.run(
            messages: [AIMessage(role: .user, content: "What are the drainage rules?")],
            tools: WebResearchToolbox.definitions,
            contextLimit: 32_000,
            makeRequest: { messages, tools in Self.request(messages: messages, tools: tools) },
            start: { request in script.next(for: request) },
            execute: { call, budget in
                recorder.budgets.append(budget)
                return "Results for \(WebResearchToolbox.arguments(of: call)["query"] ?? "")"
            },
            emit: { event in if case .textDelta(let text) = event { recorder.text += text } }
        )

        XCTAssertEqual(recorder.text, "Rainwater stays on the plot.")
        XCTAssertEqual(script.requests.count, 2, "One request to ask for the tool, one to answer.")
        let second = script.requests[1].messages
        XCTAssertEqual(second[second.count - 2].toolCalls, [call], "The model's own tool call is replayed to it.")
        XCTAssertEqual(second.last?.role, .tool)
        XCTAssertEqual(second.last?.content, "Results for drainage")
        XCTAssertEqual(second.last?.toolCallID, "call_1")
        XCTAssertEqual(recorder.budgets.count, 1)
        XCTAssertGreaterThan(recorder.budgets[0], 0)
    }

    func testUsageIsSummedAcrossTheWholeTurn() async throws {
        let call = AIToolCall(id: "call_1", name: "web_search", arguments: "{}")
        let script = Script(rounds: [
            [.usage(AIUsage(inputTokens: 100, outputTokens: 10)), .toolCall(call), .completed(AICompletionMetadata(modelID: "local"))],
            [.usage(AIUsage(inputTokens: 400, outputTokens: 40)), .textDelta("Done"), .completed(AICompletionMetadata(modelID: "local"))]
        ])
        let recorder = Recorder()

        try await ToolLoop.run(
            messages: [AIMessage(role: .user, content: "Ask")],
            tools: WebResearchToolbox.definitions,
            contextLimit: 32_000,
            makeRequest: { messages, tools in Self.request(messages: messages, tools: tools) },
            start: { request in script.next(for: request) },
            execute: { _, _ in "Results" },
            emit: { event in if case .usage(let usage) = event { recorder.usage = usage } }
        )

        XCTAssertEqual(recorder.usage?.inputTokens, 500)
        XCTAssertEqual(recorder.usage?.outputTokens, 50)
    }

    func testAModelThatOnlyKeepsResearchingIsStopped() async {
        let call = AIToolCall(id: "call_1", name: "web_search", arguments: "{}")
        let script = Script(rounds: Array(repeating: [.toolCall(call), .completed(AICompletionMetadata(modelID: "local"))], count: 4))

        do {
            try await ToolLoop.run(
                messages: [AIMessage(role: .user, content: "Ask")],
                tools: WebResearchToolbox.definitions,
                maximumRounds: 3,
                contextLimit: 32_000,
                makeRequest: { messages, tools in Self.request(messages: messages, tools: tools) },
                start: { request in script.next(for: request) },
                execute: { _, _ in "Results" },
                emit: { _ in }
            )
            XCTFail("A turn that never answers must fail rather than run on.")
        } catch {
            XCTAssertEqual(error as? ToolLoopError, .noAnswer)
            XCTAssertEqual(script.requests.count, 3)
        }
    }

    func testResultBudgetShrinksWithWhatTheRequestAlreadyUses() {
        let overfull = Self.request(messages: [AIMessage(role: .user, content: String(repeating: "x", count: 30_000))], tools: [])
        let crowded = Self.request(messages: [AIMessage(role: .user, content: String(repeating: "x", count: 20_000))], tools: [])
        let roomy = Self.request(messages: [AIMessage(role: .user, content: "short")], tools: [])

        XCTAssertEqual(ToolLoop.resultBudget(for: overfull, contextLimit: 24_000, sharedBy: 1), 0, "With no room left, no page is sent at all.")

        let crowdedBudget = ToolLoop.resultBudget(for: crowded, contextLimit: 24_000, sharedBy: 1)
        XCTAssertGreaterThan(crowdedBudget, 0)
        XCTAssertLessThan(crowdedBudget, ToolLoop.defaultResultBudget, "A full context leaves a page less room than the cap.")

        XCTAssertEqual(
            ToolLoop.resultBudget(for: roomy, contextLimit: 200_000, sharedBy: 1),
            ToolLoop.defaultResultBudget,
            "A roomy window still caps one result, so a single page cannot crowd out the answer."
        )

        // Sharing only bites when the room is scarce; two calls then get half each.
        let shared = ToolLoop.resultBudget(for: roomy, contextLimit: 24_000, sharedBy: 2)
        let alone = ToolLoop.resultBudget(for: roomy, contextLimit: 24_000, sharedBy: 1)
        XCTAssertGreaterThan(shared, 0)
        XCTAssertLessThan(shared, alone / 2 + 500)
    }

    private static func request(messages: [AIMessage], tools: [AIToolDefinition]) -> AIRequest {
        AIRequest(
            projectID: UUID(),
            projectRevision: 1,
            purpose: .chat,
            providerID: .ollama,
            modelID: "local",
            configurationID: UUID(),
            messages: messages,
            tools: tools,
            maximumOutputTokens: 1_000
        )
    }
}

/// The provider's side of the turn: one scripted round per request.
private final class Script: @unchecked Sendable {
    private var rounds: [[AIStreamEvent]]
    private(set) var requests: [AIRequest] = []

    init(rounds: [[AIStreamEvent]]) {
        self.rounds = rounds
    }

    func next(for request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        requests.append(request)
        let events = rounds.isEmpty ? [] : rounds.removeFirst()
        return AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}

private final class Recorder: @unchecked Sendable {
    var text = ""
    var usage: AIUsage?
    var budgets: [Int] = []
}
