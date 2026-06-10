import Foundation

@MainActor
final class DataFolderStore {
    static let defaultsKey = "dataFolderBookmark"
    static let dbFilename = "standupbuddy.sqlite"

    private(set) var folderURL: URL?

    // Returns the resolved folder URL, starting security-scoped access.
    // Returns nil if no bookmark is saved or it can't be resolved.
    func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale { save(url: url) }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        folderURL = url
        return url
    }

    // Saves a security-scoped bookmark for the given folder URL.
    func save(url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        // Start access if not already doing so
        if folderURL != url {
            folderURL?.stopAccessingSecurityScopedResource()
            _ = url.startAccessingSecurityScopedResource()
            folderURL = url
        }
    }

    func stopAccessing() {
        folderURL?.stopAccessingSecurityScopedResource()
        folderURL = nil
    }

    // Returns the DB file URL for the currently resolved folder.
    var dbURL: URL? {
        folderURL?.appendingPathComponent(Self.dbFilename)
    }

    // A sensible default directory for the folder picker: the user's iCloud
    // Drive Documents folder, falling back to the on-disk CloudDocs path.
    static func defaultPickerDirectory() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
        ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    }

    // Copies the legacy Application Support database into the chosen folder
    // if no DB exists there yet. Leaves the legacy file untouched as a backup.
    func migrateLegacyIfNeeded(into folderURL: URL) {
        let destination = folderURL.appendingPathComponent(Self.dbFilename)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let legacyURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StandupBuddy/\(Self.dbFilename)")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        try? FileManager.default.copyItem(at: legacyURL, to: destination)
    }
}
