import SwiftUI

struct SectionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.previousEnabled {
                    sectionBlock(title: model.previousHeader.isEmpty ? Setting.previousHeaderDefault : model.previousHeader, items: model.previousItems)
                }
                if model.todayEnabled {
                    sectionBlock(title: model.todayHeader.isEmpty ? Setting.todayHeaderDefault : model.todayHeader, items: model.todayItems)
                }
                if model.blockersEnabled {
                    sectionBlock(title: model.blockersHeader.isEmpty ? Setting.blockersHeaderDefault : model.blockersHeader, items: model.blockerItems, emptyNote: "No open blockers")
                }
                if model.openPRsEnabled {
                    prSection
                }
                if model.gratitudeEnabled {
                    sectionBlock(title: model.gratitudeHeader.isEmpty ? Setting.gratitudeHeaderDefault : model.gratitudeHeader, items: model.gratitudeItems, emptyNote: "No open items")
                }
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
            Text(model.openPRsHeader.isEmpty ? Setting.openPRsHeaderDefault : model.openPRsHeader)
                .font(.headline)
                .bold()
            Text("(fetched live when you Generate)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
        }
    }
}
