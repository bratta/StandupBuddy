import SwiftUI

@main
struct StandupBuddyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Generate Standup...") {
                    NotificationCenter.default.post(name: .generateStandup, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                Divider()
                Button("Open SQLite Database in Finder") {
                    let url = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("StandupBuddy/standupbuddy.sqlite")
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            ViewMenuCommands()
        }

        Window("API Console Log", id: "api-console") {
            APIConsoleView()
        }
        .defaultSize(width: 700, height: 500)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

private struct ViewMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("View") {
            Button("Show API Console Log") {
                openWindow(id: "api-console")
            }
        }
    }
}

extension Notification.Name {
    static let generateStandup = Notification.Name("generateStandup")
}
