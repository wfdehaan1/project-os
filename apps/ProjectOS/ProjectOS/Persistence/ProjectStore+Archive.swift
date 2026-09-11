import Foundation

extension ProjectStore: ProjectArchiveSource {
    func archiveSnapshot(for projectID: UUID) async throws -> ProjectArchiveSnapshot {
        let snapshotRows = try queue.sync {
            guard let project = try fetchOne("SELECT data FROM projects WHERE id = ?", bind: [projectID.uuidString], as: ProjectRecord.self) else { throw ProjectStoreError.notFound("Project") }
            let sources = try fetchAll("SELECT data FROM sources WHERE project_id = ?", bind: [projectID.uuidString], as: SourceRecord.self).sorted { $0.createdAt < $1.createdAt }
            let conversations = try fetchAll("SELECT data FROM conversations WHERE project_id = ?", bind: [projectID.uuidString], as: ConversationRecord.self).sorted { $0.updatedAt > $1.updatedAt }
            let messages = try fetchAll("SELECT data FROM messages WHERE project_id = ?", bind: [projectID.uuidString], as: MessageRecord.self).sorted { $0.createdAt < $1.createdAt }
            let artifacts = try fetchAll("SELECT data FROM artifacts WHERE project_id = ?", bind: [projectID.uuidString], as: ArtifactRecord.self).sorted { $0.updatedAt > $1.updatedAt }
            let proposals = try fetchAll("SELECT data FROM proposals WHERE project_id = ?", bind: [projectID.uuidString], as: ProposalRecord.self).sorted { $0.createdAt > $1.createdAt }
            let changes = try fetchAll("SELECT data FROM changes WHERE project_id = ? ORDER BY revision DESC", bind: [projectID.uuidString], as: ChangeRecord.self)
            let outcomes = try fetchAll("SELECT data FROM outcomes WHERE project_id = ?", bind: [projectID.uuidString], as: ReturnRecord.self)
            let recommendation = try fetchAll("SELECT data FROM recommendations WHERE project_id = ?", bind: [projectID.uuidString], as: RecommendationRecord.self).sorted { $0.createdAt > $1.createdAt }.first
            let jobs = try fetchAll("SELECT data FROM jobs WHERE project_id = ?", bind: [projectID.uuidString], as: InferenceJobRecord.self)
            var drafts: [UUID: String] = [:]
            for conversation in conversations {
                drafts[conversation.id] = try scalarText("SELECT text FROM conversation_drafts WHERE project_id = ? AND conversation_id = ?", bind: [projectID.uuidString, conversation.id.uuidString]) ?? ""
            }
            return (project, sources, conversations, messages, artifacts, proposals, changes, outcomes, recommendation, jobs, drafts)
        }
        let (project, sourceRecords, conversationRecords, messageRecords, artifactRecords, proposalRecords, changeRecords, outcomeRecords, recommendationRecord, jobRecords, savedDrafts) = snapshotRows
        var records: [ArchivedRecord] = []
        let now = Date()

        for conversation in conversationRecords {
            records.append(.init(id: conversation.id, projectID: projectID, kind: .conversation, version: 1, state: "owned", createdAt: conversation.createdAt, updatedAt: conversation.updatedAt, parentID: nil, references: [], fields: ["title": .string(conversation.title)], importMetadata: nil))
        }
        records += sourceRecords.map { source in
            .init(id: source.id, projectID: projectID, kind: .source, version: source.version, state: "current", createdAt: source.createdAt, updatedAt: source.createdAt, parentID: nil, references: [], fields: ["label": .string(source.label), "text": .string(source.text)], importMetadata: nil)
        }
        records += messageRecords.map { message in
            .init(id: message.id, projectID: projectID, kind: .message, version: 1, state: message.completion.rawValue, createdAt: message.createdAt, updatedAt: message.createdAt, parentID: message.conversationID, references: [.init(role: "conversation", targetID: message.conversationID)], fields: ["role": .string(message.role.rawValue), "text": .string(message.text)], importMetadata: nil)
        }
        records += artifactRecords.map { artifact in
            .init(id: artifact.id, projectID: projectID, kind: .artifact, version: artifact.version, state: artifact.state.rawValue, createdAt: artifact.updatedAt, updatedAt: artifact.updatedAt, parentID: nil, references: artifact.evidence.enumerated().map { .init(role: "evidence.\($0.offset)", targetID: $0.element.sourceID) } + artifact.relationships.enumerated().compactMap { index, relation in relation.targetArtifactID.map { .init(role: "relation.\(index)", targetID: $0) } }, fields: [
                "kind": .string(artifact.kind.rawValue), "title": .string(artifact.title), "content": .string(artifact.content),
                "rationale": artifact.rationale.map(ArchiveValue.string) ?? .null,
                "decisionSubject": artifact.decisionSubject.map(ArchiveValue.string) ?? .null,
                "certainty": artifact.certainty.map(ArchiveValue.string) ?? .null,
                "limitations": artifact.limitations.map(ArchiveValue.string) ?? .null,
                "evidence": .array(artifact.evidence.map { .object(["id": .string($0.id.uuidString), "sourceType": .string($0.sourceType), "version": .integer($0.version), "quote": .string($0.quote), "aiAuthored": .boolean($0.aiAuthored)]) }),
                "relationships": .array(artifact.relationships.map { .object(["id": .string($0.id.uuidString), "type": .string($0.type)]) })
            ], importMetadata: nil)
        }
        records += proposalRecords.map { proposal in
            let evidenceReferences = proposal.evidence.enumerated().map { ArchivedReference(role: "evidence.\($0.offset)", targetID: $0.element.sourceID) }
            let relationshipReferences = proposal.relationships.enumerated().compactMap { index, relation -> ArchivedReference? in
                guard let target = relation.targetArtifactID ?? relation.targetProposalID else { return nil }
                return ArchivedReference(role: "relation.\(index)", targetID: target)
            }
            let dependencyReferences = proposal.dependencyIDs.enumerated().map { ArchivedReference(role: "dependency.\($0.offset)", targetID: $0.element) }
            let targetReferences = proposal.targetID.map { [ArchivedReference(role: "target", targetID: $0)] } ?? []
            let acceptedArtifactReferences = proposal.acceptedArtifactID.map { [ArchivedReference(role: "acceptedArtifact", targetID: $0)] } ?? []
            let references = evidenceReferences + relationshipReferences + dependencyReferences + targetReferences + acceptedArtifactReferences
            let fields: [String: ArchiveValue] = [
                "originatingRevision": .integer(proposal.originatingRevision), "operation": .string(proposal.operation.rawValue), "expectedTargetRevision": proposal.expectedTargetRevision.map(ArchiveValue.integer) ?? .null, "kind": .string(proposal.kind.rawValue), "title": .string(proposal.title), "content": .string(proposal.content),
                "rationale": proposal.rationale.map(ArchiveValue.string) ?? .null, "decisionSubject": proposal.decisionSubject.map(ArchiveValue.string) ?? .null,
                "proposedState": proposal.proposedState.map { .string($0.rawValue) } ?? .null,
                "certainty": proposal.certainty.map(ArchiveValue.string) ?? .null,
                "limitations": proposal.limitations.map(ArchiveValue.string) ?? .null,
                "acceptedTitle": proposal.acceptedTitle.map(ArchiveValue.string) ?? .null,
                "acceptedContent": proposal.acceptedContent.map(ArchiveValue.string) ?? .null,
                "evidence": .array(proposal.evidence.map { .object(["id": .string($0.id.uuidString), "sourceType": .string($0.sourceType), "version": .integer($0.version), "quote": .string($0.quote), "aiAuthored": .boolean($0.aiAuthored)]) }),
                "relationships": .array(proposal.relationships.map { .object(["id": .string($0.id.uuidString), "type": .string($0.type), "targetsProposal": .boolean($0.targetProposalID != nil)]) })
            ]
            return ArchivedRecord(id: proposal.id, projectID: projectID, kind: .proposal, version: 1, state: proposal.lifecycle.rawValue, createdAt: proposal.createdAt, updatedAt: proposal.createdAt, parentID: nil, references: references, fields: fields, importMetadata: nil)
        }
        let archiveEncoder = JSONEncoder()
        archiveEncoder.dateEncodingStrategy = .iso8601
        records += try changeRecords.map { change in
            let before = try change.beforeArtifact.map { try archiveEncoder.encode($0).base64EncodedString() }
            let after = try change.afterArtifact.map { try archiveEncoder.encode($0).base64EncodedString() }
            let proposalReference = change.originatingProposalID.map { [ArchivedReference(role: "originatingProposal", targetID: $0)] } ?? []
            return .init(id: change.id, projectID: projectID, kind: .acceptedChange, version: change.revision, state: change.undone ? "undone" : "accepted", createdAt: change.createdAt, updatedAt: change.createdAt, parentID: nil, references: proposalReference, fields: ["transactionID": .string(change.transactionID.uuidString), "summary": .string(change.summary), "actor": change.actor.map(ArchiveValue.string) ?? .null, "beforePayload": before.map(ArchiveValue.string) ?? .null, "afterPayload": after.map(ArchiveValue.string) ?? .null], importMetadata: nil)
        }
        records += outcomeRecords.map { outcome in
            .init(id: outcome.id, projectID: projectID, kind: .returnRecord, version: 1, state: outcome.projectOutcome, createdAt: outcome.createdAt, updatedAt: outcome.createdAt, parentID: nil, references: [], fields: ["durationMinutes": .integer(outcome.durationMinutes), "understanding": .integer(outcome.understanding), "trust": .integer(outcome.trust), "usefulness": .integer(outcome.usefulness), "resumedWithinFiveMinutes": .boolean(outcome.resumedWithinFiveMinutes), "actionOutcome": .string(outcome.actionOutcome), "reviewMinutes": .integer(outcome.reviewMinutes), "notes": .string(outcome.notes)], importMetadata: nil)
        }
        if let recommendationRecord {
            records.append(.init(id: recommendationRecord.id, projectID: projectID, kind: .recommendation, version: 1, state: recommendationRecord.isDismissed ? "dismissed" : "current", createdAt: recommendationRecord.createdAt, updatedAt: recommendationRecord.createdAt, parentID: nil, references: recommendationRecord.supportingRecords.enumerated().map { .init(role: "support.\($0.offset)", targetID: $0.element.id) }, fields: ["text": .string(recommendationRecord.text), "uncertainty": recommendationRecord.uncertainty.map(ArchiveValue.string) ?? .null, "originatingRevision": .integer(recommendationRecord.originatingRevision), "supportVersions": .array(recommendationRecord.supportingRecords.map { .integer($0.version) })], importMetadata: nil))
        }
        for job in jobRecords {
            let selections = job.sourceIDs.enumerated().map { ArchivedReference(role: "source.\($0.offset)", targetID: $0.element) }
                + job.artifactIDs.enumerated().map { ArchivedReference(role: "artifact.\($0.offset)", targetID: $0.element) }
                + job.messageIDs.enumerated().map { ArchivedReference(role: "message.\($0.offset)", targetID: $0.element) }
            records.append(.init(id: job.contextID, projectID: projectID, kind: .context, version: 1, state: "frozen", createdAt: job.createdAt, updatedAt: job.createdAt, parentID: nil, references: selections, fields: ["sourceRevision": .integer(job.sourceRevision), "provider": .string(job.provider), "model": .string(job.model), "configuredUpstreamRoute": job.configuredUpstreamRoute.map(ArchiveValue.string) ?? .null, "purpose": .string(job.purpose)], importMetadata: nil))
            records.append(.init(id: job.id, projectID: projectID, kind: .job, version: 1, state: job.status.rawValue, createdAt: job.createdAt, updatedAt: job.createdAt, parentID: job.contextID, references: [.init(role: "context", targetID: job.contextID)], fields: ["inputTokens": job.inputTokens.map(ArchiveValue.integer) ?? .null, "outputTokens": job.outputTokens.map(ArchiveValue.integer) ?? .null, "cost": job.cost.map { .string(NSDecimalNumber(decimal: $0).stringValue) } ?? .null, "currency": job.currency.map(ArchiveValue.string) ?? .null, "actualModel": job.actualModel.map(ArchiveValue.string) ?? .null, "actualUpstreamProvider": job.actualUpstreamProvider.map(ArchiveValue.string) ?? .null], importMetadata: nil))
        }
        for conversation in conversationRecords {
            records.append(.init(id: UUID(), projectID: projectID, kind: .draft, version: 1, state: "saved", createdAt: now, updatedAt: now, parentID: conversation.id, references: [.init(role: "conversation", targetID: conversation.id)], fields: ["text": .string(savedDrafts[conversation.id] ?? "")], importMetadata: nil))
        }

        return ProjectArchiveSnapshot(project: .init(id: project.id, name: project.name, description: project.summary, createdAt: project.createdAt, updatedAt: project.updatedAt, acceptedStateRevision: project.revision, previousVisitRevision: project.previousVisitRevision, originalProjectID: nil), records: records)
    }
}

