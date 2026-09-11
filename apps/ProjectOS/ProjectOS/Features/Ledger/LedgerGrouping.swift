import Foundation

/// A named run of records in the state ledger.
struct LedgerGroup: Identifiable {
    let id: String
    let title: String
    let records: [ArtifactRecord]
}

/// Turns accepted records into the ledger's current-state-first ordering.
///
/// The grouping is the product's claim about what matters: what governs now,
/// what is still open, and what recently changed. Keeping it pure means the
/// same rules can be asserted in a test.
enum LedgerGrouping {
    static func groups(
        for records: [ArtifactRecord],
        recentlyChangedWithin days: Int = 14,
        now: Date = Date()
    ) -> [LedgerGroup] {
        let visible = records.filter { $0.state != .removed }

        let governing = visible.filter {
            $0.state == .current || $0.state == .resolved || $0.state == .done
        }
        let openWork = visible.filter {
            $0.state == .open || $0.state == .inProgress || $0.state == .blocked
        }
        let historical = visible.filter { $0.state == .superseded || $0.state == .dismissed }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let recentlyChanged = historical.filter { $0.updatedAt >= cutoff }
        let earlier = historical.filter { $0.updatedAt < cutoff }

        return [
            LedgerGroup(id: "governing", title: "Governing now", records: governing),
            LedgerGroup(id: "open", title: "Open work", records: openWork),
            LedgerGroup(id: "recent", title: "Recently changed", records: recentlyChanged),
            LedgerGroup(id: "earlier", title: "Earlier state", records: earlier),
        ]
        .filter { !$0.records.isEmpty }
    }

    /// Case- and diacritic-insensitive matching across the fields a person
    /// would search by.
    static func matches(_ record: ArtifactRecord, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let haystack = [
            record.title,
            record.content,
            record.rationale ?? "",
            record.decisionSubject ?? "",
        ].joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(trimmed)
    }
}
