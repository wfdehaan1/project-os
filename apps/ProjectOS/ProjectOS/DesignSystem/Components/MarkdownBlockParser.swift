import Foundation

/// One block of assistant Markdown.
///
/// Foundation's `AttributedString(markdown:)` only styles inline runs well, so
/// block structure — headings, lists, fences, tables, quotes — is recognised
/// here and each block's inline text is styled separately.
enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list([MarkdownListItem])
    case quote([MarkdownBlock])
    case code(language: String?, text: String)
    case table(header: [String], rows: [[String]])
    case rule
}

struct MarkdownListItem: Equatable, Sendable {
    enum Marker: Equatable, Sendable {
        case bullet
        case number(Int)
        case task(done: Bool)
    }

    /// Nesting depth, 0 for top-level items.
    var level: Int
    var marker: Marker
    var text: String
}

/// Splits Markdown into blocks. Tolerant by design: model output streams in,
/// so an unclosed fence or half-written table must still render sensibly.
enum MarkdownBlockParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        var scanner = Scanner(lines: normalized.components(separatedBy: "\n"))
        return scanner.parseBlocks()
    }
}

/// Inline styling — emphasis, code spans, links, strikethrough — for the text
/// of a single block.
enum MarkdownInline {
    private static let options = AttributedString.MarkdownParsingOptions(
        allowsExtendedAttributes: false,
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    static func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Scanner

private struct Scanner {
    let lines: [String]
    var index = 0

    mutating func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        while index < lines.count {
            let line = lines[index]
            if line.isBlank {
                index += 1
            } else if let fence = Fence(line) {
                blocks.append(parseCode(fence))
            } else if let heading = Self.heading(line) {
                blocks.append(heading)
                index += 1
            } else if Self.isRule(line) {
                blocks.append(.rule)
                index += 1
            } else if Self.quoteContent(line) != nil {
                blocks.append(parseQuote())
            } else if Self.listItem(line) != nil {
                blocks.append(parseList())
            } else if isTableStart(at: index) {
                blocks.append(parseTable())
            } else {
                blocks.append(parseParagraph())
            }
        }
        return blocks
    }

    // MARK: Block parsers

    private mutating func parseCode(_ fence: Fence) -> MarkdownBlock {
        index += 1
        var code: [String] = []
        while index < lines.count {
            let line = lines[index]
            index += 1
            if fence.isClosed(by: line) { break }
            code.append(String(line.dropLeadingSpaces(upTo: fence.indent)))
        }
        return .code(language: fence.language, text: code.joined(separator: "\n"))
    }

    private mutating func parseQuote() -> MarkdownBlock {
        var content: [String] = []
        while index < lines.count, let inner = Self.quoteContent(lines[index]) {
            content.append(inner)
            index += 1
        }
        var inner = Scanner(lines: content)
        return .quote(inner.parseBlocks())
    }

    private mutating func parseList() -> MarkdownBlock {
        var items: [MarkdownListItem] = []
        var indents: [Int] = []
        var sawBlank = false

        while index < lines.count {
            let line = lines[index]
            if line.isBlank {
                // A list only continues past blank lines into another item or
                // an indented continuation of the current one.
                var next = index + 1
                while next < lines.count, lines[next].isBlank { next += 1 }
                guard next < lines.count else { index = next; break }
                let following = lines[next]
                let continues = Self.listItem(following) != nil
                    || (following.leadingIndent >= 2 && Fence(following) == nil)
                guard continues, !Self.isRule(following) else { break }
                sawBlank = true
                index = next
            } else if Self.isRule(line) || Fence(line) != nil {
                break
            } else if let item = Self.listItem(line) {
                while let last = indents.last, last > item.indent { indents.removeLast() }
                if indents.last.map({ $0 < item.indent }) ?? true { indents.append(item.indent) }
                items.append(MarkdownListItem(level: indents.count - 1, marker: item.marker, text: item.text))
                sawBlank = false
                index += 1
            } else if startsBlock(at: index) || items.isEmpty {
                break
            } else {
                items[items.count - 1].text += (sawBlank ? "\n\n" : "\n") + line.trimmed
                sawBlank = false
                index += 1
            }
        }
        return .list(items)
    }

    private mutating func parseTable() -> MarkdownBlock {
        let header = Self.cells(lines[index])
        index += 2
        var rows: [[String]] = []
        while index < lines.count, !lines[index].isBlank, lines[index].contains("|") {
            var row = Self.cells(lines[index])
            if row.count < header.count {
                row += Array(repeating: "", count: header.count - row.count)
            }
            rows.append(Array(row.prefix(header.count)))
            index += 1
        }
        return .table(header: header, rows: rows)
    }

    private mutating func parseParagraph() -> MarkdownBlock {
        var text: [String] = [lines[index].trimmed]
        index += 1
        while index < lines.count, !lines[index].isBlank, !startsBlock(at: index) {
            text.append(lines[index].trimmed)
            index += 1
        }
        return .paragraph(text.joined(separator: "\n"))
    }

    // MARK: Line classification

    private func startsBlock(at index: Int) -> Bool {
        let line = lines[index]
        return Fence(line) != nil
            || Self.heading(line) != nil
            || Self.isRule(line)
            || Self.quoteContent(line) != nil
            || Self.listItem(line) != nil
            || isTableStart(at: index)
    }

    private func isTableStart(at index: Int) -> Bool {
        guard index + 1 < lines.count, lines[index].contains("|") else { return false }
        let separator = lines[index + 1]
        guard separator.contains("-") else { return false }
        let cells = Self.cells(separator)
        let isSeparator = cells.allSatisfy { cell in
            cell.contains("-") && cell.allSatisfy { $0 == "-" || $0 == ":" }
        }
        return isSeparator && cells.count == Self.cells(lines[index]).count
    }

    private static func heading(_ line: String) -> MarkdownBlock? {
        guard line.leadingIndent <= 3 else { return nil }
        let content = line.trimmed
        let hashes = content.prefix { $0 == "#" }.count
        guard (1 ... 6).contains(hashes) else { return nil }
        let rest = content.dropFirst(hashes)
        guard rest.isEmpty || rest.first == " " else { return nil }
        var text = rest.trimmed
        // Optional closing sequence: "## Title ##".
        if let closing = text.range(of: #"\s+#+$"#, options: .regularExpression) {
            text = String(text[..<closing.lowerBound])
        } else if text.allSatisfy({ $0 == "#" }) {
            text = ""
        }
        return .heading(level: hashes, text: text)
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.leadingIndent <= 3 else { return false }
        let marks = line.filter { !$0.isWhitespace }
        guard marks.count >= 3, let first = marks.first, "-*_".contains(first) else { return false }
        return marks.allSatisfy { $0 == first }
    }

    private static func quoteContent(_ line: String) -> String? {
        guard line.leadingIndent <= 3 else { return nil }
        let content = line.drop { $0 == " " }
        guard content.first == ">" else { return nil }
        let inner = content.dropFirst()
        return String(inner.first == " " ? inner.dropFirst() : inner)
    }

    private static func listItem(_ line: String) -> (indent: Int, marker: MarkdownListItem.Marker, text: String)? {
        let indent = line.leadingIndent
        let content = line.drop { $0 == " " || $0 == "\t" }

        if let first = content.first, "-*+".contains(first) {
            let rest = content.dropFirst()
            guard rest.first == " " else { return nil }
            let text = rest.trimmed
            for (prefix, done) in [("[ ] ", false), ("[x] ", true), ("[X] ", true)] where text.hasPrefix(prefix) {
                return (indent, .task(done: done), String(text.dropFirst(prefix.count)))
            }
            return (indent, .bullet, text)
        }

        let digits = content.prefix { $0.isASCII && $0.isNumber }
        guard (1 ... 9).contains(digits.count), let number = Int(digits) else { return nil }
        let rest = content.dropFirst(digits.count)
        guard let delimiter = rest.first, delimiter == "." || delimiter == ")" else { return nil }
        let afterDelimiter = rest.dropFirst()
        guard afterDelimiter.first == " " else { return nil }
        return (indent, .number(number), afterDelimiter.trimmed)
    }

    private static func cells(_ line: String) -> [String] {
        var content = Substring(line.trimmed)
        if content.hasPrefix("|") { content = content.dropFirst() }
        if content.hasSuffix("|") { content = content.dropLast() }
        return content.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmed }
    }
}

