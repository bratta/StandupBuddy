import SwiftUI

struct CalendarImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var events: [CalendarEventInfo] = []
    @State private var selected: Set<String> = []
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Today's Events")
                .font(.title2).bold()

            content

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Add Events as Entries") { addSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
            }
        }
        .padding()
        .frame(width: 460, height: 460)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            VStack { Spacer(); ProgressView(); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !model.calendarAuthorized {
            unavailable("Calendar access not granted", systemImage: "calendar.badge.exclamationmark",
                        detail: "Grant access in Settings → Calendars.")
        } else if events.isEmpty {
            unavailable("No events today", systemImage: "calendar",
                        detail: "Nothing scheduled in your enabled calendars.")
        } else {
            List {
                ForEach(events) { event in
                    Toggle(isOn: binding(for: event.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                            Text("\(timeLabel(event)) · \(event.calendarTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .listStyle(.inset)
        }
    }

    private func unavailable(_ title: String, systemImage: String, detail: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(detail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { v in
                if v { selected.insert(id) } else { selected.remove(id) }
            }
        )
    }

    private func timeLabel(_ event: CalendarEventInfo) -> String {
        if event.isAllDay { return "All day" }
        return event.start.formatted(date: .omitted, time: .shortened)
    }

    private func load() async {
        loading = true
        if !model.calendarAuthorized {
            await model.requestCalendarAccess()
        }
        events = model.fetchTodayEvents()
        loading = false
    }

    private func addSelected() {
        let items = events
            .filter { selected.contains($0.id) }
            .map { StandupItem(date: .now, details: $0.title, category: .standup, completed: false) }
        Task { await model.addItems(items) }
        dismiss()
    }
}
