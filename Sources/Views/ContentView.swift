import SwiftUI

private enum MainTab: String, CaseIterable {
    case entries = "Entries"
    case quickPreview = "Quick Preview"

    var icon: String {
        switch self {
        case .entries: return "list.bullet"
        case .quickPreview: return "eye"
        }
    }

    var activeColor: Color {
        switch self {
        case .entries: return .textPrimary
        case .quickPreview: return Color(red: 0.612, green: 0.753, blue: 0.961) // #9CC0F5
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab: MainTab = .entries
    @State private var showCalendarImport = false

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().overlay(Color.softBorder)
            contentArea
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCalendarImport = true } label: {
                    Label("Import from Calendar", systemImage: "calendar.badge.plus")
                }
                .help("Import today's calendar events as entries")
            }
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
        .sheet(isPresented: $showCalendarImport) {
            CalendarImportSheet().environment(model)
        }
        .task { await model.loadAll() }
    }

    private var tabBar: some View {
        HStack {
            Spacer()
            tabSwitcher
            Spacer()
        }
        .padding(.vertical, 10)
        .background(Color.bgRaised)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 3) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(red: 0.188, green: 0.165, blue: 0.157))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.softBorder, lineWidth: 1)
                )
        )
    }

    private func tabButton(for tab: MainTab) -> some View {
        let isActive = selectedTab == tab
        return Button { selectedTab = tab } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(isActive ? tab.activeColor : Color.codeText)
            .padding(.vertical, 6)
            .padding(.leading, 13)
            .padding(.trailing, 15)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 0.290, green: 0.259, blue: 0.247),
                                Color(red: 0.231, green: 0.200, blue: 0.192)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: isActive)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .entries:
            DataEntryView()
        case .quickPreview:
            SectionsView()
        }
    }
}
