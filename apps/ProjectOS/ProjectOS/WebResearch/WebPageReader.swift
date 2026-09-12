import Foundation

protocol WebPageReading: Sendable {
    func read(_ url: URL) async throws -> WebPageSnapshot
}

/// Downloads one page and keeps its readable text.
///
/// Requests carry no cookies or stored credentials, follow redirects only to
/// other public HTTPS pages, and stop at a size limit. What it returns is
/// exactly what is retained if the page is later saved as a source, so evidence
/// quotes keep matching even after the live page changes.
struct WebPageReader: WebPageReading {
    /// Enough for a long article; beyond this a page is not reading matter.
    static let maximumBytes = 5_000_000
    /// The store's own limit on a source's text.
    static let maximumCharacters = 250_000

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 60
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration, delegate: PublicRedirectsOnlyDelegate(), delegateQueue: nil)
        }
    }

    func read(_ url: URL) async throws -> WebPageSnapshot {
        guard PublicWebURLPolicy.allows(url) else { throw WebResearchError.pageNotAllowed }
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.1", forHTTPHeaderField: "Accept")
        request.setValue("ProjectOS (personal research assistant)", forHTTPHeaderField: "User-Agent")

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw WebResearchError.pageUnavailable(0)
        }
        guard let http = response as? HTTPURLResponse else { throw WebResearchError.pageUnreadable }
        guard (200..<300).contains(http.statusCode) else { throw WebResearchError.pageUnavailable(http.statusCode) }
        // A redirect this policy refused arrives here as the redirect itself.
        let finalURL = http.url ?? url
        guard PublicWebURLPolicy.allows(finalURL) else { throw WebResearchError.pageNotAllowed }

        let mimeType = (http.mimeType ?? "text/html").lowercased()
        let isHTML = mimeType == "text/html" || mimeType == "application/xhtml+xml"
        guard isHTML || mimeType == "text/plain" || mimeType == "text/markdown" else {
            throw WebResearchError.unsupportedPageType(mimeType)
        }
        if http.expectedContentLength > Int64(Self.maximumBytes) { throw WebResearchError.pageTooLarge }

        var data = Data()
        data.reserveCapacity(min(Self.maximumBytes, 1_000_000))
        for try await byte in bytes {
            data.append(byte)
            if data.count > Self.maximumBytes { throw WebResearchError.pageTooLarge }
        }

        guard let body = Self.decode(data, encodingName: http.textEncodingName) else {
            throw WebResearchError.pageUnreadable
        }
        let extracted = isHTML
            ? HTMLTextExtractor.extract(from: body)
            : HTMLTextExtractor.Result(title: nil, text: body.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !extracted.text.isEmpty else { throw WebResearchError.noReadableText }

        return WebPageSnapshot(
            url: finalURL,
            title: extracted.title ?? finalURL.host ?? finalURL.absoluteString,
            text: String(extracted.text.prefix(Self.maximumCharacters)),
            fetchedAt: Date()
        )
    }

    /// The server's stated encoding, then UTF-8, then Latin-1, which cannot
    /// fail and keeps a mislabelled page readable.
    static func decode(_ data: Data, encodingName: String?) -> String? {
        if let encodingName {
            let identifier = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            if identifier != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(identifier))
                if let text = String(data: data, encoding: encoding) { return text }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }
}

/// Follows a redirect only when it leads to another public HTTPS page, so a
/// page cannot bounce the app onto this Mac or the local network.
final class PublicRedirectsOnlyDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, PublicWebURLPolicy.allows(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
