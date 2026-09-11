import Foundation
import SQLite3

enum ProjectStoreError: LocalizedError {
    case database(String)
    case encoding(String)
    case notFound(String)
    case stale(expected: Int, actual: Int)
    case unsupportedSchema(Int)
    case injectedFailure

    var errorDescription: String? {
        switch self {
        case .database(let message): "Saving failed. The previous coherent state is unchanged. \(message)"
        case .encoding(let message): "Stored project data could not be read: \(message)"
        case .notFound(let item): "\(item) no longer exists. Refresh and try again."
        case .stale(let expected, let actual): "The project changed (expected revision \(expected), now \(actual)). Regenerate or review again."
        case .unsupportedSchema(let version): "This database was created by a newer ProjectOS schema (\(version))."
        case .injectedFailure: "Saving failed during the transaction. The previous coherent state remains available."
        }
    }
}

final class ProjectStore: @unchecked Sendable {
    private let database: OpaquePointer
    let queue = DispatchQueue(label: "ProjectOS.ProjectStore")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    var injectNextCommitFailure = false

    static func defaultURL() throws -> URL {
        let manager = FileManager.default
        let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appending(path: "ProjectOS", directoryHint: .isDirectory)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "projectos.sqlite3")
    }

    init(url: URL) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database"
            if let handle { sqlite3_close(handle) }
            throw ProjectStoreError.database(message)
        }
        database = handle
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            try DatabaseMigration.execute(database, "PRAGMA foreign_keys = ON")
            try DatabaseMigration.execute(database, "PRAGMA journal_mode = WAL")
            try DatabaseMigration.apply(to: database)
        } catch {
            sqlite3_close(database)
            throw error
        }
    }

    deinit { sqlite3_close(database) }

    func projects() throws -> [ProjectRecord] {
        try queue.sync { try fetchAll("SELECT data FROM projects", as: ProjectRecord.self).sorted { $0.updatedAt > $1.updatedAt } }
    }

    func createProject(name: String, summary: String) throws -> ProjectRecord {
        try queue.sync {
            let now = Date()
            let project = ProjectRecord(id: UUID(), name: name, summary: summary, createdAt: now, updatedAt: now, revision: 0, previousVisitRevision: 0)
            try put(project, table: "projects", id: project.id)
            return project
        }
    }

    func saveProject(_ project: ProjectRecord) throws {
        try queue.sync {
            try ensureWritable(project.id)
            try put(project, table: "projects", id: project.id)
        }
    }

    func updateProjectDetails(projectID: UUID, expectedRevision: Int, name: String, summary: String) throws -> ProjectRecord {
        try queue.sync {
            try transaction {
                try ensureWritable(projectID)
                var project = try requireProject(projectID)
                guard project.revision == expectedRevision else { throw ProjectStoreError.stale(expected: expectedRevision, actual: project.revision) }
                project.name = name
                project.summary = summary
                project.revision += 1
                project.updatedAt = Date()
                try put(project, table: "projects", id: project.id)
            }
            return try requireProject(projectID)
        }
    }

    func markVisitBaseline(projectID: UUID, baseline: Int) throws {
        try queue.sync {
            try ensureWritable(projectID)
            guard var project = try fetchOne("SELECT data FROM projects WHERE id = ?", bind: [projectID.uuidString], as: ProjectRecord.self) else {
                throw ProjectStoreError.notFound("Project")
            }
            project.previousVisitRevision = baseline
            project.updatedAt = Date()
            try put(project, table: "projects", id: project.id)
        }
    }

    func deleteProject(_ id: UUID) throws {
        try queue.sync { try execute("DELETE FROM projects WHERE id = ?", bind: [id.uuidString]) }
    }

    func sources(projectID: UUID) throws -> [SourceRecord] {
        try queue.sync { try fetchAll("SELECT data FROM sources WHERE project_id = ?", bind: [projectID.uuidString], as: SourceRecord.self).sorted { $0.createdAt < $1.createdAt } }
    }

    func addSource(projectID: UUID, label: String, text: String) throws -> SourceRecord {
        guard text.count <= 250_000 else { throw ProjectStoreError.encoding("Sources are limited to 250,000 characters.") }
        return try queue.sync {
            try ensureWritable(projectID)
            let source = SourceRecord(id: UUID(), projectID: projectID, label: label, text: text, version: 1, createdAt: Date())
            try put(source, table: "sources", id: source.id, projectID: projectID)
            return source
        }
    }

    func conversations(projectID: UUID) throws -> [ConversationRecord] {
        try queue.sync {
            try fetchAll("SELECT data FROM conversations WHERE project_id = ?", bind: [projectID.uuidString], as: ConversationRecord.self)
                .sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func ensureConversations(projectID: UUID) throws -> [ConversationRecord] {
        try queue.sync {
            var records: [ConversationRecord] = try fetchAll("SELECT data FROM conversations WHERE project_id = ?", bind: [projectID.uuidString], as: ConversationRecord.self)
            if records.isEmpty {
                let existingMessages: [MessageRecord] = try fetchAll("SELECT data FROM messages WHERE project_id = ?", bind: [projectID.uuidString], as: MessageRecord.self)
                let grouped = Dictionary(grouping: existingMessages, by: \.conversationID)
                if grouped.isEmpty {
                    let conversation = ConversationRecord(id: UUID(), projectID: projectID, title: "New conversation", createdAt: Date(), updatedAt: Date())
                    try put(conversation, table: "conversations", id: conversation.id, projectID: projectID)
                    records = [conversation]
                } else {
                    for (id, messages) in grouped {
                        let ordered = messages.sorted { $0.createdAt < $1.createdAt }
                        let title = ordered.first(where: { $0.role == .user })?.text.prefix(48).description ?? "Conversation"
                        let record = ConversationRecord(id: id, projectID: projectID, title: title, createdAt: ordered.first?.createdAt ?? Date(), updatedAt: ordered.last?.createdAt ?? Date())
                        try put(record, table: "conversations", id: record.id, projectID: projectID)
                        records.append(record)
                    }
                }
            }
            return records.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func createConversation(projectID: UUID, researchID: UUID? = nil) throws -> ConversationRecord {
        try queue.sync {
            try ensureWritable(projectID)
            _ = try requireProject(projectID)
            if let researchID {
                guard let research = try fetchOne("SELECT data FROM artifacts WHERE id = ?", bind: [researchID.uuidString], as: ArtifactRecord.self),
                      research.projectID == projectID, research.kind == .research else { throw ProjectStoreError.notFound("Research item") }
            }
            let record = ConversationRecord(id: UUID(), projectID: projectID, title: "New conversation", createdAt: Date(), updatedAt: Date(), researchID: researchID)
            try put(record, table: "conversations", id: record.id, projectID: projectID)
            return record
        }
    }

    func messages(projectID: UUID) throws -> [MessageRecord] {
        try queue.sync { try fetchAll("SELECT data FROM messages WHERE project_id = ?", bind: [projectID.uuidString], as: MessageRecord.self).sorted { $0.createdAt < $1.createdAt } }
    }

    func messages(projectID: UUID, conversationID: UUID) throws -> [MessageRecord] {
        try queue.sync { try fetchAll("SELECT data FROM messages WHERE project_id = ? AND conversation_id = ?", bind: [projectID.uuidString, conversationID.uuidString], as: MessageRecord.self).sorted { $0.createdAt < $1.createdAt } }
    }

    func saveMessage(_ message: MessageRecord) throws {
        try queue.sync {
            try ensureWritable(message.projectID)
            var conversation = try fetchOne("SELECT data FROM conversations WHERE id = ?", bind: [message.conversationID.uuidString], as: ConversationRecord.self)
                ?? ConversationRecord(id: message.conversationID, projectID: message.projectID, title: "New conversation", createdAt: message.createdAt, updatedAt: message.createdAt)
            guard conversation.projectID == message.projectID else { throw ProjectStoreError.encoding("Conversation belongs to another project") }
            if conversation.title == "New conversation", message.role == .user, !message.text.isEmpty { conversation.title = String(message.text.prefix(48)) }
            conversation.updatedAt = message.createdAt
            try put(conversation, table: "conversations", id: conversation.id, projectID: message.projectID)
            try put(message, table: "messages", id: message.id, projectID: message.projectID, conversationID: message.conversationID)
        }
    }

    func draft(projectID: UUID) throws -> String {
        try queue.sync { try scalarText("SELECT text FROM drafts WHERE project_id = ?", bind: [projectID.uuidString]) ?? "" }
    }

    func saveDraft(projectID: UUID, text: String) throws {
        try queue.sync {
            try ensureWritable(projectID)
            try execute("INSERT INTO drafts(project_id, text) VALUES(?, ?) ON CONFLICT(project_id) DO UPDATE SET text=excluded.text", bind: [projectID.uuidString, text])
        }
    }

    func draft(projectID: UUID, conversationID: UUID) throws -> String {
        try queue.sync { try scalarText("SELECT text FROM conversation_drafts WHERE project_id = ? AND conversation_id = ?", bind: [projectID.uuidString, conversationID.uuidString]) ?? "" }
    }

    func saveDraft(projectID: UUID, conversationID: UUID, text: String) throws {
        try queue.sync {
            try ensureWritable(projectID)
            try execute("INSERT INTO conversation_drafts(conversation_id, project_id, text) VALUES(?, ?, ?) ON CONFLICT(conversation_id) DO UPDATE SET text=excluded.text", bind: [conversationID.uuidString, projectID.uuidString, text])
        }
    }

    func artifacts(projectID: UUID) throws -> [ArtifactRecord] {
        try queue.sync { try fetchAll("SELECT data FROM artifacts WHERE project_id = ?", bind: [projectID.uuidString], as: ArtifactRecord.self).sorted { $0.updatedAt > $1.updatedAt } }
    }

    func proposals(projectID: UUID) throws -> [ProposalRecord] {
        try queue.sync { try fetchAll("SELECT data FROM proposals WHERE project_id = ?", bind: [projectID.uuidString], as: ProposalRecord.self).sorted { $0.createdAt > $1.createdAt } }
    }

    func saveProposals(_ proposals: [ProposalRecord], expectedProjectRevision: Int) throws {
        guard let projectID = proposals.first?.projectID else { return }
        guard proposals.allSatisfy({ $0.projectID == projectID }), Set(proposals.map(\.id)).count == proposals.count else {
            throw ProjectStoreError.encoding("Proposal batches require unique IDs in one project.")
        }
        try queue.sync {
            try transaction {
                try ensureWritable(projectID)
                let project = try requireProject(projectID)
                guard project.revision == expectedProjectRevision else { throw ProjectStoreError.stale(expected: expectedProjectRevision, actual: project.revision) }
                for proposal in proposals { try put(proposal, table: "proposals", id: proposal.id, projectID: projectID) }
            }
        }
    }

    func acceptProposal(_ proposalID: UUID, editedTitle: String? = nil, editedContent: String? = nil) throws {
        try queue.sync {
            try transaction {
                guard let root = try fetchOne("SELECT data FROM proposals WHERE id = ?", bind: [proposalID.uuidString], as: ProposalRecord.self) else {
                    throw ProjectStoreError.notFound("Proposal")
                }
                try ensureWritable(root.projectID)
                guard root.lifecycle == .pending || root.lifecycle == .deferred else { return }
                var project = try requireProject(root.projectID)
                let isCurrent = try project.revision == root.originatingRevision
                    || movedOnlyBySameSnapshotAcceptances(projectID: project.id, since: root.originatingRevision, currentRevision: project.revision)
                guard isCurrent else { throw ProjectStoreError.stale(expected: root.originatingRevision, actual: project.revision) }
                let all: [ProposalRecord] = try fetchAll("SELECT data FROM proposals WHERE project_id = ?", bind: [project.id.uuidString], as: ProposalRecord.self)
                let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
                var ordered: [ProposalRecord] = []
                var visiting = Set<UUID>()
                var visited = Set<UUID>()
                func visit(_ id: UUID) throws {
                    guard let proposal = byID[id], proposal.lifecycle == .pending || proposal.lifecycle == .deferred else { throw ProjectStoreError.notFound("Proposal dependency") }
                    guard proposal.originatingRevision == root.originatingRevision else { throw ProjectStoreError.stale(expected: root.originatingRevision, actual: proposal.originatingRevision) }
                    guard visiting.insert(id).inserted else { throw ProjectStoreError.database("Proposal dependencies contain a cycle.") }
                    if !visited.contains(id) {
                        for dependency in proposal.dependencyIDs { try visit(dependency) }
                        ordered.append(proposal)
                        visited.insert(id)
                    }
                    visiting.remove(id)
                }
                try visit(root.id)
                var artifactsByID = Dictionary(uniqueKeysWithValues: try fetchAll("SELECT data FROM artifacts WHERE project_id = ?", bind: [project.id.uuidString], as: ArtifactRecord.self).map { ($0.id, $0) })
                for proposal in ordered where proposal.kind == .decision && proposal.operation == .create {
                    if let subject = normalizedDecisionSubject(proposal.decisionSubject),
                       artifactsByID.values.contains(where: { $0.kind == .decision && $0.state == .current && normalizedDecisionSubject($0.decisionSubject) == subject }) {
                        throw ProjectStoreError.database("A governing decision already exists for this subject. Mark the proposal as an explicit replacement before accepting it.")
                    }
                }
                var resultingArtifactID: [UUID: UUID] = [:]
                for proposal in ordered {
                    switch proposal.operation {
                    case .create, .supersede: resultingArtifactID[proposal.id] = UUID()
                    case .update, .relate:
                        guard let target = proposal.targetID, artifactsByID[target] != nil else { throw ProjectStoreError.notFound("Proposal target") }
                        resultingArtifactID[proposal.id] = target
                    }
                }
                let revision = project.revision + 1
                let transactionID = UUID()
                for var proposal in ordered {
                    let targetBefore = proposal.targetID.flatMap { artifactsByID[$0] }
                    var before = targetBefore
                    let resultID = resultingArtifactID[proposal.id]!
                    var result: ArtifactRecord
                    switch proposal.operation {
                    case .create:
                        result = ArtifactRecord(id: resultID, projectID: project.id, kind: proposal.kind, title: proposal.id == root.id ? editedTitle ?? proposal.title : proposal.title, content: proposal.id == root.id ? editedContent ?? proposal.content : proposal.content, state: proposal.proposedState ?? defaultState(for: proposal.kind), rationale: proposal.rationale, decisionSubject: proposal.decisionSubject, certainty: proposal.certainty, limitations: proposal.limitations, evidence: proposal.evidence, relationships: [], version: 1, updatedAt: Date())
                    case .update:
                        guard var target = targetBefore, proposal.expectedTargetRevision == target.version else { throw ProjectStoreError.notFound("Current proposal target version") }
                        target.title = proposal.id == root.id ? editedTitle ?? proposal.title : proposal.title
                        target.content = proposal.id == root.id ? editedContent ?? proposal.content : proposal.content
                        target.rationale = proposal.rationale
                        target.state = proposal.proposedState ?? target.state
                        target.certainty = proposal.certainty
                        target.limitations = proposal.limitations
                        target.evidence = proposal.evidence
                        target.version += 1
                        target.updatedAt = Date()
                        result = target
                    case .supersede:
                        guard var prior = targetBefore, prior.kind == .decision, proposal.expectedTargetRevision == prior.version else { throw ProjectStoreError.notFound("Decision to supersede") }
                        prior.state = .superseded
                        prior.version += 1
                        prior.updatedAt = Date()
                        try put(prior, table: "artifacts", id: prior.id, projectID: project.id)
                        artifactsByID[prior.id] = prior
                        before = targetBefore
                        result = ArtifactRecord(id: resultID, projectID: project.id, kind: .decision, title: proposal.id == root.id ? editedTitle ?? proposal.title : proposal.title, content: proposal.id == root.id ? editedContent ?? proposal.content : proposal.content, state: .current, rationale: proposal.rationale, decisionSubject: proposal.decisionSubject, certainty: proposal.certainty, limitations: proposal.limitations, evidence: proposal.evidence, relationships: [TypedRelationship(id: UUID(), type: "supersedes", targetArtifactID: prior.id, targetProposalID: nil)], version: 1, updatedAt: Date())
                    case .relate:
                        guard var target = targetBefore, proposal.expectedTargetRevision == target.version else { throw ProjectStoreError.notFound("Artifact to relate") }
                        target.version += 1
                        target.updatedAt = Date()
                        result = target
                    }
                    for relationship in proposal.relationships {
                        let targetID = relationship.targetArtifactID ?? relationship.targetProposalID.flatMap { resultingArtifactID[$0] }
                        guard let targetID, artifactsByID[targetID] != nil || resultingArtifactID.values.contains(targetID) else { throw ProjectStoreError.notFound("Relationship target") }
                        result.relationships.append(TypedRelationship(id: relationship.id, type: relationship.type, targetArtifactID: targetID, targetProposalID: nil))
                    }
                    artifactsByID[result.id] = result
                    proposal.lifecycle = .accepted
                    proposal.acceptedTitle = result.title
                    proposal.acceptedContent = result.content
                    proposal.acceptedArtifactID = result.id
                    let change = ChangeRecord(id: UUID(), projectID: project.id, revision: revision, transactionID: transactionID, summary: proposal.operation == .supersede ? "Superseded decision with: \(result.title)" : "Accepted \(proposal.kind.rawValue): \(result.title)", beforeArtifact: before, afterArtifact: result, createdAt: Date(), undone: false, actor: editedTitle != nil || editedContent != nil ? "user-edited proposal" : "accepted proposal", originatingProposalID: proposal.id)
                    try put(result, table: "artifacts", id: result.id, projectID: project.id)
                    try put(proposal, table: "proposals", id: proposal.id, projectID: project.id)
                    try put(change, table: "changes", id: change.id, projectID: project.id, revision: revision)
                }
                let acceptedIDs = Set(ordered.map(\.id))
                for var dependent in all where (dependent.lifecycle == .pending || dependent.lifecycle == .deferred) && !acceptedIDs.contains(dependent.id) && !acceptedIDs.isDisjoint(with: dependent.dependencyIDs) {
                    dependent.lifecycle = .invalidated
                    try put(dependent, table: "proposals", id: dependent.id, projectID: project.id)
                }
                project.revision += 1
                project.updatedAt = Date()
                try put(project, table: "projects", id: project.id)
            }
        }
    }

    /// Whether every revision after `revision` came from accepting a proposal
    /// generated from that same snapshot, none of them undone. Such siblings were
    /// reviewed against identical state, and the per-target version and
    /// decision-subject checks still stop any overwrite. Any other edit, an undo,
    /// or a proposal from another snapshot leaves the proposal stale.
    private func movedOnlyBySameSnapshotAcceptances(projectID: UUID, since revision: Int, currentRevision: Int) throws -> Bool {
        guard currentRevision > revision else { return false }
        let later: [ChangeRecord] = try fetchAll("SELECT data FROM changes WHERE project_id = ? AND revision > ?", bind: [projectID.uuidString, String(revision)], as: ChangeRecord.self)
        let proposals: [ProposalRecord] = try fetchAll("SELECT data FROM proposals WHERE project_id = ?", bind: [projectID.uuidString], as: ProposalRecord.self)
        let sameSnapshot = Set(proposals.filter { $0.originatingRevision == revision && $0.lifecycle == .accepted }.map(\.id))
        // A revision without a change record (e.g. a details edit) is a change we cannot vouch for.
        guard Set(later.map(\.revision)) == Set((revision + 1)...currentRevision) else { return false }
        return later.allSatisfy { change in
            !change.undone && change.originatingProposalID.map(sameSnapshot.contains) == true
        }
    }

    func setProposal(_ id: UUID, lifecycle: ProposalLifecycle) throws {
        try queue.sync {
            try transaction {
                guard var proposal = try fetchOne("SELECT data FROM proposals WHERE id = ?", bind: [id.uuidString], as: ProposalRecord.self) else { throw ProjectStoreError.notFound("Proposal") }
                try ensureWritable(proposal.projectID)
                proposal.lifecycle = lifecycle
                try put(proposal, table: "proposals", id: id, projectID: proposal.projectID)

                // A dependent proposal cannot remain actionable once one of its
                // prerequisites is rejected or invalidated.
                if lifecycle == .rejected || lifecycle == .invalidated {
                    var pending: [ProposalRecord] = try fetchAll(
                        "SELECT data FROM proposals WHERE project_id = ?",
                        bind: [proposal.projectID.uuidString],
                        as: ProposalRecord.self
                    )
                    var invalidated = Set([id])
                    var changed = true
                    while changed {
                        changed = false
                        for index in pending.indices where pending[index].lifecycle == .pending || pending[index].lifecycle == .deferred {
                            if !invalidated.isDisjoint(with: pending[index].dependencyIDs) {
                                pending[index].lifecycle = .invalidated
                                invalidated.insert(pending[index].id)
                                changed = true
                            }
                        }
                    }
                    for dependent in pending where invalidated.contains(dependent.id) && dependent.id != id {
                        try put(dependent, table: "proposals", id: dependent.id, projectID: dependent.projectID)
                    }
                }
            }
        }
    }

    func markProposalAsSuperseding(_ proposalID: UUID, priorDecisionID: UUID) throws {
        try queue.sync {
            try transaction {
                guard var proposal = try fetchOne("SELECT data FROM proposals WHERE id = ?", bind: [proposalID.uuidString], as: ProposalRecord.self),
                      proposal.lifecycle == .pending || proposal.lifecycle == .deferred else { throw ProjectStoreError.notFound("Pending proposal") }
                try ensureWritable(proposal.projectID)
                guard let prior = try fetchOne("SELECT data FROM artifacts WHERE id = ?", bind: [priorDecisionID.uuidString], as: ArtifactRecord.self),
                      prior.projectID == proposal.projectID, prior.kind == .decision, prior.state == .current else { throw ProjectStoreError.notFound("Governing decision") }
                proposal.operation = .supersede
                proposal.targetID = prior.id
                proposal.expectedTargetRevision = prior.version
                proposal.kind = .decision
                proposal.decisionSubject = prior.decisionSubject
                try put(proposal, table: "proposals", id: proposal.id, projectID: proposal.projectID)
            }
        }
    }

    func saveArtifact(_ artifact: ArtifactRecord, expectedProjectRevision: Int, summary: String) throws {
        try queue.sync {
            try transaction {
                try ensureWritable(artifact.projectID)
                var project = try requireProject(artifact.projectID)
                guard project.revision == expectedProjectRevision else { throw ProjectStoreError.stale(expected: expectedProjectRevision, actual: project.revision) }
                let before = try fetchOne("SELECT data FROM artifacts WHERE id = ?", bind: [artifact.id.uuidString], as: ArtifactRecord.self)
                var changed = artifact
                changed.version = (before?.version ?? 0) + 1
                changed.updatedAt = Date()
                project.revision += 1
                project.updatedAt = Date()
                let existing: [ArtifactRecord] = try fetchAll("SELECT data FROM artifacts WHERE project_id = ?", bind: [project.id.uuidString], as: ArtifactRecord.self)
                if changed.kind == .decision, changed.state == .current, let subject = normalizedDecisionSubject(changed.decisionSubject) {
                    if existing.contains(where: { $0.kind == .decision && $0.state == .current && normalizedDecisionSubject($0.decisionSubject) == subject && $0.id != changed.id }) {
                        throw ProjectStoreError.database("A governing decision already exists for this subject. Correct that record or use an explicitly reviewed replacement proposal.")
                    }
                }
                let transactionID = UUID()
                var relationChanges: [(ArtifactRecord, ArtifactRecord)] = []
                if changed.state == .removed {
                    changed.relationships = []
                    for var other in existing where other.id != changed.id && other.state != .removed && other.relationships.contains(where: { $0.targetArtifactID == changed.id }) {
                        let original = other
                        other.relationships.removeAll { $0.targetArtifactID == changed.id }
                        other.version += 1
                        other.updatedAt = Date()
                        relationChanges.append((original, other))
                    }
                }
                let change = ChangeRecord(id: UUID(), projectID: project.id, revision: project.revision, transactionID: transactionID, summary: summary, beforeArtifact: before, afterArtifact: changed, createdAt: Date(), undone: false, actor: "user")
                try put(changed, table: "artifacts", id: changed.id, projectID: project.id)
                for (original, cleaned) in relationChanges {
                    try put(cleaned, table: "artifacts", id: cleaned.id, projectID: project.id)
                    let relationChange = ChangeRecord(id: UUID(), projectID: project.id, revision: project.revision, transactionID: transactionID, summary: "Removed relationship to \(changed.title)", beforeArtifact: original, afterArtifact: cleaned, createdAt: Date(), undone: false, actor: "user")
                    try put(relationChange, table: "changes", id: relationChange.id, projectID: project.id, revision: project.revision)
                }
                try put(project, table: "projects", id: project.id)
                try put(change, table: "changes", id: change.id, projectID: project.id, revision: project.revision)
            }
        }
    }

    func changes(projectID: UUID, after revision: Int = -1) throws -> [ChangeRecord] {
        try queue.sync { try fetchAll("SELECT data FROM changes WHERE project_id = ? AND revision > ? ORDER BY revision DESC", bind: [projectID.uuidString, String(revision)], as: ChangeRecord.self) }
    }

    func undoLatest(projectID: UUID) throws {
        try queue.sync {
            try transaction {
                var project = try requireProject(projectID)
                let changes: [ChangeRecord] = try fetchAll("SELECT data FROM changes WHERE project_id = ? ORDER BY revision DESC", bind: [projectID.uuidString], as: ChangeRecord.self)
                guard let latest = changes.first(where: { !$0.undone }) else { throw ProjectStoreError.notFound("Undoable change") }
                var transactionChanges = changes.filter { $0.transactionID == latest.transactionID && !$0.undone }
                for index in transactionChanges.indices.reversed() {
                    let change = transactionChanges[index]
                    if let before = change.beforeArtifact {
                        if let after = change.afterArtifact, after.id != before.id { try execute("DELETE FROM artifacts WHERE id = ?", bind: [after.id.uuidString]) }
                        try put(before, table: "artifacts", id: before.id, projectID: projectID)
                    } else if let after = change.afterArtifact {
                        try execute("DELETE FROM artifacts WHERE id = ?", bind: [after.id.uuidString])
                    }
                    transactionChanges[index].undone = true
                    try put(transactionChanges[index], table: "changes", id: change.id, projectID: projectID, revision: change.revision)
                }
                for proposalID in Set(transactionChanges.compactMap(\.originatingProposalID)) {
                    if var proposal = try fetchOne("SELECT data FROM proposals WHERE id = ?", bind: [proposalID.uuidString], as: ProposalRecord.self) {
                        proposal.lifecycle = .pending
                        proposal.acceptedTitle = nil
                        proposal.acceptedContent = nil
                        proposal.acceptedArtifactID = nil
                        try put(proposal, table: "proposals", id: proposal.id, projectID: projectID)
                    }
                }
                project.revision += 1
                project.updatedAt = Date()
                let compensationTransaction = UUID()
                for change in transactionChanges {
                    let compensation = ChangeRecord(id: UUID(), projectID: projectID, revision: project.revision, transactionID: compensationTransaction, summary: "Undid: \(change.summary)", beforeArtifact: change.afterArtifact, afterArtifact: change.beforeArtifact, createdAt: Date(), undone: true)
                    try put(compensation, table: "changes", id: compensation.id, projectID: projectID, revision: compensation.revision)
                }
                try put(project, table: "projects", id: project.id)
            }
        }
    }

    func saveOutcome(_ outcome: ReturnRecord) throws {
        try queue.sync { try ensureWritable(outcome.projectID); try put(outcome, table: "outcomes", id: outcome.id, projectID: outcome.projectID) }
    }

    func outcomes(projectID: UUID) throws -> [ReturnRecord] {
        try queue.sync { try fetchAll("SELECT data FROM outcomes WHERE project_id = ?", bind: [projectID.uuidString], as: ReturnRecord.self) }
    }

    func recommendation(projectID: UUID) throws -> RecommendationRecord? {
        try queue.sync { try fetchAll("SELECT data FROM recommendations WHERE project_id = ?", bind: [projectID.uuidString], as: RecommendationRecord.self).sorted { $0.createdAt > $1.createdAt }.first }
    }

    func saveRecommendation(_ recommendation: RecommendationRecord) throws {
        try queue.sync {
            try transaction {
                try ensureWritable(recommendation.projectID)
                try execute("DELETE FROM recommendations WHERE project_id = ?", bind: [recommendation.projectID.uuidString])
                try put(recommendation, table: "recommendations", id: recommendation.id, projectID: recommendation.projectID)
            }
        }
    }

    func saveJob(_ job: InferenceJobRecord) throws {
        try queue.sync { try ensureWritable(job.projectID); try put(job, table: "jobs", id: job.id, projectID: job.projectID) }
    }

    func jobs(projectID: UUID) throws -> [InferenceJobRecord] {
        try queue.sync { try fetchAll("SELECT data FROM jobs WHERE project_id = ?", bind: [projectID.uuidString], as: InferenceJobRecord.self) }
    }

    func markUnfinishedJobsInterrupted() throws {
        try queue.sync {
            let all: [InferenceJobRecord] = try fetchAll("SELECT data FROM jobs", as: InferenceJobRecord.self)
            for var job in all where job.status == .running {
                job.status = .interrupted
                try put(job, table: "jobs", id: job.id, projectID: job.projectID)
            }
        }
    }

    func restoreArchiveSnapshot(_ snapshot: ProjectArchiveSnapshot) throws {
        try queue.sync {
            try transaction {
                if try fetchOne("SELECT data FROM projects WHERE id = ?", bind: [snapshot.project.id.uuidString], as: ProjectRecord.self) != nil {
                    throw ProjectStoreError.database("The restored project identity already exists.")
                }
                let project = ProjectRecord(id: snapshot.project.id, name: snapshot.project.name, summary: snapshot.project.description, createdAt: snapshot.project.createdAt, updatedAt: snapshot.project.updatedAt, revision: snapshot.project.acceptedStateRevision, previousVisitRevision: snapshot.project.previousVisitRevision)
                try put(project, table: "projects", id: project.id)
                var restoredIDByOriginalID = Dictionary(uniqueKeysWithValues: snapshot.records.compactMap { record in
                    record.importMetadata.map { ($0.originalRecordID, record.id) }
                })
                let archiveDecoder = JSONDecoder()
                archiveDecoder.dateDecodingStrategy = .iso8601
                // A prior create may already have been undone, leaving its
                // artifact only in append-only change payloads. Give those
                // historical identities a stable identity in the restored copy.
                for record in snapshot.records where record.kind == .acceptedChange {
                    for key in ["beforePayload", "afterPayload"] {
                        guard let encoded = record.fields[key]?.stringValue,
                              let data = Data(base64Encoded: encoded),
                              let artifact = try? archiveDecoder.decode(ArtifactRecord.self, from: data) else { continue }
                        if restoredIDByOriginalID[artifact.id] == nil { restoredIDByOriginalID[artifact.id] = UUID() }
                    }
                }
                let contextRecords = Dictionary(uniqueKeysWithValues: snapshot.records.filter { $0.kind == .context }.map { ($0.id, $0) })
                for record in snapshot.records {
                    switch record.kind {
                    case .source:
                        let source = SourceRecord(id: record.id, projectID: project.id, label: record.fields["label"]?.stringValue ?? "Source", text: record.fields["text"]?.stringValue ?? "", version: record.version, createdAt: record.createdAt)
                        try put(source, table: "sources", id: source.id, projectID: project.id)
                    case .message:
                        let conversationID = record.parentID ?? record.references.first(where: { $0.role == "conversation" })?.targetID ?? UUID()
                        guard let roleRaw = record.fields["role"]?.stringValue, let role = MessageRole(rawValue: roleRaw), let completion = MessageCompletion(rawValue: record.state) else { throw ProjectStoreError.encoding("Invalid archived message") }
                        let message = MessageRecord(id: record.id, projectID: project.id, conversationID: conversationID, role: role, text: record.fields["text"]?.stringValue ?? "", completion: completion, createdAt: record.createdAt)
                        try put(message, table: "messages", id: message.id, projectID: project.id, conversationID: conversationID)
                    case .artifact:
                        guard let kindRaw = record.fields["kind"]?.stringValue, let kind = ArtifactKind(rawValue: kindRaw), let state = ArtifactState(rawValue: record.state) else { throw ProjectStoreError.encoding("Invalid archived artifact") }
                        let artifact = ArtifactRecord(id: record.id, projectID: project.id, kind: kind, title: record.fields["title"]?.stringValue ?? "", content: record.fields["content"]?.stringValue ?? "", state: ArtifactRecord.normalizedState(state, kind: kind), rationale: record.fields["rationale"]?.stringValue, decisionSubject: record.fields["decisionSubject"]?.stringValue, certainty: record.fields["certainty"]?.stringValue, limitations: record.fields["limitations"]?.stringValue, evidence: try decodeEvidence(record), relationships: try decodeRelationships(record), version: record.version, updatedAt: record.updatedAt)
                        try put(artifact, table: "artifacts", id: artifact.id, projectID: project.id)
                    case .proposal:
                        guard let kindRaw = record.fields["kind"]?.stringValue, let kind = ArtifactKind(rawValue: kindRaw), let lifecycle = ProposalLifecycle(rawValue: record.state) else { throw ProjectStoreError.encoding("Invalid archived proposal") }
                        guard let operationRaw = record.fields["operation"]?.stringValue,
                              let operation = ProposalOperation(rawValue: operationRaw) else { throw ProjectStoreError.encoding("Invalid archived proposal operation") }
                        let targetID = record.references.first(where: { $0.role == "target" })?.targetID
                        let dependencies = record.references.filter { $0.role.hasPrefix("dependency.") }.sorted { $0.role < $1.role }.map(\.targetID)
                        let proposal = ProposalRecord(id: record.id, projectID: project.id, originatingRevision: record.fields["originatingRevision"]?.intValue ?? 0, operation: operation, targetID: targetID, expectedTargetRevision: record.fields["expectedTargetRevision"]?.intValue, kind: kind, title: record.fields["title"]?.stringValue ?? "", content: record.fields["content"]?.stringValue ?? "", rationale: record.fields["rationale"]?.stringValue, decisionSubject: record.fields["decisionSubject"]?.stringValue, proposedState: record.fields["proposedState"]?.stringValue.flatMap(ArtifactState.init(rawValue:)), certainty: record.fields["certainty"]?.stringValue, limitations: record.fields["limitations"]?.stringValue, evidence: try decodeEvidence(record), relationships: try decodeRelationships(record), dependencyIDs: dependencies, lifecycle: lifecycle, createdAt: record.createdAt, acceptedTitle: record.fields["acceptedTitle"]?.stringValue, acceptedContent: record.fields["acceptedContent"]?.stringValue, acceptedArtifactID: record.references.first(where: { $0.role == "acceptedArtifact" })?.targetID)
                        try put(proposal, table: "proposals", id: proposal.id, projectID: project.id)
                    case .acceptedChange:
                        let before = try decodeArchivedArtifact(record.fields["beforePayload"]?.stringValue, projectID: project.id, idMap: restoredIDByOriginalID, decoder: archiveDecoder)
                        let after = try decodeArchivedArtifact(record.fields["afterPayload"]?.stringValue, projectID: project.id, idMap: restoredIDByOriginalID, decoder: archiveDecoder)
                        let transactionID = record.fields["transactionID"]?.stringValue.flatMap(UUID.init(uuidString:)) ?? UUID()
                        let change = ChangeRecord(id: record.id, projectID: project.id, revision: record.version, transactionID: transactionID, summary: record.fields["summary"]?.stringValue ?? "Imported change", beforeArtifact: before, afterArtifact: after, createdAt: record.createdAt, undone: record.state == "undone", actor: record.fields["actor"]?.stringValue, originatingProposalID: record.references.first(where: { $0.role == "originatingProposal" })?.targetID)
                        try put(change, table: "changes", id: change.id, projectID: project.id, revision: change.revision)
                    case .returnRecord:
                        let outcome = ReturnRecord(id: record.id, projectID: project.id, durationMinutes: record.fields["durationMinutes"]?.intValue ?? 0, understanding: record.fields["understanding"]?.intValue ?? 0, trust: record.fields["trust"]?.intValue ?? 0, usefulness: record.fields["usefulness"]?.intValue ?? 0, resumedWithinFiveMinutes: record.fields["resumedWithinFiveMinutes"]?.boolValue ?? false, actionOutcome: record.fields["actionOutcome"]?.stringValue ?? "", reviewMinutes: record.fields["reviewMinutes"]?.intValue ?? 0, projectOutcome: record.state, notes: record.fields["notes"]?.stringValue ?? "", createdAt: record.createdAt)
                        try put(outcome, table: "outcomes", id: outcome.id, projectID: project.id)
                    case .draft:
                        if let conversationID = record.parentID ?? record.references.first(where: { $0.role == "conversation" })?.targetID {
                            try execute("INSERT INTO conversation_drafts(conversation_id, project_id, text) VALUES(?, ?, ?) ON CONFLICT(conversation_id) DO UPDATE SET text=excluded.text", bind: [conversationID.uuidString, project.id.uuidString, record.fields["text"]?.stringValue ?? ""])
                        } else {
                            try execute("INSERT INTO drafts(project_id, text) VALUES(?, ?) ON CONFLICT(project_id) DO UPDATE SET text=excluded.text", bind: [project.id.uuidString, record.fields["text"]?.stringValue ?? ""])
                        }
                    case .recommendation:
                        let versions = record.fields["supportVersions"]?.arrayValue ?? []
                        let supports = record.references.filter { $0.role.hasPrefix("support.") }.sorted { $0.role < $1.role }.enumerated().map { index, reference in RecommendationSupport(id: reference.targetID, version: versions.indices.contains(index) ? versions[index].intValue ?? 1 : 1) }
                        let recommendation = RecommendationRecord(id: record.id, projectID: project.id, text: record.fields["text"]?.stringValue ?? "", supportingRecords: supports, uncertainty: record.fields["uncertainty"]?.stringValue, originatingRevision: record.fields["originatingRevision"]?.intValue ?? 0, createdAt: record.createdAt, isDismissed: record.state == "dismissed")
                        try put(recommendation, table: "recommendations", id: recommendation.id, projectID: project.id)
                    case .job:
                        guard let contextID = record.parentID ?? record.references.first(where: { $0.role == "context" })?.targetID,
                              let context = contextRecords[contextID],
                              let status = InferenceJobStatus(rawValue: record.state) else { throw ProjectStoreError.encoding("Invalid archived inference job") }
                        let sources = context.references.filter { $0.role.hasPrefix("source.") }.sorted { $0.role < $1.role }.map(\.targetID)
                        let artifacts = context.references.filter { $0.role.hasPrefix("artifact.") }.sorted { $0.role < $1.role }.map(\.targetID)
                        let messages = context.references.filter { $0.role.hasPrefix("message.") }.sorted { $0.role < $1.role }.map(\.targetID)
                        let job = InferenceJobRecord(id: record.id, contextID: contextID, projectID: project.id, sourceRevision: context.fields["sourceRevision"]?.intValue ?? 0, provider: context.fields["provider"]?.stringValue ?? "", model: context.fields["model"]?.stringValue ?? "", configuredUpstreamRoute: context.fields["configuredUpstreamRoute"]?.stringValue, purpose: context.fields["purpose"]?.stringValue ?? "", sourceIDs: sources, artifactIDs: artifacts, messageIDs: messages, createdAt: record.createdAt, status: status == .running ? .interrupted : status, inputTokens: record.fields["inputTokens"]?.intValue, outputTokens: record.fields["outputTokens"]?.intValue, cost: record.fields["cost"]?.stringValue.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }, currency: record.fields["currency"]?.stringValue, actualModel: record.fields["actualModel"]?.stringValue, actualUpstreamProvider: record.fields["actualUpstreamProvider"]?.stringValue)
                        try put(job, table: "jobs", id: job.id, projectID: project.id)
                    case .conversation:
                        let conversation = ConversationRecord(id: record.id, projectID: project.id, title: record.fields["title"]?.stringValue ?? "Conversation", createdAt: record.createdAt, updatedAt: record.updatedAt, researchID: record.references.first(where: { $0.role == "research" })?.targetID)
                        try put(conversation, table: "conversations", id: conversation.id, projectID: project.id)
                    case .relation, .context:
                        continue
                    }
                }
            }
        }
    }

    func createDeletionFence(_ fence: ProjectDeletionFence) throws {
        try queue.sync {
            if try scalarText("SELECT token FROM deletion_tombstones WHERE project_id = ?", bind: [fence.projectID.uuidString]) != nil {
                throw ProjectDeletionError.deletionAlreadyInProgress
            }
            try execute("INSERT INTO deletion_tombstones(project_id, token, created_at) VALUES(?, ?, ?)", bind: [fence.projectID.uuidString, fence.token.uuidString, ISO8601DateFormatter().string(from: Date())])
        }
    }

    func finishDeletion(_ fence: ProjectDeletionFence) throws {
        try queue.sync {
            try transaction {
                guard try scalarText("SELECT token FROM deletion_tombstones WHERE project_id = ?", bind: [fence.projectID.uuidString]) == fence.token.uuidString else {
                    throw ProjectDeletionError.deletionAlreadyInProgress
                }
                try execute("DELETE FROM projects WHERE id = ?", bind: [fence.projectID.uuidString])
            }
        }
    }

    func removeDeletionFence(_ fence: ProjectDeletionFence) throws {
        try queue.sync {
            try execute("DELETE FROM deletion_tombstones WHERE project_id = ? AND token = ?", bind: [fence.projectID.uuidString, fence.token.uuidString])
        }
    }

    private func decodeEvidence(_ record: ArchivedRecord) throws -> [EvidenceRecord] {
        let entries = record.fields["evidence"]?.arrayValue ?? []
        return try entries.enumerated().map { index, value in
            guard let object = value.objectValue,
                  let sourceType = object["sourceType"]?.stringValue,
                  let version = object["version"]?.intValue,
                  let quote = object["quote"]?.stringValue,
                  let sourceID = record.references.first(where: { $0.role == "evidence.\(index)" })?.targetID,
                  let evidenceIDRaw = object["id"]?.stringValue,
                  let evidenceID = UUID(uuidString: evidenceIDRaw) else { throw ProjectStoreError.encoding("Invalid archived evidence") }
            return EvidenceRecord(id: evidenceID, sourceType: sourceType, sourceID: sourceID, version: version, quote: quote, aiAuthored: object["aiAuthored"]?.boolValue ?? false)
        }
    }

    private func decodeRelationships(_ record: ArchivedRecord) throws -> [TypedRelationship] {
        let entries = record.fields["relationships"]?.arrayValue ?? []
        return try entries.enumerated().map { index, value in
            guard let object = value.objectValue,
                  let type = object["type"]?.stringValue,
                  let target = record.references.first(where: { $0.role == "relation.\(index)" })?.targetID,
                  let relationIDRaw = object["id"]?.stringValue,
                  let relationID = UUID(uuidString: relationIDRaw) else { throw ProjectStoreError.encoding("Invalid archived relationship") }
            return TypedRelationship(id: relationID, type: type, targetArtifactID: object["targetsProposal"]?.boolValue == true ? nil : target, targetProposalID: object["targetsProposal"]?.boolValue == true ? target : nil)
        }
    }

    private func decodeArchivedArtifact(_ value: String?, projectID: UUID, idMap: [UUID: UUID], decoder: JSONDecoder) throws -> ArtifactRecord? {
        guard let value, let data = Data(base64Encoded: value) else { return nil }
        let artifact = try decoder.decode(ArtifactRecord.self, from: data)
        guard let restoredID = idMap[artifact.id] else { throw ProjectStoreError.encoding("Archived change references an unknown artifact") }
        let evidence = try artifact.evidence.map { item in
            guard let sourceID = idMap[item.sourceID] else { throw ProjectStoreError.encoding("Archived change references unknown evidence") }
            return EvidenceRecord(id: item.id, sourceType: item.sourceType, sourceID: sourceID, version: item.version, quote: item.quote, aiAuthored: item.aiAuthored)
        }
        let relationships = try artifact.relationships.map { relation -> TypedRelationship in
            let artifactTarget = try relation.targetArtifactID.map { oldID -> UUID in
                guard let mapped = idMap[oldID] else { throw ProjectStoreError.encoding("Archived change references an unknown relationship target") }
                return mapped
            }
            let proposalTarget = try relation.targetProposalID.map { oldID -> UUID in
                guard let mapped = idMap[oldID] else { throw ProjectStoreError.encoding("Archived change references an unknown proposal target") }
                return mapped
            }
            return TypedRelationship(id: relation.id, type: relation.type, targetArtifactID: artifactTarget, targetProposalID: proposalTarget)
        }
        return ArtifactRecord(id: restoredID, projectID: projectID, kind: artifact.kind, title: artifact.title, content: artifact.content, state: artifact.state, rationale: artifact.rationale, decisionSubject: artifact.decisionSubject, certainty: artifact.certainty, limitations: artifact.limitations, evidence: evidence, relationships: relationships, version: artifact.version, updatedAt: artifact.updatedAt)
    }

    private func defaultState(for kind: ArtifactKind) -> ArtifactState {
        kind.initialState
    }

    private func normalizedDecisionSubject(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private func requireProject(_ id: UUID) throws -> ProjectRecord {
        guard let project = try fetchOne("SELECT data FROM projects WHERE id = ?", bind: [id.uuidString], as: ProjectRecord.self) else { throw ProjectStoreError.notFound("Project") }
        return project
    }

    private func ensureWritable(_ projectID: UUID) throws {
        if try scalarText("SELECT token FROM deletion_tombstones WHERE project_id = ?", bind: [projectID.uuidString]) != nil {
            throw ProjectStoreError.notFound("Project being deleted")
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        try DatabaseMigration.execute(database, "BEGIN IMMEDIATE")
        do {
            try body()
            if injectNextCommitFailure {
                injectNextCommitFailure = false
                throw ProjectStoreError.injectedFailure
            }
            try DatabaseMigration.execute(database, "COMMIT")
        } catch {
            _ = try? DatabaseMigration.execute(database, "ROLLBACK")
            throw error
        }
    }

    private func put<T: Encodable>(_ value: T, table: String, id: UUID, projectID: UUID? = nil, conversationID: UUID? = nil, revision: Int? = nil) throws {
        let data: Data
        do { data = try encoder.encode(value) } catch { throw ProjectStoreError.encoding(error.localizedDescription) }
        var columns = ["id", "data"]
        var values = [id.uuidString, data.base64EncodedString()]
        if let projectID { columns.insert("project_id", at: 1); values.insert(projectID.uuidString, at: 1) }
        if let conversationID { columns.insert("conversation_id", at: columns.count - 1); values.insert(conversationID.uuidString, at: values.count - 1) }
        if let revision { columns.insert("revision", at: columns.count - 1); values.insert(String(revision), at: values.count - 1) }
        let placeholders = Array(repeating: "?", count: columns.count).joined(separator: ",")
        let assignments = columns.filter { $0 != "id" }.map { "\($0)=excluded.\($0)" }.joined(separator: ",")
        try execute("INSERT INTO \(table)(\(columns.joined(separator: ","))) VALUES(\(placeholders)) ON CONFLICT(id) DO UPDATE SET \(assignments)", bind: values)
    }

    func fetchAll<T: Decodable>(_ sql: String, bind: [String] = [], as type: T.Type) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw databaseError() }
        defer { sqlite3_finalize(statement) }
        try bindValues(bind, to: statement)
        var result: [T] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            guard let bytes = sqlite3_column_text(statement, 0), let data = Data(base64Encoded: String(cString: bytes)) else { throw ProjectStoreError.encoding("Invalid stored JSON") }
            do { result.append(try decoder.decode(T.self, from: data)) } catch { throw ProjectStoreError.encoding(error.localizedDescription) }
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw databaseError() }
        return result
    }

    func fetchOne<T: Decodable>(_ sql: String, bind: [String], as type: T.Type) throws -> T? {
        try fetchAll(sql, bind: bind, as: type).first
    }

    func scalarText(_ sql: String, bind: [String]) throws -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw databaseError() }
        defer { sqlite3_finalize(statement) }
        try bindValues(bind, to: statement)
        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            guard let value = sqlite3_column_text(statement, 0) else { return nil }
            return String(cString: value)
        case SQLITE_DONE:
            return nil
        default:
            throw databaseError()
        }
    }

    private func execute(_ sql: String, bind: [String]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw databaseError() }
        defer { sqlite3_finalize(statement) }
        try bindValues(bind, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError() }
    }

    private func bindValues(_ values: [String], to statement: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in values.enumerated() {
            guard sqlite3_bind_text(statement, Int32(offset + 1), value, -1, transient) == SQLITE_OK else { throw databaseError() }
        }
    }

    private func databaseError() -> ProjectStoreError { .database(String(cString: sqlite3_errmsg(database))) }
}
