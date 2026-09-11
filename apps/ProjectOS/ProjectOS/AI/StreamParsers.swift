import Foundation

struct UTF8LineBuffer: Sendable {
    private var bytes = Data()

    mutating func append(_ byte: UInt8) throws -> String? {
        guard byte == 0x0A else {
            bytes.append(byte)
            return nil
        }
        return try takeLine()
    }

    mutating func finish() throws -> String? {
        guard !bytes.isEmpty else { return nil }
        return try takeLine()
    }

    private mutating func takeLine() throws -> String {
        if bytes.last == 0x0D { bytes.removeLast() }
        guard let line = String(data: bytes, encoding: .utf8) else {
            bytes.removeAll(keepingCapacity: true)
            throw AIProviderError.malformedStream
        }
        bytes.removeAll(keepingCapacity: true)
        return line
    }
}

struct SSEDataParser: Sendable {
    private var dataLines: [String] = []

    mutating func consume(line: String) -> String? {
        if line.isEmpty {
            return flush()
        }
        if line.hasPrefix(":") { return nil }
        guard line == "data" || line.hasPrefix("data:") else { return nil }
        var value = line == "data" ? "" : String(line.dropFirst(5))
        if value.first == " " { value.removeFirst() }
        dataLines.append(value)
        return nil
    }

    mutating func finish() -> String? { flush() }

    private mutating func flush() -> String? {
        guard !dataLines.isEmpty else { return nil }
        defer { dataLines.removeAll(keepingCapacity: true) }
        return dataLines.joined(separator: "\n")
    }
}

final class RejectRedirectsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

enum HTTPErrorMapper {
    static func map(status: Int) -> AIProviderError {
        switch status {
        case 402: .billingRejected
        case 429: .rateLimited
        default: .httpStatus(status)
        }
    }
}
