import SwiftUI

struct HeaderSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                headerRow(
                    label: "Previous",
                    placeholder: Setting.previousHeaderDefault,
                    value: model.previousHeader,
                    key: Setting.previousHeaderKey
                )
                headerRow(
                    label: "Today",
                    placeholder: Setting.todayHeaderDefault,
                    value: model.todayHeader,
                    key: Setting.todayHeaderKey
                )
                headerRow(
                    label: "Blockers",
                    placeholder: Setting.blockersHeaderDefault,
                    value: model.blockersHeader,
                    key: Setting.blockersHeaderKey
                )
                headerRow(
                    label: "Open Pull Requests",
                    placeholder: Setting.openPRsHeaderDefault,
                    value: model.openPRsHeader,
                    key: Setting.openPRsHeaderKey
                )
                headerRow(
                    label: "Gratitude/Joy/Others",
                    placeholder: Setting.gratitudeHeaderDefault,
                    value: model.gratitudeHeader,
                    key: Setting.gratitudeHeaderKey
                )
            } header: {
                Text("Section Headers")
            } footer: {
                Text("Leave blank to use the default. Text replacements like {yesterday} and {format_date('%A')} are supported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func headerRow(label: String, placeholder: String, value: String, key: String) -> some View {
        LabeledContent(label) {
            TextField(placeholder, text: Binding(
                get: { value },
                set: { v in Task { await model.setStringSetting(key: key, value: v) } }
            ))
            .multilineTextAlignment(.trailing)
        }
    }
}
