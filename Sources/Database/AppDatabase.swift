import Foundation
import GRDB

/// Errors surfaced while opening the database file.
enum DatabaseOpenError: Error {
    /// The database refers to migrations this build doesn't know about — i.e. it
    /// was written by a newer version of Standup Buddy. We refuse to open it
    /// rather than migrating/reading against an unexpected schema.
    case superseded
}

final class AppDatabase: Sendable {
    let dbQueue: DatabaseQueue

    init(path: String) throws {
        let queue = try DatabaseQueue(path: path)
        let migrator = Self.makeMigrator()

        let (superseded, applied, completed) = try queue.read { db in
            (try migrator.hasBeenSuperseded(db),
             try migrator.appliedIdentifiers(db),
             try migrator.hasCompletedMigrations(db))
        }

        // A database written by a newer app version would let GRDB's migrate()
        // silently no-op the unknown future migrations and "succeed" — only to
        // fail later when reading rows against an unexpected schema. Detect and
        // bail out before touching anything.
        if superseded {
            throw DatabaseOpenError.superseded
        }

        // Back up before migrating an *existing* database that has data to lose
        // (at least one migration already applied, but not all). A brand-new or
        // freshly-created file has nothing to protect, so it's skipped — this
        // also avoids a spurious backup on first launch. DatabaseQueue uses a
        // rollback journal (not WAL) and there's no transaction in flight here,
        // so the on-disk .sqlite file is fully consistent to copy byte-for-byte.
        if !completed && !applied.isEmpty {
            try Self.backupDatabaseFile(at: path, reason: "premigration")
        }

        try migrator.migrate(queue)
        self.dbQueue = queue
    }

    // For tests — in-memory database
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
        try! Self.makeMigrator().migrate(dbQueue)
    }

    // MARK: - Backups

    private static let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    /// Copies the live database file into a `Backups` subfolder of the data
    /// folder with a timestamped, reason-tagged name. The user can restore it
    /// manually. Backups are never auto-deleted.
    ///
    /// - Returns: The URL of the backup that was created.
    @discardableResult
    static func backupDatabaseFile(at dbPath: String, reason: String) throws -> URL {
        let dbURL = URL(fileURLWithPath: dbPath)
        let backupsDir = dbURL.deletingLastPathComponent().appendingPathComponent("Backups")
        try FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        let stamp = backupTimestampFormatter.string(from: Date())
        let dest = backupsDir.appendingPathComponent("standupbuddy-backup-\(stamp)-\(reason).sqlite")
        try FileManager.default.copyItem(at: dbURL, to: dest)
        return dest
    }

    // MARK: - Migrations

    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_standupItem") { db in
            try db.create(table: "standupItem") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("details", .text).notNull().defaults(to: "")
                t.column("category", .text).notNull().defaults(to: "standup")
                t.column("completed", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }

        migrator.registerMigration("v1_repositoryConfig") { db in
            try db.create(table: "repositoryConfig") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("owner", .text).notNull().defaults(to: "")
                t.column("name", .text).notNull().defaults(to: "")
                t.column("displayName", .text).notNull().defaults(to: "")
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v1_customReplacement") { db in
            try db.create(table: "customReplacement") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().defaults(to: "")
                t.column("pattern", .text).notNull().defaults(to: "")
                t.column("template", .text).notNull().defaults(to: "")
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v1_holiday") { db in
            try db.create(table: "holiday") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("name", .text).notNull().defaults(to: "")
            }
        }

        migrator.registerMigration("v1_ptoRange") { db in
            try db.create(table: "ptoRange") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("startDate", .text).notNull()
                t.column("endDate", .text).notNull()
                t.column("note", .text).notNull().defaults(to: "")
            }
        }

        migrator.registerMigration("v1_setting") { db in
            try db.create(table: "setting") { t in
                t.primaryKey("id", .text)
                t.column("value", .text).notNull().defaults(to: "")
            }
            // Seed defaults
            try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.dadJokeEnabledKey, "true"])
            try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.formatDateEnabledKey, "true"])
        }

        migrator.registerMigration("v2_drop_holidays_pto") { db in
            try db.execute(sql: "DROP TABLE IF EXISTS holiday")
            try db.execute(sql: "DROP TABLE IF EXISTS ptoRange")
        }

        migrator.registerMigration("v3_new_builtin_replacements") { db in
            try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.yesterdayEnabledKey, "true"])
            try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.funFactEnabledKey, "true"])
            try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.affirmationEnabledKey, "true"])
            try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.emojiOfDayEnabledKey, "true"])
        }

        migrator.registerMigration("v4_section_headers") { db in
            // Empty value means "use built-in default"
            let keys = [
                Setting.previousHeaderKey,
                Setting.todayHeaderKey,
                Setting.blockersHeaderKey,
                Setting.openPRsHeaderKey,
                Setting.gratitudeHeaderKey,
            ]
            for key in keys {
                try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [key, ""])
            }
        }

        migrator.registerMigration("v5_entry_date") { db in
            try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [Setting.entryDateEnabledKey, "true"])
        }

        migrator.registerMigration("v6_section_enabled") { db in
            let keys = [
                Setting.previousEnabledKey,
                Setting.todayEnabledKey,
                Setting.blockersEnabledKey,
                Setting.openPRsEnabledKey,
                Setting.gratitudeEnabledKey,
            ]
            for key in keys {
                try db.execute(sql: "INSERT OR IGNORE INTO setting (id, value) VALUES (?, ?)", arguments: [key, "true"])
            }
        }

        return migrator
    }
}