extension ProjectStore: ProjectArchiveRestoreStore {
    func restoreProjectAtomically(from snapshot: ProjectArchiveSnapshot) async throws {
        try restoreArchiveSnapshot(snapshot)
    }
}

extension ProjectStore: ProjectDeletionStore {
    func beginDeletion(of projectID: UUID, expectedName: String) async throws -> ProjectDeletionFence {
        guard let project = try projects().first(where: { $0.id == projectID && $0.name == expectedName }) else {
            throw ProjectStoreError.notFound("Project")
        }
        let fence = ProjectDeletionFence(projectID: project.id, token: UUID())
        try createDeletionFence(fence)
        return fence
    }

    func deleteProjectAtomically(using fence: ProjectDeletionFence) async throws {
        try finishDeletion(fence)
    }

    func abandonDeletion(using fence: ProjectDeletionFence) async {
        try? removeDeletionFence(fence)
    }
}

extension ArchiveValue {
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
    var intValue: Int? { if case .integer(let value) = self { value } else { nil } }
    var boolValue: Bool? { if case .boolean(let value) = self { value } else { nil } }
    var arrayValue: [ArchiveValue]? { if case .array(let value) = self { value } else { nil } }
    var objectValue: [String: ArchiveValue]? { if case .object(let value) = self { value } else { nil } }
}
