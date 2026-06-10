import Foundation
import Observation

@Observable
@MainActor
final class DatabaseManager {
    private(set) var database: AppDatabase?
    private(set) var needsSetup: Bool = false
    private(set) var folderURL: URL?

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
        } catch {
            if let oldFolder { open(folderURL: oldFolder) }
            return "The database in the selected folder couldn't be opened. It may be from a newer version of Standup Buddy.\n\n\(error.localizedDescription)"
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

    // For tests or pre-seeded in-memory databases.
    func useDatabase(_ db: AppDatabase) {
        database = db
        needsSetup = false
    }

    // MARK: - Private

    private func open(folderURL: URL) {
        let dbPath = folderURL.appendingPathComponent(DataFolderStore.dbFilename).path
        database = try? AppDatabase(path: dbPath)
    }

}

extension Notification.Name {
    static let databaseConflictDetected = Notification.Name("databaseConflictDetected")
}