/// An opening code fence: three or more backticks or tildes.
private struct Fence {
    let character: Character
    let length: Int
    let indent: Int
    let language: String?

    init?(_ line: String) {
        indent = line.leadingIndent
        guard indent <= 3 else { return nil }
        let content = line.trimmed
        guard let first = content.first, first == "`" || first == "~" else { return nil }
        let run = content.prefix { $0 == first }.count
        guard run >= 3 else { return nil }
        let info = content.dropFirst(run).trimmed
        if first == "`", info.contains("`") { return nil }
        character = first
        length = run
        language = info.split(separator: " ").first.map(String.init)
    }

    func isClosed(by line: String) -> Bool {
        let content = line.trimmed
        return content.count >= length && content.allSatisfy { $0 == character }
    }
}

private extension StringProtocol {
    var isBlank: Bool { allSatisfy(\.isWhitespace) }

    var trimmed: String { trimmingCharacters(in: .whitespaces) }

    /// Leading indentation in columns, counting a tab as four.
    var leadingIndent: Int {
        var columns = 0
        for character in self {
            if character == " " { columns += 1 } else if character == "\t" { columns += 4 } else { break }
        }
        return columns
    }

    func dropLeadingSpaces(upTo count: Int) -> SubSequence {
        var remaining = count
        return drop { character in
            guard remaining > 0, character == " " else { return false }
            remaining -= 1
            return true
        }
    }
}
