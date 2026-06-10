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
                        Text("{today} or {format_date}")
                            .font(.body.monospaced())
                        Text("Replaced with the current workday name (e.g. Friday).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Accepts an optional strftime format: {today('%Y-%m-%d')}.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { model.yesterdayEnabled },
                    set: { v in Task { await model.setSetting(key: Setting.yesterdayEnabledKey, value: v) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("{previous} or {yesterday}")
                            .font(.body.monospaced())
                        Text("Replaced with the previous workday name (e.g. Friday).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Accepts an optional strftime format: {previous('%Y-%m-%d')}.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { model.funFactEnabled },
                    set: { v in Task { await model.setSetting(key: Setting.funFactEnabledKey, value: v) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("{fun_fact}")
                            .font(.body.monospaced())
                        Text("Replaced with a random fun fact from uselessfacts.jsph.pl")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { model.affirmationEnabled },
                    set: { v in Task { await model.setSetting(key: Setting.affirmationEnabledKey, value: v) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("{affirmation}")
                            .font(.body.monospaced())
                        Text("Replaced with a random positive affirmation from affirmations.dev")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { model.emojiOfDayEnabled },
                    set: { v in Task { await model.setSetting(key: Setting.emojiOfDayEnabledKey, value: v) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("{emoji_of_day}")
                            .font(.body.monospaced())
                        Text("Replaced with a consistent emoji for today's date — changes each day, the same for everyone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { model.entryDateEnabled },
                    set: { v in Task { await model.setSetting(key: Setting.entryDateEnabledKey, value: v) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("{entry_date}")
                            .font(.body.monospaced())
                        Text("Replaced with the entry's own date (e.g. 2025-06-02).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Accepts an optional strftime format: {entry_date('%A')}.")
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
