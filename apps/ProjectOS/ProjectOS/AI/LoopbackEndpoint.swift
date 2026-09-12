import Foundation

/// A local service on this Mac, reached over plain HTTP: an explicit numeric
/// loopback IP and port, with no credentials, path, query, or fragment.
/// Ollama and SearXNG are both addressed this way.
enum LoopbackEndpoint {
    static func isValid(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "http",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let host = components.host,
              isNumericLoopback(host),
              let port = components.port,
              (1...65_535).contains(port) else {
            return false
        }
        return true
    }

    private static func isNumericLoopback(_ host: String) -> Bool {
        if host == "::1" { return true }
        let pieces = host.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 4,
              pieces.allSatisfy({ UInt8($0) != nil }) else { return false }
        return pieces[0] == "127"
    }
}
