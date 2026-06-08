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
