import Foundation

enum WebResearchError: Error, Equatable, LocalizedError {
    case invalidSearchEndpoint
    case searchUnavailable
    case jsonFormatDisabled
    case searchFailed(Int)
    case malformedSearchResponse
    case pageNotAllowed
    case pageUnavailable(Int)
    case unsupportedPageType(String)
    case pageTooLarge
    case pageUnreadable
    case noReadableText

    var errorDescription: String? {
        switch self {
        case .invalidSearchEndpoint:
            "SearXNG must run on this Mac at an explicit HTTP loopback address and port, such as http://127.0.0.1:8888, without credentials, path, query, or fragment."
        case .searchUnavailable:
            "SearXNG did not answer. Start it on this Mac at the configured address, then try again."
        case .jsonFormatDisabled:
            "SearXNG refused to answer in JSON. Add json to search.formats in its settings.yml and restart it."
        case .searchFailed(let status):
            "SearXNG returned HTTP \(status)."
        case .malformedSearchResponse:
            "SearXNG returned results ProjectOS could not read."
        case .pageNotAllowed:
            "Only public HTTPS pages can be read, and only ones found by searching in this reply or named in the question."
        case .pageUnavailable(let status):
            "The page returned HTTP \(status)."
        case .unsupportedPageType(let type):
            "Only HTML and plain-text pages can be read; this one is \(type)."
        case .pageTooLarge:
            "The page is larger than ProjectOS reads."
        case .pageUnreadable:
            "The page's text could not be decoded."
        case .noReadableText:
            "The page has no readable text. It may build its content in the browser."
        }
    }
}
