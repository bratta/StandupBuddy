import Foundation
import GRDB

final class AppDatabase: Sendable {
    let dbQueue: DatabaseQueue

    init(path: String) throws {
        let queue = try DatabaseQueue(path: path)
        self.dbQueue = queue
        try migrate(queue)
    }

    // For tests — in-memory database
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
        try! migrate(dbQueue)
    }

    private func migrate(_ db: DatabaseQueue) throws {
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

        try migrator.migrate(db)
    }
}
