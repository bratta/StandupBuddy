import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Built-in Text Replacements") {
                Toggle(isOn: Binding(
                    get: { model.dadJokeEnabled },
                    set: { v in Task { await model.setSetting(key: Setting.dadJokeEnabledKey, value: v) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("{dad_joke}")
                            .font(.body.monospaced())
                        Text("Replaced with :joy_cat: and a random dad joke from icanhazdadjoke.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { model.formatDateEnabled },
                    set: { v in Task { await model.setSetting(key: Setting.formatDateEnabledKey, value: v) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("{format_date('%A')}")
                            .font(.body.monospaced())
                        Text("Replaced with the formatted current date using POSIX strftime formatting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
