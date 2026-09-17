import Foundation

private final class CodexRedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum CodexExperimentError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { text } else { "Experiment failed" } }
}

extension JSONValue {
    subscript(acp key: String) -> JSONValue { if case .object(let values) = self { values[key] ?? .null } else { .null } }
    var acpString: String? { if case .string(let value) = self { value } else { nil } }
    var acpArray: [JSONValue] { if case .array(let values) = self { values } else { [] } }
    var acpInt: Int? { if case .number(let value) = self, value.isFinite, value >= 0, value < Double(Int.max) { Int(value) } else { nil } }
    var acpBool: Bool { self == .bool(true) }
}

@MainActor
protocol CodexExperimentTransport: AnyObject {
    func rpc(_ method: String, _ params: [String: JSONValue]) async throws -> JSONValue
    func events(after cursor: Int) async throws -> JSONValue
    func permission(id: String, optionID: String) async throws
}

/// Pairing secrets stay in memory. No provider credentials pass through this client.
@MainActor
final class CodexLoopbackTransport: CodexExperimentTransport {
    let port: Int
    private let token: String
    private let session: URLSession

    init(pairing: String) throws {
        let parts = pairing.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let port = Int(parts[0]), (1...65535).contains(port),
              parts[1].count == 64, parts[1].allSatisfy({ $0.isHexDigit }) else {
            throw CodexExperimentError.message("Paste the helper's complete PORT:TOKEN pairing code.")
        }
        self.port = port
        token = String(parts[1])
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 660
        config.timeoutIntervalForResource = 660
        config.httpCookieStorage = nil
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: CodexRedirectBlocker(), delegateQueue: nil)
    }

    func rpc(_ method: String, _ params: [String: JSONValue] = [:]) async throws -> JSONValue {
        let response = try await request(path: "/rpc", body: .object(["method": .string(method), "params": .object(params)]))
        return response[acp: "result"]
    }

    func events(after cursor: Int) async throws -> JSONValue { try await request(path: "/events?after=\(cursor == -1 ? "latest" : String(cursor))") }

    func permission(id: String, optionID: String) async throws {
        _ = try await request(path: "/permission", body: .object(["id": .string(id), "optionId": .string(optionID)]))
    }

    private func request(path: String, body: JSONValue? = nil) async throws -> JSONValue {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpMethod = "POST"
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw CodexExperimentError.message(value[acp: "error"][acp: "message"].acpString ?? "Helper connection failed. Restart helper and resume.")
        }
        return value
    }
}
