import CryptoKit
import Foundation

/// Portable, credential-free representation of one complete project graph.
///
/// Store implementations translate their records to this DTO instead of exporting a
/// SQLite file. References are explicit so restore can validate and remap the graph.
struct ProjectArchiveSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var project: ArchivedProject
    var records: [ArchivedRecord]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        exportedAt: Date = Date(),
        project: ArchivedProject,
        records: [ArchivedRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.project = project
        self.records = records
    }
}

struct ArchivedProject: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var acceptedStateRevision: Int
    var previousVisitRevision: Int
    var originalProjectID: UUID?
}

enum ArchivedRecordKind: String, Codable, CaseIterable, Sendable {
    case source
    case conversation
    case message
    case artifact
    case proposal
    case acceptedChange
    case relation
    case context
    case job
    case recommendation
    case returnRecord
    case draft
}

struct ArchivedRecord: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var projectID: UUID
    var kind: ArchivedRecordKind
    var version: Int
    var state: String
    var createdAt: Date
    var updatedAt: Date
    var parentID: UUID?
    var references: [ArchivedReference]
    var fields: [String: ArchiveValue]
    var importMetadata: ArchiveImportMetadata?
}

struct ArchivedReference: Codable, Equatable, Hashable, Sendable {
    /// Semantic role such as `evidenceSource`, `supports`, `supersedes`, or `previousVersion`.
    var role: String
    var targetID: UUID
}

struct ArchiveImportMetadata: Codable, Equatable, Sendable {
    var originalProjectID: UUID
    var originalRecordID: UUID
}

/// JSON-compatible values keep the archive readable without binding it to SQLite rows.
indirect enum ArchiveValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case decimal(Double)
    case boolean(Bool)
    case array([ArchiveValue])
    case object([String: ArchiveValue])
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .boolean(value) }
        else if let value = try? container.decode(Int.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .decimal(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([ArchiveValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: ArchiveValue].self)) }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .decimal(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct ProjectArchiveManifest: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var archiveSchemaVersion: Int
    var projectID: UUID
    var createdAt: Date
    var files: [ProjectArchiveManifestFile]
}

struct ProjectArchiveManifestFile: Codable, Equatable, Sendable {
    var path: String
    var byteCount: Int
    var sha256: String
}

struct ValidatedProjectArchive: Sendable {
    let sourceURL: URL
    let manifest: ProjectArchiveManifest
    let snapshot: ProjectArchiveSnapshot
}

struct ProjectArchiveReceipt: Equatable, Sendable {
    let archiveURL: URL
    let projectID: UUID
    let revision: Int
    let manifestSHA256: String
}

struct ProjectRestoreReceipt: Equatable, Sendable {
    let sourceArchiveURL: URL
    let originalProjectID: UUID
    let restoredProjectID: UUID
    let restoredRecordCount: Int
}

protocol ProjectArchiveSource: Sendable {
    /// Must include sources, transcript completion state, artifacts and their versions,
    /// relations, proposal/review history, contexts/jobs, recommendations, and outcomes.
    /// Credentials and runtime caches must never be represented.
    func archiveSnapshot(for projectID: UUID) async throws -> ProjectArchiveSnapshot
}

protocol ProjectArchiveRestoreStore: Sendable {
    /// Inserts the complete remapped graph in one transaction. On failure, no project,
    /// records, relationships, or import metadata may remain in the destination store.
    func restoreProjectAtomically(from snapshot: ProjectArchiveSnapshot) async throws
}

enum ProjectArchiveError: LocalizedError, Equatable {
    case destinationAlreadyExists
    case invalidArchiveDirectory
    case unsupportedManifestVersion(Int)
    case unsupportedSchemaVersion(Int)
    case missingManifestEntry(String)
    case unsafeManifestPath(String)
    case checksumMismatch(String)
    case byteCountMismatch(String)
    case invalidProjectIdentity
    case duplicateRecordID(UUID)
    case invalidRecordProject(UUID)
    case invalidRecordVersion(UUID)
    case missingReference(source: UUID, target: UUID)
    case sensitiveField(String)
    case encoding(String)
    case filesystem(String)

