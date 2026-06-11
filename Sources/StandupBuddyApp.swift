import SwiftUI

@main
struct StandupBuddyApp: App {
    @State private var manager: DatabaseManager
    @State private var model: AppModel
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
        .defaultSize(width: 620, height: 520)
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

extension Notification.Name {
    static let generateStandup = Notification.Name("generateStandup")
}
