import XCTest
@testable import ProjectOS

/// The block parser behind assistant message rendering. Model output streams
/// in, so partial input must degrade to plain text rather than disappear.
final class MarkdownBlockParserTests: XCTestCase {
    func testHeadingsParagraphsAndRules() {
        let blocks = MarkdownBlockParser.parse("""
        # Plan ##
        First line
        second line

        ---
        ### Details
        #hashtag stays text
        """)

        XCTAssertEqual(blocks, [
            .heading(level: 1, text: "Plan"),
            .paragraph("First line\nsecond line"),
            .rule,
            .heading(level: 3, text: "Details"),
            .paragraph("#hashtag stays text"),
        ])
    }

    func testNestedMixedAndLooseLists() {
        let blocks = MarkdownBlockParser.parse("""
        1. **Drainage**
           - Pumped
           - Gravity
             continued

        2. Budget
        - [x] Done
        - [ ] Open
        """)

        XCTAssertEqual(blocks, [
            .list([
                MarkdownListItem(level: 0, marker: .number(1), text: "**Drainage**"),
                MarkdownListItem(level: 1, marker: .bullet, text: "Pumped"),
                MarkdownListItem(level: 1, marker: .bullet, text: "Gravity\ncontinued"),
                MarkdownListItem(level: 0, marker: .number(2), text: "Budget"),
                MarkdownListItem(level: 0, marker: .task(done: true), text: "Done"),
                MarkdownListItem(level: 0, marker: .task(done: false), text: "Open"),
            ]),
        ])
    }

    func testListEndsAtUnindentedParagraph() {
        let blocks = MarkdownBlockParser.parse("- one\n\nAfter the list.")
        XCTAssertEqual(blocks, [
            .list([MarkdownListItem(level: 0, marker: .bullet, text: "one")]),
            .paragraph("After the list."),
        ])
    }

    func testFencedCodeKeepsContentVerbatimAndToleratesMissingClose() {
        let closed = MarkdownBlockParser.parse("```swift\nlet a = 1\n\n  # not a heading\n```\nAfter")
        XCTAssertEqual(closed, [
            .code(language: "swift", text: "let a = 1\n\n  # not a heading"),
            .paragraph("After"),
        ])

        let streaming = MarkdownBlockParser.parse("Run:\n```bash\nnpm install")
        XCTAssertEqual(streaming, [
            .paragraph("Run:"),
            .code(language: "bash", text: "npm install"),
        ])
    }

    func testCodeFenceInsideListItem() {
        let blocks = MarkdownBlockParser.parse("1. Install:\n   ```\n   make\n   ```\n2. Run")
        XCTAssertEqual(blocks, [
            .list([MarkdownListItem(level: 0, marker: .number(1), text: "Install:")]),
            .code(language: nil, text: "make"),
            .list([MarkdownListItem(level: 0, marker: .number(2), text: "Run")]),
        ])
    }

    func testTablesPadShortRows() {
        let blocks = MarkdownBlockParser.parse("""
        | Option | Cost |
        |:-------|-----:|
        | Pumped | €12k |
        | Gravity |
        """)

        XCTAssertEqual(blocks, [
            .table(header: ["Option", "Cost"], rows: [["Pumped", "€12k"], ["Gravity", ""]]),
        ])
    }

    func testPipeWithoutSeparatorIsAParagraph() {
        XCTAssertEqual(MarkdownBlockParser.parse("a | b\nc | d"), [.paragraph("a | b\nc | d")])
    }

    func testBlockQuotesParseTheirContent() {
        let blocks = MarkdownBlockParser.parse("> **Note**\n> - keep\n\nDone")
        XCTAssertEqual(blocks, [
            .quote([
                .paragraph("**Note**"),
                .list([MarkdownListItem(level: 0, marker: .bullet, text: "keep")]),
            ]),
            .paragraph("Done"),
        ])
    }

    func testInlineStylingAndUnclosedEmphasis() {
        let styled = MarkdownInline.attributed("A **bold** and `code` word")
        XCTAssertEqual(String(styled.characters), "A bold and code word")
        let bold = styled.runs.first { String(styled[$0.range].characters) == "bold" }
        XCTAssertEqual(bold?.inlinePresentationIntent, .stronglyEmphasized)

        let partial = MarkdownInline.attributed("Streaming **bol")
        XCTAssertEqual(String(partial.characters), "Streaming **bol")
    }
}
