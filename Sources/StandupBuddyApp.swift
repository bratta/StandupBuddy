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
                if !manager.needsSetup {
                    await model.loadAll()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    Task {
                        await manager.reconnect()
                        await model.loadAll()
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
