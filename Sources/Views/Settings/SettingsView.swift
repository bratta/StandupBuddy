import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .environment(model)

            TextReplacementSettingsView()
                .tabItem { Label("Replacements", systemImage: "text.magnifyingglass") }
                .environment(model)

            GitHubSettingsView()
                .tabItem { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                .environment(model)
        }
        .frame(width: 560, height: 420)
        .task { await model.loadAll() }
    }
}
