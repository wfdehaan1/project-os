import Foundation

/// Where a source came from when it was kept from the web: the page it was
/// read from, and when ProjectOS downloaded the text that was retained.
///
/// The retained text is a copy taken at that moment. The live page may since
/// have changed, which is why the moment is part of the record.
struct SourceOrigin: Codable, Hashable, Sendable {
    var url: URL
    var title: String
    var fetchedAt: Date

    /// Whether this origin describes the same retrieval as `page`. Times are
    /// compared with a second's tolerance, because they travel through JSON.
    func matches(_ page: WebPageSnapshot) -> Bool {
        url == page.url && abs(fetchedAt.timeIntervalSince(page.fetchedAt)) < 1
    }
}

struct WebSearchResult: Codable, Hashable, Sendable {
    var title: String
    var url: URL
    var snippet: String
}

/// The text ProjectOS read from one page, kept exactly as read so it can later
/// be saved as a source and quoted as evidence.
struct WebPageSnapshot: Codable, Hashable, Sendable {
    var url: URL
    var title: String
    var text: String
    var fetchedAt: Date

    var origin: SourceOrigin { SourceOrigin(url: url, title: title, fetchedAt: fetchedAt) }
}

/// One thing the model did on the web while writing a reply. The trail is kept
/// with the reply, so what an answer rests on stays visible afterwards.
struct WebResearchStep: Codable, Hashable, Identifiable, Sendable {
    enum Action: String, Codable, Sendable {
        case search
        case read
    }

    enum Status: String, Codable, Sendable {
        case running
        case done
        case failed
    }

    let id: UUID
    var action: Action
    /// The search query, or the address of the page to read.
    var subject: String
    var status: Status
    var results: [WebSearchResult]?
    var page: WebPageSnapshot?
    var failure: String?

    init(
        id: UUID = UUID(),
        action: Action,
        subject: String,
        status: Status,
        results: [WebSearchResult]? = nil,
        page: WebPageSnapshot? = nil,
        failure: String? = nil
    ) {
        self.id = id
        self.action = action
        self.subject = subject
        self.status = status
        self.results = results
        self.page = page
        self.failure = failure
    }

    /// How a step that never finished is recorded once the reply has ended.
    func interrupted() -> WebResearchStep {
        guard status == .running else { return self }
        var step = self
        step.status = .failed
        step.failure = "Stopped before it finished."
        return step
    }
}