    var errorDescription: String? {
        switch self {
        case .destinationAlreadyExists:
            "An item already exists at the export destination. Choose a new folder; ProjectOS never overwrites an export."
        case .invalidArchiveDirectory:
            "This folder is not a regular ProjectOS archive. The existing project was not changed."
        case .unsupportedManifestVersion(let version):
            "Archive manifest version \(version) is not supported. The existing project was not changed."
        case .unsupportedSchemaVersion(let version):
            "Project archive schema version \(version) is not supported. The existing project was not changed."
        case .missingManifestEntry(let path):
            "The archive is missing its checksummed \(path) entry. The existing project was not changed."
        case .unsafeManifestPath(let path):
            "The archive contains an unsafe file path (\(path)). The existing project was not changed."
        case .checksumMismatch(let path):
            "The checksum for \(path) does not match. The archive may be corrupt or altered."
        case .byteCountMismatch(let path):
            "The recorded size for \(path) does not match. The archive may be incomplete."
        case .invalidProjectIdentity:
            "The archive project identity is inconsistent. Nothing was restored."
        case .duplicateRecordID(let id):
            "The archive contains duplicate record ID \(id). Nothing was restored."
        case .invalidRecordProject(let id):
            "Record \(id) belongs to a different project. Nothing was restored."
        case .invalidRecordVersion(let id):
            "Record \(id) has an invalid version. Nothing was restored."
        case .missingReference(let source, let target):
            "Record \(source) references missing record \(target). Nothing was restored."
        case .sensitiveField(let key):
            "The export was blocked because credential-like field '\(key)' was present. Remove secrets from the archive source."
        case .encoding(let detail):
            "The project archive could not be encoded or decoded: \(detail)"
        case .filesystem(let detail):
            "The archive operation failed before completion: \(detail)"
        }
    }
}

