import Foundation
import SQLite3

enum DatabaseMigration {
    // Version 3 adds explicit conversation ownership and per-thread drafts.
    // Keeping this as a real migration matters for databases created by early
    // development builds that already recorded user_version = 1.
    static let currentVersion: Int32 = 3

    static func apply(to database: OpaquePointer) throws {
        let version = sqlite3_user_version(database)
        guard version <= currentVersion else {
            throw ProjectStoreError.unsupportedSchema(Int(version))
        }
        guard version < currentVersion else { return }

        let statements = [
            "CREATE TABLE IF NOT EXISTS projects (id TEXT PRIMARY KEY, data BLOB NOT NULL)",
            "CREATE TABLE IF NOT EXISTS sources (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS conversations (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, conversation_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS artifacts (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS proposals (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS changes (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, revision INTEGER NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS outcomes (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS recommendations (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS jobs (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, data BLOB NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS drafts (project_id TEXT PRIMARY KEY, text TEXT NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS conversation_drafts (conversation_id TEXT PRIMARY KEY, project_id TEXT NOT NULL, text TEXT NOT NULL, FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE)",
            "CREATE TABLE IF NOT EXISTS deletion_tombstones (project_id TEXT PRIMARY KEY, token TEXT NOT NULL, created_at TEXT NOT NULL)",
            "CREATE INDEX IF NOT EXISTS idx_sources_project ON sources(project_id)",
            "CREATE INDEX IF NOT EXISTS idx_messages_project ON messages(project_id)",
            "CREATE INDEX IF NOT EXISTS idx_conversations_project ON conversations(project_id)",
            "CREATE INDEX IF NOT EXISTS idx_artifacts_project ON artifacts(project_id)",
            "CREATE INDEX IF NOT EXISTS idx_proposals_project ON proposals(project_id)",
            "CREATE INDEX IF NOT EXISTS idx_changes_project ON changes(project_id, revision)",
            "CREATE INDEX IF NOT EXISTS idx_outcomes_project ON outcomes(project_id)"
        ]

        try execute(database, "BEGIN IMMEDIATE")
        do {
            for statement in statements { try execute(database, statement) }
            try execute(database, "PRAGMA user_version = \(currentVersion)")
            try execute(database, "COMMIT")
        } catch {
            _ = try? execute(database, "ROLLBACK")
            throw error
        }
    }

    @discardableResult
    static func execute(_ database: OpaquePointer, _ sql: String) throws -> Int32 {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw ProjectStoreError.database(message)
        }
        return result
    }
}

private func sqlite3_user_version(_ database: OpaquePointer) -> Int32 {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK,
          let statement else { return 0 }
    defer { sqlite3_finalize(statement) }
    return sqlite3_step(statement) == SQLITE_ROW ? sqlite3_column_int(statement, 0) : 0
}
