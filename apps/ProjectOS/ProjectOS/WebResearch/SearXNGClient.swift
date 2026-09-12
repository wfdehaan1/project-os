import Foundation

protocol WebSearching: Sendable {
    func search(_ query: String) async throws -> [WebSearchResult]
}

/// Searches through a SearXNG running on this Mac.
///
/// SearXNG has no index of its own: it passes the query to the engines it is
/// configured for and merges what they return. Queries therefore leave this Mac,
/// which is why web research is off unless a conversation turns it on.
struct SearXNGClient: WebSearching {
    static let defaultURL = "http://127.0.0.1:8888"
    static let maximumResults = 8

    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession? = nil) throws {
        guard LoopbackEndpoint.isValid(baseURL) else { throw WebResearchError.invalidSearchEndpoint }
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.httpCookieStorage = nil
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration, delegate: RejectRedirectsDelegate(), delegateQueue: nil)
        }
    }

    func search(_ query: String) async throws -> [WebSearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "safesearch", value: "1")
        ]
        guard let url = components?.url else { throw WebResearchError.invalidSearchEndpoint }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw WebResearchError.searchUnavailable
        }
        guard let http = response as? HTTPURLResponse else { throw WebResearchError.malformedSearchResponse }
        switch http.statusCode {
        case 200: break
        // SearXNG answers a format it was not configured to serve with 403.
        case 403: throw WebResearchError.jsonFormatDisabled
        default: throw WebResearchError.searchFailed(http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw WebResearchError.malformedSearchResponse
        }

        var seen: Set<URL> = []
        var results: [WebSearchResult] = []
        for item in decoded.results {
            guard results.count < Self.maximumResults,
                  let url = URL(string: item.url),
                  PublicWebURLPolicy.allows(url),
                  seen.insert(url).inserted else { continue }
            results.append(WebSearchResult(
                title: clean(item.title) ?? url.host ?? item.url,
                url: url,
                snippet: clean(item.content) ?? ""
            ))
        }
        return results
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    private struct Response: Decodable {
        struct Item: Decodable {
            let url: String
            let title: String?
            let content: String?
        }
        let results: [Item]
    }
}
