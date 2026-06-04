import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showGenerate = false
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
                Button("Generate") { showGenerate = true }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Open Settings")
            }
        }
        .sheet(isPresented: $showGenerate) {
            GeneratePreviewSheet()
                .environment(model)
        }
        .onReceive(NotificationCenter.default.publisher(for: .generateStandup)) { _ in
            showGenerate = true
        }
        .task { await model.loadAll() }
    }
}