actor ProjectArchiveService {
    private static let readmeName = "README.md"
    private static let projectMarkdownName = "project.md"
    private static let projectJSONName = "project.json"
    private static let manifestName = "manifest.json"
    private static let payloadNames = [readmeName, projectMarkdownName, projectJSONName]

    func exportProject(
        id projectID: UUID,
        from source: any ProjectArchiveSource,
        to destinationURL: URL
    ) async throws -> ProjectArchiveReceipt {
        let snapshot = try await source.archiveSnapshot(for: projectID)
        guard snapshot.project.id == projectID else { throw ProjectArchiveError.invalidProjectIdentity }
        try Self.validate(snapshot)

        let manager = FileManager.default
        guard !manager.fileExists(atPath: destinationURL.path) else {
            throw ProjectArchiveError.destinationAlreadyExists
        }
        let parent = destinationURL.deletingLastPathComponent()
        let stagingURL = parent.appending(
            path: ".projectos-export-\(UUID().uuidString).staging",
            directoryHint: .isDirectory
        )
        var createdStagingDirectory = false

        do {
            try manager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            createdStagingDirectory = true
            let encoder = Self.archiveEncoder()
            let jsonData = try encoder.encode(snapshot)
            let readmeData = Data(Self.readme(for: snapshot).utf8)
            let markdownData = Data(Self.projectMarkdown(for: snapshot).utf8)
            let payloads = [
                Self.readmeName: readmeData,
                Self.projectMarkdownName: markdownData,
                Self.projectJSONName: jsonData
            ]

            for name in Self.payloadNames {
                guard let data = payloads[name] else { throw ProjectArchiveError.missingManifestEntry(name) }
                try data.write(to: stagingURL.appending(path: name), options: [.atomic])
            }

            let manifest = ProjectArchiveManifest(
                formatVersion: ProjectArchiveManifest.currentFormatVersion,
                archiveSchemaVersion: snapshot.schemaVersion,
                projectID: snapshot.project.id,
                createdAt: snapshot.exportedAt,
                files: Self.payloadNames.map { name in
                    let data = payloads[name]!
                    return ProjectArchiveManifestFile(path: name, byteCount: data.count, sha256: Self.sha256(data))
                }
            )
            let manifestData = try encoder.encode(manifest)
            try manifestData.write(to: stagingURL.appending(path: Self.manifestName), options: [.atomic])

            _ = try Self.validateArchive(at: stagingURL)
            try manager.moveItem(at: stagingURL, to: destinationURL)
            return ProjectArchiveReceipt(
                archiveURL: destinationURL,
                projectID: projectID,
                revision: snapshot.project.acceptedStateRevision,
                manifestSHA256: Self.sha256(manifestData)
            )
        } catch {
            if createdStagingDirectory { try? manager.removeItem(at: stagingURL) }
            if let archiveError = error as? ProjectArchiveError { throw archiveError }
            throw ProjectArchiveError.filesystem(error.localizedDescription)
        }
    }

    func verifyArchive(at archiveURL: URL) throws -> ValidatedProjectArchive {
        try Self.validateArchive(at: archiveURL)
    }

    func restoreProject(
        from archiveURL: URL,
        into store: any ProjectArchiveRestoreStore,
        newProjectID: UUID = UUID()
    ) async throws -> ProjectRestoreReceipt {
        // All file, schema, graph, and secret checks happen before the store is called.
        let validated = try Self.validateArchive(at: archiveURL)
        let remapped = try Self.remapForRestore(validated.snapshot, newProjectID: newProjectID)
        try await store.restoreProjectAtomically(from: remapped)
        return ProjectRestoreReceipt(
            sourceArchiveURL: archiveURL,
            originalProjectID: validated.snapshot.project.id,
            restoredProjectID: newProjectID,
            restoredRecordCount: remapped.records.count
        )
    }

    private static func validateArchive(at archiveURL: URL) throws -> ValidatedProjectArchive {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: archiveURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ProjectArchiveError.invalidArchiveDirectory
        }
        let directoryValues = try archiveURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard directoryValues.isSymbolicLink != true else { throw ProjectArchiveError.invalidArchiveDirectory }

        let decoder = archiveDecoder()
        let manifestURL = archiveURL.appending(path: manifestName)
        let manifestData: Data
        do {
            let values = try manifestURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ProjectArchiveError.invalidArchiveDirectory
            }
            manifestData = try Data(contentsOf: manifestURL)
        }
        catch let archiveError as ProjectArchiveError { throw archiveError }
        catch { throw ProjectArchiveError.missingManifestEntry(manifestName) }

        let manifest: ProjectArchiveManifest
        do { manifest = try decoder.decode(ProjectArchiveManifest.self, from: manifestData) }
        catch { throw ProjectArchiveError.encoding(error.localizedDescription) }
        guard manifest.formatVersion == ProjectArchiveManifest.currentFormatVersion else {
            throw ProjectArchiveError.unsupportedManifestVersion(manifest.formatVersion)
        }
        guard manifest.archiveSchemaVersion == ProjectArchiveSnapshot.currentSchemaVersion else {
            throw ProjectArchiveError.unsupportedSchemaVersion(manifest.archiveSchemaVersion)
        }
        guard Set(manifest.files.map(\.path)) == Set(payloadNames), manifest.files.count == payloadNames.count else {
            let missing = payloadNames.first { required in !manifest.files.contains { $0.path == required } } ?? "payload file"
            throw ProjectArchiveError.missingManifestEntry(missing)
        }

        var payloads: [String: Data] = [:]
        for entry in manifest.files {
            guard payloadNames.contains(entry.path),
                  entry.path == URL(fileURLWithPath: entry.path).lastPathComponent,
                  !entry.path.contains("..") else {
                throw ProjectArchiveError.unsafeManifestPath(entry.path)
            }
            let fileURL = archiveURL.appending(path: entry.path)
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ProjectArchiveError.invalidArchiveDirectory
            }
            let data = try Data(contentsOf: fileURL)
            guard data.count == entry.byteCount else { throw ProjectArchiveError.byteCountMismatch(entry.path) }
            guard sha256(data) == entry.sha256.lowercased() else { throw ProjectArchiveError.checksumMismatch(entry.path) }
            payloads[entry.path] = data
        }

        guard let projectData = payloads[projectJSONName] else {
            throw ProjectArchiveError.missingManifestEntry(projectJSONName)
        }
        let snapshot: ProjectArchiveSnapshot
        do { snapshot = try decoder.decode(ProjectArchiveSnapshot.self, from: projectData) }
        catch { throw ProjectArchiveError.encoding(error.localizedDescription) }
        guard snapshot.schemaVersion == manifest.archiveSchemaVersion,
              snapshot.project.id == manifest.projectID else {
            throw ProjectArchiveError.invalidProjectIdentity
        }
        try validate(snapshot)
        return ValidatedProjectArchive(sourceURL: archiveURL, manifest: manifest, snapshot: snapshot)
    }

    private static func validate(_ snapshot: ProjectArchiveSnapshot) throws {
        guard snapshot.schemaVersion == ProjectArchiveSnapshot.currentSchemaVersion else {
            throw ProjectArchiveError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        guard snapshot.project.acceptedStateRevision >= 0,
              snapshot.project.previousVisitRevision >= 0,
              snapshot.project.previousVisitRevision <= snapshot.project.acceptedStateRevision else {
            throw ProjectArchiveError.invalidProjectIdentity
        }

        var ids = Set<UUID>()
        for record in snapshot.records {
            guard record.id != snapshot.project.id else { throw ProjectArchiveError.invalidProjectIdentity }
            guard ids.insert(record.id).inserted else { throw ProjectArchiveError.duplicateRecordID(record.id) }
            guard record.projectID == snapshot.project.id else { throw ProjectArchiveError.invalidRecordProject(record.id) }
            guard record.version > 0 else { throw ProjectArchiveError.invalidRecordVersion(record.id) }
            try rejectSensitiveKeys(in: record.fields)
        }
        for record in snapshot.records {
            if let parentID = record.parentID, !ids.contains(parentID) {
                throw ProjectArchiveError.missingReference(source: record.id, target: parentID)
            }
            for reference in record.references where !ids.contains(reference.targetID) {
                throw ProjectArchiveError.missingReference(source: record.id, target: reference.targetID)
            }
        }
    }

    private static func rejectSensitiveKeys(in fields: [String: ArchiveValue]) throws {
        let forbiddenSuffixes = [
            "authorization", "apikey", "credential", "password", "token",
            "secret", "privatekey"
        ]
        for (key, value) in fields {
            let normalized = key.lowercased().filter(\.isLetter)
            if forbiddenSuffixes.contains(where: normalized.hasSuffix) {
                throw ProjectArchiveError.sensitiveField(key)
            }
            try rejectSensitiveKeys(in: value)
        }
    }

    private static func rejectSensitiveKeys(in value: ArchiveValue) throws {
        switch value {
        case .object(let object):
            try rejectSensitiveKeys(in: object)
        case .array(let values):
            for value in values { try rejectSensitiveKeys(in: value) }
        default:
            break
        }
    }

    private static func remapForRestore(
        _ snapshot: ProjectArchiveSnapshot,
        newProjectID: UUID
    ) throws -> ProjectArchiveSnapshot {
        guard newProjectID != snapshot.project.id else { throw ProjectArchiveError.invalidProjectIdentity }
        let recordMap = Dictionary(uniqueKeysWithValues: snapshot.records.map { ($0.id, UUID()) })
        let originalProjectID = snapshot.project.originalProjectID ?? snapshot.project.id
        var project = snapshot.project
        project.id = newProjectID
        project.originalProjectID = originalProjectID
        project.createdAt = Date()
        project.updatedAt = project.createdAt

        let records = try snapshot.records.map { original -> ArchivedRecord in
            guard let newID = recordMap[original.id] else { throw ProjectArchiveError.invalidProjectIdentity }
            var copy = original
            copy.id = newID
            copy.projectID = newProjectID
            copy.parentID = try original.parentID.map { oldID in
                guard let remapped = recordMap[oldID] else {
                    throw ProjectArchiveError.missingReference(source: original.id, target: oldID)
                }
                return remapped
            }
            copy.references = try original.references.map { reference in
                guard let remapped = recordMap[reference.targetID] else {
                    throw ProjectArchiveError.missingReference(source: original.id, target: reference.targetID)
                }
                return ArchivedReference(role: reference.role, targetID: remapped)
            }
            copy.importMetadata = ArchiveImportMetadata(
                originalProjectID: original.importMetadata?.originalProjectID ?? originalProjectID,
                originalRecordID: original.importMetadata?.originalRecordID ?? original.id
            )
            return copy
        }
        let restored = ProjectArchiveSnapshot(project: project, records: records)
        try validate(restored)
        return restored
    }

    private static func archiveEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func archiveDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func readme(for snapshot: ProjectArchiveSnapshot) -> String {
        """
        # ProjectOS export

        This directory is a complete, human-readable ProjectOS project export.

        - `project.md` is a readable inventory of the project and its records.
        - `project.json` is the versioned restore payload.
        - `manifest.json` records the schema and SHA-256 checksum of every payload file.

        Import ProjectOS exports through Project Settings. ProjectOS verifies every checksum,
        the supported schema, and all record references before creating a separate project copy.
        Existing projects are never overwritten. Credentials, Keychain items, runtime caches,
        external-provider data, system backups, and separately saved exports are not included.

        Project: \(snapshot.project.name)
        Project ID at export: \(snapshot.project.id.uuidString)
        Accepted-state revision: \(snapshot.project.acceptedStateRevision)
        """
    }

    private static func projectMarkdown(for snapshot: ProjectArchiveSnapshot) -> String {
        var lines = [
            "# \(markdownEscaped(snapshot.project.name))",
            "",
            snapshot.project.description,
            "",
            "- Project ID: `\(snapshot.project.id.uuidString)`",
            "- Accepted-state revision: \(snapshot.project.acceptedStateRevision)",
            "- Exported records: \(snapshot.records.count)",
            ""
        ]
        for record in snapshot.records.sorted(by: recordOrdering) {
            lines.append("## \(record.kind.rawValue): \(record.id.uuidString)")
            lines.append("")
            lines.append("- State: \(markdownEscaped(record.state))")
            lines.append("- Version: \(record.version)")
            if let parentID = record.parentID { lines.append("- Parent: `\(parentID.uuidString)`") }
            for reference in record.references.sorted(by: { ($0.role, $0.targetID.uuidString) < ($1.role, $1.targetID.uuidString) }) {
                lines.append("- \(markdownEscaped(reference.role)): `\(reference.targetID.uuidString)`")
            }
            if !record.fields.isEmpty {
                lines.append("")
                lines.append("```json")
                if let data = try? archiveEncoder().encode(record.fields),
                   let text = String(data: data, encoding: .utf8) {
                    lines.append(text)
                }
                lines.append("```")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func recordOrdering(_ lhs: ArchivedRecord, _ rhs: ArchivedRecord) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func markdownEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "`", with: "\\`")
    }
}
