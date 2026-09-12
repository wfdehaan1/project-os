import Foundation

enum ToolLoopError: Error, Equatable, LocalizedError {
    case noAnswer

    var errorDescription: String? {
        switch self {
        case .noAnswer: "The model kept asking for web research instead of answering. Ask a narrower question, or turn web research off for this conversation."
        }
    }
}

/// One chat turn in which the model may use tools.
///
/// Each round the model either answers or asks for tools. Tool results are
/// appended to the same conversation and the model continues from them, until
/// it answers or the round limit is reached. Every round is a separate provider
/// request, so with an external provider each one is billed on its own.
enum ToolLoop {
    /// Enough rounds for the toolbox's own search and page limits to be spent
    /// one call at a time, plus the round that answers.
    static let maximumRounds = 10

    /// What a tool result may take of the context window when nothing else
    /// constrains it, in UTF-8 bytes.
    static let defaultResultBudget = 24_000

    /// Below this a result is not worth sending, and the tool is told so.
    static let minimumResultBudget = 400

    static func run(
        messages initial: [AIMessage],
        tools: [AIToolDefinition],
        maximumRounds: Int = ToolLoop.maximumRounds,
        contextLimit: Int?,
        makeRequest: ([AIMessage], [AIToolDefinition]) -> AIRequest,
        start: (AIRequest) async throws -> AsyncThrowingStream<AIStreamEvent, Error>,
        execute: (AIToolCall, Int) async throws -> String,
        emit: (AIStreamEvent) async -> Void
    ) async throws {
        var messages = initial
        var totalUsage: AIUsage?

        for round in 1...maximumRounds {
            let request = makeRequest(messages, tools)
            var answer = ""
            var calls: [AIToolCall] = []

            for try await event in try await start(request) {
                try Task.checkCancellation()
                switch event {
                case .textDelta(let delta):
                    answer += delta
                    await emit(event)
                case .toolCall(let call):
                    calls.append(call)
                case .usage(let usage):
                    let combined = totalUsage?.adding(usage) ?? usage
                    totalUsage = combined
                    await emit(.usage(combined))
                case .completed:
                    await emit(event)
                }
            }

            guard !calls.isEmpty else { return }
            guard round < maximumRounds else { throw ToolLoopError.noAnswer }

            messages.append(AIMessage(role: .assistant, content: answer, toolCalls: calls))
            for (index, call) in calls.enumerated() {
                let remainingCalls = calls.count - index
                let budget = resultBudget(
                    for: makeRequest(messages, tools),
                    contextLimit: contextLimit,
                    sharedBy: remainingCalls
                )
                let result = try await execute(call, budget)
                messages.append(AIMessage(role: .tool, content: result, toolCallID: call.id, toolName: call.name))
            }
        }
    }

    /// What one tool result may take: whatever the configured window has left
    /// once everything already in the request, and the answer, are accounted
    /// for, shared evenly by the calls still to run.
    static func resultBudget(for request: AIRequest, contextLimit: Int?, sharedBy calls: Int) -> Int {
        let share = max(1, calls)
        guard let contextLimit else { return defaultResultBudget / share }
        // Framing per result, plus room for the model's own words about it.
        let reserve = 256 * share
        let remaining = contextLimit - ProviderRequestValidator.upperBound(of: request) - reserve
        return max(0, min(defaultResultBudget, remaining / share))
    }
}
