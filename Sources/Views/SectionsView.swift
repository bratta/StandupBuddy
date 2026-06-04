import SwiftUI

struct SectionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionBlock(title: "Previous", items: model.previousItems)
                sectionBlock(title: "Today", items: model.todayItems)
                sectionBlock(title: "Blockers", items: model.blockerItems, emptyNote: "No open blockers")
                prSection
                sectionBlock(title: "Gratitude/Joy/Others", items: model.gratitudeItems, emptyNote: "No open items")
            }
            .padding()
        }
        .task { await model.loadSectionItems() }
    }

    private func sectionBlock(title: String, items: [StandupItem], emptyNote: String = "No entries") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .bold()

            if items.isEmpty {
                Text("• \(emptyNote)")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(items) { item in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(item.details)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Open Pull Requests")
                .font(.headline)
                .bold()
            Text("(fetched live when you Generate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
        }
    }
}
