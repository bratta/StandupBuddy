import SwiftUI
import AppKit

struct DatabaseSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(DatabaseManager.self) private var manager

    var body: some View {
        Form {
            Section("Database") {
                LabeledContent("Folder") {
                    Text(folderDisplayPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folderDisplayPath)
                }
                HStack {
                    Button("Change Folder…") { changeFolder() }
                    Button("Show in Finder") { showInFinder() }
                        .disabled(manager.folderURL == nil)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Database folder

    private var folderDisplayPath: String {
        guard let url = manager.folderURL else { return "Not set" }
        return (url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }

    private func showInFinder() {
        guard let folder = manager.folderURL else { return }
        let dbURL = folder.appendingPathComponent(DataFolderStore.dbFilename)
        NSWorkspace.shared.activateFileViewerSelecting([dbURL])
    }

    private func changeFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use as Database Folder"
        panel.message = "Choose where Standup Buddy stores its database. For iCloud sync, pick a folder inside iCloud Drive."
        panel.directoryURL = manager.folderURL ?? DataFolderStore.defaultPickerDirectory()

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // If the chosen folder already has a database, adopt it. Otherwise ask
        // whether to bring the current data along or start fresh.
        let copyExistingData: Bool
        if manager.targetHasDatabase(at: url) {
            copyExistingData = false
        } else {
            switch promptForEmptyFolderChoice() {
            case .copy: copyExistingData = true
            case .fresh: copyExistingData = false
            case .cancel: return
            }
        }

        Task {
            if let error = await manager.changeFolder(to: url, copyExistingData: copyExistingData) {
                presentError(error)
            } else {
                await model.loadAll()
            }
        }
    }

    private enum EmptyFolderChoice { case copy, fresh, cancel }

    private func promptForEmptyFolderChoice() -> EmptyFolderChoice {
        let alert = NSAlert()
        alert.messageText = "No Database in That Folder"
        alert.informativeText = "The selected folder doesn't contain a Standup Buddy database. Would you like to move your current data there, or start with a fresh, empty database?"
        alert.addButton(withTitle: "Move My Data")   // .alertFirstButtonReturn
        alert.addButton(withTitle: "Start Fresh")     // .alertSecondButtonReturn
        alert.addButton(withTitle: "Cancel")          // .alertThirdButtonReturn
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .copy
        case .alertSecondButtonReturn: return .fresh
        default: return .cancel
        }
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn't Change Database Folder"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
