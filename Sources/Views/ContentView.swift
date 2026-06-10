import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DataEntryView()
                .tabItem { Label("Entries", systemImage: "list.bullet") }
                .tag(0)

            SectionsView()
                .tabItem { Label("Preview", systemImage: "rectangle.3.group") }
                .tag(1)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Generate") { NotificationCenter.default.post(name: .generateStandup, object: nil) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Open Settings")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .generateStandup)) { _ in
            openWindow(id: "standup-output")
        }
        .task { await model.loadAll() }
    }
}
