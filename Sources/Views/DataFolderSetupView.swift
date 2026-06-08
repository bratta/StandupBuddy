import SwiftUI
import AppKit

struct DataFolderSetupView: View {
    let manager: DatabaseManager
    let onComplete: () async -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Choose a Database Folder")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Standup Buddy stores its data in a single SQLite file. Pick a folder in iCloud Drive to sync between your Macs, or any local folder for single-machine use.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 360)
            }

            Button("Choose Folder…") {
                pickFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(minWidth: 480)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use as Database Folder"
        panel.message = "Choose where Standup Buddy stores its database. For iCloud sync, pick a folder inside iCloud Drive."
        panel.directoryURL = iCloudDriveURL()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            manager.selectFolder(url)
            await onComplete()
        }
    }

    private func iCloudDriveURL() -> URL? {
        FileManager.default.url(
            forUbiquityContainerIdentifier: nil
        )?.appendingPathComponent("Documents") ??
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    }
}
