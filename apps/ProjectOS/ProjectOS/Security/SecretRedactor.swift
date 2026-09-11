import Foundation

public enum SecretRedactor {
    private static let patterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "(?i)bearer\\s+[A-Za-z0-9._~+\\-/]+=*"),
        try! NSRegularExpression(pattern: "(?i)(authorization|api[-_ ]?key|token)\\s*[:=]\\s*[^\\s,;]+"),
        try! NSRegularExpression(pattern: "\\bsk-or-v1-[A-Za-z0-9_-]+\\b")
    ]

    public static func redact(_ input: String, additionalSecrets: [String] = []) -> String {
        var result = input
        for secret in additionalSecrets where !secret.isEmpty {
            result = result.replacingOccurrences(of: secret, with: "[REDACTED]")
        }
        for pattern in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = pattern.stringByReplacingMatches(in: result, range: range, withTemplate: "[REDACTED]")
        }
        return result
    }
}
