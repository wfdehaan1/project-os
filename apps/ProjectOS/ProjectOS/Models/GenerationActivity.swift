import Foundation

/// The provider request the window is working on, described in the product's
/// own words. A project runs one request at a time, so there is at most one.
///
/// It stays after the request ends so the outcome can still be read; a
/// completed request clears itself, a failed or stopped one waits to be
/// dismissed.
struct GenerationActivity: Identifiable, Equatable {
    enum Outcome: Equatable {
        case completed(String)
        case failed(String)
        case stopped
    }

    /// How one step of the request reads in the timeline.
    enum StepState: Equatable {
        case done
        case current
        case failed
        case stopped
        case pending
        case skipped
    }

    /// The inference job this activity describes.
    let id: UUID
    let projectID: UUID
    let projectName: String
    let purpose: AIJobPurpose
    let provider: ProviderChoice
    let model: String
    /// The configured OpenRouter upstream route; `nil` for a local model.
    let route: String?
    let contextSummary: String
    /// Whether this reply may search the web, which adds a step of its own.
    let usesWebResearch: Bool
    private(set) var phase: AIJobPhase = .preparing
    private(set) var outcome: Outcome?
    /// The search or page the model is on, while it is researching.
    private(set) var researchNote: String?

    init(
        id: UUID,
        projectID: UUID,
        projectName: String,
        purpose: AIJobPurpose,
        provider: ProviderChoice,
        model: String,
        route: String?,
        contextSummary: String,
        usesWebResearch: Bool = false
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.purpose = purpose
        self.provider = provider
        self.model = model
        self.route = route
        self.contextSummary = contextSummary
        self.usesWebResearch = usesWebResearch
    }

    var isRunning: Bool { outcome == nil }
    var runsLocally: Bool { provider == .ollama }

    var steps: [AIJobPhase] {
        guard usesWebResearch, purpose == .chat else { return purpose.steps }
        return [.preparing, .waiting, .researching, .receiving]
    }

    /// Moves to a later phase. Phases never go back, and an ended request
    /// stays where it ended, so a late event cannot rewrite what happened.
    @discardableResult
    mutating func advance(to next: AIJobPhase) -> Bool {
        guard isRunning, next > phase else { return false }
        phase = next
        return true
    }

    /// Names what the model is looking at right now. Only meaningful while the
    /// request runs.
    @discardableResult
    mutating func note(_ note: String?) -> Bool {
        guard isRunning, researchNote != note else { return false }
        researchNote = note
        return true
    }

    /// Records how the request ended. Only the first ending counts.
    @discardableResult
    mutating func finish(_ ending: Outcome) -> Bool {
        guard isRunning else { return false }
        outcome = ending
        researchNote = nil
        return true
    }

    func state(of step: AIJobPhase) -> StepState {
        if case .completed = outcome { return .done }
        if step < phase { return .done }
        if step > phase { return isRunning ? .pending : .skipped }
        switch outcome {
        case nil: return .current
        case .failed: return .failed
        case .stopped: return .stopped
        case .completed: return .done
        }
    }

    /// The status line the sidebar shows.
    var headline: String {
        switch outcome {
        case nil: researchNote ?? phase.title(for: purpose)
        case .completed(let message): message
        case .failed: "\(purpose.activityTitle) failed"
        case .stopped: "\(purpose.activityTitle) stopped"
        }
    }

    /// "2 sources · 5 records · 12 messages", leaving out what was not sent.
    static func contextSummary(includesDescription: Bool, sources: Int, records: Int, messages: Int) -> String {
        var parts: [String] = []
        if includesDescription { parts.append("project description") }
        if sources > 0 { parts.append(counted(sources, "source")) }
        if records > 0 { parts.append(counted(records, "record")) }
        if messages > 0 { parts.append(counted(messages, "message")) }
        guard !parts.isEmpty else { return "No project context" }
        let joined = parts.joined(separator: " · ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    private static func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}

extension AIJobPurpose {
    var activityTitle: String {
        switch self {
        case .chat: "Reply"
        case .proposals: "Project updates"
        case .nextAction: "Next action"
        }
    }

    /// The steps this kind of request goes through, in order. A reply streams
    /// straight into the conversation, so it has nothing to check or save.
    var steps: [AIJobPhase] {
        switch self {
        case .chat: [.preparing, .waiting, .receiving]
        case .proposals, .nextAction: [.preparing, .waiting, .receiving, .checking, .saving]
        }
    }
}

extension AIJobPhase {
    func title(for purpose: AIJobPurpose) -> String {
        switch (self, purpose) {
        case (.preparing, _): "Preparing context"
        case (.waiting, _): "Waiting for the model"
        case (.researching, _): "Researching the web"
        case (.receiving, .chat): "Writing the reply"
        case (.receiving, .proposals): "Drafting project updates"
        case (.receiving, .nextAction): "Drafting the next action"
        case (.checking, .nextAction): "Checking the suggestion"
        case (.checking, _): "Checking evidence"
        case (.saving, .proposals): "Saving for review"
        case (.saving, _): "Saving"
        }
    }

    /// What is actually going on during this step, shown for the current one.
    func detail(for purpose: AIJobPurpose, runsLocally: Bool, route: String?) -> String {
        switch (self, purpose) {
        case (.preparing, _):
            return "Assembling the selected context into a request."
        case (.waiting, _):
            if runsLocally {
                return "Ollama loads the model into memory if it isn't already, then reads the context. With a large context this is usually the longest step."
            }
            let destination = route.map { "to \($0)" } ?? "upstream"
            return "OpenRouter forwards the request \(destination), and the model reads the context before it starts writing."
        case (.researching, _):
            let cost = runsLocally ? "" : " Each step is another request to OpenRouter."
            return "The model searches through SearXNG and reads pages it found. Every search and page appears in the reply.\(cost)"
        case (.receiving, .chat):
            return "The reply appears in the conversation as it arrives."
        case (.receiving, _):
            return "The model is writing a structured answer. Nothing is shown until it has been checked."
        case (.checking, .nextAction):
            return "Every supporting record must exist at the version the model cited."
        case (.checking, _):
            return "Every quoted piece of evidence must match its source exactly, or nothing is saved."
        case (.saving, _):
            return "Storing the result on this Mac. Accepted project state does not change."
        }
    }
}
