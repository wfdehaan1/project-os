import Foundation

public enum CoordinatedJobStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled
    case interrupted
}

public struct CoordinatedJobRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let attemptID: UUID
    public let projectID: UUID
    public let sourceRevision: Int64
    public let purpose: AIJobPurpose
    public let providerID: ProviderID
    public let modelID: String
    public let configurationID: UUID
    public var status: CoordinatedJobStatus
    public var usage: AIUsage?
    public let createdAt: Date
    public var finishedAt: Date?
}

public struct AIJobHandle: Sendable {
    public let jobID: UUID
    public let attemptID: UUID
    public let projectID: UUID
    public let sourceRevision: Int64
    public let events: AsyncThrowingStream<AIStreamEvent, Error>
}

public enum JobCoordinatorError: Error, Equatable, Sendable {
    case projectAlreadyHasActiveJob
    case projectWasDeleted
}

private struct ActiveJob {
    let recordID: UUID
    let attemptID: UUID
    let task: Task<Void, Never>
    let continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
}

/// Enforces one frozen inference request per project and drops late events after cancellation/deletion.
public actor JobCoordinator {
    private let registry: ProviderRegistry
    private var activeByProject: [UUID: ActiveJob] = [:]
    private var recordsByJob: [UUID: CoordinatedJobRecord] = [:]
    private var deletedProjects: Set<UUID> = []

    public init(registry: ProviderRegistry) {
        self.registry = registry
    }

    public func start(_ request: AIRequest) async throws -> AIJobHandle {
        guard !deletedProjects.contains(request.projectID) else { throw JobCoordinatorError.projectWasDeleted }
        guard activeByProject[request.projectID] == nil else { throw JobCoordinatorError.projectAlreadyHasActiveJob }
        // Resolve and retain the immutable adapter now; later registry/settings changes cannot affect this attempt.
        let provider = try await registry.provider(for: request.providerID)

        let attemptID = UUID()
        let pair = AsyncThrowingStream<AIStreamEvent, Error>.makeStream()
        var record = CoordinatedJobRecord(
            id: request.id,
            attemptID: attemptID,
            projectID: request.projectID,
            sourceRevision: request.projectRevision,
            purpose: request.purpose,
            providerID: request.providerID,
            modelID: request.modelID,
            configurationID: request.configurationID,
            status: .queued,
            usage: nil,
            createdAt: Date(),
            finishedAt: nil
        )
        recordsByJob[request.id] = record
        let task = Task { [weak self] in
            guard let self else { return }
            await self.run(request: request, attemptID: attemptID, provider: provider)
        }
        activeByProject[request.projectID] = ActiveJob(
            recordID: request.id,
            attemptID: attemptID,
            task: task,
            continuation: pair.continuation
        )
        record.status = .running
        recordsByJob[request.id] = record
        pair.continuation.onTermination = { @Sendable [weak self] _ in
            Task { await self?.cancel(projectID: request.projectID, jobID: request.id) }
        }
        return AIJobHandle(
            jobID: request.id,
            attemptID: attemptID,
            projectID: request.projectID,
            sourceRevision: request.projectRevision,
            events: pair.stream
        )
    }

    public func cancel(projectID: UUID, jobID: UUID) {
        guard let active = activeByProject[projectID], active.recordID == jobID else { return }
        activeByProject[projectID] = nil
        active.task.cancel()
        active.continuation.finish(throwing: AIProviderError.cancelled)
        finishRecord(jobID: jobID, status: .cancelled)
    }

    public func cancelAll(for projectID: UUID) {
        guard let active = activeByProject[projectID] else { return }
        cancel(projectID: projectID, jobID: active.recordID)
    }

    /// Call before deleting project rows. The tombstone prevents late completions and ID reuse.
    public func markProjectDeleted(_ projectID: UUID) {
        deletedProjects.insert(projectID)
        cancelAll(for: projectID)
    }

    public func activeJob(for projectID: UUID) -> CoordinatedJobRecord? {
        guard let jobID = activeByProject[projectID]?.recordID else { return nil }
        return recordsByJob[jobID]
    }

    public func record(for jobID: UUID) -> CoordinatedJobRecord? { recordsByJob[jobID] }

    /// Restores persisted job metadata after launch without replaying any request.
    public func recoverAsInterrupted(_ unfinished: [CoordinatedJobRecord]) {
        for var record in unfinished where record.status == .queued || record.status == .running {
            record.status = .interrupted
            record.finishedAt = Date()
            recordsByJob[record.id] = record
        }
    }

    private func run(request: AIRequest, attemptID: UUID, provider: any AIProvider) async {
        do {
            let source = try await provider.events(for: request)
            for try await event in source {
                try Task.checkCancellation()
                guard isCurrent(projectID: request.projectID, jobID: request.id, attemptID: attemptID) else { return }
                if case .usage(let usage) = event, var record = recordsByJob[request.id] {
                    record.usage = usage
                    recordsByJob[request.id] = record
                }
                activeByProject[request.projectID]?.continuation.yield(event)
            }
            guard isCurrent(projectID: request.projectID, jobID: request.id, attemptID: attemptID) else { return }
            activeByProject[request.projectID]?.continuation.finish()
            activeByProject[request.projectID] = nil
            finishRecord(jobID: request.id, status: .completed)
        } catch is CancellationError {
            cancel(projectID: request.projectID, jobID: request.id)
        } catch {
            guard isCurrent(projectID: request.projectID, jobID: request.id, attemptID: attemptID) else { return }
            activeByProject[request.projectID]?.continuation.finish(throwing: error)
            activeByProject[request.projectID] = nil
            finishRecord(jobID: request.id, status: error as? AIProviderError == .cancelled ? .cancelled : .failed)
        }
    }

    private func isCurrent(projectID: UUID, jobID: UUID, attemptID: UUID) -> Bool {
        guard !deletedProjects.contains(projectID), let active = activeByProject[projectID] else { return false }
        return active.recordID == jobID && active.attemptID == attemptID
    }

    private func finishRecord(jobID: UUID, status: CoordinatedJobStatus) {
        guard var record = recordsByJob[jobID] else { return }
        record.status = status
        record.finishedAt = Date()
        recordsByJob[jobID] = record
    }
}
