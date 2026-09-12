import Foundation

/// Reads the text a person would read on a page: its title, and its main
/// content with paragraphs and lists kept, without scripts, styles, navigation,
/// or markup.
///
/// Deliberately plain: no layout engine and no JavaScript, so a page that
/// builds its content in the browser comes back empty and the reader says so.
/// The result is what gets retained when the page is saved as a source, so it
/// stays close to the words on the page rather than being reformatted.
enum HTMLTextExtractor {
    struct Result: Equatable {
        let title: String?
        let text: String
    }

    /// Elements whose content is furniture rather than reading matter.
    private static let discardedElements = [
        "head", "script", "style", "noscript", "template", "svg", "canvas",
        "iframe", "nav", "footer", "aside", "form", "button", "select", "dialog"
    ]

    static func extract(from html: String) -> Result {
        var document = replace(html, #"<!--.*?-->"#, with: " ")
        let title = firstCapture(document, #"<title[^>]*>(.*?)</title\s*>"#)
            .map { collapseSpaces(decodeEntities(stripTags($0))) }
            .flatMap { $0.isEmpty ? nil : $0 }

        for element in discardedElements {
            document = replace(document, "<\(element)\\b[^>]*>.*?</\(element)\\s*>", with: " ")
        }
        document = mainContent(of: document)

        document = replace(document, #"<li\b[^>]*>"#, with: "\n- ")
        document = replace(document, #"<br\s*/?>"#, with: "\n")
        document = replace(document, #"</?(p|div|section|article|header|main|h[1-6]|ul|ol|table|tr|blockquote|pre|dl|dt|dd|figure|figcaption|hr)\b[^>]*>"#, with: "\n\n")
        document = replace(document, #"</?(td|th)\b[^>]*>"#, with: " ")

        return Result(title: title, text: normalize(decodeEntities(stripTags(document))))
    }

    /// The page's own content when it says where that is: `<main>`, else the
    /// longest `<article>`, else everything left.
    private static func mainContent(of document: String) -> String {
        if let main = firstCapture(document, #"<main\b[^>]*>(.*)</main\s*>"#), !main.isEmpty {
            return main
        }
        let articles = captures(document, #"<article\b[^>]*>(.*?)</article\s*>"#)
        if let longest = articles.max(by: { $0.count < $1.count }), !longest.isEmpty {
            return longest
        }
        return document
    }

    // MARK: - Text shaping

    private static func stripTags(_ text: String) -> String {
        replace(text, #"<[a-zA-Z/!?][^>]*>"#, with: "")
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "ndash": "–", "mdash": "—", "hellip": "…", "middot": "·", "bull": "•",
        "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "laquo": "«", "raquo": "»",
        "copy": "©", "reg": "®", "trade": "™", "deg": "°", "plusmn": "±",
        "times": "×", "divide": "÷", "frac12": "½", "frac14": "¼",
        "euro": "€", "pound": "£", "yen": "¥", "cent": "¢", "sect": "§", "para": "¶",
        "shy": "", "zwj": "", "zwnj": "", "ensp": " ", "emsp": " ", "thinsp": " "
    ]

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let pattern = try! NSRegularExpression(pattern: #"&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]{1,10});"#)
        let range = NSRange(text.startIndex..., in: text)
        var result = ""
        var cursor = text.startIndex
        for match in pattern.matches(in: text, range: range) {
            guard let matchRange = Range(match.range, in: text),
                  let nameRange = Range(match.range(at: 1), in: text) else { continue }
            result += text[cursor..<matchRange.lowerBound]
            result += replacement(for: String(text[nameRange])) ?? String(text[matchRange])
            cursor = matchRange.upperBound
        }
        result += text[cursor...]
        return result
    }

    private static func replacement(for name: String) -> String? {
        if name.hasPrefix("#") {
            let digits = name.dropFirst()
            let scalarValue: UInt32? = if digits.hasPrefix("x") || digits.hasPrefix("X") {
                UInt32(digits.dropFirst(), radix: 16)
            } else {
                UInt32(digits)
            }
            guard let scalarValue, let scalar = Unicode.Scalar(scalarValue) else { return nil }
            return String(Character(scalar))
        }
        return namedEntities[name.lowercased()]
    }

    /// Blank space becomes ordinary: single spaces inside a line, at most one
    /// blank line between blocks.
    private static func normalize(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { collapseSpaces(String($0)) }
        var result: [String] = []
        for line in lines {
            if line.isEmpty, result.last?.isEmpty == true { continue }
            result.append(line)
        }
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Called on text that has already been split into lines, so collapsing
    /// every run of whitespace cannot join separate blocks. `\s` is
    /// Unicode-aware here, which covers non-breaking and other exotic spaces.
    private static func collapseSpaces(_ text: String) -> String {
        replace(text, #"\s+"#, with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Matching

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are literals in this file; a failure would be a programming
        // error, not something a page can cause.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }

    private static func replace(_ text: String, _ pattern: String, with replacement: String) -> String {
        regex(pattern).stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
    }

    private static func firstCapture(_ text: String, _ pattern: String) -> String? {
        captures(text, pattern).first
    }

    private static func captures(_ text: String, _ pattern: String) -> [String] {
        regex(pattern)
            .matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { match in Range(match.range(at: 1), in: text).map { String(text[$0]) } }
    }
}
