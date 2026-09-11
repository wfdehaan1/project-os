import SwiftUI

/// Renders Markdown from the model with the design system's type roles.
///
/// Parsing happens per render so a streaming reply restyles as it arrives; an
/// unfinished construct simply shows as plain text until it closes.
struct MarkdownText: View {
    private let blocks: [MarkdownBlock]

    init(_ source: String) {
        blocks = MarkdownBlockParser.parse(source)
    }

    var body: some View {
        MarkdownBlockStack(blocks: blocks)
    }
}

private struct MarkdownBlockStack: View {
    let blocks: [MarkdownBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step3) {
            ForEach(blocks.indices, id: \.self) { index in
                MarkdownBlockView(block: blocks[index])
            }
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    @Environment(\.theme) private var theme

    var body: some View {
        switch block {
        case let .heading(level, text):
            inline(text)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? Spacing.step1 : 0)
        case let .paragraph(text):
            inline(text)
                .font(TypeRole.body)
        case let .list(items):
            VStack(alignment: .leading, spacing: Spacing.step1) {
                ForEach(items.indices, id: \.self) { index in
                    listRow(items[index])
                }
            }
        case let .quote(blocks):
            HStack(alignment: .top, spacing: Spacing.step3) {
                RoundedRectangle(cornerRadius: Stroke.loadBearing)
                    .fill(theme.essentialBoundary.opacity(0.6))
                    .frame(width: Stroke.loadBearing * 2)
                MarkdownBlockStack(blocks: blocks)
                    .foregroundStyle(theme.muted)
            }
            .fixedSize(horizontal: false, vertical: true)
        case let .code(language, text):
            MarkdownCodeBlock(language: language, code: text)
        case let .table(header, rows):
            MarkdownTable(header: header, rows: rows)
        case .rule:
            DecorativeDivider()
        }
    }

    private func inline(_ text: String) -> some View {
        Text(MarkdownInline.attributed(text))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: TypeRole.sectionTitle
        case 2: TypeRole.heading
        default: TypeRole.body.weight(.semibold)
        }
    }

    private func listRow(_ item: MarkdownListItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.step2) {
            marker(item)
                .font(TypeRole.body.monospacedDigit())
                .foregroundStyle(theme.muted)
                .frame(minWidth: Spacing.step4, alignment: .trailing)
            inline(item.text)
                .font(TypeRole.body)
        }
        .padding(.leading, CGFloat(item.level) * Spacing.step4)
    }

    private func marker(_ item: MarkdownListItem) -> Text {
        switch item.marker {
        case .bullet:
            Text(["•", "◦", "▪"][min(item.level, 2)])
        case let .number(number):
            Text("\(number).")
        case let .task(done):
            Text(Image(systemName: done ? "checkmark.square" : "square"))
        }
    }
}

private struct MarkdownCodeBlock: View {
    let language: String?
    let code: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.step1) {
            if let language {
                Text(language)
                    .font(TypeRole.eyebrow)
                    .foregroundStyle(theme.muted)
            }
            ScrollView(.horizontal) {
                Text(code)
                    .font(TypeRole.codeBlock)
                    .fixedSize()
            }
            .scrollIndicators(.automatic)
        }
        .padding(Spacing.step3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.canvas, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(theme.essentialBoundary.opacity(0.35), lineWidth: Stroke.hairline)
        }
    }
}

private struct MarkdownTable: View {
    let header: [String]
    let rows: [[String]]

    @Environment(\.theme) private var theme

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.step3, verticalSpacing: Spacing.step2) {
            GridRow {
                ForEach(header.indices, id: \.self) { column in
                    cell(header[column])
                        .font(TypeRole.body.weight(.semibold))
                }
            }
            DecorativeDivider()
                .gridCellUnsizedAxes(.horizontal)
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(rows[row].indices, id: \.self) { column in
                        cell(rows[row][column])
                            .font(TypeRole.body)
                    }
                }
            }
        }
        .padding(Spacing.step3)
        .background(theme.canvas, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(theme.essentialBoundary.opacity(0.35), lineWidth: Stroke.hairline)
        }
    }

    private func cell(_ text: String) -> some View {
        Text(MarkdownInline.attributed(text))
            .fixedSize(horizontal: false, vertical: true)
    }
}
