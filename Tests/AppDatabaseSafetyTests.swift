import Testing
import Foundation
import GRDB
@testable import StandupBuddy

@Suite("AppDatabase data-safety guards")
@MainActor
struct AppDatabaseSafetyTests {
    // A unique temp folder per test, cleaned up afterwards.
    @MainActor
    final class TempFolder {
        let url: URL
        init() {
            url = FileManager.default.temporaryDirectory
                .appendingPathComponent("AppDatabaseSafetyTests-\(UUID().uuidString)")
            try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: url) }

        var dbURL: URL { url.appendingPathComponent(DataFolderStore.dbFilename) }
        var backupsDir: URL { url.appendingPathComponent("Backups") }

        func backupFiles() -> [String] {
            (try? FileManager.default.contentsOfDirectory(atPath: backupsDir.path)) ?? []
        }
    }

    @Test("Pending migrations trigger a pre-migration backup")
    func backsUpBeforeMigrating() throws {
        let folder = TempFolder()

        // Create a partially-migrated database (only the first few migrations).
        let queue = try DatabaseQueue(path: folder.dbURL.path)
        try AppDatabase.makeMigrator().migrate(queue, upTo: "v1_setting")
        // Release the connection so the file is settled before reopening.
        try queue.close()

        // Opening through AppDatabase should back up, then finish migrating.
        let db = try AppDatabase(path: folder.dbURL.path)
        let completed = try db.dbQueue.read { try AppDatabase.makeMigrator().hasCompletedMigrations($0) }
        #expect(completed)

        let backups = folder.backupFiles()
        #expect(backups.count == 1)
        #expect(backups.first?.contains("premigration") == true)
    }

    @Test("A fully-migrated database is opened without creating a backup")
    func noBackupWhenCurrent() throws {
        let folder = TempFolder()

        // First open creates and fully migrates the database.
        _ = try AppDatabase(path: folder.dbURL.path)
        #expect(folder.backupFiles().isEmpty)

        // Reopening (as happens on every iCloud reconnect) must not back up again.
        _ = try AppDatabase(path: folder.dbURL.path)
        #expect(folder.backupFiles().isEmpty)
    }

    @Test("A database from a newer version is refused without mutation")
    func refusesSupersededDatabase() throws {
        let folder = TempFolder()

        // Fully migrate, then pretend a newer app applied an unknown migration.
        let queue = try DatabaseQueue(path: folder.dbURL.path)
        try AppDatabase.makeMigrator().migrate(queue)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES ('v999_future')")
        }
        try queue.close()

        let before = try Data(contentsOf: folder.dbURL)

        #expect(throws: DatabaseOpenError.superseded) {
            _ = try AppDatabase(path: folder.dbURL.path)
        }

        // The file must be byte-for-byte unchanged, and no backup created.
        let after = try Data(contentsOf: folder.dbURL)
        #expect(before == after)
        #expect(folder.backupFiles().isEmpty)
    }

    @Test("backupDatabaseFile copies the live file into a timestamped Backups entry")
    func backupHelperCopiesFile() throws {
        let folder = TempFolder()
        _ = try AppDatabase(path: folder.dbURL.path)

        let backupURL = try AppDatabase.backupDatabaseFile(at: folder.dbURL.path, reason: "reset")
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        #expect(backupURL.lastPathComponent.contains("reset"))
        #expect(try Data(contentsOf: backupURL) == (try Data(contentsOf: folder.dbURL)))
    }
}
