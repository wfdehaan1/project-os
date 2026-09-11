import Foundation

struct ProjectDeletionFence: Hashable, Sendable {
    let projectID: UUID
    let token: UUID
}

enum ProjectDeletionExportDecision: Equatable, Sendable {
    /// A receipt proves ProjectArchiveService completed and verified the export.
    case exported(ProjectArchiveReceipt)
    case declined
}

struct ProjectDeletionRequest: Equatable, Sendable {
    let projectID: UUID
    let projectName: String
    let typedConfirmation: String
    let exportOfferWasPresented: Bool
    let exportDecision: ProjectDeletionExportDecision

    var requiredConfirmation: String { "DELETE \(projectName)" }
}

struct ProjectDeletionReceipt: Equatable, Sendable {
    let deletedProjectID: UUID
    let exportURL: URL?
    let localNotice: String
    let externalNotice: String
}

/// The fence is the store-level race barrier for deletion. While it exists, every
/// mutation path, including AI job completion, must reject writes for this project.
protocol ProjectDeletionStore: Sendable {
    /// Verifies the current name, creates a durable write fence, and returns it.
    /// This operation must not remove project content.
    func beginDeletion(of projectID: UUID, expectedName: String) async throws -> ProjectDeletionFence

    /// Removes all app-managed rows/content in one transaction. The implementation
    /// must retain enough tombstone/generation state to reject already-issued jobs.
    func deleteProjectAtomically(using fence: ProjectDeletionFence) async throws

    /// Removes the fence after a failed attempt so the otherwise intact project is usable.
    func abandonDeletion(using fence: ProjectDeletionFence) async
}

protocol ProjectDeletionJobCancelling: Sendable {
    /// Cancels every known job and permanently rejects their late events/completions.
    /// Cancellation does not imply that an external provider stopped work or billing.
    func cancelJobsForDeletion(projectID: UUID) async throws
}

enum ProjectDeletionError: LocalizedError, Equatable {
    case exportWasNotOffered
    case confirmationMismatch(required: String)
    case deletionAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .exportWasNotOffered:
            "Offer a verified project export before permanent deletion. The user may explicitly decline it."
        case .confirmationMismatch(let required):
            "Permanent deletion was not confirmed. Type exactly: \(required)"
        case .deletionAlreadyInProgress:
            "Deletion is already in progress for this project."
        }
    }
}

actor ProjectDeletionCoordinator {
    private var projectsBeingDeleted = Set<UUID>()

    func deleteProject(
        _ request: ProjectDeletionRequest,
        store: any ProjectDeletionStore,
        jobs: any ProjectDeletionJobCancelling
    ) async throws -> ProjectDeletionReceipt {
        guard request.exportOfferWasPresented else { throw ProjectDeletionError.exportWasNotOffered }
        guard request.typedConfirmation == request.requiredConfirmation else {
            throw ProjectDeletionError.confirmationMismatch(required: request.requiredConfirmation)
        }
        guard projectsBeingDeleted.insert(request.projectID).inserted else {
            throw ProjectDeletionError.deletionAlreadyInProgress
        }
        defer { projectsBeingDeleted.remove(request.projectID) }

        let fence = try await store.beginDeletion(of: request.projectID, expectedName: request.projectName)
        do {
            try await jobs.cancelJobsForDeletion(projectID: request.projectID)
            try await store.deleteProjectAtomically(using: fence)
        } catch {
            await store.abandonDeletion(using: fence)
            throw error
        }

        let exportURL: URL?
        switch request.exportDecision {
        case .exported(let receipt): exportURL = receipt.archiveURL
        case .declined: exportURL = nil
        }
        return ProjectDeletionReceipt(
            deletedProjectID: request.projectID,
            exportURL: exportURL,
            localNotice: "ProjectOS removed the project's app-managed content. Separately saved exports, system backups, and shared local models remain.",
            externalNotice: "Project deletion does not delete data independently retained by OpenRouter or another external provider, and it is not secure forensic erasure."
        )
    }
}
