import Foundation
import Observation

@Observable
@MainActor
final class DatabaseManager {
    private(set) var database: AppDatabase?
    private(set) var needsSetup: Bool = false
    private(set) var folderURL: URL?

    // Set when the database in the active folder was written by a newer version
    // of the app. The UI observes this to present the resolution dialog.
    private(set) var supersededDatabaseURL: URL?

    private let folderStore = DataFolderStore()

    // Call once on launch to open the database from a saved bookmark (or signal setup needed).
    func setup() {
        guard let folder = folderStore.resolve() else {
            needsSetup = true
            return
        }
        folderURL = folder
        folderStore.migrateLegacyIfNeeded(into: folder)
        open(folderURL: folder)
    }

    // Called after the user picks a folder. Saves the bookmark and opens the DB.
    func selectFolder(_ url: URL) {
        folderStore.save(url: url)
        folderURL = url
        folderStore.migrateLegacyIfNeeded(into: url)
        open(folderURL: url)
        needsSetup = false
    }

    // Whether the given folder already contains a Standup Buddy database file.
    // Wraps security-scoped access so it works for a freshly picked URL.
    func targetHasDatabase(at url: URL) -> Bool {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        let dbURL = url.appendingPathComponent(DataFolderStore.dbFilename)
        return FileManager.default.fileExists(atPath: dbURL.path)
    }

    // Switch the active database to a new folder.
    //
    // - If the folder already holds a compatible database, it is opened and used.
    // - If the folder is empty and `copyExistingData` is true, the current
    //   database file is copied into it first (preserving the user's data).
    // - If the folder is empty and `copyExistingData` is false, a fresh,
    //   empty database is created there.
    //
    // The switch is validated before it is committed: if the database in the
    // new folder can't be opened/migrated, the previous folder is restored and
    // a human-readable error message is returned. Returns nil on success.
    func changeFolder(to url: URL, copyExistingData: Bool) async -> String? {
        let fm = FileManager.default
        let newDBURL = url.appendingPathComponent(DataFolderStore.dbFilename)
        let oldFolder = folderURL
        let oldDBURL = oldFolder?.appendingPathComponent(DataFolderStore.dbFilename)

        // Hold access to the new folder for the duration of the file operations.
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }

        let targetHasDB = fm.fileExists(atPath: newDBURL.path)

        // Close the current connection so the source file is settled and the
        // destination isn't opened under two connections.
        database = nil

        // Bring the existing data along when moving into an empty folder.
        if !targetHasDB, copyExistingData, let oldDBURL, fm.fileExists(atPath: oldDBURL.path) {
            do {
                try fm.copyItem(at: oldDBURL, to: newDBURL)
            } catch {
                if let oldFolder { open(folderURL: oldFolder) }
                return "Couldn't copy the database into the new folder: \(error.localizedDescription)"
            }
        }

        // Validate that the database at the new location opens and migrates
        // cleanly before committing the switch.
        let candidate: AppDatabase
        do {
            candidate = try AppDatabase(path: newDBURL.path)
        } catch DatabaseOpenError.superseded {
            if let oldFolder { open(folderURL: oldFolder) }
            return "The database in the selected folder was created by a newer version of Standup Buddy and can't be opened by this version. Update Standup Buddy, or choose a different folder."
        } catch {
            if let oldFolder { open(folderURL: oldFolder) }
            return "The database in the selected folder couldn't be opened.\n\n\(error.localizedDescription)"
        }

        // Commit: persist the bookmark and adopt the new connection.
        folderStore.save(url: url)
        folderURL = url
        database = candidate
        needsSetup = false
        return nil
    }

    // Close the current database so iCloud can sync the at-rest file,
    // then reopen it (with NSFileCoordinator to force download of latest version).
    func reconnect() async {
        guard let folder = folderURL ?? folderStore.resolve() else { return }
        if folderURL == nil { folderURL = folder }
        let dbURL = folder.appendingPathComponent(DataFolderStore.dbFilename)

        database = nil

        // Force iCloud to materialise the latest version before reopening.
        await Task.detached(priority: .userInitiated) {
            var coordinatorError: NSError?
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: dbURL, options: [], error: &coordinatorError) { _ in
                // Block runs synchronously; iCloud downloads the file before returning.
            }
        }.value

        open(folderURL: folder)
    }

    // Tear down the connection so the OS/iCloud can upload the settled file.
    func close() {
        database = nil
    }

    // Replace the database in the given folder with a fresh, empty one, backing
    // up the existing file first. Used to recover from a superseded ("newer
    // version") database when the user chooses to start fresh. The backup is
    // taken before the live file is removed, so a crash mid-operation still
    // leaves a recoverable copy. Returns a human-readable error, or nil on success.
    func startFreshReplacing(at folderURL: URL) async -> String? {
        let dbURL = folderURL.appendingPathComponent(DataFolderStore.dbFilename)
        let fm = FileManager.default

        // Close any open connection so the file is settled before we touch it.
        database = nil

        if fm.fileExists(atPath: dbURL.path) {
            do {
                try AppDatabase.backupDatabaseFile(at: dbURL.path, reason: "reset")
            } catch {
                open(folderURL: folderURL)
                return "Couldn't back up the existing database before starting fresh: \(error.localizedDescription)"
            }
            do {
                try fm.removeItem(at: dbURL)
            } catch {
                open(folderURL: folderURL)
                return "Couldn't remove the existing database: \(error.localizedDescription)"
            }
        }

        supersededDatabaseURL = nil
        self.folderURL = folderURL
        open(folderURL: folderURL)
        return database == nil ? "Couldn't create a fresh database in the selected folder." : nil
    }

    // Clear the superseded flag once the user has resolved it (e.g. chose a
    // different folder or quit).
    func resolveSuperseded() {
        supersededDatabaseURL = nil
    }

    // For tests or pre-seeded in-memory databases.
    func useDatabase(_ db: AppDatabase) {
        database = db
        needsSetup = false
    }

    // MARK: - Private

    private func open(folderURL: URL) {
        let dbURL = folderURL.appendingPathComponent(DataFolderStore.dbFilename)
        do {
            database = try AppDatabase(path: dbURL.path)
            supersededDatabaseURL = nil
        } catch DatabaseOpenError.superseded {
            database = nil
            supersededDatabaseURL = dbURL
        } catch {
            database = nil
        }
    }

}

extension Notification.Name {
    static let databaseConflictDetected = Notification.Name("databaseConflictDetected")
}
