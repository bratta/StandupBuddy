import SwiftUI

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didHandleLaunch = false

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !didHandleLaunch else { return }
        didHandleLaunch = true
        // Close any state-restored standup output window — it should only open on explicit request.
        DispatchQueue.main.async {
            NSApp.windows
                .filter { $0.title == "Standup Output" }
                .forEach { $0.close() }
        }
    }
}

@main
struct StandupBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var manager: DatabaseManager
    @State private var model: AppModel
    @State private var updateChecker = UpdateChecker()
    @State private var isPresentingSuperseded = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
        let m = DatabaseManager()
        _manager = State(initialValue: m)
        _model = State(initialValue: AppModel(manager: m))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if manager.needsSetup {
                    DataFolderSetupView(manager: manager) {
                        await model.loadAll()
                    }
                } else {
                    ContentView()
                        .environment(model)
                }
            }
            .task {
                manager.setup()
                if manager.supersededDatabaseURL != nil {
                    handleSupersededIfNeeded()
                } else if !manager.needsSetup {
                    await model.loadAll()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    Task {
                        await manager.reconnect()
                        if manager.supersededDatabaseURL != nil {
                            handleSupersededIfNeeded()
                        } else {
                            await model.loadAll()
                        }
                    }
                case .background, .inactive:
                    manager.close()
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .databaseConflictDetected)) { note in
                guard let url = note.object as? URL else { return }
                showConflictAlert(for: url)
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button {
                    Task { await updateChecker.checkForUpdates() }
                } label: {
                    Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(updateChecker.isChecking)
            }
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(after: .newItem) {
                Button("Generate Standup...") {
                    NotificationCenter.default.post(name: .generateStandup, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            ViewMenuCommands(model: model)
        }

        Window("Standup Output", id: "standup-output") {
            GeneratePreviewSheet()
                .environment(model)
        }
        .defaultSize(width: 820, height: 540)
        .windowResizability(.contentMinSize)

        Window("API Console Log", id: "api-console") {
            APIConsoleView()
        }
        .defaultSize(width: 700, height: 500)

        Settings {
            SettingsView()
                .environment(model)
                .environment(manager)
        }
    }

    private func showConflictAlert(for url: URL) {
        let alert = NSAlert()
        alert.messageText = "Database Conflict Detected"
        alert.informativeText = "iCloud found a conflicting copy of your database (both Macs wrote data before syncing). Your current data is intact. You can inspect the conflict copies via iCloud Drive in Finder."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // Present the superseded-database dialog if the manager has flagged one,
    // guarding against re-entrancy from the launch task and scene-activation
    // paths both firing.
    private func handleSupersededIfNeeded() {
        guard !isPresentingSuperseded, let url = manager.supersededDatabaseURL else { return }
        isPresentingSuperseded = true
        presentSupersededAlert(for: url)
        isPresentingSuperseded = false
    }

    // The database in the active folder was written by a newer version of the
    // app. Offer to quit (so the user can handle it), point at a different
    // folder, or start fresh — which backs the existing file up before replacing it.
    private func presentSupersededAlert(for dbURL: URL) {
        let folderURL = dbURL.deletingLastPathComponent()

        let alert = NSAlert()
        alert.messageText = "Database Created by a Newer Version"
        alert.informativeText = "The database in this folder was created by a newer version of Standup Buddy and can't be safely opened by this version.\n\nUpdate Standup Buddy, or choose a different folder. You can also start fresh — your existing database will be backed up to a “Backups” folder first so you can restore it later."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit Standup Buddy")     // .alertFirstButtonReturn
        alert.addButton(withTitle: "Choose Different Folder…") // .alertSecondButtonReturn
        alert.addButton(withTitle: "Start Fresh")             // .alertThirdButtonReturn

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSApp.terminate(nil)
        case .alertSecondButtonReturn:
            chooseDifferentFolderAfterSuperseded()
        case .alertThirdButtonReturn:
            Task {
                if let error = await manager.startFreshReplacing(at: folderURL) {
                    presentSupersededRecoveryError(error)
                } else {
                    await model.loadAll()
                }
            }
        default:
            break
        }
    }

    private func chooseDifferentFolderAfterSuperseded() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use as Database Folder"
        panel.message = "Choose a folder whose database was created by this version of Standup Buddy (or an empty folder to start fresh there)."
        panel.directoryURL = DataFolderStore.defaultPickerDirectory()

        guard panel.runModal() == .OK, let url = panel.url else {
            // User cancelled — re-present so they don't end up with no database.
            if let dbURL = manager.supersededDatabaseURL { presentSupersededAlert(for: dbURL) }
            return
        }

        manager.resolveSuperseded()
        manager.selectFolder(url)
        Task {
            if manager.database != nil { await model.loadAll() }
        }
    }

    private func presentSupersededRecoveryError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn't Start Fresh"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct ViewMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    var model: AppModel

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Toggle(isOn: Binding(
                get: { model.showCompletedEntries },
                set: { newValue in Task { await model.setShowCompletedEntries(newValue) } }
            )) {
                Label("Show Completed Entries", systemImage: "checklist")
            }
            Divider()
            Button {
                openWindow(id: "api-console")
            } label: {
                Label("Show API Console Log", systemImage: "terminal")
            }
        }
    }
}

/// Drives the user-initiated "Check for Updates…" flow and presents the result
/// with an NSAlert (mirroring StandupBuddyApp.showConflictAlert).
@MainActor
@Observable
final class UpdateChecker {
    private(set) var isChecking = false

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let result = try await UpdateService.checkForUpdate()
            switch result {
            case .upToDate(let current):
                presentUpToDate(current: current)
            case .updateAvailable(let current, let latest, let releaseURL):
                presentUpdateAvailable(current: current, latest: latest, releaseURL: releaseURL)
            }
        } catch {
            presentError(error)
        }
    }

    private func presentUpToDate(current: String) {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "Standup Buddy \(current) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentUpdateAvailable(current: String, latest: String, releaseURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Standup Buddy \(latest) is available — you have \(current)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Close")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't Check for Updates"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension Notification.Name {
    static let generateStandup = Notification.Name("generateStandup")
}
