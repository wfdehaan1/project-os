import CoreGraphics
import Foundation

/// Where each node sits, and how an edge travels between two of them.
///
/// The layout is deliberately not a force simulation. Columns come from the
/// artifact type and rows from a stable order, so the same project state always
/// produces the same map — a person can build a reliable mental picture, and
/// ordinary edits never rearrange the canvas underneath them.
enum GraphLayout {
    static let nodeSize = CGSize(width: 212, height: 96)
    static let columnGap: CGFloat = 104
    static let rowGap: CGFloat = 24
    static let margin: CGFloat = 32

    struct Result: Equatable {
        /// Top-left origin per node.
        var positions: [UUID: CGPoint] = [:]
        var size: CGSize = .zero
        /// Node ids per rendered column, left to right.
        var columns: [[UUID]] = []

        func frame(of id: UUID) -> CGRect? {
            positions[id].map { CGRect(origin: $0, size: GraphLayout.nodeSize) }
        }
    }

    /// The knowledge a project accumulates flows from what it came from, through
    /// what it decided, to what that leaves to do. Reading the map left to right
    /// follows that flow.
    static func column(for node: GraphNode) -> Int {
        guard let kind = node.kind else { return 0 }
        switch kind {
        case .topic: return 1
        case .research: return 2
        case .decision: return 3
        case .openQuestion, .task: return 4
        }
    }

    static func layout(_ graph: ProjectGraph) -> Result {
        guard !graph.nodes.isEmpty else { return Result() }

        // Unused columns are closed up, so a project with only research and
        // decisions gets two columns rather than four and two empty gaps.
        let grouped = Dictionary(grouping: graph.ordered, by: column(for:))
        var columns = grouped.keys.sorted().map { grouped[$0]!.sorted { $0.sortKey < $1.sortKey } }

        columns = ordered(columns, graph: graph)

        var positions: [UUID: CGPoint] = [:]
        let tallest = columns.map(height(of:)).max() ?? 0

        for (index, column) in columns.enumerated() {
            let x = margin + CGFloat(index) * (nodeSize.width + columnGap)
            // Columns are centred against the tallest one so the map reads as a
            // balanced whole rather than hanging from the top edge.
            let top = margin + (tallest - height(of: column)) / 2
            for (row, node) in column.enumerated() {
                let step: CGFloat = nodeSize.height + rowGap
                let y: CGFloat = top + CGFloat(row) * step
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }

        let columnCount = CGFloat(columns.count)
        let gapCount = CGFloat(max(columns.count - 1, 0))
        let width: CGFloat = margin * 2 + columnCount * nodeSize.width + gapCount * columnGap
        let height: CGFloat = margin * 2 + tallest
        return Result(
            positions: positions,
            size: CGSize(width: width, height: height),
            columns: columns.map { $0.map(\.id) }
        )
    }

    private static func height(of column: [GraphNode]) -> CGFloat {
        guard !column.isEmpty else { return 0 }
        return CGFloat(column.count) * nodeSize.height + CGFloat(column.count - 1) * rowGap
    }

    /// Orders each column by the average position of what it connects to in the
    /// column before it, which pulls related records level with each other and
    /// takes most crossings out. Ties fall back to the stable order, so the
    /// result stays identical for identical input.
    private static func ordered(_ columns: [[GraphNode]], graph: ProjectGraph) -> [[GraphNode]] {
        var columns = columns
        guard columns.count > 1 else { return columns }

        func reorder(_ column: [GraphNode], against reference: [GraphNode]) -> [GraphNode] {
            var rank: [UUID: Double] = [:]
            for (index, node) in reference.enumerated() {
                rank[node.id] = Double(index)
            }

            var scored: [(node: GraphNode, position: Double)] = []
            for node in column {
                var connected: [Double] = []
                for edge in graph.edges {
                    if edge.sourceID == node.id, let position = rank[edge.targetID] {
                        connected.append(position)
                    }
                    if edge.targetID == node.id, let position = rank[edge.sourceID] {
                        connected.append(position)
                    }
                }
                if connected.isEmpty {
                    // Nothing in the neighbouring column to line up with, so it
                    // keeps the stable order and settles after those that do.
                    scored.append((node, .greatestFiniteMagnitude))
                } else {
                    var total: Double = 0
                    for position in connected { total += position }
                    scored.append((node, total / Double(connected.count)))
                }
            }

            scored.sort { left, right in
                if left.position == right.position {
                    return left.node.sortKey < right.node.sortKey
                }
                return left.position < right.position
            }
            return scored.map(\.node)
        }

        for index in 1 ..< columns.count {
            columns[index] = reorder(columns[index], against: columns[index - 1])
        }
        for index in stride(from: columns.count - 2, through: 0, by: -1) {
            columns[index] = reorder(columns[index], against: columns[index + 1])
        }
        return columns
    }
}

/// The geometry of one drawn relationship. The view turns this into a path; the
/// maths stays here where it can be reasoned about on its own.
struct GraphConnection: Equatable {
    var start: CGPoint
    var control1: CGPoint
    var control2: CGPoint
    var end: CGPoint
    /// Where the relationship's label sits, on the curve itself.
    var midpoint: CGPoint
    /// Direction the curve arrives at the target, in radians.
    var angle: CGFloat

    /// Leaves the side of the source facing the target and arrives at the
    /// facing side of the target, so a line never crosses the node it starts
    /// from.
    init(from source: CGRect, to target: CGRect) {
        let start: CGPoint
        let end: CGPoint
        let isHorizontal: Bool

        if target.minX >= source.maxX {
            start = CGPoint(x: source.maxX, y: source.midY)
            end = CGPoint(x: target.minX, y: target.midY)
            isHorizontal = true
        } else if target.maxX <= source.minX {
            start = CGPoint(x: source.minX, y: source.midY)
            end = CGPoint(x: target.maxX, y: target.midY)
            isHorizontal = true
        } else if target.midY >= source.midY {
            start = CGPoint(x: source.midX, y: source.maxY)
            end = CGPoint(x: target.midX, y: target.minY)
            isHorizontal = false
        } else {
            start = CGPoint(x: source.midX, y: source.minY)
            end = CGPoint(x: target.midX, y: target.maxY)
            isHorizontal = false
        }

        let control1: CGPoint
        let control2: CGPoint
        if isHorizontal {
            let midX = (start.x + end.x) / 2
            control1 = CGPoint(x: midX, y: start.y)
            control2 = CGPoint(x: midX, y: end.y)
        } else {
            let midY = (start.y + end.y) / 2
            control1 = CGPoint(x: start.x, y: midY)
            control2 = CGPoint(x: end.x, y: midY)
        }

        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
        self.midpoint = CGPoint(
            x: (start.x + 3 * control1.x + 3 * control2.x + end.x) / 8,
            y: (start.y + 3 * control1.y + 3 * control2.y + end.y) / 8
        )
        self.angle = atan2(end.y - control2.y, end.x - control2.x)
    }
}
