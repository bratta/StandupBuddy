import SwiftUI

struct CalendarSettingsView: View {
    @Environment(AppModel.self) private var model

    private var calendarsBySource: [(source: String, calendars: [CalendarInfo])] {
        let grouped = Dictionary(grouping: model.availableCalendars, by: \.sourceTitle)
        return grouped
            .map { (source: $0.key, calendars: $0.value) }
            .sorted { $0.source < $1.source }
    }

    var body: some View {
        Form {
            if !model.calendarAuthorized {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Standup Buddy needs permission to read your calendars.")
                        Button("Grant Calendar Access") {
                            Task { await model.requestCalendarAccess() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }

            if model.calendarAuthorized {
                if model.availableCalendars.isEmpty {
                    Section {
                        Text("No calendars found.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(calendarsBySource, id: \.source) { group in
                        Section(group.source) {
                            ForEach(group.calendars) { cal in
                                Toggle(cal.title, isOn: Binding(
                                    get: { model.enabledCalendarIdentifiers.contains(cal.id) },
                                    set: { v in Task { await model.setCalendarEnabled(cal.id, enabled: v) } }
                                ))
                            }
                        }
                    }
                }
            }

            Section {
                Text("To import Google, Exchange, or other calendars, add the account in System Settings → Internet Accounts; it will appear here automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await model.loadCalendars() }
    }
}
